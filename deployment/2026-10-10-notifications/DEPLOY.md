# Notification fix for the existing Petty Cash project

The SQL migration adds Admin and Super Admin notifications for every new core payment activity across offices. It does not change payment actions or the UI. Existing notifications are not replayed, so test with a new request after applying it.

1. In Petty Cash Supabase SQL Editor, run `supabase/migrations/202610100002_admin_payment_notifications.sql` once. Keep older SQL and data.
2. In the Firebase project used by `android/app/google-services.json` (`petty-cash-73663`), create a **service-account JSON**. In Supabase **Edge Functions → Secrets**, set `FIREBASE_SERVICE_ACCOUNT` to the complete JSON. Never put it in this repository or chat. This secret is currently absent from the live project.
3. Generate a random value of at least 32 characters. Save it as `PUSH_WORKER_SECRET` in Supabase Edge Function secrets. In Supabase **Integrations → Vault**, add another secret named `petty_cash_push_worker_secret` with the **same** value. Keep the value private. This secret is also currently absent from the live project.
4. Deploy the updated worker from the repository root: `npx.cmd supabase functions deploy send-push --project-ref ysrwvlminsuvwswgpuhh --no-verify-jwt`.
5. Run `START_PUSH_WORKER.sql` in the same project's SQL Editor. It schedules queue delivery once per minute. Then run `VERIFY_NOTIFICATIONS.sql` to inspect token counts, pending messages and the schedule.
6. Build and install the updated Android app. Sign in, accept the device notification permission, then create a new payment request from another account. Verify the in-app notification and lock-screen push on a physical device. Android device notification settings can still suppress lock-screen display; the app cannot override a user's OS setting.

For iOS, this workspace currently lacks `ios/Runner/GoogleService-Info.plist`. Add the matching Firebase iOS app config, enable Push Notifications and Remote Notifications for the Runner target in Xcode, and upload the APNs key to Firebase. Test on a physical iPhone. Web push separately needs the web Firebase configuration, VAPID key and HTTPS service worker.

If `VERIFY_NOTIFICATIONS.sql` shows zero device tokens, the installed app did not register for push. If it shows queued or exhausted pushes, inspect the worker logs and `last_error`; do not assume a successful in-app notification means phone delivery works.
