-- Petty Cash: complete merged schema and latest fixes
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.users (
  uid uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  role text NOT NULL DEFAULT 'office_boy',
  "createdAt" timestamptz NOT NULL DEFAULT now(),
  "isActive" boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.requests (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "requestedBy" uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  "requesterName" text NOT NULL,
  "requesterEmail" text,
  "itemDescription" text NOT NULL,
  amount numeric(12,2) NOT NULL,
  reason text NOT NULL,
  "billImageUrl" text,
  status text NOT NULL DEFAULT 'Pending',
  "rejectionReason" text,
  "reviewedBy" uuid REFERENCES public.users(uid) ON DELETE SET NULL,
  "reviewedByName" text,
  "createdAt" timestamptz NOT NULL DEFAULT now(),
  "updatedAt" timestamptz NOT NULL DEFAULT now(),
  "auditLogs" jsonb NOT NULL DEFAULT '[]'
);

ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS request_type text NOT NULL DEFAULT 'reimbursement';
ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS settlement_amount numeric(12,2);
ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS settlement_method text;
ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS settlement_note text;
ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS settlement_date timestamptz;
ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS is_settled boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  related_request_id text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Replace legacy application policies.
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('users', 'requests', 'notifications')
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON %I.%I',
      p.policyname, p.schemaname, p.tablename
    );
  END LOOP;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'notifications'
      AND column_name = 'isRead'
  ) THEN
    ALTER TABLE public.notifications RENAME COLUMN "isRead" TO is_read;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'notifications'
      AND column_name = 'relatedRequestId'
  ) THEN
    ALTER TABLE public.notifications
      RENAME COLUMN "relatedRequestId" TO related_request_id;
  END IF;
END $$;

DO $$
DECLARE c record;
BEGIN
  FOR c IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.notifications'::regclass
      AND confrelid = 'public.requests'::regclass
  LOOP
    EXECUTE format(
      'ALTER TABLE public.notifications DROP CONSTRAINT %I',
      c.conname
    );
  END LOOP;
END $$;

ALTER TABLE public.requests ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.requests ALTER COLUMN id TYPE text USING id::text;
ALTER TABLE public.requests
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.notifications
  ALTER COLUMN related_request_id TYPE text
  USING related_request_id::text;

ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0;
ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS "paidAt" timestamptz;

-- Recover known payment dates from the existing audit trail.
UPDATE public.requests r
SET "paidAt" = (
  SELECT (e->>'timestamp')::timestamptz
  FROM jsonb_array_elements(r."auditLogs") e
  WHERE e->>'action' IN (
    'Status changed to Paid',
    'Status overridden to Paid'
  )
  ORDER BY (e->>'timestamp')::timestamptz DESC
  LIMIT 1
)
WHERE status = 'Paid' AND "paidAt" IS NULL;

-- Passwords belong in Supabase Auth, not in a readable profile table.
ALTER TABLE public.users DROP COLUMN IF EXISTS password;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS "fcmToken" text;

DO $$
DECLARE c record;
BEGIN
  FOR c IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.requests'::regclass
      AND contype = 'f'
      AND conkey = ARRAY[
        (
          SELECT attnum FROM pg_attribute
          WHERE attrelid = 'public.requests'::regclass
            AND attname = 'requestedBy'
        )
      ]::smallint[]
  LOOP
    EXECUTE format(
      'ALTER TABLE public.requests DROP CONSTRAINT %I',
      c.conname
    );
  END LOOP;
END $$;

ALTER TABLE public.requests
  ADD CONSTRAINT requests_owner_fk
  FOREIGN KEY ("requestedBy")
  REFERENCES public.users(uid) ON DELETE RESTRICT;

ALTER TABLE public.requests
  DROP CONSTRAINT IF EXISTS requests_amount_valid;
ALTER TABLE public.requests
  ADD CONSTRAINT requests_amount_valid
  CHECK (
    amount::text NOT IN ('NaN', 'Infinity', '-Infinity')
    AND amount > 0
  ) NOT VALID;

ALTER TABLE public.requests
  DROP CONSTRAINT IF EXISTS requests_status_valid;
ALTER TABLE public.requests
  ADD CONSTRAINT requests_status_valid
  CHECK (
    status IN (
      'Pending', 'Approved', 'Rejected', 'Paid',
      'Pending Settlement', 'Settled'
    )
  ) NOT VALID;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_role_valid;
ALTER TABLE public.users
  ADD CONSTRAINT users_role_valid
  CHECK (
    role IN ('super_admin', 'admin', 'finance', 'office_boy')
  ) NOT VALID;

CREATE INDEX IF NOT EXISTS requests_created_idx
  ON public.requests ("createdAt" DESC, id);
CREATE INDEX IF NOT EXISTS requests_owner_created_idx
  ON public.requests ("requestedBy", "createdAt" DESC);
CREATE INDEX IF NOT EXISTS requests_paid_idx
  ON public.requests ("paidAt") WHERE status = 'Paid';
CREATE INDEX IF NOT EXISTS notifications_user_date_idx
  ON public.notifications (user_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role
  FROM public.users
  WHERE uid = auth.uid() AND "isActive" = true
$$;

REVOKE ALL ON FUNCTION public.current_user_role()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_role()
  TO authenticated;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.users, public.requests, public.notifications
  FROM anon, authenticated;
GRANT SELECT ON public.users, public.requests, public.notifications
  TO authenticated;
GRANT UPDATE(is_read), DELETE ON public.notifications
  TO authenticated;

CREATE POLICY users_read ON public.users
FOR SELECT TO authenticated
USING (
  uid = auth.uid()
  OR public.current_user_role() IN ('super_admin', 'admin', 'finance')
);

CREATE POLICY requests_read ON public.requests
FOR SELECT TO authenticated
USING (
  public.current_user_role() IS NOT NULL
  AND (
    "requestedBy" = auth.uid()
    OR public.current_user_role() IN ('super_admin', 'admin', 'finance')
  )
);

CREATE POLICY notifications_read ON public.notifications
FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  AND public.current_user_role() IS NOT NULL
);

