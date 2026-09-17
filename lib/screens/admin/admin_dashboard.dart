import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import 'all_transactions_screen.dart';
import '../super_admin/analytics_screen.dart';
import '../reports/monthly_reporting_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);

    final destinations = [
      NavigationItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: 'Transactions',
        badgeCount: expense.pendingCount > 0 ? expense.pendingCount : null,
      ),
      const NavigationItem(
        icon: Icons.bar_chart_rounded,
        selectedIcon: Icons.insert_chart_rounded,
        label: 'Reports & Analytics',
      ),
      const NavigationItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: 'Monthly Reports',
      ),
    ];

    final screens = const [
      AllTransactionsScreen(),
      AnalyticsScreen(),
      MonthlyReportingScreen(),
    ];

    final titles = [
      'All Transactions',
      'Reports & Analytics',
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
