-- Run in the Supabase SQL Editor only after migrations 024-026 are applied.
-- Uses existing active Finance and Office Boy identities. Everything, including
-- notifications and ledger movements, is rolled back. No sample data remains.
BEGIN;
DO $$
DECLARE
 finance_id uuid;
 office_id uuid;
 v_advance_id uuid := gen_random_uuid();
 float_rejected_id uuid := gen_random_uuid();
 float_approved_id uuid := gen_random_uuid();
 reimbursement_id uuid := gen_random_uuid();
 requested_advance_id uuid := gen_random_uuid();
 requested_expense_id uuid := gen_random_uuid();
 issued_advance_id uuid;
 row_request public.advance_requests;
 row_advance public.advances;
 row_expense public.expenses;
 balance numeric;
 held numeric;
BEGIN
 SELECT uid INTO finance_id FROM public.users WHERE role='finance' AND "isActive" ORDER BY uid LIMIT 1;
 SELECT uid INTO office_id FROM public.users WHERE role='office_boy' AND "isActive" ORDER BY uid LIMIT 1;
 IF finance_id IS NULL OR office_id IS NULL THEN
  RAISE EXCEPTION 'An active Finance and Office Boy account are required';
 END IF;

 PERFORM set_config('request.jwt.claim.sub',finance_id::text,true);
 SELECT * INTO row_advance FROM public.give_advance(v_advance_id,office_id,100,'Card','Rollback-only verification');
 IF row_advance.status<>'Awaiting Confirmation' THEN RAISE EXCEPTION 'Advance not awaiting confirmation'; END IF;
 PERFORM set_config('request.jwt.claim.sub',office_id::text,true);
 SELECT * INTO row_advance FROM public.confirm_advance(v_advance_id,'Cash');
 IF row_advance.status<>'Received' OR NOT row_advance.mismatch_flag THEN RAISE EXCEPTION 'Advance confirmation mismatch failed'; END IF;
 SELECT available_balance INTO balance FROM public.payment_overview() WHERE office_boy_id=office_id;
 -- Existing real float may be nonzero; verify the new credit rather than its absolute total.
 IF NOT EXISTS(SELECT 1 FROM public.float_ledger l WHERE l.advance_id=v_advance_id AND l.entry_type='credit' AND l.amount=100) THEN
  RAISE EXCEPTION 'Advance credit missing';
 END IF;

 SELECT * INTO row_request FROM public.request_advance(requested_advance_id,35,'Rollback request');
 IF row_request.status<>'Pending' THEN RAISE EXCEPTION 'Advance request was not submitted'; END IF;
 PERFORM set_config('request.jwt.claim.sub',finance_id::text,true);
 SELECT * INTO row_request FROM public.review_advance_request(requested_advance_id,'Approve','Cash',NULL);
 issued_advance_id:=row_request.advance_id;
 IF issued_advance_id IS NULL THEN RAISE EXCEPTION 'Advance request was not issued'; END IF;
 PERFORM set_config('request.jwt.claim.sub',office_id::text,true);
 PERFORM public.confirm_advance(issued_advance_id,'Cash');
 IF (SELECT available FROM public.advance_balance_overview() WHERE advance_id=issued_advance_id)<>35 THEN
  RAISE EXCEPTION 'Requested advance balance was not credited'; END IF;
 PERFORM public.submit_payment_expense(requested_expense_id,'float','Rollback purchase',10,'Verification',NULL,issued_advance_id);
 PERFORM set_config('request.jwt.claim.sub',finance_id::text,true);
 PERFORM public.review_payment_expense(requested_expense_id,'Approve',NULL);
 IF (SELECT available FROM public.advance_balance_overview() WHERE advance_id=issued_advance_id)<>25 THEN
  RAISE EXCEPTION 'Requested advance purchase was not deducted'; END IF;
 PERFORM set_config('request.jwt.claim.sub',office_id::text,true);

 SELECT * INTO row_expense FROM public.submit_payment_expense(float_rejected_id,'float','Rollback test',10,'Verification',NULL,v_advance_id);
 SELECT on_hold INTO held FROM public.payment_overview() WHERE office_boy_id=office_id;
 IF held<10 THEN RAISE EXCEPTION 'Float hold missing'; END IF;
 PERFORM set_config('request.jwt.claim.sub',finance_id::text,true);
 SELECT * INTO row_expense FROM public.review_payment_expense(float_rejected_id,'Reject','Rollback verification');
 IF row_expense.status<>'Rejected' THEN RAISE EXCEPTION 'Float rejection failed'; END IF;
 PERFORM set_config('request.jwt.claim.sub',office_id::text,true);
 SELECT * INTO row_expense FROM public.acknowledge_payment_rejection(float_rejected_id);
 IF row_expense.status<>'Rejection Acknowledged' THEN RAISE EXCEPTION 'Rejection acknowledgement failed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.float_ledger WHERE expense_id=float_rejected_id AND entry_type='hold_release') THEN
  RAISE EXCEPTION 'Rejected hold not released';
 END IF;

 PERFORM public.submit_payment_expense(float_approved_id,'float','Rollback test',20,'Verification',NULL,v_advance_id);
 PERFORM set_config('request.jwt.claim.sub',finance_id::text,true);
 SELECT * INTO row_expense FROM public.review_payment_expense(float_approved_id,'Approve',NULL);
 IF row_expense.status<>'Approved' OR NOT EXISTS(
   SELECT 1 FROM public.float_ledger WHERE expense_id=float_approved_id AND entry_type='deduction' AND amount=20
 ) THEN RAISE EXCEPTION 'Float approval/deduction failed'; END IF;

 PERFORM set_config('request.jwt.claim.sub',office_id::text,true);
 PERFORM public.submit_payment_expense(reimbursement_id,'reimbursement','Rollback test',5,'Verification',NULL);
 PERFORM set_config('request.jwt.claim.sub',finance_id::text,true);
 PERFORM public.review_payment_expense(reimbursement_id,'Approve',NULL);
 PERFORM public.clear_reimbursement_payment(reimbursement_id,'Card');
 PERFORM set_config('request.jwt.claim.sub',office_id::text,true);
 SELECT * INTO row_expense FROM public.confirm_reimbursement_payment(reimbursement_id,'Cash');
 IF row_expense.status<>'Paid' OR NOT row_expense.mismatch_flag THEN
  RAISE EXCEPTION 'Reimbursement confirmation/mismatch failed';
 END IF;
 IF (SELECT count(*) FROM public.payment_activity WHERE expense_id=reimbursement_id)<>4 THEN
  RAISE EXCEPTION 'Reimbursement timeline incomplete';
 END IF;
END $$;
ROLLBACK;
SELECT 'All payment flows passed; transaction rolled back' AS result;
