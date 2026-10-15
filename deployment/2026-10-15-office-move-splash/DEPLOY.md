# Office Boy office transfer and purple Android splash

1. In the existing Petty Cash Supabase SQL Editor, run
   `supabase/migrations/202610150001_office_boy_transfer.sql` once. Do not
   replace or rerun the master schema.
2. Run `deployment/2026-10-15-office-move-splash/VERIFY.sql`; all four columns
   must be `true`.
3. Redeploy the updated account function:

   ```powershell
   npx.cmd supabase functions deploy manage-user --project-ref ysrwvlminsuvwswgpuhh --no-verify-jwt
   ```

4. Install the new APK from `build/app/outputs/flutter-apk/app-release.apk`.
   Cold-launch it to see the purple splash. As Super Admin, move an Office Boy
   who has a test advance to another office. After the Office Boy refreshes or
   signs in again, confirm that the old advance and purchases remain visible
   and that its original office attribution remains unchanged.

The database patch moves the account's office only. It does not rewrite or
delete payment history. Old advances remain spendable by their owner and new
purchases against them retain the original office's accounting attribution.
