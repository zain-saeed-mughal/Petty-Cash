-- 0. Ensure tagged_manager_id exists
ALTER TABLE public.advance_items ADD COLUMN IF NOT EXISTS tagged_manager_id uuid REFERENCES public.users(uid) ON DELETE RESTRICT;
ALTER TABLE public.reimbursement_requests ADD COLUMN IF NOT EXISTS tagged_manager_id uuid REFERENCES public.users(uid) ON DELETE RESTRICT;

-- 1. DROP old function
DROP FUNCTION IF EXISTS public.direct_allot_advance_v2(uuid, uuid, numeric, text, text, uuid);

-- 2. RECREATE direct_allot_advance_v2
CREATE OR REPLACE FUNCTION public.direct_allot_advance_v2(
  p_id uuid, p_office_boy_id uuid, p_amount numeric, p_purpose text, p_method text
) RETURNS public.advance_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  actor public.users;
  boy public.users;
  result public.advance_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid = auth.uid() AND "isActive" = true;
  IF actor.uid IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
  
  IF actor.role IS DISTINCT FROM 'finance' THEN RAISE EXCEPTION 'Only Finance can allot advances' USING ERRCODE='42501'; END IF;
  
  SELECT * INTO boy FROM public.users WHERE uid = p_office_boy_id AND "isActive" = true AND role = 'office_boy';
  IF boy.uid IS NULL THEN RAISE EXCEPTION 'Invalid office boy' USING ERRCODE='42501'; END IF;
  
  INSERT INTO public.advance_requests(id,office_boy_id,office_id,amount,amount_requested,purpose,status,payment_method_requested,flow_version,cleared_by,cleared_method,cleared_at)
  VALUES(p_id,boy.uid,boy.office_id,p_amount,p_amount,trim(p_purpose),'awaiting_office_boy_approval',p_method,2,actor.uid,p_method,now())
  RETURNING * INTO result;
  
  INSERT INTO public.core_payment_activity(advance_request_id,office_boy_id,office_id,actor_id,action)
  VALUES(result.id,boy.uid,boy.office_id,actor.uid,'allotted');
  
  INSERT INTO public.notifications(user_id,title,message,related_core_advance_id)
  VALUES(boy.uid,'Advance needs approval','Finance sent you an advance of PKR '||p_amount||'. Tap to approve.',result.id);
  
  RETURN result;
END $$;

-- 3. DROP ALL old policies that might be referencing allotted_by_manager_id
DROP POLICY IF EXISTS "advance_requests_read" ON public.advance_requests;
DROP POLICY IF EXISTS "advance_requests_v2_select" ON public.advance_requests;
DROP POLICY IF EXISTS "advance_items_read" ON public.advance_items;
DROP POLICY IF EXISTS "advance_items_v2_select" ON public.advance_items;
DROP POLICY IF EXISTS "advance_ledger_read" ON public.advance_ledger;
DROP POLICY IF EXISTS "advance_ledger_select" ON public.advance_ledger;
DROP POLICY IF EXISTS "core_activity_read" ON public.core_payment_activity;
DROP POLICY IF EXISTS "core_payment_activity_select" ON public.core_payment_activity;

-- 4. RECREATE policies correctly
CREATE POLICY advance_requests_read ON public.advance_requests FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id())
);

CREATE POLICY advance_items_read ON public.advance_items FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id()) OR
  (public.current_user_role() = 'manager' AND tagged_manager_id = auth.uid())
);

CREATE POLICY advance_ledger_read ON public.advance_ledger FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id())
);

CREATE POLICY core_activity_read ON public.core_payment_activity FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin') OR
  (office_boy_id = auth.uid() AND office_id = public.current_office_id()) OR
  (public.current_user_role() = 'manager' AND (
    EXISTS(SELECT 1 FROM public.reimbursement_requests rr WHERE rr.id = core_payment_activity.reimbursement_id AND rr.tagged_manager_id = auth.uid())
  ))
);

-- 5. FINALLY drop the column
ALTER TABLE public.advance_requests DROP COLUMN IF EXISTS allotted_by_manager_id;
