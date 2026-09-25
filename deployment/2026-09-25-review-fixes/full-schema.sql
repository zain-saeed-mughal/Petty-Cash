-- Migration: 202609240001_secure_app.sql
-- Petty Cash canonical schema and upgrade, 2026-09-24.
-- Run as the database owner. Transactional and rerunnable; preserves legacy IDs.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS public.users (
 uid uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 name text NOT NULL, email text NOT NULL UNIQUE,
 role text NOT NULL DEFAULT 'office_boy',
 "createdAt" timestamptz NOT NULL DEFAULT now(), "isActive" boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS public.requests (
 id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
 "requestedBy" uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 "requesterName" text NOT NULL, "requesterEmail" text,
 "itemDescription" text NOT NULL, amount numeric(12,2) NOT NULL,
 reason text NOT NULL, "billImageUrl" text,
 status text NOT NULL DEFAULT 'Pending', "rejectionReason" text,
 "reviewedBy" uuid REFERENCES public.users(uid) ON DELETE SET NULL,
 "reviewedByName" text, "createdAt" timestamptz NOT NULL DEFAULT now(),
 "updatedAt" timestamptz NOT NULL DEFAULT now(), "auditLogs" jsonb NOT NULL DEFAULT '[]'
);
CREATE TABLE IF NOT EXISTS public.notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
 title text NOT NULL, message text NOT NULL, related_request_id text,
 is_read boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now()
);
-- Replace ALL app-table policies, including legacy permissive policies.
DO $$ DECLARE p record; BEGIN
 FOR p IN SELECT schemaname,tablename,policyname FROM pg_policies
 WHERE schemaname='public' AND tablename IN ('users','requests','notifications')
 LOOP EXECUTE format('DROP POLICY %I ON %I.%I',p.policyname,p.schemaname,p.tablename); END LOOP;
END $$;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notifications' AND column_name='isRead') THEN
  ALTER TABLE public.notifications RENAME COLUMN "isRead" TO is_read;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notifications' AND column_name='relatedRequestId') THEN
  ALTER TABLE public.notifications RENAME COLUMN "relatedRequestId" TO related_request_id;
 END IF;
END $$;
-- Existing references are preserved as text; new references use full UUID strings.
DO $$ DECLARE c record; BEGIN
 FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='public.notifications'::regclass AND confrelid='public.requests'::regclass
 LOOP EXECUTE format('ALTER TABLE public.notifications DROP CONSTRAINT %I',c.conname); END LOOP;
END $$;
ALTER TABLE public.requests ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.requests ALTER COLUMN id TYPE text USING id::text;
ALTER TABLE public.requests ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
ALTER TABLE public.notifications ALTER COLUMN related_request_id TYPE text USING related_request_id::text;
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0;
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS "paidAt" timestamptz;
-- Recover known historical payment times from the audit trail, not creation time.
UPDATE public.requests r SET "paidAt"=(
 SELECT (e->>'timestamp')::timestamptz FROM jsonb_array_elements(r."auditLogs") e
 WHERE e->>'action' IN ('Status changed to Paid','Status overridden to Paid')
 ORDER BY (e->>'timestamp')::timestamptz DESC LIMIT 1
) WHERE status='Paid' AND "paidAt" IS NULL;
ALTER TABLE public.users DROP COLUMN IF EXISTS password;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS "fcmToken" text;
-- Remove a legacy cascading owner FK without deleting any historical requests.
DO $$ DECLARE c record; BEGIN
 FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='public.requests'::regclass AND contype='f'
 AND conkey=ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid='public.requests'::regclass AND attname='requestedBy')]::smallint[]
 LOOP EXECUTE format('ALTER TABLE public.requests DROP CONSTRAINT %I',c.conname); END LOOP;
END $$;
ALTER TABLE public.requests ADD CONSTRAINT requests_owner_fk FOREIGN KEY ("requestedBy") REFERENCES public.users(uid) ON DELETE RESTRICT;
ALTER TABLE public.requests DROP CONSTRAINT IF EXISTS requests_amount_valid;
ALTER TABLE public.requests ADD CONSTRAINT requests_amount_valid CHECK (amount::text NOT IN ('NaN','Infinity','-Infinity') AND amount>0) NOT VALID;
ALTER TABLE public.requests DROP CONSTRAINT IF EXISTS requests_status_valid;
ALTER TABLE public.requests ADD CONSTRAINT requests_status_valid CHECK (status IN ('Pending','Approved','Rejected','Paid')) NOT VALID;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_valid;
ALTER TABLE public.users ADD CONSTRAINT users_role_valid CHECK (role IN ('super_admin','admin','finance','office_boy')) NOT VALID;
CREATE INDEX IF NOT EXISTS requests_created_idx ON public.requests ("createdAt" DESC,id);
CREATE INDEX IF NOT EXISTS requests_owner_created_idx ON public.requests ("requestedBy","createdAt" DESC);
CREATE INDEX IF NOT EXISTS requests_paid_idx ON public.requests ("paidAt") WHERE status='Paid';
CREATE INDEX IF NOT EXISTS notifications_user_date_idx ON public.notifications(user_id,created_at DESC);
CREATE OR REPLACE FUNCTION public.current_user_role() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public
AS $$ SELECT role FROM public.users WHERE uid=auth.uid() AND "isActive"=true $$;
REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.users,public.requests,public.notifications FROM anon,authenticated;
GRANT SELECT ON public.users,public.requests,public.notifications TO authenticated;
GRANT UPDATE(is_read),DELETE ON public.notifications TO authenticated;
CREATE POLICY users_read ON public.users FOR SELECT TO authenticated
 USING (uid=auth.uid() OR public.current_user_role() IN ('super_admin','admin','finance'));
CREATE POLICY requests_read ON public.requests FOR SELECT TO authenticated
 USING (public.current_user_role() IS NOT NULL AND ("requestedBy"=auth.uid() OR public.current_user_role() IN ('super_admin','admin','finance')));
CREATE POLICY notifications_read ON public.notifications FOR SELECT TO authenticated
 USING(user_id=auth.uid() AND public.current_user_role() IS NOT NULL);
CREATE POLICY notifications_read_update ON public.notifications FOR UPDATE TO authenticated
 USING(user_id=auth.uid() AND public.current_user_role() IS NOT NULL)
 WITH CHECK(user_id=auth.uid() AND public.current_user_role() IS NOT NULL);
CREATE POLICY notifications_delete ON public.notifications FOR DELETE TO authenticated
 USING(user_id=auth.uid() AND public.current_user_role() IS NOT NULL);
