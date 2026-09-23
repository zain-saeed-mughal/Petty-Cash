# Petty Cash — complete application review

Finalized 24 September 2026. Code and execution checks performed 23–24 September, against commit **fcea3a3 — Advanced App**. Review covers Flutter screens, providers, authentication, services, repository SQL, storage, notifications, reporting, platform setup, tests and responsive layouts. Application source and live database were not modified.

**Verdict:** the app builds and several earlier UI/security hygiene improvements are present, but it is not ready for production approval. The highest risks are authorization in the supplied SQL, incompatible database contracts, unreliable account/payment mutations, and expiring receipt links. Successful compilation does not establish correct financial behavior or safe deployed policies.

**Evidence boundaries:** “repository SQL” findings describe the checked-in schema, including isolated PostgreSQL reproductions performed during this review. This SQL is unchanged from commit 9b4f990. They do not prove that identical policies are currently deployed. Live checks used the app's public key and zero-row queries only; no private record contents, account creation, sign-in, or live mutations were used. Deployed RLS policies, RPC bodies, grants, Realtime publication and storage visibility remain unverified.

## Verification results

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | Pass: no issues found |
| `flutter test --no-pub` | **Fail: 3 passed, 1 failed**; app smoke test missing AuthProvider |
| `flutter build web --no-pub` | Pass; web output built |
| Responsive widget probe | **96 combinations; 15 with captured layout errors** |
| Live database contract probes | Missing `users.fcmToken`; legacy password column and snake_case notification fields still exist |
| Android/iOS device builds and real push delivery | Not executed |
| Authenticated live role/payment workflows | Not executed |

The responsive probe used actual screen widgets, synthetic records, bundled Material icons and a locally loaded Inter font. It exercised 320, 360, 390, 768, 1024 and 1440px widths, plus 1.5 text scale at 360 and 1024px. Navigation space was simulated, not the complete live navigation shell. Scrolling was exercised; expected failures for synthetic receipt URLs were excluded. The harness captures errors and therefore its process exit status alone is not a pass criterion. See [probe and evidence folder](<C:/Users/DEV-BT/Desktop/Petty Cash/review/2026-09-24>).

## Critical and high-priority findings

### 1. P1 — Self-profile policies allow privilege escalation

[supabase_schema.sql:60](<C:/Users/DEV-BT/Desktop/Petty Cash/supabase_schema.sql:60>) permits an authenticated user to update their entire profile row, checking only UID, name and email. The insert policy at line 66 also leaves `role` under caller control. An office-boy account can write `role = 'super_admin'`; an inactive user can reactivate themselves. `current_user_role()` then trusts those values. This was reproduced against the supplied SQL in an isolated database, including access to other profiles after escalation.

