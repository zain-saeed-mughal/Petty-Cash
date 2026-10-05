import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_theme.dart';
import '../../models/payment_models.dart';
import '../../models/user_model.dart';
import '../../widgets/app_status_badge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/submit_payment_expense_dialog.dart';
import '../../widgets/receipt_viewer_dialog.dart';
import '../../widgets/payment_record_table.dart';

String paymentText(BuildContext context, String en, String ur) =>
    context.read<LanguageProvider>().isRtl ? ur : en;

String paymentStatusLabel(BuildContext context, String status) =>
    switch (status) {
      'Awaiting Confirmation' => paymentText(
        context,
        'Waiting for Office Boy',
        'آفس بوائے کی تصدیق باقی',
      ),
      'Received' => paymentText(context, status, 'موصول'),
      'Pending' => paymentText(
        context,
        'Waiting for Finance',
        'فنانس کا فیصلہ باقی',
      ),
      'Approved' => paymentText(context, status, 'منظور شدہ'),
      'Rejected' => paymentText(context, status, 'مسترد'),
      'Rejection Acknowledged' => paymentText(
        context,
        'Rejection confirmed',
        'مستردی کی تصدیق',
      ),
      'Payment Cleared' => paymentText(
        context,
        'Payment sent',
        'رقم دی گئی، تصدیق باقی',
      ),
      'Paid' => paymentText(context, status, 'ادا شدہ'),
      _ => status,
    };

String _activityLabel(BuildContext context, String action) => switch (action) {
  'Advance Given' => paymentText(
    context,
    'Finance gave the advance',
    'فنانس نے ایڈوانس دیا',
  ),
  'Advance Received' => paymentText(
    context,
    'Office Boy confirmed receipt',
    'آفس بوائے نے وصولی کی تصدیق کی',
  ),
  'Expense Submitted' => paymentText(
    context,
    'Expense sent to Finance',
    'خرچہ فنانس کو بھیجا گیا',
  ),
  'Expense Approved' => paymentText(
    context,
    'Finance approved the expense',
    'فنانس نے خرچہ منظور کیا',
  ),
  'Expense Rejected' => paymentText(
    context,
    'Finance rejected the expense',
    'فنانس نے خرچہ مسترد کیا',
  ),
  'Rejection Acknowledged' => paymentText(
    context,
    'Rejection acknowledged',
    'مستردی تسلیم کی گئی',
  ),
  'Payment Cleared' => paymentText(
    context,
    'Finance recorded payment',
    'فنانس نے ادائیگی درج کی',
  ),
  'Payment Received' => paymentText(
    context,
    'Office Boy confirmed payment',
    'آفس بوائے نے رقم ملنے کی تصدیق کی',
  ),
  _ => action,
};

String _activityDetail(BuildContext context, Map<String, dynamic> detail) {
  final language = context.read<LanguageProvider>();
  final parts = <String>[];
  final amount = detail['amount'];
  if (amount != null) {
    parts.add(
      '${paymentText(context, 'Amount', 'رقم')}: ${language.money(paymentAmount(amount))}',
    );
  }
  final flow = detail['flow_type']?.toString();
  if (flow == 'float' || flow == 'reimbursement') {
    parts.add(
      flow == 'float'
          ? paymentText(context, 'Paid from an advance', 'ایڈوانس سے ادا کیا')
          : paymentText(context, 'Paid from own pocket', 'اپنی جیب سے ادا کیا'),
    );
  }
  final method = detail['method']?.toString();
  if (method == 'Cash' || method == 'Card') {
    parts.add(
      '${paymentText(context, 'Method', 'طریقہ')}: ${paymentText(context, method!, method == 'Cash' ? 'نقد' : 'کارڈ')}',
    );
  }
  if (detail['mismatch'] == true) {
    parts.add(
      paymentText(
        context,
        'Payment methods differ',
        'ادائیگی کے طریقے مختلف ہیں',
      ),
    );
  }
  final reason = detail['reason']?.toString();
  if (reason != null && reason.trim().isNotEmpty) {
    parts.add('${paymentText(context, 'Reason', 'وجہ')}: $reason');
  }
  return parts.join(' · ');
}

class PaymentMethodChip extends StatelessWidget {
  final String method;
  const PaymentMethodChip(this.method, {super.key});

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(
      method == 'Card' ? Icons.credit_card_rounded : Icons.payments_outlined,
      size: 17,
    ),
    label: Text(
      paymentText(context, method, method == 'Card' ? 'کارڈ' : 'نقد'),
    ),
  );
}

class PaymentPanel extends StatelessWidget {
  final Widget child;
  const PaymentPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF5F8FF)]),
      border: Border.all(color: AppTheme.borderLight),
      borderRadius: BorderRadius.circular(22),
      boxShadow: AppTheme.premiumShadow,
    ),
    padding: const EdgeInsets.all(20),
    child: child,
  );
}

Widget _recordText(String value, {bool bold = false}) => Text(
  value,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    color: const Color(0xFF172238),
    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
  ),
);

Widget _recordStatus(BuildContext context, String status, bool mismatch) =>
    Wrap(
      spacing: 5,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppStatusBadge(status: status),
        if (mismatch)
          Tooltip(
            message: paymentText(
              context,
              'Payment methods do not match',
              'ادائیگی کے طریقے مختلف ہیں',
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: AppTheme.statusRejected,
            ),
          ),
      ],
    );

Widget _recordTable<T>(
  BuildContext context, {
  required String tableId,
  required List<T> records,
  required List<PaymentRecordColumn<T>> columns,
  required String Function(T) idOf,
  required String Function(T) searchOf,
  required String Function(T) statusOf,
  required Widget Function(BuildContext, T) details,
}) => PaymentRecordTable<T>(
  tableId: tableId,
  records: records,
  columns: columns,
  idOf: idOf,
  searchOf: searchOf,
  statusOf: statusOf,
  statusLabel: (status) => paymentStatusLabel(context, status),
  details: details,
  searchHint: paymentText(
    context,
    'Search this list',
    'اس فہرست میں تلاش کریں',
  ),
  statusHint: paymentText(context, 'Status', 'حالت'),
  allStatusesLabel: paymentText(context, 'All statuses', 'تمام حالتیں'),
  recordsLabel: paymentText(context, 'records', 'ریکارڈ'),
  noMatchesLabel: paymentText(
    context,
    'No matching records. Try another search or status.',
    'کوئی ریکارڈ نہیں ملا۔ تلاش یا حالت بدل کر دیکھیں۔',
  ),
  detailsLabel: paymentText(context, 'View details', 'تفصیل دیکھیں'),
  showMoreLabel: paymentText(context, 'Show more', 'مزید دیکھیں'),
);

