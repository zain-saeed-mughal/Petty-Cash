import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
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

    final destinations = [
      const NavigationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: 'Analytics',
      ),
      NavigationItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: 'Transactions',
        badgeCount: expense.pendingCount > 0 ? expense.pendingCount : null,
      ),
      const NavigationItem(
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings_rounded,
        label: 'Users & Roles',
      ),
      const NavigationItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: 'Reports',
      ),
    ];

    final screens = const [
      AnalyticsScreen(),
      AllTransactionsScreen(),
      UserManagementScreen(),
      MonthlyReportingScreen(),
    ];

    final titles = [
      'Executive Analytics Dashboard',
      'Transactions Audit & Override',
      'User & Role Management',
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
