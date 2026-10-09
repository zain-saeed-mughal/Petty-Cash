import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/core_flow_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/adaptive_scaffold.dart';
import '../../widgets/modern_dashboard_view.dart';
import '../core/core_dashboard_screens.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final ur = context.watch<LanguageProvider>().isRtl;
    final screens = [
      ManagerHome(onRecords: () => setState(() => _index = 1)),
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
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          label: ur ? 'ریکارڈ' : 'Records',
        ),
      ],
      body: screens[_index],
    );
  }
}

class ManagerHome extends StatefulWidget {
  final VoidCallback? onRecords;
  const ManagerHome({super.key, this.onRecords});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _startDate;
  DateTime? _endDate;

  bool _inRange(DateTime date) {
    if (_startDate != null && _endDate != null) {
      final d = DateTime(date.year, date.month, date.day);
      final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      return !d.isBefore(s) && !d.isAfter(e);
    }
    return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<CoreFlowProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final uid = user?.uid ?? '';
    final ur = context.watch<LanguageProvider>().isRtl;

    final myItems = flow.items.where((i) => i.taggedManagerId == uid).toList();
    final myReimbursements = flow.reimbursements.where((r) => r.taggedManagerId == uid).toList();

    double totalTaggedItems = 0;
    double totalTaggedReimbursements = 0;

    for (var i in myItems) {
      if (i.status != 'rejected') {
        if (_inRange(i.createdAt)) totalTaggedItems += i.amount;
      }
    }
    for (var r in myReimbursements) {
      if (r.status != 'rejected' && r.status != 'declined') {
        if (_inRange(r.createdAt)) totalTaggedReimbursements += r.amount;
      }
    }

    final totalSpent = totalTaggedItems + totalTaggedReimbursements;
    final pendingCount = myItems.where((i) => i.status == 'pending' && _inRange(i.createdAt)).length +
        myReimbursements.where((r) => r.status == 'pending' && _inRange(r.createdAt)).length;

    final pendingAmount = myItems.where((i) => i.status == 'pending' && _inRange(i.createdAt)).fold<double>(0, (s, i) => s + i.amount) +
        myReimbursements.where((r) => r.status == 'pending' && _inRange(r.createdAt)).fold<double>(0, (s, r) => s + r.amount);

    final heroAmount = totalSpent > 0
        ? totalSpent
        : (pendingAmount > 0 ? pendingAmount : 0.0);

    final recentList = <RecentActivityItem>[];
    final seenIds = <String>{};
    for (final item in myItems.where((i) => _inRange(i.createdAt)).take(6)) {
      if (!seenIds.add('item_${item.id}')) continue;
      final isDone = item.status == 'approved';
      recentList.add(RecentActivityItem(
        icon: Icons.shopping_cart_rounded,
        iconColor: const Color(0xFF1E60FF),
        iconBgColor: const Color(0xFFEFF6FF),
        title: item.description,
        subtitle: 'PKR ${item.amount.toInt()} · Tagged purchase',
        time: DateFormat('d MMM').format(item.createdAt),
        statusDotColor: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
      ));
    }
    for (final r in myReimbursements.where((r) => _inRange(r.createdAt)).take(4)) {
      if (!seenIds.add('reimb_${r.id}')) continue;
      final isDone = r.status == 'paid' || r.status == 'approved';
      recentList.add(RecentActivityItem(
        icon: Icons.receipt_long_rounded,
        iconColor: const Color(0xFF0D9488),
        iconBgColor: const Color(0xFFF0FDFA),
        title: r.description,
        subtitle: 'PKR ${r.amount.toInt()} · Tagged reimbursement',
        time: DateFormat('d MMM').format(r.createdAt),
        statusDotColor: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
      ));
    }

    return ModernDashboardView(
      showBranchFilter: false,
      showFinancialCards: false,
      roleBadgeText: ur ? 'مینیجر' : 'Branch Manager',
      heroTitle: ur ? 'مینیج شدہ اخراجات' : 'Managed Branch Budget',
      heroAmount: heroAmount,
      availableAmount: 0,
      onHoldAmount: 0,
      spentAmount: 0,
      metric1Count: myItems.where((i) => _inRange(i.createdAt)).length,
      metric1Label: ur ? 'خریداری' : 'Purchases',
      metric1Icon: Icons.shopping_cart_rounded,
      metric2Count: myReimbursements.where((r) => _inRange(r.createdAt)).length,
      metric2Label: ur ? 'واپسی' : 'Reimb.',
      metric2Icon: Icons.receipt_rounded,
      metric3Count: pendingCount,
      metric3Label: ur ? 'زیر التوا' : 'Pending',
      metric3Icon: Icons.hourglass_top_rounded,
      recentActivities: recentList,
      onViewReport: widget.onRecords,
      onViewAllActivity: widget.onRecords,
      initialMonth: _selectedMonth,
      initialStartDate: _startDate,
      initialEndDate: _endDate,
      onDateRangeChanged: (start, end) {
        setState(() {
          _startDate = start;
          _endDate = end;
          _selectedMonth = DateTime(start.year, start.month);
        });
      },
      onMonthChanged: (m) => setState(() {
        _selectedMonth = m;
        _startDate = DateTime(m.year, m.month, 1);
        _endDate = DateTime(m.year, m.month + 1, 0);
      }),
    );
  }
}
