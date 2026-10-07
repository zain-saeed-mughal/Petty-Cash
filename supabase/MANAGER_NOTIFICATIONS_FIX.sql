-- Notify admins and super admins for manager-tagged transactions
CREATE OR REPLACE FUNCTION public.log_advance_item_v2(
  p_id uuid, p_advance_id uuid, p_item text, p_amount numeric, p_bill_path text DEFAULT NULL,
  p_tagged_manager_id uuid DEFAULT NULL
) RETURNS public.advance_items LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; advance public.advance_requests; result public.advance_items; balance numeric;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy can add advance items' USING ERRCODE='42501'; END IF;
  
  IF p_id IS NULL OR NOT public.payment_amount_valid(p_amount)
    OR length(trim(coalesce(p_item,''))) NOT BETWEEN 1 AND 500
    OR (p_bill_path IS NOT NULL AND (p_bill_path NOT LIKE actor.uid::text||'/%' OR p_bill_path LIKE '%..%'))
  THEN RAISE EXCEPTION 'Check the item and amount'; END IF;

  SELECT * INTO result FROM public.advance_items WHERE id=p_id;
  IF FOUND THEN
    IF result.office_boy_id<>actor.uid OR result.advance_request_id<>p_advance_id
      OR result.item_description<>trim(p_item) OR result.amount_spent<>p_amount
      OR result.bill_path IS DISTINCT FROM p_bill_path THEN RAISE EXCEPTION 'Item reference already used'; END IF;
    RETURN result;
  END IF;

  SELECT * INTO advance FROM public.advance_requests WHERE id=p_advance_id FOR UPDATE;
  IF NOT FOUND OR advance.flow_version<>2 OR advance.office_boy_id<>actor.uid
    OR advance.office_id<>actor.office_id THEN RAISE EXCEPTION 'Advance not found' USING ERRCODE='42501'; END IF;
  IF advance.status<>'cleared' THEN RAISE EXCEPTION 'This advance is not available for spending'; END IF;

  balance := public.core_advance_balance(p_advance_id);
  IF p_amount > balance THEN RAISE EXCEPTION 'This exceeds your remaining advance balance'; END IF;

  INSERT INTO public.advance_items(id, advance_request_id, office_boy_id, office_id, item_description, amount_spent, bill_path, status, tagged_manager_id)
  VALUES(p_id, p_advance_id, actor.uid, actor.office_id, trim(p_item), p_amount, p_bill_path, 'pending', p_tagged_manager_id) RETURNING * INTO result;

  INSERT INTO public.core_payment_activity(advance_request_id, office_boy_id, office_id, actor_id, action, detail)
  VALUES(p_advance_id, actor.uid, actor.office_id, actor.uid, 'item_added',
    jsonb_build_object('item_id', result.id, 'amount', p_amount, 'item', result.item_description, 'status', 'pending'));
    
  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  SELECT uid,'New Advance Item',actor.name||' submitted an advance item for PKR '||p_amount||' for review.',p_advance_id
  FROM public.users WHERE "isActive" AND role='finance';

  IF p_tagged_manager_id IS NOT NULL THEN
      -- Notify Tagged Manager
      INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
      VALUES (
          p_tagged_manager_id,
          'New Tagged Purchase',
          'Office Boy logged a purchase tagged to you for: ' || p_item,
          p_advance_id
      );
      
      -- Notify Admins and Super Admins
      INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
      SELECT uid, 'New Tagged Purchase', 'Office Boy logged a purchase tagged to a Manager.', p_advance_id
      FROM public.users WHERE "isActive" AND role IN ('admin', 'super_admin');
  END IF;

  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.submit_reimbursement_v2(
  p_id uuid,p_item text,p_amount numeric,p_method text,p_bill_path text DEFAULT NULL,
  p_account_name text DEFAULT NULL,p_account_details text DEFAULT NULL,
  p_tagged_manager_id uuid DEFAULT NULL
) RETURNS public.reimbursement_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.reimbursement_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy can request repayment' USING ERRCODE='42501'; END IF;
  IF p_id IS NULL OR NOT public.payment_amount_valid(p_amount)
    OR length(trim(coalesce(p_item,''))) NOT BETWEEN 1 AND 500
    OR p_method IS NULL OR p_method NOT IN ('cash','card')
    OR length(coalesce(p_account_name,''))>120 OR length(coalesce(p_account_details,''))>500
    OR (p_method='cash' AND (nullif(trim(coalesce(p_account_name,'')),'') IS NOT NULL
      OR nullif(trim(coalesce(p_account_details,'')),'') IS NOT NULL))
    OR (p_bill_path IS NOT NULL AND (p_bill_path NOT LIKE actor.uid::text||'/%' OR p_bill_path LIKE '%..%'))
  THEN RAISE EXCEPTION 'Check the item, amount and payment details'; END IF;
  SELECT * INTO result FROM public.reimbursement_requests WHERE id=p_id;
  IF FOUND THEN
    IF result.office_boy_id<>actor.uid OR result.item_description<>trim(p_item)
      OR result.amount_spent<>p_amount OR result.payment_method_wanted<>p_method
      OR result.bill_path IS DISTINCT FROM p_bill_path
      OR result.receiver_account_name IS DISTINCT FROM nullif(trim(p_account_name),'')
      OR result.receiver_account_details IS DISTINCT FROM nullif(trim(p_account_details),'')
    THEN RAISE EXCEPTION 'Request reference already used'; END IF;
    RETURN result;
  END IF;
  INSERT INTO public.reimbursement_requests(id,office_boy_id,office_id,item_description,amount_spent,bill_path,
    payment_method_wanted,receiver_account_name,receiver_account_details, tagged_manager_id)
  VALUES(p_id,actor.uid,actor.office_id,trim(p_item),p_amount,p_bill_path,p_method,
    nullif(trim(p_account_name),''),nullif(trim(p_account_details),''), p_tagged_manager_id) RETURNING * INTO result;
  INSERT INTO public.core_payment_activity(reimbursement_id,office_boy_id,office_id,actor_id,action)
  VALUES(result.id,actor.uid,actor.office_id,actor.uid,'requested');
  INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
  SELECT uid,'Repayment requested',actor.name||' requested PKR '||p_amount||' repayment.',result.id
  FROM public.users WHERE "isActive" AND role='finance';

  IF p_tagged_manager_id IS NOT NULL THEN
      -- Notify Tagged Manager
      INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
      VALUES (
          p_tagged_manager_id,
          'New Tagged Reimbursement',
          'Office Boy requested a reimbursement tagged to you for: ' || p_item,
          result.id
      );
      
      -- Notify Admins and Super Admins
      INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
      SELECT uid, 'New Tagged Reimbursement', 'Office Boy submitted an expense tagged to a Manager.', result.id
      FROM public.users WHERE "isActive" AND role IN ('admin', 'super_admin');
  END IF;

  RETURN result;
END $$;