CREATE POLICY notifications_read_update ON public.notifications
FOR UPDATE TO authenticated
USING (
  user_id = auth.uid()
  AND public.current_user_role() IS NOT NULL
)
WITH CHECK (
  user_id = auth.uid()
  AND public.current_user_role() IS NOT NULL
);

CREATE POLICY notifications_delete ON public.notifications
FOR DELETE TO authenticated
USING (
  user_id = auth.uid()
  AND public.current_user_role() IS NOT NULL
);

-- Disable obsolete administrative RPCs.
DO $$
DECLARE f record;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'admin_create_user',
        'update_user_credentials',
        'delete_user',
        'submit_request'
      )
  LOOP
    EXECUTE format(
      'REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',
      f.signature
    );
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS
  public.submit_request(text, text, numeric, text, text);

-- Create requests with validation and retry protection.
CREATE OR REPLACE FUNCTION public.submit_request(
  request_id text,
  item_description text,
  request_amount numeric,
  request_reason text,
  receipt_path text DEFAULT NULL,
  p_request_type text DEFAULT 'reimbursement'
)
RETURNS public.requests
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor public.users;
  result public.requests;
BEGIN
  SELECT * INTO actor
  FROM public.users
  WHERE uid = auth.uid() AND "isActive";

  IF actor.uid IS NULL THEN
    RAISE EXCEPTION 'Your account is not active'
      USING ERRCODE = '42501';
  END IF;

  IF request_id IS NULL
     OR request_id !~ '^[0-9a-fA-F-]{36}$' THEN
    RAISE EXCEPTION 'Invalid request reference';
  END IF;

  IF request_amount IS NULL
     OR request_amount::text IN ('NaN', 'Infinity', '-Infinity')
     OR request_amount <= 0
     OR request_amount >= 10000000000
     OR request_amount <> round(request_amount, 2) THEN
    RAISE EXCEPTION
      'Enter a positive amount with at most two decimal places';
  END IF;

  IF item_description IS NULL
     OR request_reason IS NULL
     OR length(trim(item_description)) NOT BETWEEN 1 AND 500
     OR length(trim(request_reason)) NOT BETWEEN 1 AND 2000 THEN
    RAISE EXCEPTION 'Description and reason are required';
  END IF;

  IF p_request_type IS NULL
     OR p_request_type NOT IN ('reimbursement', 'advance') THEN
    RAISE EXCEPTION 'Invalid request type';
  END IF;

  IF receipt_path IS NOT NULL
     AND (
       receipt_path NOT LIKE actor.uid::text || '/%'
       OR receipt_path LIKE '%..%'
     ) THEN
    RAISE EXCEPTION 'Invalid receipt path';
  END IF;

  SELECT * INTO result
  FROM public.requests
  WHERE id = request_id;

  IF FOUND THEN
    IF result."requestedBy" <> actor.uid
       OR result.request_type <> p_request_type
       OR result.amount <> request_amount
       OR result."itemDescription" <> trim(item_description)
       OR result.reason <> trim(request_reason)
       OR result."billImageUrl" IS DISTINCT FROM receipt_path THEN
      RAISE EXCEPTION 'Request reference already used';
    END IF;
    RETURN result;
  END IF;

  INSERT INTO public.requests (
    id, "requestedBy", "requesterName", "requesterEmail",
    "itemDescription", amount, reason, "billImageUrl",
    "auditLogs", request_type
  )
  VALUES (
    request_id, actor.uid, actor.name, actor.email,
    trim(item_description), request_amount,
    trim(request_reason), receipt_path,
    jsonb_build_array(
      jsonb_build_object(
        'timestamp', now(),
        'action', 'Created ' || p_request_type || ' request',
        'performerId', actor.uid,
        'performerName', actor.name
      )
    ),
    p_request_type
  )
  RETURNING * INTO result;

  RETURN result;
END $$;

-- Approvals, payments and supported super-admin overrides.
CREATE OR REPLACE FUNCTION public.review_request(
  request_id text,
  expected_version integer,
  new_status text,
  review_note text DEFAULT NULL,
  is_override boolean DEFAULT false
)
RETURNS public.requests
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor public.users;
  result public.requests;
