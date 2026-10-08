-- Migration: Give Managers visibility into all records tagged to them.
-- When an Office Boy tags a Manager on an advance item or a reimbursement,
-- that Manager must be able to see those records in their dashboard.

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. advance_items � managers can see any item tagged to them
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS advance_items_read ON public.advance_items;
CREATE POLICY advance_items_read ON public.advance_items
  FOR SELECT TO authenticated USING (
    public.current_user_role() IN ('finance', 'admin', 'super_admin')
    OR (office_boy_id = auth.uid() AND office_id = public.current_office_id())
    OR (public.current_user_role() = 'manager' AND tagged_manager_id = auth.uid())
  );

-- -----------------------------------------------------------------------------
-- 2. reimbursement_requests � managers can see reimbursements tagged to them
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS reimbursements_read ON public.reimbursement_requests;
CREATE POLICY reimbursements_read ON public.reimbursement_requests
  FOR SELECT TO authenticated USING (
    public.current_user_role() IN ('finance', 'admin', 'super_admin')
    OR (office_boy_id = auth.uid() AND office_id = public.current_office_id())
    OR (public.current_user_role() = 'manager' AND tagged_manager_id = auth.uid())
  );

-- -----------------------------------------------------------------------------
-- 3. core_payment_activity � managers can see activity for tagged reimbursements
--    Note: advance_items are linked via advance_request_id (no direct item FK).
--    Activity for reimbursements tagged to this manager is included.
-- -----------------------------------------------------------------------------


DROP POLICY IF EXISTS core_activity_read ON public.core_payment_activity;
CREATE POLICY core_activity_read ON public.core_payment_activity
  FOR SELECT TO authenticated USING (
    public.current_user_role() IN ('finance', 'admin', 'super_admin')
    OR (office_boy_id = auth.uid() AND office_id = public.current_office_id())
    OR (
      public.current_user_role() = 'manager'
      AND (
        EXISTS (
          SELECT 1 FROM public.reimbursement_requests rr
          WHERE rr.id = core_payment_activity.reimbursement_id
            AND rr.tagged_manager_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.advance_items ai
          WHERE ai.advance_request_id = core_payment_activity.advance_request_id
            AND ai.tagged_manager_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.advance_items ai2
          WHERE ai2.office_boy_id = core_payment_activity.office_boy_id
            AND ai2.tagged_manager_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.reimbursement_requests rr2
          WHERE rr2.office_boy_id = core_payment_activity.office_boy_id
            AND rr2.tagged_manager_id = auth.uid()
        )
      )
    )
  );

-- -----------------------------------------------------------------------------
-- 4. advance_requests – managers can see advance payments of their tagged office boys
--    or advances with items tagged to them.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS advance_requests_read ON public.advance_requests;
CREATE POLICY advance_requests_read ON public.advance_requests
  FOR SELECT TO authenticated USING (
    public.current_user_role() IN ('finance', 'admin', 'super_admin')
    OR (office_boy_id = auth.uid() AND office_id = public.current_office_id())
    OR (
      public.current_user_role() = 'manager'
      AND (
        EXISTS (
          SELECT 1 FROM public.advance_items ai
          WHERE ai.advance_request_id = advance_requests.id
            AND ai.tagged_manager_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.advance_items ai2
          WHERE ai2.office_boy_id = advance_requests.office_boy_id
            AND ai2.tagged_manager_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.reimbursement_requests rr
          WHERE rr.office_boy_id = advance_requests.office_boy_id
            AND rr.tagged_manager_id = auth.uid()
        )
      )
    )
  );

COMMIT;
