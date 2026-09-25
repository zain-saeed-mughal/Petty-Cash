# Petty Cash — 25 September fixes

This package fixes the account dialog, the super-admin delete action, English/Urdu request-type controls and the account header. **The live project has not been changed.** Its `manage-user` endpoint returned HTTP 404 during verification, which explains the account create/edit failures.

## 1. Update the existing database

In Supabase project `ysrwvlminsuvwswgpuhh`, open **SQL Editor**, paste `database-update.sql`, and run it once. It is safe to rerun. This patch assumes the advance/settlement schema already used by your app is installed.

- Enables super-admin deletion of Pending, Approved, Rejected, Paid, Pending Settlement and Settled transactions.
- Removes deleted transactions from active lists and report totals; keeps their complete snapshots in the protected `request_deletion_audit` table.
- Keeps non-super-admin deletion blocked.
- Removes the obsolete request-submission overload and validates settlement amounts and request versions.

Do not replace this incremental patch with an older full schema file.

## 2. Deploy the missing account function

Open **Edge Functions → Deploy a new function → Via Editor**. Name it exactly **`manage-user`**. Replace the editor's `index.ts` with the complete contents of this package's **`manage-user.ts`**, then deploy.

In the function settings, turn **Verify JWT with legacy secret** off, matching the repository's `supabase/config.toml`. The handler itself verifies every bearer token with Supabase Auth and checks the actor's active status and role. It never accepts an unauthenticated account change. Supabase provides the function's `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` automatically; do not put a service-role key in the Flutter app.

CLI alternative, from the repository root after signing into the Supabase CLI:

```powershell
npx supabase functions deploy manage-user --project-ref ysrwvlminsuvwswgpuhh --no-verify-jwt
```

New and changed passwords must be **6–8 characters**. If Auth's configured minimum is greater than 8, set its minimum to 6 under Authentication password/security settings. Existing passwords remain unchanged and can still be used to sign in. When editing a user, leave the password empty to retain the existing password.

## 3. Install/publish the updated frontend

- **Android:** `petty-cash-test.apk` is a debug-signed test build. Use it to verify the changes on your phone. For Play Store distribution, configure `android/key.properties` with your upload key and build `flutter build appbundle --release` from the source project. Release builds no longer silently use the debug signing key.
- **Web:** extract `petty-cash-web.zip` and publish its contents on your HTTPS host. It targets the existing Supabase project. For a different project or Firebase web push, use `tool/build_web.ps1` with your production configuration. In-app notifications work independently of Firebase push setup.
- **iOS:** the source contains the same UI fixes. Build/sign on macOS with Xcode using your Apple team, bundle ID and Firebase iOS configuration. An iOS archive has not been built on this Windows machine.

## 4. Check after deployment

1. Sign in as super-admin. Create a disposable user with an eight-character password; sign in as that user.
2. Edit that user’s name. Then change its password and confirm the new password signs in. A blank password must preserve the previous one.
3. On a disposable test transaction, press Delete, cancel once, then confirm. Verify it disappears and its audit snapshot exists. Do not use a real payment as a test record.
4. Select Urdu: request types read **خرچ کی واپسی** and **پیشگی رقم**, each on one line. Check the settlement labels too.
5. Check the header: **ENG / اردو**, account name, notification bell and sign-out. Page headings remain in the page content, not the top bar.

If account management still reports “not deployed”, check the project and function name. If it reports an expired session, sign out and sign in again. Backend failures now show a useful message rather than a bare “Exception”.