BEGIN
  SELECT * INTO actor
  FROM public.users
  WHERE uid = auth.uid() AND "isActive";

  IF actor.role IS NULL
     OR actor.role NOT IN ('finance', 'super_admin') THEN
    RAISE EXCEPTION 'You cannot review requests'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO result
  FROM public.requests
  WHERE id = request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  IF expected_version IS NULL
     OR result.version <> expected_version THEN
    RAISE EXCEPTION
      'This request changed. Refresh it before reviewing.'
      USING ERRCODE = '40001';
  END IF;

  IF new_status IS NULL
     OR new_status NOT IN ('Pending', 'Approved', 'Rejected', 'Paid')
     OR new_status = result.status THEN
    RAISE EXCEPTION 'Invalid status transition';
  END IF;

  IF is_override THEN
    IF actor.role <> 'super_admin'
       OR coalesce(length(trim(review_note)), 0) = 0 THEN
      RAISE EXCEPTION
        'A super-admin and an override reason are required'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    IF NOT (
      (
        result.status = 'Pending'
        AND new_status IN ('Approved', 'Rejected', 'Paid')
      )
      OR (
        result.status = 'Approved'
        AND new_status IN ('Paid', 'Rejected')
      )
    ) THEN
      RAISE EXCEPTION 'This request can no longer be reviewed';
    END IF;
  END IF;

  IF new_status = 'Rejected'
     AND coalesce(length(trim(review_note)), 0) = 0 THEN
    RAISE EXCEPTION 'A rejection reason is required';
  END IF;

  UPDATE public.requests
  SET
    status = new_status,
    "rejectionReason" = CASE
      WHEN new_status = 'Rejected' THEN trim(review_note)
    END,
    "reviewedBy" = actor.uid,
    "reviewedByName" = actor.name,
    "updatedAt" = now(),
    version = version + 1,
    settlement_amount = NULL,
    settlement_method = NULL,
    settlement_note = NULL,
    settlement_date = NULL,
    is_settled = false,
    "paidAt" = CASE
      WHEN new_status = 'Paid' THEN now()
      ELSE NULL
    END,
    "auditLogs" = "auditLogs" || jsonb_build_array(
      jsonb_build_object(
        'timestamp', now(),
        'action',
          CASE
            WHEN is_override THEN 'Status overridden to '
            ELSE 'Status changed to '
          END || new_status,
        'performerId', actor.uid,
        'performerName', actor.name,
        'notes', nullif(trim(review_note), '')
      )
    )
  WHERE id = request_id
  RETURNING * INTO result;

  RETURN result;
END $$;

