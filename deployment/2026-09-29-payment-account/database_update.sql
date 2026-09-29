BEGIN;

-- Office Boys may ask Finance for money before spending. Approval creates an
-- advance; receipt confirmation is still required before it becomes spendable.
CREATE TABLE IF NOT EXISTS public.advance_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 amount numeric(12,2) NOT NULL CHECK (amount>0 AND amount::text NOT IN ('NaN','Infinity','-Infinity')),
 purpose text NOT NULL CHECK (length(trim(purpose)) BETWEEN 1 AND 2000),
 status text NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending','Approved','Rejected')),
 rejection_reason text CHECK (length(trim(rejection_reason)) BETWEEN 1 AND 2000),
 decided_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
 decided_at timestamptz,
 advance_id uuid UNIQUE REFERENCES public.advances(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT advance_request_decision_valid CHECK (
  (status='Pending' AND decided_by IS NULL AND decided_at IS NULL AND advance_id IS NULL AND rejection_reason IS NULL)
  OR (status='Approved' AND decided_by IS NOT NULL AND decided_at IS NOT NULL AND advance_id IS NOT NULL AND rejection_reason IS NULL)
  OR (status='Rejected' AND decided_by IS NOT NULL AND decided_at IS NOT NULL AND advance_id IS NULL AND rejection_reason IS NOT NULL)
 )
);
CREATE INDEX IF NOT EXISTS advance_requests_owner_date_idx ON public.advance_requests(office_boy_id,created_at DESC);
CREATE INDEX IF NOT EXISTS advance_requests_queue_idx ON public.advance_requests(status,created_at DESC);

ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS advance_id uuid REFERENCES public.advances(id) ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS expenses_advance_idx ON public.expenses(advance_id,created_at DESC);
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS related_advance_request_id uuid REFERENCES public.advance_requests(id) ON DELETE SET NULL;
GRANT SELECT(related_advance_request_id) ON public.notifications TO authenticated;

ALTER TABLE public.advance_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.advance_requests FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.advance_requests TO authenticated;
GRANT ALL ON public.advance_requests TO service_role;
DROP POLICY IF EXISTS advance_requests_read ON public.advance_requests;
CREATE POLICY advance_requests_read ON public.advance_requests FOR SELECT TO authenticated USING (
 public.current_user_role() IS NOT NULL AND
 (office_boy_id=auth.uid() OR public.current_user_role() IN ('finance','admin','super_admin'))
);

CREATE OR REPLACE FUNCTION public.advance_balance_for(p_advance_id uuid) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT CASE WHEN a.status='Received' THEN a.amount - coalesce((
  SELECT sum(CASE l.entry_type WHEN 'hold_release' THEN -l.amount ELSE l.amount END)
  FROM public.float_ledger l JOIN public.expenses e ON e.id=l.expense_id
  WHERE e.advance_id=a.id AND l.entry_type IN ('hold','hold_release','deduction')
 ),0) ELSE 0 END
 FROM public.advances a WHERE a.id=p_advance_id
