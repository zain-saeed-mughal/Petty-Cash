import 'package:petty_cash/l10n/context_l10n.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/expense_request_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/status_badge.dart';
import '../finance/request_detail_screen.dart';

class MonthlyReportingScreen extends StatefulWidget {
  const MonthlyReportingScreen({super.key});

  @override
  State<MonthlyReportingScreen> createState() => _MonthlyReportingScreenState();
}

class _MonthlyReportingScreenState extends State<MonthlyReportingScreen> {
  DateTime _month = DateTime.now();
  String? _user;
  RequestStatus? _status;
  int _page = 0;

  void _move(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _page = 0;
  });

  bool _matches(ExpenseRequest r) =>
      (_user == null || r.requestedBy == _user) &&
      (_status == null || r.status == _status);

  bool _inMonth(ExpenseRequest r, DateTime month) {
    if (r.hasDisbursement && r.paidAt == null) return false;
    final d = r.reportingDate;
    return d.year == month.year && d.month == month.month;
  }

  bool _matchesPaymentStatus(String status) => switch (_status) {
    null => true,
    RequestStatus.pending =>
      status == 'Pending' || status == 'Awaiting Confirmation',
    RequestStatus.approved => status == 'Approved' || status == 'Received',
    RequestStatus.rejected => status == 'Rejected',
    RequestStatus.paid => status == 'Paid',
    RequestStatus.pendingSettlement || RequestStatus.settled => false,
  };

  @override
  Widget build(BuildContext context) {
    final expense = context.watch<ExpenseProvider>();
    final payments = context.watch<PaymentProvider>();
    final users = context.watch<UserProvider>().allUsers;
    final names = {for (final user in users) user.uid: user.name};

    final rows = expense.allRequests
        .where((r) => _matches(r) && _inMonth(r, _month))
        .toList();
    final paymentRows = <_MonthlyPaymentRow>[];
    void addPaymentRow(_MonthlyPaymentRow row) {
      if (row.date.year == _month.year &&
          row.date.month == _month.month &&
          (_user == null || row.officeBoyId == _user) &&
          _matchesPaymentStatus(row.status)) {
        paymentRows.add(row);
      }
    }

    for (final request in payments.advanceRequests) {
      addPaymentRow(
        _MonthlyPaymentRow(
          id: request.id,
          date: request.createdAt,
          officeBoyId: request.officeBoyId,
          type: 'Advance request',
          description: request.purpose,
          amount: request.amount,
          status: request.status,
        ),
      );
    }
    for (final advance in payments.advances) {
      addPaymentRow(
        _MonthlyPaymentRow(
          id: advance.id,
          date: advance.createdAt,
          officeBoyId: advance.officeBoyId,
          type: 'Advance issued',
          description: advance.note ?? advance.financeMethod,
          amount: advance.amount,
          status: advance.status,
        ),
      );
    }
    for (final payment in payments.expenses) {
      addPaymentRow(
        _MonthlyPaymentRow(
          id: payment.id,
          date: payment.paidAt ?? payment.createdAt,
          officeBoyId: payment.officeBoyId,
          type: payment.flowType == 'float'
              ? 'Advance expense'
              : 'Own-pocket expense',
          description: payment.itemDescription,
          amount: payment.amount,
          status: payment.status,
        ),
      );
    }
    paymentRows.sort((a, b) => b.date.compareTo(a.date));
    final newAdvances = paymentRows
        .where((row) => row.type == 'Advance issued')
        .fold<double>(0, (sum, row) => sum + row.amount);
    final newFloatSpent = paymentRows
        .where(
          (row) => row.type == 'Advance expense' && row.status == 'Approved',
        )
        .fold<double>(0, (sum, row) => sum + row.amount);
    final newReimbursementsPaid = paymentRows
        .where(
          (row) => row.type == 'Own-pocket expense' && row.status == 'Paid',
        )
        .fold<double>(0, (sum, row) => sum + row.amount);
    double reimbursementsPaidIn(DateTime month) => payments.expenses
        .where(
          (payment) =>
              payment.status == 'Paid' &&
              payment.paidAt != null &&
              payment.paidAt!.year == month.year &&
              payment.paidAt!.month == month.month &&
              (_user == null || payment.officeBoyId == _user) &&
              _matchesPaymentStatus(payment.status),
        )
        .fold<double>(0, (sum, payment) => sum + payment.amount);

    final previous = DateTime(_month.year, _month.month - 1);
    final paid = rows
        .where((r) => r.hasDisbursement)
        .fold(0.0, (sum, r) => sum + r.amount);
    final previousPaid = expense.allRequests
        .where((r) => r.hasDisbursement && _matches(r) && _inMonth(r, previous))
        .fold(0.0, (sum, r) => sum + r.amount);
    final reportPaid = paid + newReimbursementsPaid;
    final reportPreviousPaid = previousPaid + reimbursementsPaidIn(previous);
    final undated = expense.allRequests
        .where((r) => r.hasDisbursement && r.paidAt == null && _matches(r))
        .length;

    final pages = math.max(1, (rows.length / 10).ceil());
    final page = math.min(_page, pages - 1);
    final visible = rows.skip(page * 10).take(10).toList();

    return LayoutBuilder(
      builder: (context, bounds) {
        final inset = bounds.maxWidth >= 900 ? 32.0 : 16.0;

        return RefreshIndicator(
          onRefresh: () async {
            expense.refresh();
            context.read<UserProvider>().refresh();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(inset),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('Monthly Reports'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          'Paid amounts use the payment date. Other requests use their submission date.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final width = math.min(280.0, c.maxWidth);
                              return Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: width,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          tooltip:
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).tr('prev_month'),
                                          onPressed: () => _move(-1),
                                          icon: const Icon(Icons.chevron_left),
                                        ),
                                        Expanded(
                                          child: Text(
                                            context.language.date(
                                              _month,
                                              pattern: 'MMMM yyyy',
                                            ),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip:
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).tr('next_month'),
                                          onPressed: () => _move(1),
                                          icon: const Icon(Icons.chevron_right),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: DropdownButtonFormField<String>(
                                      initialValue:
                                          users.any((u) => u.uid == _user)
                                          ? _user
                                          : null,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText:
                                            Provider.of<LanguageProvider>(
                                              context,
                                              listen: false,
                                            ).tr('requester'),
                                      ),
                                      items: [
                                        DropdownMenuItem<String>(
                                          value: null,
                                          child: Text(context.t('All users')),
                                        ),
                                        ...users.map(
                                          (u) => DropdownMenuItem(
                                            value: u.uid,
                                            child: Text(
                                              u.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) => setState(() {
                                        _user = v;
                                        _page = 0;
                                      }),
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child:
                                        DropdownButtonFormField<RequestStatus>(
                                          initialValue: _status,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText:
                                                Provider.of<LanguageProvider>(
                                                  context,
                                                  listen: false,
                                                ).tr('status'),
                                          ),
                                          items: [
                                            DropdownMenuItem<RequestStatus>(
                                              value: null,
                                              child: Text(
                                                context.t('Any progress'),
                                              ),
                                            ),
                                            ...RequestStatus.values.map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(
                                                  context.t(s.displayName),
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (v) => setState(() {
                                            _status = v;
                                            _page = 0;
                                          }),
                                        ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (expense.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            context.t(
                              'Data could not be refreshed. Displayed values may be out of date.',
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, c) {
                          final scale = MediaQuery.textScalerOf(context)
                              .scale(1);
                          final columns = c.maxWidth >= 1100 && scale < 1.3
                              ? 4
                              : c.maxWidth >= 600
                              ? 2
                              : 1;
                          final width =
                              (c.maxWidth - (columns - 1) * 16) / columns;

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _metric(
                                width,
                                Provider.of<LanguageProvider>(context)
                                    .tr('total_paid'),
                                context.language.money(reportPaid),
                                Icons.payments_outlined,
                                AppTheme.accentTeal,
                                reportPreviousPaid > 0
                                    ? '${(((reportPaid - reportPreviousPaid) / reportPreviousPaid) * 100).toStringAsFixed(1)}${Provider.of<LanguageProvider>(context).tr('vs_prev_month')}'
                                    : Provider.of<LanguageProvider>(context)
                                          .tr('no_prev_paid'),
                              ),
                              _metric(
                                width,
                                Provider.of<LanguageProvider>(context)
                                    .tr('requests_in_view'),
                                (rows.length + paymentRows.length).toString(),
                                Icons.receipt_long_outlined,
                                AppTheme.primaryBlue,
                                Provider.of<LanguageProvider>(context)
                                    .tr('all_filters_applied'),
                              ),
                              _metric(
                                width,
                                Provider.of<LanguageProvider>(context)
                                    .tr('pending'),
                                (rows.where((r) => r.isPending).length +
                                        paymentRows
                                            .where(
                                              (row) =>
                                                  row.status == 'Pending' ||
                                                  row.status ==
                                                      'Awaiting Confirmation',
                                            )
                                            .length)
                                    .toString(),
                                Icons.schedule_outlined,
                                AppTheme.statusPending,
                                Provider.of<LanguageProvider>(context)
                                    .tr('awaiting_decision'),
                              ),
                              _metric(
                                width,
                                Provider.of<LanguageProvider>(context)
                                    .tr('rejected'),
                                (rows.where((r) => r.isRejected).length +
                                        paymentRows
                                            .where(
                                              (row) => row.status == 'Rejected',
                                            )
                                            .length)
                                    .toString(),
                                Icons.cancel_outlined,
                                AppTheme.statusRejected,
                                Provider.of<LanguageProvider>(context)
                                    .tr('review_reasons'),
                              ),
                            ],
                          );
                        },
                      ),
                      if (undated > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            '$undated${Provider.of<LanguageProvider>(context).tr('historical_payments_no_date')}',
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        context.t('Request details'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (rows.isEmpty)
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                context.t('No requests match these filters.'),
                              ),
                            ),
                          ),
                        ),
                      if (visible.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            dataRowMinHeight: 64,
                            dataRowMaxHeight: 90,
                            headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryNavy,
                            ),
                            columns: [
                              DataColumn(label: Text(context.t('ID / Date'))),
                              DataColumn(label: Text(context.t('Requester'))),
                              DataColumn(label: Text(context.t('Description'))),
                              DataColumn(label: Text(context.t('Amount'))),
                              DataColumn(label: Text(context.t('Progress'))),
                            ],
                            rows: visible.map((r) {
                              return DataRow(
                                onSelectChanged: (_) =>
                                    RequestDetailScreen.show(context, r),
                                cells: [
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 120,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            r.displayId,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            context.language.date(
                                              r.reportingDate,
                                              pattern: 'dd MMM yyyy',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 120,
                                      ),
                                      child: Text(
                                        r.requesterName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 180,
                                      ),
                                      child: Text(
                                        r.itemDescription,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 90,
                                      ),
                                      child: Text(
                                        context.language.money(r.amount),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(StatusBadge(status: r.status)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      if (rows.isNotEmpty)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${rows.length} ${Provider.of<LanguageProvider>(context).tr('requests_suffix')} · ${Provider.of<LanguageProvider>(context).tr('page')} ${page + 1} ${Provider.of<LanguageProvider>(context).tr('of')} $pages',
                            ),
                            IconButton.outlined(
                              onPressed: page > 0
                                  ? () => setState(() => _page = page - 1)
                                  : null,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            IconButton.outlined(
                              onPressed: page + 1 < pages
                                  ? () => setState(() => _page = page + 1)
                                  : null,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                          ],
                        ),
                      const SizedBox(height: 28),
                      Text(
                        context.language.format(
                          'Advance & expense activity',
                          'ایڈوانس اور اخراجات کی سرگرمیاں',
                          const {},
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (payments.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            context.t(
                              'Payment data could not be refreshed. Displayed values may be out of date.',
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, c) {
                          final columns = c.maxWidth >= 900
                              ? 4
                              : c.maxWidth >= 500
                              ? 2
                              : 1;
                          final width =
                              (c.maxWidth - (columns - 1) * 16) / columns;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _metric(
                                width,
                                context.language.format(
                                  'Advances issued',
                                  'جاری کیے گئے ایڈوانس',
                                  const {},
                                ),
                                context.language.money(newAdvances),
                                Icons.account_balance_wallet_outlined,
                                AppTheme.primaryBlue,
                                '${paymentRows.where((row) => row.type == 'Advance issued').length} ${context.language.format('records', 'ریکارڈز', const {})}',
                              ),
                              _metric(
                                width,
                                context.language.format(
                                  'Approved advance expenses',
                                  'منظور شدہ ایڈوانس اخراجات',
                                  const {},
                                ),
                                context.language.money(newFloatSpent),
                                Icons.shopping_bag_outlined,
                                AppTheme.statusApproved,
                                context.language.format(
                                  'Selected month',
                                  'منتخب مہینہ',
                                  const {},
                                ),
                              ),
                              _metric(
                                width,
                                context.language.format(
                                  'Reimbursements paid',
                                  'ادا شدہ ذاتی اخراجات',
                                  const {},
                                ),
                                context.language.money(newReimbursementsPaid),
                                Icons.payments_outlined,
                                AppTheme.accentTeal,
                                context.language.format(
                                  'Selected month',
                                  'منتخب مہینہ',
                                  const {},
                                ),
                              ),
                              _metric(
                                width,
                                context.language.format(
                                  'New payment records',
                                  'نئے ادائیگی ریکارڈ',
                                  const {},
                                ),
                                paymentRows.length.toString(),
                                Icons.receipt_long_outlined,
                                AppTheme.primaryBlue,
                                context.language.format(
                                  'All filters applied',
                                  'تمام فلٹرز لاگو ہیں',
                                  const {},
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (paymentRows.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                context.language.format(
                                  'No new payment activity matches this month and filters.',
                                  'اس مہینے اور فلٹرز کے لیے کوئی نئی ادائیگی سرگرمی نہیں۔',
                                  const {},
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              DataColumn(
                                label: Text(
                                  context.language.format(
                                    'Date',
                                    'تاریخ',
                                    const {},
                                  ),
                                ),
                              ),
                              DataColumn(label: Text(context.t('Office Boy'))),
                              DataColumn(
                                label: Text(
                                  context.language.format(
                                    'Type',
                                    'قسم',
                                    const {},
                                  ),
                                ),
                              ),
                              DataColumn(label: Text(context.t('Description'))),
                              DataColumn(label: Text(context.t('Amount'))),
                              DataColumn(label: Text(context.t('Progress'))),
                            ],
                            rows: paymentRows.map((row) {
                              final typeUrdu = switch (row.type) {
                                'Advance request' => 'ایڈوانس کی درخواست',
                                'Advance issued' => 'ایڈوانس جاری',
                                'Advance expense' => 'ایڈوانس کا خرچ',
                                _ => 'ذاتی جیب کا خرچ',
                              };
                              return DataRow(
                                key: ValueKey(row.id),
                                cells: [
                                  DataCell(
                                    Text(
                                      context.language.date(
                                        row.date,
                                        pattern: 'dd MMM yyyy',
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      names[row.officeBoyId] ??
                                          row.officeBoyId.substring(0, 8),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      context.language.format(
                                        row.type,
                                        typeUrdu,
                                        const {},
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 220,
                                      ),
                                      child: Text(
                                        row.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(context.language.money(row.amount)),
                                  ),
                                  DataCell(Chip(label: Text(row.status))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metric(
    double width,
    String title,
    String value,
    IconData icon,
    Color color,
    String note,
  ) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xff64748b),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MonthlyPaymentRow {
  final String id;
  final DateTime date;
  final String officeBoyId;
  final String type;
  final String description;
  final double amount;
  final String status;

  const _MonthlyPaymentRow({
    required this.id,
    required this.date,
    required this.officeBoyId,
    required this.type,
    required this.description,
    required this.amount,
    required this.status,
  });
}
