import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import 'finance_overview_screen.dart';
import 'pending_requests_screen.dart';
import 'payment_history_screen.dart';
import '../reports/monthly_reporting_screen.dart';
import '../payments/payment_center_screen.dart';

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
  int _currentIndex = 0;
  int _requestViewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final pendingCount = expense.pendingCount;
    final paymentPending =
        context
            .watch<PaymentProvider>()
            .expenses
            .where(
              (row) =>
                  row.status == 'Pending' ||
                  (row.flowType == 'reimbursement' && row.status == 'Approved'),
            )
            .length +
        context
            .watch<PaymentProvider>()
            .advanceRequests
            .where((row) => row.status == 'Pending')
            .length;

    final destinations = [
      NavigationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: lang.isRtl ? 'ڈیش بورڈ' : 'Overview',
      ),
      NavigationItem(
        icon: Icons.pending_actions_outlined,
        selectedIcon: Icons.pending_actions_rounded,
        label: lang.isRtl ? 'رقم کا حساب' : 'Money',
        badgeCount: paymentPending > 0 ? paymentPending : null,
      ),
      NavigationItem(
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments_rounded,
        label: lang.isRtl ? 'پرانا ریکارڈ' : 'Earlier',
        badgeCount: pendingCount > 0 ? pendingCount : null,
      ),
      NavigationItem(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        label: lang.tr('monthly_reports'),
      ),
    ];

    final screens = [
      FinanceOverviewScreen(
        onViewPendingTap: () => setState(() {
          _currentIndex = 2;
          _requestViewIndex = 0;
        }),
        onViewHistoryTap: () => setState(() {
          _currentIndex = 2;
          _requestViewIndex = 1;
        }),
        onViewPaymentsTap: () => setState(() => _currentIndex = 1),
      ),
      const PaymentCenterScreen(),
      _FinanceRequestsWorkspace(
        selectedView: _requestViewIndex,
        onSelectedViewChanged: (index) =>
            setState(() => _requestViewIndex = index),
      ),
      const MonthlyReportingScreen(),
    ];

    final titles = [
      lang.isRtl ? 'فنانس ڈیش بورڈ' : 'Finance Dashboard',
      lang.isRtl ? 'رقم اور خرچ' : 'Money & Expenses',
      lang.isRtl ? 'پرانی درخواستیں' : 'Earlier Requests',
      lang.tr('monthly_reports'),
    ];

    return Directionality(
      textDirection: lang.currentLanguage == 'ur'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: AdaptiveScaffold(
        title: titles[_currentIndex],
        currentIndex: _currentIndex,
        onNavigationIndexChanged: (idx) => setState(() => _currentIndex = idx),
        destinations: destinations,
        body: screens[_currentIndex],
      ),
    );
  }
}

class _FinanceRequestsWorkspace extends StatelessWidget {
  final int selectedView;
  final ValueChanged<int> onSelectedViewChanged;

  const _FinanceRequestsWorkspace({
    required this.selectedView,
    required this.onSelectedViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(language.isRtl ? 'زیرِ التواء' : 'Pending'),
              ),
              ButtonSegment(
                value: 1,
                label: Text(
                  language.isRtl ? 'ادائیگی کی ہسٹری' : 'Payment history',
                ),
              ),
            ],
            selected: {selectedView},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onSelectedViewChanged(selection.first);
              }
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: selectedView,
            children: const [PendingRequestsScreen(), PaymentHistoryScreen()],
          ),
        ),
      ],
    );
  }
}