-- Disable obsolete administrative RPCs so old deployments cannot bypass the new boundary.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('admin_create_user','update_user_credentials','delete_user')
 LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature); END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.submit_request(request_id text,item_description text,request_amount numeric,request_reason text,receipt_path text DEFAULT NULL)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 IF request_id IS NULL OR request_id !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN RAISE EXCEPTION 'Invalid request reference'; END IF;
 IF request_amount IS NULL OR request_amount::text IN ('NaN','Infinity','-Infinity') OR request_amount<=0 OR request_amount>=10000000000 OR request_amount<>round(request_amount,2) THEN RAISE EXCEPTION 'Enter a positive amount with at most two decimal places'; END IF;
 IF item_description IS NULL OR request_reason IS NULL OR length(trim(item_description)) NOT BETWEEN 1 AND 500 OR length(trim(request_reason)) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Description and reason are required'; END IF;
 IF receipt_path IS NOT NULL AND (receipt_path NOT LIKE actor.uid::text||'/%' OR receipt_path LIKE '%..%') THEN RAISE EXCEPTION 'Invalid receipt path'; END IF;
 -- A retry after a network timeout must not create a second payment request.
 SELECT * INTO result FROM public.requests WHERE id=request_id;
 IF FOUND THEN
  IF result."requestedBy"<>actor.uid OR result.amount<>request_amount OR result."itemDescription"<>trim(item_description) OR result.reason<>trim(request_reason) OR result."billImageUrl" IS DISTINCT FROM receipt_path THEN RAISE EXCEPTION 'Request reference already used'; END IF;
  RETURN result;
 END IF;
 INSERT INTO public.requests(id,"requestedBy","requesterName","requesterEmail","itemDescription",amount,reason,"billImageUrl","auditLogs")
 VALUES(request_id,actor.uid,actor.name,actor.email,trim(item_description),request_amount,trim(request_reason),receipt_path,
 jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Created request','performerId',actor.uid,'performerName',actor.name)))
 RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.review_request(request_id text,expected_version integer,new_status text,review_note text DEFAULT NULL,is_override boolean DEFAULT false)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS NULL OR actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'You cannot review requests' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF expected_version IS NULL OR result.version<>expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF length(review_note)>2000 THEN RAISE EXCEPTION 'Review reason is too long'; END IF;
 IF new_status IS NULL OR new_status NOT IN ('Pending','Approved','Rejected','Paid') OR new_status=result.status THEN RAISE EXCEPTION 'Invalid status transition'; END IF;
 IF is_override THEN
  IF actor.role<>'super_admin' OR coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A super-admin and an override reason are required' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT ((result.status='Pending' AND new_status IN ('Approved','Rejected','Paid')) OR (result.status='Approved' AND new_status IN ('Paid','Rejected'))) THEN RAISE EXCEPTION 'This request can no longer be reviewed'; END IF;
 END IF;
 IF new_status='Rejected' AND coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A rejection reason is required'; END IF;
 UPDATE public.requests SET status=new_status,"rejectionReason"=CASE WHEN new_status='Rejected' THEN trim(review_note) END,
 "reviewedBy"=actor.uid,"reviewedByName"=actor.name,"updatedAt"=now(),version=version+1,
 "paidAt"=CASE WHEN new_status='Paid' THEN now() ELSE NULL END,
 "auditLogs"="auditLogs"||jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN is_override THEN 'Status overridden to ' ELSE 'Status changed to ' END||new_status,'performerId',actor.uid,'performerName',actor.name,'notes',nullif(trim(review_note),'')))
 WHERE id=request_id RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.delete_request(request_id text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF public.current_user_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 DELETE FROM public.requests WHERE id=request_id AND status IN ('Pending','Rejected');
 IF NOT FOUND THEN RAISE EXCEPTION 'Only pending or rejected requests can be deleted. Paid history must be retained.'; END IF;
END $$;
-- Atomic Auth/profile synchronization. Only Auth app_metadata carries privilege fields.
-- Seed metadata for existing accounts before enabling the trigger.
UPDATE auth.users a SET raw_app_meta_data=coalesce(a.raw_app_meta_data,'{}')||
 jsonb_build_object('petty_cash_role',u.role,'petty_cash_active',u."isActive")
FROM public.users u WHERE u.uid=a.id;
CREATE OR REPLACE FUNCTION public.sync_auth_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE requested_role text; active boolean; existing public.users;
BEGIN
 requested_role:=NEW.raw_app_meta_data->>'petty_cash_role';
 IF requested_role IS NULL THEN RETURN NEW; END IF; -- Unprovisioned public signups receive no app access.
 IF requested_role NOT IN ('office_boy','finance','admin','super_admin') THEN RAISE EXCEPTION 'Invalid app role'; END IF;
 active:=coalesce((NEW.raw_app_meta_data->>'petty_cash_active')::boolean,true);
 PERFORM pg_advisory_xact_lock(72624401);
 SELECT * INTO existing FROM public.users WHERE uid=NEW.id;
 IF existing.role='super_admin' AND existing."isActive" AND (requested_role<>'super_admin' OR NOT active)
 AND NOT EXISTS(SELECT 1 FROM public.users WHERE role='super_admin' AND "isActive" AND uid<>NEW.id)
 THEN RAISE EXCEPTION 'The last active super-admin cannot be disabled or demoted'; END IF;
 INSERT INTO public.users(uid,name,email,role,"isActive")
 VALUES(NEW.id,coalesce(nullif(trim(NEW.raw_user_meta_data->>'name'),''),existing.name,'Staff member'),NEW.email,requested_role,active)
 ON CONFLICT(uid) DO UPDATE SET name=EXCLUDED.name,email=EXCLUDED.email,role=EXCLUDED.role,"isActive"=EXCLUDED."isActive";
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS petty_cash_auth_profile ON auth.users;
CREATE TRIGGER petty_cash_auth_profile AFTER INSERT OR UPDATE OF email,raw_app_meta_data,raw_user_meta_data ON auth.users FOR EACH ROW EXECUTE FUNCTION public.sync_auth_profile();
CREATE OR REPLACE FUNCTION public.request_notifications() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.notifications(user_id,title,message,related_request_id)
  SELECT uid,'New expense request',NEW."requesterName"||' submitted a request for PKR '||NEW.amount,NEW.id
  FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
 ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
  INSERT INTO public.notifications(user_id,title,message,related_request_id)
  VALUES(NEW."requestedBy",'Request '||NEW.status,'Your request for '||NEW."itemDescription"||' is now '||lower(NEW.status)||'.',NEW.id);
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS petty_cash_request_notifications ON public.requests;
CREATE TRIGGER petty_cash_request_notifications AFTER INSERT OR UPDATE OF status ON public.requests FOR EACH ROW EXECUTE FUNCTION public.request_notifications();
CREATE TABLE IF NOT EXISTS public.device_tokens (
 token text PRIMARY KEY, user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
 platform text NOT NULL, updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.device_tokens FROM anon,authenticated;
CREATE OR REPLACE FUNCTION public.register_device(device_token text,device_platform text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF public.current_user_role() IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 IF device_token IS NULL OR length(device_token) NOT BETWEEN 10 AND 4096 THEN RAISE EXCEPTION 'Invalid device token'; END IF;
 INSERT INTO public.device_tokens(token,user_id,platform) VALUES(device_token,auth.uid(),device_platform)
 ON CONFLICT(token) DO UPDATE SET user_id=EXCLUDED.user_id,platform=EXCLUDED.platform,updated_at=now();
END $$;
CREATE OR REPLACE FUNCTION public.unregister_device(device_token text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN DELETE FROM public.device_tokens WHERE token=device_token AND user_id=auth.uid(); END $$;
-- Realtime is an invalidation signal; clients fetch paginated authoritative snapshots.
DO $$ DECLARE t text; BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') THEN
  FOREACH t IN ARRAY ARRAY['users','requests','notifications'] LOOP
   IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t) THEN
    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',t);
   END IF;
  END LOOP;
 END IF;
END $$;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('receipts','receipts',false,10485760,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=EXCLUDED.file_size_limit,allowed_mime_types=EXCLUDED.allowed_mime_types;
DO $$ DECLARE p record; BEGIN
 FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
 AND (coalesce(qual,'') ILIKE '%receipts%' OR coalesce(with_check,'') ILIKE '%receipts%' OR policyname ILIKE '%receipt%')
 LOOP EXECUTE format('DROP POLICY %I ON storage.objects',p.policyname); END LOOP;
END $$;
CREATE POLICY receipts_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='receipts' AND public.current_user_role() IS NOT NULL AND (storage.foldername(name))[1]=auth.uid()::text);
CREATE POLICY receipts_select ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id='receipts' AND public.current_user_role() IS NOT NULL AND (owner=auth.uid() OR public.current_user_role() IN ('super_admin','admin','finance')));
CREATE POLICY receipts_delete ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id='receipts' AND public.current_user_role() IS NOT NULL AND owner=auth.uid()
 AND NOT EXISTS(SELECT 1 FROM public.requests WHERE "billImageUrl"=name));
-- Every callable mutation explicitly checks identity; trigger helpers are not public APIs.
REVOKE ALL ON FUNCTION public.submit_request(text,text,numeric,text,text),public.review_request(text,integer,text,text,boolean),public.delete_request(text),public.register_device(text,text),public.unregister_device(text),public.sync_auth_profile(),public.request_notifications() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.submit_request(text,text,numeric,text,text),public.review_request(text,integer,text,text,boolean),public.delete_request(text),public.register_device(text,text),public.unregister_device(text) TO authenticated;
GRANT ALL ON public.users,public.requests,public.notifications,public.device_tokens TO service_role;
COMMIT;



-- Migration: 202609240002_push_outbox.sql
BEGIN;
CREATE TABLE IF NOT EXISTS public.push_outbox(
 id uuid PRIMARY KEY REFERENCES public.notifications(id) ON DELETE CASCADE,
 attempts integer NOT NULL DEFAULT 0,
 available_at timestamptz NOT NULL DEFAULT now(),
 sent_at timestamptz,last_error text
);
ALTER TABLE public.push_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_outbox FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.push_outbox TO service_role;
CREATE INDEX IF NOT EXISTS push_outbox_pending_idx ON public.push_outbox(available_at) WHERE sent_at IS NULL;
CREATE OR REPLACE FUNCTION public.queue_push() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN INSERT INTO public.push_outbox(id) VALUES(NEW.id) ON CONFLICT DO NOTHING; RETURN NEW; END $$;
DROP TRIGGER IF EXISTS petty_cash_queue_push ON public.notifications;
CREATE TRIGGER petty_cash_queue_push AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.queue_push();
CREATE OR REPLACE FUNCTION public.claim_push_batch() RETURNS TABLE(id uuid,user_id uuid,request_id text)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 WITH claimed AS (
  SELECT o.id FROM public.push_outbox o WHERE o.sent_at IS NULL AND o.attempts<8 AND o.available_at<=now()
  ORDER BY o.available_at LIMIT 50 FOR UPDATE SKIP LOCKED
 ), leased AS (
  UPDATE public.push_outbox o SET attempts=o.attempts+1,available_at=now()+interval '5 minutes'
  FROM claimed WHERE o.id=claimed.id RETURNING o.id
 )
 SELECT n.id,n.user_id,n.related_request_id FROM leased JOIN public.notifications n USING(id)
$$;
REVOKE ALL ON FUNCTION public.queue_push(),public.claim_push_batch() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_batch() TO service_role;
COMMIT;



-- Migration: 202609240003_device_language.sql
BEGIN;
ALTER TABLE public.device_tokens ADD COLUMN IF NOT EXISTS language_code text NOT NULL DEFAULT 'en'
  CHECK (language_code IN ('en','ur'));
-- The two-argument endpoint stays available for older clients.
CREATE OR REPLACE FUNCTION public.register_device_language(device_token text, device_platform text, device_language text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF device_language IS NULL OR device_language NOT IN ('en','ur') THEN RAISE EXCEPTION 'Invalid language'; END IF;
 IF device_platform IS NULL OR device_platform NOT IN ('web','android','iOS') THEN RAISE EXCEPTION 'Invalid platform'; END IF;
 PERFORM public.register_device(device_token,device_platform);
 UPDATE public.device_tokens SET language_code=device_language WHERE token=device_token AND user_id=auth.uid();
END $$;
REVOKE ALL ON FUNCTION public.register_device_language(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.register_device_language(text,text,text) TO authenticated;
COMMIT;


-- Migration: 202609240004_review_validation.sql
BEGIN;
CREATE OR REPLACE FUNCTION public.submit_request(request_id text,item_description text,request_amount numeric,request_reason text,receipt_path text DEFAULT NULL)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 IF request_id IS NULL OR request_id !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN RAISE EXCEPTION 'Invalid request reference'; END IF;
 IF request_amount IS NULL OR request_amount::text IN ('NaN','Infinity','-Infinity') OR request_amount<=0 OR request_amount>=10000000000 OR request_amount<>round(request_amount,2) THEN RAISE EXCEPTION 'Enter a positive amount with at most two decimal places'; END IF;
 IF item_description IS NULL OR request_reason IS NULL OR length(trim(item_description)) NOT BETWEEN 1 AND 500 OR length(trim(request_reason)) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Description and reason are required'; END IF;
 IF receipt_path IS NOT NULL AND (receipt_path NOT LIKE actor.uid::text||'/%' OR receipt_path LIKE '%..%') THEN RAISE EXCEPTION 'Invalid receipt path'; END IF;
 -- A retry after a network timeout must not create a second payment request.
 SELECT * INTO result FROM public.requests WHERE id=request_id;
 IF FOUND THEN
  IF result."requestedBy"<>actor.uid OR result.amount<>request_amount OR result."itemDescription"<>trim(item_description) OR result.reason<>trim(request_reason) OR result."billImageUrl" IS DISTINCT FROM receipt_path THEN RAISE EXCEPTION 'Request reference already used'; END IF;
  RETURN result;
 END IF;
 INSERT INTO public.requests(id,"requestedBy","requesterName","requesterEmail","itemDescription",amount,reason,"billImageUrl","auditLogs")
 VALUES(request_id,actor.uid,actor.name,actor.email,trim(item_description),request_amount,trim(request_reason),receipt_path,
 jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Created request','performerId',actor.uid,'performerName',actor.name)))
 RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.review_request(request_id text,expected_version integer,new_status text,review_note text DEFAULT NULL,is_override boolean DEFAULT false)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS NULL OR actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'You cannot review requests' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF expected_version IS NULL OR result.version<>expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF length(review_note)>2000 THEN RAISE EXCEPTION 'Review reason is too long'; END IF;
 IF new_status IS NULL OR new_status NOT IN ('Pending','Approved','Rejected','Paid') OR new_status=result.status THEN RAISE EXCEPTION 'Invalid status transition'; END IF;
 IF is_override THEN
  IF actor.role<>'super_admin' OR coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A super-admin and an override reason are required' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT ((result.status='Pending' AND new_status IN ('Approved','Rejected','Paid')) OR (result.status='Approved' AND new_status IN ('Paid','Rejected'))) THEN RAISE EXCEPTION 'This request can no longer be reviewed'; END IF;
 END IF;
 IF new_status='Rejected' AND coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A rejection reason is required'; END IF;
 UPDATE public.requests SET status=new_status,"rejectionReason"=CASE WHEN new_status='Rejected' THEN trim(review_note) END,
 "reviewedBy"=actor.uid,"reviewedByName"=actor.name,"updatedAt"=now(),version=version+1,
 "paidAt"=CASE WHEN new_status='Paid' THEN now() ELSE NULL END,
 "auditLogs"="auditLogs"||jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN is_override THEN 'Status overridden to ' ELSE 'Status changed to ' END||new_status,'performerId',actor.uid,'performerName',actor.name,'notes',nullif(trim(review_note),'')))
 WHERE id=request_id RETURNING * INTO result;
 RETURN result;
END $$;

COMMIT;


-- Migration: 202609250017_advance_settlement.sql
-- Petty Cash canonical schema and upgrade, 2026-09-24 (Updated for Advance Settlements).
-- Run as the database owner. Transactional and rerunnable; preserves legacy IDs.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.users (
 uid uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 name text NOT NULL, email text NOT NULL UNIQUE,
 role text NOT NULL DEFAULT 'office_boy',
 "createdAt" timestamptz NOT NULL DEFAULT now(), "isActive" boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.requests (
 id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
 "requestedBy" uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
 "requesterName" text NOT NULL, "requesterEmail" text,
 "itemDescription" text NOT NULL, amount numeric(12,2) NOT NULL,
 reason text NOT NULL, "billImageUrl" text,
 status text NOT NULL DEFAULT 'Pending', "rejectionReason" text,
 "reviewedBy" uuid REFERENCES public.users(uid) ON DELETE SET NULL,
 "reviewedByName" text, "createdAt" timestamptz NOT NULL DEFAULT now(),
 "updatedAt" timestamptz NOT NULL DEFAULT now(), "auditLogs" jsonb NOT NULL DEFAULT '[]'
);

-- ADD NEW COLUMNS FOR ADVANCE SETTLEMENT (Safe to run multiple times)
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS request_type text NOT NULL DEFAULT 'reimbursement';
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS settlement_amount numeric(12,2);
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS settlement_method text;
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS settlement_note text;
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS settlement_date timestamptz;
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS is_settled boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
 title text NOT NULL, message text NOT NULL, related_request_id text,
 is_read boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now()
);

-- Replace ALL app-table policies, including legacy permissive policies.
DO $$ DECLARE p record; BEGIN
 FOR p IN SELECT schemaname,tablename,policyname FROM pg_policies
 WHERE schemaname='public' AND tablename IN ('users','requests','notifications')
 LOOP EXECUTE format('DROP POLICY %I ON %I.%I',p.policyname,p.schemaname,p.tablename); END LOOP;
END $$;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notifications' AND column_name='isRead') THEN
  ALTER TABLE public.notifications RENAME COLUMN "isRead" TO is_read;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notifications' AND column_name='relatedRequestId') THEN
  ALTER TABLE public.notifications RENAME COLUMN "relatedRequestId" TO related_request_id;
 END IF;
END $$;
-- Existing references are preserved as text; new references use full UUID strings.
DO $$ DECLARE c record; BEGIN
 FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='public.notifications'::regclass AND confrelid='public.requests'::regclass
 LOOP EXECUTE format('ALTER TABLE public.notifications DROP CONSTRAINT %I',c.conname); END LOOP;
END $$;

ALTER TABLE public.requests ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.requests ALTER COLUMN id TYPE text USING id::text;
ALTER TABLE public.requests ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
ALTER TABLE public.notifications ALTER COLUMN related_request_id TYPE text USING related_request_id::text;
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 0;
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS "paidAt" timestamptz;
-- Recover known historical payment times from the audit trail, not creation time.
UPDATE public.requests r SET "paidAt"=(
 SELECT (e->>'timestamp')::timestamptz FROM jsonb_array_elements(r."auditLogs") e
 WHERE e->>'action' IN ('Status changed to Paid','Status overridden to Paid')
 ORDER BY (e->>'timestamp')::timestamptz DESC LIMIT 1
) WHERE status='Paid' AND "paidAt" IS NULL;

ALTER TABLE public.users DROP COLUMN IF EXISTS password;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS "fcmToken" text;

-- Remove a legacy cascading owner FK without deleting any historical requests.
DO $$ DECLARE c record; BEGIN
 FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='public.requests'::regclass AND contype='f'
 AND conkey=ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid='public.requests'::regclass AND attname='requestedBy')]::smallint[]
 LOOP EXECUTE format('ALTER TABLE public.requests DROP CONSTRAINT %I',c.conname); END LOOP;
