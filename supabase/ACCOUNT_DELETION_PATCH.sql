-- ==============================================================================
-- ACCOUNT & OFFICE DELETION PATCH
-- ==============================================================================
-- Allows Super Admins to safely delete user accounts and empty offices without
-- foreign key violation errors or leaving orphan records.
-- ==============================================================================

BEGIN;

-- 1. Table to queue receipt paths for cleanup upon user deletion
CREATE TABLE IF NOT EXISTS public.account_deletion_receipts (
  account_uid uuid NOT NULL,
  path text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_uid, path)
);

ALTER TABLE public.account_deletion_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_deletion_receipts FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.account_deletion_receipts TO service_role;

-- 2. Stored procedure to safely purge all financial data of a user before account deletion
CREATE OR REPLACE FUNCTION public.delete_user_financial_data(p_uid uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  account public.users;
  core_advance_ids uuid[] := ARRAY[]::uuid[];
  reimbursement_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;
  IF p_uid IS NULL THEN 
    RAISE EXCEPTION 'Account id is required'; 
  END IF;

  SELECT * INTO account FROM public.users WHERE uid = p_uid FOR UPDATE;
  IF NOT FOUND THEN 
    RAISE EXCEPTION 'Account not found'; 
  END IF;
  
  IF account.role = 'super_admin' AND account."isActive" AND NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE role = 'super_admin' AND "isActive" AND uid <> p_uid
  ) THEN
    RAISE EXCEPTION 'The last active Super Admin cannot be deleted';
  END IF;

  -- Collect all advance request IDs connected to this user
  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::uuid[])
  INTO core_advance_ids
  FROM (
    SELECT a.id FROM public.advance_requests a
    WHERE a.office_boy_id = p_uid OR a.cleared_by = p_uid OR a.allotted_by_manager_id = p_uid
    UNION
    SELECT i.advance_request_id FROM public.advance_items i
    WHERE i.office_boy_id = p_uid OR i.reviewed_by = p_uid OR i.tagged_manager_id = p_uid
    UNION
    SELECT l.advance_request_id FROM public.advance_ledger l
    WHERE l.office_boy_id = p_uid OR l.actor_id = p_uid
    UNION
    SELECT c.advance_request_id FROM public.core_payment_activity c
    WHERE c.advance_request_id IS NOT NULL AND (c.office_boy_id = p_uid OR c.actor_id = p_uid)
  ) linked_advances;

  -- Collect all reimbursement IDs connected to this user
  SELECT coalesce(array_agg(DISTINCT id), ARRAY[]::uuid[])
  INTO reimbursement_ids
  FROM (
    SELECT r.id FROM public.reimbursement_requests r
    WHERE r.office_boy_id = p_uid OR r.reviewed_by = p_uid OR r.tagged_manager_id = p_uid
    UNION
    SELECT c.reimbursement_id FROM public.core_payment_activity c
    WHERE c.reimbursement_id IS NOT NULL AND (c.office_boy_id = p_uid OR c.actor_id = p_uid)
  ) linked_reimbursements;

  -- Queue receipt images for Storage deletion
  INSERT INTO public.account_deletion_receipts(account_uid, path)
  SELECT p_uid, split_part(
    CASE WHEN raw_path LIKE 'http%' THEN split_part(raw_path, '/receipts/', 2)
      ELSE raw_path END, '?', 1)
  FROM (
    SELECT i.bill_path AS raw_path FROM public.advance_items i
      WHERE i.advance_request_id = ANY(core_advance_ids)
    UNION
    SELECT r.bill_path AS raw_path FROM public.reimbursement_requests r
      WHERE r.id = ANY(reimbursement_ids)
  ) files
  WHERE raw_path IS NOT NULL AND raw_path <> ''
    AND (CASE WHEN raw_path LIKE 'http%' THEN split_part(raw_path, '/receipts/', 2)
      ELSE raw_path END) ~ '^[0-9a-fA-F-]{36}/'
  ON CONFLICT DO NOTHING;

  -- Delete associated notifications & device push tokens
  DELETE FROM public.notifications n
  WHERE n.user_id = p_uid 
    OR n.related_request_id = ANY(core_advance_ids::text[])
    OR n.related_request_id = ANY(reimbursement_ids::text[]);
    
  DELETE FROM public.device_tokens WHERE user_id = p_uid;

  -- Enable temporary purge privilege for history protection trigger
  PERFORM set_config('app.allow_account_data_purge', 'on', true);

  -- Delete transaction rows in strict child-to-parent foreign key order
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

  -- Handle legacy tables if they exist in this or future migrations
  IF to_regclass('public.requests') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.requests WHERE "requestedBy" = $1 OR "reviewedBy" = $1' USING p_uid;
  END IF;
  IF to_regclass('public.expenses') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.expenses WHERE office_boy_id = $1 OR reviewed_by = $1' USING p_uid;
  END IF;
  IF to_regclass('public.advances') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.advances WHERE office_boy_id = $1 OR given_by = $1' USING p_uid;
  END IF;

  -- Clean up queued receipt paths if any surviving record still references them
  DELETE FROM public.account_deletion_receipts q
  WHERE q.account_uid = p_uid AND (
    EXISTS (SELECT 1 FROM public.advance_items i WHERE i.bill_path = q.path)
    OR EXISTS (SELECT 1 FROM public.reimbursement_requests r WHERE r.bill_path = q.path)
  );

  -- Delete public profile record
  DELETE FROM public.users WHERE uid = p_uid;
END $$;

REVOKE ALL ON FUNCTION public.delete_user_financial_data(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_financial_data(uuid) TO service_role;

-- 3. Office deletion function
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
    SELECT 1 FROM public.advance_requests WHERE office_id = p_office_id
  ) OR EXISTS (
    SELECT 1 FROM public.reimbursement_requests WHERE office_id = p_office_id
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

REVOKE ALL ON FUNCTION public.delete_office(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_office(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