-- Super-admin deletion preserves a complete audit snapshot.
CREATE OR REPLACE FUNCTION public.delete_request(request_id text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE target public.requests;
BEGIN
  IF public.current_user_role() IS DISTINCT FROM 'super_admin' THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO target
  FROM public.requests
  WHERE id = request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  INSERT INTO public.request_deletion_audit (
    request_id, deleted_by, request_snapshot
  )
  VALUES (
    target.id, auth.uid(), to_jsonb(target)
  );

  DELETE FROM public.requests WHERE id = target.id;
END $$;

-- Submit a settlement or update a pending settlement.
CREATE OR REPLACE FUNCTION public.settle_advance_request(
  p_request_id text,
  p_expected_version integer,
  p_settlement_amount numeric,
  p_settlement_method text,
  p_settlement_note text
)
RETURNS public.requests
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor public.users;
  result public.requests;
BEGIN
  SELECT * INTO actor
  FROM public.users
  WHERE uid = auth.uid() AND "isActive";

  IF actor.uid IS NULL THEN
    RAISE EXCEPTION 'Your account is not active'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO result
  FROM public.requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  IF result."requestedBy" <> actor.uid
     AND actor.role NOT IN ('finance', 'super_admin') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF result.status NOT IN ('Paid', 'Pending Settlement')
     OR result.request_type <> 'advance' THEN
    RAISE EXCEPTION 'Only paid or pending advances can be settled';
  END IF;

  IF p_expected_version IS NULL
     OR result.version <> p_expected_version THEN
    RAISE EXCEPTION
      'This request changed. Refresh it before reviewing.'
      USING ERRCODE = '40001';
  END IF;

  IF p_settlement_amount IS NULL
     OR p_settlement_amount::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_settlement_amount <> round(p_settlement_amount, 2)
     OR p_settlement_amount < 0
     OR p_settlement_amount > result.amount THEN
    RAISE EXCEPTION 'Invalid settlement amount';
  END IF;

  IF p_settlement_amount < result.amount
     AND (
       p_settlement_method IS NULL
       OR p_settlement_method NOT IN ('Cash', 'Card')
     ) THEN
    RAISE EXCEPTION 'Choose a valid return method';
  END IF;

  IF length(p_settlement_note) > 2000 THEN
    RAISE EXCEPTION 'Settlement note is too long';
  END IF;

  UPDATE public.requests
  SET
    status = 'Pending Settlement',
    settlement_amount = p_settlement_amount,
    settlement_method = p_settlement_method,
    settlement_note = trim(p_settlement_note),
    settlement_date = now(),
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(
      jsonb_build_object(
        'timestamp', now(),
        'action',
          CASE
            WHEN result.status = 'Pending Settlement'
              THEN 'Updated Settlement'
            ELSE 'Submitted Settlement'
          END,
        'performerId', actor.uid,
        'performerName', actor.name,
        'notes',
          'Spent: ' || p_settlement_amount
          || ', Returned via ' || coalesce(p_settlement_method, 'None')
          || '. Note: ' || coalesce(p_settlement_note, '')
      )
    )
  WHERE id = p_request_id
  RETURNING * INTO result;

  RETURN result;
END $$;

-- Finance verifies the latest valid settlement revision.
CREATE OR REPLACE FUNCTION public.verify_advance_settlement(
  p_request_id text,
  p_expected_version integer
)
RETURNS public.requests
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor public.users;
  result public.requests;
BEGIN
  SELECT * INTO actor
  FROM public.users
  WHERE uid = auth.uid() AND "isActive";

  IF actor.uid IS NULL THEN
    RAISE EXCEPTION 'Your account is not active'
      USING ERRCODE = '42501';
  END IF;

  IF actor.role NOT IN ('finance', 'super_admin') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO result
  FROM public.requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  IF result.status <> 'Pending Settlement'
     OR result.request_type <> 'advance' THEN
    RAISE EXCEPTION 'Request is not pending settlement';
  END IF;

  IF p_expected_version IS NULL
     OR result.version <> p_expected_version THEN
    RAISE EXCEPTION
      'This request changed. Refresh it before reviewing.'
      USING ERRCODE = '40001';
  END IF;

  IF result.settlement_amount IS NULL
     OR result.settlement_amount::text IN ('NaN', 'Infinity', '-Infinity')
     OR result.settlement_amount < 0
     OR result.settlement_amount > result.amount THEN
    RAISE EXCEPTION 'Invalid settlement amount';
  END IF;

  IF result.settlement_amount < result.amount
     AND (
       result.settlement_method IS NULL
       OR result.settlement_method NOT IN ('Cash', 'Card')
     ) THEN
    RAISE EXCEPTION 'Choose a valid return method';
  END IF;

  UPDATE public.requests
  SET
    status = 'Settled',
    is_settled = true,
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(
      jsonb_build_object(
        'timestamp', now(),
        'action', 'Settlement Verified',
        'performerId', actor.uid,
        'performerName', actor.name
      )
    )
  WHERE id = p_request_id
  RETURNING * INTO result;

  RETURN result;
END $$;

-- Synchronize Auth metadata and application profiles.
UPDATE auth.users a
SET raw_app_meta_data = coalesce(a.raw_app_meta_data, '{}')
  || jsonb_build_object(
    'petty_cash_role', u.role,
    'petty_cash_active', u."isActive"
  )
FROM public.users u
WHERE u.uid = a.id;

CREATE OR REPLACE FUNCTION public.sync_auth_profile()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  requested_role text;
  active boolean;
  existing public.users;
BEGIN
  requested_role := NEW.raw_app_meta_data->>'petty_cash_role';

  IF requested_role IS NULL THEN
    RETURN NEW;
  END IF;

  IF requested_role NOT IN (
    'office_boy', 'finance', 'admin', 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Invalid app role';
  END IF;

  active := coalesce(
    (NEW.raw_app_meta_data->>'petty_cash_active')::boolean,
    true
  );

  PERFORM pg_advisory_xact_lock(72624401);

  SELECT * INTO existing
  FROM public.users
  WHERE uid = NEW.id;

  IF existing.role = 'super_admin'
     AND existing."isActive"
     AND (requested_role <> 'super_admin' OR NOT active)
     AND NOT EXISTS (
       SELECT 1 FROM public.users
       WHERE role = 'super_admin'
         AND "isActive"
         AND uid <> NEW.id
     ) THEN
    RAISE EXCEPTION
      'The last active super-admin cannot be disabled or demoted';
  END IF;

  INSERT INTO public.users(uid, name, email, role, "isActive")
  VALUES (
    NEW.id,
    coalesce(
      nullif(trim(NEW.raw_user_meta_data->>'name'), ''),
      existing.name,
      'Staff member'
    ),
    NEW.email,
    requested_role,
    active
  )
  ON CONFLICT(uid) DO UPDATE
  SET name = EXCLUDED.name,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      "isActive" = EXCLUDED."isActive";

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS petty_cash_auth_profile ON auth.users;
CREATE TRIGGER petty_cash_auth_profile
AFTER INSERT OR UPDATE OF email, raw_app_meta_data, raw_user_meta_data
ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.sync_auth_profile();

-- Notifications include edits to an already pending settlement.
CREATE OR REPLACE FUNCTION public.request_notifications()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.notifications(
      user_id, title, message, related_request_id
    )
    SELECT
      uid,
      'New expense request',
      NEW."requesterName"
        || ' submitted a request for PKR ' || NEW.amount,
      NEW.id
    FROM public.users
    WHERE "isActive"
      AND role IN ('finance', 'admin', 'super_admin')
      AND uid <> NEW."requestedBy";

  ELSIF NEW.status IS DISTINCT FROM OLD.status
    OR (
      NEW.status = 'Pending Settlement'
      AND ROW(
        NEW.settlement_amount,
        NEW.settlement_method,
        NEW.settlement_note,
        NEW.settlement_date
      ) IS DISTINCT FROM ROW(
        OLD.settlement_amount,
        OLD.settlement_method,
        OLD.settlement_note,
        OLD.settlement_date
      )
    ) THEN

    IF NEW.status = 'Pending Settlement' THEN
      INSERT INTO public.notifications(
        user_id, title, message, related_request_id
      )
      SELECT
        uid,
        'Advance Settlement',
        NEW."requesterName" || ' submitted a settlement update.',
        NEW.id
      FROM public.users
      WHERE "isActive"
        AND role IN ('finance', 'admin', 'super_admin')
        AND uid <> NEW."requestedBy";

      INSERT INTO public.notifications(
        user_id, title, message, related_request_id
      )
      VALUES (
        NEW."requestedBy",
        'Settlement Submitted',
        'Your settlement update has been submitted for review.',
        NEW.id
      );

    ELSIF NEW.status = 'Settled' THEN
      INSERT INTO public.notifications(
        user_id, title, message, related_request_id
      )
      SELECT
        uid,
        'Advance Settled',
        NEW."requesterName"
          || '''s advance has been fully settled and closed.',
        NEW.id
      FROM public.users
      WHERE "isActive"
        AND role IN ('finance', 'admin', 'super_admin')
        AND uid <> NEW."requestedBy";

      INSERT INTO public.notifications(
        user_id, title, message, related_request_id
      )
      VALUES (
        NEW."requestedBy",
        'Advance Settled',
        'Your advance settlement was verified by Finance and is now closed.',
        NEW.id
      );

    ELSE
      INSERT INTO public.notifications(
        user_id, title, message, related_request_id
      )
      VALUES (
        NEW."requestedBy",
        'Request ' || NEW.status,
        'Your request for ' || NEW."itemDescription"
          || ' is now ' || lower(NEW.status) || '.',
        NEW.id
      );
    END IF;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS petty_cash_request_notifications
  ON public.requests;
CREATE TRIGGER petty_cash_request_notifications
AFTER INSERT OR UPDATE OF status ON public.requests
FOR EACH ROW EXECUTE FUNCTION public.request_notifications();

CREATE TABLE IF NOT EXISTS public.device_tokens (
  token text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  platform text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.device_tokens FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.register_device(
  device_token text,
  device_platform text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.current_user_role() IS NULL THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  IF length(device_token) NOT BETWEEN 10 AND 4096 THEN
    RAISE EXCEPTION 'Invalid device token';
  END IF;

  INSERT INTO public.device_tokens(token, user_id, platform)
  VALUES(device_token, auth.uid(), device_platform)
  ON CONFLICT(token) DO UPDATE
  SET user_id = EXCLUDED.user_id,
      platform = EXCLUDED.platform,
      updated_at = now();
END $$;

CREATE OR REPLACE FUNCTION public.unregister_device(device_token text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.device_tokens
  WHERE token = device_token AND user_id = auth.uid();
END $$;

-- Enable realtime for application tables.
DO $$
DECLARE t text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    FOREACH t IN ARRAY ARRAY['users', 'requests', 'notifications']
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = t
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          t
        );
      END IF;
    END LOOP;
  END IF;
END $$;

-- Private receipt storage.
INSERT INTO storage.buckets(
  id, name, public, file_size_limit, allowed_mime_types
)
VALUES(
  'receipts',
  'receipts',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT(id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND (
        coalesce(qual, '') ILIKE '%receipts%'
        OR coalesce(with_check, '') ILIKE '%receipts%'
        OR policyname ILIKE '%receipt%'
      )
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON storage.objects',
      p.policyname
    );
  END LOOP;
END $$;

CREATE POLICY receipts_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'receipts'
  AND public.current_user_role() IS NOT NULL
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY receipts_select ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'receipts'
  AND public.current_user_role() IS NOT NULL
  AND (
    owner = auth.uid()
    OR public.current_user_role() IN ('super_admin', 'admin', 'finance')
  )
);

CREATE POLICY receipts_delete ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'receipts'
  AND public.current_user_role() IS NOT NULL
  AND owner = auth.uid()
  AND NOT EXISTS (
    SELECT 1 FROM public.requests WHERE "billImageUrl" = name
  )
);

REVOKE ALL ON FUNCTION
  public.submit_request(text,text,numeric,text,text,text),
  public.review_request(text,integer,text,text,boolean),
  public.delete_request(text),
  public.register_device(text,text),
  public.unregister_device(text),
  public.sync_auth_profile(),
  public.request_notifications(),
  public.settle_advance_request(text,integer,numeric,text,text),
  public.verify_advance_settlement(text,integer)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.submit_request(text,text,numeric,text,text,text),
  public.review_request(text,integer,text,text,boolean),
  public.delete_request(text),
  public.register_device(text,text),
  public.unregister_device(text),
  public.settle_advance_request(text,integer,numeric,text,text),
  public.verify_advance_settlement(text,integer)
TO authenticated;

GRANT ALL ON
  public.users,
  public.requests,
  public.notifications,
  public.device_tokens
TO service_role;

-- Push notification delivery queue.
CREATE TABLE IF NOT EXISTS public.push_outbox (
  id uuid PRIMARY KEY REFERENCES public.notifications(id) ON DELETE CASCADE,
  attempts integer NOT NULL DEFAULT 0,
  available_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  last_error text
);

ALTER TABLE public.push_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_outbox FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.push_outbox TO service_role;

CREATE INDEX IF NOT EXISTS push_outbox_pending_idx
  ON public.push_outbox(available_at) WHERE sent_at IS NULL;

CREATE OR REPLACE FUNCTION public.queue_push()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.push_outbox(id)
  VALUES(NEW.id)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS petty_cash_queue_push ON public.notifications;
CREATE TRIGGER petty_cash_queue_push
AFTER INSERT ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.queue_push();

CREATE OR REPLACE FUNCTION public.claim_push_batch()
RETURNS TABLE(id uuid, user_id uuid, request_id text)
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  WITH claimed AS (
    SELECT o.id
    FROM public.push_outbox o
    WHERE o.sent_at IS NULL
      AND o.attempts < 8
      AND o.available_at <= now()
    ORDER BY o.available_at
    LIMIT 50
    FOR UPDATE SKIP LOCKED
  ),
  leased AS (
    UPDATE public.push_outbox o
    SET attempts = o.attempts + 1,
        available_at = now() + interval '5 minutes'
    FROM claimed
    WHERE o.id = claimed.id
    RETURNING o.id
  )
  SELECT n.id, n.user_id, n.related_request_id
  FROM leased
  JOIN public.notifications n USING(id)
$$;

REVOKE ALL ON FUNCTION
  public.queue_push(),
  public.claim_push_batch()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.claim_push_batch()
TO service_role;

-- Remember notification language for each device.
ALTER TABLE public.device_tokens
  ADD COLUMN IF NOT EXISTS language_code text NOT NULL DEFAULT 'en'
  CHECK (language_code IN ('en', 'ur'));

CREATE OR REPLACE FUNCTION public.register_device_language(
  device_token text,
  device_platform text,
  device_language text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF device_language IS NULL
     OR device_language NOT IN ('en', 'ur') THEN
    RAISE EXCEPTION 'Invalid language';
  END IF;

  IF device_platform IS NULL
     OR device_platform NOT IN ('web', 'android', 'iOS') THEN
    RAISE EXCEPTION 'Invalid platform';
  END IF;

  PERFORM public.register_device(device_token, device_platform);

  UPDATE public.device_tokens
  SET language_code = device_language
  WHERE token = device_token AND user_id = auth.uid();
END $$;

REVOKE ALL ON FUNCTION
  public.register_device_language(text,text,text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.register_device_language(text,text,text)
TO authenticated;

-- Protected archive of deleted transactions.
CREATE TABLE IF NOT EXISTS public.request_deletion_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text NOT NULL,
  deleted_by uuid NOT NULL,
  deleted_at timestamptz NOT NULL DEFAULT now(),
  request_snapshot jsonb NOT NULL
);

ALTER TABLE public.request_deletion_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.request_deletion_audit
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.request_deletion_audit TO authenticated;
GRANT ALL ON public.request_deletion_audit TO service_role;

DROP POLICY IF EXISTS superadmin_deletion_audit
  ON public.request_deletion_audit;
CREATE POLICY superadmin_deletion_audit
ON public.request_deletion_audit
FOR SELECT TO authenticated
USING (public.current_user_role() = 'super_admin');

REVOKE ALL ON FUNCTION public.delete_request(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_request(text)
  TO authenticated;

DROP FUNCTION IF EXISTS
  public.submit_request(text,text,numeric,text,text);

REVOKE ALL ON FUNCTION
  public.submit_request(text,text,numeric,text,text,text),
  public.review_request(text,integer,text,text,boolean),
  public.settle_advance_request(text,integer,numeric,text,text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.submit_request(text,text,numeric,text,text,text),
  public.review_request(text,integer,text,text,boolean),
  public.settle_advance_request(text,integer,numeric,text,text)
TO authenticated;

-- Final notification trigger also watches settlement edits.
DROP TRIGGER IF EXISTS petty_cash_request_notifications
  ON public.requests;

CREATE TRIGGER petty_cash_request_notifications
AFTER INSERT OR UPDATE OF
  status,
  settlement_amount,
  settlement_method,
  settlement_note,
  settlement_date
ON public.requests
FOR EACH ROW EXECUTE FUNCTION public.request_notifications();

REVOKE ALL ON FUNCTION
  public.settle_advance_request(text,integer,numeric,text,text),
  public.verify_advance_settlement(text,integer),
  public.review_request(text,integer,text,text,boolean),
  public.request_notifications()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.settle_advance_request(text,integer,numeric,text,text),
  public.verify_advance_settlement(text,integer),
  public.review_request(text,integer,text,text,boolean)
TO authenticated;

-- Incremental transaction synchronization.
CREATE TABLE IF NOT EXISTS public.request_sync_clock (
  singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
  revision bigint NOT NULL DEFAULT 0
);

INSERT INTO public.request_sync_clock(singleton)
VALUES(true)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.request_changes (
  request_id text PRIMARY KEY,
  owner_id uuid NOT NULL,
  revision bigint NOT NULL,
  deleted boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS request_changes_revision_idx
  ON public.request_changes(revision);
CREATE INDEX IF NOT EXISTS request_changes_owner_revision_idx
  ON public.request_changes(owner_id, revision);

ALTER TABLE public.request_sync_clock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_changes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.request_sync_clock, public.request_changes
  FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.request_sync_clock, public.request_changes
  TO service_role;

CREATE OR REPLACE FUNCTION public.track_request_change()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  next_revision bigint;
  row_id text;
  row_owner uuid;
BEGIN
  UPDATE public.request_sync_clock
  SET revision = revision + 1
  WHERE singleton
  RETURNING revision INTO next_revision;

  IF TG_OP = 'DELETE' THEN
    row_id := OLD.id;
    row_owner := OLD."requestedBy";
  ELSE
    row_id := NEW.id;
    row_owner := NEW."requestedBy";
  END IF;

  INSERT INTO public.request_changes(
    request_id, owner_id, revision, deleted
  )
  VALUES(
    row_id, row_owner, next_revision, TG_OP = 'DELETE'
  )
  ON CONFLICT(request_id) DO UPDATE
  SET owner_id = EXCLUDED.owner_id,
      revision = EXCLUDED.revision,
      deleted = EXCLUDED.deleted;

  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS petty_cash_request_changes ON public.requests;
CREATE TRIGGER petty_cash_request_changes
AFTER INSERT OR UPDATE OR DELETE ON public.requests
FOR EACH ROW EXECUTE FUNCTION public.track_request_change();

-- Existing rows enter the feed once; repeat deployment retains cursors.
DO $$
DECLARE
  r record;
  next_revision bigint;
BEGIN
  FOR r IN
    SELECT id, "requestedBy"
    FROM public.requests
    WHERE NOT EXISTS (
      SELECT 1 FROM public.request_changes c
      WHERE c.request_id = requests.id
    )
    ORDER BY id
  LOOP
    UPDATE public.request_sync_clock
    SET revision = revision + 1
    WHERE singleton
    RETURNING revision INTO next_revision;

    INSERT INTO public.request_changes(
      request_id, owner_id, revision
    )
    VALUES(r.id, r."requestedBy", next_revision);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sync_requests(
  after_revision bigint DEFAULT 0,
  page_size integer DEFAULT 500
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor_role text;
  ceiling bigint;
  batch jsonb;
  last_revision bigint;
  batch_count integer;
BEGIN
  actor_role := public.current_user_role();

  IF actor_role IS NULL THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  IF after_revision IS NULL
     OR after_revision < 0
     OR page_size IS NULL
     OR page_size NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'Invalid sync cursor or page size';
  END IF;

  SELECT revision INTO ceiling
  FROM public.request_sync_clock
  WHERE singleton;

  IF after_revision > ceiling THEN
    RAISE EXCEPTION 'Invalid sync cursor or page size';
  END IF;

  WITH page AS (
    SELECT c.*
    FROM public.request_changes c
    WHERE c.revision > after_revision
      AND c.revision <= ceiling
      AND (
        actor_role IN ('admin', 'super_admin', 'finance')
        OR c.owner_id = auth.uid()
      )
    ORDER BY c.revision
    LIMIT page_size
  )
  SELECT
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', p.request_id,
          'deleted', p.deleted OR r.id IS NULL,
          'request',
            CASE
              WHEN NOT p.deleted AND r.id IS NOT NULL
                THEN to_jsonb(r)
              ELSE NULL
            END
        )
        ORDER BY p.revision
      ),
      '[]'::jsonb
    ),
    max(p.revision),
    count(*)
  INTO batch, last_revision, batch_count
  FROM page p
  LEFT JOIN public.requests r ON r.id = p.request_id;

  RETURN jsonb_build_object(
    'changes', batch,
    'cursor',
      CASE
        WHEN batch_count < page_size THEN ceiling
        ELSE last_revision
      END,
    'has_more', batch_count = page_size
  );
END $$;

REVOKE ALL ON FUNCTION
  public.track_request_change(),
  public.sync_requests(bigint,integer)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.sync_requests(bigint,integer)
TO authenticated;

NOTIFY pgrst, 'reload schema';

-- Additive dual-payment schema, roles and realtime.
-- New payment flows are additive. Historical public.requests rows remain untouched.
CREATE TABLE IF NOT EXISTS public.advances (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 given_by uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 amount numeric(12,2) NOT NULL CHECK (amount > 0 AND amount::text NOT IN ('NaN','Infinity','-Infinity')),
 finance_method text NOT NULL CHECK (finance_method IN ('Cash','Card')),
 received_method text CHECK (received_method IN ('Cash','Card')),
 status text NOT NULL DEFAULT 'Awaiting Confirmation' CHECK (status IN ('Awaiting Confirmation','Received')),
 mismatch_flag boolean NOT NULL DEFAULT false,
 note text CHECK (length(note) <= 2000),
 created_at timestamptz NOT NULL DEFAULT now(),
 confirmed_at timestamptz,
 CONSTRAINT advance_confirmation_consistent CHECK (
  (status='Awaiting Confirmation' AND received_method IS NULL AND confirmed_at IS NULL AND NOT mismatch_flag)
  OR (status='Received' AND received_method IS NOT NULL AND confirmed_at IS NOT NULL
      AND mismatch_flag=(finance_method<>received_method))
 )
);
CREATE INDEX IF NOT EXISTS advances_owner_date_idx ON public.advances(office_boy_id,created_at DESC);
CREATE INDEX IF NOT EXISTS advances_status_idx ON public.advances(status,created_at DESC);

CREATE TABLE IF NOT EXISTS public.expenses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 flow_type text NOT NULL CHECK (flow_type IN ('float','reimbursement')),
 item_description text NOT NULL CHECK (length(trim(item_description)) BETWEEN 1 AND 500),
 amount numeric(12,2) NOT NULL CHECK (amount > 0 AND amount::text NOT IN ('NaN','Infinity','-Infinity')),
 reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 1 AND 2000),
 bill_path text,
 status text NOT NULL DEFAULT 'Pending',
 payment_method_finance text CHECK (payment_method_finance IN ('Cash','Card')),
 payment_method_received text CHECK (payment_method_received IN ('Cash','Card')),
 mismatch_flag boolean NOT NULL DEFAULT false,
 rejection_reason text CHECK (length(trim(rejection_reason)) BETWEEN 1 AND 2000),
 rejection_acknowledged_at timestamptz,
 cleared_at timestamptz,
 paid_at timestamptz,
 reviewed_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
 reviewed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT expense_flow_status_valid CHECK (
  (flow_type='float' AND status IN ('Pending','Approved','Rejected','Rejection Acknowledged'))
  OR (flow_type='reimbursement' AND status IN ('Pending','Approved','Rejected','Rejection Acknowledged','Payment Cleared','Paid'))
 ),
 CONSTRAINT expense_payment_consistent CHECK (
  (flow_type='float' AND payment_method_finance IS NULL AND payment_method_received IS NULL
   AND cleared_at IS NULL AND paid_at IS NULL AND NOT mismatch_flag)
  OR (flow_type='reimbursement'
      AND (status NOT IN ('Payment Cleared','Paid') OR (payment_method_finance IS NOT NULL AND cleared_at IS NOT NULL))
      AND (status<>'Paid' OR (payment_method_received IS NOT NULL AND paid_at IS NOT NULL
       AND mismatch_flag=(payment_method_finance<>payment_method_received)))
      AND (status='Paid' OR (payment_method_received IS NULL AND paid_at IS NULL AND NOT mismatch_flag)))
 ),
 CONSTRAINT expense_rejection_consistent CHECK (
  (status IN ('Rejected','Rejection Acknowledged'))=(rejection_reason IS NOT NULL)
  AND (status='Rejection Acknowledged')=(rejection_acknowledged_at IS NOT NULL)
 )
);
CREATE INDEX IF NOT EXISTS expenses_owner_date_idx ON public.expenses(office_boy_id,created_at DESC);
CREATE INDEX IF NOT EXISTS expenses_queue_idx ON public.expenses(flow_type,status,created_at DESC);

-- Append-only movements. Available = credit - deduction - active holds.
-- A hold is released only after approval or the owner's rejection acknowledgement.
CREATE TABLE IF NOT EXISTS public.float_ledger (
 id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
 office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 advance_id uuid REFERENCES public.advances(id) ON DELETE RESTRICT,
 expense_id uuid REFERENCES public.expenses(id) ON DELETE RESTRICT,
 entry_type text NOT NULL CHECK (entry_type IN ('credit','hold','hold_release','deduction')),
 amount numeric(12,2) NOT NULL CHECK (amount>0 AND amount::text NOT IN ('NaN','Infinity','-Infinity')),
 actor_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT ledger_source_valid CHECK (
  (entry_type='credit' AND advance_id IS NOT NULL AND expense_id IS NULL)
  OR (entry_type<>'credit' AND advance_id IS NULL AND expense_id IS NOT NULL)
 ),
 UNIQUE(advance_id,entry_type), UNIQUE(expense_id,entry_type)
);
CREATE INDEX IF NOT EXISTS float_ledger_owner_date_idx ON public.float_ledger(office_boy_id,created_at DESC,id DESC);

CREATE TABLE IF NOT EXISTS public.payment_activity (
 id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
 advance_id uuid REFERENCES public.advances(id) ON DELETE RESTRICT,
 expense_id uuid REFERENCES public.expenses(id) ON DELETE RESTRICT,
 office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 actor_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 action text NOT NULL,
 detail jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT activity_one_source CHECK ((advance_id IS NULL)<>(expense_id IS NULL))
);
CREATE INDEX IF NOT EXISTS payment_activity_advance_idx ON public.payment_activity(advance_id,created_at,id);
CREATE INDEX IF NOT EXISTS payment_activity_expense_idx ON public.payment_activity(expense_id,created_at,id);

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS related_advance_id uuid REFERENCES public.advances(id) ON DELETE SET NULL;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS related_expense_id uuid REFERENCES public.expenses(id) ON DELETE SET NULL;

ALTER TABLE public.advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.float_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_activity ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.advances,public.expenses,public.float_ledger,public.payment_activity FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.advances,public.expenses,public.float_ledger,public.payment_activity TO authenticated;
GRANT ALL ON public.advances,public.expenses,public.float_ledger,public.payment_activity TO service_role;
GRANT USAGE,SELECT ON SEQUENCE public.float_ledger_id_seq,public.payment_activity_id_seq TO service_role;
GRANT SELECT(related_advance_id,related_expense_id) ON public.notifications TO authenticated;

DROP POLICY IF EXISTS advances_read ON public.advances;
CREATE POLICY advances_read ON public.advances FOR SELECT TO authenticated USING (
 public.current_user_role() IS NOT NULL AND
 (office_boy_id=auth.uid() OR public.current_user_role() IN ('finance','admin','super_admin'))
);
DROP POLICY IF EXISTS expenses_read ON public.expenses;
CREATE POLICY expenses_read ON public.expenses FOR SELECT TO authenticated USING (
 public.current_user_role() IS NOT NULL AND
 (office_boy_id=auth.uid() OR public.current_user_role() IN ('finance','admin','super_admin'))
);
DROP POLICY IF EXISTS float_ledger_read ON public.float_ledger;
CREATE POLICY float_ledger_read ON public.float_ledger FOR SELECT TO authenticated USING (
 public.current_user_role() IS NOT NULL AND
 (office_boy_id=auth.uid() OR public.current_user_role() IN ('finance','admin','super_admin'))
);
DROP POLICY IF EXISTS payment_activity_read ON public.payment_activity;
CREATE POLICY payment_activity_read ON public.payment_activity FOR SELECT TO authenticated USING (
 public.current_user_role() IS NOT NULL AND
 (office_boy_id=auth.uid() OR public.current_user_role() IN ('finance','admin','super_admin'))
);

-- Uploaded bills must remain private and cannot be removed after submission.
DROP POLICY IF EXISTS receipts_delete ON storage.objects;
CREATE POLICY receipts_delete ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id='receipts' AND public.current_user_role() IS NOT NULL AND owner=auth.uid()
  AND NOT EXISTS(SELECT 1 FROM public.requests WHERE "billImageUrl"=name)
  AND NOT EXISTS(SELECT 1 FROM public.expenses WHERE bill_path=name));

-- Financial history is immutable, including for privileged API clients.
CREATE OR REPLACE FUNCTION public.prevent_payment_history_change() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$
BEGIN RAISE EXCEPTION 'Payment history cannot be changed or deleted' USING ERRCODE='42501'; END $$;
DROP TRIGGER IF EXISTS float_ledger_immutable ON public.float_ledger;
CREATE TRIGGER float_ledger_immutable BEFORE UPDATE OR DELETE ON public.float_ledger
FOR EACH ROW EXECUTE FUNCTION public.prevent_payment_history_change();
DROP TRIGGER IF EXISTS payment_activity_immutable ON public.payment_activity;
CREATE TRIGGER payment_activity_immutable BEFORE UPDATE OR DELETE ON public.payment_activity
FOR EACH ROW EXECUTE FUNCTION public.prevent_payment_history_change();
REVOKE ALL ON FUNCTION public.prevent_payment_history_change() FROM PUBLIC,anon,authenticated;

DO $$ DECLARE t text; BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') THEN
  FOREACH t IN ARRAY ARRAY['advances','expenses','float_ledger','payment_activity'] LOOP
   IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t) THEN
    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',t);
   END IF;
  END LOOP;
 END IF;
END $$;

-- Server-validated advance, float and reimbursement flows.
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


-- 2026-09-29: Office Boy advance requests and per-advance spending
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