END $$;

ALTER TABLE public.requests ADD CONSTRAINT requests_owner_fk FOREIGN KEY ("requestedBy") REFERENCES public.users(uid) ON DELETE RESTRICT;
ALTER TABLE public.requests DROP CONSTRAINT IF EXISTS requests_amount_valid;
ALTER TABLE public.requests ADD CONSTRAINT requests_amount_valid CHECK (amount::text NOT IN ('NaN','Infinity','-Infinity') AND amount>0) NOT VALID;
ALTER TABLE public.requests DROP CONSTRAINT IF EXISTS requests_status_valid;
ALTER TABLE public.requests ADD CONSTRAINT requests_status_valid CHECK (status IN ('Pending','Approved','Rejected','Paid', 'Pending Settlement', 'Settled')) NOT VALID;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_valid;
ALTER TABLE public.users ADD CONSTRAINT users_role_valid CHECK (role IN ('super_admin','admin','finance','office_boy')) NOT VALID;

CREATE INDEX IF NOT EXISTS requests_created_idx ON public.requests ("createdAt" DESC,id);
CREATE INDEX IF NOT EXISTS requests_owner_created_idx ON public.requests ("requestedBy","createdAt" DESC);
CREATE INDEX IF NOT EXISTS requests_paid_idx ON public.requests ("paidAt") WHERE status='Paid';
CREATE INDEX IF NOT EXISTS notifications_user_date_idx ON public.notifications(user_id,created_at DESC);

