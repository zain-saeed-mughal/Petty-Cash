-- Read-only checks after 202610150001_office_boy_transfer.sql succeeds.
SELECT
  NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.users'::regclass
      AND tgname='prevent_office_boy_history_move'
      AND NOT tgisinternal
  ) AS old_office_blocker_removed,
  position('An Office Boy with financial history cannot change office'
    IN pg_get_functiondef('public.sync_auth_profile()'::regprocedure))=0
    AS auth_profile_allows_move,
  NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public'
      AND tablename IN ('advance_requests','advance_items','advance_ledger',
                        'reimbursement_requests','core_payment_activity')
      AND policyname IN ('advance_requests_read','advance_items_read',
                         'advance_ledger_read','reimbursements_read','core_activity_read')
      AND qual LIKE '%current_office_id%'
  ) AS old_history_visible_to_owner,
  position('advance.office_id'
    IN pg_get_functiondef('public.log_advance_item_v2(uuid,uuid,text,numeric,text,uuid)'::regprocedure))>0
    AS old_advance_spends_keep_original_office;
