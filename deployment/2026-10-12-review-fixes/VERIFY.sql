SELECT
  to_regclass('public.push_device_deliveries') IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM pg_class c
      WHERE c.oid = to_regclass('public.push_device_deliveries')
        AND c.relrowsecurity
    ) AS push_tracking_ready,
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='advance_ledger'
      AND policyname='advance_ledger_read'
      AND qual LIKE '%advance_item_id%'
      AND qual LIKE '%entry_type%'
  ) AND EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='core_payment_activity'
      AND policyname='core_activity_read'
      AND qual LIKE '%item_id%'
  ) AS manager_scope_ready;
