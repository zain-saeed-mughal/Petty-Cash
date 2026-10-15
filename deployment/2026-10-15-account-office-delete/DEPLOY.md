# Account and office deletion

1. Run `supabase/migrations/202610150002_safe_account_office_delete.sql` in the
   existing Petty Cash Supabase SQL Editor. This installs functions and does not
   delete existing accounts or offices.
2. Run `VERIFY.sql` in SQL Editor. All five results should be `true`.
3. The updated `manage-user` Edge Function was deployed on 2026-10-16.
   To redeploy from the Petty Cash project folder if needed:

   ```powershell
   npx.cmd supabase functions deploy manage-user --project-ref ysrwvlminsuvwswgpuhh --no-verify-jwt
   ```

4. Install `build/app/outputs/flutter-apk/app-release.apk` on the phone.

Super Admin can permanently delete any account other than their own. The
service-role purge removes all linked financial transactions, their ledger and
activity rows, notifications and receipts, even when another user owns a
linked transaction. The app confirmation makes this explicit. A failed cleanup
leaves the account disabled and can be retried. Main Office is protected.
Other offices can be deleted only when no account or historical financial row
points to them.
