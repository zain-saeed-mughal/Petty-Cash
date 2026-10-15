-- Run on the existing database. Preserve each payment's original office when
-- Super Admin moves an Office Boy account to another office.
BEGIN;

-- The old trigger and auth-profile guard reject a move as soon as history
-- exists. Financial rows must stay attributed to the office where they arose.
DROP TRIGGER IF EXISTS prevent_office_boy_history_move ON public.users;

CREATE OR REPLACE FUNCTION public.sync_auth_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  requested_role text;
  active boolean;
  existing public.users;
  requested_office uuid;
BEGIN
  requested_role := NEW.raw_app_meta_data->>'petty_cash_role';
  IF requested_role IS NULL THEN RETURN NEW; END IF;
  IF requested_role NOT IN ('office_boy','finance','admin','super_admin','manager') THEN
    RAISE EXCEPTION 'Invalid app role';
  END IF;
  active := coalesce((NEW.raw_app_meta_data->>'petty_cash_active')::boolean,true);
  PERFORM pg_advisory_xact_lock(72624401);
  SELECT * INTO existing FROM public.users WHERE uid=NEW.id;
  IF existing.role='super_admin' AND existing."isActive"
     AND (requested_role<>'super_admin' OR NOT active)
     AND NOT EXISTS(SELECT 1 FROM public.users
                    WHERE role='super_admin' AND "isActive" AND uid<>NEW.id) THEN
    RAISE EXCEPTION 'The last active super-admin cannot be disabled or demoted';
  END IF;
  requested_office := coalesce(
    nullif(NEW.raw_app_meta_data->>'petty_cash_office_id','')::uuid,
    existing.office_id, '00000000-0000-0000-0000-000000000001'::uuid);
  IF NOT EXISTS (SELECT 1 FROM public.offices WHERE id=requested_office) THEN
    RAISE EXCEPTION 'Office not found';
  END IF;
  INSERT INTO public.users(uid,name,email,role,"isActive",office_id)
  VALUES(NEW.id,
    coalesce(nullif(trim(NEW.raw_user_meta_data->>'name'),''),existing.name,'Staff member'),
    NEW.email,requested_role,active,requested_office)
  ON CONFLICT(uid) DO UPDATE SET
    name=EXCLUDED.name,email=EXCLUDED.email,role=EXCLUDED.role,
    "isActive"=EXCLUDED."isActive",office_id=EXCLUDED.office_id;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sync_auth_profile() FROM PUBLIC, anon, authenticated;

-- Ownership is the Office Boy's uid. Reassignment must not hide records whose
-- historical office_id differs from the user's current office_id.
DROP POLICY IF EXISTS advance_requests_read ON public.advance_requests;
CREATE POLICY advance_requests_read ON public.advance_requests FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin')
  OR (public.current_user_role()='office_boy' AND office_boy_id=auth.uid())
  OR (public.current_user_role()='manager' AND EXISTS (
    SELECT 1 FROM public.advance_items ai
    WHERE ai.advance_request_id=advance_requests.id AND ai.tagged_manager_id=auth.uid()
  ))
);

DROP POLICY IF EXISTS advance_items_read ON public.advance_items;
CREATE POLICY advance_items_read ON public.advance_items FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin')
  OR (public.current_user_role()='office_boy' AND office_boy_id=auth.uid())
  OR (public.current_user_role()='manager' AND tagged_manager_id=auth.uid())
);

DROP POLICY IF EXISTS advance_ledger_read ON public.advance_ledger;
CREATE POLICY advance_ledger_read ON public.advance_ledger FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin')
  OR (public.current_user_role()='office_boy' AND office_boy_id=auth.uid())
  OR (public.current_user_role()='manager' AND entry_type='spend' AND EXISTS (
    SELECT 1 FROM public.advance_items ai
    WHERE ai.id=advance_ledger.advance_item_id AND ai.tagged_manager_id=auth.uid()
  ))
);

DROP POLICY IF EXISTS reimbursements_read ON public.reimbursement_requests;
CREATE POLICY reimbursements_read ON public.reimbursement_requests FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin')
  OR (public.current_user_role()='office_boy' AND office_boy_id=auth.uid())
  OR (public.current_user_role()='manager' AND tagged_manager_id=auth.uid())
);

