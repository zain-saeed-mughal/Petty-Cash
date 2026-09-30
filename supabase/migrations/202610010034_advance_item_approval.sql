BEGIN;

-- Add approval flow to advance_items
ALTER TABLE public.advance_items
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'approved' CHECK (status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS rejection_reason text CHECK (length(trim(rejection_reason)) BETWEEN 1 AND 2000),
  ADD CONSTRAINT advance_items_status_valid CHECK (
    (status = 'pending' AND reviewed_by IS NULL AND reviewed_at IS NULL AND rejection_reason IS NULL) OR
    (status = 'approved' AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL AND rejection_reason IS NULL) OR
    (status = 'rejected' AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL AND rejection_reason IS NOT NULL) OR
    -- To support existing records which were created before this change
    (status = 'approved' AND reviewed_by IS NULL AND reviewed_at IS NULL AND rejection_reason IS NULL)
  );

CREATE INDEX IF NOT EXISTS advance_items_status_idx ON public.advance_items(office_id, status);

-- Update log_advance_item_v2 to make new items 'pending' and NOT deduct immediately
CREATE OR REPLACE FUNCTION public.log_advance_item_v2(
  p_id uuid, p_advance_id uuid, p_item text, p_amount numeric, p_bill_path text DEFAULT NULL
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
  
  SELECT * INTO advance FROM public.advance_requests WHERE id=p_advance_id;
  IF NOT FOUND OR advance.flow_version<>2 OR advance.office_boy_id<>actor.uid
    OR advance.office_id<>actor.office_id THEN RAISE EXCEPTION 'Advance not found' USING ERRCODE='42501'; END IF;
  
  IF advance.status<>'cleared' THEN RAISE EXCEPTION 'This advance is not available for spending'; END IF;
  
  balance:=public.core_advance_balance(p_advance_id);
  -- Check if pending items + this amount exceed the balance
  DECLARE pending_amount numeric;
  BEGIN
    SELECT coalesce(sum(amount_spent), 0) INTO pending_amount FROM public.advance_items WHERE advance_request_id = p_advance_id AND status = 'pending';
    IF (p_amount + pending_amount) > balance THEN RAISE EXCEPTION 'This exceeds your remaining advance balance including pending requests'; END IF;
  END;

  INSERT INTO public.advance_items(id,advance_request_id,office_boy_id,office_id,item_description,amount_spent,bill_path,status)
  VALUES(p_id,p_advance_id,actor.uid,actor.office_id,trim(p_item),p_amount,p_bill_path,'pending') RETURNING * INTO result;
  
  INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action,detail)
  VALUES(p_advance_id,actor.uid,actor.office_id,actor.uid,'item_added',
    jsonb_build_object('item_id',result.id,'amount',p_amount,'item',result.item_description,'status','pending'));
    
  -- Notify Finance
  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  SELECT uid,'Expense pending approval',actor.name||' spent PKR '||p_amount||' from advance and needs approval.',p_advance_id
  FROM public.users WHERE "isActive" AND role='finance' AND office_id=actor.office_id;

  RETURN result;
END $$;

-- RPC to review advance item (approve/reject)
CREATE OR REPLACE FUNCTION public.review_advance_item_v2(
  p_item_id uuid, p_decision text, p_reason text DEFAULT NULL
) RETURNS public.advance_items LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; item public.advance_items; balance numeric;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance can review advance items' USING ERRCODE='42501'; END IF;
  
  IF p_decision NOT IN ('approve','reject') THEN RAISE EXCEPTION 'Invalid decision'; END IF;
  IF p_decision = 'reject' AND length(trim(coalesce(p_reason,''))) NOT BETWEEN 1 AND 2000 THEN 
    RAISE EXCEPTION 'Rejection reason is required (max 2000 chars)'; END IF;
    
  SELECT * INTO item FROM public.advance_items WHERE id=p_item_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Item not found'; END IF;
  IF item.status <> 'pending' THEN RAISE EXCEPTION 'Item is already %', item.status; END IF;
  
  IF p_decision = 'approve' THEN
    balance := public.core_advance_balance(item.advance_request_id);
    IF item.amount_spent > balance THEN RAISE EXCEPTION 'Insufficient advance balance for this approval'; END IF;
    
    UPDATE public.advance_items SET status='approved', reviewed_by=actor.uid, reviewed_at=now() WHERE id=p_item_id RETURNING * INTO item;
    
    INSERT INTO public.advance_ledger(advance_request_id,advance_item_id,office_boy_id,office_id,entry_type,amount,actor_id)
    VALUES(item.advance_request_id,item.id,item.office_boy_id,item.office_id,'spend',item.amount_spent,actor.uid);
    
    IF balance = item.amount_spent THEN 
      UPDATE public.advance_requests SET status='fully_utilized' WHERE id=item.advance_request_id; 
    END IF;
    
    INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action,detail)
    VALUES(item.advance_request_id,item.office_boy_id,item.office_id,actor.uid,'item_approved',
      jsonb_build_object('item_id',item.id,'amount',item.amount_spent,'item',item.item_description));
      
    INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
    VALUES(item.office_boy_id,'Expense approved','Finance approved your PKR '||item.amount_spent||' expense.',item.advance_request_id);
  ELSE
    UPDATE public.advance_items SET status='rejected', reviewed_by=actor.uid, reviewed_at=now(), rejection_reason=trim(p_reason) 
    WHERE id=p_item_id RETURNING * INTO item;
    
    INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action,detail)
    VALUES(item.advance_request_id,item.office_boy_id,item.office_id,actor.uid,'item_rejected',
      jsonb_build_object('item_id',item.id,'amount',item.amount_spent,'item',item.item_description,'reason',trim(p_reason)));
      
    INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
    VALUES(item.office_boy_id,'Expense rejected','Finance rejected your PKR '||item.amount_spent||' expense.',item.advance_request_id);
  END IF;

  RETURN item;
END $$;

-- RPC for Finance to directly allot advance to an office boy
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
  VALUES(p_id,boy.uid,boy.office_id,p_amount,p_amount,trim(p_purpose),'cleared',p_method,2,actor.uid,p_method,now())
  RETURNING * INTO result;
  
  INSERT INTO public.advance_ledger(advance_request_id,office_boy_id,office_id,entry_type,amount,actor_id)
  VALUES(result.id,result.office_boy_id,result.office_id,'credit',result.amount_requested,actor.uid);
  
  INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action,detail)
  VALUES(result.id,result.office_boy_id,result.office_id,actor.uid,'direct_allot',jsonb_build_object('method',p_method));
  
  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  VALUES(boy.uid,'Advance received','Finance gave you a direct advance of PKR '||p_amount||'.',result.id);
  
  RETURN result;
END $$;

COMMIT;
