# Updated review fixes — 25 September 2026

Apply the SQL before installing this frontend. The frontend now calls `sync_requests` for incremental transaction updates.

1. In your existing Supabase project's SQL Editor, run **database-update.sql**. It includes the language-device migration and migrations 018–023 in order, including the settlement corrections and change feed. It assumes your existing advance/settlement schema (017) is installed. Running the patch does not delete accounts or transactions.
2. If you need the complete schema in one file, **full-schema.sql** contains all repository migrations in order. Use this for a complete setup/upgrade instead of manually combining old queries. For an existing working project the smaller update is sufficient; do not rerun an older schema after this patch, as that can overwrite corrected functions.
3. Publish the contents of **petty-cash-web.zip**, or install **petty-cash-test.apk** for Android testing. The APK is debug-signed; a store release still requires your signing key. iOS still needs macOS/Xcode signing and verification.
4. No change to `manage-user` is required by these review fixes. If it has never been deployed, its file and instructions remain in the earlier deployment package. The account deactivation issue was intentionally left unchanged at the owner's request.

## Verify after deployment

- Use a disposable advance: create, pay, submit settlement, edit that pending settlement, then verify as Finance.
- Confirm both initial and updated settlement notifications arrive in-app. Finance should see the pending settlement in its work queue with the correct status.
- Disbursed totals and the payment reporting month must stay unchanged through settlement. Verified spending and returns count after Finance verification. Until then the advance remains outstanding; its submitted spending is provisional.
- Try invalid/negative/over-limit/more-than-two-decimal amounts. They must be rejected. A return requires Cash or Card, and notes are limited to 2,000 characters.
- Check Urdu update buttons and currency, including cents.
- Delete a disposable transaction as super-admin and confirm other open sessions remove it too.

## Data loading

The first session sync reads transaction history in pages of at most 500 rows. Subsequent realtime/poll refreshes retrieve only changed transactions and deletion markers. Unchanged history is not downloaded again and an unchanged poll does not rebuild the request list. Manual refresh and a new account session reload the initial snapshot. The change feed has role/owner checks and keeps one latest marker per transaction; audit and receipt access stay protected.

The initial history is still held in client memory to support existing global searches and reports. This change removes repeated history downloads; it is not a claim of unlimited initial-history scalability. No production load test was performed.

No live deployment was performed. Firebase/FCM production configuration and actual device push delivery remain deployment checks; in-app notification tests do not prove push delivery.
