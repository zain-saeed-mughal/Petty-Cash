# Current application review — 25 September 2026

**Follow-up:** Findings 1, 2 and 4–8 have now been addressed in source and migrations 022/023. Finding 3 (user deactivation) was explicitly excluded by the owner and remains unchanged. Updated deployment files are in `deployment/2026-09-25-review-fixes/`. The findings below document the reviewed pre-fix revision, not the final implementation.

Verdict: do not label this revision production-ready yet. The latest partial-settlement changes introduce functional regressions that static analysis and the existing tests do not detect. This was a focused source and local regression review, not a live authenticated deployment audit. No production records or application source were changed during this review.

## Confirmed findings, ordered by impact

1. **P1 — Settlements remove real payments from financial totals.** `lib/providers/expense_provider.dart:178` totals only `isPaid`; `lib/models/expense_request_model.dart:108` defines that as exactly `Paid`. After a paid advance becomes `Pending Settlement` or `Settled`, dashboard and monthly paid totals exclude it. `lib/screens/reports/monthly_reporting_screen.dart:55` repeats the filter, and the model's reporting date switches back to creation time. Example: an issued Rs. 10,000 advance disappears from paid totals when its settlement is submitted. Define separate disbursed, spent, returned and outstanding measures; retain payment dates through settlement.

2. **P1 — The newest settlement migration removes server validation.** `supabase/migrations/202609250020_partial_settlements.sql:20` replaces the hardened function from migration 019 with only a lower/upper amount comparison. Local PostgreSQL probes confirmed that NULL enters Pending Settlement and `10.123` with method `INVALID` is accepted (the amount silently rounds to `10.12`). Note-length and return-method checks are also lost. Restore the validation while retaining updates to pending settlements; validate again before verification.

3. **P1 — Account deactivation always sends an unsupported action.** `lib/services/database_service.dart:234` sends `action: delete`, while `supabase/functions/manage-user/handler.ts:16` accepts only `create`, `update`, `deactivate`. The UI explicitly promises deactivation. Even a correctly deployed current handler returns HTTP 400 / Invalid action. Send `deactivate` and add a test covering the actual client/server contract.

4. **P2 — Editing a pending settlement generates no notification.** Migration 020 supports `Pending Settlement` to `Pending Settlement` updates, but `supabase/migrations/202609250021_settlement_notifications.sql:8` emits notifications only when status changes. A local database probe measured zero new notifications after a settlement amount/method update. Notify on a changed settlement revision or relevant settlement fields as well, without notifying for unrelated edits.

5. **P2 — The finance pending queue excludes pending settlements.** `lib/providers/expense_provider.dart:127` admits only `Pending`. Finance receives an approval notification but does not see that settlement in its work queue or pending count; it must find it via notification/history. Include a separate settlement review queue or include both actionable states, with consistent badges and counts.

6. **P2 — Super-admin override offers statuses its RPC rejects.** `lib/widgets/request_override_dialog.dart:80` offers every enum status, including Pending Settlement and Settled. `supabase/migrations/202609250019_advance_validation.sql:35` only accepts Pending, Approved, Rejected and Paid. Restrict choices to supported transitions; settlement completion must use the settlement-verification flow.

7. **P2 — Latest Urdu screens still contain hardcoded English.** `lib/screens/office_boy/my_requests_screen.dart:620` displays literal `Update Settlement`. The new wallet summaries use literal `Rs.` and `toStringAsFixed(0)` at that screen's line 184 and `lib/screens/finance/pending_requests_screen.dart:159`, losing localized currency and cents. Use the existing language text and money helpers. Newly added settlement notification messages also fall back to generic Urdu text, so the translated notification loses its specific meaning.

8. **P2 — Data refresh cost grows with all historical records.** `lib/services/database_service.dart:118` downloads every 500-row page, including audit logs, on each relevant realtime event and every 45 seconds (line 157). A 10,000-record table costs at least 20 reads per full refresh per connected privileged client. Offset pagination during concurrent insertion/deletion can also produce an inconsistent snapshot. Use paginated screen queries and server-side reporting aggregates; measure with realistic history volume.

## Deployment and notification boundaries

- `web/firebase-config.js` currently contains a null configuration. Web push requires production Firebase definitions, a populated service-worker config, a deployed sender, and a scheduler/webhook invoking the sender. Live delivery and server configuration were not verified in this review; in-app notifications are a separate mechanism.
- The earlier deployment ZIP contains migrations 018/019 and predates source migrations 020/021. It is not a release of the complete current source. Rebuild the package after resolving these regressions.
- No new Android release or iOS archive was built. Store signing, physical-device behavior and authenticated live account/settlement flows remain deployment checks.

## Verification

- Fresh Flutter analysis: no issues found.
- Existing local database security/workflow suite: passed against all current migrations, including 020/021.
- Additional local probe reproduced invalid settlement acceptance and missing update notifications. Probe output: `.dart_tool/review_probe.log`; generator: `.dart_tool/create_review_probe.mjs`.
- Fresh Flutter widget/layout suite: 13 tests passed, including the responsive screen matrix; no render overflow was reported for the tested configurations. Log: `.dart_tool/review_latest_tests.log`.

Passing the existing tests does not invalidate the findings above: those tests do not yet assert these client/server contracts, settlement totals or repeat-settlement notification behavior.
