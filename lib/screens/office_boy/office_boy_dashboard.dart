import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
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
    final user = auth.currentUser;

    final myRequests = user != null ? expense.getMyRequests(user.uid) : [];
    final pendingCount = myRequests.where((r) => r.isPending).length;

    final destinations = [
      NavigationItem(
        icon: Icons.history_rounded,
        selectedIcon: Icons.history_edu_rounded,
        label: 'My Requests',
        badgeCount: pendingCount > 0 ? pendingCount : null,
      ),
      const NavigationItem(
        icon: Icons.add_circle_outline_rounded,
        selectedIcon: Icons.add_circle_rounded,
        label: 'New Request',
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

    return AdaptiveScaffold(
      title: _currentIndex == 0 ? 'My Expense Requests' : 'Submit New Expense',
      currentIndex: _currentIndex,
      onNavigationIndexChanged: (idx) => setState(() => _currentIndex = idx),
      destinations: destinations,
      body: screens[_currentIndex],
    );
  }
}