$$;
REVOKE ALL ON FUNCTION public.advance_balance_for(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.request_advance(p_request_id uuid,p_amount numeric,p_purpose text)
RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.advance_requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy may request an advance' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR NOT public.payment_amount_valid(p_amount)
  OR length(trim(coalesce(p_purpose,''))) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Enter a valid amount and purpose'; END IF;
 SELECT * INTO result FROM public.advance_requests WHERE id=p_request_id;
 IF FOUND THEN
  IF result.office_boy_id<>actor.uid OR result.amount<>p_amount OR result.purpose<>trim(p_purpose) THEN
   RAISE EXCEPTION 'Advance request reference already used'; END IF;
  RETURN result;
 END IF;
 INSERT INTO public.advance_requests(id,office_boy_id,amount,purpose)
 VALUES(p_request_id,actor.uid,p_amount,trim(p_purpose)) RETURNING * INTO result;
 INSERT INTO public.notifications(user_id,title,message,related_advance_request_id)
 SELECT uid,'Advance requested',actor.name||' requested PKR '||p_amount||' in advance.',result.id
 FROM public.users WHERE "isActive" AND role='finance';
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.review_advance_request(
 p_request_id uuid,p_decision text,p_method text DEFAULT NULL,p_reason text DEFAULT NULL
) RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.advance_requests; issued public.advances;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance may review advance requests' USING ERRCODE='42501'; END IF;
 IF p_decision IS NULL OR p_decision NOT IN ('Approve','Reject') THEN RAISE EXCEPTION 'Select Approve or Reject'; END IF;
 IF p_decision='Approve' AND (p_method IS NULL OR p_method NOT IN ('Cash','Card')) THEN
  RAISE EXCEPTION 'Select Cash or Card for the advance'; END IF;
 IF p_decision='Reject' AND length(trim(coalesce(p_reason,''))) NOT BETWEEN 1 AND 2000 THEN
  RAISE EXCEPTION 'A rejection reason is required'; END IF;
 SELECT * INTO result FROM public.advance_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Advance request not found'; END IF;
 IF result.status<>'Pending' THEN RAISE EXCEPTION 'Advance request is no longer pending'; END IF;
 IF p_decision='Approve' THEN
  SELECT * INTO issued FROM public.give_advance(gen_random_uuid(),result.office_boy_id,result.amount,p_method,result.purpose);
  UPDATE public.advance_requests SET status='Approved',decided_by=actor.uid,decided_at=now(),advance_id=issued.id
   WHERE id=result.id RETURNING * INTO result;
 ELSE
  UPDATE public.advance_requests SET status='Rejected',rejection_reason=trim(p_reason),decided_by=actor.uid,decided_at=now()
   WHERE id=result.id RETURNING * INTO result;
  INSERT INTO public.notifications(user_id,title,message,related_advance_request_id)
  VALUES(result.office_boy_id,'Advance request rejected','Your advance request was rejected: '||result.rejection_reason,result.id);
 END IF;
 RETURN result;
END $$;

-- Replaces the six-argument RPC. A float expense must identify the advance
-- whose money was used; older unallocated expenses remain visible as history.
DROP FUNCTION IF EXISTS public.submit_payment_expense(uuid,text,text,numeric,text,text);
CREATE OR REPLACE FUNCTION public.submit_payment_expense(
 p_expense_id uuid,p_flow_type text,p_item text,p_amount numeric,p_reason text,
 p_bill_path text DEFAULT NULL,p_advance_id uuid DEFAULT NULL
) RETURNS public.expenses LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.expenses; selected_advance public.advances;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy may submit expenses' USING ERRCODE='42501'; END IF;
 IF p_expense_id IS NULL OR p_flow_type IS NULL OR p_flow_type NOT IN ('float','reimbursement') OR NOT public.payment_amount_valid(p_amount)
  OR length(trim(coalesce(p_item,''))) NOT BETWEEN 1 AND 500
  OR length(trim(coalesce(p_reason,''))) NOT BETWEEN 1 AND 2000
  OR (p_bill_path IS NOT NULL AND (p_bill_path NOT LIKE actor.uid::text||'/%' OR p_bill_path LIKE '%..%'))
  OR (p_flow_type='float' AND p_advance_id IS NULL)
  OR (p_flow_type='reimbursement' AND p_advance_id IS NOT NULL)
 THEN RAISE EXCEPTION 'Invalid expense details'; END IF;
 SELECT * INTO result FROM public.expenses WHERE id=p_expense_id;
 IF FOUND THEN
  IF result.office_boy_id<>actor.uid OR result.flow_type<>p_flow_type OR result.amount<>p_amount
   OR result.item_description<>trim(p_item) OR result.reason<>trim(p_reason)
   OR result.bill_path IS DISTINCT FROM p_bill_path OR result.advance_id IS DISTINCT FROM p_advance_id
  THEN RAISE EXCEPTION 'Expense reference already used'; END IF;
  RETURN result;
 END IF;
 IF p_flow_type='float' THEN
  PERFORM 1 FROM public.users WHERE uid=actor.uid FOR UPDATE;
  SELECT * INTO selected_advance FROM public.advances WHERE id=p_advance_id AND office_boy_id=actor.uid AND status='Received';
  IF NOT FOUND THEN RAISE EXCEPTION 'Select one of your received advances'; END IF;
  IF public.float_balance_for(actor.uid)<p_amount OR public.advance_balance_for(p_advance_id)<p_amount THEN
   RAISE EXCEPTION 'Insufficient available advance balance'; END IF;
 END IF;
 INSERT INTO public.expenses(id,office_boy_id,flow_type,item_description,amount,reason,bill_path,advance_id)
 VALUES(p_expense_id,actor.uid,p_flow_type,trim(p_item),p_amount,trim(p_reason),p_bill_path,p_advance_id) RETURNING * INTO result;
 IF p_flow_type='float' THEN
  INSERT INTO public.float_ledger(office_boy_id,expense_id,entry_type,amount,actor_id)
  VALUES(actor.uid,result.id,'hold',p_amount,actor.uid);
 END IF;
 INSERT INTO public.payment_activity(expense_id,office_boy_id,actor_id,action,detail)
 VALUES(result.id,actor.uid,actor.uid,'Expense Submitted',
  jsonb_build_object('flow_type',p_flow_type,'amount',p_amount,'advance_id',p_advance_id));
 INSERT INTO public.notifications(user_id,title,message,related_expense_id)
 SELECT uid,'New '||CASE WHEN p_flow_type='float' THEN 'advance expense' ELSE 'pocket expense' END,
  actor.name||' submitted PKR '||p_amount||' for review.',result.id
 FROM public.users WHERE "isActive" AND role='finance';
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.advance_balance_overview()
RETURNS TABLE(advance_id uuid,office_boy_id uuid,amount numeric,spent numeric,on_hold numeric,available numeric,expense_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE role_name text;
BEGIN
 role_name:=public.current_user_role();
 IF role_name IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 RETURN QUERY
 SELECT a.id,a.office_boy_id,a.amount,
  coalesce(sum(l.amount) FILTER(WHERE l.entry_type='deduction'),0),
  coalesce(sum(l.amount) FILTER(WHERE l.entry_type='hold'),0)
   -coalesce(sum(l.amount) FILTER(WHERE l.entry_type='hold_release'),0),
  public.advance_balance_for(a.id),
  count(DISTINCT e.id)
 FROM public.advances a LEFT JOIN public.expenses e ON e.advance_id=a.id
 LEFT JOIN public.float_ledger l ON l.expense_id=e.id
 WHERE a.status='Received' AND (role_name IN ('finance','admin','super_admin') OR a.office_boy_id=auth.uid())
 GROUP BY a.id,a.office_boy_id,a.amount,a.created_at
 ORDER BY a.created_at DESC;
END $$;

REVOKE ALL ON FUNCTION public.request_advance(uuid,numeric,text),
 public.review_advance_request(uuid,text,text,text),
 public.submit_payment_expense(uuid,text,text,numeric,text,text,uuid),
 public.advance_balance_overview() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.request_advance(uuid,numeric,text),
 public.review_advance_request(uuid,text,text,text),
 public.submit_payment_expense(uuid,text,text,numeric,text,text,uuid),
 public.advance_balance_overview() TO authenticated;

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') AND NOT EXISTS(
  SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='advance_requests'
 ) THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.advance_requests; END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