Restrict self-service changes to explicitly allowed columns and move role/activation/account creation into protected server operations. Row policies alone do not limit writable columns: [Supabase column security](https://supabase.com/docs/guides/database/postgres/column-level-security).

### 2. P1 — Staff can insert a request already marked Paid

[supabase_schema.sql:111](<C:/Users/DEV-BT/Desktop/Petty Cash/supabase_schema.sql:111>) checks ownership, description and amount but does not require Pending status, active employment, empty reviewer fields or server-owned audit data. An authenticated staff client can submit a Paid request directly, bypassing the intended finance workflow. An inactive account can also insert its own request. Both were reproduced with the supplied SQL.

Enforce an active requester and initial state on the server, and generate review/audit fields through controlled transitions.

### 3. P1 — The schema file is neither a safe upgrade nor safely rerunnable

[supabase_schema.sql:36](<C:/Users/DEV-BT/Desktop/Petty Cash/supabase_schema.sql:36>) drops different names from some policies it subsequently creates. A second execution fails with a duplicate-policy error. `CREATE TABLE IF NOT EXISTS` does not migrate existing columns, keys or constraints. The receipt bucket insert at line 185 uses `ON CONFLICT DO NOTHING`, so an existing public bucket stays public.

Applying the original repository schema followed by the current schema in an isolated database retained legacy permissive policies, text request IDs, a cascading request-owner foreign key and a public receipt bucket. Such permissive policies can continue granting access alongside newer restrictions. Use versioned migrations that explicitly retire old policies, transform columns, repair foreign keys and set bucket visibility. See [PostgreSQL table creation](https://www.postgresql.org/docs/16/sql-createtable.html) and [policy combination rules](https://www.postgresql.org/docs/16/sql-createpolicy.html).

### 4. P1 — Fresh database and app contracts disagree

[expense_provider.dart:183](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/providers/expense_provider.dart:183>) generates `REQ-XXXXXXXX`; [schema line 73](<C:/Users/DEV-BT/Desktop/Petty Cash/supabase_schema.sql:73>) requires UUID. Fresh-schema request insertion fails. Separately, [notification_model.dart:24](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/models/notification_model.dart:24>) writes `is_read` and `related_request_id`, but the SQL declares `isRead` and `relatedRequestId`.

The live zero-row checks accepted the sample `REQ-` filter and snake_case notification columns, while rejecting camelCase columns. This explains how the deployed app can behave differently from a fresh installation. Pick one canonical schema and provide a tested migration; changing only the client or only the setup SQL will not resolve both environments.

### 5. P1 — Payment decisions can overwrite one another and lose audit history

[database_service.dart:105](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/services/database_service.dart:105>) updates the complete request map using only its ID. [expense_provider.dart:246](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/providers/expense_provider.dart:246>) creates that map from cached state, including the audit array. Two reviewers can act on stale Pending copies: a later rejection can overwrite an earlier payment and its audit entry. SQL line 130 permits this because it does not restrict the previous status or the fields changed. The isolated SQL reproduction accepted Paid → Rejected with replacement audit data.

Use a transactional server operation with expected status/version, immutable audit append and an explicit allowed-transition matrix. The detail screen should also refresh the request by ID before acting. The current SQL additionally rejects a super-admin reset to Pending for a request owned by somebody else, although the app exposes override behavior.

### 6. P1 — Account administration cannot be reproduced from this repository

[database_service.dart:144](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/services/database_service.dart:144>) depends on `admin_create_user`, `update_user_credentials` and `delete_user`. Their definitions and deployment instructions are absent from the supplied backend. Fresh provisioning therefore cannot supply these operations; create-user fallback rejects the empty UID passed by the UI. Existing live RPC availability and authorization were not verified.

There are independent correctness defects: email-only edits change the profile but never Supabase Auth; password-RPC errors are swallowed at line 205; deletion falls back to deleting only the profile when the RPC fails. This can report success with unchanged login credentials or leave an Auth account behind. The SQL also allows only self/super-admin profile writes, while the Admin UI offers management of staff. Updates do not check affected rows, so RLS-denied mutations can appear successful. Provide protected server operations and return explicit, verified outcomes.

### 7. P1 — Saved receipt links expire after one hour

[storage_service.dart:62](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/services/storage_service.dart:62>) returns a signed URL valid for 3,600 seconds. Submission persists that URL as `billImageUrl`; viewers reuse it without renewal. After expiry, a later receipt fetch cannot open the historical attachment. Store the object path and generate a fresh authorized URL when viewing. Also remove newly uploaded orphan files when request insertion fails.

### 8. P1 — User/request caches are not reset with authentication

[main.dart:24](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/main.dart:24>) creates ExpenseProvider and UserProvider for the app lifetime. Their constructors start subscriptions, but neither is keyed to the authenticated UID or cleared on sign-out. Only NotificationProvider follows AuthProvider changes. Existing records and errors can survive account switches, and the new user does not receive a guaranteed clean initial fetch. This is a shared-device data-isolation risk, especially between management roles; exact visible exposure depends on screen filters and stream behavior.

Cancel subscriptions, clear data immediately and recreate the providers when identity changes. Do not rely on RLS to erase information already cached in memory.

### 9. P2 — Disabled/missing-profile login leaves an Auth session behind

[auth_service.dart:92](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/services/auth_service.dart:92>) authenticates before loading the app profile. An inactive or absent profile throws without signing out the newly created Auth session. The generic catch also hides the useful inactive-account explanation. There is no ongoing profile-deactivation watcher. Combined with owner policies that ignore active status, disabling a profile is not a dependable access cutoff. Clear failed-login sessions and enforce active status in every protected server operation/policy.

## Notifications, submission and reporting

### 10. P2 — New FCM token persistence fails against the live database

[auth_service.dart:19](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/services/auth_service.dart:19>) writes `users.fcmToken`, but the live contract query returned PostgreSQL error **42703: column users.fcmToken does not exist**. The supplied SQL omits it too. Errors are swallowed, so a successful login does not establish a usable push destination. Add the migration and verify persistence before treating push as complete.

### 11. P2 — Push integration is incomplete across supported platforms

[push_notification_service.dart:25](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/services/push_notification_service.dart:25>) initializes Firebase without generated cross-platform options. Android configuration exists, but the repository lacks iOS Firebase configuration/entitlements and the web messaging service worker. No server sender/trigger is included. Foreground messages only log; token refresh, sign-out token cleanup and notification-tap routing are absent. A separately configured external sender may exist, but was not verified.

Complete platform setup and token lifecycle, then test real devices in foreground/background/terminated states. See [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup) and [FCM Flutter requirements](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

### 12. P2 — In-app notification creation/deletion conflicts with fresh RLS

[expense_provider.dart:213](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/providers/expense_provider.dart:213>) asks the requesting office-boy client to find managers and notify them. Fresh policies prevent that user from reading manager profiles and inserting notifications for other users. Moving this action server-side also makes it reliable if the client disconnects after submission.

The new swipe-delete path calls [database_service.dart:287](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/services/database_service.dart:287>), but the SQL has no notification DELETE policy. A denied deletion can affect zero rows without throwing; optimistic removal then looks successful until reload. Optimistic operations also need rollback/error feedback.

### 13. P2 — Receipt upload failure can leave submission stuck

[new_request_screen.dart:83](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/office_boy/new_request_screen.dart:83>) sets submitting=true before an upload with no surrounding try/finally. An upload exception never resets the button. The validation return at line 108 also leaves it set. The line 119 setState happens after asynchronous work without checking mounted, so leaving the screen can produce setState-after-dispose. Capture form values before uploading, handle failure, clean up in finally and guard every post-await UI access.

### 14. P2 — “Approved / Paid” filters omit Approved records

[my_requests_screen.dart:179](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/office_boy/my_requests_screen.dart:179>), [all_transactions_screen.dart:304](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/admin/all_transactions_screen.dart:304>) and [payment_history_screen.dart:187](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/finance/payment_history_screen.dart:187>) label a combined category but select only `RequestStatus.paid`. Their equality filters exclude Approved. The chip count can therefore disagree with the displayed list. Use a set of statuses or separate chips.

### 15. P2 — Financial summaries mix different meanings

[expense_provider.dart:140](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/providers/expense_provider.dart:140>) includes Approved and Paid in totalSpent, while payment history presents this as settled/paid and analytics as disbursed. Outstanding approvals can inflate cash actually paid. [monthly_reporting_screen.dart:47](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/reports/monthly_reporting_screen.dart:47>) groups by creation month, so a September request paid in October is attributed to September's paid total. User/status filters change the table but not its summary cards. Define each metric explicitly, persist paidAt and make filter scope visible and consistent.

### 16. P2 — Analytics merges different people with the same name

[analytics_screen.dart:433](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/super_admin/analytics_screen.dart:433>) groups totals by `requesterName`. Two employees named the same are combined; a renamed employee can be split. Group by immutable requestedBy UID and display the name separately.

### 17. P2 — Timestamp serialization is inconsistent

[expense_request_model.dart:89](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/models/expense_request_model.dart:89>) serializes local DateTime values without converting to UTC. Such strings lack an offset; TIMESTAMPTZ interprets them in the database session timezone, which can shift the actual instant. Notification and audit timestamps have the same pattern, and display/grouping does not consistently convert parsed UTC values to local time. Use server timestamps or UTC serialization and an explicit reporting timezone.

### 18. P2 — Data loading errors can look like empty or zero-valued reports

[expense_provider.dart:46](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/providers/expense_provider.dart:46>) stores stream errors, but many list/report screens continue showing their cached/empty collections without a visible loading/error/retry state. Errors also are not cleared on a later successful stream event. For a cash application, zero totals must be distinguishable from unavailable data.

### 19. P2 — Complete-history totals depend on an unpaginated client stream

[database_service.dart:61](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/services/database_service.dart:61>) loads requests into memory and computes all summaries on the client. No paging or server aggregate contract establishes that this is the complete history. With an API response cap, totals can silently omit older rows; large uncapped responses grow memory and table costs. Supabase documents a default 1,000-row response limit, configurable per project; the live cap was not inspected. Use server aggregates plus paginated detail queries and provision Realtime publication explicitly. [Select limits](https://supabase.com/docs/reference/dart/select), [stream setup](https://supabase.com/docs/reference/dart/stream).

## Frontend and responsiveness

### 20. P2 — Reports break at small desktop/tablet landscape widths

[monthly_reporting_screen.dart:244](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/reports/monthly_reporting_screen.dart:244>) selects four columns using full-screen width, even when navigation reduces usable space. Fixed aspect ratio 2.2 makes cards too short. At 1024px, all four cards overflow vertically; the amount's FittedBox at line 410 shrinks the value to near-illegibility. At 1.5 text scale, overflows grow to 47–52px. Choose columns from local LayoutBuilder constraints and preserve readable text with adaptive card height.

![Reports at 1024px with normal text scale](<C:/Users/DEV-BT/Desktop/Petty Cash/review/2026-09-24/reports_1024_1.0.png>)

### 21. P2 — Narrow-screen actions and enlarged text overflow

| Screen / source | Reproduced failure |
|---|---|
| [My Requests:497](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/office_boy/my_requests_screen.dart:497>) | Receipt button overflows 62–63px at 320; 22–23px at 360; 153–154px at 360/1.5 |
| [Payment History:445](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/finance/payment_history_screen.dart:445>) | Footer actions overflow 12px at 320; 58px at 360/1.5 |
| [Request Detail:202](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/finance/request_detail_screen.dart:202>) | Header row overflows 31px at 320; 104px at 360/1.5 |
| [Rejection dialog:54](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/widgets/rejection_reason_dialog.dart:54>) | Title row overflows 45px at 320, 5.1px at 360 and 92px at 360/1.5 |
| [Notifications:30](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/widgets/notifications_panel.dart:30>) | Header overflows 42px at 360/1.5 and 1.8px at 1024/1.5 |
| [Report dropdown:177](<C:/Users/DEV-BT/Desktop/Petty Cash/lib/screens/reports/monthly_reporting_screen.dart:177>) | Dropdown row overflows 35px at 360/1.5 and 28px at 1024/1.5 |

Use flexible or wrapping controls and vertical arrangements when content cannot fit. Preserve tap targets and text scaling; do not solve these by shrinking all text. [web/index.html:34](<C:/Users/DEV-BT/Desktop/Petty Cash/web/index.html:34>) also explicitly disables user zoom and should allow browser accessibility zoom. These are failures in representative fixtures, not a claim that every record/device overflows.

## Tests, release setup and remaining data hygiene

### 22. P2 — Current smoke test is broken after provider relocation

[test/widget_test.dart:7](<C:/Users/DEV-BT/Desktop/Petty Cash/test/widget_test.dart:7>) pumps PettyCashApp directly. Providers now live outside it in main(), so RoleRouter throws ProviderNotFoundException for AuthProvider. This is a reproduced test/bootstrap-contract regression, **not proof of a production startup crash**: main() supplies the providers. Use the production provider wrapper or a testable app bootstrap. Existing passing tests do not cover the authorization, upload failure or concurrent payment scenarios above.

### 23. P2 — Android release configuration still uses the debug signing key

[android/app/build.gradle.kts:37](<C:/Users/DEV-BT/Desktop/Petty Cash/android/app/build.gradle.kts:37>) assigns debug signing to release builds. Configure the intended release/upload signing identity before distribution. Web compilation does not validate Android or iOS packaging, permissions or native Firebase behavior.

### 24. P2 — Legacy password column remains in the deployed schema

The zero-row `users?select=password&limit=0` request returned 200, confirming the column exists. No values were fetched: whether it contains old passwords and who can read them are unknown. The current model correctly avoids password persistence, but client cleanup does not remove old server data. Inventory and securely remove any legacy credential data through a migration; assess reset requirements only if actual stored credentials are confirmed.

### 25. P2 — Database amount validation does not exclude NaN

[supabase_schema.sql:78](<C:/Users/DEV-BT/Desktop/Petty Cash/supabase_schema.sql:78>) uses `amount > 0 AND amount = amount::numeric`; the second term does not establish finiteness. PostgreSQL numeric NaN passed this constraint in the isolated reproduction. Current UI validation rejects non-finite doubles, which is good, but direct API clients bypass it. Reject non-finite values explicitly at the database boundary and define accepted currency precision.

Additional lower-priority cleanup: ExpenseRequest.copyWith cannot clear an existing rejectionReason by passing null (line 159); request IDs use only eight UUID hex digits, so a UUID primary key plus separate display reference would age better; receipt upload labels every selected image as JPEG; README SDK requirements need alignment with the current pubspec; hardcoded environment configuration should be separated for dev/staging/production. None of these replace the higher-priority fixes.

## Improvements confirmed in the current code

- Dart analysis is clean and the web bundle builds.
- Passwords are not serialized in the current user profile model; account creation uses a temporary credential rather than exposing stored passwords in the UI.
- Request approval controls now check the user's approval capability and Pending state.
- Request amount validation rejects non-positive/non-finite input; storage applies a 10MB limit.
- Payment-history header/date layout adapts better to narrow screens; remaining footer issues are identified above.
- Android Internet permission and iOS image/camera usage descriptions are present.
- Notification actions now update immediately in the UI, although persistence and rollback still need correction.

## Recommended implementation sequence

1. Make database changes reproducible: canonical schema, versioned upgrades, least-privilege policies, protected account/payment operations and immutable audit history. Verify the deployed policy/RPC state in an authorized staging environment.
2. Fix receipt storage references, Auth/profile synchronization, identity-scoped caches and submission cleanup. Test interrupted uploads, denied updates and concurrent reviewers.
3. Correct financial definitions, status filters and reporting dates; test Approved vs Paid, cross-month payments and duplicate employee names.
4. Repair responsive layouts and the app smoke test; promote the failing fixtures into assertions that fail on Flutter layout errors.
5. Finish push platform/sender/token setup and release signing; validate actual Android/iOS devices and a fresh database installation before release.

**Saved evidence:** [layout results](<C:/Users/DEV-BT/Desktop/Petty Cash/review/2026-09-24/layout_results.json>), [live zero-row contract results](<C:/Users/DEV-BT/Desktop/Petty Cash/review/2026-09-24/live_contracts.json>), [layout probe](<C:/Users/DEV-BT/Desktop/Petty Cash/review/2026-09-24/probe_test.dart>), [probe log](<C:/Users/DEV-BT/Desktop/Petty Cash/review/2026-09-24/layout_run.log>). The isolated SQL findings were reproduced earlier in this review against the identical schema; their temporary harness is not included in this evidence folder.
