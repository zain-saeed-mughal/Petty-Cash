# Petty Cash Manager 1.2 deployment

This package upgrades the **existing** Petty Cash Supabase project. It preserves the old financial tables as historical data. Deleting text from a saved SQL Editor tab does not delete database tables or undo an executed query. Do **not** replace the prior 1,871-line schema with this smaller upgrade on a fresh project.

1. Take a Supabase database backup. In the Petty Cash project's SQL Editor, paste and run `RUN_ON_EXISTING_DATABASE.sql` as one script. It contains migrations 029–032 in order. A successful run shows `Success. No rows returned`; do not assume this alone verifies all app roles.
2. Run `VERIFY_DATABASE.sql`. All readiness/RLS columns should be `true`, `users_without_office` should be `0`, and, if the legacy `give_advance` function exists, `old_give_advance_blocked` should be `true`.
3. From the repository root, deploy the changed Edge Functions. Supabase CLI login is already established on this machine; `--no-verify-jwt` is required because `manage-user` validates the caller itself and `send-push` uses its own authorization.

   ```powershell
   npx.cmd supabase functions deploy manage-user --project-ref ysrwvlminsuvwswgpuhh --no-verify-jwt
   npx.cmd supabase functions deploy send-push --project-ref ysrwvlminsuvwswgpuhh --no-verify-jwt
   ```

4. Publish `petty-cash-web.zip` to a static HTTPS host. Install the Android **test** APK for role checks. The release APK in this package is unsigned because this workspace does not contain the private signing key. To publish to Play Store, supply `android/key.properties` and a private keystore, then build a signed AAB. The iOS source zip needs a Mac, Xcode, your Apple team/bundle ID, and signing; an iOS binary cannot be produced on Windows.
5. Before switching everyone to 1.2, sign in with real Office Boy, Finance, Admin and Super Admin accounts and exercise these records in a disposable office: request/clear Cash and Card advances; log items up to and over the remaining balance; submit/approve/reject/pay a reimbursement; inspect notifications, per-person balances and monthly totals; verify an Office Boy cannot see another office. Delete the disposable Office Boy through Super Admin only after checking the account-purge policy. No test records are included in the release.

The app intentionally removes the older payment actions from active navigation. Earlier records remain in the database. New payments start only from an Office Boy's Advance Request or own-money reimbursement request. Finance can view all offices; an Office Boy is limited by RLS to their own office and records. UI language can be changed between English and Urdu without changing stored business values.

Release checks in this workspace: `dart analyze lib test`, `flutter test`, and all five backend/Postgres simulation suites. These check the code and SQL locally; production end-to-end verification still requires the SQL upgrade, Edge deployment, and live role accounts above. Do not interpret the local tests as a claim that the production Supabase project was migrated.
