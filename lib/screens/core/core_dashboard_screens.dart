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
import '../../widgets/receipt_viewer_dialog.dart';
import 'core_entry_dialog.dart';

const _blue = Color(0xFF3159E8);
const _navy = Color(0xFF14223D);
const _teal = Color(0xFF087F8C);
const _surface = Color(0xFFF5F8FC);

String _label(BuildContext context, String english, String urdu) =>
    context.watch<LanguageProvider>().isRtl ? urdu : english;
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

String _status(BuildContext context, String status) => switch (status) {
  'pending' => _label(context, 'Waiting', 'انتظار میں'),
  'cleared' => _label(context, 'Money Sent', 'رقم دے دی گئی'),
  'fully_utilized' => _label(context, 'Fully Cleared', 'مکمل کلیئر ہو گیا'),
  'approved' => _label(context, 'Approved', 'منظور'),
  'rejected' => _label(context, 'Rejected', 'مسترد'),
  'paid' => _label(context, 'Paid', 'ادا کر دیا'),
  'awaiting_office_boy_approval' => _label(context, 'Needs Approval', 'منظوری درکار ہے'),
  'declined' => _label(context, 'Declined', 'انکار کر دیا'),
  _ => status,
};

class _Panel extends StatelessWidget {
  final Widget child;
  final Color? tint;
  const _Panel({required this.child, this.tint});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: tint ?? Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE1E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C1C355B),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' || 'awaiting_office_boy_approval' => const Color(0xFFAA6E00),
      'rejected' || 'declined' => const Color(0xFFC23F42),
      'cleared' || 'approved' => _blue,
      _ => const Color(0xFF05865F),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _status(context, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(fontSize: 12, color: Color(0xFF617187)),
        ),
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  final List<Widget> children;
  const _MetricGrid(this.children);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final columns = size.maxWidth >= 950
          ? 4
          : size.maxWidth >= 380
          ? 2
          : 1;
      final gap = 10.0;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map(
              (child) => SizedBox(
                width: (size.maxWidth - gap * (columns - 1)) / columns,
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
  const _Empty(this.title, this.icon);
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
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CoreEntryDialog(mode: mode, advance: advance),
  );
}

