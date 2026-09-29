BEGIN;

CREATE OR REPLACE FUNCTION public.payment_amount_valid(value numeric) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=public AS $$
 SELECT value IS NOT NULL AND value::text NOT IN ('NaN','Infinity','-Infinity')
  AND value>0 AND value<10000000000 AND value=round(value,2)
$$;
CREATE OR REPLACE FUNCTION public.float_balance_for(p_user uuid) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(sum(CASE entry_type WHEN 'credit' THEN amount WHEN 'hold_release' THEN amount
  ELSE -amount END),0) FROM public.float_ledger WHERE office_boy_id=p_user
$$;
REVOKE ALL ON FUNCTION public.payment_amount_valid(numeric),public.float_balance_for(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.give_advance(
 p_advance_id uuid,p_office_boy_id uuid,p_amount numeric,p_method text,p_note text DEFAULT NULL
) RETURNS public.advances LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; recipient public.users; result public.advances;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance may give advances' USING ERRCODE='42501'; END IF;
 SELECT * INTO recipient FROM public.users WHERE uid=p_office_boy_id AND "isActive" AND role='office_boy';
 IF recipient.uid IS NULL THEN RAISE EXCEPTION 'Select an active Office Boy'; END IF;
 IF p_advance_id IS NULL OR NOT public.payment_amount_valid(p_amount) OR p_method IS NULL OR p_method NOT IN ('Cash','Card')
  OR length(coalesce(p_note,''))>2000 THEN RAISE EXCEPTION 'Invalid advance details'; END IF;
 SELECT * INTO result FROM public.advances WHERE id=p_advance_id;
 IF FOUND THEN
  IF result.office_boy_id<>p_office_boy_id OR result.given_by<>actor.uid OR result.amount<>p_amount
   OR result.finance_method<>p_method OR result.note IS DISTINCT FROM nullif(trim(p_note),'') THEN
   RAISE EXCEPTION 'Advance reference already used'; END IF;
  RETURN result;
 END IF;
 INSERT INTO public.advances(id,office_boy_id,given_by,amount,finance_method,note)
 VALUES(p_advance_id,p_office_boy_id,actor.uid,p_amount,p_method,nullif(trim(p_note),'')) RETURNING * INTO result;
 INSERT INTO public.payment_activity(advance_id,office_boy_id,actor_id,action,detail)
 VALUES(result.id,recipient.uid,actor.uid,'Advance Given',jsonb_build_object('amount',p_amount,'method',p_method));
 INSERT INTO public.notifications(user_id,title,message,related_advance_id)
 VALUES(recipient.uid,'Advance awaiting confirmation','Finance gave you an advance of PKR '||p_amount||'. Confirm receipt and method.',result.id);
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.confirm_advance(p_advance_id uuid,p_received_method text)
RETURNS public.advances LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.advances;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only the Office Boy may confirm receipt' USING ERRCODE='42501'; END IF;
 IF p_received_method IS NULL OR p_received_method NOT IN ('Cash','Card') THEN RAISE EXCEPTION 'Select Cash or Card'; END IF;
 SELECT * INTO result FROM public.advances WHERE id=p_advance_id FOR UPDATE;
 IF NOT FOUND OR result.office_boy_id<>actor.uid THEN RAISE EXCEPTION 'Advance not found' USING ERRCODE='42501'; END IF;
 IF result.status<>'Awaiting Confirmation' THEN RAISE EXCEPTION 'Advance already confirmed'; END IF;
 -- Serialize receipt credits with concurrent float holds for this owner.
 PERFORM 1 FROM public.users WHERE uid=actor.uid FOR UPDATE;
 UPDATE public.advances SET status='Received',received_method=p_received_method,
  mismatch_flag=finance_method<>p_received_method,confirmed_at=now()
 WHERE id=p_advance_id RETURNING * INTO result;
 INSERT INTO public.float_ledger(office_boy_id,advance_id,entry_type,amount,actor_id)
 VALUES(actor.uid,result.id,'credit',result.amount,actor.uid);
 INSERT INTO public.payment_activity(advance_id,office_boy_id,actor_id,action,detail)
 VALUES(result.id,actor.uid,actor.uid,'Advance Received',jsonb_build_object('method',p_received_method,'mismatch',result.mismatch_flag));
 INSERT INTO public.notifications(user_id,title,message,related_advance_id)
 SELECT uid,CASE WHEN result.mismatch_flag THEN 'Advance method mismatch' ELSE 'Advance received' END,
  actor.name||' confirmed an advance of PKR '||result.amount||' by '||p_received_method||'.',result.id
 FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin');
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.submit_payment_expense(
 p_expense_id uuid,p_flow_type text,p_item text,p_amount numeric,p_reason text,p_bill_path text DEFAULT NULL
) RETURNS public.expenses LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.expenses;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy may submit expenses' USING ERRCODE='42501'; END IF;
 IF p_expense_id IS NULL OR p_flow_type IS NULL OR p_flow_type NOT IN ('float','reimbursement') OR NOT public.payment_amount_valid(p_amount)
  OR length(trim(coalesce(p_item,''))) NOT BETWEEN 1 AND 500
  OR length(trim(coalesce(p_reason,''))) NOT BETWEEN 1 AND 2000
  OR (p_bill_path IS NOT NULL AND (p_bill_path NOT LIKE actor.uid::text||'/%' OR p_bill_path LIKE '%..%'))
 THEN RAISE EXCEPTION 'Invalid expense details'; END IF;
 SELECT * INTO result FROM public.expenses WHERE id=p_expense_id;
 IF FOUND THEN
  IF result.office_boy_id<>actor.uid OR result.flow_type<>p_flow_type OR result.amount<>p_amount
   OR result.item_description<>trim(p_item) OR result.reason<>trim(p_reason)
   OR result.bill_path IS DISTINCT FROM p_bill_path THEN RAISE EXCEPTION 'Expense reference already used'; END IF;
  RETURN result;
 END IF;
 IF p_flow_type='float' THEN
  PERFORM 1 FROM public.users WHERE uid=actor.uid FOR UPDATE;
  IF public.float_balance_for(actor.uid)<p_amount THEN RAISE EXCEPTION 'Insufficient available float balance'; END IF;
 END IF;
 INSERT INTO public.expenses(id,office_boy_id,flow_type,item_description,amount,reason,bill_path)
 VALUES(p_expense_id,actor.uid,p_flow_type,trim(p_item),p_amount,trim(p_reason),p_bill_path) RETURNING * INTO result;
 IF p_flow_type='float' THEN
  INSERT INTO public.float_ledger(office_boy_id,expense_id,entry_type,amount,actor_id)
  VALUES(actor.uid,result.id,'hold',p_amount,actor.uid);
 END IF;
 INSERT INTO public.payment_activity(expense_id,office_boy_id,actor_id,action,detail)
 VALUES(result.id,actor.uid,actor.uid,'Expense Submitted',jsonb_build_object('flow_type',p_flow_type,'amount',p_amount));
 INSERT INTO public.notifications(user_id,title,message,related_expense_id)
 SELECT uid,'New '||CASE WHEN p_flow_type='float' THEN 'float expense' ELSE 'reimbursement' END,
  actor.name||' submitted PKR '||p_amount||' for review.',result.id
 FROM public.users WHERE "isActive" AND role='finance';
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.review_payment_expense(p_expense_id uuid,p_decision text,p_reason text DEFAULT NULL)
RETURNS public.expenses LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.expenses; next_status text;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance may review expenses' USING ERRCODE='42501'; END IF;
 IF p_decision IS NULL OR p_decision NOT IN ('Approve','Reject') THEN RAISE EXCEPTION 'Invalid review decision'; END IF;
 IF p_decision='Reject' AND length(trim(coalesce(p_reason,''))) NOT BETWEEN 1 AND 2000 THEN
  RAISE EXCEPTION 'A rejection reason is required'; END IF;
 SELECT * INTO result FROM public.expenses WHERE id=p_expense_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Expense not found'; END IF;
 IF result.status<>'Pending' THEN RAISE EXCEPTION 'Expense is no longer pending'; END IF;
 next_status:=CASE WHEN p_decision='Approve' THEN 'Approved' ELSE 'Rejected' END;
 UPDATE public.expenses SET status=next_status,reviewed_by=actor.uid,reviewed_at=now(),updated_at=now(),
  rejection_reason=CASE WHEN next_status='Rejected' THEN trim(p_reason) END
 WHERE id=p_expense_id RETURNING * INTO result;
 IF result.flow_type='float' AND next_status='Approved' THEN
  INSERT INTO public.float_ledger(office_boy_id,expense_id,entry_type,amount,actor_id)
  VALUES(result.office_boy_id,result.id,'hold_release',result.amount,actor.uid),
        (result.office_boy_id,result.id,'deduction',result.amount,actor.uid);
 END IF;
 INSERT INTO public.payment_activity(expense_id,office_boy_id,actor_id,action,detail)
 VALUES(result.id,result.office_boy_id,actor.uid,'Expense '||next_status,
  jsonb_build_object('reason',result.rejection_reason));
 INSERT INTO public.notifications(user_id,title,message,related_expense_id)
 VALUES(result.office_boy_id,'Expense '||next_status,
  CASE WHEN next_status='Rejected' THEN 'Your expense was rejected: '||result.rejection_reason
   ELSE 'Your expense was approved.' END,result.id);
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.acknowledge_payment_rejection(p_expense_id uuid)
RETURNS public.expenses LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.expenses;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only the Office Boy may acknowledge a rejection' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.expenses WHERE id=p_expense_id FOR UPDATE;
 IF NOT FOUND OR result.office_boy_id<>actor.uid THEN RAISE EXCEPTION 'Expense not found' USING ERRCODE='42501'; END IF;
 IF result.status<>'Rejected' THEN RAISE EXCEPTION 'Only rejected expenses can be acknowledged'; END IF;
 UPDATE public.expenses SET status='Rejection Acknowledged',rejection_acknowledged_at=now(),updated_at=now()
 WHERE id=p_expense_id RETURNING * INTO result;
 IF result.flow_type='float' THEN
  INSERT INTO public.float_ledger(office_boy_id,expense_id,entry_type,amount,actor_id)
  VALUES(actor.uid,result.id,'hold_release',result.amount,actor.uid);
 END IF;
 INSERT INTO public.payment_activity(expense_id,office_boy_id,actor_id,action)
 VALUES(result.id,actor.uid,actor.uid,'Rejection Acknowledged');
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.clear_reimbursement_payment(p_expense_id uuid,p_method text)
RETURNS public.expenses LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.expenses;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance may clear payments' USING ERRCODE='42501'; END IF;
 IF p_method IS NULL OR p_method NOT IN ('Cash','Card') THEN RAISE EXCEPTION 'Select Cash or Card'; END IF;
 SELECT * INTO result FROM public.expenses WHERE id=p_expense_id FOR UPDATE;
 IF NOT FOUND OR result.flow_type<>'reimbursement' OR result.status<>'Approved' THEN
  RAISE EXCEPTION 'Only approved reimbursements can be cleared'; END IF;
 UPDATE public.expenses SET status='Payment Cleared',payment_method_finance=p_method,cleared_at=now(),updated_at=now()
 WHERE id=p_expense_id RETURNING * INTO result;
 INSERT INTO public.payment_activity(expense_id,office_boy_id,actor_id,action,detail)
 VALUES(result.id,result.office_boy_id,actor.uid,'Payment Cleared',jsonb_build_object('method',p_method));
 INSERT INTO public.notifications(user_id,title,message,related_expense_id)
 VALUES(result.office_boy_id,'Reimbursement payment cleared','Confirm receipt of your reimbursement and payment method.',result.id);
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.confirm_reimbursement_payment(p_expense_id uuid,p_received_method text)
RETURNS public.expenses LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.expenses;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only the Office Boy may confirm payment' USING ERRCODE='42501'; END IF;
 IF p_received_method IS NULL OR p_received_method NOT IN ('Cash','Card') THEN RAISE EXCEPTION 'Select Cash or Card'; END IF;
 SELECT * INTO result FROM public.expenses WHERE id=p_expense_id FOR UPDATE;
 IF NOT FOUND OR result.office_boy_id<>actor.uid THEN RAISE EXCEPTION 'Expense not found' USING ERRCODE='42501'; END IF;
 IF result.flow_type<>'reimbursement' OR result.status<>'Payment Cleared' THEN
  RAISE EXCEPTION 'Payment is not awaiting confirmation'; END IF;
 UPDATE public.expenses SET status='Paid',payment_method_received=p_received_method,
  mismatch_flag=payment_method_finance<>p_received_method,paid_at=now(),updated_at=now()
 WHERE id=p_expense_id RETURNING * INTO result;
 INSERT INTO public.payment_activity(expense_id,office_boy_id,actor_id,action,detail)
 VALUES(result.id,actor.uid,actor.uid,'Payment Received',
  jsonb_build_object('method',p_received_method,'mismatch',result.mismatch_flag));
 INSERT INTO public.notifications(user_id,title,message,related_expense_id)
 SELECT uid,CASE WHEN result.mismatch_flag THEN 'Reimbursement method mismatch' ELSE 'Reimbursement received' END,
  actor.name||' confirmed receipt of PKR '||result.amount||' by '||p_received_method||'.',result.id
 FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin');
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.payment_overview(p_from timestamptz DEFAULT NULL,p_to timestamptz DEFAULT NULL)
RETURNS TABLE(office_boy_id uuid,office_boy_name text,total_received numeric,total_spent numeric,on_hold numeric,
 available_balance numeric,total_reimbursed numeric,advance_count bigint,expense_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE role_name text;
BEGIN
 role_name:=public.current_user_role();
 IF role_name IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 IF p_from IS NOT NULL AND p_to IS NOT NULL AND p_from>p_to THEN RAISE EXCEPTION 'Invalid date range'; END IF;
 RETURN QUERY
 WITH period_movement AS (
  SELECT l.office_boy_id,
   sum(l.amount) FILTER(WHERE l.entry_type='credit') received,
   sum(l.amount) FILTER(WHERE l.entry_type='deduction') spent
  FROM public.float_ledger l WHERE (p_from IS NULL OR l.created_at>=p_from)
   AND (p_to IS NULL OR l.created_at<p_to) GROUP BY l.office_boy_id
 ), current_movement AS (
  SELECT l.office_boy_id,
   coalesce(sum(CASE l.entry_type WHEN 'credit' THEN l.amount WHEN 'hold_release' THEN l.amount ELSE -l.amount END),0) balance,
   coalesce(sum(l.amount) FILTER(WHERE l.entry_type='hold'),0)
    -coalesce(sum(l.amount) FILTER(WHERE l.entry_type='hold_release'),0) held
  FROM public.float_ledger l GROUP BY l.office_boy_id
 ), reimbursement AS (
  SELECT e.office_boy_id,sum(e.amount) FILTER(WHERE e.status='Paid') reimbursed,
   count(*) expense_total FROM public.expenses e
  WHERE (p_from IS NULL OR e.created_at>=p_from) AND (p_to IS NULL OR e.created_at<p_to)
  GROUP BY e.office_boy_id
 ), advance_totals AS (
  SELECT a.office_boy_id,count(*) advance_total FROM public.advances a
  WHERE (p_from IS NULL OR a.created_at>=p_from) AND (p_to IS NULL OR a.created_at<p_to)
  GROUP BY a.office_boy_id
 )
 SELECT u.uid,u.name,coalesce(m.received,0),coalesce(m.spent,0),coalesce(c.held,0),
  coalesce(c.balance,0),
  coalesce(r.reimbursed,0),coalesce(a.advance_total,0),coalesce(r.expense_total,0)
 FROM public.users u LEFT JOIN period_movement m ON m.office_boy_id=u.uid
 LEFT JOIN current_movement c ON c.office_boy_id=u.uid
 LEFT JOIN reimbursement r ON r.office_boy_id=u.uid
 LEFT JOIN advance_totals a ON a.office_boy_id=u.uid
 WHERE u.role='office_boy' AND (role_name IN ('finance','admin','super_admin') OR u.uid=auth.uid())
 ORDER BY u.name;
END $$;

DO $$ DECLARE signature regprocedure; BEGIN
 FOR signature IN SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN
 ('give_advance','confirm_advance','submit_payment_expense','review_payment_expense',
  'acknowledge_payment_rejection','clear_reimbursement_payment','confirm_reimbursement_payment','payment_overview')
 LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',signature);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',signature); END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
