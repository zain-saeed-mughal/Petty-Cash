# Verification — 25 September 2026

## Changes included

- New/replacement account passwords use 6–8 characters in both the dialog and server. Existing login passwords are not truncated. An empty password during editing retains the existing password.
- Account calls authenticate with the current session and retry once after an expired session. Function errors now display a useful message, including a missing deployment.
- Super-admin can delete transactions in all six statuses after confirmation. The database preserves a protected snapshot and rejects deletion by other roles.
- Urdu request types are translated and stay on one line. English uses the same responsive control.
- Dashboard and detail headers show language, signed-in name, notifications and sign-out. Page titles remain in the page content.
- Settlement layouts wrap safely; Urdu action buttons use the app's Arabic font.

## Checks performed

- Flutter tests: 13 passed, including 352 layout combinations across 22 screen variants, 8 size/text-scale combinations and both languages.
- Dart analysis of `lib` and `test`: no issues found.
- Account function: 4 Deno tests passed, covering password bounds, edits without password changes and role restrictions.
- The standalone `manage-user.ts` deployment file and repository entry point passed Deno type checking.
- Local PostgreSQL-compatible schema/workflow tests passed, including repeat migrations, role restrictions, private receipts, version checks, notification permissions, all six deletion statuses and protected deletion snapshots.
- Android debug APK and Web release builds produced successfully. See SHA256SUMS.txt for the packaged file hashes.

## Deployment boundaries

No live database, user or transaction was modified. A read-only diagnostic found the live `manage-user` endpoint returning HTTP 404 (function not found). Authenticated create/edit/delete must be checked after the owner deploys this package, using disposable test records as described in DEPLOY.md.

The SQL patch targets the existing app database with the advance/settlement migration already installed. It is not a fresh-project bootstrap.

The APK is debug-signed for device testing, not a Play Store release. A production Android release needs the owner's signing key. Flutter reported a future Kotlin compatibility warning for `file_picker` and `firebase_core`; it did not block the current build. iOS signing and archive verification require macOS/Xcode and were not performed here. Firebase push delivery requires production platform configuration and was not verified; these fixes do not configure it.
