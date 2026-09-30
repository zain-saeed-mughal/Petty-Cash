import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import '../core/core_dashboard_screens.dart';
import 'user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final ur = context.watch<LanguageProvider>().isRtl;
    final screens = [
      AdminCoreOverview(
        superAdmin: false,
        onRecords: () => setState(() => _index = 1),
      ),
      const CoreMonthlyRecords(),
      const UserManagementScreen(),
    ];
    return AdaptiveScaffold(
      title: '',
      currentIndex: _index,
      onNavigationIndexChanged: (index) => setState(() => _index = index),
      destinations: [
        NavigationItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: ur ? 'خلاصہ' : 'Overview',
        ),
        NavigationItem(
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          label: ur ? 'ریکارڈ' : 'Records',
        ),
        NavigationItem(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: ur ? 'صارفین' : 'Users',
        ),
      ],
      body: screens[_index],
    );
  }
}
