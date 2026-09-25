import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import 'new_request_screen.dart';
import 'my_requests_screen.dart';

class OfficeBoyDashboard extends StatefulWidget {
  const OfficeBoyDashboard({super.key});

  @override
  State<OfficeBoyDashboard> createState() => _OfficeBoyDashboardState();
}

class _OfficeBoyDashboardState extends State<OfficeBoyDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final expense = Provider.of<ExpenseProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final user = auth.currentUser;

    final myRequests = user != null ? expense.getMyRequests(user.uid) : [];
    final pendingCount = myRequests.where((r) => r.isPending).length;

    final destinations = [
      NavigationItem(
        icon: Icons.history_rounded,
        selectedIcon: Icons.history_edu_rounded,
        label: lang.tr('my_requests'),
        badgeCount: pendingCount > 0 ? pendingCount : null,
      ),
      NavigationItem(
        icon: Icons.add_circle_outline_rounded,
        selectedIcon: Icons.add_circle_rounded,
        label: lang.tr('new_request'),
      ),
    ];

    final screens = [
      MyRequestsScreen(
        onNewRequestTap: () => setState(() => _currentIndex = 1),
      ),
      NewRequestScreen(
        onRequestSubmitted: () => setState(() => _currentIndex = 0),
      ),
    ];

    return Directionality(
      textDirection: lang.currentLanguage == 'ur'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: AdaptiveScaffold(
        title: _currentIndex == 0
            ? lang.tr('my_expense_requests')
            : lang.tr('submit_new_expense'),
        currentIndex: _currentIndex,
        onNavigationIndexChanged: (idx) => setState(() => _currentIndex = idx),
        destinations: destinations,
        body: screens[_currentIndex],
      ),
    );
  }
}