DROP POLICY IF EXISTS core_activity_read ON public.core_payment_activity;
CREATE POLICY core_activity_read ON public.core_payment_activity FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin')
  OR (public.current_user_role()='office_boy' AND office_boy_id=auth.uid())
  OR (public.current_user_role()='manager' AND (
    EXISTS (SELECT 1 FROM public.advance_items ai
            WHERE ai.id::text=core_payment_activity.detail->>'item_id'
              AND ai.tagged_manager_id=auth.uid())
    OR EXISTS (SELECT 1 FROM public.reimbursement_requests rr
               WHERE rr.id=core_payment_activity.reimbursement_id
                 AND rr.tagged_manager_id=auth.uid())
  ))
);

DROP POLICY IF EXISTS offices_read ON public.offices;
CREATE POLICY offices_read ON public.offices FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin')
  OR id=public.current_office_id()
  OR (public.current_user_role()='office_boy' AND (
    EXISTS (SELECT 1 FROM public.advance_requests a
            WHERE a.office_id=offices.id AND a.office_boy_id=auth.uid())
    OR EXISTS (SELECT 1 FROM public.reimbursement_requests r
               WHERE r.office_id=offices.id AND r.office_boy_id=auth.uid())
  ))
);

CREATE OR REPLACE FUNCTION public.advance_balances_v2()
RETURNS TABLE(advance_request_id uuid,office_boy_id uuid,office_id uuid,total numeric,spent numeric,remaining numeric,item_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public, pg_temp AS $$
DECLARE role_name text;
BEGIN
  role_name:=public.current_user_role();
  IF role_name IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT a.id,a.office_boy_id,a.office_id,a.amount_requested,
    coalesce(sum(i.amount_spent),0),public.core_advance_balance(a.id),count(i.id)
  FROM public.advance_requests a
  LEFT JOIN public.advance_items i ON i.advance_request_id=a.id AND i.status='approved'
  WHERE a.flow_version=2 AND a.status IN ('cleared','fully_utilized')
    AND (role_name IN ('finance','admin','super_admin')
      OR (role_name='office_boy' AND a.office_boy_id=auth.uid()))
  GROUP BY a.id,a.office_boy_id,a.office_id,a.amount_requested,a.created_at
  ORDER BY a.created_at DESC;
END $$;

-- An unused old-office advance remains spendable by its owner. New entries
-- keep that advance's original office_id so office-level accounts stay exact.
CREATE OR REPLACE FUNCTION public.log_advance_item_v2(
  p_id uuid, p_advance_id uuid, p_item text, p_amount numeric, p_bill_path text DEFAULT NULL,
  p_tagged_manager_id uuid DEFAULT NULL
) RETURNS public.advance_items LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
DECLARE actor public.users; advance public.advance_requests; result public.advance_items; balance numeric;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid=auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN RAISE EXCEPTION 'Only an Office Boy can add advance items' USING ERRCODE='42501'; END IF;
  IF p_id IS NULL OR NOT public.payment_amount_valid(p_amount)
    OR length(trim(coalesce(p_item,''))) NOT BETWEEN 1 AND 500
    OR (p_bill_path IS NOT NULL AND (p_bill_path NOT LIKE actor.uid::text||'/%' OR p_bill_path LIKE '%..%'))
  THEN RAISE EXCEPTION 'Check the item and amount'; END IF;
  IF p_tagged_manager_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.users WHERE uid=p_tagged_manager_id AND role='manager' AND "isActive"
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
  THEN RAISE EXCEPTION 'Advance not found' USING ERRCODE='42501'; END IF;
  IF advance.status<>'cleared' THEN RAISE EXCEPTION 'This advance is not available for spending'; END IF;
  balance := public.core_advance_balance(p_advance_id);
  IF p_amount > balance THEN RAISE EXCEPTION 'This exceeds your remaining advance balance'; END IF;
  INSERT INTO public.advance_items(id,advance_request_id,office_boy_id,office_id,item_description,amount_spent,bill_path,status,tagged_manager_id)
  VALUES(p_id,p_advance_id,actor.uid,advance.office_id,trim(p_item),p_amount,p_bill_path,'pending',p_tagged_manager_id)
  RETURNING * INTO result;
  INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action,detail)
  VALUES(p_advance_id,actor.uid,advance.office_id,actor.uid,'item_added',
    jsonb_build_object('item_id',result.id,'amount',p_amount,'item',result.item_description,'status','pending'));
  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  SELECT uid,'New Advance Item',actor.name||' submitted an advance item for PKR '||p_amount||' for review.',p_advance_id
  FROM public.users WHERE "isActive" AND role='finance';
  IF p_tagged_manager_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
    VALUES(p_tagged_manager_id,'New Tagged Purchase',
      actor.name||' logged a purchase tagged to you for: '||trim(p_item),p_advance_id);
  END IF;
  RETURN result;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
