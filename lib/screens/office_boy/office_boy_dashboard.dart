import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/core_flow_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import '../core/core_dashboard_screens.dart';

class OfficeBoyDashboard extends StatefulWidget {
  const OfficeBoyDashboard({super.key});
  @override
  State<OfficeBoyDashboard> createState() => _OfficeBoyDashboardState();
}

class _OfficeBoyDashboardState extends State<OfficeBoyDashboard> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final ur = context.watch<LanguageProvider>().isRtl;
    final uid = context.watch<AuthProvider>().currentUser?.uid ?? '';
    final flow = context.watch<CoreFlowProvider>();
    final waiting =
        flow.advances.where((a) => a.officeBoyId == uid && (a.status == 'pending' || a.status == 'awaiting_office_boy_approval')).length +
        flow.reimbursements.where((r) => r.officeBoyId == uid && r.status == 'pending').length;
    return AdaptiveScaffold(
      title: '',
      currentIndex: _index,
      onNavigationIndexChanged: (index) => setState(() => _index = index),
      destinations: [
        NavigationItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: ur ? 'گھر' : 'Home',
        ),
        NavigationItem(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history,
          label: ur ? 'میرا ریکارڈ' : 'My Records',
          badgeCount: waiting > 0 ? waiting : null,
        ),
      ],
      body: _index == 0
          ? OfficeBoyHome(onRecords: () => setState(() => _index = 1))
          : const CoreRecordsScreen(),
    );
  }
}
