BEGIN;

-- Keep the existing organization usable while allowing additional offices.
CREATE TABLE IF NOT EXISTS public.offices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE CHECK (length(trim(name)) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.offices(id, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'Main Office')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS office_id uuid REFERENCES public.offices(id) ON DELETE RESTRICT;
UPDATE public.users
SET office_id = '00000000-0000-0000-0000-000000000001'
WHERE office_id IS NULL;
ALTER TABLE public.users
  ALTER COLUMN office_id SET DEFAULT '00000000-0000-0000-0000-000000000001',
  ALTER COLUMN office_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS users_office_role_idx ON public.users(office_id, role);

ALTER TABLE public.offices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.offices FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.offices TO authenticated;
GRANT ALL ON public.offices TO service_role;
DROP POLICY IF EXISTS offices_read ON public.offices;
CREATE POLICY offices_read ON public.offices FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance', 'admin', 'super_admin')
  OR id = (SELECT u.office_id FROM public.users u WHERE u.uid = auth.uid() AND u."isActive")
);

CREATE OR REPLACE FUNCTION public.current_office_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT office_id FROM public.users WHERE uid = auth.uid() AND "isActive"
$$;
REVOKE ALL ON FUNCTION public.current_office_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_office_id() TO authenticated;

-- Auth app_metadata remains the source of truth for assignments made through
-- the account-management Edge Function. Ordinary clients cannot edit it.
CREATE OR REPLACE FUNCTION public.sync_auth_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE requested_role text; active boolean; existing public.users; requested_office uuid;
BEGIN
  requested_role := NEW.raw_app_meta_data->>'petty_cash_role';
  IF requested_role IS NULL THEN RETURN NEW; END IF;
  IF requested_role NOT IN ('office_boy','finance','admin','super_admin') THEN RAISE EXCEPTION 'Invalid app role'; END IF;
  active := coalesce((NEW.raw_app_meta_data->>'petty_cash_active')::boolean,true);
  PERFORM pg_advisory_xact_lock(72624401);
  SELECT * INTO existing FROM public.users WHERE uid=NEW.id;
  IF existing.role='super_admin' AND existing."isActive" AND (requested_role<>'super_admin' OR NOT active)
    AND NOT EXISTS(SELECT 1 FROM public.users WHERE role='super_admin' AND "isActive" AND uid<>NEW.id)
  THEN RAISE EXCEPTION 'The last active super-admin cannot be disabled or demoted'; END IF;
  requested_office := coalesce(nullif(NEW.raw_app_meta_data->>'petty_cash_office_id','')::uuid,
    existing.office_id,'00000000-0000-0000-0000-000000000001'::uuid);
  IF NOT EXISTS (SELECT 1 FROM public.offices WHERE id=requested_office) THEN RAISE EXCEPTION 'Office not found'; END IF;
  IF existing.uid IS NOT NULL AND existing.office_id IS DISTINCT FROM requested_office
    AND existing.role = 'office_boy' AND (
      EXISTS(SELECT 1 FROM public.advance_requests WHERE office_boy_id=NEW.id)
      OR EXISTS(SELECT 1 FROM public.advances WHERE office_boy_id=NEW.id)
      OR EXISTS(SELECT 1 FROM public.expenses WHERE office_boy_id=NEW.id)
      OR EXISTS(SELECT 1 FROM public.requests WHERE "requestedBy"=NEW.id)
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

CREATE OR REPLACE FUNCTION public.create_office(p_name text)
RETURNS public.offices LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.offices;
BEGIN
  IF public.current_user_role() IS DISTINCT FROM 'super_admin' THEN
    RAISE EXCEPTION 'Only a Super Admin can add an office' USING ERRCODE = '42501';
  END IF;
  IF length(trim(coalesce(p_name, ''))) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'Enter an office name';
  END IF;
  INSERT INTO public.offices(name) VALUES (trim(p_name)) RETURNING * INTO result;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.assign_user_office(p_uid uuid, p_office_id uuid)
RETURNS public.users LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.users;
BEGIN
  IF public.current_user_role() IS DISTINCT FROM 'super_admin' THEN
    RAISE EXCEPTION 'Only a Super Admin can assign offices' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.offices WHERE id = p_office_id) THEN
    RAISE EXCEPTION 'Office not found';
  END IF;
  UPDATE auth.users SET raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)
    ||jsonb_build_object('petty_cash_office_id',p_office_id::text) WHERE id=p_uid;
  SELECT * INTO result FROM public.users WHERE uid=p_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'User not found'; END IF;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.create_office(text),
  public.assign_user_office(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_office(text),
  public.assign_user_office(uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
