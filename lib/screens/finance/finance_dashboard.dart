import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import 'pending_requests_screen.dart';
import 'payment_history_screen.dart';
import '../reports/monthly_reporting_screen.dart';

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final pendingCount = expense.pendingCount;

    final destinations = [
      NavigationItem(
        icon: Icons.pending_actions_outlined,
        selectedIcon: Icons.pending_actions_rounded,
        label: 'Pending Reviews',
        badgeCount: pendingCount > 0 ? pendingCount : null,
      ),
      const NavigationItem(
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments_rounded,
        label: 'Payment History',
      ),
      const NavigationItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: 'Monthly Reports',
      ),
    ];

    final screens = const [
      PendingRequestsScreen(),
      PaymentHistoryScreen(),
      MonthlyReportingScreen(),
    ];

    final titles = [
      'Pending Approvals',
      'Payment History',
      'Monthly Reports',
    ];

    return AdaptiveScaffold(
      title: titles[_currentIndex],
      currentIndex: _currentIndex,
      onNavigationIndexChanged: (idx) => setState(() => _currentIndex = idx),
      destinations: destinations,
      body: screens[_currentIndex],
    );
  }
}
