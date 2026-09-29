import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import 'office_boy_overview_screen.dart';
import 'new_request_screen.dart';
import 'my_requests_screen.dart';
import '../payments/payment_center_screen.dart';

class OfficeBoyDashboard extends StatefulWidget {
  const OfficeBoyDashboard({super.key});

  @override
  State<OfficeBoyDashboard> createState() => _OfficeBoyDashboardState();
}

class _OfficeBoyDashboardState extends State<OfficeBoyDashboard> {
  int _currentIndex = 0;
  int _recordsViewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final expense = Provider.of<ExpenseProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final user = auth.currentUser;

    final myRequests = user != null ? expense.getMyRequests(user.uid) : [];
    final pendingCount = myRequests.where((r) => r.isPending).length;
    final paymentAttentionCount = context
      .watch<PaymentProvider>()
      .expenses
      .where((expense) =>
        expense.status == 'Rejected' || expense.status == 'Payment Cleared')
      .length;
    final hasEarlierRequests = myRequests.isNotEmpty;

    final destinations = [
      NavigationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: lang.isRtl ? 'ڈیش بورڈ' : 'Overview',
      ),
      NavigationItem(
        icon: Icons.history_rounded,
        selectedIcon: Icons.history_edu_rounded,
        label: lang.isRtl ? 'رقم اور ریکارڈ' : 'Money & Records',
        badgeCount: pendingCount + paymentAttentionCount > 0
            ? pendingCount + paymentAttentionCount
            : null,
      ),
      NavigationItem(
        icon: Icons.add_circle_outline_rounded,
        selectedIcon: Icons.add_circle_rounded,
        label: lang.isRtl ? 'نیا اندراج' : 'Add New',
      ),
    ];

    final screens = [
      OfficeBoyOverviewScreen(
        onNewRequestTap: () => setState(() => _currentIndex = 2),
        onViewAllTap: () => setState(() {
          _currentIndex = 1;
          _recordsViewIndex = 1;
        }),
        onViewPaymentsTap: () => setState(() => _currentIndex = 1),
      ),
      _OfficeBoyRecordsWorkspace(
        hasEarlierRequests: hasEarlierRequests,
        selectedView: hasEarlierRequests ? _recordsViewIndex : 0,
        onSelectedViewChanged: (index) =>
            setState(() => _recordsViewIndex = index),
        onNewRequestTap: () => setState(() => _currentIndex = 2),
      ),
      NewRequestScreen(
        onRequestSubmitted: () => setState(() => _currentIndex = 1),
      ),
    ];

    return Directionality(
      textDirection: lang.currentLanguage == 'ur'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: AdaptiveScaffold(
        title: _currentIndex == 0
            ? (lang.isRtl ? 'ڈیش بورڈ' : 'Overview')
            : _currentIndex == 1
            ? (lang.isRtl ? 'رقم اور ریکارڈ' : 'Money & Records')
            : _currentIndex == 2
            ? (lang.isRtl ? 'کیا درج کرنا ہے؟' : 'What would you like to add?')
            : (lang.isRtl ? 'رقم اور ریکارڈ' : 'Money & Records'),
        currentIndex: _currentIndex,
        onNavigationIndexChanged: (idx) => setState(() => _currentIndex = idx),
        destinations: destinations,
        body: screens[_currentIndex],
      ),
    );
  }
}

class _OfficeBoyRecordsWorkspace extends StatelessWidget {
  final bool hasEarlierRequests;
  final int selectedView;
  final ValueChanged<int> onSelectedViewChanged;
  final VoidCallback onNewRequestTap;

  const _OfficeBoyRecordsWorkspace({
    required this.hasEarlierRequests,
    required this.selectedView,
    required this.onSelectedViewChanged,
    required this.onNewRequestTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasEarlierRequests) return const PaymentCenterScreen();
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
                label: Text(
                  language.isRtl ? 'رقم اور خرچ' : 'Money & Expenses',
                ),
              ),
              ButtonSegment(
                value: 1,
                label: Text(
                  language.isRtl ? 'پرانے ریکارڈ' : 'Earlier requests',
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
            children: [
              const PaymentCenterScreen(),
              MyRequestsScreen(onNewRequestTap: onNewRequestTap),
            ],
          ),
        ),
      ],
    );
  }
}
