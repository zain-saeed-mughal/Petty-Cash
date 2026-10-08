import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/core_flow_models.dart';
import '../providers/auth_provider.dart';
import '../providers/core_flow_provider.dart';
import '../providers/language_provider.dart';

class QuickActionData {
  final IconData icon;
  final String title;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const QuickActionData({
    required this.icon,
    required this.title,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

class RecentActivityItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String time;
  final Color statusDotColor;

  const RecentActivityItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.statusDotColor,
  });
}

class ModernDashboardView extends StatefulWidget {
  final String roleBadgeText;
  final String heroTitle;
  final double heroAmount;
  final double availableAmount;
  final double onHoldAmount;
  final double spentAmount;
  final int metric1Count;
  final String metric1Label;
  final IconData metric1Icon;
  final int metric2Count;
  final String metric2Label;
  final IconData metric2Icon;
  final int metric3Count;
  final String metric3Label;
  final IconData metric3Icon;
  final List<QuickActionData> quickActions;
  final List<RecentActivityItem> recentActivities;
  final VoidCallback? onViewReport;
  final VoidCallback? onViewAllActivity;
  final String? initialOfficeId;
  final DateTime? initialMonth;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final ValueChanged<String?>? onOfficeChanged;
  final ValueChanged<DateTime>? onMonthChanged;
  final void Function(DateTime from, DateTime to)? onDateRangeChanged;
  final bool showBranchFilter;
  final Widget? actionHeader;

  const ModernDashboardView({
    super.key,
    required this.roleBadgeText,
    required this.heroTitle,
    required this.heroAmount,
    required this.availableAmount,
    required this.onHoldAmount,
    required this.spentAmount,
    required this.metric1Count,
    required this.metric1Label,
    required this.metric1Icon,
    required this.metric2Count,
    required this.metric2Label,
    required this.metric2Icon,
    required this.metric3Count,
    required this.metric3Label,
    required this.metric3Icon,
    this.quickActions = const [],
    required this.recentActivities,
    this.onViewReport,
    this.onViewAllActivity,
    this.initialOfficeId,
    this.initialMonth,
    this.initialStartDate,
    this.initialEndDate,
    this.onOfficeChanged,
    this.onMonthChanged,
    this.onDateRangeChanged,
    this.showBranchFilter = true,
    this.actionHeader,
  });

  @override
  State<ModernDashboardView> createState() => _ModernDashboardViewState();
}

