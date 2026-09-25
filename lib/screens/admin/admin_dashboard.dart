import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import 'all_transactions_screen.dart';
import 'user_management_screen.dart';
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
    final lang = Provider.of<LanguageProvider>(context);

    final destinations = [
      NavigationItem(
        icon: Icons.bar_chart_rounded,
        selectedIcon: Icons.insert_chart_rounded,
        label: lang.tr('analytics_nav'),
      ),
      NavigationItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: lang.tr('transactions_nav'),
        badgeCount: expense.pendingCount > 0 ? expense.pendingCount : null,
      ),
      NavigationItem(
        icon: Icons.people_alt_outlined,
        selectedIcon: Icons.people_alt_rounded,
        label: lang.tr('users_nav'),
      ),
      NavigationItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: lang.tr('reports_nav'),
      ),
    ];

    final screens = [
      const AnalyticsScreen(),
      const AllTransactionsScreen(),
      const UserManagementScreen(),
      const MonthlyReportingScreen(),
    ];

    final titles = [
      lang.tr('reports_analytics_title'),
      lang.tr('all_transactions_title'),
      lang.tr('user_management_title'),
      lang.tr('monthly_reports_title'),
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
