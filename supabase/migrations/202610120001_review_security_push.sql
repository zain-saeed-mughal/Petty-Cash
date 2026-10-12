-- Apply after the 2026-10-12 master upgrade on an existing Petty Cash database.
BEGIN;

-- Persist successful per-device sends so a failed later device does not cause
-- earlier devices to receive the same notification again on worker retry.
CREATE TABLE IF NOT EXISTS public.push_device_deliveries (
  notification_id uuid NOT NULL REFERENCES public.push_outbox(id) ON DELETE CASCADE,
  device_token text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (notification_id, device_token)
);
ALTER TABLE public.push_device_deliveries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_device_deliveries FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.push_device_deliveries TO service_role;

-- A tagged purchase permits the manager to see only that purchase's spend,
-- not the advance credit or unrelated purchases in the same advance.
DROP POLICY IF EXISTS advance_ledger_read ON public.advance_ledger;
CREATE POLICY advance_ledger_read ON public.advance_ledger
FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin')
  OR (office_boy_id = auth.uid() AND office_id = public.current_office_id())
  OR (public.current_user_role() = 'manager' AND entry_type = 'spend'
      AND EXISTS (SELECT 1 FROM public.advance_items ai
                  WHERE ai.id = advance_ledger.advance_item_id
                    AND ai.tagged_manager_id = auth.uid()))
);

-- Advance activity identifies an item in detail.item_id. A manager can read
-- only events for an item tagged to them; reimbursement access is unchanged.
DROP POLICY IF EXISTS core_activity_read ON public.core_payment_activity;
CREATE POLICY core_activity_read ON public.core_payment_activity
FOR SELECT TO authenticated USING (
  public.current_user_role() IN ('finance','admin','super_admin')
  OR (office_boy_id = auth.uid() AND office_id = public.current_office_id())
  OR (public.current_user_role() = 'manager' AND (
      EXISTS (SELECT 1 FROM public.advance_items ai
              WHERE ai.id::text = core_payment_activity.detail->>'item_id'
                AND ai.tagged_manager_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.reimbursement_requests rr
                 WHERE rr.id = core_payment_activity.reimbursement_id
                   AND rr.tagged_manager_id = auth.uid())
  ))
);

-- Match the card-account requirement already shown in the request form.
CREATE OR REPLACE FUNCTION public.request_advance_v2(
  p_id uuid,p_purpose text,p_amount numeric,p_method text,
  p_account_name text DEFAULT NULL,p_account_details text DEFAULT NULL
) RETURNS public.advance_requests LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor public.users; result public.advance_requests;
BEGIN
  SELECT * INTO actor FROM public.users WHERE uid = auth.uid() AND "isActive";
  IF actor.role IS DISTINCT FROM 'office_boy' THEN
    RAISE EXCEPTION 'Only an Office Boy can request an advance' USING ERRCODE='42501';
  END IF;
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

NOTIFY pgrst, 'reload schema';
COMMIT;
