import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/core_flow_models.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_flow_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/receipt_viewer_dialog.dart';
import '../../widgets/modern_dashboard_view.dart';
import '../../widgets/app_toast.dart';
import 'core_entry_dialog.dart';

const _blue = Color(0xFF3159E8);
const _navy = Color(0xFF14223D);
const _teal = Color(0xFF087F8C);
const _surface = Color(0xFFF5F8FC);

String _label(BuildContext context, String english, String urdu) =>
    context.watch<LanguageProvider>().isRtl ? urdu : english;
String _readLabel(BuildContext context, String english, String urdu) =>
    context.read<LanguageProvider>().isRtl ? urdu : english;
String _money(BuildContext context, num value) =>
    context.read<LanguageProvider>().money(value.toDouble());
String _date(DateTime value) => DateFormat('d MMM yyyy').format(value);
String _person(BuildContext context, String id) {
  for (final user in context.watch<UserProvider>().allUsers) {
    if (user.uid == id) return user.name;
  }
  return id.length > 8 ? id.substring(0, 8) : id;
}

String _office(BuildContext context, String id) {
  for (final office in context.watch<CoreFlowProvider>().offices) {
    if (office.id == id) return office.name;
  }
  return '';
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE1E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x0C1C355B),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isRecipient;
  const _StatusChip(this.status, {this.isRecipient = false});
  @override
  Widget build(BuildContext context) =>
      AppStatusBadge(status: status, isCompact: true, isRecipient: isRecipient);
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? badge;
  final Color? badgeColor;
  const _Metric(this.label, this.value, this.icon, this.color, {this.badge, this.badgeColor});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (badgeColor ?? color).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: badgeColor ?? color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _navy,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF617187),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<Widget> children;
  const _MetricGrid(this.children);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final columns = size.maxWidth >= 900 ? 4 : 2;
      final gap = 12.0;
      final itemWidth = (size.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map(
              (child) => SizedBox(
                width: itemWidth,
                child: child,
              ),
            )
            .toList(),
      );
    },
  );
}

