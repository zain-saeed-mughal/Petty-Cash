-- Petty Cash master upgrade for the EXISTING production database.
-- Run this file as one query. It does not drop application tables or erase data.
-- The earlier 1,871-line historical schema must already have been applied.
-- Saved SQL Editor tabs are drafts; deleting them does not undo database changes.
-- This script deliberately does not auto-approve old pending purchases.
BEGIN;

DO $preflight$
BEGIN
  IF to_regclass('public.requests') IS NULL
     OR to_regclass('public.notifications') IS NULL
     OR to_regclass('public.device_tokens') IS NULL
     OR to_regclass('public.push_outbox') IS NULL
     OR to_regclass('public.advances') IS NULL
     OR to_regclass('public.expenses') IS NULL
     OR to_regclass('public.float_ledger') IS NULL
     OR to_regclass('public.payment_activity') IS NULL
     OR to_regclass('public.request_deletion_audit') IS NULL
     OR to_regclass('public.advance_requests') IS NULL
  THEN
    RAISE EXCEPTION 'Historical Petty Cash schema is missing. Do not run this upgrade on a new/empty database.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='notifications'
      AND column_name='related_advance_request_id'
  ) THEN
    RAISE EXCEPTION 'Advance-request history upgrade is missing. Apply the existing historical migrations first.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='advance_requests'
      AND column_name='decided_by'
  ) THEN
    RAISE EXCEPTION 'Legacy advance_requests.decided_by is missing. Existing database migration is incomplete.';
  END IF;
END $preflight$;

