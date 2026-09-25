import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/stat_card.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;

    final totalSpent = expense.totalSpent;
    final pendingAmount = expense.pendingAmount;
    final approvedCount = expense.approvedCount;
    final pendingCount = expense.pendingCount;
    final rejectedCount = expense.rejectedCount;
    final totalCount = expense.totalTransactionsCount;

    return RefreshIndicator(
      onRefresh: () async {
        expense.refresh();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr('financial_analytics_reports'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.tr('financial_analytics_sub'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // KPI Cards Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    int crossAxisCount = 1;
                    if (availableWidth >= 800) {
                      crossAxisCount = 4;
                    } else if (availableWidth >= 500) {
                      crossAxisCount = 2;
                    }

                    final spacing = 16.0;
                    final cardWidth =
                        (availableWidth - (crossAxisCount - 1) * spacing) /
                        crossAxisCount;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: StatCard(
                            title: Provider.of<LanguageProvider>(context)
                                .tr('total_disbursed'),
                            value: context.language.money(totalSpent),
                            subtitle:
                                '$approvedCount${Provider.of<LanguageProvider>(context).tr('approved_payments_suffix')}',
                            icon: Icons.payments_rounded,
                            color: AppTheme.statusApproved,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: StatCard(
                            title: Provider.of<LanguageProvider>(context)
                                .tr('pending_queue'),
                            value: context.language.money(pendingAmount),
                            subtitle:
                                '$pendingCount${Provider.of<LanguageProvider>(context).tr('requests_awaiting_review')}',
                            icon: Icons.hourglass_top_rounded,
                            color: AppTheme.statusPending,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: StatCard(
                            title: Provider.of<LanguageProvider>(context)
                                .tr('approval_rate'),
                            value:
                                '${expense.approvalRate.toStringAsFixed(1)}%',
                            subtitle: context.language.format(
                              '{approved} of {total} reviewed',
                              '{total} میں سے {approved} منظور',
                              {
                                'approved': approvedCount,
                                'total': approvedCount + rejectedCount,
                              },
                            ),
                            icon: Icons.verified_rounded,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: StatCard(
                            title: Provider.of<LanguageProvider>(context)
                                .tr('rejection_count'),
                            value: '$rejectedCount',
                            subtitle: Provider.of<LanguageProvider>(context)
                                .tr('returned_to_requester'),
                            icon: Icons.cancel_rounded,
                            color: AppTheme.statusRejected,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final metric in [
                      (
                        context.t('Verified expenses'),
                        expense.verifiedExpenses,
                      ),
                      (context.t('Verified returns'), expense.returnedAmount),
                      (
                        context.t('Unsettled advances'),
                        expense.outstandingAdvances,
                      ),
                    ])
                      Chip(
                        label: Text(
                          '${metric.$1}: ${context.language.money(metric.$2)}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // Charts Row / Column
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildStatusPieChartCard(
                          context: context,
                          pendingCount: pendingCount,
                          approvedCount: approvedCount,
                          rejectedCount: rejectedCount,
                          totalCount: totalCount,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 7,
                        child: _buildSpendingBarChartCard(context, expense),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildStatusPieChartCard(
                        context: context,
                        pendingCount: pendingCount,
                        approvedCount: approvedCount,
                        rejectedCount: rejectedCount,
                        totalCount: totalCount,
                      ),
                      const SizedBox(height: 20),
                      _buildSpendingBarChartCard(context, expense),
                    ],
                  ),
                const SizedBox(height: 28),

                // Recent Transaction Log Overview
                _buildTopRequestersCard(context, expense),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPieChartCard({
    required BuildContext context,
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
    required int totalCount,
  }) {
    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('req_status_dist'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.tr('req_status_dist_sub'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: totalCount == 0
                ? Center(child: Text(lang.tr('no_req_data')))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: [
                        if (approvedCount > 0)
                          PieChartSectionData(
                            color: AppTheme.statusApproved,
                            value: approvedCount.toDouble(),
                            title: '$approvedCount',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (pendingCount > 0)
                          PieChartSectionData(
                            color: AppTheme.statusPending,
                            value: pendingCount.toDouble(),
                            title: '$pendingCount',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (rejectedCount > 0)
                          PieChartSectionData(
                            color: AppTheme.statusRejected,
                            value: rejectedCount.toDouble(),
                            title: '$rejectedCount',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildLegendItem(
                '${lang.tr('approved_word')} ($approvedCount)',
                AppTheme.statusApproved,
              ),
              _buildLegendItem(
                '${lang.tr('pending')} ($pendingCount)',
                AppTheme.statusPending,
              ),
              _buildLegendItem(
                '${lang.tr('rejected')} ($rejectedCount)',
                AppTheme.statusRejected,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingBarChartCard(
    BuildContext context,
    ExpenseProvider expense,
  ) {
    final lang = Provider.of<LanguageProvider>(context);
    final requests = expense.allRequests.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('recent_exp_amt_comp'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.tr('recent_exp_amt_sub'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: requests.isEmpty
                ? Center(child: Text(lang.tr('no_transactions_recorded_yet')))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          requests
                                  .map((r) => r.amount)
                                  .reduce((a, b) => a > b ? a : b) *
                              1.25 +
                          10,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < requests.length) {
                                final desc = requests[idx].itemDescription;
                                final short = desc.length > 8
                                    ? '${desc.substring(0, 6)}..'
                                    : desc;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    short,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (val, meta) {
                              if (val == meta.max || val == meta.min) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                NumberFormat.compact(
                                  locale: context.language.currentLanguage,
                                ).format(val),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                                textAlign: TextAlign.right,
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      barGroups: List.generate(requests.length, (i) {
                        final req = requests[i];
                        Color barColor = AppTheme.primaryBlue;
                        if (req.isRejected) barColor = AppTheme.statusRejected;
                        if (req.isPending) barColor = AppTheme.statusPending;

                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: req.amount,
                              color: barColor,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRequestersCard(
    BuildContext context,
    ExpenseProvider expense,
  ) {
    final lang = Provider.of<LanguageProvider>(context);
    final Map<String, double> requesterTotals = {};
    for (final r in expense.allRequests) {
      if (r.hasDisbursement) {
        requesterTotals[r.requestedBy] =
            (requesterTotals[r.requestedBy] ?? 0.0) + r.amount;
      }
    }

    final sorted = requesterTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('disbursements_by_req'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.tr('disbursements_by_req_sub'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(lang.tr('no_paid_transactions_yet')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final entry = sorted[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryBlue.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          expense.allRequests
                              .firstWhere((r) => r.requestedBy == entry.key)
                              .requesterName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.primaryNavy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        context.language.money(entry.value),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
