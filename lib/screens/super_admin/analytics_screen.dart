import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../widgets/stat_card.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;
    final isTablet = screenWidth >= 600 && screenWidth < 950;

    final totalSpent = expense.totalSpent;
    final pendingAmount = expense.pendingAmount;
    final approvedCount = expense.approvedCount;
    final pendingCount = expense.pendingCount;
    final rejectedCount = expense.rejectedCount;
    final totalCount = expense.totalTransactionsCount;

    return SingleChildScrollView(
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
                children: const [
                  Text(
                    'Financial Analytics & Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Real-time overview of petty cash outflows, approvals, and queue bottlenecks',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // KPI Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isDesktop ? 1.4 : 2.0,
                    children: [
                      StatCard(
                        title: 'TOTAL DISBURSED',
                        value: '${AppConstants.defaultCurrencySymbol}${totalSpent.toStringAsFixed(2)}',
                        subtitle: '$approvedCount approved payments',
                        icon: Icons.payments_rounded,
                        color: AppTheme.statusApproved,
                      ),
                      StatCard(
                        title: 'PENDING QUEUE',
                        value: '${AppConstants.defaultCurrencySymbol}${pendingAmount.toStringAsFixed(2)}',
                        subtitle: '$pendingCount requests awaiting review',
                        icon: Icons.hourglass_top_rounded,
                        color: AppTheme.statusPending,
                      ),
                      StatCard(
                        title: 'APPROVAL RATE',
                        value: '${expense.approvalRate.toStringAsFixed(1)}%',
                        subtitle: '$approvedCount of ${approvedCount + rejectedCount} reviewed',
                        icon: Icons.verified_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                      StatCard(
                        title: 'REJECTION COUNT',
                        value: '$rejectedCount',
                        subtitle: 'Returned to requester',
                        icon: Icons.cancel_rounded,
                        color: AppTheme.statusRejected,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Charts Row / Column
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildStatusPieChartCard(
                        pendingCount: pendingCount,
                        approvedCount: approvedCount,
                        rejectedCount: rejectedCount,
                        totalCount: totalCount,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 7,
                      child: _buildSpendingBarChartCard(expense),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildStatusPieChartCard(
                      pendingCount: pendingCount,
                      approvedCount: approvedCount,
                      rejectedCount: rejectedCount,
                      totalCount: totalCount,
                    ),
                    const SizedBox(height: 20),
                    _buildSpendingBarChartCard(expense),
                  ],
                ),
              const SizedBox(height: 28),

              // Recent Transaction Log Overview
              _buildTopRequestersCard(expense),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPieChartCard({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
    required int totalCount,
  }) {
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
          const Text(
            'Request Status Distribution',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 4),
          const Text(
            'Proportion of approved, pending, and rejected requests',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: totalCount == 0
                ? const Center(child: Text('No request data available'))
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
                            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (pendingCount > 0)
                          PieChartSectionData(
                            color: AppTheme.statusPending,
                            value: pendingCount.toDouble(),
                            title: '$pendingCount',
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (rejectedCount > 0)
                          PieChartSectionData(
                            color: AppTheme.statusRejected,
                            value: rejectedCount.toDouble(),
                            title: '$rejectedCount',
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
              _buildLegendItem('Approved ($approvedCount)', AppTheme.statusApproved),
              _buildLegendItem('Pending ($pendingCount)', AppTheme.statusPending),
              _buildLegendItem('Rejected ($rejectedCount)', AppTheme.statusRejected),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _buildSpendingBarChartCard(ExpenseProvider expense) {
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
          const Text(
            'Recent Expense Amount Comparison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 4),
          const Text(
            'Amounts of the latest expense submissions (${AppConstants.defaultCurrencySymbol})',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: requests.isEmpty
                ? const Center(child: Text('No transactions recorded yet.'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: requests.map((r) => r.amount).reduce((a, b) => a > b ? a : b) * 1.25 + 10,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < requests.length) {
                                final desc = requests[idx].itemDescription;
                                final short = desc.length > 8 ? '${desc.substring(0, 6)}..' : desc;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(short, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (val, meta) {
                              return Text(
                                '${val.toInt()}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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

  Widget _buildTopRequestersCard(ExpenseProvider expense) {
    final Map<String, double> requesterTotals = {};
    for (final r in expense.allRequests) {
      if (r.isApproved || r.isPaid) {
        requesterTotals[r.requesterName] = (requesterTotals[r.requesterName] ?? 0.0) + r.amount;
      }
    }

    final sorted = requesterTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

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
          const Text(
            'Disbursements by Requester',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cumulative approved petty cash expenditure per staff member',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No approved transactions found yet.'),
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
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        child: Text('${idx + 1}', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryNavy),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${AppConstants.defaultCurrencySymbol}${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryBlue),
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