class OfficeBoyHome extends StatelessWidget {
  final VoidCallback onRecords;
  const OfficeBoyHome({super.key, required this.onRecords});
  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final uid = context.watch<AuthProvider>().currentUser?.uid ?? '';
        final mine = flow.advances.where((a) => a.officeBoyId == uid).toList();
        final spent = flow.balances
            .where((b) => b.officeBoyId == uid)
            .fold<double>(0, (s, b) => s + b.spent);
        final pending = mine.where((a) => a.status == 'pending').length;
        return ColoredBox(
          color: _surface,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [_navy, Color(0xFF304D80)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3014243D),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(
                        context,
                        'My Advance Balance',
                        'میرا ایڈوانس بیلنس',
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _money(context, flow.balanceFor(uid)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _label(
                        context,
                        '$pending waiting · ${_money(context, spent)} spent',
                        '$pending درخواستیں انتظار میں · ${_money(context, spent)} خرچ',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _label(
                  context,
                  'What would you like to do?',
                  'آپ کیا کرنا چاہتے ہیں؟',
                ),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.account_balance_wallet_rounded,
                color: _blue,
                title: _label(context, 'Request Advance', 'ایڈوانس مانگیں'),
                subtitle: _label(
                  context,
                  'Need money before buying',
                  'خریداری سے پہلے رقم چاہیے',
                ),
                onTap: () => _openEntry(context, 'advance'),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.shopping_bag_rounded,
                color: _teal,
                title: _label(
                  context,
                  'I Bought Something Myself',
                  'میں نے اپنی رقم سے خریدا',
                ),
                subtitle: _label(
                  context,
                  'Ask Finance to pay you back',
                  'فنانس سے رقم واپس لیں',
                ),
                onTap: () => _openEntry(context, 'reimbursement'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(context, 'My Advances', 'میرے ایڈوانس'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRecords,
                    child: Text(_label(context, 'All records', 'سارا ریکارڈ')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (mine.isEmpty)
                _Empty(
                  _label(context, 'No advances yet', 'ابھی کوئی ایڈوانس نہیں'),
                  Icons.wallet_outlined,
                )
              else
                ...mine
                    .take(4)
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CoreAdvanceCard(advance: a, showOwner: false),
                      ),
                    ),
            ],
          ),
        );
      },
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF63748C),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
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
    final role = context.watch<AuthProvider>().currentUser?.role;
    final balance = flow.balanceForAdvance(advance.id);
    final items = flow.items.where((i) => i.advanceId == advance.id).toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: _blue),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  advance.purpose,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: _navy,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatusChip(advance.status),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${_money(context, advance.amount)} · ${_date(advance.createdAt)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
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
          if (balance != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_label(context, 'Spent', 'خرچ')}: ${_money(context, balance.spent)}',
                  ),
                ),
                Flexible(
                  child: Text(
                    '${_label(context, 'Left', 'باقی')}: ${_money(context, balance.remaining)}',
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
              value: balance.total > 0
                  ? (balance.spent / balance.total).clamp(0, 1)
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
                          if (item.status != 'approved')
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
                              onPressed: flow.isBusy(item.id) ? null : () {
                                flow.reviewAdvanceItem(item.id, 'approve', null);
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
                                  flow.reviewAdvanceItem(item.id, 'reject', reason);
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
                        : () => flow.respondToDirectAdvance(advance.id, 'decline'),
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
                        : () => flow.respondToDirectAdvance(advance.id, 'approve'),
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
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              '${name ?? ''}${name != null && details != null ? '\n' : ''}${details ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
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
  if (context.mounted && !ok) _showError(context, flow.error);
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
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: _teal),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  request.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: _navy,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatusChip(request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_money(context, request.amount)} · ${_date(request.createdAt)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
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
                          if (context.mounted && !ok) {
                            _showError(context, flow.error);
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
      actions: [
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
  );
  controller.dispose();
  if (reason == null || !context.mounted) return;
  final flow = context.read<CoreFlowProvider>();
  final ok = await flow.reviewReimbursement(request.id, 'reject', reason);
  if (context.mounted && !ok) _showError(context, flow.error);
}

Future<void> _markPaid(BuildContext context, CoreReimbursement request) async {
  final flow = context.read<CoreFlowProvider>();
  final ok = await flow.markReimbursementPaid(request.id, request.wantedMethod);
  if (context.mounted && !ok) _showError(context, flow.error);
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
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Material(
                color: Colors.white,
                child: TabBar(
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
  Widget build(BuildContext context) => records.isEmpty
      ? ColoredBox(
          color: _surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _Empty(empty, Icons.inbox_outlined),
            ),
          ),
        )
      : ColoredBox(
          color: _surface,
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

  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final pendingAdvances = flow.advances
            .where((a) => a.status == 'pending')
            .length;
        final pendingRepayments = flow.reimbursements
            .where((r) => r.status == 'pending' || r.status == 'approved')
            .length;
        final totalBalance = flow.balances.fold<double>(
          0,
          (s, b) => s + b.remaining,
        );

        final monthAdvances = flow.advances.where((a) => 
            a.status != 'declined' &&
            a.status != 'pending' &&
            a.status != 'rejected' &&
            a.clearedAt != null &&
            a.clearedAt!.year == _selectedMonth.year &&
            a.clearedAt!.month == _selectedMonth.month
        ).fold<double>(0, (s, a) => s + a.amount);

        return ColoredBox(
          color: _surface,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _label(context, 'Finance Overview', 'فنانس کا خلاصہ'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _label(
                  context,
                  'Requests from every office',
                  'تمام دفاتر کی درخواستیں',
                ),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Card(
                color: _blue,
                elevation: 4,
                shadowColor: _blue.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _label(context, 'Advances Disbursed', 'دیے گئے ایڈوانس'),
                            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedMonth,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => _selectedMonth = DateTime(date.year, date.month));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${_selectedMonth.month}/${_selectedMonth.year}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _money(context, monthAdvances),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MetricGrid([
                _Metric(
                  _label(context, 'Advances waiting', 'ایڈوانس انتظار میں'),
                  '$pendingAdvances',
                  Icons.wallet,
                  _blue,
                ),
                _Metric(
                  _label(
                    context,
                    'Repayments to review/pay',
                    'واپسی کی درخواستیں',
                  ),
                  '$pendingRepayments',
                  Icons.shopping_bag,
                  _teal,
                ),
                _Metric(
                  _label(context, 'Advance money left', 'ایڈوانس کی باقی رقم'),
                  _money(context, totalBalance),
                  Icons.account_balance_wallet,
                  _blue,
                ),
                _Metric(
                  _label(context, 'Offices', 'دفاتر'),
                  '${flow.offices.length}',
                  Icons.business,
                  _teal,
                ),
              ]),
              const SizedBox(height: 20),
              _ActionTile(
                icon: Icons.account_balance_wallet,
                color: _blue,
                title: _label(context, 'Advance Requests', 'ایڈوانس درخواستیں'),
                subtitle: _label(
                  context,
                  '$pendingAdvances waiting for payment',
                  '$pendingAdvances ادائیگی کے انتظار میں',
                ),
                onTap: widget.onAdvances,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.shopping_bag,
                color: _teal,
                title: _label(
                  context,
                  'Repayment Requests',
                  'رقم واپسی کی درخواستیں',
                ),
                subtitle: _label(
                  context,
                  '$pendingRepayments to review or pay',
                  '$pendingRepayments دیکھنی یا ادا کرنی ہیں',
                ),
                onTap: widget.onReimbursements,
              ),
            ],
          ),
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
              .where((a) => a.status == 'pending')
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_label(context, 'Given', 'دیا')}: ${_money(context, total)}',
                  ),
                  Text(
                    '${_label(context, 'Spent', 'خرچ')}: ${_money(context, spent)}',
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
                      ),
                      subtitle: Text(
                        '${b.itemCount} ${_label(context, 'purchases', 'خریداری')}',
                      ),
                      trailing: Text(_money(context, b.remaining)),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    ],
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
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
  );

  bool _inRange(DateTime? date) {
    if (date == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(_dateRange.start.year, _dateRange.start.month, _dateRange.start.day);
    final end = DateTime(_dateRange.end.year, _dateRange.end.month, _dateRange.end.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final users = context.watch<UserProvider>().allUsers;
        final advances = flow.advances.where((a) => _inRange(a.clearedAt));
        final paid = flow.reimbursements.where((r) => _inRange(r.paidAt));
        final advanceTotal = advances.fold<double>(0, (s, a) => s + a.amount);
        final reimbursed = paid.fold<double>(0, (s, r) => s + r.amount);
        return ColoredBox(
          color: _surface,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.superAdmin) ...[
                _Panel(
                  tint: const Color(0xFFEAF0FF),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: _blue,
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _label(
                                context,
                                'Welcome, Zain Saeed Mughal',
                                'خوش آمدید، زین سعید مغل',
                              ),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                            Text(
                              _label(
                                context,
                                'Here is your business overview.',
                                'یہ آپ کے کاروبار کا خلاصہ ہے۔',
                              ),
                              style: const TextStyle(color: Color(0xFF63748C)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _label(context, 'Overview', 'خلاصہ'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        initialDateRange: _dateRange,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (range != null) {
                        setState(() => _dateRange = range);
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      _dateRange.start.day == 1 &&
                              _dateRange.start.month == _dateRange.end.month &&
                              _dateRange.start.year == _dateRange.end.year &&
                              _dateRange.end.day == DateTime(_dateRange.start.year, _dateRange.start.month + 1, 0).day
                          ? DateFormat('MMMM yyyy').format(_dateRange.start)
                          : '${DateFormat('d MMM yy').format(_dateRange.start)} - ${DateFormat('d MMM yy').format(_dateRange.end)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MetricGrid([
                _Metric(
                  _label(context, 'Offices', 'دفاتر'),
                  '${flow.offices.length}',
                  Icons.business,
                  _blue,
                ),
                _Metric(
                  _label(context, 'Office Boys / Finance', 'آفس بوائے / فنانس'),
                  '${users.where((u) => u.role == UserRole.officeBoy).length} / ${users.where((u) => u.role == UserRole.finance).length}',
                  Icons.people,
                  _teal,
                ),
                _Metric(
                  _label(context, 'Advances given', 'دیے گئے ایڈوانس'),
                  _money(context, advanceTotal),
                  Icons.wallet,
                  _blue,
                ),
                _Metric(
                  _label(context, 'Paid back', 'واپس ادا کی گئی رقم'),
                  _money(context, reimbursed),
                  Icons.payments,
                  _teal,
                ),
              ]),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.calendar_month,
                color: _blue,
                title: _label(context, 'Monthly Records', 'ماہانہ ریکارڈ'),
                subtitle: _label(
                  context,
                  'Filter by office, person and payment type',
                  'دفتر، شخص اور ادائیگی کے حساب سے دیکھیں',
                ),
                onTap: widget.onRecords,
              ),
            ],
          ),
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
  @override
  Widget build(BuildContext context) => CoreDataGate(
    child: Builder(
      builder: (context) {
        final flow = context.watch<CoreFlowProvider>();
        final people = context
            .watch<UserProvider>()
            .allUsers
            .where(
              (u) =>
                  u.role == UserRole.officeBoy &&
                  (_officeId == null || u.officeId == _officeId),
            )
            .toList();
        final managers = context.watch<UserProvider>().allUsers.where((u) => u.isManager).toList();

        final allAdvances = flow.advances
            .where(
              (a) =>
                  (_officeId == null || a.officeId == _officeId) &&
                  (_personId == null || a.officeBoyId == _personId) &&
                  (_managerId == null || flow.items.any((i) => i.advanceId == a.id && i.taggedManagerId == _managerId)),
            )
            .toList();
        final allRepayments = flow.reimbursements
            .where(
              (r) =>
                  (_officeId == null || r.officeId == _officeId) &&
                  (_personId == null || r.officeBoyId == _personId) &&
                  (_managerId == null || r.taggedManagerId == _managerId),
            )
            .toList();
        final advances = allAdvances
            .where(
              (a) =>
                  _inRange(a.createdAt) ||
                  _inRange(a.clearedAt) ||
                  flow.items.any(
                    (item) =>
                        item.advanceId == a.id && _inRange(item.createdAt),
                  ),
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
            .where((a) => _inRange(a.clearedAt))
            .fold<double>(0, (s, a) => s + a.amount);
        final eligibleAdvanceIds = allAdvances.map((a) => a.id).toSet();
        final utilized = flow.items
            .where(
              (item) =>
                  eligibleAdvanceIds.contains(item.advanceId) &&
                  item.status == 'approved' &&
                  _inRange(item.createdAt),
            )
            .fold<double>(0, (s, item) => s + item.amount);
        final reimbursed = allRepayments
            .where((r) => _inRange(r.paidAt))
            .fold<double>(0, (s, r) => s + r.amount);
        final pending =
            (shownAdvances ? allAdvances : <CoreAdvance>[])
                .where((a) => a.status == 'pending' && _inRange(a.createdAt))
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
        return ColoredBox(
          color: _surface,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              if (index > 0) {
                final row = rows[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: row is CoreAdvance
                      ? CoreAdvanceCard(advance: row)
                      : CoreReimbursementCard(
                          request: row as CoreReimbursement,
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
                              onPressed: () async {
                                final range = await showDateRangePicker(
                                  context: context,
                                  initialDateRange: _dateRange,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (range != null) {
                                  setState(() => _dateRange = range);
                                }
                              },
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
                      const Color(0xFFC23F42),
                    ),
                    _Metric(
                      _label(context, 'Advances given', 'دیے گئے ایڈوانس'),
                      _money(context, shownAdvances ? totalAdvance : 0),
                      Icons.wallet,
                      _blue,
                    ),
                    _Metric(
                      _label(context, 'Advance used', 'ایڈوانس سے خرچ'),
                      _money(context, shownAdvances ? utilized : 0),
                      Icons.receipt_long,
                      _teal,
                    ),
                    _Metric(
                      _label(context, 'Paid back', 'واپس ادا کیا'),
                      _money(context, shownRepayments ? reimbursed : 0),
                      Icons.payments,
                      _teal,
                    ),
                    _Metric(
                      _label(context, 'Waiting / due', 'انتظار / باقی'),
                      _money(context, pending),
                      Icons.pending_actions,
                      const Color(0xFFAA6E00),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Text(
                    _label(
                      context,
                      'Transactions (${rows.length})',
                      'لین دین (${rows.length})',
                    ),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _navy,
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
        return ColoredBox(
          color: _surface,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(context, 'Offices', 'دفاتر'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                  ),
                  FilledButton.icon(
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
                        const Icon(Icons.business_outlined, color: _blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            o.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${context.watch<UserProvider>().allUsers.where((u) => u.officeId == o.id).length} ${_label(context, 'people', 'لوگ')}',
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
      title: Text(_label(context, 'Add office', 'دفتر شامل کریں')),
      content: Form(
        key: key,
        child: TextFormField(
          controller: controller,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: _label(context, 'Office name', 'دفتر کا نام'),
          ),
          validator: (v) => v?.trim().isEmpty ?? true
              ? _label(context, 'Enter an office name.', 'دفتر کا نام لکھیں۔')
              : null,
        ),
      ),
      actions: [
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
          child: Text(_label(context, 'Save', 'محفوظ کریں')),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || !context.mounted) return;
  try {
    await DatabaseService().createOffice(name);
    if (context.mounted) context.read<CoreFlowProvider>().refresh();
  } catch (e) {
    if (context.mounted) _showError(context, e.toString());
  }
}
