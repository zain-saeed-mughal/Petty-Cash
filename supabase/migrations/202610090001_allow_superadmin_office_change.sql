-- Allow Super Admin to change user office and role without restriction
BEGIN;

-- 1. Remove the restrictive trigger that blocks changing office
DROP TRIGGER IF EXISTS prevent_office_boy_history_move ON public.users;

CREATE OR REPLACE FUNCTION public.prevent_office_boy_history_move()
RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
  RETURN NEW;
END $$;

-- 2. Update sync_auth_profile to allow Superadmin office reassignment for all roles
CREATE OR REPLACE FUNCTION public.sync_auth_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE requested_role text; active boolean; existing public.users; requested_office uuid;
BEGIN
  requested_role := NEW.raw_app_meta_data->>'petty_cash_role';
  IF requested_role IS NULL THEN RETURN NEW; END IF;
  
  IF requested_role NOT IN ('office_boy','finance','admin','super_admin','manager') THEN 
    RAISE EXCEPTION 'Invalid app role'; 
  END IF;
  
  active := coalesce((NEW.raw_app_meta_data->>'petty_cash_active')::boolean,true);
  
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
  
  INSERT INTO public.users(uid,name,email,role,"isActive",office_id)
  VALUES(NEW.id,coalesce(nullif(trim(NEW.raw_user_meta_data->>'name'),''),existing.name,'Staff member'),
    NEW.email,requested_role,active,requested_office)
  ON CONFLICT(uid) DO UPDATE SET name=EXCLUDED.name,email=EXCLUDED.email,role=EXCLUDED.role,
    "isActive"=EXCLUDED."isActive",office_id=EXCLUDED.office_id;
    
  RETURN NEW;
END $$;

COMMIT;