-- ==============================================================================
-- PETTY CASH: COMPLETE CONSOLIDATED SCHEMA (WITH ALL LATEST FIXES)
-- ==============================================================================
-- This script contains all tables, roles, security policies, and the LATEST
-- functions for Office Boy Approvals, Finance Reviews, and Optional Bank Info.
-- It resolves all previous duplicate function conflicts.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------------------------
-- 1. BASE TABLES & CORE ENTITIES
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.offices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE CHECK (length(trim(name)) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.offices(id, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'Main Office')
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.users (
  uid uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  role text NOT NULL DEFAULT 'office_boy',
  "createdAt" timestamptz NOT NULL DEFAULT now(),
  "isActive" boolean NOT NULL DEFAULT true,
  "fcmToken" text,
  office_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001' REFERENCES public.offices(id) ON DELETE RESTRICT
);
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS office_id uuid NOT NULL
    DEFAULT '00000000-0000-0000-0000-000000000001'
    REFERENCES public.offices(id) ON DELETE RESTRICT;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_valid;
ALTER TABLE public.users ADD CONSTRAINT users_role_valid
  CHECK (role IN ('office_boy', 'finance', 'admin', 'super_admin', 'manager'));
CREATE INDEX IF NOT EXISTS users_office_role_idx ON public.users(office_id, role);

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  related_request_id text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_user_date_idx ON public.notifications (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.device_tokens (
  token text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  platform text NOT NULL,
  language_code text NOT NULL DEFAULT 'en' CHECK (language_code IN ('en', 'ur')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.device_tokens
  ADD COLUMN IF NOT EXISTS language_code text NOT NULL DEFAULT 'en';

CREATE TABLE IF NOT EXISTS public.push_outbox (
  id uuid PRIMARY KEY REFERENCES public.notifications(id) ON DELETE CASCADE,
  attempts integer NOT NULL DEFAULT 0,
  available_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  last_error text
);
CREATE INDEX IF NOT EXISTS push_outbox_pending_idx ON public.push_outbox(available_at) WHERE sent_at IS NULL;

CREATE TABLE IF NOT EXISTS public.push_device_deliveries (
  notification_id uuid NOT NULL REFERENCES public.push_outbox(id) ON DELETE CASCADE,
  device_token text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (notification_id, device_token)
);

-- ------------------------------------------------------------------------------
-- 2. V2 PAYMENTS (ADVANCES, REIMBURSEMENTS, LEDGER)
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.advance_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE RESTRICT,
  amount numeric(12,2) NOT NULL,
  amount_requested numeric(12,2) NOT NULL,
  purpose text NOT NULL CHECK (length(trim(purpose)) BETWEEN 1 AND 2000),
  status text NOT NULL DEFAULT 'pending',
  payment_method_requested text,
  receiver_account_name text,
  receiver_account_details text,
  cleared_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  cleared_method text,
  cleared_at timestamptz,
  finance_note text,
  flow_version smallint NOT NULL DEFAULT 2,
  created_at timestamptz NOT NULL DEFAULT now()
);
-- Older installations created this table for the legacy advance-request flow.
-- Preserve those rows as version 1 while adding the version 2 columns.
ALTER TABLE public.advance_requests
  ADD COLUMN IF NOT EXISTS office_id uuid REFERENCES public.offices(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS amount_requested numeric(12,2),
  ADD COLUMN IF NOT EXISTS payment_method_requested text,
  ADD COLUMN IF NOT EXISTS receiver_account_name text,
  ADD COLUMN IF NOT EXISTS receiver_account_details text,
  ADD COLUMN IF NOT EXISTS cleared_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS cleared_method text,
  ADD COLUMN IF NOT EXISTS cleared_at timestamptz,
  ADD COLUMN IF NOT EXISTS finance_note text,
  ADD COLUMN IF NOT EXISTS flow_version smallint NOT NULL DEFAULT 1;
UPDATE public.advance_requests a
SET office_id=u.office_id,amount_requested=a.amount
FROM public.users u WHERE u.uid=a.office_boy_id
  AND (a.office_id IS NULL OR a.amount_requested IS NULL);
ALTER TABLE public.advance_requests
  ALTER COLUMN office_id SET NOT NULL,
  ALTER COLUMN amount_requested SET NOT NULL;
CREATE INDEX IF NOT EXISTS advance_requests_v2_office_status_idx ON public.advance_requests(office_id,status,created_at DESC) WHERE flow_version = 2;

-- STRICT V2 CONSTRAINTS
ALTER TABLE public.advance_requests
  DROP CONSTRAINT IF EXISTS advance_requests_status_check;
ALTER TABLE public.advance_requests
  DROP CONSTRAINT IF EXISTS advance_request_decision_valid;
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

CREATE TABLE IF NOT EXISTS public.advance_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  advance_request_id uuid NOT NULL REFERENCES public.advance_requests(id) ON DELETE RESTRICT,
  office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE RESTRICT,
  item_description text NOT NULL CHECK (length(trim(item_description)) BETWEEN 1 AND 500),
  amount_spent numeric(12,2) NOT NULL CHECK (amount_spent > 0 AND amount_spent < 10000000000),
  bill_path text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  rejection_reason text CHECK (length(trim(rejection_reason)) BETWEEN 1 AND 2000),
  reviewed_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  tagged_manager_id uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS advance_items_request_date_idx ON public.advance_items(advance_request_id,created_at DESC);

ALTER TABLE public.advance_items
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS rejection_reason text CHECK (length(trim(rejection_reason)) BETWEEN 1 AND 2000),
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS tagged_manager_id uuid REFERENCES public.users(uid) ON DELETE RESTRICT;

-- Never turn a pending item into an approved item without a Finance decision
-- and a matching advance_ledger spend entry.

CREATE TABLE IF NOT EXISTS public.advance_ledger (
  id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  advance_request_id uuid NOT NULL REFERENCES public.advance_requests(id) ON DELETE RESTRICT,
  advance_item_id uuid UNIQUE REFERENCES public.advance_items(id) ON DELETE RESTRICT,
  office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE RESTRICT,
  entry_type text NOT NULL CHECK (entry_type IN ('credit','spend')),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  actor_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT advance_ledger_source_valid CHECK (
    (entry_type = 'credit' AND advance_item_id IS NULL) OR
    (entry_type = 'spend' AND advance_item_id IS NOT NULL)
  )
);
CREATE UNIQUE INDEX IF NOT EXISTS advance_ledger_one_credit_idx ON public.advance_ledger(advance_request_id) WHERE entry_type = 'credit';
CREATE INDEX IF NOT EXISTS advance_ledger_request_date_idx ON public.advance_ledger(advance_request_id,created_at DESC,id DESC);

-- A historical direct-allot version wrote cleared_at before Office Boy
-- confirmation. Correct only still-pending records with no ledger credit.
UPDATE public.advance_requests ar SET cleared_at=NULL
WHERE ar.flow_version=2 AND ar.status='awaiting_office_boy_approval'
  AND ar.cleared_at IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.advance_ledger l
                  WHERE l.advance_request_id=ar.id AND l.entry_type='credit');

CREATE TABLE IF NOT EXISTS public.reimbursement_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE RESTRICT,
  item_description text NOT NULL CHECK (length(trim(item_description)) BETWEEN 1 AND 500),
  amount_spent numeric(12,2) NOT NULL CHECK (amount_spent > 0 AND amount_spent < 10000000000),
  bill_path text,
  payment_method_wanted text NOT NULL CHECK (payment_method_wanted IN ('cash','card')),
  receiver_account_name text CHECK (length(receiver_account_name) <= 120),
  receiver_account_details text CHECK (length(receiver_account_details) <= 500),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','paid')),
  rejection_reason text CHECK (length(trim(rejection_reason)) BETWEEN 1 AND 2000),
  reviewed_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  paid_method text CHECK (paid_method IN ('cash','card')),
  paid_at timestamptz,
  tagged_manager_id uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.reimbursement_requests
  ADD COLUMN IF NOT EXISTS tagged_manager_id uuid
    REFERENCES public.users(uid) ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS reimbursements_office_status_idx ON public.reimbursement_requests(office_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS reimbursements_owner_date_idx ON public.reimbursement_requests(office_boy_id,created_at DESC);

CREATE TABLE IF NOT EXISTS public.core_payment_activity (
  id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  advance_request_id uuid REFERENCES public.advance_requests(id) ON DELETE RESTRICT,
  reimbursement_id uuid REFERENCES public.reimbursement_requests(id) ON DELETE RESTRICT,
  office_boy_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE RESTRICT,
  actor_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  action text NOT NULL,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_activity_one_source CHECK ((advance_request_id IS NULL) <> (reimbursement_id IS NULL))
);
CREATE INDEX IF NOT EXISTS core_activity_advance_idx ON public.core_payment_activity(advance_request_id,created_at,id);
CREATE INDEX IF NOT EXISTS core_activity_reimbursement_idx ON public.core_payment_activity(reimbursement_id,created_at,id);

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS related_core_advance_id uuid REFERENCES public.advance_requests(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS related_reimbursement_id uuid REFERENCES public.reimbursement_requests(id) ON DELETE SET NULL;


-- ------------------------------------------------------------------------------
-- 3. HELPER FUNCTIONS
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.current_user_role() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT role FROM public.users WHERE uid = auth.uid() AND "isActive" = true
$$;

CREATE OR REPLACE FUNCTION public.current_office_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT office_id FROM public.users WHERE uid = auth.uid() AND "isActive"
$$;

CREATE OR REPLACE FUNCTION public.payment_amount_valid(value numeric) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=public AS $$
  SELECT value IS NOT NULL AND value::text NOT IN ('NaN','Infinity','-Infinity')
    AND value>0 AND value<10000000000 AND value=round(value,2)
$$;


-- ------------------------------------------------------------------------------
-- 4. TRIGGERS & HISTORY PROTECTION
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.prevent_payment_history_change() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF auth.role() = 'service_role' AND current_setting('app.allow_account_data_purge', true) = 'on' THEN
    RETURN OLD;
  END IF;

  -- LATEST LOGIC: Allow updates to advance_items if ONLY the status and review fields are changing
  IF TG_TABLE_NAME = 'advance_items' AND TG_OP = 'UPDATE' THEN
    IF NEW.advance_request_id = OLD.advance_request_id AND
       NEW.office_boy_id = OLD.office_boy_id AND
       NEW.office_id = OLD.office_id AND
       NEW.item_description = OLD.item_description AND
       NEW.amount_spent = OLD.amount_spent AND
       NEW.bill_path IS NOT DISTINCT FROM OLD.bill_path AND
       NEW.tagged_manager_id IS NOT DISTINCT FROM OLD.tagged_manager_id AND
       NEW.created_at = OLD.created_at THEN
      RETURN NEW;
    END IF;
  END IF;

  RAISE EXCEPTION 'Payment history cannot be changed or deleted' USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS advance_items_immutable ON public.advance_items;
CREATE TRIGGER advance_items_immutable BEFORE UPDATE OR DELETE ON public.advance_items FOR EACH ROW EXECUTE FUNCTION public.prevent_payment_history_change();
DROP TRIGGER IF EXISTS advance_ledger_immutable ON public.advance_ledger;
CREATE TRIGGER advance_ledger_immutable BEFORE UPDATE OR DELETE ON public.advance_ledger FOR EACH ROW EXECUTE FUNCTION public.prevent_payment_history_change();
DROP TRIGGER IF EXISTS core_activity_immutable ON public.core_payment_activity;
CREATE TRIGGER core_activity_immutable BEFORE UPDATE OR DELETE ON public.core_payment_activity FOR EACH ROW EXECUTE FUNCTION public.prevent_payment_history_change();


-- ------------------------------------------------------------------------------
-- 5. V2 CORE BUSINESS LOGIC (MERGED & LATEST)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.core_advance_balance(p_request_id uuid) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(sum(CASE entry_type WHEN 'credit' THEN amount ELSE -amount END),0)
  FROM public.advance_ledger WHERE advance_request_id = p_request_id
$$;

-- 5A. Direct Allotment (Requires Office Boy Approval)
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
    OR p_method IS NULL OR p_method NOT IN ('cash','card')
  THEN RAISE EXCEPTION 'Check the amount, purpose and payment details'; END IF;

  SELECT * INTO result FROM public.advance_requests WHERE id = p_id;
  IF FOUND THEN
    IF result.office_boy_id <> boy.uid OR result.amount_requested <> p_amount
       OR result.purpose <> trim(p_purpose)
       OR result.payment_method_requested <> p_method
       OR result.flow_version <> 2
    THEN RAISE EXCEPTION 'Advance reference already used'; END IF;
    RETURN result;
  END IF;

  INSERT INTO public.advance_requests(id,office_boy_id,office_id,amount,amount_requested,purpose,status,
    payment_method_requested,flow_version,cleared_by,cleared_method,cleared_at)
  VALUES(p_id,boy.uid,boy.office_id,p_amount,p_amount,trim(p_purpose),'awaiting_office_boy_approval',p_method,2,actor.uid,p_method,NULL)
  RETURNING * INTO result;

  INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action,detail)
  VALUES(result.id,result.office_boy_id,result.office_id,actor.uid,'direct_allot_pending',jsonb_build_object('method',p_method));

  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  VALUES(boy.uid,'Advance needs approval','Finance sent you an advance of PKR '||p_amount||'. Tap to approve.',result.id);

  RETURN result;
END $$;

-- 5B. Office Boy action on Direct Allotment
CREATE OR REPLACE FUNCTION public.respond_to_direct_advance_v2(
  p_id uuid, p_decision text
) RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; result public.advance_requests; finance public.users;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy can approve advances' USING ERRCODE='42501'; END IF;

  IF p_decision IS NULL OR p_decision NOT IN ('approve','decline') THEN
    RAISE EXCEPTION 'Decision must be approve or decline';
  END IF;

  SELECT * INTO result FROM public.advance_requests WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Advance not found'; END IF;
  IF result.office_boy_id <> actor.uid THEN RAISE EXCEPTION 'Not your advance'; END IF;
  IF result.status <> 'awaiting_office_boy_approval' THEN RAISE EXCEPTION 'Advance is not awaiting approval'; END IF;

  SELECT * INTO finance FROM public.users WHERE uid=result.cleared_by;

  IF p_decision = 'approve' THEN
    UPDATE public.advance_requests SET status='cleared', cleared_at=now()
    WHERE id=p_id RETURNING * INTO result;

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

-- 5C. Request Advance (Bank details optional)
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
    OR (p_method='card' AND (length(trim(coalesce(p_account_name,''))) NOT BETWEEN 1 AND 120
      OR length(trim(coalesce(p_account_details,''))) NOT BETWEEN 1 AND 500))
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

-- 5D. Clear Advance Request
CREATE OR REPLACE FUNCTION public.clear_advance_request_v2(p_id uuid,p_method text,p_note text DEFAULT NULL)
RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; result public.advance_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance can clear advances' USING ERRCODE='42501'; END IF;
  SELECT * INTO result FROM public.advance_requests WHERE id=p_id FOR UPDATE;
  IF NOT FOUND OR result.flow_version<>2 THEN RAISE EXCEPTION 'Advance request not found'; END IF;
  IF result.status<>'pending' THEN RAISE EXCEPTION 'This advance is no longer waiting'; END IF;
  IF p_method IS DISTINCT FROM result.payment_method_requested OR length(coalesce(p_note,''))>2000 THEN
    RAISE EXCEPTION 'Use the requested Cash or Card method'; END IF;
  UPDATE public.advance_requests SET status='cleared',cleared_by=actor.uid,cleared_method=p_method,
    cleared_at=now(),finance_note=nullif(trim(p_note),'') WHERE id=p_id RETURNING * INTO result;
  INSERT INTO public.advance_ledger(advance_request_id,office_boy_id,office_id,entry_type,amount,actor_id)
  VALUES(result.id,result.office_boy_id,result.office_id,'credit',result.amount_requested,actor.uid);
  INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action,
    detail) VALUES(result.id,result.office_boy_id,result.office_id,actor.uid,'cleared',
    jsonb_build_object('method',p_method));
  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  VALUES(result.office_boy_id,'Advance sent','Finance marked your advance as sent.',result.id);
  RETURN result;
END $$;

-- 5E. Log Advance Item (Creates as PENDING, no immediate deduction)
CREATE OR REPLACE FUNCTION public.log_advance_item_v2(
  p_id uuid, p_advance_id uuid, p_item text, p_amount numeric, p_bill_path text DEFAULT NULL,
  p_tagged_manager_id uuid DEFAULT NULL
) RETURNS public.advance_items LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; advance public.advance_requests; result public.advance_items; balance numeric;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy can add advance items' USING ERRCODE='42501'; END IF;

  IF p_id IS NULL OR NOT public.payment_amount_valid(p_amount)
    OR length(trim(coalesce(p_item,''))) NOT BETWEEN 1 AND 500
    OR (p_bill_path IS NOT NULL AND (p_bill_path NOT LIKE actor.uid::text||'/%' OR p_bill_path LIKE '%..%'))
  THEN RAISE EXCEPTION 'Check the item and amount'; END IF;
  IF p_tagged_manager_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE uid=p_tagged_manager_id AND role='manager' AND "isActive"
  ) THEN RAISE EXCEPTION 'Select an active manager'; END IF;

  SELECT * INTO result FROM public.advance_items WHERE id=p_id;
  IF FOUND THEN
    IF result.office_boy_id<>actor.uid OR result.advance_request_id<>p_advance_id
      OR result.item_description<>trim(p_item) OR result.amount_spent<>p_amount
      OR result.bill_path IS DISTINCT FROM p_bill_path
      OR result.tagged_manager_id IS DISTINCT FROM p_tagged_manager_id
    THEN RAISE EXCEPTION 'Item reference already used'; END IF;
    RETURN result;
  END IF;

  SELECT * INTO advance FROM public.advance_requests WHERE id=p_advance_id FOR UPDATE;
  IF NOT FOUND OR advance.flow_version<>2 OR advance.office_boy_id<>actor.uid
    OR advance.office_id<>actor.office_id THEN RAISE EXCEPTION 'Advance not found' USING ERRCODE='42501'; END IF;
  IF advance.status<>'cleared' THEN RAISE EXCEPTION 'This advance is not available for spending'; END IF;

  balance := public.core_advance_balance(p_advance_id);
  IF p_amount > balance THEN RAISE EXCEPTION 'This exceeds your remaining advance balance'; END IF;

  INSERT INTO public.advance_items(id, advance_request_id, office_boy_id, office_id, item_description, amount_spent, bill_path, status, tagged_manager_id)
  VALUES(p_id, p_advance_id, actor.uid, actor.office_id, trim(p_item), p_amount, p_bill_path, 'pending', p_tagged_manager_id) RETURNING * INTO result;

  INSERT INTO public.core_payment_activity(advance_request_id, office_boy_id, office_id, actor_id, action, detail)
  VALUES(p_advance_id, actor.uid, actor.office_id, actor.uid, 'item_added',
    jsonb_build_object('item_id', result.id, 'amount', p_amount, 'item', result.item_description, 'status', 'pending'));

  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  SELECT uid,'New Advance Item',actor.name||' submitted an advance item for PKR '||p_amount||' for review.',p_advance_id
  FROM public.users WHERE "isActive" AND role='finance';

  IF p_tagged_manager_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
    VALUES (p_tagged_manager_id,'New Tagged Purchase',
      actor.name||' logged a purchase tagged to you for: '||trim(p_item),p_advance_id);
  END IF;

  RETURN result;
END $$;

-- 5F. Review Advance Item (Deducts money ONLY when APPROVED)
CREATE OR REPLACE FUNCTION public.review_advance_item_v2(
  p_item_id uuid, p_decision text, p_reason text DEFAULT NULL
) RETURNS public.advance_items LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; result public.advance_items; advance public.advance_requests; balance numeric;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance can review advance items' USING ERRCODE='42501'; END IF;

  IF p_decision IS NULL OR p_decision NOT IN ('approve','reject') OR (p_decision='reject'
    AND length(trim(coalesce(p_reason,''))) NOT BETWEEN 1 AND 2000) THEN RAISE EXCEPTION 'Add a reason when rejecting'; END IF;

  SELECT * INTO result FROM public.advance_items WHERE id=p_item_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Advance item not found'; END IF;
  IF result.status<>'pending' THEN RAISE EXCEPTION 'This item has already been reviewed'; END IF;

  -- Serialize all decisions for one advance, then recheck the actual ledger.
  -- A submission-time check alone cannot prevent two pending items from
  -- spending more than the available advance when both are later approved.
  SELECT * INTO advance FROM public.advance_requests
  WHERE id = result.advance_request_id FOR UPDATE;
  IF p_decision = 'approve' THEN
    balance := public.core_advance_balance(result.advance_request_id);
    IF result.amount_spent > balance THEN
      RAISE EXCEPTION 'Insufficient advance balance for this approval';
    END IF;
  END IF;

  UPDATE public.advance_items SET status=CASE WHEN p_decision='approve' THEN 'approved' ELSE 'rejected' END,
    rejection_reason=CASE WHEN p_decision='reject' THEN trim(p_reason) END,
    reviewed_by=actor.uid, reviewed_at=now() WHERE id=p_item_id RETURNING * INTO result;

  IF p_decision = 'approve' THEN
    INSERT INTO public.advance_ledger(advance_request_id, advance_item_id, office_boy_id, office_id, entry_type, amount, actor_id)
    VALUES(result.advance_request_id, result.id, result.office_boy_id, result.office_id, 'spend', result.amount_spent, actor.uid);

    balance := public.core_advance_balance(result.advance_request_id);
    IF balance <= 0 THEN
      UPDATE public.advance_requests SET status='fully_utilized' WHERE id=result.advance_request_id;
    END IF;
  END IF;

  INSERT INTO public.core_payment_activity(advance_request_id, office_boy_id, office_id, actor_id, action, detail)
  VALUES(result.advance_request_id, result.office_boy_id, result.office_id, actor.uid, 'item_' || p_decision,
    jsonb_build_object('item_id', result.id, 'reason', result.rejection_reason));

  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  VALUES(result.office_boy_id, CASE WHEN p_decision='approve' THEN 'Advance Item Approved' ELSE 'Advance Item Rejected' END,
    CASE WHEN p_decision='approve' THEN 'Finance approved your advance item.'
      ELSE 'Finance rejected your advance item: '||result.rejection_reason END, result.advance_request_id);

  IF result.tagged_manager_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
    VALUES(result.tagged_manager_id,
      CASE WHEN p_decision='approve' THEN 'Tagged purchase approved' ELSE 'Tagged purchase rejected' END,
      'Finance '||CASE WHEN p_decision='approve' THEN 'approved' ELSE 'rejected' END||
      ' the PKR '||result.amount_spent||' tagged purchase.',result.advance_request_id);
  END IF;

  RETURN result;
END $$;

-- 5G. Submit Reimbursement (Bank info optional)
CREATE OR REPLACE FUNCTION public.submit_reimbursement_v2(
  p_id uuid,p_item text,p_amount numeric,p_method text,p_bill_path text DEFAULT NULL,
  p_account_name text DEFAULT NULL,p_account_details text DEFAULT NULL,
  p_tagged_manager_id uuid DEFAULT NULL
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
  IF p_tagged_manager_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE uid=p_tagged_manager_id AND role='manager' AND "isActive"
  ) THEN RAISE EXCEPTION 'Select an active manager'; END IF;
  SELECT * INTO result FROM public.reimbursement_requests WHERE id=p_id;
  IF FOUND THEN
    IF result.office_boy_id<>actor.uid OR result.item_description<>trim(p_item)
      OR result.amount_spent<>p_amount OR result.payment_method_wanted<>p_method
      OR result.bill_path IS DISTINCT FROM p_bill_path
      OR result.receiver_account_name IS DISTINCT FROM nullif(trim(p_account_name),'')
      OR result.receiver_account_details IS DISTINCT FROM nullif(trim(p_account_details),'')
      OR result.tagged_manager_id IS DISTINCT FROM p_tagged_manager_id
    THEN RAISE EXCEPTION 'Request reference already used'; END IF;
    RETURN result;
  END IF;
  INSERT INTO public.reimbursement_requests(id,office_boy_id,office_id,item_description,amount_spent,bill_path,
    payment_method_wanted,receiver_account_name,receiver_account_details, tagged_manager_id)
  VALUES(p_id,actor.uid,actor.office_id,trim(p_item),p_amount,p_bill_path,p_method,
    nullif(trim(p_account_name),''),nullif(trim(p_account_details),''), p_tagged_manager_id) RETURNING * INTO result;
  INSERT INTO public.core_payment_activity(reimbursement_id,office_boy_id,office_id,actor_id,action)
  VALUES(result.id,actor.uid,actor.office_id,actor.uid,'requested');
  INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
  SELECT uid,'Repayment requested',actor.name||' requested PKR '||p_amount||' repayment.',result.id
  FROM public.users WHERE "isActive" AND role='finance';
  IF p_tagged_manager_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
    VALUES(p_tagged_manager_id,'New Tagged Reimbursement',
      actor.name||' requested a reimbursement tagged to you for: '||trim(p_item),result.id);
  END IF;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.review_reimbursement_v2(p_id uuid,p_decision text,p_reason text DEFAULT NULL)
RETURNS public.reimbursement_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.reimbursement_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance can review repayments' USING ERRCODE='42501'; END IF;
  IF p_decision IS NULL OR p_decision NOT IN ('approve','reject') OR (p_decision='reject'
    AND length(trim(coalesce(p_reason,''))) NOT BETWEEN 1 AND 2000) THEN RAISE EXCEPTION 'Add a reason when rejecting'; END IF;
  SELECT * INTO result FROM public.reimbursement_requests WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Repayment request not found'; END IF;
  IF result.status<>'pending' THEN RAISE EXCEPTION 'This request has already been reviewed'; END IF;
  UPDATE public.reimbursement_requests SET status=CASE WHEN p_decision='approve' THEN 'approved' ELSE 'rejected' END,
    rejection_reason=CASE WHEN p_decision='reject' THEN trim(p_reason) END,
    reviewed_by=actor.uid,reviewed_at=now(),updated_at=now() WHERE id=p_id RETURNING * INTO result;
  INSERT INTO public.core_payment_activity(reimbursement_id,office_boy_id,office_id,actor_id,action,detail)
  VALUES(result.id,result.office_boy_id,result.office_id,actor.uid,p_decision,
    jsonb_build_object('reason',result.rejection_reason));
  INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
  VALUES(result.office_boy_id,CASE WHEN p_decision='approve' THEN 'Repayment approved' ELSE 'Repayment rejected' END,
    CASE WHEN p_decision='approve' THEN 'Finance approved your repayment request.'
      ELSE 'Finance rejected your request: '||result.rejection_reason END,result.id);

  IF result.tagged_manager_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
    VALUES(result.tagged_manager_id,
      CASE WHEN p_decision='approve' THEN 'Tagged repayment approved' ELSE 'Tagged repayment rejected' END,
      'Finance '||CASE WHEN p_decision='approve' THEN 'approved' ELSE 'rejected' END||
      ' the PKR '||result.amount_spent||' tagged repayment.',result.id);
  END IF;

  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.mark_reimbursement_paid_v2(p_id uuid,p_method text)
RETURNS public.reimbursement_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.reimbursement_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance can mark repayments paid' USING ERRCODE='42501'; END IF;
  IF p_method IS NULL OR p_method NOT IN ('cash','card') THEN RAISE EXCEPTION 'Choose Cash or Card'; END IF;
  SELECT * INTO result FROM public.reimbursement_requests WHERE id=p_id FOR UPDATE;
  IF NOT FOUND OR result.status<>'approved' THEN RAISE EXCEPTION 'Only approved requests can be marked paid'; END IF;
  UPDATE public.reimbursement_requests SET status='paid',paid_method=p_method,paid_at=now(),updated_at=now()
  WHERE id=p_id RETURNING * INTO result;
  INSERT INTO public.core_payment_activity(reimbursement_id,office_boy_id,office_id,actor_id,action,detail)
  VALUES(result.id,result.office_boy_id,result.office_id,actor.uid,'paid',jsonb_build_object('method',p_method));
  INSERT INTO public.notifications(user_id,title,message,related_reimbursement_id)
  VALUES(result.office_boy_id,'Repayment paid','Finance marked your repayment as paid.',result.id);
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.advance_balances_v2()
RETURNS TABLE(advance_request_id uuid,office_boy_id uuid,office_id uuid,total numeric,spent numeric,remaining numeric,item_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE role_name text;
BEGIN
  role_name:=public.current_user_role();
  IF role_name IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT a.id,a.office_boy_id,a.office_id,a.amount_requested,
    coalesce(sum(i.amount_spent),0),public.core_advance_balance(a.id),count(i.id)
  FROM public.advance_requests a LEFT JOIN public.advance_items i ON i.advance_request_id=a.id AND i.status='approved'
  WHERE a.flow_version=2 AND a.status IN ('cleared','fully_utilized')
    AND (role_name IN ('finance','admin','super_admin')
      OR (a.office_boy_id=auth.uid() AND a.office_id=public.current_office_id()))
  GROUP BY a.id,a.office_boy_id,a.office_id,a.amount_requested,a.created_at
  ORDER BY a.created_at DESC;
END $$;


-- ------------------------------------------------------------------------------
-- 6. SECURITY & GRANTS
-- ------------------------------------------------------------------------------

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_device_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.advance_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.advance_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.advance_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reimbursement_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.core_payment_activity ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.users, public.offices, public.notifications, public.device_tokens,
  public.push_outbox, public.push_device_deliveries, public.advance_requests, public.advance_items, public.advance_ledger,
  public.reimbursement_requests, public.core_payment_activity FROM anon, authenticated, PUBLIC;

GRANT SELECT ON public.users, public.offices, public.advance_requests, public.advance_items,
  public.advance_ledger, public.reimbursement_requests, public.core_payment_activity
  TO authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE(is_read), DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.users, public.offices, public.notifications, public.device_tokens,
  public.push_outbox, public.push_device_deliveries, public.advance_requests, public.advance_items, public.advance_ledger,
  public.reimbursement_requests, public.core_payment_activity TO service_role;

DROP POLICY IF EXISTS users_read ON public.users;
CREATE POLICY users_read ON public.users FOR SELECT TO authenticated
USING (uid = auth.uid() OR public.current_user_role() IN ('super_admin', 'admin', 'finance', 'manager') OR role = 'manager');

DROP POLICY IF EXISTS offices_read ON public.offices;
CREATE POLICY offices_read ON public.offices FOR SELECT TO authenticated
USING (public.current_user_role() IN ('finance', 'admin', 'super_admin') OR id = public.current_office_id());

DROP POLICY IF EXISTS notifications_read ON public.notifications;
CREATE POLICY notifications_read ON public.notifications FOR SELECT TO authenticated
USING (user_id = auth.uid() AND public.current_user_role() IS NOT NULL);

-- Remove older V2 policies first. PostgreSQL combines multiple SELECT
-- policies with OR, so leaving an old broad policy would undo the limits below.
DO $policies$
DECLARE p record;
BEGIN
  FOR p IN SELECT tablename, policyname FROM pg_policies
    WHERE schemaname='public' AND tablename IN
      ('advance_requests','advance_items','advance_ledger',
       'reimbursement_requests','core_payment_activity')
  LOOP
    EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,p.tablename);
  END LOOP;
END $policies$;

DROP POLICY IF EXISTS advance_requests_read ON public.advance_requests;
CREATE POLICY advance_requests_read ON public.advance_requests FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id()) OR
  (public.current_user_role() = 'manager' AND EXISTS (
    SELECT 1 FROM public.advance_items ai
    WHERE ai.advance_request_id = advance_requests.id
      AND ai.tagged_manager_id = auth.uid()
  ))
);

