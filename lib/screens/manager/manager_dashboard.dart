import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/core_flow_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/core_flow_models.dart';
import '../core/core_dashboard_screens.dart';


import '../../widgets/account_app_bar.dart';
import '../../widgets/app_status_badge.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AccountAppBar(),
      body: ManagerHome(),
    );
  }
}

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  DateTime _selectedDate = DateTime.now();
  bool _monthly = true;

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

    bool inRange(DateTime date) {
      if (_monthly) {
        return date.year == _selectedDate.year && date.month == _selectedDate.month;
      }
      return date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
    }

    for (var i in myItems) {
      if (i.status != 'rejected') {
        if (inRange(i.createdAt)) totalTaggedItems += i.amount;
      }
    }
    for (var r in myReimbursements) {
      if (r.status != 'rejected' && r.status != 'declined') {
        if (inRange(r.createdAt)) totalTaggedReimbursements += r.amount;
      }
    }

    final totalSpent = totalTaggedItems + totalTaggedReimbursements;

    // Filtered lists for display (date-filtered)
    final filteredItems = myItems.where((i) => inRange(i.createdAt)).toList();
    final filteredReimbursements = myReimbursements.where((r) => inRange(r.createdAt)).toList();

    final String dateLabel = _monthly
        ? '${_selectedDate.month}/${_selectedDate.year}'
        : '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';

    return ColoredBox(
      color: const Color(0xFFF5F8FC),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ur ? 'میرا خلاصہ' : 'My Overview',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF14223D),
                ),
              ),
              Row(
                children: [
                  Switch(
                    value: _monthly,
                    onChanged: (v) => setState(() => _monthly = v),
                  ),
                  Text(ur ? 'ماہانہ' : 'Monthly'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF3159E8),
            elevation: 4,
            shadowColor: const Color(0xFF3159E8).withValues(alpha: 0.4),
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
                        ur ? 'کل خرچ' : 'Total Spent',
                        style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
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
                                dateLabel,
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
                    context.read<LanguageProvider>().money(totalSpent),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            ur ? 'حالیہ سرگرمی' : 'Recent Activity',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF14223D),
            ),
          ),
          const SizedBox(height: 10),

          if (filteredItems.isEmpty && filteredReimbursements.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                        ur
                          ? 'اس مدت میں کوئی کام نہیں ہوا۔ کوئی اور تاریخ چنیں۔'
                          : 'No activity in this period. Try another date.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Reimbursements tagged to this manager (date-filtered)
            ...filteredReimbursements.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CoreReimbursementCard(request: r, showOwner: true),
            )),

            // Items tagged to this manager (date-filtered)
            if (filteredItems.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                ur ? 'خریداری' : 'Purchases',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF14223D),
                ),
              ),
              const SizedBox(height: 8),
              ...filteredItems.map((item) => _ManagerItemTile(item: item)),
            ],
          ],
        ],
      ),
    );
  }
}

/// Tile to show a purchase item tagged to this manager
class _ManagerItemTile extends StatelessWidget {
  final CoreAdvanceItem item;
  const _ManagerItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3159E8).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: Color(0xFF3159E8), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF14223D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Builder(builder: (ctx) {
                  final users = ctx.watch<UserProvider>().allUsers;
                  final obUser = users.where((u) => u.uid == item.officeBoyId).firstOrNull;
                  final obName = obUser?.name ?? item.officeBoyId.substring(0, 8);
                  return Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: Color(0xFF3159E8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${lang.isRtl ? 'آفس بوائے' : 'By'}: $obName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFF3159E8),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      lang.date(item.createdAt),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 14,
                      color: Color(0xFF3159E8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      lang.money(item.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF14223D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppStatusBadge(status: item.status, isCompact: true),
        ],
      ),
    );
  }
}
