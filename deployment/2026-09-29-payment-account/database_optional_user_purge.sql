BEGIN;

-- Permit immutable-ledger deletion only inside the privileged purge RPC.
CREATE OR REPLACE FUNCTION public.prevent_payment_history_change() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF auth.role()='service_role'
  AND current_setting('app.allow_account_data_purge',true)='on' THEN
  RETURN OLD;
 END IF;
 RAISE EXCEPTION 'Payment history cannot be changed or deleted' USING ERRCODE='42501';
END $$;

CREATE OR REPLACE FUNCTION public.delete_office_boy_data(p_uid uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
 request_ids text[];
 advance_request_ids uuid[];
 advance_ids uuid[];
 expense_ids uuid[];
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' THEN
  RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
 END IF;

 PERFORM 1 FROM public.users WHERE uid=p_uid AND role='office_boy' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Office Boy account not found'; END IF;
 IF EXISTS(SELECT 1 FROM public.advances WHERE given_by=p_uid AND office_boy_id<>p_uid)
  OR EXISTS(SELECT 1 FROM public.expenses WHERE reviewed_by=p_uid AND office_boy_id<>p_uid)
  OR EXISTS(SELECT 1 FROM public.advance_requests WHERE decided_by=p_uid AND office_boy_id<>p_uid)
  OR EXISTS(SELECT 1 FROM public.float_ledger WHERE actor_id=p_uid AND office_boy_id<>p_uid)
  OR EXISTS(SELECT 1 FROM public.payment_activity WHERE actor_id=p_uid AND office_boy_id<>p_uid) THEN
  RAISE EXCEPTION 'This account is referenced by another user financial history';
 END IF;
 UPDATE public.users SET "isActive"=false WHERE uid=p_uid;

 SELECT coalesce(array_agg(id),ARRAY[]::text[]) INTO request_ids
  FROM public.requests WHERE "requestedBy"=p_uid;
 SELECT coalesce(array_agg(id),ARRAY[]::uuid[]) INTO advance_request_ids
  FROM public.advance_requests WHERE office_boy_id=p_uid;
 SELECT coalesce(array_agg(id),ARRAY[]::uuid[]) INTO advance_ids
  FROM public.advances WHERE office_boy_id=p_uid;
 SELECT coalesce(array_agg(id),ARRAY[]::uuid[]) INTO expense_ids
  FROM public.expenses WHERE office_boy_id=p_uid;

 DELETE FROM public.notifications
  WHERE user_id=p_uid
   OR related_request_id=ANY(request_ids)
   OR related_advance_request_id=ANY(advance_request_ids)
   OR related_advance_id=ANY(advance_ids)
   OR related_expense_id=ANY(expense_ids);
 DELETE FROM public.device_tokens WHERE user_id=p_uid;
 DELETE FROM public.request_deletion_audit WHERE request_id=ANY(request_ids);
 DELETE FROM public.requests WHERE "requestedBy"=p_uid;
 DELETE FROM public.advance_requests WHERE office_boy_id=p_uid;

 PERFORM set_config('app.allow_account_data_purge','on',true);
 DELETE FROM public.payment_activity WHERE office_boy_id=p_uid;
 DELETE FROM public.float_ledger WHERE office_boy_id=p_uid;
 DELETE FROM public.expenses WHERE office_boy_id=p_uid;
 DELETE FROM public.advances WHERE office_boy_id=p_uid;
END $$;

REVOKE ALL ON FUNCTION public.delete_office_boy_data(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.delete_office_boy_data(uuid) TO service_role;

COMMIT;
BEGIN;

-- The previous purge only collected requests still present in public.requests.
-- Include snapshots of requests that a super-admin deleted earlier, so their
-- audit rows and related notifications are removed with the Office Boy.
CREATE OR REPLACE FUNCTION public.delete_office_boy_data(p_uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  request_ids text[];
  advance_request_ids uuid[];
  advance_ids uuid[];
  expense_ids uuid[];
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  PERFORM 1 FROM public.users
  WHERE uid = p_uid AND role = 'office_boy' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Office Boy account not found'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.advances
    WHERE given_by = p_uid AND office_boy_id <> p_uid
  ) OR EXISTS (
    SELECT 1 FROM public.expenses
    WHERE reviewed_by = p_uid AND office_boy_id <> p_uid
  ) OR EXISTS (
    SELECT 1 FROM public.advance_requests
    WHERE decided_by = p_uid AND office_boy_id <> p_uid
  ) OR EXISTS (
    SELECT 1 FROM public.float_ledger
    WHERE actor_id = p_uid AND office_boy_id <> p_uid
  ) OR EXISTS (
    SELECT 1 FROM public.payment_activity
    WHERE actor_id = p_uid AND office_boy_id <> p_uid
  ) THEN
    RAISE EXCEPTION 'This account is referenced by another user financial history';
  END IF;

  UPDATE public.users SET "isActive" = false WHERE uid = p_uid;

  SELECT coalesce(array_agg(id), ARRAY[]::text[]) INTO request_ids
  FROM (
    SELECT id FROM public.requests WHERE "requestedBy" = p_uid
    UNION
    SELECT request_id AS id FROM public.request_deletion_audit
    WHERE request_snapshot->>'requestedBy' = p_uid::text
  ) own_requests;
  SELECT coalesce(array_agg(id), ARRAY[]::uuid[]) INTO advance_request_ids
  FROM public.advance_requests WHERE office_boy_id = p_uid;
  SELECT coalesce(array_agg(id), ARRAY[]::uuid[]) INTO advance_ids
  FROM public.advances WHERE office_boy_id = p_uid;
  SELECT coalesce(array_agg(id), ARRAY[]::uuid[]) INTO expense_ids
  FROM public.expenses WHERE office_boy_id = p_uid;

  DELETE FROM public.notifications
  WHERE user_id = p_uid
    OR related_request_id = ANY(request_ids)
    OR related_advance_request_id = ANY(advance_request_ids)
    OR related_advance_id = ANY(advance_ids)
    OR related_expense_id = ANY(expense_ids);
  DELETE FROM public.device_tokens WHERE user_id = p_uid;
  DELETE FROM public.request_deletion_audit
  WHERE request_id = ANY(request_ids);
  DELETE FROM public.requests WHERE "requestedBy" = p_uid;
  DELETE FROM public.advance_requests WHERE office_boy_id = p_uid;

  PERFORM set_config('app.allow_account_data_purge', 'on', true);
  DELETE FROM public.payment_activity WHERE office_boy_id = p_uid;
  DELETE FROM public.float_ledger WHERE office_boy_id = p_uid;
  DELETE FROM public.expenses WHERE office_boy_id = p_uid;
  DELETE FROM public.advances WHERE office_boy_id = p_uid;
END
$$;

REVOKE ALL ON FUNCTION public.delete_office_boy_data(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_office_boy_data(uuid)
  TO service_role;

COMMIT;

