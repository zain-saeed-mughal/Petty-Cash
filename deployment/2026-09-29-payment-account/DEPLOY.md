# Petty Cash 1.1.0 payment account update

The app now keeps advance money and Office Boy own-pocket reimbursements in separate records. Advance requests require Finance approval and Office Boy receipt confirmation before the amount is spendable. Every new advance expense selects its source advance. Finance can reconcile each advance's credited, held, spent and available amounts against individual purchases and the immutable ledger. Finance and Admin reports can filter period totals while showing current balances separately.

The latest UI groups advance requests, advance history, and expense history into searchable, status-filtered tables that fit phone and desktop widths. Finance sees advance requests and expenses needing decisions together. Office Boys see receipt confirmations and rejected expenses in a clear next-steps section; their dashboard shows an action count. Empty legacy request sections stay hidden when there is no legacy data. Navigation labels and payment statuses use simpler English and Urdu wording.

## Database

Because the 2026-09-28 complete SQL was already applied, paste **only** `database_update.sql` into the same Supabase project's SQL Editor and run it once. It adds `advance_requests`, per-advance expense allocation, related notifications, RLS, and the new RPCs. It preserves existing requests, advances, expenses, receipts, and ledger rows. Earlier float expenses remain in history without an assigned advance because their original source was not recorded. The app calls out these unallocated amounts and limits new spending by both the chosen advance and total available balance.

For a completely new project, use `complete_setup.sql` instead; it includes the previous schema and this update. Do not use both files on the same project.

After applying the update, `test/backend/live_payment_smoke.sql` is an optional rollback-only verification. It requires one active Finance and one active Office Boy account and leaves no test records.

Permanent Office Boy deletion is optional. If migration 027 has not been run, apply `database_optional_user_purge.sql` (027 plus its audit-history fix). If migration 027 was already run, apply **only** `database_purge_audit_fix.sql` (migration 028). Then deploy the current `supabase/functions/manage-user` Edge Function. This action removes that user's financial records and receipt files, so back up the project first. The payment flows above do not depend on these optional migrations.

## App

`petty-cash-web.zip` contains the web release build. Extract its contents to the web host's public directory and route unknown paths to `index.html`.

`petty-cash-android-unsigned.apk` is an **unsigned release build for validation**, not a Play Store upload. Configure `android/key.properties` with your own release keystore, then run `flutter build appbundle --release` or `flutter build apk --release` for publishing. Keep signing files private.

`petty-cash-android-test.apk` is a debug-signed build that you can install on an Android phone for live checks. Do not publish this test APK.

iOS signing and IPA creation must be done on a Mac with Xcode and your Apple signing profile. `petty-cash-ios-source.zip` contains the Flutter iOS source and app files. Extract it on the Mac, run `flutter pub get`, then `flutter build ipa --release` with your signing profile.

The app defaults to the configured Petty Cash Supabase project. For another project, supply `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` when building. Use only the public/publishable key in client builds.

## Verification performed locally

- PostgreSQL migration applied and reapplied in PGlite; role permissions, approval, rejection, balance, allocation and reimbursement flows passed.
- Flutter widget, localization and responsive tests passed, including narrow Urdu screens, enlarged text, history tables, and Office Boy next-step actions.
- Web release and Android release compilation are checked in this package. Hosted Supabase production data was not modified during validation.