DROP POLICY IF EXISTS advance_items_read ON public.advance_items;
CREATE POLICY advance_items_read ON public.advance_items FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id()) OR
  (public.current_user_role() = 'manager' AND tagged_manager_id = auth.uid())
);

DROP POLICY IF EXISTS advance_ledger_read ON public.advance_ledger;
CREATE POLICY advance_ledger_read ON public.advance_ledger FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id()) OR
  (public.current_user_role() = 'manager' AND entry_type='spend' AND EXISTS (
    SELECT 1 FROM public.advance_items ai
    WHERE ai.id = advance_ledger.advance_item_id
      AND ai.tagged_manager_id = auth.uid()
  ))
);

DROP POLICY IF EXISTS reimbursements_read ON public.reimbursement_requests;
CREATE POLICY reimbursements_read ON public.reimbursement_requests FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id()) OR
  (public.current_user_role() = 'manager' AND tagged_manager_id = auth.uid())
);

DROP POLICY IF EXISTS core_activity_read ON public.core_payment_activity;
CREATE POLICY core_activity_read ON public.core_payment_activity FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id()) OR
  (public.current_user_role() = 'manager' AND (
    EXISTS(SELECT 1 FROM public.advance_items ai
      WHERE ai.id::text = core_payment_activity.detail->>'item_id'
        AND ai.tagged_manager_id = auth.uid()) OR
    EXISTS(SELECT 1 FROM public.reimbursement_requests rr WHERE rr.id = core_payment_activity.reimbursement_id AND rr.tagged_manager_id = auth.uid())
  ))
);

