# Petty Cash review fixes

The 2026-10-12 master upgrade is already installed on the existing production
database. Do not replace or rerun historical schema files for this update.

1. In the **Petty Cash** Supabase SQL Editor, run
   `supabase/migrations/202610120001_review_security_push.sql` once. It adds
   per-device push delivery tracking, narrows manager ledger/activity reads,
   and requires account details for card advance requests.
2. Run `deployment/2026-10-12-review-fixes/VERIFY.sql` in a new SQL Editor tab.
   Both booleans must be `true`.
3. Deploy the updated Edge Functions from the repository root:

   ```powershell
   npx.cmd supabase functions deploy manage-user --project-ref ysrwvlminsuvwswgpuhh --no-verify-jwt
   npx.cmd supabase functions deploy send-push --project-ref ysrwvlminsuvwswgpuhh --no-verify-jwt
   ```

4. Build and install the updated Flutter app. Test account editing, a tagged
   purchase, and one notification on two registered phones. The send-push worker
   still relies on the existing scheduled job and Firebase service-account
   secret; this update does not replace either.

An account that cannot be fully deleted is now disabled first. Retry the same
delete action to finish cleanup. New or replacement account passwords require
6–8 characters; existing passwords continue to work until changed.

Web push needs the Firebase web configuration and VAPID key supplied through
`tool/build_web.ps1`. iOS push needs its Firebase plist, APNs setup, signing,
and physical iPhone testing. These credentials are not stored in the repo.