class _ModernDashboardViewState extends State<ModernDashboardView> {
  String? _selectedOfficeId;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedOfficeId = widget.initialOfficeId;
    _selectedMonth = widget.initialMonth ?? DateTime(DateTime.now().year, DateTime.now().month);
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  void didUpdateWidget(ModernDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMonth != null && widget.initialMonth != oldWidget.initialMonth) {
      _selectedMonth = widget.initialMonth!;
    }
    if (widget.initialStartDate != oldWidget.initialStartDate) {
      _startDate = widget.initialStartDate;
    }
    if (widget.initialEndDate != oldWidget.initialEndDate) {
      _endDate = widget.initialEndDate;
    }
    if (widget.initialOfficeId != oldWidget.initialOfficeId) {
      _selectedOfficeId = widget.initialOfficeId;
    }
  }

  String _formatMoney(double val) {
    final formatter = NumberFormat('#,##,###', 'en_US');
    return 'PKR ${formatter.format(val.toInt())}';
  }

  String _getGreeting(bool ur) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return ur ? 'صبح بخیر' : 'Good morning';
    } else if (hour < 17) {
      return ur ? 'دوپہر بخیر' : 'Good afternoon';
    } else {
      return ur ? 'شام بخیر' : 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ur = context.watch<LanguageProvider>().isRtl;
    final langProvider = context.watch<LanguageProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final flow = context.watch<CoreFlowProvider>();
    final userName = user?.name.split(' ').first ?? 'User';

    // Compute office name
    String officeDisplayName = ur ? 'تمام برانچز' : 'All Branches';
    if (_selectedOfficeId != null && _selectedOfficeId!.isNotEmpty) {
      final found = flow.offices.where((o) => o.id == _selectedOfficeId);
      if (found.isNotEmpty) {
        officeDisplayName = found.first.name;
      }
    }

    final totalFloat = widget.heroAmount > 0 ? widget.heroAmount : (widget.availableAmount + widget.onHoldAmount + widget.spentAmount);
    final availPct = totalFloat > 0 ? (widget.availableAmount / totalFloat * 100).toStringAsFixed(1) : '0.0';
    final onHoldPct = totalFloat > 0 ? (widget.onHoldAmount / totalFloat * 100).toStringAsFixed(1) : '0.0';
    final spentPct = totalFloat > 0 ? (widget.spentAmount / totalFloat * 100).toStringAsFixed(1) : '0.0';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // 1. Top Greeting Header with Language Toggle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_getGreeting(ur)}, ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            userName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ur
                          ? 'یہاں آپ کی کمپنی کا تازہ ترین خلاصہ ہے'
                          : "Here's what's happening across your company",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Language Switcher Capsule [EN | اردو]
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (langProvider.currentLanguage != 'en') {
                          langProvider.setLanguage('en');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: langProvider.currentLanguage == 'en'
                              ? const Color(0xFF1E60FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'EN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: langProvider.currentLanguage == 'en'
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (langProvider.currentLanguage != 'ur') {
                          langProvider.setLanguage('ur');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: langProvider.currentLanguage == 'ur'
                              ? const Color(0xFF1E60FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'اردو',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'JameelNooriNastaleeq',
                            color: langProvider.currentLanguage == 'ur'
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Section Header: Overview + Role Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ur ? 'خلاصہ' : 'Overview',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.5) : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.4) : const Color(0xFFDDD6FE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 4),
                    Text(
                      widget.roleBadgeText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.actionHeader != null) ...[
            const SizedBox(height: 12),
            widget.actionHeader!,
          ],

          const SizedBox(height: 12),

          // 3. Filters Row: Branch Dropdown & Date Range Picker
          Row(
            children: [
              if (widget.showBranchFilter) ...[
                // Branch Filter
                Expanded(
                  child: InkWell(
                    onTap: () => _openBranchPicker(context, flow.offices),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business_rounded, size: 17, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              officeDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Date Range Filter (With Separate Calendars)
              Expanded(
                child: InkWell(
                  onTap: () => _openDateRangePicker(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _startDate != null && _endDate != null
                                ? '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}'
                                : DateFormat('MMMM yyyy').format(_selectedMonth),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Hero Card (Gradient Purple - never overflows in RTL / Urdu)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF6D28D9), Color(0xFF4C1D95)]
                    : const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.heroTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          _formatMoney(widget.heroAmount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 5. Small Cards Row 1: Available, On Hold, Spent (3 in one row with different colors)
          Row(
            children: [
              // Available (Mint Green)
              Expanded(
                child: _buildSmallStatCard(
                  bgColor: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFFBBF7D0),
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFDCFCE7),
                  title: ur ? 'دستیاب' : 'Available',
                  amount: _formatMoney(widget.availableAmount),
                  subtitle: '$availPct% ${ur ? 'کل کا' : 'of total'}',
                ),
              ),
              const SizedBox(width: 8),
              // On Hold (Amber/Orange)
              Expanded(
                child: _buildSmallStatCard(
                  bgColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                  icon: Icons.access_time_filled_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFEF3C7),
                  title: ur ? 'زیر التوا' : 'On Hold',
                  amount: _formatMoney(widget.onHoldAmount),
                  subtitle: '$onHoldPct% ${ur ? 'کل کا' : 'of total'}',
                ),
              ),
              const SizedBox(width: 8),
              // Spent (Soft Blue)
              Expanded(
                child: _buildSmallStatCard(
                  bgColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                  icon: Icons.pie_chart_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBgColor: const Color(0xFFDBEAFE),
                  title: ur ? 'خرچ شدہ' : 'Spent',
                  amount: _formatMoney(widget.spentAmount),
                  subtitle: '$spentPct% ${ur ? 'کل کا' : 'of total'}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 6. Small Cards Row 2: Users, Branches, Pending (3 in one row with different colors)
          Row(
            children: [
              // Metric 1 (Pastel Blue)
              Expanded(
                child: _buildCounterCard(
                  icon: widget.metric1Icon,
                  iconColor: const Color(0xFF2563EB),
                  iconBgColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                  count: '${widget.metric1Count}',
                  label: widget.metric1Label,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              // Metric 2 (Pastel Teal)
              Expanded(
                child: _buildCounterCard(
                  icon: widget.metric2Icon,
                  iconColor: const Color(0xFF0D9488),
                  iconBgColor: isDark ? const Color(0xFF134E4A).withValues(alpha: 0.5) : const Color(0xFFF0FDFA),
                  count: '${widget.metric2Count}',
                  label: widget.metric2Label,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              // Metric 3 (Pastel Amber)
              Expanded(
                child: _buildCounterCard(
                  icon: widget.metric3Icon,
                  iconColor: const Color(0xFFD97706),
                  iconBgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFFFBEB),
                  count: '${widget.metric3Count}',
                  label: widget.metric3Label,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Spending Overview (Bar Chart)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ur ? 'اخراجات کا جائزہ' : 'Spending overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (widget.onViewReport != null)
                      InkWell(
                        onTap: widget.onViewReport,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ur ? 'رپورٹ دیکھیں' : 'View report',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSpendingBarChart(flow, isDark, ur),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 9. Recent Activity Section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ur ? 'حالیہ سرگرمی' : 'Recent activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (widget.onViewAllActivity != null)
                      InkWell(
                        onTap: widget.onViewAllActivity,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ur ? 'سب دیکھیں' : 'View all',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (widget.recentActivities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        ur ? 'ابھی کوئی سرگرمی نہیں' : 'No recent activity yet',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...() {
                    final seen = <String>{};
                    final unique = widget.recentActivities.where((act) {
                      final k = '${act.title}_${act.subtitle}_${act.time}';
                      return seen.add(k);
                    }).toList();
                    return unique.map((act) => _buildActivityRow(act, isDark));
                  }(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard({
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String amount,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              amount,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String count,
    required String label,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingBarChart(CoreFlowProvider flow, bool isDark, bool ur) {
    final days = ur
        ? ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Real aggregation for each day of the week (0 = Monday .. 6 = Sunday) in _selectedMonth and _selectedOfficeId
    final weekdayTotals = List<double>.filled(7, 0.0);

    for (final item in flow.items) {
      if (item.status == 'rejected') continue;
      if (_selectedOfficeId != null && _selectedOfficeId!.isNotEmpty && _selectedOfficeId != 'all') {
        if (item.officeId != _selectedOfficeId) continue;
      }
      if (item.createdAt.year == _selectedMonth.year && item.createdAt.month == _selectedMonth.month) {
        final w = item.createdAt.weekday - 1;
        if (w >= 0 && w < 7) {
          weekdayTotals[w] += item.amount;
        }
      }
    }

    for (final r in flow.reimbursements) {
      if (r.status != 'paid') continue;
      if (_selectedOfficeId != null && _selectedOfficeId!.isNotEmpty && _selectedOfficeId != 'all') {
        if (r.officeId != _selectedOfficeId) continue;
      }
      final date = r.paidAt ?? r.createdAt;
      if (date.year == _selectedMonth.year && date.month == _selectedMonth.month) {
        final w = date.weekday - 1;
        if (w >= 0 && w < 7) {
          weekdayTotals[w] += r.amount;
        }
      }
    }

    final totalSpent = weekdayTotals.fold<double>(0.0, (s, v) => s + v);
    double maxSpent = 0.0;
    int peakIndex = -1;
    for (int i = 0; i < 7; i++) {
      if (weekdayTotals[i] > maxSpent) {
        maxSpent = weekdayTotals[i];
        peakIndex = i;
      }
    }

    final heights = List<double>.generate(7, (i) {
      if (maxSpent <= 0) return 0.08;
      final ratio = weekdayTotals[i] / maxSpent;
      return math.max(0.08, ratio);
    });

    String formatK(double val) {
      if (val <= 0) return '0';
      if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
      if (val >= 1000) return '${(val / 1000).toStringAsFixed(val >= 10000 ? 0 : 1)}k';
      return val.toInt().toString();
    }

    final amounts = weekdayTotals.map((v) => formatK(v)).toList();
    final activeDays = weekdayTotals.where((v) => v > 0).length;
    final avgPerDay = totalSpent > 0 ? (totalSpent / (activeDays > 0 ? activeDays : 7)) : 0.0;
    final avgText = totalSpent > 0
        ? (ur ? 'اوسط: PKR ${formatK(avgPerDay)}/دن' : 'Avg: PKR ${formatK(avgPerDay)}/day')
        : (ur ? 'اس ماہ کوئی خرچ نہیں' : 'PKR 0 this month');

    return Column(
      children: [
        // Top summary row inside chart
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ur ? 'ہفتہ وار اخراجات کا رجحان' : 'Weekly Trend',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  avgText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 145,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final isPeak = index == peakIndex && weekdayTotals[index] > 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Peak tag on top of highest bar
                      if (isPeak)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            amounts[index],
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 17),
                      // Bar with background track
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                // Background pill track
                                Container(
                                  width: 14,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF334155).withValues(alpha: 0.5)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                // Purple gradient bar
                                Container(
                                  width: 14,
                                  height: constraints.maxHeight * heights[index],
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isPeak
                                          ? const [Color(0xFF8B5CF6), Color(0xFF6D28D9)]
                                          : [
                                              const Color(0xFFA78BFA).withValues(alpha: 0.8),
                                              const Color(0xFF7C3AED).withValues(alpha: 0.9),
                                            ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: isPeak
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Day label
                      Text(
                        days[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                          color: isPeak
                              ? const Color(0xFF7C3AED)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRow(RecentActivityItem act, [bool isDark = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: act.iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(act.icon, color: act.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  act.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    act.time,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: act.statusDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openBranchPicker(BuildContext context, List<OfficeRecord> offices) {
    final ur = context.read<LanguageProvider>().isRtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  ur ? 'برانچ منتخب کریں' : 'Select Branch',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : null),
              ListTile(
                leading: const Icon(Icons.corporate_fare_rounded, color: Color(0xFF7C3AED)),
                title: Text(
                  ur ? 'تمام برانچز' : 'All Branches',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                trailing: _selectedOfficeId == null ? const Icon(Icons.check, color: Color(0xFF7C3AED)) : null,
                onTap: () {
                  setState(() => _selectedOfficeId = null);
                  widget.onOfficeChanged?.call(null);
                  Navigator.pop(ctx);
                },
              ),
              ...offices.map((office) {
                final isSel = _selectedOfficeId == office.id;
                return ListTile(
                  leading: Icon(Icons.business_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  title: Text(
                    office.name,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  trailing: isSel ? const Icon(Icons.check, color: Color(0xFF7C3AED)) : null,
                  onTap: () {
                    setState(() => _selectedOfficeId = office.id);
                    widget.onOfficeChanged?.call(office.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openDateRangePicker(BuildContext context) {
    final ur = context.read<LanguageProvider>().isRtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime tempStart = _startDate ?? DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    DateTime tempEnd = _endDate ?? DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      ur ? 'تاریخ کا دورانیہ منتخب کریں' : 'Select Date Range',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ur ? 'شروع اور اختتام کی تاریخ منتخب کریں' : 'Choose From and To dates to filter records',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Separate Calendars Pickers Row
                    Row(
                      children: [
                        // FROM CALENDAR
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                helpText: ur ? 'شروع کی تاریخ' : 'Select From Date',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = tempStart;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF7C3AED)),
                                      const SizedBox(width: 6),
                                      Text(
                                        ur ? 'شروع (From)' : 'From Date',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF7C3AED),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(tempStart),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('EEEE').format(tempStart),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // TO CALENDAR
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd.isBefore(tempStart) ? tempStart : tempEnd,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                helpText: ur ? 'اختتام کی تاریخ' : 'Select To Date',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempEnd = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempStart = tempEnd;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.event_busy_rounded, size: 16, color: Color(0xFF0D9488)),
                                      const SizedBox(width: 6),
                                      Text(
                                        ur ? 'اختتام (To)' : 'To Date',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0D9488),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(tempEnd),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('EEEE').format(tempEnd),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip(
                          label: ur ? 'آج' : 'Today',
                          onTap: () {
                            final now = DateTime.now();
                            setModalState(() {
                              tempStart = DateTime(now.year, now.month, now.day);
                              tempEnd = DateTime(now.year, now.month, now.day);
                            });
                          },
                          isDark: isDark,
                        ),
                        _buildPresetChip(
                          label: ur ? 'یہ مہینہ' : 'This Month',
                          onTap: () {
                            final now = DateTime.now();
                            setModalState(() {
                              tempStart = DateTime(now.year, now.month, 1);
                              tempEnd = DateTime(now.year, now.month + 1, 0);
                            });
                          },
                          isDark: isDark,
                        ),
                        _buildPresetChip(
                          label: ur ? 'پچھلا مہینہ' : 'Last Month',
                          onTap: () {
                            final now = DateTime.now();
                            setModalState(() {
                              tempStart = DateTime(now.year, now.month - 1, 1);
                              tempEnd = DateTime(now.year, now.month, 0);
                            });
                          },
                          isDark: isDark,
                        ),
                        _buildPresetChip(
                          label: ur ? 'پچھلے 30 دن' : 'Last 30 Days',
                          onTap: () {
                            final now = DateTime.now();
                            setModalState(() {
                              tempStart = now.subtract(const Duration(days: 30));
                              tempEnd = now;
                            });
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Apply button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _startDate = tempStart;
                          _endDate = tempEnd;
                          _selectedMonth = DateTime(tempStart.year, tempStart.month);
                        });
                        widget.onDateRangeChanged?.call(tempStart, tempEnd);
                        widget.onMonthChanged?.call(_selectedMonth);
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        ur ? 'فلٹر لاگو کریں' : 'Apply Date Range',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
