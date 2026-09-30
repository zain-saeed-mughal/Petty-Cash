-- Read-only post-upgrade check. Every *_ready and *_rls value should be true.
SELECT
  to_regclass('public.offices') IS NOT NULL AS offices_ready,
  to_regclass('public.advance_items') IS NOT NULL AS advance_items_ready,
  to_regclass('public.advance_ledger') IS NOT NULL AS advance_ledger_ready,
  to_regclass('public.reimbursement_requests') IS NOT NULL AS reimbursements_ready,
  to_regclass('public.core_payment_activity') IS NOT NULL AS activity_ready,
  to_regprocedure('public.request_advance_v2(uuid,text,numeric,text,text,text)') IS NOT NULL AS request_advance_ready,
  to_regprocedure('public.clear_advance_request_v2(uuid,text,text)') IS NOT NULL AS clear_advance_ready,
  to_regprocedure('public.log_advance_item_v2(uuid,uuid,text,numeric,text)') IS NOT NULL AS log_item_ready,
  to_regprocedure('public.submit_reimbursement_v2(uuid,text,numeric,text,text,text,text)') IS NOT NULL AS submit_repayment_ready,
  to_regprocedure('public.review_reimbursement_v2(uuid,text,text)') IS NOT NULL AS review_repayment_ready,
  to_regprocedure('public.mark_reimbursement_paid_v2(uuid,text)') IS NOT NULL AS mark_paid_ready,
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.offices'::regclass) AS offices_rls,
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.advance_items'::regclass) AS advance_items_rls,
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.advance_ledger'::regclass) AS advance_ledger_rls,
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.reimbursement_requests'::regclass) AS reimbursements_rls;

-- Existing users must have an assigned office after the upgrade.
SELECT count(*) AS users_without_office FROM public.users WHERE office_id IS NULL;

-- Legacy unsolicited payment function must not be callable by normal clients.
SELECT NOT has_function_privilege('authenticated', p.oid, 'EXECUTE') AS old_give_advance_blocked
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='give_advance';
