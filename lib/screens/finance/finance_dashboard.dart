import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
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
    final lang = Provider.of<LanguageProvider>(context);
    final pendingCount = expense.pendingCount;

    final destinations = [
      NavigationItem(
        icon: Icons.pending_actions_outlined,
        selectedIcon: Icons.pending_actions_rounded,
        label: lang.tr('pending_reviews'),
        badgeCount: pendingCount > 0 ? pendingCount : null,
      ),
      NavigationItem(
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments_rounded,
        label: lang.tr('payment_history'),
      ),
      NavigationItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: lang.tr('monthly_reports'),
      ),
    ];

    final screens = const [
      PendingRequestsScreen(),
      PaymentHistoryScreen(),
      MonthlyReportingScreen(),
    ];

    final titles = [
      lang.tr('pending_approvals'),
      lang.tr('payment_history'),
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
