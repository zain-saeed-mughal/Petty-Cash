import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import '../core/core_dashboard_screens.dart';
import '../admin/user_management_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});
  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final ur = context.watch<LanguageProvider>().isRtl;
    final screens = [
      AdminCoreOverview(
        superAdmin: true,
        onRecords: () => setState(() => _index = 1),
      ),
      const CoreMonthlyRecords(),
      const UserManagementScreen(),
      const CoreOfficesScreen(),
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
        NavigationItem(
          icon: Icons.business_outlined,
          selectedIcon: Icons.business,
          label: ur ? 'دفاتر' : 'Offices',
        ),
      ],
      body: screens[_index],
    );
  }
}