class PaymentCenterScreen extends StatelessWidget {
  final String? advanceId;
  final String? expenseId, advanceRequestId;
  const PaymentCenterScreen({
    super.key,
    this.advanceId,
    this.expenseId,
    this.advanceRequestId,
  });

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<AuthProvider>().currentUser;
    final payments = context.watch<PaymentProvider>();
    final language = context.watch<LanguageProvider>();
    final users = context.watch<UserProvider>().allUsers;
    final names = {for (final user in users) user.uid: user.name};
    if (actor == null) return const Center(child: CircularProgressIndicator());
    if (payments.isLoading && payments.advances.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = payments.overview
        .where((row) => row.officeBoyId == actor.uid)
        .firstOrNull;
    final reviewQueue = actor.isFinance
        ? payments.expenses
              .where(
                (row) =>
                    (expenseId == null || row.id == expenseId) &&
                    (row.status == 'Pending' ||
                        (row.flowType == 'reimbursement' &&
                            row.status == 'Approved')),
              )
              .toList()
        : <PaymentExpense>[];
    final expenseHistory = payments.expenses
        .where((row) => expenseId == null || row.id == expenseId)
        .toList();
    final advanceRequests = payments.advanceRequests
        .where((row) => advanceRequestId == null || row.id == advanceRequestId)
        .toList();
    final advanceReviewQueue = actor.isFinance
        ? advanceRequests.where((row) => row.status == 'Pending').toList()
        : <AdvanceRequestRecord>[];
    final advances = payments.advances
        .where((row) => advanceId == null || row.id == advanceId)
        .toList();
    final receiptQueue = actor.isOfficeBoy
        ? advances
              .where((row) => row.status == 'Awaiting Confirmation')
              .toList()
        : <AdvanceRecord>[];
    final expenseActionQueue = actor.isOfficeBoy
        ? expenseHistory
              .where(
                (row) =>
                    row.status == 'Rejected' || row.status == 'Payment Cleared',
              )
              .toList()
        : <PaymentExpense>[];
    final unallocatedIds = payments.expenses
        .where((row) => row.flowType == 'float' && row.advanceId == null)
        .map((row) => row.id)
        .toSet();
    final unallocatedImpact = payments.ledger
        .where(
          (entry) => unallocatedIds.contains(entry['expense_id']?.toString()),
        )
        .fold<double>(
          0,
          (sum, entry) =>
              sum +
              (entry['entry_type'] == 'hold_release' ? -1 : 1) *
                  paymentAmount(entry['amount']),
        );
    return RefreshIndicator(
      onRefresh: () async {
        payments.refresh();
        await payments.refreshOverview();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Text(
                          paymentText(
                            context,
                            'Money & Expenses',
                            'رقم اور خرچ',
                          ),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (actor.isFinance)
                          FilledButton.icon(
                            onPressed: payments.isBusy('give-advance')
                                ? null
                                : () => _showGiveAdvance(context),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              paymentText(
                                context,
                                'Give Advance',
                                'ایڈوانس دیں',
                              ),
                            ),
                          ),
                        if (actor.isOfficeBoy)
                          FilledButton.icon(
                            onPressed: payments.isBusy('submit-expense')
                                ? null
                                : () => _showSubmitExpense(context),
                            icon: const Icon(Icons.add_shopping_cart_rounded),
                            label: Text(
                              paymentText(
                                context,
                                'Add Expense',
                                'خرچہ شامل کریں',
                              ),
                            ),
                          ),
                        if (!actor.isOfficeBoy)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDateRange:
                                    payments.reportFrom != null &&
                                        payments.reportTo != null
                                    ? DateTimeRange(
                                        start: payments.reportFrom!,
                                        end: payments.reportTo!.subtract(
                                          const Duration(days: 1),
                                        ),
                                      )
                                    : null,
                              );
                              if (range != null && context.mounted) {
                                await context
                                    .read<PaymentProvider>()
                                    .setReportRange(
                                      range.start,
                                      range.end.add(const Duration(days: 1)),
                                    );
                              }
                            },
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                              paymentText(
                                context,
                                'Totals date range',
                                'مجموعی رقم کی مدت',
                              ),
                            ),
                          ),
                        if (!actor.isOfficeBoy && payments.reportFrom != null)
                          TextButton(
                            onPressed: () =>
                                payments.setReportRange(null, null),
                            child: Text(
                              paymentText(context, 'All dates', 'تمام تاریخیں'),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (payments.error != null) ...[
                      PaymentPanel(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppTheme.statusRejected,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(language.error(payments.error!)),
                            ),
                            TextButton(
                              onPressed: payments.refresh,
                              child: Text(
                                paymentText(context, 'Retry', 'دوبارہ کوشش'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (actor.isOfficeBoy) _SummaryGrid(summary: summary),
                    if (actor.isOfficeBoy) ...[
                      const SizedBox(height: 12),
                      _PocketSummary(expenses: payments.expenses),
                    ],
                    if (!actor.isOfficeBoy)
                      _BalanceOverview(
                        rows: payments.overview,
                        period: payments.reportFrom == null
                            ? null
                            : '${language.date(payments.reportFrom!)} – ${language.date(payments.reportTo!.subtract(const Duration(days: 1)))}',
                      ),
                    if (unallocatedIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PaymentPanel(
                        child: Text(
                          paymentText(
                            context,
                            '${unallocatedIds.length} older expenses have no advance number. ${language.money(unallocatedImpact)} is already included in the balance.',
                            '${unallocatedIds.length} پرانے خرچوں کا ایڈوانس نمبر موجود نہیں۔ ${language.money(unallocatedImpact)} بیلنس میں پہلے ہی شامل ہیں۔',
                          ),
                        ),
                      ),
                    ],
                    if (actor.isOfficeBoy &&
                        (receiptQueue.isNotEmpty ||
                            expenseActionQueue.isNotEmpty)) ...[
                      const SizedBox(height: 20),
                      Text(
                        paymentText(
                          context,
                          'Your next steps',
                          'اب آپ نے کیا کرنا ہے',
                        ),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      ...receiptQueue.map(
                        (advance) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AdvanceCard(
                            advance: advance,
                            officeBoyName: names[advance.officeBoyId],
                            canConfirm: true,
                            activity: payments.activity
                                .where((event) => event.advanceId == advance.id)
                                .toList(),
                            balance: null,
                            linkedExpenses: const [],
                          ),
                        ),
                      ),
                      ...expenseActionQueue.map(
                        (expense) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExpenseCard(
                            expense: expense,
                            officeBoyName: names[expense.officeBoyId],
                            isFinance: false,
                            isOfficeBoy: true,
                            activity: payments.activity
                                .where((event) => event.expenseId == expense.id)
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                    if (actor.isFinance) ...[
                      const SizedBox(height: 20),
                      Text(
                        paymentText(
                          context,
                          'Needs Finance Action',
                          'فنانس کی کارروائی باقی',
                        ),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (reviewQueue.isEmpty && advanceReviewQueue.isEmpty)
                        PaymentPanel(
                          child: Text(
                            paymentText(
                              context,
                              'Nothing needs your decision right now.',
                              'فی الحال آپ کے فیصلے کا کوئی کام باقی نہیں۔',
                            ),
                          ),
                        )
                      else ...[
                        if (advanceReviewQueue.isNotEmpty) ...[
                          Text(
                            paymentText(
                              context,
                              'Advance requests to review',
                              'ایڈوانس کی درخواستوں پر فیصلہ کریں',
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ...advanceReviewQueue.map(
                            (request) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AdvanceRequestCard(
                                request: request,
                                officeBoyName: names[request.officeBoyId],
                                canReview: true,
                                canConfirm: false,
                              ),
                            ),
                          ),
                        ],
                        if (reviewQueue.isNotEmpty) ...[
                          Text(
                            paymentText(
                              context,
                              'Expenses to review or pay',
                              'خرچوں کا فیصلہ یا ادائیگی کریں',
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ...reviewQueue.map(
                            (expense) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ExpenseCard(
                                expense: expense,
                                officeBoyName: users
                                    .where((u) => u.uid == expense.officeBoyId)
                                    .firstOrNull
                                    ?.name,
                                isFinance: true,
                                isOfficeBoy: false,
                                activity: payments.activity
                                    .where(
                                      (event) => event.expenseId == expense.id,
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                    const SizedBox(height: 20),
                    Text(
                      paymentText(
                        context,
                        'Advance requests',
                        'ایڈوانس کی درخواستیں',
                      ),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    if (advanceRequests.isEmpty)
                      PaymentPanel(
                        child: Text(
                          paymentText(
                            context,
                            'No advance requests yet.',
                            'ابھی کوئی ایڈوانس درخواست نہیں۔',
                          ),
                        ),
                      )
                    else
                      _recordTable<AdvanceRequestRecord>(
                        context,
                        tableId: 'advance-requests',
                        records: advanceRequests,
                        idOf: (row) => row.id,
                        statusOf: (row) => row.status,
                        searchOf: (row) =>
                            '${row.id} ${row.purpose} ${row.amount} ${names[row.officeBoyId] ?? ''}',
                        columns: [
                          PaymentRecordColumn(
                            label: paymentText(context, 'Date', 'تاریخ'),
                            cell: (_, row) =>
                                _recordText(language.date(row.createdAt)),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(
                              context,
                              'Office Boy',
                              'آفس بوائے',
                            ),
                            cell: (_, row) => _recordText(
                              names[row.officeBoyId] ?? actor.name,
                            ),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Purpose', 'مقصد'),
                            flex: 3,
                            cell: (_, row) =>
                                _recordText(row.purpose, bold: true),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Amount', 'رقم'),
                            cell: (_, row) => _recordText(
                              language.money(row.amount),
                              bold: true,
                            ),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Status', 'حالت'),
                            flex: 3,
                            cell: (_, row) => Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: AppStatusBadge(status: row.status),
                            ),
                          ),
                        ],
                        details: (_, request) => _AdvanceRequestCard(
                          request: request,
                          officeBoyName: names[request.officeBoyId],
                          canReview: actor.isFinance,
                          canConfirm: actor.isOfficeBoy,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      paymentText(
                        context,
                        'Advance history',
                        'ایڈوانس کی تاریخ',
                      ),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    if (advances.isEmpty)
                      PaymentPanel(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              paymentText(
                                context,
                                'No advances yet.',
                                'ابھی کوئی ایڈوانس نہیں۔',
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      _recordTable<AdvanceRecord>(
                        context,
                        tableId: 'advance-history',
                        records: advances,
                        idOf: (row) => row.id,
                        statusOf: (row) => row.status,
                        searchOf: (row) =>
                            '${row.id} ${row.note ?? ''} ${row.amount} ${names[row.officeBoyId] ?? ''}',
                        columns: [
                          PaymentRecordColumn(
                            label: paymentText(
                              context,
                              'Date / reference',
                              'تاریخ / نمبر',
                            ),
                            cell: (_, row) => _recordText(
                              '${language.date(row.createdAt)}\n#${row.id.substring(0, 8)}',
                            ),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(
                              context,
                              'Office Boy',
                              'آفس بوائے',
                            ),
                            cell: (_, row) => _recordText(
                              names[row.officeBoyId] ?? actor.name,
                            ),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Amount', 'رقم'),
                            cell: (_, row) => _recordText(
                              language.money(row.amount),
                              bold: true,
                            ),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Available', 'دستیاب'),
                            cell: (_, row) {
                              final balance = payments.advanceBalances
                                  .where(
                                    (balance) => balance.advanceId == row.id,
                                  )
                                  .firstOrNull;
                              return _recordText(
                                row.status != 'Received'
                                    ? '—'
                                    : balance == null
                                    ? paymentText(
                                        context,
                                        'Updating…',
                                        'حساب جاری…',
                                      )
                                    : language.money(balance.available),
                                bold: true,
                              );
                            },
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Status', 'حالت'),
                            flex: 3,
                            cell: (_, row) => _recordStatus(
                              context,
                              row.status,
                              row.mismatchFlag,
                            ),
                          ),
                        ],
                        details: (_, advance) => _AdvanceCard(
                          advance: advance,
                          officeBoyName: names[advance.officeBoyId],
                          canConfirm:
                              actor.isOfficeBoy &&
                              advance.officeBoyId == actor.uid,
                          activity: payments.activity
                              .where((event) => event.advanceId == advance.id)
                              .toList(),
                          balance: payments.advanceBalances
                              .where((row) => row.advanceId == advance.id)
                              .firstOrNull,
                          linkedExpenses: payments.expenses
                              .where((row) => row.advanceId == advance.id)
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 32),
                    Text(
                      paymentText(context, 'Expense history', 'خرچے کی تاریخ'),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    if (expenseHistory.isEmpty)
                      PaymentPanel(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              paymentText(
                                context,
                                'No expenses yet.',
                                'ابھی کوئی خرچہ نہیں۔',
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      _recordTable<PaymentExpense>(
                        context,
                        tableId: 'expense-history',
                        records: expenseHistory,
                        idOf: (row) => row.id,
                        statusOf: (row) => row.status,
                        searchOf: (row) =>
                            '${row.id} ${row.itemDescription} ${row.reason} ${row.amount} ${names[row.officeBoyId] ?? ''} ${row.advanceId ?? ''}',
                        columns: [
                          PaymentRecordColumn(
                            label: paymentText(
                              context,
                              'Date / Office Boy',
                              'تاریخ / آفس بوائے',
                            ),
                            cell: (_, row) => _recordText(
                              '${language.date(row.createdAt)}\n${names[row.officeBoyId] ?? actor.name}',
                            ),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Item', 'سامان'),
                            flex: 3,
                            cell: (_, row) =>
                                _recordText(row.itemDescription, bold: true),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(
                              context,
                              'Paid from',
                              'رقم کہاں سے',
                            ),
                            cell: (_, row) => _recordText(
                              row.flowType == 'float'
                                  ? paymentText(context, 'Advance', 'ایڈوانس')
                                  : paymentText(
                                      context,
                                      'Own pocket',
                                      'اپنی جیب',
                                    ),
                            ),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Amount', 'رقم'),
                            cell: (_, row) => _recordText(
                              language.money(row.amount),
                              bold: true,
                            ),
                          ),
                          PaymentRecordColumn(
                            label: paymentText(context, 'Status', 'حالت'),
                            flex: 3,
                            cell: (_, row) => _recordStatus(
                              context,
                              row.status,
                              row.mismatchFlag,
                            ),
                          ),
                        ],
                        details: (_, expense) => _ExpenseCard(
                          expense: expense,
                          officeBoyName: names[expense.officeBoyId],
                          isFinance: actor.isFinance,
                          isOfficeBoy:
                              actor.isOfficeBoy &&
                              expense.officeBoyId == actor.uid,
                          activity: payments.activity
                              .where((event) => event.expenseId == expense.id)
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGiveAdvance(BuildContext context) async {
    final users = context
        .read<UserProvider>()
        .allUsers
        .where((user) => user.role == UserRole.officeBoy && user.isActive)
        .toList();
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentText(
              context,
              'No active Office Boy account is available.',
              'کوئی فعال آفس بوائے اکاؤنٹ موجود نہیں۔',
            ),
          ),
        ),
      );
      return;
    }
    final payments = context.read<PaymentProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => _GiveAdvanceDialog(users: users, payments: payments),
    );
  }

  Future<void> _showSubmitExpense(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SubmitPaymentExpenseDialog(),
    );
    if (result == true && context.mounted) {
      context.read<PaymentProvider>().refresh();
    }
  }
}

class _GiveAdvanceDialog extends StatefulWidget {
  final List<AppUser> users;
  final PaymentProvider payments;

  const _GiveAdvanceDialog({required this.users, required this.payments});

  @override
  State<_GiveAdvanceDialog> createState() => _GiveAdvanceDialogState();
}

class _GiveAdvanceDialogState extends State<_GiveAdvanceDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _advanceId = const Uuid().v4();
  late String _officeBoyId = widget.users.first.uid;
  String _method = 'Cash';
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final success = await widget.payments.giveAdvance(
      id: _advanceId,
      officeBoyId: _officeBoyId,
      amount: double.parse(_amount.text.trim()),
      method: _method,
      note: _note.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(paymentText(context, 'Give Advance', 'ایڈوانس دیں')),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _officeBoyId,
                decoration: InputDecoration(
                  labelText: paymentText(context, 'Office Boy', 'آفس بوائے'),
                ),
                items: widget.users
                    .map(
                      (user) => DropdownMenuItem(
                        value: user.uid,
                        child: Text(user.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _officeBoyId = value);
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: paymentText(context, 'Amount (PKR)', 'رقم (روپے)'),
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null ||
                      !parsed.isFinite ||
                      parsed <= 0 ||
                      parsed >= 10000000000 ||
                      (parsed * 100).roundToDouble() != parsed * 100) {
                    return paymentText(
                      context,
                      'Enter a valid positive amount.',
                      'درست مثبت رقم درج کریں۔',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _method,
                decoration: InputDecoration(
                  labelText: paymentText(
                    context,
                    'Given by',
                    'ادائیگی کا طریقہ',
                  ),
                ),
                items: ['Cash', 'Card']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          paymentText(
                            context,
                            value,
                            value == 'Cash' ? 'نقد' : 'کارڈ',
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _method = value);
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                maxLength: 2000,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: paymentText(
                    context,
                    'Note (optional)',
                    'نوٹ (اختیاری)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: Text(paymentText(context, 'Cancel', 'منسوخ')),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(paymentText(context, 'Give Advance', 'ایڈوانس دیں')),
      ),
    ],
  );
}

class _AdvanceRequestCard extends StatelessWidget {
  final AdvanceRequestRecord request;
  final String? officeBoyName;
  final bool canReview;
  final bool canConfirm;
  const _AdvanceRequestCard({
    required this.request,
    required this.officeBoyName,
    required this.canReview,
    required this.canConfirm,
  });

  Future<void> _approve(BuildContext context) async {
    final method = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          paymentText(
            context,
            'Approve & give money',
            'منظور کریں اور رقم دیں',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paymentText(
                context,
                'How will Finance give the money?',
                'فنانس رقم کس طریقے سے دے گا؟',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(paymentText(context, 'Cash', 'نقد')),
              leading: const Icon(Icons.payments_outlined),
              onTap: () => Navigator.pop(dialog, 'Cash'),
            ),
            ListTile(
              title: Text(paymentText(context, 'Card', 'کارڈ')),
              leading: const Icon(Icons.credit_card_rounded),
              onTap: () => Navigator.pop(dialog, 'Card'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(paymentText(context, 'Cancel', 'منسوخ')),
          ),
        ],
      ),
    );
    if (method != null && context.mounted) {
      await context.read<PaymentProvider>().reviewAdvanceRequest(
        request.id,
        'Approve',
        method: method,
      );
    }
  }

  Future<void> _confirm(BuildContext context) async {
    final advanceId = request.advanceId;
    if (advanceId == null) return;
    final method = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          paymentText(
            context,
            'Confirm money received',
            'رقم موصول ہونے کی تصدیق',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              paymentText(
                context,
                'How did you actually receive this advance?',
                'آپ کو یہ رقم کس طریقے سے ملی؟',
              ),
            ),
            ListTile(
              title: Text(paymentText(context, 'Cash', 'نقد')),
              onTap: () => Navigator.pop(dialog, 'Cash'),
            ),
            ListTile(
              title: Text(paymentText(context, 'Card', 'کارڈ')),
              onTap: () => Navigator.pop(dialog, 'Card'),
            ),
          ],
        ),
      ),
    );
    if (method != null && context.mounted) {
      await context.read<PaymentProvider>().confirmAdvance(advanceId, method);
    }
  }

  Future<void> _reject(BuildContext context) async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          paymentText(
            context,
            'Reject advance request',
            'ایڈوانس درخواست مسترد کریں',
          ),
        ),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            maxLength: 2000,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: paymentText(context, 'Reason', 'وجہ'),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? paymentText(context, 'Enter a reason.', 'وجہ درج کریں۔')
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(paymentText(context, 'Cancel', 'منسوخ')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialog, controller.text.trim());
              }
            },
            child: Text(paymentText(context, 'Reject', 'مسترد کریں')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && context.mounted) {
      await context.read<PaymentProvider>().reviewAdvanceRequest(
        request.id,
        'Reject',
        reason: reason,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final payments = context.watch<PaymentProvider>();
    return PaymentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(
                officeBoyName ??
                    paymentText(context, 'My request', 'میری درخواست'),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              AppStatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            language.money(request.amount),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(request.purpose),
          Text(
            language.date(request.createdAt),
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          if (request.decidedAt != null)
            Text(
              '${paymentText(context, 'Reviewed', 'فیصلہ ہوا')}: ${language.date(request.decidedAt!)}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          if (request.advanceId != null)
            Text(
              '${paymentText(context, 'Advance ID', 'ایڈوانس نمبر')}: ${request.advanceId!.substring(0, 8)}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          if (request.status == 'Approved')
            Text(
              payments.advances.any(
                    (advance) =>
                        advance.id == request.advanceId &&
                        advance.status == 'Received',
                  )
                  ? paymentText(
                      context,
                      'Money received and added to your advance balance.',
                      'رقم موصول ہو کر آپ کے ایڈوانس بیلنس میں شامل ہو گئی ہے۔',
                    )
                  : paymentText(
                      context,
                      'Finance approved. Confirm receipt to add this money to your balance.',
                      'فنانس نے منظور کیا۔ بیلنس میں شامل کرنے کے لیے وصولی کی تصدیق کریں۔',
                    ),
            ),
          if (canConfirm &&
              request.status == 'Approved' &&
              request.advanceId != null &&
              payments.advances.any(
                (advance) =>
                    advance.id == request.advanceId &&
                    advance.status == 'Awaiting Confirmation',
              ))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: FilledButton.icon(
                onPressed: payments.isBusy(request.advanceId!)
                    ? null
                    : () => _confirm(context),
                icon: const Icon(Icons.verified_outlined),
                label: Text(
                  paymentText(context, 'Confirm receipt', 'وصولی کی تصدیق'),
                ),
              ),
            ),
          if (request.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${paymentText(context, 'Reason', 'وجہ')}: ${request.rejectionReason}',
                style: const TextStyle(color: AppTheme.statusRejected),
              ),
            ),
          if (canReview && request.status == 'Pending')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: payments.isBusy(request.id)
                        ? null
                        : () => _approve(context),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(paymentText(context, 'Approve', 'منظور کریں')),
                  ),
                  OutlinedButton.icon(
                    onPressed: payments.isBusy(request.id)
                        ? null
                        : () => _reject(context),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(paymentText(context, 'Reject', 'مسترد کریں')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PocketSummary extends StatelessWidget {
  final List<PaymentExpense> expenses;
  const _PocketSummary({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    double total(String status) => expenses
        .where((row) => row.flowType == 'reimbursement' && row.status == status)
        .fold<double>(0, (sum, row) => sum + row.amount);
    final pending = total('Pending');
    final approved = total('Approved');
    final sent = total('Payment Cleared');
    final paid = total('Paid');
    return PaymentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paymentText(context, 'My own-pocket spending', 'اپنی جیب سے خرچ'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                '${paymentText(context, 'Under review', 'زیرِ جائزہ')}: ${language.money(pending)}',
              ),
              Text(
                '${paymentText(context, 'Approved, unpaid', 'منظور، ادائیگی باقی')}: ${language.money(approved)}',
              ),
              Text(
                '${paymentText(context, 'Payment sent', 'ادائیگی بھیجی گئی')}: ${language.money(sent)}',
              ),
              Text(
                '${paymentText(context, 'Received', 'موصول')}: ${language.money(paid)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final FloatSummary? summary;
  const _SummaryGrid({this.summary});

  @override
  Widget build(BuildContext context) => _BalanceOverview(
    rows: summary == null ? const [] : [summary!],
    personal: true,
  );
}

class _BalanceOverview extends StatelessWidget {
  final List<FloatSummary> rows;
  final String? period;
  final bool personal;

  const _BalanceOverview({
    required this.rows,
    this.period,
    this.personal = false,
  });
  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    double sum(double Function(FloatSummary row) value) =>
        rows.fold<double>(0, (total, row) => total + value(row));
    final metrics = [
      (
        paymentText(context, 'Available now', 'ابھی دستیاب'),
        language.money(sum((row) => row.availableBalance)),
        Icons.account_balance_wallet_outlined,
        const Color(0xFFE7F5EF),
        const Color(0xFF18794E),
      ),
      (
        paymentText(context, 'On hold', 'روکی گئی رقم'),
        language.money(sum((row) => row.onHold)),
        Icons.lock_clock_outlined,
        const Color(0xFFFFF3DC),
        const Color(0xFF9A5B00),
      ),
      (
        paymentText(
          context,
          period == null ? 'All-time given' : 'Period given',
          period == null ? 'کل دیا گیا' : 'مدت میں دیا گیا',
        ),
        language.money(sum((row) => row.totalReceived)),
        Icons.south_west_rounded,
        const Color(0xFFEAF1FD),
        const Color(0xFF2757A5),
      ),
      (
        paymentText(
          context,
          period == null ? 'All-time spent' : 'Period spent',
          period == null ? 'کل خرچ' : 'مدت میں خرچ',
        ),
        language.money(sum((row) => row.totalSpent)),
        Icons.north_east_rounded,
        const Color(0xFFFDECEC),
        const Color(0xFFAE3F3F),
      ),
      (
        paymentText(context, 'Own-pocket repaid', 'ذاتی خرچ واپس'),
        language.money(sum((row) => row.totalReimbursed)),
        Icons.payments_outlined,
        const Color(0xFFECECF8),
        const Color(0xFF55528F),
      ),
    ];
    return SizedBox(
      width: double.infinity,
      child: PaymentPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paymentText(
                context,
                personal ? 'My balance' : 'Balances by Office Boy',
                personal ? 'میرا بیلنس' : 'ہر آفس بوائے کا بیلنس',
              ),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (period != null)
              Text(period!, style: const TextStyle(color: Color(0xFF64748B))),
            if (period != null)
              Text(
                paymentText(
                  context,
                  'Totals use these dates. Available balance is current; detailed history below shows all dates.',
                  'مجموعی رقم اس مدت کی ہے۔ دستیاب بیلنس موجودہ ہے؛ نیچے تفصیلی ریکارڈ تمام تاریخوں کا ہے۔',
                ),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final metricWidth = constraints.maxWidth < 340
                    ? constraints.maxWidth
                    : constraints.maxWidth < 420
                    ? (constraints.maxWidth - 10) / 2
                    : 176.0;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: metricWidth,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 82),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: metric.$4,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(metric.$3, size: 17, color: metric.$5),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      metric.$1,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: metric.$5,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                metric.$2,
                                maxLines: 2,
                                style: const TextStyle(
                                  color: Color(0xFF202B3B),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            if (!personal && rows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    paymentText(
                      context,
                      'No balance records yet.',
                      'ابھی کوئی بیلنس ریکارڈ نہیں۔',
                    ),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else if (!personal)
              LayoutBuilder(
                builder: (context, constraints) {
                  final headers = [
                    paymentText(context, 'Office Boy', 'آفس بوائے'),
                    paymentText(context, 'Available', 'دستیاب'),
                    paymentText(context, 'On hold', 'روکی گئی'),
                    paymentText(context, 'Given', 'دیا گیا'),
                    paymentText(context, 'Spent', 'خرچ'),
                    paymentText(context, 'Own-pocket repaid', 'ذاتی خرچ واپس'),
                  ];
                  if (constraints.maxWidth < 940) {
                    return Column(
                      children: [
                        for (final row in rows)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFD),
                              border: Border.all(color: AppTheme.borderLight),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.15),
                                1: FlexColumnWidth(1.4),
                              },
                              children: [
                                for (final pair in [
                                  (headers[0], row.officeBoyName),
                                  (
                                    headers[1],
                                    language.money(row.availableBalance),
                                  ),
                                  (headers[2], language.money(row.onHold)),
                                  (
                                    headers[3],
                                    language.money(row.totalReceived),
                                  ),
                                  (headers[4], language.money(row.totalSpent)),
                                  (
                                    headers[5],
                                    language.money(row.totalReimbursed),
                                  ),
                                ])
                                  TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        child: Text(
                                          pair.$1,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        child: Text(
                                          pair.$2,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                  final tableWidth = constraints.maxWidth;
                  Widget cell(
                    String text, {
                    bool bold = false,
                    bool numeric = false,
                  }) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 13,
                    ),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: numeric ? TextAlign.end : TextAlign.start,
                      style: TextStyle(
                        color: const Color(0xFF26364D),
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.8),
                            1: FlexColumnWidth(1.35),
                            2: FlexColumnWidth(1.15),
                            3: FlexColumnWidth(1.2),
                            4: FlexColumnWidth(1.15),
                            5: FlexColumnWidth(1.65),
                          },
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: AppTheme.borderLight,
                            ),
                          ),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFEAF1FD),
                              ),
                              children: [
                                for (
                                  var index = 0;
                                  index < headers.length;
                                  index++
                                )
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      headers[index],
                                      textAlign: index == 0
                                          ? TextAlign.start
                                          : TextAlign.end,
                                      style: const TextStyle(
                                        color: Color(0xFF344766),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            for (var index = 0; index < rows.length; index++)
                              TableRow(
                                decoration: BoxDecoration(
                                  color: index.isEven
                                      ? Colors.white
                                      : const Color(0xFFF8FAFD),
                                ),
                                children: [
                                  cell(rows[index].officeBoyName, bold: true),
                                  cell(
                                    language.money(
                                      rows[index].availableBalance,
                                    ),
                                    bold: true,
                                    numeric: true,
                                  ),
                                  cell(
                                    language.money(rows[index].onHold),
                                    numeric: true,
                                  ),
                                  cell(
                                    language.money(rows[index].totalReceived),
                                    numeric: true,
                                  ),
                                  cell(
                                    language.money(rows[index].totalSpent),
                                    numeric: true,
                                  ),
                                  cell(
                                    language.money(rows[index].totalReimbursed),
                                    numeric: true,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AdvanceCard extends StatelessWidget {
  final AdvanceRecord advance;
  final String? officeBoyName;
  final bool canConfirm;
  final List<PaymentActivity> activity;
  final AdvanceBalance? balance;
  final List<PaymentExpense> linkedExpenses;
  const _AdvanceCard({
    required this.advance,
    required this.officeBoyName,
    required this.canConfirm,
    required this.activity,
    required this.balance,
    required this.linkedExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final payments = context.watch<PaymentProvider>();
    final awaiting = advance.status == 'Awaiting Confirmation';
    return PaymentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    officeBoyName ??
                        paymentText(context, 'My Advance', 'میرا ایڈوانس'),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    language.date(advance.createdAt),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
              AppStatusBadge(status: advance.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            language.money(advance.amount),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            '${paymentText(context, 'Advance ID', 'ایڈوانس نمبر')}: ${advance.id.substring(0, 8)}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          if (balance != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text(
                  '${paymentText(context, 'Available', 'دستیاب')}: ${language.money(balance!.available)}',
                ),
                Text(
                  '${paymentText(context, 'Spent', 'خرچ')}: ${language.money(balance!.spent)}',
                ),
                Text(
                  '${paymentText(context, 'On hold', 'روکی گئی رقم')}: ${language.money(balance!.onHold)}',
                ),
              ],
            ),
          ],
          if (linkedExpenses.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '${paymentText(context, 'Purchases from this advance', 'اس ایڈوانس سے خریداری')} (${linkedExpenses.length})',
              ),
              children: linkedExpenses
                  .map(
                    (expense) => ListTile(
                      title: Text(expense.itemDescription),
                      subtitle: Text(language.date(expense.createdAt)),
                      trailing: Text(language.money(expense.amount)),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(paymentText(context, 'Finance gave:', 'فنانس نے دیا:')),
              PaymentMethodChip(advance.financeMethod),
              if (advance.receivedMethod != null) ...[
                Text(paymentText(context, 'Received by:', 'موصول ہوا:')),
                PaymentMethodChip(advance.receivedMethod!),
              ],
            ],
          ),
          if (advance.mismatchFlag)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.statusRejected,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      paymentText(
                        context,
                        'Method Mismatch',
                        'ادائیگی کے طریقے میں فرق',
                      ),
                      style: const TextStyle(
                        color: AppTheme.statusRejected,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (advance.note?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(advance.note!),
            ),
          if (canConfirm && awaiting)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: payments.isBusy(advance.id)
                    ? null
                    : () => _showConfirm(context),
                icon: const Icon(Icons.verified_outlined),
                label: Text(
                  paymentText(
                    context,
                    'Confirm Advance Received',
                    'ایڈوانس وصولی کی تصدیق',
                  ),
                ),
              ),
            ),
          if (activity.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                paymentText(context, 'Activity timeline', 'سرگرمی کی تفصیل'),
              ),
              children: activity
                  .map(
                    (event) => ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.circle,
                        size: 10,
                        color: AppTheme.primaryBlue,
                      ),
                      title: Text(_activityLabel(context, event.action)),
                      subtitle: Text(
                        language.date(
                          event.createdAt,
                          pattern: 'dd MMM yyyy, h:mm a',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _showConfirm(BuildContext context) async {
    var method = 'Cash';
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stateCtx, setDialogState) => AlertDialog(
          title: Text(
            paymentText(context, 'Confirm receipt', 'وصولی کی تصدیق'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paymentText(
                  context,
                  'Select how you actually received this advance.',
                  'آپ کو یہ ایڈوانس کس طریقے سے موصول ہوا؟',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: method,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: paymentText(
                    context,
                    'Received by',
                    'وصولی کا طریقہ',
                  ),
                ),
                items: ['Cash', 'Card']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          paymentText(
                            context,
                            value,
                            value == 'Cash' ? 'نقد' : 'کارڈ',
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) method = value;
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogCtx),
              child: Text(paymentText(context, 'Cancel', 'منسوخ')),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() => busy = true);
                      final ok = await context
                          .read<PaymentProvider>()
                          .confirmAdvance(advance.id, method);
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.pop(dialogCtx);
                      } else {
                        setDialogState(() => busy = false);
                      }
                    },
              child: Text(paymentText(context, 'Confirm', 'تصدیق کریں')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final PaymentExpense expense;
  final String? officeBoyName;
  final bool isFinance;
  final bool isOfficeBoy;
  final List<PaymentActivity> activity;
  const _ExpenseCard({
    required this.expense,
    required this.officeBoyName,
    required this.isFinance,
    required this.isOfficeBoy,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final payments = context.watch<PaymentProvider>();
    final awaiting = expense.status == 'Pending';
    return PaymentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    officeBoyName ??
                        paymentText(context, 'My Expense', 'میرا خرچہ'),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    language.date(expense.createdAt),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
              AppStatusBadge(status: expense.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            language.money(expense.amount),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            expense.itemDescription,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            expense.reason,
            style: const TextStyle(color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(paymentText(context, 'Flow Type:', 'قسم:')),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  expense.flowType == 'float'
                      ? paymentText(context, 'From advance', 'ایڈوانس سے')
                      : paymentText(context, 'Paid myself', 'اپنی جیب سے'),
                ),
              ),
              if (expense.advanceId != null)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    '${paymentText(context, 'Advance', 'ایڈوانس')} #${expense.advanceId!.substring(0, 8)}',
                  ),
                ),
              if (expense.flowType == 'float' && expense.advanceId == null)
                Text(
                  paymentText(
                    context,
                    'Earlier expense — source advance was not recorded',
                    'پرانا خرچ — متعلقہ ایڈوانس ریکارڈ نہیں ہوا',
                  ),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              if (expense.billPath != null)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.image, size: 16),
                  label: Text(
                    paymentText(context, 'View Receipt', 'رسید دیکھیں'),
                  ),
                  onPressed: () {
                    ReceiptViewerDialog.show(
                      context,
                      imageUrl: expense.billPath!,
                      title: expense.itemDescription,
                    );
                  },
                ),
            ],
          ),
          if (expense.paymentMethodFinance != null ||
              expense.paymentMethodReceived != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (expense.paymentMethodFinance != null) ...[
                  Text(
                    paymentText(
                      context,
                      'Finance paid by:',
                      'فنانس نے ادا کیا:',
                    ),
                  ),
                  PaymentMethodChip(expense.paymentMethodFinance!),
                ],
                if (expense.paymentMethodReceived != null) ...[
                  Text(
                    paymentText(
                      context,
                      'Office Boy received by:',
                      'آفس بوائے کو موصول ہوا:',
                    ),
                  ),
                  PaymentMethodChip(expense.paymentMethodReceived!),
                ],
              ],
            ),
          ],
          if (expense.mismatchFlag)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.statusRejected,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      paymentText(
                        context,
                        'Payment method mismatch recorded',
                        'ادائیگی کے طریقے کا فرق ریکارڈ کیا گیا',
                      ),
                      style: const TextStyle(
                        color: AppTheme.statusRejected,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (expense.rejectionReason != null &&
              expense.rejectionReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${paymentText(context, "Rejection Reason:", "مسترد ہونے کی وجہ:")} ${expense.rejectionReason}',
                style: const TextStyle(color: AppTheme.statusRejected),
              ),
            ),
          if (isFinance && awaiting)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: payments.isBusy(expense.id)
                        ? null
                        : () async {
                            await payments.reviewExpense(expense.id, 'Approve');
                          },
                    icon: const Icon(Icons.check),
                    label: Text(paymentText(context, 'Approve', 'منظور کریں')),
                  ),
                  OutlinedButton.icon(
                    onPressed: payments.isBusy(expense.id)
                        ? null
                        : () async {
                            final reason = await _askRejectionReason(context);
                            if (reason == null || !context.mounted) return;
                            await context.read<PaymentProvider>().reviewExpense(
                              expense.id,
                              'Reject',
                              reason: reason,
                            );
                          },
                    icon: const Icon(Icons.close),
                    label: Text(paymentText(context, 'Reject', 'مسترد کریں')),
                  ),
                ],
              ),
            ),
          if (isFinance &&
              expense.flowType == 'reimbursement' &&
              expense.status == 'Approved')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: payments.isBusy(expense.id)
                    ? null
                    : () async {
                        final method = await _choosePaymentMethod(
                          context,
                          title: paymentText(
                            context,
                            'Record repayment',
                            'واپس کی گئی رقم درج کریں',
                          ),
                          prompt: paymentText(
                            context,
                            'How did Finance pay this amount?',
                            'فنانس نے یہ رقم کس طریقے سے ادا کی؟',
                          ),
                        );
                        if (method == null || !context.mounted) return;
                        await context.read<PaymentProvider>().clearPayment(
                          expense.id,
                          method,
                        );
                      },
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  paymentText(
                    context,
                    'Record Payment & Notify',
                    'ادائیگی درج کریں اور اطلاع دیں',
                  ),
                ),
              ),
            ),
          if (isOfficeBoy && expense.status == 'Payment Cleared')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: payments.isBusy(expense.id)
                    ? null
                    : () async {
                        final method = await _choosePaymentMethod(
                          context,
                          title: paymentText(
                            context,
                            'Confirm payment received',
                            'موصولہ ادائیگی کی تصدیق',
                          ),
                          prompt: paymentText(
                            context,
                            'How did you actually receive the money?',
                            'آپ کو رقم کس طریقے سے موصول ہوئی؟',
                          ),
                        );
                        if (method == null || !context.mounted) return;
                        await context.read<PaymentProvider>().confirmPayment(
                          expense.id,
                          method,
                        );
                      },
                icon: const Icon(Icons.verified_outlined),
                label: Text(
                  paymentText(
                    context,
                    'Confirm Money Received',
                    'رقم موصول ہونے کی تصدیق کریں',
                  ),
                ),
              ),
            ),
          if (isOfficeBoy && expense.status == 'Rejected')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: payments.isBusy(expense.id)
                    ? null
                    : () async {
                        await payments.acknowledgeRejection(expense.id);
                      },
                icon: const Icon(Icons.done_all),
                label: Text(
                  paymentText(
                    context,
                    'Acknowledge Rejection',
                    'مستردی تسلیم کریں',
                  ),
                ),
              ),
            ),
          if (activity.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                paymentText(context, 'Activity timeline', 'سرگرمی کی تفصیل'),
              ),
              children: activity.map((event) {
                final details = _activityDetail(context, event.detail);
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.circle,
                    size: 10,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(_activityLabel(context, event.action)),
                  subtitle: Text(
                    [
                      language.date(
                        event.createdAt,
                        pattern: 'dd MMM yyyy, h:mm a',
                      ),
                      if (details.isNotEmpty) details,
                    ].join('\n'),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<String?> _askRejectionReason(BuildContext context) async {
    var enteredReason = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(paymentText(context, 'Reject expense', 'خرچہ مسترد کریں')),
        content: TextField(
          autofocus: true,
          maxLength: 2000,
          maxLines: 3,
          onChanged: (value) => enteredReason = value,
          decoration: InputDecoration(
            labelText: paymentText(context, 'Reason (required)', 'وجہ (ضروری)'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(paymentText(context, 'Cancel', 'منسوخ')),
          ),
          FilledButton(
            onPressed: () {
              if (enteredReason.trim().isNotEmpty) {
                Navigator.pop(dialogContext, enteredReason.trim());
              }
            },
            child: Text(paymentText(context, 'Reject', 'مسترد کریں')),
          ),
        ],
      ),
    );
  }

  Future<String?> _choosePaymentMethod(
    BuildContext context, {
    required String title,
    required String prompt,
  }) => showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt),
          const SizedBox(height: 12),
          ...['Cash', 'Card'].map(
            (method) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                method == 'Card'
                    ? Icons.credit_card_rounded
                    : Icons.payments_outlined,
              ),
              title: Text(
                paymentText(context, method, method == 'Card' ? 'کارڈ' : 'نقد'),
              ),
              onTap: () => Navigator.pop(dialogContext, method),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(paymentText(context, 'Cancel', 'منسوخ')),
        ),
      ],
    ),
  );
}