CREATE OR REPLACE FUNCTION public.current_user_role() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public
AS $$ SELECT role FROM public.users WHERE uid=auth.uid() AND "isActive"=true $$;
REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.users,public.requests,public.notifications FROM anon,authenticated;
GRANT SELECT ON public.users,public.requests,public.notifications TO authenticated;
GRANT UPDATE(is_read),DELETE ON public.notifications TO authenticated;

CREATE POLICY users_read ON public.users FOR SELECT TO authenticated
 USING (uid=auth.uid() OR public.current_user_role() IN ('super_admin','admin','finance'));
CREATE POLICY requests_read ON public.requests FOR SELECT TO authenticated
 USING (public.current_user_role() IS NOT NULL AND ("requestedBy"=auth.uid() OR public.current_user_role() IN ('super_admin','admin','finance')));
CREATE POLICY notifications_read ON public.notifications FOR SELECT TO authenticated
 USING(user_id=auth.uid() AND public.current_user_role() IS NOT NULL);
CREATE POLICY notifications_read_update ON public.notifications FOR UPDATE TO authenticated
 USING(user_id=auth.uid() AND public.current_user_role() IS NOT NULL)
 WITH CHECK(user_id=auth.uid() AND public.current_user_role() IS NOT NULL);
CREATE POLICY notifications_delete ON public.notifications FOR DELETE TO authenticated
 USING(user_id=auth.uid() AND public.current_user_role() IS NOT NULL);

-- Disable obsolete administrative RPCs so old deployments cannot bypass the new boundary.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('admin_create_user','update_user_credentials','delete_user', 'submit_request') -- also disable old submit_request which lacked request_type parameter
 LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature); END LOOP;
END $$;

-- Drop old submit_request so we can create it with a new signature
DROP FUNCTION IF EXISTS public.submit_request(text,text,numeric,text,text);