class _Empty extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  const _Empty(this.title, this.icon, {this.subtitle});
  @override
  Widget build(BuildContext context) => _Panel(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 25),
        child: Column(
          children: [
            Icon(icon, size: 38, color: const Color(0xFF8EA0B8)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF63748C),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8794A6),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class CoreDataGate extends StatelessWidget {
  final Widget child;
  const CoreDataGate({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final flow = context.watch<CoreFlowProvider>();
    if (flow.isLoading) return const Center(child: CircularProgressIndicator());
    if (flow.error != null && flow.offices.isEmpty && flow.advances.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 10),
                Text(
                  context.read<LanguageProvider>().error(flow.error!),
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  onPressed: flow.refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(_label(context, 'Try again', 'دوبارہ کوشش کریں')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return child;
  }
}

Future<void> _openEntry(
  BuildContext context,
  String mode, [
  CoreAdvance? advance,
]) async {
  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CoreEntryDialog(mode: mode, advance: advance),
  );
  if (res == true && context.mounted) {
    final msg = switch (mode) {
      'advance' => _label(context, 'Advance request submitted successfully!', 'ایڈوانس کی درخواست کامیابی سے جمع ہو گئی!'),
      'item' => _label(context, 'Purchase recorded successfully!', 'خریداری کامیابی سے درج کر دی گئی!'),
      'reimbursement' => _label(context, 'Reimbursement claim submitted successfully!', 'رقم واپسی کا کلیم کامیابی سے جمع ہو گیا!'),
      'direct_advance' => _label(context, 'Advance allotted to Office Boy successfully!', 'آفس بوائے کو ایڈوانس جاری کر دیا گیا!'),
      _ => _label(context, 'Record added successfully!', 'ریکارڈ کامیابی سے شامل ہو گیا!'),
    };
    showAppToast(context, message: msg, type: ToastType.success);
  }
}

class OfficeBoyHome extends StatefulWidget {
  final VoidCallback onRecords;
  const OfficeBoyHome({super.key, required this.onRecords});

  @override
  State<OfficeBoyHome> createState() => _OfficeBoyHomeState();
}

class _OfficeBoyHomeState extends State<OfficeBoyHome> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _startDate;
  DateTime? _endDate;

  bool _inRange(DateTime? date) {
    if (date == null) return false;
    if (_startDate != null && _endDate != null) {
      final d = DateTime(date.year, date.month, date.day);
      final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      return !d.isBefore(s) && !d.isAfter(e);
    }
    return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final uid = context.watch<AuthProvider>().currentUser?.uid ?? '';
        final ur = context.watch<LanguageProvider>().isRtl;

        final myAdvances = flow.advances
            .where((a) =>
                a.officeBoyId == uid &&
                (a.status == 'cleared' || a.status == 'fully_utilized') &&
                _inRange(a.clearedAt ?? a.createdAt))
            .toList();
        final myItems = flow.items
            .where((i) =>
                (i.officeBoyId == uid || myAdvances.any((a) => a.id == i.advanceId)) &&
                _inRange(i.createdAt))
            .toList();

        // Only approved purchases reduce the available advance balance
        final approvedItems = myItems.where((i) => i.status == 'approved').toList();
        final pendingItems = myItems.where((i) => i.status == 'pending').toList();
        final approvedSpent = approvedItems.fold<double>(0, (s, i) => s + i.amount);
        final pendingItemAmount = pendingItems.fold<double>(0, (s, i) => s + i.amount);
        final monthAdvanceTotal = myAdvances.fold<double>(0, (s, a) => s + a.amount);

        final pendingAdvances = flow.advances
            .where((a) =>
                a.officeBoyId == uid &&
                (a.status == 'pending' || a.status == 'awaiting_office_boy_approval') &&
                _inRange(a.createdAt))
            .toList();
        final pendingReimbursements = flow.reimbursements
            .where((r) => r.officeBoyId == uid && r.status == 'pending' && _inRange(r.createdAt))
            .toList();

        final pending = pendingAdvances.length + pendingReimbursements.length + pendingItems.length;
        final onHoldAmount = pendingAdvances.fold<double>(0, (s, a) => s + a.amount) +
            pendingReimbursements.fold<double>(0, (s, r) => s + r.amount) +
            pendingItemAmount;

        final heroAmount = monthAdvanceTotal;
        final available = (monthAdvanceTotal - approvedSpent).clamp(0.0, double.infinity);

        // Deduplicate recent activities
        final recentList = <RecentActivityItem>[];
        final seenIds = <String>{};
        for (final item in myItems.take(5)) {
          if (!seenIds.add('item_${item.id}')) continue;
          recentList.add(RecentActivityItem(
            icon: Icons.receipt_rounded,
            iconColor: const Color(0xFF1E60FF),
            iconBgColor: const Color(0xFFEFF6FF),
            title: item.description,
            subtitle: 'PKR ${item.amount.toInt()} · ${_office(context, item.advanceId)}',
            time: DateFormat('d MMM').format(item.createdAt),
            statusDotColor: item.status == 'approved'
                ? const Color(0xFF10B981)
                : (item.status == 'rejected' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
          ));
        }
        final allMyRecentAdvances = flow.advances
            .where((a) => a.officeBoyId == uid && _inRange(a.createdAt))
            .toList();
        for (final adv in allMyRecentAdvances.take(5)) {
          if (!seenIds.add('adv_${adv.id}')) continue;
          recentList.add(RecentActivityItem(
            icon: Icons.wallet_rounded,
            iconColor: const Color(0xFF0D9488),
            iconBgColor: const Color(0xFFF0FDFA),
            title: adv.purpose,
            subtitle: 'PKR ${adv.amount.toInt()} · ${adv.status}',
            time: DateFormat('d MMM').format(adv.createdAt),
            statusDotColor: (adv.status == 'cleared' || adv.status == 'fully_utilized')
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
          ));
        }

        // Prominent Request Advance & Reimbursement Claim Action Buttons
        final actionHeader = Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _openEntry(context, 'advance'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_card_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ur ? 'ایڈوانس کی درخواست' : 'Request Advance',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => _openEntry(context, 'reimbursement'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ur ? 'رقم واپسی (کلیم)' : 'Reimbursement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

        return ModernDashboardView(
          showBranchFilter: false,
          actionHeader: actionHeader,
          roleBadgeText: ur ? 'فیلڈ اسٹاف' : 'Staff Wallet',
          heroTitle: ur ? 'کل ایڈوانس بیلنس' : 'Total Advance Balance',
          heroAmount: heroAmount,
          availableAmount: available,
          onHoldAmount: onHoldAmount,
          spentAmount: approvedSpent,
          metric1Count: myAdvances.length,
          metric1Label: ur ? 'ایڈوانسز' : 'Advances',
          metric1Icon: Icons.account_balance_wallet_rounded,
          metric2Count: pending,
          metric2Label: ur ? 'زیر التوا' : 'Pending',
          metric2Icon: Icons.hourglass_top_rounded,
          metric3Count: myItems.length,
          metric3Label: ur ? 'رسیدیں' : 'Receipts',
          metric3Icon: Icons.receipt_long_rounded,
          quickActions: [
            QuickActionData(
              icon: Icons.add_card_rounded,
              title: ur ? 'ایڈوانس' : 'Advance',
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
              onTap: () => _openEntry(context, 'advance'),
            ),
            QuickActionData(
              icon: Icons.receipt_long_rounded,
              title: ur ? 'واپسی' : 'Claim',
              color: const Color(0xFF0D9488),
              bgColor: const Color(0xFFF0FDFA),
              onTap: () => _openEntry(context, 'reimbursement'),
            ),
            QuickActionData(
              icon: Icons.receipt_rounded,
              title: ur ? 'خریداری' : 'Receipt',
              color: const Color(0xFF1E60FF),
              bgColor: const Color(0xFFEFF6FF),
              onTap: () => _openEntry(context, 'item'),
            ),
          ],
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
      },
    ),
  );
}

class CoreAdvanceCard extends StatelessWidget {
  final CoreAdvance advance;
  final bool showOwner;
  const CoreAdvanceCard({
    super.key,
    required this.advance,
    this.showOwner = true,
  });
  @override
  Widget build(BuildContext context) {
    final flow = context.watch<CoreFlowProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final isManager = user?.isManager == true;
    final role = user?.role;
    final balance = flow.balanceForAdvance(advance.id);
    final items = flow.items
        .where((i) =>
            i.advanceId == advance.id &&
            (!isManager || i.taggedManagerId == user?.uid))
        .toList();
    final approvedItems = items.where((i) => i.status == 'approved').toList();
    final cardSpent = approvedItems.fold<double>(0.0, (s, i) => s + i.amount);
    final displaySpent = isManager ? cardSpent : (balance?.spent ?? cardSpent);
    final displayLeft = isManager
        ? (advance.amount - cardSpent).clamp(0.0, double.infinity)
        : (balance?.remaining ?? (advance.amount - cardSpent).clamp(0.0, double.infinity));
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Highlighted Header Badge ("Pani", "I want Money", etc.)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.label_important_rounded,
                  size: 16,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    advance.purpose.isNotEmpty ? advance.purpose : _label(context, 'Advance', 'ایڈوانس'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _StatusChip(advance.status, isRecipient: !showOwner),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_outlined, size: 15, color: _blue),
                  const SizedBox(width: 4),
                  Text(
                    _money(context, advance.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(_date(advance.createdAt)),
                ],
              ),
            ],
          ),
          if (showOwner)
            Text(
              '${_person(context, advance.officeBoyId)} · ${_office(context, advance.officeId)}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          const SizedBox(height: 8),
          Text(
            '${_label(context, 'Requested', 'مانگا گیا')}: ${advance.method == 'card' ? _label(context, 'Card', 'کارڈ') : _label(context, 'Cash', 'نقد')}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          if (advance.financeNote != null && advance.financeNote!.isNotEmpty)
            Text(
              '${_label(context, 'Finance note', 'فنانس کا نوٹ')}: ${advance.financeNote}',
            ),
          if (advance.method == 'card')
            _CopyAccount(
              name: advance.accountName,
              details: advance.accountDetails,
            ),
          if (balance != null || isManager) ...[
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_label(context, 'Spent', 'خرچ')}: ${_money(context, displaySpent)}',
                  ),
                ),
                Flexible(
                  child: Text(
                    '${_label(context, 'Left', 'باقی')}: ${_money(context, displayLeft)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: advance.amount > 0
                  ? (displaySpent / advance.amount).clamp(0, 1)
                  : 0,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              color: _teal,
              backgroundColor: const Color(0xFFE5EBF3),
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                _label(
                  context,
                  'Purchases (${items.length})',
                  'خریداری (${items.length})',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(item.description),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_date(item.createdAt)),
                          if (item.taggedManagerId != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_label(context, 'Manager', 'منیجر')}: ${_person(context, item.taggedManagerId!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF3159E8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (item.status == 'rejected' && item.rejectionReason != null && item.rejectionReason!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${_label(context, 'Reason:', 'وجہ:')} ${item.rejectionReason}',
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _StatusChip(item.status),
                          ),
                          item.billPath == null
                              ? Text(_money(context, item.amount))
                              : IconButton(
                                  tooltip: _label(
                                    context,
                                    'View bill',
                                    'بل دیکھیں',
                                  ),
                                  icon: const Icon(Icons.receipt_long),
                                  onPressed: () => ReceiptViewerDialog.show(
                                    context,
                                    imageUrl: item.billPath!,
                                  ),
                                ),
                          if (role == UserRole.finance && item.status == 'pending') ...[
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: flow.isBusy(item.id) ? null : () async {
                                final ok = await flow.reviewAdvanceItem(item.id, 'approve', null);
                                if (context.mounted) {
                                  if (ok) {
                                    showAppToast(
                                      context,
                                      message: _label(context, 'Purchase approved!', 'خریداری منظور ہو گئی!'),
                                      type: ToastType.success,
                                    );
                                  } else {
                                    _showError(context, flow.error);
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: flow.isBusy(item.id) ? null : () async {
                                final reasonController = TextEditingController();
                                final reason = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(_label(context, 'Reject Reason', 'مسترد کرنے کی وجہ')),
                                    content: TextField(
                                      controller: reasonController,
                                      decoration: InputDecoration(
                                        hintText: _label(context, 'Enter reason', 'وجہ درج کریں'),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(_label(context, 'Cancel', 'منسوخ کریں')),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, reasonController.text),
                                        child: Text(_label(context, 'Submit', 'جمع کریں')),
                                      ),
                                    ],
                                  ),
                                );
                                if (reason != null && reason.trim().isNotEmpty) {
                                  final ok = await flow.reviewAdvanceItem(item.id, 'reject', reason);
                                  if (context.mounted) {
                                    if (ok) {
                                      showAppToast(
                                        context,
                                        message: _label(context, 'Purchase rejected', 'خریداری مسترد کر دی گئی'),
                                        type: ToastType.warning,
                                      );
                                    } else {
                                      _showError(context, flow.error);
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (role == UserRole.officeBoy && advance.status == 'cleared') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openEntry(context, 'item', advance),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  _label(context, 'Add Purchase', 'خریداری درج کریں'),
                ),
              ),
            ),
          ],
          if (role == UserRole.officeBoy && advance.status == 'awaiting_office_boy_approval') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: flow.isBusy(advance.id)
                        ? null
                        : () async {
                            final ok = await flow.respondToDirectAdvance(advance.id, 'decline');
                            if (context.mounted) {
                              if (ok) {
                                showAppToast(
                                  context,
                                  message: _label(context, 'Advance declined', 'ایڈوانس مسترد کر دیا گیا'),
                                  type: ToastType.warning,
                                );
                              } else {
                                showAppToast(
                                  context,
                                  message: flow.error ?? _label(context, 'Failed to decline', 'مسترد کرنے میں ناکامی'),
                                  type: ToastType.error,
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: Text(
                      _label(context, 'Decline', 'مسترد کریں'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: flow.isBusy(advance.id)
                        ? null
                        : () async {
                            final ok = await flow.respondToDirectAdvance(advance.id, 'approve');
                            if (context.mounted) {
                              if (ok) {
                                showAppToast(
                                  context,
                                  message: _label(context, 'Advance approved and added to balance!', 'ایڈوانس منظور ہو گیا اور آپ کے بیلنس میں شامل کر دیا گیا!'),
                                  type: ToastType.success,
                                );
                              } else {
                                showAppToast(
                                  context,
                                  message: flow.error ?? _label(context, 'Failed to approve', 'منظور کرنے میں ناکامی'),
                                  type: ToastType.error,
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.check),
                    label: Text(
                      _label(context, 'Approve', 'منظور کریں'),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (role == UserRole.finance && advance.status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: flow.isBusy(advance.id)
                    ? null
                    : () => _clearAdvance(context, advance),
                icon: const Icon(Icons.done_all),
                label: Text(
                  advance.method == 'cash'
                      ? _label(context, 'Cash Given', 'نقد رقم دے دی')
                      : _label(context, 'Mark as Sent', 'رقم بھیج دی'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CopyAccount extends StatelessWidget {
  final String? name, details;
  const _CopyAccount({this.name, this.details});
  @override
  Widget build(BuildContext context) {
    if ((name ?? '').isEmpty && (details ?? '').isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFD6E4FF),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              '${name ?? ''}${name != null && details != null ? '\n' : ''}${details ?? ''}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            tooltip: _label(
              context,
              'Copy account details',
              'اکاؤنٹ کی تفصیل کاپی کریں',
            ),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: '${name ?? ''}\n${details ?? ''}'.trim()),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _label(
                        context,
                        'Account details copied',
                        'اکاؤنٹ کی تفصیل کاپی ہو گئی',
                      ),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}

Future<void> _clearAdvance(BuildContext context, CoreAdvance advance) async {
  final flow = context.read<CoreFlowProvider>();
  final ok = await flow.clearAdvance(
    advance.id,
    advance.method,
    null,
  );
  if (context.mounted) {
    if (ok) {
      showAppToast(
        context,
        message: _label(context, 'Advance cleared and funds marked as sent!', 'ایڈوانس جاری کر دیا گیا اور رقم بھیج دی گئی!'),
        type: ToastType.success,
      );
    } else {
      _showError(context, flow.error);
    }
  }
}

void _showError(BuildContext context, String? error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        context.read<LanguageProvider>().error(error ?? 'Please try again.'),
      ),
    ),
  );
}

class CoreReimbursementCard extends StatelessWidget {
  final CoreReimbursement request;
  final bool showOwner;
  const CoreReimbursementCard({
    super.key,
    required this.request,
    this.showOwner = true,
  });
  @override
  Widget build(BuildContext context) {
    final flow = context.watch<CoreFlowProvider>();
    final finance =
        context.watch<AuthProvider>().currentUser?.role == UserRole.finance;
    final timeline = flow.activity
        .where((a) => a.reimbursementId == request.id)
        .toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Highlighted Header Badge ("Pani", "I want Money", etc.)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.label_important_rounded,
                  size: 16,
                  color: Color(0xFF0D9488),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.description.isNotEmpty ? request.description : _label(context, 'Reimbursement', 'واپسی'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _StatusChip(request.status),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_outlined, size: 15, color: _teal),
                  const SizedBox(width: 4),
                  Text(
                    _money(context, request.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(_date(request.createdAt)),
                ],
              ),
            ],
          ),
          if (showOwner)
            Text(
              '${_person(context, request.officeBoyId)} · ${_office(context, request.officeId)}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          if (request.taggedManagerId != null)
            Text(
              '${_label(context, 'Manager', 'منیجر')}: ${_person(context, request.taggedManagerId!)}',
              style: const TextStyle(
                color: Color(0xFF3159E8),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          Text(
            '${_label(context, 'Wants', 'چاہیے')}: ${request.wantedMethod == 'card' ? _label(context, 'Card', 'کارڈ') : _label(context, 'Cash', 'نقد')}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          if (request.wantedMethod == 'card')
            _CopyAccount(
              name: request.accountName,
              details: request.accountDetails,
            ),
          if (request.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_label(context, 'Reason', 'وجہ')}: ${request.rejectionReason}',
                style: const TextStyle(
                  color: Color(0xFFC23F42),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (request.paidMethod != null)
            Text(
              '${_label(context, 'Paid by', 'ادا کیا')}: ${request.paidMethod == 'cash' ? _label(context, 'Cash', 'نقد') : _label(context, 'Card', 'کارڈ')}',
            ),
          if (request.billPath != null)
            TextButton.icon(
              onPressed: () => ReceiptViewerDialog.show(
                context,
                imageUrl: request.billPath!,
              ),
              icon: const Icon(Icons.receipt_long),
              label: Text(_label(context, 'View bill', 'بل دیکھیں')),
            ),
          if (timeline.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                _label(context, 'History', 'مکمل ریکارڈ'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: timeline
                  .map(
                    (a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline, size: 18),
                      title: Text(_activityLabel(context, a.action)),
                      subtitle: Text(
                        '${_date(a.createdAt)} · ${_person(context, a.actorId)}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (finance && request.status == 'pending') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                 FilledButton.icon(
                  onPressed: flow.isBusy(request.id)
                      ? null
                      : () async {
                          final ok = await flow.reviewReimbursement(
                            request.id,
                            'approve',
                            null,
                          );
                          if (context.mounted) {
                            if (ok) {
                              showAppToast(
                                context,
                                message: _label(context, 'Reimbursement claim approved!', 'رقم واپسی کا کلیم منظور کر لیا گیا!'),
                                type: ToastType.success,
                              );
                            } else {
                              _showError(context, flow.error);
                            }
                          }
                        },
                  icon: const Icon(Icons.check),
                  label: Text(_label(context, 'Approve', 'منظور کریں')),
                ),
                OutlinedButton.icon(
                  onPressed: flow.isBusy(request.id)
                      ? null
                      : () => _reject(context, request),
                  icon: const Icon(Icons.close),
                  label: Text(_label(context, 'Reject', 'مسترد کریں')),
                ),
              ],
            ),
          ],
          if (finance && request.status == 'approved') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: flow.isBusy(request.id)
                    ? null
                    : () => _markPaid(context, request),
                icon: const Icon(Icons.payments_outlined),
                label: Text(_label(context, 'Mark Paid', 'ادائیگی درج کریں')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _activityLabel(BuildContext context, String action) => switch (action) {
  'requested' => _label(context, 'Request sent', 'درخواست بھیجی گئی'),
  'cleared' => _label(context, 'Money sent', 'رقم دے دی گئی'),
  'item_added' => _label(context, 'Purchase added', 'خریداری درج ہوئی'),
  'approve' => _label(context, 'Approved', 'منظور ہوئی'),
  'reject' => _label(context, 'Rejected', 'مسترد ہوئی'),
  'paid' => _label(context, 'Paid', 'ادا کر دیا'),
  _ => action,
};

Future<void> _reject(BuildContext context, CoreReimbursement request) async {
  final controller = TextEditingController();
  final key = GlobalKey<FormState>();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        _label(
          context,
          'Why reject this request?',
          'یہ درخواست کیوں مسترد کر رہے ہیں؟',
        ),
      ),
      content: Form(
        key: key,
        child: TextFormField(
          controller: controller,
          maxLines: 3,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: _label(
              context,
              'Reason for Office Boy',
              'آفس بوائے کے لیے وجہ',
            ),
          ),
          validator: (value) => value?.trim().isEmpty ?? true
              ? _label(
                  context,
                  'Please write a reason.',
                  'براہِ کرم وجہ لکھیں۔',
                )
              : null,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_label(context, 'Cancel', 'منسوخ کریں')),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: Text(_label(context, 'Reject', 'مسترد کریں')),
            ),
          ],
        ),
      ],
    ),
  );
  controller.dispose();
  if (reason == null || !context.mounted) return;
  final flow = context.read<CoreFlowProvider>();
  final ok = await flow.reviewReimbursement(request.id, 'reject', reason);
  if (context.mounted) {
    if (ok) {
      showAppToast(
        context,
        message: _label(context, 'Reimbursement claim rejected', 'رقم واپسی کا کلیم مسترد کر دیا گیا'),
        type: ToastType.warning,
      );
    } else {
      _showError(context, flow.error);
    }
  }
}

Future<void> _markPaid(BuildContext context, CoreReimbursement request) async {
  final flow = context.read<CoreFlowProvider>();
  final ok = await flow.markReimbursementPaid(request.id, request.wantedMethod);
  if (context.mounted) {
    if (ok) {
      showAppToast(
        context,
        message: _label(context, 'Payment marked as completed!', 'ادائیگی کامیابی سے درج کر دی گئی!'),
        type: ToastType.success,
      );
    } else {
      _showError(context, flow.error);
    }
  }
}

class CoreRecordsScreen extends StatelessWidget {
  final bool finance;
  const CoreRecordsScreen({super.key, this.finance = false});
  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final uid = context.watch<AuthProvider>().currentUser?.uid;
        final advances = finance
            ? flow.advances
            : flow.advances.where((a) => a.officeBoyId == uid).toList();
        final repayments = finance
            ? flow.reimbursements
            : flow.reimbursements.where((a) => a.officeBoyId == uid).toList();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Material(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: TabBar(
                  indicatorColor: const Color(0xFF7C3AED),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF7C3AED),
                  unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: _label(context, 'Advances', 'ایڈوانس')),
                    Tab(text: _label(context, 'Own money', 'اپنی رقم')),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _RecordList<CoreAdvance>(
                      records: advances,
                      empty: _label(
                        context,
                        'No advances yet',
                        'ابھی کوئی ایڈوانس نہیں',
                      ),
                      card: (a) =>
                          CoreAdvanceCard(advance: a, showOwner: finance),
                    ),
                    _RecordList<CoreReimbursement>(
                      records: repayments,
                      empty: _label(
                        context,
                        'No repayment requests yet',
                        'ابھی واپسی کی درخواست نہیں',
                      ),
                      card: (r) =>
                          CoreReimbursementCard(request: r, showOwner: finance),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _RecordList<T> extends StatelessWidget {
  final List<T> records;
  final String empty;
  final Widget Function(T) card;
  const _RecordList({
    required this.records,
    required this.empty,
    required this.card,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0F19) : _surface;
    return records.isEmpty
        ? ColoredBox(
            color: bg,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _Empty(
                  empty,
                  Icons.inbox_outlined,
                  subtitle: _label(
                    context,
                    'New records will show here.',
                    'نیا ریکارڈ یہاں نظر آئے گا۔',
                  ),
                ),
              ),
            ),
          )
        : ColoredBox(
            color: bg,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: card(records[index]),
              ),
            ),
          );
  }
}

class FinanceHome extends StatefulWidget {
  final VoidCallback onAdvances, onReimbursements;
  const FinanceHome({
    super.key,
    required this.onAdvances,
    required this.onReimbursements,
  });

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedOfficeId;

  bool _inMonth(DateTime? date) {
    if (date == null) return false;
    return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final ur = context.watch<LanguageProvider>().isRtl;

        final monthAdvancesList = flow.advances.where((a) => 
            (_selectedOfficeId == null || a.officeId == _selectedOfficeId) &&
            (a.status == 'cleared' || a.status == 'fully_utilized') &&
            _inMonth(a.clearedAt ?? a.createdAt)
        ).toList();
        final monthAdvances = monthAdvancesList.fold<double>(0, (s, a) => s + a.amount);

        final monthItemsList = flow.items.where((i) =>
            (_selectedOfficeId == null || i.officeId == _selectedOfficeId) &&
            i.status != 'rejected' &&
            _inMonth(i.createdAt)
        ).toList();
        final monthItemSpent = monthItemsList.fold<double>(0, (s, i) => s + i.amount);

        final monthPaidList = flow.reimbursements.where((r) =>
            (_selectedOfficeId == null || r.officeId == _selectedOfficeId) &&
            r.status == 'paid' &&
            _inMonth(r.paidAt ?? r.createdAt)
        ).toList();
        final monthPaid = monthPaidList.fold<double>(0, (s, r) => s + r.amount);
        final totalSpent = monthItemSpent + monthPaid;

        final monthPendingAdvances = flow.advances.where((a) =>
            (_selectedOfficeId == null || a.officeId == _selectedOfficeId) &&
            (a.status == 'pending' || a.status == 'awaiting_office_boy_approval') &&
            _inMonth(a.createdAt)
        ).toList();
        final monthPendingRepayments = flow.reimbursements.where((r) =>
            (_selectedOfficeId == null || r.officeId == _selectedOfficeId) &&
            (r.status == 'pending' || r.status == 'approved') &&
            _inMonth(r.createdAt)
        ).toList();

        final onHoldAmount = monthPendingAdvances.fold<double>(0, (s, a) => s + a.amount) +
            monthPendingRepayments.fold<double>(0, (s, r) => s + r.amount);

        final monthAvailable = flow.balances.where((b) {
          return monthAdvancesList.any((a) => a.id == b.advanceId);
        }).fold<double>(0, (s, b) => s + b.remaining);

        final heroAmount = monthAdvances;
        final availableAmount = monthAdvances > 0 ? monthAvailable : 0.0;

        final recentList = <RecentActivityItem>[];
        final seenIds = <String>{};
        for (final a in monthAdvancesList.take(5)) {
          if (!seenIds.add('adv_${a.id}')) continue;
          recentList.add(RecentActivityItem(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF1E60FF),
            iconBgColor: const Color(0xFFEFF6FF),
            title: a.purpose.isNotEmpty ? a.purpose : (ur ? 'ایڈوانس جاری' : 'Advance issued'),
            subtitle: 'PKR ${a.amount.toInt()} · ${_person(context, a.officeBoyId)}',
            time: DateFormat('d MMM').format(a.createdAt),
            statusDotColor: const Color(0xFF10B981),
          ));
        }
        for (final r in monthPendingRepayments.take(4)) {
          if (!seenIds.add('repay_${r.id}')) continue;
          recentList.add(RecentActivityItem(
            icon: Icons.receipt_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: const Color(0xFFFFFBEB),
            title: r.description.isNotEmpty ? r.description : (ur ? 'واپسی زیر التوا' : 'Repayment pending'),
            subtitle: 'PKR ${r.amount.toInt()} · ${_person(context, r.officeBoyId)}',
            time: DateFormat('d MMM').format(r.createdAt),
            statusDotColor: const Color(0xFFF59E0B),
          ));
        }

        return ModernDashboardView(
          roleBadgeText: ur ? 'فنانس' : 'Finance Manager',
          heroTitle: ur ? 'جاری کردہ فلوٹ' : 'Total Disbursed Float',
          heroAmount: heroAmount,
          availableAmount: availableAmount,
          onHoldAmount: onHoldAmount,
          spentAmount: totalSpent,
          metric1Count: monthPendingAdvances.length,
          metric1Label: ur ? 'ایڈوانس زیر التوا' : 'Adv. Waiting',
          metric1Icon: Icons.wallet_rounded,
          metric2Count: monthPendingRepayments.length,
          metric2Label: ur ? 'واپسی زیر التوا' : 'Repay Waiting',
          metric2Icon: Icons.shopping_bag_rounded,
          metric3Count: flow.offices.length,
          metric3Label: ur ? 'دفاتر' : 'Offices',
          metric3Icon: Icons.business_rounded,
          recentActivities: recentList,
          onViewReport: widget.onAdvances,
          onViewAllActivity: widget.onAdvances,
          initialOfficeId: _selectedOfficeId,
          initialMonth: _selectedMonth,
          onOfficeChanged: (id) => setState(() => _selectedOfficeId = id),
          onMonthChanged: (m) => setState(() => _selectedMonth = m),
        );
      },
    ),
  );
}

class FinanceQueue extends StatelessWidget {
  final bool advances;
  const FinanceQueue({super.key, required this.advances});
  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        if (advances) {
          final rows = flow.advances
              .where((a) => a.status == 'pending' || a.status == 'awaiting_office_boy_approval')
              .toList();
          return _RecordList<CoreAdvance>(
            records: rows,
            empty: _label(
              context,
              'No advance requests waiting',
              'ایڈوانس کی کوئی درخواست باقی نہیں',
            ),
            card: (a) => CoreAdvanceCard(advance: a),
          );
        }
        final rows = flow.reimbursements
            .where((r) => r.status == 'pending' || r.status == 'approved')
            .toList();
        return _RecordList<CoreReimbursement>(
          records: rows,
          empty: _label(
            context,
            'No repayment requests waiting',
            'رقم واپسی کی کوئی درخواست باقی نہیں',
          ),
          card: (r) => CoreReimbursementCard(request: r),
        );
      },
    ),
  );
}

class FinanceBalances extends StatelessWidget {
  const FinanceBalances({super.key});
  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final ids = flow.balances.map((b) => b.officeBoyId).toSet().toList();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ColoredBox(
          color: isDark ? const Color(0xFF0B0F19) : _surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _openEntry(context, 'direct_advance'),
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(
                      _label(context, 'Give Advance', 'ایڈوانس دیں'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _RecordList<String>(
                  records: ids,
                  empty: _label(
                    context,
                    'No advance balances yet',
                    'ابھی کوئی ایڈوانس بیلنس نہیں',
                  ),
                  card: (id) {
                    final records = flow.balances
                        .where((b) => b.officeBoyId == id)
                        .toList();
                    final total = records.fold<double>(0, (s, b) => s + b.total);
                    final spent = records.fold<double>(0, (s, b) => s + b.spent);
                    return _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _person(context, id),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : _navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_label(context, 'Given', 'دیا')}: ${_money(context, total)}',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                          Text(
                            '${_label(context, 'Spent', 'خرچ')}: ${_money(context, spent)}',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                          Text(
                            '${_label(context, 'Left', 'باقی')}: ${_money(context, total - spent)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _teal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...records.map((b) {
                            final advance = flow.advances
                                .where((a) => a.id == b.advanceId)
                                .firstOrNull;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                advance?.purpose ??
                                    _label(context, 'Advance', 'ایڈوانس'),
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${b.itemCount} ${_label(context, 'purchases', 'خریداری')}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              trailing: Text(
                                _money(context, b.remaining),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class AdminCoreOverview extends StatefulWidget {
  final bool superAdmin;
  final VoidCallback onRecords;
  const AdminCoreOverview({
    super.key,
    required this.superAdmin,
    required this.onRecords,
  });

  @override
  State<AdminCoreOverview> createState() => _AdminCoreOverviewState();
}

class _AdminCoreOverviewState extends State<AdminCoreOverview> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedOfficeId;

  bool _inMonth(DateTime? date) {
    if (date == null) return false;
    return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final users = context.watch<UserProvider>().allUsers;
        final ur = context.watch<LanguageProvider>().isRtl;

        // 1. Advances disbursed/cleared in the selected month
        final monthAdvances = flow.advances.where((a) {
          final matchesOffice = _selectedOfficeId == null || a.officeId == _selectedOfficeId;
          return matchesOffice &&
              _inMonth(a.clearedAt ?? a.createdAt) &&
              (a.status == 'cleared' || a.status == 'fully_utilized');
        }).toList();

        // 2. Advance items spent in selected month
        final monthItems = flow.items.where((i) {
          final matchesOffice = _selectedOfficeId == null || i.officeId == _selectedOfficeId;
          return matchesOffice && _inMonth(i.createdAt) && i.status != 'rejected';
        }).toList();

        // 3. Paid reimbursements in selected month
        final monthPaid = flow.reimbursements.where((r) {
          final matchesOffice = _selectedOfficeId == null || r.officeId == _selectedOfficeId;
          return matchesOffice && _inMonth(r.paidAt ?? r.createdAt) && r.status == 'paid';
        }).toList();

        final advanceTotal = monthAdvances.fold<double>(0, (s, a) => s + a.amount);
        final itemSpent = monthItems.fold<double>(0, (s, i) => s + i.amount);
        final reimbursed = monthPaid.fold<double>(0, (s, r) => s + r.amount);
        final totalSpent = itemSpent + reimbursed;

        // Pending in selected month
        final monthPendingAdvances = flow.advances.where((a) {
          final matchesOffice = _selectedOfficeId == null || a.officeId == _selectedOfficeId;
          return matchesOffice &&
              (a.status == 'pending' || a.status == 'awaiting_office_boy_approval') &&
              _inMonth(a.createdAt);
        }).toList();

        final monthPendingReimbursements = flow.reimbursements.where((r) {
          final matchesOffice = _selectedOfficeId == null || r.officeId == _selectedOfficeId;
          return matchesOffice && r.status == 'pending' && _inMonth(r.createdAt);
        }).toList();

        final pendingCount = monthPendingAdvances.length + monthPendingReimbursements.length;
        final onHoldAmount = monthPendingAdvances.fold<double>(0, (s, a) => s + a.amount) +
            monthPendingReimbursements.fold<double>(0, (s, r) => s + r.amount);

        // Balances from advances belonging to this month
        final monthAvailable = flow.balances.where((b) {
          return monthAdvances.any((a) => a.id == b.advanceId);
        }).fold<double>(0, (s, b) => s + b.remaining);

        final heroAmount = advanceTotal;
        final availableAmount = advanceTotal > 0 ? monthAvailable : 0.0;

        final recentList = <RecentActivityItem>[];
        final seenIds = <String>{};
        for (final a in monthAdvances.take(5)) {
          if (!seenIds.add('adv_${a.id}')) continue;
          final isDone = a.status == 'cleared' || a.status == 'approved';
          recentList.add(RecentActivityItem(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF1E60FF),
            iconBgColor: const Color(0xFFEFF6FF),
            title: a.purpose.isNotEmpty ? a.purpose : (ur ? 'ایڈوانس' : 'Advance disbursed'),
            subtitle: 'PKR ${a.amount.toInt()} · ${_person(context, a.officeBoyId)}',
            time: DateFormat('d MMM').format(a.createdAt),
            statusDotColor: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ));
        }
        for (final r in monthPaid.take(4)) {
          if (!seenIds.add('repay_${r.id}')) continue;
          final isDone = r.status == 'paid' || r.status == 'approved';
          recentList.add(RecentActivityItem(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF0D9488),
            iconBgColor: const Color(0xFFF0FDFA),
            title: r.description.isNotEmpty ? r.description : (ur ? 'واپسی' : 'Reimbursement'),
            subtitle: 'PKR ${r.amount.toInt()} · ${_person(context, r.officeBoyId)}',
            time: DateFormat('d MMM').format(r.createdAt),
            statusDotColor: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ));
        }

        return ModernDashboardView(
          roleBadgeText: widget.superAdmin ? (ur ? 'سپر ایڈمن' : 'Super Admin') : (ur ? 'ایڈمن' : 'Branch Admin'),
          heroTitle: widget.superAdmin ? (ur ? 'کل کمپنی فلوٹ' : 'Total Company Float') : (ur ? 'برانچ فلوٹ' : 'Branch Float'),
          heroAmount: heroAmount,
          availableAmount: availableAmount,
          onHoldAmount: onHoldAmount,
          spentAmount: totalSpent,
          metric1Count: users.length,
          metric1Label: ur ? 'صارفین' : 'Users',
          metric1Icon: Icons.people_alt_rounded,
          metric2Count: flow.offices.length,
          metric2Label: ur ? 'برانچز' : 'Branches',
          metric2Icon: Icons.business_rounded,
          metric3Count: pendingCount,
          metric3Label: ur ? 'زیر التوا' : 'Pending',
          metric3Icon: Icons.description_rounded,
          recentActivities: recentList,
          onViewReport: widget.onRecords,
          onViewAllActivity: widget.onRecords,
          initialOfficeId: _selectedOfficeId,
          initialMonth: _selectedMonth,
          onOfficeChanged: (id) => setState(() => _selectedOfficeId = id),
          onMonthChanged: (m) => setState(() => _selectedMonth = m),
        );
      },
    ),
  );
}

class CoreMonthlyRecords extends StatefulWidget {
  const CoreMonthlyRecords({super.key});
  @override
  State<CoreMonthlyRecords> createState() => _CoreMonthlyRecordsState();
}

class _CoreMonthlyRecordsState extends State<CoreMonthlyRecords> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
  );
  String? _officeId, _personId, _managerId;
  String _type = 'all';

  bool _inRange(DateTime? date) {
    if (date == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(_dateRange.start.year, _dateRange.start.month, _dateRange.start.day);
    final end = DateTime(_dateRange.end.year, _dateRange.end.month, _dateRange.end.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
  Future<void> _pickSeparateDateRange(BuildContext context) async {
    final ur = context.read<LanguageProvider>().isRtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime tempStart = _dateRange.start;
    DateTime tempEnd = _dateRange.end;

    await showModalBottomSheet<void>(
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
                      ur ? 'الگ الگ تاریخ منتخب کریں' : 'Choose From and To dates',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                helpText: ur ? 'شروع کی تاریخ' : 'From Date',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) tempEnd = tempStart;
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
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd.isBefore(tempStart) ? tempStart : tempEnd,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                helpText: ur ? 'اختتام کی تاریخ' : 'To Date',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempEnd = picked;
                                  if (tempEnd.isBefore(tempStart)) tempStart = tempEnd;
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
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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
                          _dateRange = DateTimeRange(start: tempStart, end: tempEnd);
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        ur ? 'لاگو کریں' : 'Apply Range',
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

  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final currentUser = context.watch<AuthProvider>().currentUser;
        final isManager = currentUser?.isManager == true;
        final effectiveManagerId = isManager ? currentUser?.uid : _managerId;

        // For manager, only show office boys tagged to this manager
        final taggedOfficeBoyIds = flow.items
            .where((i) => i.taggedManagerId == effectiveManagerId)
            .map((i) => i.officeBoyId)
            .toSet()
          ..addAll(
            flow.reimbursements
                .where((r) => r.taggedManagerId == effectiveManagerId)
                .map((r) => r.officeBoyId),
          );

        final people = context
            .watch<UserProvider>()
            .allUsers
            .where(
              (u) =>
                  u.role == UserRole.officeBoy &&
                  (!isManager || taggedOfficeBoyIds.contains(u.uid)) &&
                  (isManager || _officeId == null || u.officeId == _officeId),
            )
            .toList();
        final managers = context.watch<UserProvider>().allUsers.where((u) => u.isManager).toList();

        final allAdvances = flow.advances
            .where(
              (a) =>
                  (isManager || _officeId == null || a.officeId == _officeId) &&
                  (_personId == null || a.officeBoyId == _personId) &&
                  (isManager
                      ? flow.items.any((i) => i.advanceId == a.id && i.taggedManagerId == effectiveManagerId)
                      : (_managerId == null ||
                          flow.items.any((i) => i.advanceId == a.id && i.taggedManagerId == _managerId))),
            )
            .toList();
        final allRepayments = flow.reimbursements
            .where(
              (r) =>
                  (isManager || _officeId == null || r.officeId == _officeId) &&
                  (_personId == null || r.officeBoyId == _personId) &&
                  (isManager
                      ? r.taggedManagerId == effectiveManagerId
                      : (_managerId == null || r.taggedManagerId == _managerId)),
            )
            .toList();
        final advances = allAdvances
            .where(
              (a) =>
                  flow.items.any(
                    (item) =>
                        item.advanceId == a.id &&
                        (!isManager || item.taggedManagerId == effectiveManagerId) &&
                        _inRange(item.createdAt),
                  ) ||
                  (!isManager && (_inRange(a.createdAt) || _inRange(a.clearedAt))),
            )
            .toList();
        final repayments = allRepayments
            .where(
              (r) =>
                  _inRange(r.createdAt) ||
                  _inRange(r.reviewedAt) ||
                  _inRange(r.paidAt),
            )
            .toList();
        final shownAdvances = _type != 'reimbursement';
        final shownRepayments = _type != 'advance';
        final totalAdvance = allAdvances
            .where((a) =>
                (a.status == 'cleared' || a.status == 'fully_utilized') &&
                _inRange(a.clearedAt ?? a.createdAt))
            .fold<double>(0, (s, a) => s + a.amount);
        final eligibleAdvanceIds = allAdvances
            .where((a) => a.status == 'cleared' || a.status == 'fully_utilized')
            .map((a) => a.id)
            .toSet();
        final utilized = flow.items
            .where(
              (item) =>
                  eligibleAdvanceIds.contains(item.advanceId) &&
                  (!isManager || item.taggedManagerId == effectiveManagerId) &&
                  item.status == 'approved' &&
                  _inRange(item.createdAt),
            )
            .fold<double>(0, (s, item) => s + item.amount);
        final reimbursed = allRepayments
            .where((r) => r.status == 'paid' && _inRange(r.paidAt ?? r.createdAt))
            .fold<double>(0, (s, r) => s + r.amount);
        final pending =
            (shownAdvances ? allAdvances : <CoreAdvance>[])
                .where((a) =>
                    (a.status == 'pending' || a.status == 'awaiting_office_boy_approval') &&
                    _inRange(a.createdAt))
                .fold<double>(0, (s, a) => s + a.amount) +
            (shownRepayments ? allRepayments : <CoreReimbursement>[])
                .where(
                  (r) =>
                      (r.status == 'pending' || r.status == 'approved') &&
                      _inRange(r.createdAt),
                )
                .fold<double>(0, (s, r) => s + r.amount);
        final rows = <Object>[
          if (shownAdvances) ...advances,
          if (shownRepayments) ...repayments,
        ];

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ColoredBox(
          color: isDark ? const Color(0xFF0B0F19) : _surface,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              if (index > 0) {
                final item = rows[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: item is CoreAdvance
                      ? CoreAdvanceCard(advance: item)
                      : CoreReimbursementCard(
                          request: item as CoreReimbursement,
                        ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Panel(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fieldWidth = constraints.maxWidth < 220
                            ? constraints.maxWidth
                            : ((constraints.maxWidth - 10) / 2).clamp(
                                0.0,
                                420.0,
                              );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickSeparateDateRange(context),
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                _dateRange.start.day == 1 &&
                                        _dateRange.start.month ==
                                            _dateRange.end.month &&
                                        _dateRange.start.year ==
                                            _dateRange.end.year &&
                                        _dateRange.end.day ==
                                            DateTime(
                                              _dateRange.start.year,
                                              _dateRange.start.month + 1,
                                              0,
                                            ).day
                                    ? DateFormat('MMMM yyyy')
                                          .format(_dateRange.start)
                                    : '${DateFormat('d MMM yy').format(_dateRange.start)} - ${DateFormat('d MMM yy').format(_dateRange.end)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (!isManager)
                                  SizedBox(
                                    width: fieldWidth,
                                    child: DropdownButtonFormField<String?>(
                                      initialValue: _officeId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: _label(
                                          context,
                                          'Office',
                                          'دفتر',
                                        ),
                                      ),
                                      items: [
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text(
                                            _label(
                                              context,
                                              'All offices',
                                              'تمام دفاتر',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        ...flow.offices.map(
                                          (o) => DropdownMenuItem<String?>(
                                            value: o.id,
                                            child: Text(
                                              o.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) => setState(() {
                                        _officeId = v;
                                        _personId = null;
                                      }),
                                    ),
                                  ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: _personId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: _label(
                                        context,
                                        'Office Boy',
                                        'آفس بوائے',
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          _label(
                                            context,
                                            'All people',
                                            'تمام لوگ',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      ...people.map(
                                        (u) => DropdownMenuItem<String?>(
                                          value: u.uid,
                                          child: Text(
                                            u.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _personId = v),
                                  ),
                                ),
                                if (!isManager)
                                  SizedBox(
                                    width: fieldWidth,
                                    child: DropdownButtonFormField<String?>(
                                      initialValue: _managerId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: _label(
                                          context,
                                          'Manager',
                                          'مینیجر',
                                        ),
                                      ),
                                      items: [
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text(
                                            _label(
                                              context,
                                              'All Managers',
                                              'تمام مینیجرز',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        ...managers.map(
                                          (m) => DropdownMenuItem<String?>(
                                            value: m.uid,
                                            child: Text(
                                              m.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _managerId = v),
                                    ),
                                  ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _type,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: _label(context, 'Type', 'قسم'),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          _label(
                                            context,
                                            'All payments',
                                            'تمام ادائیگیاں',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'advance',
                                        child: Text(
                                          _label(context, 'Advance', 'ایڈوانس'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'reimbursement',
                                        child: Text(
                                          _label(
                                            context,
                                            'Own money',
                                            'اپنی رقم',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _type = v ?? 'all'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MetricGrid([
                    _Metric(
                      _label(context, 'Total given out', 'کل دی گئی رقم'),
                      _money(context, (shownAdvances ? totalAdvance : 0) + (shownRepayments ? reimbursed : 0)),
                      Icons.account_balance_wallet,
                      const Color(0xFF7C3AED),
                      badge: _label(context, 'Total Out', 'کل جاری'),
                      badgeColor: const Color(0xFF7C3AED),
                    ),
                    _Metric(
                      _label(context, 'Advances given', 'دیے گئے ایڈوانس'),
                      _money(context, shownAdvances ? totalAdvance : 0),
                      Icons.wallet,
                      const Color(0xFF2563EB),
                      badge: _label(context, 'Advance', 'ایڈوانس'),
                      badgeColor: const Color(0xFF2563EB),
                    ),
                    _Metric(
                      _label(context, 'Advance used', 'ایڈوانس سے خرچ'),
                      _money(context, shownAdvances ? utilized : 0),
                      Icons.receipt_long,
                      const Color(0xFF0D9488),
                      badge: _label(context, 'Used', 'استعمال شدہ'),
                      badgeColor: const Color(0xFF0D9488),
                    ),
                    _Metric(
                      _label(context, 'Paid back', 'واپس ادا کیا'),
                      _money(context, shownRepayments ? reimbursed : 0),
                      Icons.payments,
                      const Color(0xFF10B981),
                      badge: _label(context, 'Settled', 'ادا شدہ'),
                      badgeColor: const Color(0xFF10B981),
                    ),
                    _Metric(
                      _label(context, 'Waiting / due', 'انتظار / باقی'),
                      _money(context, pending),
                      Icons.pending_actions,
                      const Color(0xFFF59E0B),
                      badge: _label(context, 'Pending', 'زیر التوا'),
                      badgeColor: const Color(0xFFF59E0B),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Text(
                    _label(
                      context,
                      'Transactions (${rows.length})',
                      'لین دین (${rows.length})',
                    ),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (rows.isEmpty)
                    _Empty(
                      _label(
                        context,
                        'No records for these filters',
                        'ان فلٹرز کے لیے کوئی ریکارڈ نہیں',
                      ),
                      Icons.search_off,
                      subtitle: _label(
                        context,
                        'Change your filters to see more.',
                        'مزید دیکھنے کے لیے فلٹر بدلیں۔',
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}

class CoreOfficesScreen extends StatelessWidget {
  const CoreOfficesScreen({super.key});
  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ColoredBox(
          color: isDark ? const Color(0xFF0B0F19) : _surface,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(context, 'Offices', 'دفاتر'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : _navy,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _createOffice(context),
                    icon: const Icon(Icons.add),
                    label: Text(
                      _label(context, 'Add office', 'دفتر شامل کریں'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...flow.offices.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _Panel(
                    child: Row(
                      children: [
                        const Icon(Icons.business_outlined, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            o.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          '${context.watch<UserProvider>().allUsers.where((u) => u.officeId == o.id).length} ${_label(context, 'people', 'لوگ')}',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _createOffice(BuildContext context) async {
  final controller = TextEditingController();
  final key = GlobalKey<FormState>();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(_label(dialogContext, 'Add office', 'دفتر شامل کریں')),
      content: Form(
        key: key,
        child: TextFormField(
          controller: controller,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: _label(dialogContext, 'Office name', 'دفتر کا نام'),
          ),
          validator: (v) => v?.trim().isEmpty ?? true
              ? _readLabel(dialogContext, 'Enter an office name.', 'دفتر کا نام لکھیں۔')
              : null,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_label(dialogContext, 'Cancel', 'منسوخ کریں')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: Text(_label(dialogContext, 'Save', 'محفوظ کریں')),
            ),
          ],
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || !context.mounted) return;
  try {
    await DatabaseService().createOffice(name);
    if (context.mounted) {
      context.read<CoreFlowProvider>().refresh();
      showAppToast(
        context,
        message: _label(context, 'Office added successfully!', 'دفتر کامیابی سے شامل کر دیا گیا!'),
        type: ToastType.success,
      );
    }
  } catch (e) {
    if (context.mounted) _showError(context, e.toString());
  }
}
