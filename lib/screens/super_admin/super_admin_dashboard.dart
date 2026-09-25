import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import 'analytics_screen.dart';
import '../admin/all_transactions_screen.dart';
import '../admin/user_management_screen.dart';
import '../reports/monthly_reporting_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);

    final destinations = [
      NavigationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: lang.tr('analytics_nav'),
      ),
      NavigationItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: lang.tr('transactions_nav'),
        badgeCount: expense.pendingCount > 0 ? expense.pendingCount : null,
      ),
      NavigationItem(
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings_rounded,
        label: lang.tr('users_nav'),
      ),
      NavigationItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: lang.tr('reports_nav'),
      ),
    ];

    final screens = const [
      AnalyticsScreen(),
      AllTransactionsScreen(),
      UserManagementScreen(),
      MonthlyReportingScreen(),
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