REVOKE ALL ON FUNCTION public.current_user_role(), public.current_office_id(), public.payment_amount_valid(numeric),
  public.core_advance_balance(uuid), public.request_advance_v2(uuid,text,numeric,text,text,text),
  public.direct_allot_advance_v2(uuid,uuid,numeric,text,text), public.respond_to_direct_advance_v2(uuid,text),
  public.clear_advance_request_v2(uuid,text,text), public.log_advance_item_v2(uuid,uuid,text,numeric,text,uuid),
  public.review_advance_item_v2(uuid,text,text), public.advance_balances_v2(),
  public.submit_reimbursement_v2(uuid,text,numeric,text,text,text,text,uuid),
  public.review_reimbursement_v2(uuid,text,text), public.mark_reimbursement_paid_v2(uuid,text)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.current_user_role(), public.current_office_id(),
  public.request_advance_v2(uuid,text,numeric,text,text,text),
  public.direct_allot_advance_v2(uuid,uuid,numeric,text,text), public.respond_to_direct_advance_v2(uuid,text),
  public.clear_advance_request_v2(uuid,text,text), public.log_advance_item_v2(uuid,uuid,text,numeric,text,uuid),
  public.review_advance_item_v2(uuid,text,text), public.advance_balances_v2(),
  public.submit_reimbursement_v2(uuid,text,numeric,text,text,text,text,uuid),
  public.review_reimbursement_v2(uuid,text,text), public.mark_reimbursement_paid_v2(uuid,text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ------------------------------------------------------------------------------
-- 7. AUTH TRIGGER (SYNC TO PUBLIC.USERS)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_auth_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE requested_role text; active boolean; existing public.users; requested_office uuid;
BEGIN
  requested_role := NEW.raw_app_meta_data->>'petty_cash_role';
  IF requested_role IS NULL THEN RETURN NEW; END IF;
  IF requested_role NOT IN ('office_boy','finance','admin','super_admin','manager') THEN RAISE EXCEPTION 'Invalid app role'; END IF;

  active := coalesce((NEW.raw_app_meta_data->>'petty_cash_active')::boolean,true);

  -- Advisory lock to prevent race conditions during concurrent user creation
  PERFORM pg_advisory_xact_lock(72624401);

  SELECT * INTO existing FROM public.users WHERE uid=NEW.id;

  IF existing.role='super_admin' AND existing."isActive" AND (requested_role<>'super_admin' OR NOT active)
    AND NOT EXISTS(SELECT 1 FROM public.users WHERE role='super_admin' AND "isActive" AND uid<>NEW.id)
  THEN
    RAISE EXCEPTION 'The last active super-admin cannot be disabled or demoted';
  END IF;

  requested_office := coalesce(nullif(NEW.raw_app_meta_data->>'petty_cash_office_id','')::uuid,
    existing.office_id,'00000000-0000-0000-0000-000000000001'::uuid);

  IF NOT EXISTS (SELECT 1 FROM public.offices WHERE id=requested_office) THEN
    RAISE EXCEPTION 'Office not found';
  END IF;

  -- Check if office boy has history before changing office
  IF existing.uid IS NOT NULL AND existing.office_id IS DISTINCT FROM requested_office
    AND existing.role = 'office_boy' AND (
      EXISTS(SELECT 1 FROM public.advance_requests WHERE office_boy_id=NEW.id)
      OR EXISTS(SELECT 1 FROM public.reimbursement_requests WHERE office_boy_id=NEW.id)
    ) THEN
    RAISE EXCEPTION 'An Office Boy with financial history cannot change office';
  END IF;

  INSERT INTO public.users(uid,name,email,role,"isActive",office_id)
  VALUES(NEW.id,coalesce(nullif(trim(NEW.raw_user_meta_data->>'name'),''),existing.name,'Staff member'),
    NEW.email,requested_role,active,requested_office)
  ON CONFLICT(uid) DO UPDATE SET name=EXCLUDED.name,email=EXCLUDED.email,role=EXCLUDED.role,
    "isActive"=EXCLUDED."isActive",office_id=EXCLUDED.office_id;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.sync_auth_profile();

DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.sync_auth_profile();

-- The app sends tagged_manager_id, so retire ambiguous older RPC overloads.
DROP FUNCTION IF EXISTS public.log_advance_item_v2(uuid,uuid,text,numeric,text);
DROP FUNCTION IF EXISTS public.submit_reimbursement_v2(uuid,text,numeric,text,text,text,text);
DROP FUNCTION IF EXISTS public.direct_allot_advance_v2(uuid,uuid,numeric,text,text,uuid);

-- Each core activity reaches active Admin and Super Admin accounts in every
-- office. The activity/recipient pair prevents duplicate fan-out on retries.
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS source_activity_id bigint
    REFERENCES public.core_payment_activity(id) ON DELETE SET NULL;
CREATE UNIQUE INDEX IF NOT EXISTS notifications_activity_recipient_unique
  ON public.notifications(source_activity_id,user_id)
  WHERE source_activity_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.notify_admins_of_core_payment_activity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $$
DECLARE actor_name text; event_title text;
BEGIN
  SELECT name INTO actor_name FROM public.users WHERE uid=NEW.actor_id;
  actor_name := coalesce(nullif(actor_name,''),'A team member');
  event_title := CASE NEW.action
    WHEN 'requested' THEN 'Payment request submitted'
    WHEN 'direct_allot_pending' THEN 'Advance sent for approval'
    WHEN 'approved_by_boy' THEN 'Advance received'
    WHEN 'declined_by_boy' THEN 'Advance declined'
    WHEN 'cleared' THEN 'Advance sent'
    WHEN 'item_added' THEN 'Purchase submitted'
    WHEN 'item_approved' THEN 'Purchase approved'
    WHEN 'item_approve' THEN 'Purchase approved'
    WHEN 'item_rejected' THEN 'Purchase rejected'
    WHEN 'item_reject' THEN 'Purchase rejected'
    WHEN 'approve' THEN 'Repayment approved'
    WHEN 'reject' THEN 'Repayment rejected'
    WHEN 'paid' THEN 'Repayment paid'
    ELSE 'Payment updated'
  END;
  INSERT INTO public.notifications(user_id,title,message,
    related_core_advance_id,related_reimbursement_id,source_activity_id)
  SELECT u.uid,event_title,
    actor_name||': '||event_title||'. Tap to view details.',
    NEW.advance_request_id,NEW.reimbursement_id,NEW.id
  FROM public.users u
  WHERE u."isActive" AND u.role IN ('admin','super_admin')
    AND u.uid<>NEW.actor_id
  ON CONFLICT(source_activity_id,user_id)
    WHERE source_activity_id IS NOT NULL DO NOTHING;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS petty_cash_admin_core_activity
  ON public.core_payment_activity;
CREATE TRIGGER petty_cash_admin_core_activity
AFTER INSERT ON public.core_payment_activity FOR EACH ROW
EXECUTE FUNCTION public.notify_admins_of_core_payment_activity();
REVOKE ALL ON FUNCTION public.notify_admins_of_core_payment_activity()
  FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.queue_push() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  INSERT INTO public.push_outbox(id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS petty_cash_queue_push ON public.notifications;
CREATE TRIGGER petty_cash_queue_push AFTER INSERT ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.queue_push();
REVOKE ALL ON FUNCTION public.queue_push() FROM PUBLIC,anon,authenticated;

DROP FUNCTION IF EXISTS public.claim_push_batch();
CREATE FUNCTION public.claim_push_batch()
RETURNS TABLE(id uuid,user_id uuid,request_id text,
  core_advance_id uuid,reimbursement_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $$
  WITH claimed AS (
    SELECT o.id FROM public.push_outbox o
    WHERE o.sent_at IS NULL AND o.attempts<8 AND o.available_at<=now()
    ORDER BY o.available_at LIMIT 50 FOR UPDATE SKIP LOCKED
  ), leased AS (
    UPDATE public.push_outbox o SET attempts=o.attempts+1,
      available_at=now()+interval '5 minutes'
    FROM claimed WHERE o.id=claimed.id RETURNING o.id
  )
  SELECT n.id,n.user_id,n.related_request_id,
    n.related_core_advance_id,n.related_reimbursement_id
  FROM leased JOIN public.notifications n USING(id)
$$;
REVOKE ALL ON FUNCTION public.claim_push_batch()
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_batch() TO service_role;

-- Service-role account purge covers the legacy and current payment tables.
-- Other people's financial history is never removed with this account.
CREATE OR REPLACE FUNCTION public.delete_office_boy_data(p_uid uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $$
DECLARE
  request_ids text[];
  advance_request_ids uuid[];
  advance_ids uuid[];
  expense_ids uuid[];
  reimbursement_ids uuid[];
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
  END IF;
  PERFORM 1 FROM public.users WHERE uid=p_uid AND role='office_boy' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Office Boy account not found'; END IF;

  IF EXISTS(SELECT 1 FROM public.advances
            WHERE given_by=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.expenses
            WHERE reviewed_by=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.advance_requests
            WHERE decided_by=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.advance_requests
            WHERE cleared_by=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.advance_items
            WHERE reviewed_by=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.advance_items
            WHERE tagged_manager_id=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.advance_ledger
            WHERE actor_id=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.reimbursement_requests
            WHERE reviewed_by=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.reimbursement_requests
            WHERE tagged_manager_id=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.core_payment_activity
            WHERE actor_id=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.float_ledger
            WHERE actor_id=p_uid AND office_boy_id<>p_uid)
     OR EXISTS(SELECT 1 FROM public.payment_activity
            WHERE actor_id=p_uid AND office_boy_id<>p_uid)
  THEN
    RAISE EXCEPTION 'This account is referenced by another user financial history';
  END IF;

  UPDATE public.users SET "isActive"=false WHERE uid=p_uid;
  SELECT coalesce(array_agg(id),ARRAY[]::text[]) INTO request_ids
  FROM (
    SELECT id FROM public.requests WHERE "requestedBy"=p_uid
    UNION
    SELECT request_id FROM public.request_deletion_audit
    WHERE request_snapshot->>'requestedBy'=p_uid::text
  ) own_requests;
  SELECT coalesce(array_agg(id),ARRAY[]::uuid[]) INTO advance_request_ids
  FROM public.advance_requests WHERE office_boy_id=p_uid;
  SELECT coalesce(array_agg(id),ARRAY[]::uuid[]) INTO advance_ids
  FROM public.advances WHERE office_boy_id=p_uid;
  SELECT coalesce(array_agg(id),ARRAY[]::uuid[]) INTO expense_ids
  FROM public.expenses WHERE office_boy_id=p_uid;
  SELECT coalesce(array_agg(id),ARRAY[]::uuid[]) INTO reimbursement_ids
  FROM public.reimbursement_requests WHERE office_boy_id=p_uid;

  DELETE FROM public.notifications
  WHERE user_id=p_uid
     OR related_request_id=ANY(request_ids)
     OR related_advance_request_id=ANY(advance_request_ids)
     OR related_core_advance_id=ANY(advance_request_ids)
     OR related_advance_id=ANY(advance_ids)
     OR related_expense_id=ANY(expense_ids)
     OR related_reimbursement_id=ANY(reimbursement_ids);
  DELETE FROM public.device_tokens WHERE user_id=p_uid;
  DELETE FROM public.request_deletion_audit
    WHERE request_id=ANY(request_ids);
  DELETE FROM public.requests WHERE "requestedBy"=p_uid;

  PERFORM set_config('app.allow_account_data_purge','on',true);
  DELETE FROM public.core_payment_activity WHERE office_boy_id=p_uid;
  DELETE FROM public.advance_ledger WHERE office_boy_id=p_uid;
  DELETE FROM public.advance_items WHERE office_boy_id=p_uid;
  DELETE FROM public.reimbursement_requests WHERE office_boy_id=p_uid;
  DELETE FROM public.advance_requests WHERE office_boy_id=p_uid;
  DELETE FROM public.payment_activity WHERE office_boy_id=p_uid;
  DELETE FROM public.float_ledger WHERE office_boy_id=p_uid;
  DELETE FROM public.expenses WHERE office_boy_id=p_uid;
  DELETE FROM public.advances WHERE office_boy_id=p_uid;
END $$;
REVOKE ALL ON FUNCTION public.delete_office_boy_data(uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.delete_office_boy_data(uuid)
  TO service_role;

NOTIFY pgrst,'reload schema';
COMMIT;

-- Read-only post-run check. Zero in all anomaly counts is the target.
SELECT
  'applied' AS master_upgrade,
  (SELECT count(*) FROM public.advance_items i
   WHERE i.status='approved' AND NOT EXISTS (
     SELECT 1 FROM public.advance_ledger l
     WHERE l.advance_item_id=i.id AND l.entry_type='spend'
   )) AS approved_items_without_spend,
  (SELECT count(*) FROM public.advance_requests a
   WHERE a.flow_version=2 AND public.core_advance_balance(a.id)<0
  ) AS advances_with_negative_balance,
  (SELECT count(*) FROM public.advance_requests a
   WHERE a.flow_version=2 AND a.status='awaiting_office_boy_approval'
     AND EXISTS(SELECT 1 FROM public.advance_ledger l
                WHERE l.advance_request_id=a.id AND l.entry_type='credit')
  ) AS unconfirmed_advances_already_credited,
  EXISTS(SELECT 1 FROM pg_trigger
         WHERE tgrelid='public.core_payment_activity'::regclass
           AND tgname='petty_cash_admin_core_activity' AND NOT tgisinternal
  ) AS admin_alert_trigger_ready,
  EXISTS(SELECT 1 FROM pg_trigger
         WHERE tgrelid='public.notifications'::regclass
           AND tgname='petty_cash_queue_push' AND NOT tgisinternal
  ) AS push_queue_trigger_ready;
