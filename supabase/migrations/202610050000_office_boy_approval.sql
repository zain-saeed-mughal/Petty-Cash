BEGIN;

ALTER TABLE public.advance_requests DROP CONSTRAINT IF EXISTS advance_requests_v2_valid;
ALTER TABLE public.advance_requests
  ADD CONSTRAINT advance_requests_v2_valid CHECK (
    (flow_version = 1 AND status IN ('Pending','Approved','Rejected')) OR
    (flow_version = 2 AND status IN ('pending','cleared','fully_utilized','awaiting_office_boy_approval','declined')
      AND amount_requested = amount
      AND payment_method_requested IN ('cash','card')
      AND ((payment_method_requested = 'cash'
        AND receiver_account_name IS NULL AND receiver_account_details IS NULL)
        OR (payment_method_requested = 'card'
          AND length(trim(coalesce(receiver_account_name,''))) <= 120
          AND length(trim(coalesce(receiver_account_details,''))) <= 500))
      AND length(coalesce(finance_note,'')) <= 2000)
  );

CREATE OR REPLACE FUNCTION public.direct_allot_advance_v2(
  p_id uuid, p_office_boy_id uuid, p_amount numeric, p_purpose text, p_method text
) RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; boy public.users; result public.advance_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance can allot advances' USING ERRCODE='42501'; END IF;
  
  SELECT * INTO boy FROM public.users WHERE uid=p_office_boy_id AND "isActive" AND role='office_boy';
  IF NOT FOUND THEN RAISE EXCEPTION 'Active office boy not found'; END IF;
  
  IF p_id IS NULL OR NOT public.payment_amount_valid(p_amount)
    OR length(trim(coalesce(p_purpose,''))) NOT BETWEEN 1 AND 2000
    OR p_method NOT IN ('cash','card')
  THEN RAISE EXCEPTION 'Check the amount, purpose and payment details'; END IF;
  
  SELECT * INTO result FROM public.advance_requests WHERE id = p_id;
  IF FOUND THEN RETURN result; END IF;
  
  INSERT INTO public.advance_requests(id,office_boy_id,office_id,amount,amount_requested,purpose,status,
    payment_method_requested,flow_version,cleared_by,cleared_method,cleared_at)
  VALUES(p_id,boy.uid,boy.office_id,p_amount,p_amount,trim(p_purpose),'awaiting_office_boy_approval',p_method,2,actor.uid,p_method,now())
  RETURNING * INTO result;
  
  INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action,detail)
  VALUES(result.id,result.office_boy_id,result.office_id,actor.uid,'direct_allot_pending',jsonb_build_object('method',p_method));
  
  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  VALUES(boy.uid,'Advance needs approval','Finance sent you an advance of PKR '||p_amount||'. Tap to approve.',result.id);
  
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.respond_to_direct_advance_v2(
  p_id uuid, p_decision text
) RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; result public.advance_requests; finance public.users;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy can approve advances' USING ERRCODE='42501'; END IF;
  
  IF p_decision NOT IN ('approve','decline') THEN RAISE EXCEPTION 'Decision must be approve or decline'; END IF;
  
  SELECT * INTO result FROM public.advance_requests WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Advance not found'; END IF;
  IF result.office_boy_id <> actor.uid THEN RAISE EXCEPTION 'Not your advance'; END IF;
  IF result.status <> 'awaiting_office_boy_approval' THEN RAISE EXCEPTION 'Advance is not awaiting approval'; END IF;
  
  SELECT * INTO finance FROM public.users WHERE uid=result.cleared_by;
  
  IF p_decision = 'approve' THEN
    UPDATE public.advance_requests SET status='cleared' WHERE id=p_id RETURNING * INTO result;
    
    INSERT INTO public.advance_ledger(advance_request_id,office_boy_id,office_id,entry_type,amount,actor_id)
    VALUES(result.id,result.office_boy_id,result.office_id,'credit',result.amount_requested,actor.uid);
    
    INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action)
    VALUES(result.id,result.office_boy_id,result.office_id,actor.uid,'approved_by_boy');
    
    IF finance.uid IS NOT NULL THEN
      INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
      VALUES(finance.uid,'Advance approved',actor.name||' approved the PKR '||result.amount_requested||' advance.',result.id);
    END IF;
  ELSE
    UPDATE public.advance_requests SET status='declined' WHERE id=p_id RETURNING * INTO result;
    
    INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action)
    VALUES(result.id,result.office_boy_id,result.office_id,actor.uid,'declined_by_boy');
    
    IF finance.uid IS NOT NULL THEN
      INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
      VALUES(finance.uid,'Advance declined',actor.name||' declined the PKR '||result.amount_requested||' advance.',result.id);
    END IF;
  END IF;
  
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.respond_to_direct_advance_v2(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_direct_advance_v2(uuid,text) TO authenticated;

-- Make all bank/account-detail fields OPTIONAL for Advance requests (flow_version 2)
CREATE OR REPLACE FUNCTION public.request_advance_v2(
  p_id uuid,p_purpose text,p_amount numeric,p_method text,
  p_account_name text DEFAULT NULL,p_account_details text DEFAULT NULL
) RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; result public.advance_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid = auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy can request an advance' USING ERRCODE='42501'; END IF;
  IF p_id IS NULL OR NOT public.payment_amount_valid(p_amount)
    OR length(trim(coalesce(p_purpose,''))) NOT BETWEEN 1 AND 2000
    OR p_method IS NULL OR p_method NOT IN ('cash','card')
    OR (p_method='card' AND (length(trim(coalesce(p_account_name,''))) > 120
      OR length(trim(coalesce(p_account_details,''))) > 500))
    OR (p_method='cash' AND (nullif(trim(coalesce(p_account_name,'')),'') IS NOT NULL
      OR nullif(trim(coalesce(p_account_details,'')),'') IS NOT NULL))
  THEN RAISE EXCEPTION 'Check the amount, purpose and payment details'; END IF;
  SELECT * INTO result FROM public.advance_requests WHERE id = p_id;
  IF FOUND THEN
    IF result.flow_version <> 2 OR result.office_boy_id <> actor.uid OR result.amount_requested <> p_amount
      OR result.purpose <> trim(p_purpose) OR result.payment_method_requested <> p_method
      OR result.receiver_account_name IS DISTINCT FROM nullif(trim(p_account_name),'')
      OR result.receiver_account_details IS DISTINCT FROM nullif(trim(p_account_details),'')
    THEN RAISE EXCEPTION 'Request reference already used'; END IF;
    RETURN result;
  END IF;
  INSERT INTO public.advance_requests(id,office_boy_id,office_id,amount,amount_requested,purpose,status,
    payment_method_requested,receiver_account_name,receiver_account_details,flow_version)
  VALUES(p_id,actor.uid,actor.office_id,p_amount,p_amount,trim(p_purpose),'pending',p_method,
    nullif(trim(p_account_name),''),nullif(trim(p_account_details),''),2)
  RETURNING * INTO result;
  INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action)
  VALUES(result.id,actor.uid,actor.office_id,actor.uid,'requested');
  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  SELECT uid,'Advance requested',actor.name||' requested PKR '||p_amount||'.',result.id
  FROM public.users WHERE "isActive" AND role='finance';
  RETURN result;
END $$;

-- Make all bank/account-detail fields OPTIONAL for Reimbursement requests
CREATE OR REPLACE FUNCTION public.submit_reimbursement_v2(
  p_id uuid,p_item text,p_amount numeric,p_method text,p_bill_path text DEFAULT NULL,
  p_account_name text DEFAULT NULL,p_account_details text DEFAULT NULL
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
    payment_method_wanted,receiver_account_name,receiver_account_details)
  VALUES(p_id,actor.uid,actor.office_id,trim(p_item),p_amount,p_bill_path,p_method,
    nullif(trim(p_account_name),''),nullif(trim(p_account_details),'')) RETURNING * INTO result;
  INSERT INTO public.core_payment_activity(reimbursement_id,office_boy_id,office_id,actor_id,action)
  VALUES(result.id,actor.uid,actor.office_id,actor.uid,'requested');
  INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
  SELECT uid,'Repayment requested',actor.name||' requested PKR '||p_amount||' repayment.',result.id
  FROM public.users WHERE "isActive" AND role='finance';
  RETURN result;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
