-- Install on the existing database. Installation itself deletes no data.
BEGIN;

-- Keep receipt paths until Storage cleanup succeeds, including after a retry.
CREATE TABLE IF NOT EXISTS public.account_deletion_receipts (
  account_uid uuid NOT NULL,
  path text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_uid, path)
);
ALTER TABLE public.account_deletion_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_deletion_receipts FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.account_deletion_receipts TO service_role;

DROP FUNCTION IF EXISTS public.assert_staff_account_deletable(uuid);

-- Called only by manage-user with the service key, after Super Admin auth.
-- A referenced payment is removed as a unit, so no orphaned ledger/spend remains.
CREATE OR REPLACE FUNCTION public.delete_user_financial_data(p_uid uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  account public.users;
  request_ids text[] := ARRAY[]::text[];
  core_advance_ids uuid[] := ARRAY[]::uuid[];
  legacy_advance_ids uuid[] := ARRAY[]::uuid[];
  expense_ids uuid[] := ARRAY[]::uuid[];
  reimbursement_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;
  IF p_uid IS NULL THEN RAISE EXCEPTION 'Account id is required'; END IF;

  SELECT * INTO account FROM public.users WHERE uid = p_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account not found'; END IF;
  IF account.role = 'super_admin' AND account."isActive" AND NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE role = 'super_admin' AND "isActive" AND uid <> p_uid
  ) THEN
    RAISE EXCEPTION 'The last active Super Admin cannot be deleted';
  END IF;

  -- Legacy request IDs also include audit-only snapshots of already deleted rows.
  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::text[]) INTO request_ids
  FROM (
    SELECT r.id FROM public.requests r
    WHERE r."requestedBy" = p_uid OR r."reviewedBy" = p_uid
      OR r."auditLogs"::text LIKE '%' || p_uid::text || '%'
    UNION
    SELECT a.request_id FROM public.request_deletion_audit a
    WHERE a.deleted_by = p_uid
      OR a.request_snapshot::text LIKE '%' || p_uid::text || '%'
  ) linked_requests;

  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::uuid[])
  INTO core_advance_ids
  FROM (
    SELECT a.id FROM public.advance_requests a
    WHERE a.office_boy_id = p_uid OR a.decided_by = p_uid OR a.cleared_by = p_uid
    UNION
    SELECT i.advance_request_id FROM public.advance_items i
    WHERE i.office_boy_id = p_uid OR i.reviewed_by = p_uid
      OR i.tagged_manager_id = p_uid
    UNION
    SELECT l.advance_request_id FROM public.advance_ledger l
    WHERE l.office_boy_id = p_uid OR l.actor_id = p_uid
    UNION
    SELECT c.advance_request_id FROM public.core_payment_activity c
    WHERE c.advance_request_id IS NOT NULL
      AND (c.office_boy_id = p_uid OR c.actor_id = p_uid)
  ) linked_core_advances;

  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::uuid[])
  INTO legacy_advance_ids
  FROM (
    SELECT a.id FROM public.advances a
    WHERE a.office_boy_id = p_uid OR a.given_by = p_uid
    UNION
    SELECT a.advance_id FROM public.advance_requests a
    WHERE a.id = ANY(core_advance_ids) AND a.advance_id IS NOT NULL
    UNION
    SELECT l.advance_id FROM public.float_ledger l
    WHERE l.advance_id IS NOT NULL
      AND (l.office_boy_id = p_uid OR l.actor_id = p_uid)
    UNION
    SELECT c.advance_id FROM public.payment_activity c
    WHERE c.advance_id IS NOT NULL
      AND (c.office_boy_id = p_uid OR c.actor_id = p_uid)
  ) linked_legacy_advances;

  -- An old advance request may point at a legacy advance selected above.
  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::uuid[])
  INTO core_advance_ids
  FROM (
    SELECT unnest(core_advance_ids) AS id
    UNION
    SELECT a.id FROM public.advance_requests a
    WHERE a.advance_id = ANY(legacy_advance_ids)
  ) all_core_advances;

  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::uuid[])
  INTO legacy_advance_ids
  FROM (
    SELECT unnest(legacy_advance_ids) AS id
    UNION
    SELECT a.advance_id FROM public.advance_requests a
    WHERE a.id = ANY(core_advance_ids) AND a.advance_id IS NOT NULL
  ) all_legacy_advances;

  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::uuid[])
  INTO expense_ids
  FROM (
    SELECT e.id FROM public.expenses e
    WHERE e.office_boy_id = p_uid OR e.reviewed_by = p_uid
      OR e.advance_id = ANY(legacy_advance_ids)
    UNION
    SELECT l.expense_id FROM public.float_ledger l
    WHERE l.expense_id IS NOT NULL
      AND (l.office_boy_id = p_uid OR l.actor_id = p_uid)
    UNION
    SELECT c.expense_id FROM public.payment_activity c
    WHERE c.expense_id IS NOT NULL
      AND (c.office_boy_id = p_uid OR c.actor_id = p_uid)
  ) linked_expenses;

  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::uuid[])
  INTO reimbursement_ids
  FROM (
    SELECT r.id FROM public.reimbursement_requests r
    WHERE r.office_boy_id = p_uid OR r.reviewed_by = p_uid
      OR r.tagged_manager_id = p_uid
    UNION
    SELECT c.reimbursement_id FROM public.core_payment_activity c
    WHERE c.reimbursement_id IS NOT NULL
      AND (c.office_boy_id = p_uid OR c.actor_id = p_uid)
  ) linked_reimbursements;

  -- Save exact attached files before deleting their database references.
  INSERT INTO public.account_deletion_receipts(account_uid, path)
  SELECT p_uid, split_part(
    CASE WHEN raw_path LIKE 'http%' THEN split_part(raw_path, '/receipts/', 2)
      ELSE raw_path END, '?', 1)
  FROM (
    SELECT r."billImageUrl" AS raw_path FROM public.requests r
      WHERE r.id = ANY(request_ids)
    UNION
    SELECT e.bill_path FROM public.expenses e WHERE e.id = ANY(expense_ids)
    UNION
    SELECT i.bill_path FROM public.advance_items i
      WHERE i.advance_request_id = ANY(core_advance_ids)
    UNION
    SELECT r.bill_path FROM public.reimbursement_requests r
      WHERE r.id = ANY(reimbursement_ids)
  ) files
  WHERE raw_path IS NOT NULL AND raw_path <> ''
    AND (CASE WHEN raw_path LIKE 'http%' THEN split_part(raw_path, '/receipts/', 2)
      ELSE raw_path END) ~ '^[0-9a-fA-F-]{36}/'
  ON CONFLICT DO NOTHING;

  DELETE FROM public.notifications n
  WHERE n.user_id = p_uid OR n.related_request_id = ANY(request_ids)
    OR n.related_advance_request_id = ANY(core_advance_ids)
    OR n.related_core_advance_id = ANY(core_advance_ids)
    OR n.related_advance_id = ANY(legacy_advance_ids)
    OR n.related_expense_id = ANY(expense_ids)
    OR n.related_reimbursement_id = ANY(reimbursement_ids)
    OR n.source_activity_id IN (
      SELECT c.id FROM public.core_payment_activity c
      WHERE c.advance_request_id = ANY(core_advance_ids)
        OR c.reimbursement_id = ANY(reimbursement_ids)
    );
  DELETE FROM public.device_tokens WHERE user_id = p_uid;
  DELETE FROM public.request_deletion_audit a
  WHERE a.request_id = ANY(request_ids) OR a.deleted_by = p_uid
    OR a.request_snapshot::text LIKE '%' || p_uid::text || '%';

  -- This is the existing, narrowly scoped exception to immutable history.
  PERFORM set_config('app.allow_account_data_purge', 'on', true);
  DELETE FROM public.core_payment_activity c
    WHERE c.advance_request_id = ANY(core_advance_ids)
      OR c.reimbursement_id = ANY(reimbursement_ids);
  DELETE FROM public.advance_ledger l
    WHERE l.advance_request_id = ANY(core_advance_ids);
  DELETE FROM public.advance_items i
    WHERE i.advance_request_id = ANY(core_advance_ids);
  DELETE FROM public.reimbursement_requests r
    WHERE r.id = ANY(reimbursement_ids);
  DELETE FROM public.advance_requests a
    WHERE a.id = ANY(core_advance_ids);
  DELETE FROM public.payment_activity c
    WHERE c.advance_id = ANY(legacy_advance_ids)
      OR c.expense_id = ANY(expense_ids);
  DELETE FROM public.float_ledger l
    WHERE l.advance_id = ANY(legacy_advance_ids)
      OR l.expense_id = ANY(expense_ids);
  DELETE FROM public.expenses e WHERE e.id = ANY(expense_ids);
  DELETE FROM public.advances a WHERE a.id = ANY(legacy_advance_ids);
  DELETE FROM public.requests r WHERE r.id = ANY(request_ids);

  -- Do not remove a Storage object if another surviving record shares it.
  DELETE FROM public.account_deletion_receipts q
  WHERE q.account_uid = p_uid AND (
    EXISTS (SELECT 1 FROM public.requests r WHERE r."billImageUrl" = q.path)
    OR EXISTS (SELECT 1 FROM public.expenses e WHERE e.bill_path = q.path)
    OR EXISTS (SELECT 1 FROM public.advance_items i WHERE i.bill_path = q.path)
    OR EXISTS (SELECT 1 FROM public.reimbursement_requests r WHERE r.bill_path = q.path)
  );
