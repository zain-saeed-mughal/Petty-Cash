import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../providers/core_flow_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import '../core/core_dashboard_screens.dart';

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});
  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final ur = context.watch<LanguageProvider>().isRtl;
    final flow = context.watch<CoreFlowProvider>();
    final advances = flow.advances
        .where((a) => a.status == 'pending' || a.status == 'awaiting_office_boy_approval')
        .length;
    final repayments = flow.reimbursements
        .where((r) => r.status == 'pending' || r.status == 'approved')
        .length;
    final screens = [
      FinanceHome(
        onAdvances: () => setState(() => _index = 1),
        onReimbursements: () => setState(() => _index = 2),
        onRecords: () => setState(() => _index = 4),
      ),
      const FinanceQueue(advances: true),
      const FinanceQueue(advances: false),
      const FinanceBalances(),
      const CoreMonthlyRecords(),
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
          icon: Icons.wallet_outlined,
          selectedIcon: Icons.wallet,
          label: ur ? 'ایڈوانس' : 'Advances',
          badgeCount: advances > 0 ? advances : null,
        ),
        NavigationItem(
          icon: Icons.shopping_bag_outlined,
          selectedIcon: Icons.shopping_bag,
          label: ur ? 'واپسی' : 'Repayments',
          badgeCount: repayments > 0 ? repayments : null,
        ),
        NavigationItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          label: ur ? 'بیلنس' : 'Balances',
        ),
        NavigationItem(
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          label: ur ? 'ریکارڈ' : 'Records',
        ),
      ],
      body: screens[_index],
    );
  }
}
