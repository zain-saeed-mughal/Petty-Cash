import 'package:petty_cash/l10n/context_l10n.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/expense_request_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final expense = context.watch<ExpenseProvider>();
    final users = context.watch<UserProvider>().allUsers;

    final rows = expense.allRequests
        .where((r) => _matches(r) && _inMonth(r, _month))
        .toList();

    final previous = DateTime(_month.year, _month.month - 1);
    final paid = rows
        .where((r) => r.hasDisbursement)
        .fold(0.0, (sum, r) => sum + r.amount);
    final previousPaid = expense.allRequests
        .where((r) => r.hasDisbursement && _matches(r) && _inMonth(r, previous))
        .fold(0.0, (sum, r) => sum + r.amount);
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
                                                context.t('All statuses'),
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
                                context.language.money(paid),
                                Icons.payments_outlined,
                                AppTheme.accentTeal,
                                previousPaid > 0
                                    ? '${(((paid - previousPaid) / previousPaid) * 100).toStringAsFixed(1)}${Provider.of<LanguageProvider>(context).tr('vs_prev_month')}'
                                    : Provider.of<LanguageProvider>(context)
                                          .tr('no_prev_paid'),
                              ),
                              _metric(
                                width,
                                Provider.of<LanguageProvider>(context)
                                    .tr('requests_in_view'),
                                rows.length.toString(),
                                Icons.receipt_long_outlined,
                                AppTheme.primaryBlue,
                                Provider.of<LanguageProvider>(context)
                                    .tr('all_filters_applied'),
                              ),
                              _metric(
                                width,
                                Provider.of<LanguageProvider>(context)
                                    .tr('pending'),
                                rows
                                    .where((r) => r.isPending)
                                    .length
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
                                rows
                                    .where((r) => r.isRejected)
                                    .length
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
                              DataColumn(label: Text(context.t('Status'))),
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