CREATE OR REPLACE FUNCTION public.submit_request(request_id text,item_description text,request_amount numeric,request_reason text,receipt_path text DEFAULT NULL, p_request_type text DEFAULT 'reimbursement')
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 IF request_id IS NULL OR request_id !~ '^[0-9a-fA-F-]{36}$' THEN RAISE EXCEPTION 'Invalid request reference'; END IF;
 IF request_amount IS NULL OR request_amount::text IN ('NaN','Infinity','-Infinity') OR request_amount<=0 OR request_amount>=10000000000 OR request_amount<>round(request_amount,2) THEN RAISE EXCEPTION 'Enter a positive amount with at most two decimal places'; END IF;
 IF length(trim(item_description)) NOT BETWEEN 1 AND 500 OR length(trim(request_reason)) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Description and reason are required'; END IF;
 IF p_request_type NOT IN ('reimbursement', 'advance') THEN RAISE EXCEPTION 'Invalid request type'; END IF;
 IF receipt_path IS NOT NULL AND (receipt_path NOT LIKE actor.uid::text||'/%' OR receipt_path LIKE '%..%') THEN RAISE EXCEPTION 'Invalid receipt path'; END IF;
 -- A retry after a network timeout must not create a second payment request.
 SELECT * INTO result FROM public.requests WHERE id=request_id;
 IF FOUND THEN
  IF result."requestedBy"<>actor.uid OR result.amount<>request_amount OR result."itemDescription"<>trim(item_description) OR result.reason<>trim(request_reason) OR result."billImageUrl" IS DISTINCT FROM receipt_path THEN RAISE EXCEPTION 'Request reference already used'; END IF;
  RETURN result;
 END IF;
 INSERT INTO public.requests(id,"requestedBy","requesterName","requesterEmail","itemDescription",amount,reason,"billImageUrl","auditLogs",request_type)
 VALUES(request_id,actor.uid,actor.name,actor.email,trim(item_description),request_amount,trim(request_reason),receipt_path,
 jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Created ' || p_request_type || ' request','performerId',actor.uid,'performerName',actor.name)), p_request_type)
 RETURNING * INTO result;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.review_request(request_id text,expected_version integer,new_status text,review_note text DEFAULT NULL,is_override boolean DEFAULT false)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS NULL OR actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'You cannot review requests' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result.version<>expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF new_status NOT IN ('Pending','Approved','Rejected','Paid') OR new_status=result.status THEN RAISE EXCEPTION 'Invalid status transition'; END IF;
 IF is_override THEN
  IF actor.role<>'super_admin' OR coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A super-admin and an override reason are required' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT ((result.status='Pending' AND new_status IN ('Approved','Rejected','Paid')) OR (result.status='Approved' AND new_status IN ('Paid','Rejected'))) THEN RAISE EXCEPTION 'This request can no longer be reviewed'; END IF;
 END IF;
 IF new_status='Rejected' AND coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A rejection reason is required'; END IF;
 UPDATE public.requests SET status=new_status,"rejectionReason"=CASE WHEN new_status='Rejected' THEN trim(review_note) END,
 "reviewedBy"=actor.uid,"reviewedByName"=actor.name,"updatedAt"=now(),version=version+1,
 "paidAt"=CASE WHEN new_status='Paid' THEN now() ELSE NULL END,
 "auditLogs"="auditLogs"||jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN is_override THEN 'Status overridden to ' ELSE 'Status changed to ' END||new_status,'performerId',actor.uid,'performerName',actor.name,'notes',nullif(trim(review_note),'')))
 WHERE id=request_id RETURNING * INTO result;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.delete_request(request_id text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF public.current_user_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 DELETE FROM public.requests WHERE id=request_id AND status IN ('Pending','Rejected');
 IF NOT FOUND THEN RAISE EXCEPTION 'Only pending or rejected requests can be deleted. Paid history must be retained.'; END IF;
END $$;

-- RPC for Office Boy to settle advance
CREATE OR REPLACE FUNCTION public.settle_advance_request(
    p_request_id text,
    p_expected_version integer,
    p_settlement_amount numeric,
    p_settlement_method text,
    p_settlement_note text
)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result."requestedBy" <> actor.uid AND actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF result.status <> 'Paid' OR result.request_type <> 'advance' THEN RAISE EXCEPTION 'Only paid advances can be settled'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF p_settlement_amount < 0 OR p_settlement_amount > result.amount THEN RAISE EXCEPTION 'Invalid settlement amount'; END IF;
 
 UPDATE public.requests SET 
    status = 'Pending Settlement',
    settlement_amount = p_settlement_amount,
    settlement_method = p_settlement_method,
    settlement_note = trim(p_settlement_note),
    settlement_date = now(),
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Submitted Settlement','performerId',actor.uid,'performerName',actor.name,'notes','Spent: ' || p_settlement_amount || ', Returned via ' || coalesce(p_settlement_method, 'None') || '. Note: ' || coalesce(p_settlement_note, '')))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;

-- RPC for Finance to verify settlement
CREATE OR REPLACE FUNCTION public.verify_advance_settlement(
    p_request_id text,
    p_expected_version integer
)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 IF actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'Not authorized'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result.status <> 'Pending Settlement' THEN RAISE EXCEPTION 'Request is not pending settlement'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 
 UPDATE public.requests SET 
    status = 'Settled',
    is_settled = true,
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Settlement Verified','performerId',actor.uid,'performerName',actor.name))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;

-- Atomic Auth/profile synchronization. Only Auth app_metadata carries privilege fields.
-- Seed metadata for existing accounts before enabling the trigger.
UPDATE auth.users a SET raw_app_meta_data=coalesce(a.raw_app_meta_data,'{}')||
 jsonb_build_object('petty_cash_role',u.role,'petty_cash_active',u."isActive")
FROM public.users u WHERE u.uid=a.id;
CREATE OR REPLACE FUNCTION public.sync_auth_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE requested_role text; active boolean; existing public.users;
BEGIN
 requested_role:=NEW.raw_app_meta_data->>'petty_cash_role';
 IF requested_role IS NULL THEN RETURN NEW; END IF; -- Unprovisioned public signups receive no app access.
 IF requested_role NOT IN ('office_boy','finance','admin','super_admin') THEN RAISE EXCEPTION 'Invalid app role'; END IF;
 active:=coalesce((NEW.raw_app_meta_data->>'petty_cash_active')::boolean,true);
 PERFORM pg_advisory_xact_lock(72624401);
 SELECT * INTO existing FROM public.users WHERE uid=NEW.id;
 IF existing.role='super_admin' AND existing."isActive" AND (requested_role<>'super_admin' OR NOT active)
 AND NOT EXISTS(SELECT 1 FROM public.users WHERE role='super_admin' AND "isActive" AND uid<>NEW.id)
 THEN RAISE EXCEPTION 'The last active super-admin cannot be disabled or demoted'; END IF;
 INSERT INTO public.users(uid,name,email,role,"isActive")
 VALUES(NEW.id,coalesce(nullif(trim(NEW.raw_user_meta_data->>'name'),''),existing.name,'Staff member'),NEW.email,requested_role,active)
 ON CONFLICT(uid) DO UPDATE SET name=EXCLUDED.name,email=EXCLUDED.email,role=EXCLUDED.role,"isActive"=EXCLUDED."isActive";
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS petty_cash_auth_profile ON auth.users;
CREATE TRIGGER petty_cash_auth_profile AFTER INSERT OR UPDATE OF email,raw_app_meta_data,raw_user_meta_data ON auth.users FOR EACH ROW EXECUTE FUNCTION public.sync_auth_profile();

CREATE OR REPLACE FUNCTION public.request_notifications() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.notifications(user_id,title,message,related_request_id)
  SELECT uid,'New expense request',NEW."requesterName"||' submitted a request for PKR '||NEW.amount,NEW.id
  FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
 ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
  INSERT INTO public.notifications(user_id,title,message,related_request_id)
  VALUES(NEW."requestedBy",'Request '||NEW.status,'Your request for '||NEW."itemDescription"||' is now '||lower(NEW.status)||'.',NEW.id);
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS petty_cash_request_notifications ON public.requests;
CREATE TRIGGER petty_cash_request_notifications AFTER INSERT OR UPDATE OF status ON public.requests FOR EACH ROW EXECUTE FUNCTION public.request_notifications();

CREATE TABLE IF NOT EXISTS public.device_tokens (
 token text PRIMARY KEY, user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
 platform text NOT NULL, updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.device_tokens FROM anon,authenticated;
CREATE OR REPLACE FUNCTION public.register_device(device_token text,device_platform text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF public.current_user_role() IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 IF length(device_token) NOT BETWEEN 10 AND 4096 THEN RAISE EXCEPTION 'Invalid device token'; END IF;
 INSERT INTO public.device_tokens(token,user_id,platform) VALUES(device_token,auth.uid(),device_platform)
 ON CONFLICT(token) DO UPDATE SET user_id=EXCLUDED.user_id,platform=EXCLUDED.platform,updated_at=now();
END $$;
CREATE OR REPLACE FUNCTION public.unregister_device(device_token text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN DELETE FROM public.device_tokens WHERE token=device_token AND user_id=auth.uid(); END $$;

-- Realtime is an invalidation signal; clients fetch paginated authoritative snapshots.
DO $$ DECLARE t text; BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') THEN
  FOREACH t IN ARRAY ARRAY['users','requests','notifications'] LOOP
   IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t) THEN
    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',t);
   END IF;
  END LOOP;
 END IF;
END $$;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('receipts','receipts',false,10485760,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=EXCLUDED.file_size_limit,allowed_mime_types=EXCLUDED.allowed_mime_types;
DO $$ DECLARE p record; BEGIN
 FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
 AND (coalesce(qual,'') ILIKE '%receipts%' OR coalesce(with_check,'') ILIKE '%receipts%' OR policyname ILIKE '%receipt%')
 LOOP EXECUTE format('DROP POLICY %I ON storage.objects',p.policyname); END LOOP;
END $$;
CREATE POLICY receipts_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='receipts' AND public.current_user_role() IS NOT NULL AND (storage.foldername(name))[1]=auth.uid()::text);
CREATE POLICY receipts_select ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id='receipts' AND public.current_user_role() IS NOT NULL AND (owner=auth.uid() OR public.current_user_role() IN ('super_admin','admin','finance')));
CREATE POLICY receipts_delete ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id='receipts' AND public.current_user_role() IS NOT NULL AND owner=auth.uid()
 AND NOT EXISTS(SELECT 1 FROM public.requests WHERE "billImageUrl"=name));

-- Every callable mutation explicitly checks identity; trigger helpers are not public APIs.
REVOKE ALL ON FUNCTION public.submit_request(text,text,numeric,text,text,text),public.review_request(text,integer,text,text,boolean),public.delete_request(text),public.register_device(text,text),public.unregister_device(text),public.sync_auth_profile(),public.request_notifications(),public.settle_advance_request(text,integer,numeric,text,text),public.verify_advance_settlement(text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.submit_request(text,text,numeric,text,text,text),public.review_request(text,integer,text,text,boolean),public.delete_request(text),public.register_device(text,text),public.unregister_device(text),public.settle_advance_request(text,integer,numeric,text,text),public.verify_advance_settlement(text,integer) TO authenticated;
GRANT ALL ON public.users,public.requests,public.notifications,public.device_tokens TO service_role;
COMMIT;

BEGIN;
CREATE TABLE IF NOT EXISTS public.push_outbox(
 id uuid PRIMARY KEY REFERENCES public.notifications(id) ON DELETE CASCADE,
 attempts integer NOT NULL DEFAULT 0,
 available_at timestamptz NOT NULL DEFAULT now(),
 sent_at timestamptz,last_error text
);
ALTER TABLE public.push_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_outbox FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.push_outbox TO service_role;
CREATE INDEX IF NOT EXISTS push_outbox_pending_idx ON public.push_outbox(available_at) WHERE sent_at IS NULL;
CREATE OR REPLACE FUNCTION public.queue_push() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN INSERT INTO public.push_outbox(id) VALUES(NEW.id) ON CONFLICT DO NOTHING; RETURN NEW; END $$;
DROP TRIGGER IF EXISTS petty_cash_queue_push ON public.notifications;
CREATE TRIGGER petty_cash_queue_push AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.queue_push();
CREATE OR REPLACE FUNCTION public.claim_push_batch() RETURNS TABLE(id uuid,user_id uuid,request_id text)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 WITH claimed AS (
  SELECT o.id FROM public.push_outbox o WHERE o.sent_at IS NULL AND o.attempts<8 AND o.available_at<=now()
  ORDER BY o.available_at LIMIT 50 FOR UPDATE SKIP LOCKED
 ), leased AS (
  UPDATE public.push_outbox o SET attempts=o.attempts+1,available_at=now()+interval '5 minutes'
  FROM claimed WHERE o.id=claimed.id RETURNING o.id
 )
 SELECT n.id,n.user_id,n.related_request_id FROM leased JOIN public.notifications n USING(id)
$$;
REVOKE ALL ON FUNCTION public.queue_push(),public.claim_push_batch() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_batch() TO service_role;
COMMIT;


-- Migration: 202609250018_superadmin_delete.sql
BEGIN;
-- Super-admin deletion removes the transaction from active lists and reports.
-- Keep the complete record and actor for subsequent financial reconciliation.
CREATE TABLE IF NOT EXISTS public.request_deletion_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text NOT NULL,
  deleted_by uuid NOT NULL,
  deleted_at timestamptz NOT NULL DEFAULT now(),
  request_snapshot jsonb NOT NULL
);
ALTER TABLE public.request_deletion_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.request_deletion_audit FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.request_deletion_audit TO authenticated;
GRANT ALL ON public.request_deletion_audit TO service_role;
DROP POLICY IF EXISTS superadmin_deletion_audit ON public.request_deletion_audit;
CREATE POLICY superadmin_deletion_audit ON public.request_deletion_audit FOR SELECT TO authenticated
 USING(public.current_user_role()='super_admin');

CREATE OR REPLACE FUNCTION public.delete_request(request_id text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE target public.requests;
BEGIN
 IF public.current_user_role() IS DISTINCT FROM 'super_admin' THEN
  RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501';
 END IF;
 SELECT * INTO target FROM public.requests WHERE id=request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 INSERT INTO public.request_deletion_audit(request_id,deleted_by,request_snapshot)
 VALUES(target.id,auth.uid(),to_jsonb(target));
 DELETE FROM public.requests WHERE id=target.id;
END $$;
REVOKE ALL ON FUNCTION public.delete_request(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.delete_request(text) TO authenticated;
COMMIT;


-- Migration: 202609250019_advance_validation.sql
BEGIN;
DROP FUNCTION IF EXISTS public.submit_request(text,text,numeric,text,text);
CREATE OR REPLACE FUNCTION public.submit_request(request_id text,item_description text,request_amount numeric,request_reason text,receipt_path text DEFAULT NULL, p_request_type text DEFAULT 'reimbursement')
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 IF request_id IS NULL OR request_id !~ '^[0-9a-fA-F-]{36}$' THEN RAISE EXCEPTION 'Invalid request reference'; END IF;
 IF request_amount IS NULL OR request_amount::text IN ('NaN','Infinity','-Infinity') OR request_amount<=0 OR request_amount>=10000000000 OR request_amount<>round(request_amount,2) THEN RAISE EXCEPTION 'Enter a positive amount with at most two decimal places'; END IF;
 IF item_description IS NULL OR request_reason IS NULL OR length(trim(item_description)) NOT BETWEEN 1 AND 500 OR length(trim(request_reason)) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Description and reason are required'; END IF;
 IF p_request_type IS NULL OR p_request_type NOT IN ('reimbursement', 'advance') THEN RAISE EXCEPTION 'Invalid request type'; END IF;
 IF receipt_path IS NOT NULL AND (receipt_path NOT LIKE actor.uid::text||'/%' OR receipt_path LIKE '%..%') THEN RAISE EXCEPTION 'Invalid receipt path'; END IF;
 -- A retry after a network timeout must not create a second payment request.
 SELECT * INTO result FROM public.requests WHERE id=request_id;
 IF FOUND THEN
  IF result."requestedBy"<>actor.uid OR result.request_type<>p_request_type OR result.amount<>request_amount OR result."itemDescription"<>trim(item_description) OR result.reason<>trim(request_reason) OR result."billImageUrl" IS DISTINCT FROM receipt_path THEN RAISE EXCEPTION 'Request reference already used'; END IF;
  RETURN result;
 END IF;
 INSERT INTO public.requests(id,"requestedBy","requesterName","requesterEmail","itemDescription",amount,reason,"billImageUrl","auditLogs",request_type)
 VALUES(request_id,actor.uid,actor.name,actor.email,trim(item_description),request_amount,trim(request_reason),receipt_path,
 jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Created ' || p_request_type || ' request','performerId',actor.uid,'performerName',actor.name)), p_request_type)
 RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.review_request(request_id text,expected_version integer,new_status text,review_note text DEFAULT NULL,is_override boolean DEFAULT false)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS NULL OR actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'You cannot review requests' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF expected_version IS NULL OR result.version<>expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF new_status NOT IN ('Pending','Approved','Rejected','Paid') OR new_status=result.status THEN RAISE EXCEPTION 'Invalid status transition'; END IF;
 IF is_override THEN
  IF actor.role<>'super_admin' OR coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A super-admin and an override reason are required' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT ((result.status='Pending' AND new_status IN ('Approved','Rejected','Paid')) OR (result.status='Approved' AND new_status IN ('Paid','Rejected'))) THEN RAISE EXCEPTION 'This request can no longer be reviewed'; END IF;
 END IF;
 IF new_status='Rejected' AND coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A rejection reason is required'; END IF;
 UPDATE public.requests SET status=new_status,"rejectionReason"=CASE WHEN new_status='Rejected' THEN trim(review_note) END,
 "reviewedBy"=actor.uid,"reviewedByName"=actor.name,"updatedAt"=now(),version=version+1,
 "paidAt"=CASE WHEN new_status='Paid' THEN now() ELSE NULL END,
 "auditLogs"="auditLogs"||jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN is_override THEN 'Status overridden to ' ELSE 'Status changed to ' END||new_status,'performerId',actor.uid,'performerName',actor.name,'notes',nullif(trim(review_note),'')))
 WHERE id=request_id RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.settle_advance_request(
    p_request_id text,
    p_expected_version integer,
    p_settlement_amount numeric,
    p_settlement_method text,
    p_settlement_note text
)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result."requestedBy" <> actor.uid AND actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF result.status <> 'Paid' OR result.request_type <> 'advance' THEN RAISE EXCEPTION 'Only paid advances can be settled'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF p_settlement_amount IS NULL OR p_settlement_amount::text IN ('NaN','Infinity','-Infinity') OR p_settlement_amount<>round(p_settlement_amount,2) OR p_settlement_amount < 0 OR p_settlement_amount > result.amount THEN RAISE EXCEPTION 'Invalid settlement amount'; END IF;
 
 IF p_settlement_amount < result.amount AND (p_settlement_method IS NULL OR p_settlement_method NOT IN ('Cash','Card')) THEN RAISE EXCEPTION 'Choose a valid return method'; END IF;
 IF length(p_settlement_note)>2000 THEN RAISE EXCEPTION 'Settlement note is too long'; END IF;
 UPDATE public.requests SET 
    status = 'Pending Settlement',
    settlement_amount = p_settlement_amount,
    settlement_method = p_settlement_method,
    settlement_note = trim(p_settlement_note),
    settlement_date = now(),
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Submitted Settlement','performerId',actor.uid,'performerName',actor.name,'notes','Spent: ' || p_settlement_amount || ', Returned via ' || coalesce(p_settlement_method, 'None') || '. Note: ' || coalesce(p_settlement_note, '')))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.submit_request(text,text,numeric,text,text,text),public.review_request(text,integer,text,text,boolean),public.settle_advance_request(text,integer,numeric,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.submit_request(text,text,numeric,text,text,text),public.review_request(text,integer,text,text,boolean),public.settle_advance_request(text,integer,numeric,text,text) TO authenticated;
COMMIT;


-- Migration: 202609250020_partial_settlements.sql
-- Update the settle function to allow updating an already pending settlement
CREATE OR REPLACE FUNCTION public.settle_advance_request(
    p_request_id text,
    p_expected_version integer,
    p_settlement_amount numeric,
    p_settlement_method text,
    p_settlement_note text
)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result."requestedBy" <> actor.uid AND actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'Not authorized'; END IF;
 -- ALLOW Paid AND Pending Settlement to be updated
 IF result.status NOT IN ('Paid', 'Pending Settlement') OR result.request_type <> 'advance' THEN RAISE EXCEPTION 'Only paid or pending advances can be settled'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF p_settlement_amount < 0 OR p_settlement_amount > result.amount THEN RAISE EXCEPTION 'Invalid settlement amount'; END IF;
 
 UPDATE public.requests SET 
    status = 'Pending Settlement',
    settlement_amount = p_settlement_amount,
    settlement_method = p_settlement_method,
    settlement_note = trim(p_settlement_note),
    settlement_date = now(),
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Updated Settlement','performerId',actor.uid,'performerName',actor.name,'notes','Spent: ' || p_settlement_amount || ', Returned via ' || coalesce(p_settlement_method, 'None') || '. Note: ' || coalesce(p_settlement_note, '')))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;


-- Migration: 202609250021_settlement_notifications.sql
CREATE OR REPLACE FUNCTION public.request_notifications() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.notifications(user_id,title,message,related_request_id)
  SELECT uid,'New expense request',NEW."requesterName"||' submitted a request for PKR '||NEW.amount,NEW.id
  FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
 ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
  IF NEW.status = 'Pending Settlement' THEN
    -- Notify Finance/Admins
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    SELECT uid,'Advance Settlement',NEW."requesterName"||' submitted a settlement update.',NEW.id
    FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
    
    -- Notify Office Boy (Requester)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Settlement Submitted','Your settlement update has been submitted for review.',NEW.id);
    
  ELSIF NEW.status = 'Settled' THEN
    -- Notify Finance/Admins
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    SELECT uid,'Advance Settled',NEW."requesterName"||'''s advance has been fully settled and closed.',NEW.id
    FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
    
    -- Notify Office Boy (Requester)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Advance Settled','Your advance settlement was verified by Finance and is now closed.',NEW.id);
    
  ELSE
    -- Notify Office Boy of other status changes (Paid, Approved, Rejected)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Request '||NEW.status,'Your request for '||NEW."itemDescription"||' is now '||lower(NEW.status)||'.',NEW.id);
  END IF;
 END IF;
 RETURN NEW;
END $$;


-- Migration: 202609250022_settlement_review_fixes.sql
BEGIN;
CREATE OR REPLACE FUNCTION public.settle_advance_request(
    p_request_id text,
    p_expected_version integer,
    p_settlement_amount numeric,
    p_settlement_method text,
    p_settlement_note text
)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result."requestedBy" <> actor.uid AND actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF result.status NOT IN ('Paid','Pending Settlement') OR result.request_type <> 'advance' THEN RAISE EXCEPTION 'Only paid or pending advances can be settled'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF p_settlement_amount IS NULL OR p_settlement_amount::text IN ('NaN','Infinity','-Infinity') OR p_settlement_amount<>round(p_settlement_amount,2) OR p_settlement_amount < 0 OR p_settlement_amount > result.amount THEN RAISE EXCEPTION 'Invalid settlement amount'; END IF;
 
 IF p_settlement_amount < result.amount AND (p_settlement_method IS NULL OR p_settlement_method NOT IN ('Cash','Card')) THEN RAISE EXCEPTION 'Choose a valid return method'; END IF;
 IF length(p_settlement_note)>2000 THEN RAISE EXCEPTION 'Settlement note is too long'; END IF;
 UPDATE public.requests SET 
    status = 'Pending Settlement',
    settlement_amount = p_settlement_amount,
    settlement_method = p_settlement_method,
    settlement_note = trim(p_settlement_note),
    settlement_date = now(),
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN result.status='Pending Settlement' THEN 'Updated Settlement' ELSE 'Submitted Settlement' END,'performerId',actor.uid,'performerName',actor.name,'notes','Spent: ' || p_settlement_amount || ', Returned via ' || coalesce(p_settlement_method, 'None') || '. Note: ' || coalesce(p_settlement_note, '')))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.verify_advance_settlement(
    p_request_id text,
    p_expected_version integer
)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.uid IS NULL THEN RAISE EXCEPTION 'Your account is not active' USING ERRCODE='42501'; END IF;
 IF actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'Not authorized'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF result.status <> 'Pending Settlement' OR result.request_type <> 'advance' THEN RAISE EXCEPTION 'Request is not pending settlement'; END IF;
 IF p_expected_version IS NULL OR result.version<>p_expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 
 IF result.settlement_amount IS NULL OR result.settlement_amount::text IN ('NaN','Infinity','-Infinity') OR result.settlement_amount < 0 OR result.settlement_amount > result.amount THEN RAISE EXCEPTION 'Invalid settlement amount'; END IF;
 IF result.settlement_amount < result.amount AND (result.settlement_method IS NULL OR result.settlement_method NOT IN ('Cash','Card')) THEN RAISE EXCEPTION 'Choose a valid return method'; END IF;
 UPDATE public.requests SET 
    status = 'Settled',
    is_settled = true,
    version = version + 1,
    "updatedAt" = now(),
    "auditLogs" = "auditLogs" || jsonb_build_array(jsonb_build_object('timestamp',now(),'action','Settlement Verified','performerId',actor.uid,'performerName',actor.name))
 WHERE id=p_request_id RETURNING * INTO result;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.review_request(request_id text,expected_version integer,new_status text,review_note text DEFAULT NULL,is_override boolean DEFAULT false)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor public.users; result public.requests;
BEGIN
 SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
 IF actor.role IS NULL OR actor.role NOT IN ('finance','super_admin') THEN RAISE EXCEPTION 'You cannot review requests' USING ERRCODE='42501'; END IF;
 SELECT * INTO result FROM public.requests WHERE id=request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
 IF expected_version IS NULL OR result.version<>expected_version THEN RAISE EXCEPTION 'This request changed. Refresh it before reviewing.' USING ERRCODE='40001'; END IF;
 IF new_status IS NULL OR new_status NOT IN ('Pending','Approved','Rejected','Paid') OR new_status=result.status THEN RAISE EXCEPTION 'Invalid status transition'; END IF;
 IF is_override THEN
  IF actor.role<>'super_admin' OR coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A super-admin and an override reason are required' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT ((result.status='Pending' AND new_status IN ('Approved','Rejected','Paid')) OR (result.status='Approved' AND new_status IN ('Paid','Rejected'))) THEN RAISE EXCEPTION 'This request can no longer be reviewed'; END IF;
 END IF;
 IF new_status='Rejected' AND coalesce(length(trim(review_note)),0)=0 THEN RAISE EXCEPTION 'A rejection reason is required'; END IF;
 UPDATE public.requests SET status=new_status,"rejectionReason"=CASE WHEN new_status='Rejected' THEN trim(review_note) END,
 "reviewedBy"=actor.uid,"reviewedByName"=actor.name,"updatedAt"=now(),version=version+1,
 settlement_amount=NULL,settlement_method=NULL,settlement_note=NULL,settlement_date=NULL,is_settled=false,
 "paidAt"=CASE WHEN new_status='Paid' THEN now() ELSE NULL END,
 "auditLogs"="auditLogs"||jsonb_build_array(jsonb_build_object('timestamp',now(),'action',CASE WHEN is_override THEN 'Status overridden to ' ELSE 'Status changed to ' END||new_status,'performerId',actor.uid,'performerName',actor.name,'notes',nullif(trim(review_note),'')))
 WHERE id=request_id RETURNING * INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.request_notifications() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.notifications(user_id,title,message,related_request_id)
  SELECT uid,'New expense request',NEW."requesterName"||' submitted a request for PKR '||NEW.amount,NEW.id
  FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
 ELSIF NEW.status IS DISTINCT FROM OLD.status OR
   (NEW.status='Pending Settlement' AND
    ROW(NEW.settlement_amount,NEW.settlement_method,NEW.settlement_note,NEW.settlement_date)
      IS DISTINCT FROM ROW(OLD.settlement_amount,OLD.settlement_method,OLD.settlement_note,OLD.settlement_date)) THEN
  IF NEW.status = 'Pending Settlement' THEN
    -- Notify Finance/Admins
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    SELECT uid,'Advance Settlement',NEW."requesterName"||' submitted a settlement update.',NEW.id
    FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
    
    -- Notify Office Boy (Requester)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Settlement Submitted','Your settlement update has been submitted for review.',NEW.id);
    
  ELSIF NEW.status = 'Settled' THEN
    -- Notify Finance/Admins
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    SELECT uid,'Advance Settled',NEW."requesterName"||'''s advance has been fully settled and closed.',NEW.id
    FROM public.users WHERE "isActive" AND role IN ('finance','admin','super_admin') AND uid<>NEW."requestedBy";
    
    -- Notify Office Boy (Requester)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Advance Settled','Your advance settlement was verified by Finance and is now closed.',NEW.id);
    
  ELSE
    -- Notify Office Boy of other status changes (Paid, Approved, Rejected)
    INSERT INTO public.notifications(user_id,title,message,related_request_id)
    VALUES(NEW."requestedBy",'Request '||NEW.status,'Your request for '||NEW."itemDescription"||' is now '||lower(NEW.status)||'.',NEW.id);
  END IF;
 END IF;
 RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS petty_cash_request_notifications ON public.requests;
CREATE TRIGGER petty_cash_request_notifications AFTER INSERT OR UPDATE OF status,settlement_amount,settlement_method,settlement_note,settlement_date ON public.requests FOR EACH ROW EXECUTE FUNCTION public.request_notifications();
REVOKE ALL ON FUNCTION public.settle_advance_request(text,integer,numeric,text,text), public.verify_advance_settlement(text,integer),public.review_request(text,integer,text,text,boolean),public.request_notifications() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.settle_advance_request(text,integer,numeric,text,text),public.verify_advance_settlement(text,integer),public.review_request(text,integer,text,text,boolean) TO authenticated;
COMMIT;


-- Migration: 202609250023_incremental_requests.sql
BEGIN;
-- A transactional counter avoids sequence/commit-order gaps in the change feed.
CREATE TABLE IF NOT EXISTS public.request_sync_clock (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 revision bigint NOT NULL DEFAULT 0
);
INSERT INTO public.request_sync_clock(singleton) VALUES(true) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS public.request_changes (
 request_id text PRIMARY KEY,
 owner_id uuid NOT NULL,
 revision bigint NOT NULL,
 deleted boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS request_changes_revision_idx ON public.request_changes(revision);
CREATE INDEX IF NOT EXISTS request_changes_owner_revision_idx ON public.request_changes(owner_id,revision);
ALTER TABLE public.request_sync_clock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.request_sync_clock,public.request_changes FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.request_sync_clock,public.request_changes TO service_role;

CREATE OR REPLACE FUNCTION public.track_request_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE next_revision bigint; row_id text; row_owner uuid;
BEGIN
 UPDATE public.request_sync_clock SET revision=revision+1 WHERE singleton RETURNING revision INTO next_revision;
 IF TG_OP='DELETE' THEN row_id:=OLD.id; row_owner:=OLD."requestedBy";
 ELSE row_id:=NEW.id; row_owner:=NEW."requestedBy"; END IF;
 INSERT INTO public.request_changes(request_id,owner_id,revision,deleted)
 VALUES(row_id,row_owner,next_revision,TG_OP='DELETE')
 ON CONFLICT(request_id) DO UPDATE SET owner_id=EXCLUDED.owner_id,revision=EXCLUDED.revision,deleted=EXCLUDED.deleted;
 RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS petty_cash_request_changes ON public.requests;
CREATE TRIGGER petty_cash_request_changes AFTER INSERT OR UPDATE OR DELETE ON public.requests
 FOR EACH ROW EXECUTE FUNCTION public.track_request_change();

-- Backfill existing requests once; rerunning the migration keeps cursors valid.
DO $$ DECLARE r record; next_revision bigint; BEGIN
 FOR r IN SELECT id,"requestedBy" FROM public.requests
 WHERE NOT EXISTS(SELECT 1 FROM public.request_changes c WHERE c.request_id=requests.id)
 ORDER BY id LOOP
  UPDATE public.request_sync_clock SET revision=revision+1 WHERE singleton RETURNING revision INTO next_revision;
  INSERT INTO public.request_changes(request_id,owner_id,revision) VALUES(r.id,r."requestedBy",next_revision);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sync_requests(after_revision bigint DEFAULT 0,page_size integer DEFAULT 500)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor_role text; ceiling bigint; batch jsonb; last_revision bigint; batch_count integer;
BEGIN
 actor_role:=public.current_user_role();
 IF actor_role IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 IF after_revision IS NULL OR after_revision<0 OR page_size IS NULL OR page_size NOT BETWEEN 1 AND 500 THEN
  RAISE EXCEPTION 'Invalid sync cursor or page size';
 END IF;
 SELECT revision INTO ceiling FROM public.request_sync_clock WHERE singleton;
 IF after_revision>ceiling THEN RAISE EXCEPTION 'Invalid sync cursor or page size'; END IF;
 WITH page AS (
  SELECT c.* FROM public.request_changes c
  WHERE c.revision>after_revision AND c.revision<=ceiling
   AND (actor_role IN ('admin','super_admin','finance') OR c.owner_id=auth.uid())
  ORDER BY c.revision LIMIT page_size
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.request_id,
  'deleted',p.deleted OR r.id IS NULL,'request',CASE WHEN NOT p.deleted AND r.id IS NOT NULL THEN to_jsonb(r) ELSE NULL END)
  ORDER BY p.revision),'[]'::jsonb),max(p.revision),count(*)
 INTO batch,last_revision,batch_count FROM page p LEFT JOIN public.requests r ON r.id=p.request_id;
 RETURN jsonb_build_object('changes',batch,'cursor',CASE WHEN batch_count<page_size THEN ceiling ELSE last_revision END,
  'has_more',batch_count=page_size);
END $$;
REVOKE ALL ON FUNCTION public.track_request_change(),public.sync_requests(bigint,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sync_requests(bigint,integer) TO authenticated;
COMMIT;