END $$;

REVOKE ALL ON FUNCTION public.delete_user_financial_data(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_financial_data(uuid) TO service_role;

-- Offices can only be removed when no user or historical row refers to them.
CREATE OR REPLACE FUNCTION public.delete_office(p_office_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF public.current_user_role() IS DISTINCT FROM 'super_admin' THEN
    RAISE EXCEPTION 'Only a Super Admin can delete an office'
      USING ERRCODE = '42501';
  END IF;
  IF p_office_id IS NULL OR
     p_office_id = '00000000-0000-0000-0000-000000000001'::uuid THEN
    RAISE EXCEPTION 'Main Office cannot be deleted';
  END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE office_id = p_office_id) THEN
    RAISE EXCEPTION 'Move or delete every account in this office first';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.request_deletion_audit
    WHERE request_snapshot::text LIKE '%' || p_office_id::text || '%'
  ) THEN
    RAISE EXCEPTION 'This office has financial history and cannot be deleted'
      USING ERRCODE = '23503';
  END IF;
  DELETE FROM public.offices WHERE id = p_office_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Office not found'; END IF;
EXCEPTION WHEN foreign_key_violation THEN
  RAISE EXCEPTION 'This office has financial history and cannot be deleted'
    USING ERRCODE = '23503';
END $$;

REVOKE ALL ON FUNCTION public.delete_office(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_office(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
