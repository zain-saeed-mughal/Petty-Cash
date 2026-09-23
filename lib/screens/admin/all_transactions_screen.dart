import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/expense_request_model.dart';
import '../../models/user_model.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/receipt_viewer_dialog.dart';
import '../finance/request_detail_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  RequestStatus? _statusFilter;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showOverrideDialog(BuildContext context, ExpenseRequest req) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final expense = Provider.of<ExpenseProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    RequestStatus selectedStatus = req.status;
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(
                Icons.security_update_warning_rounded,
                color: AppTheme.roleSuperAdmin,
              ),
              SizedBox(width: 8),
              Text(
                'Super Admin Override',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Override status for "${req.itemDescription}" (${req.id})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<RequestStatus>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Force Status To:',
                  ),
                  items: RequestStatus.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Audit Note / Override Reason',
                    hintText: 'e.g. Approved per CEO executive exemption...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.roleSuperAdmin,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                final success = await expense.overrideStatus(
                  requestId: req.id,
                  newStatus: selectedStatus,
                  adminUser: user,
                  note: noteController.text.trim().isNotEmpty
                      ? noteController.text.trim()
                      : null,
                );
                if (success) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Transaction status overridden successfully by Super Admin.',
                      ),
                      backgroundColor: AppTheme.roleSuperAdmin,
                    ),
                  );
                }
              },
              child: const Text('Apply Override'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ExpenseRequest req) {
    final expense = Provider.of<ExpenseProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction Record'),
        content: Text(
          'Are you sure you want to permanently delete transaction "${req.itemDescription}" (${req.id})? This action is irrevocable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              final success = await expense.deleteRequest(req.id);
              if (success) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Transaction record deleted.'),
                    backgroundColor: AppTheme.statusRejected,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final expense = Provider.of<ExpenseProvider>(context);
    final currentUser = auth.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    final all = expense.filteredAllTransactions.where((req) {
      if (_statusFilter != null && req.status != _statusFilter) return false;
      final q = _searchController.text.toLowerCase().trim();
      if (q.isNotEmpty) {
        final matchDesc = req.itemDescription.toLowerCase().contains(q);
        final matchName = req.requesterName.toLowerCase().contains(q);
        final matchReason = req.reason.toLowerCase().contains(q);
        final matchId = req.id.toLowerCase().contains(q);
        return matchDesc || matchName || matchReason || matchId;
      }
      return true;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'All Organizational Transactions',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryNavy,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currentUser.isSuperAdmin
                                    ? 'Super Admin View: Full control with transaction override and audit delete'
                                    : 'Admin View: Real-time organizational audit trail',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Search & Filter
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.borderLight,
                          width: 0.5,
                        ),
                        boxShadow: AppTheme.premiumShadow,
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search by requester name, ID, item description, or reason...',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF94A3B8),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  'All (${expense.totalTransactionsCount})',
                                  null,
                                ),
                                const SizedBox(width: 12),
                                _buildFilterChip(
                                  'Pending (${expense.pendingCount})',
                                  RequestStatus.pending,
                                  color: AppTheme.statusPending,
                                ),
                                const SizedBox(width: 12),
                                _buildFilterChip(
                                  'Approved / Paid (${expense.approvedCount})',
                                  RequestStatus.paid,
                                  color: AppTheme.statusApproved,
                                ),
                                const SizedBox(width: 12),
                                _buildFilterChip(
                                  'Rejected (${expense.rejectedCount})',
                                  RequestStatus.rejected,
                                  color: AppTheme.statusRejected,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Transactions List
        if (all.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                width: double.infinity,
                padding: const EdgeInsets.all(64),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight, width: 0.5),
                  boxShadow: AppTheme.premiumShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.find_in_page_outlined,
                        size: 64,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Transactions Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try adjusting your search criteria.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16)
                .copyWith(bottom: 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: _buildTransactionCard(all[index], currentUser),
                  ),
                );
              }, childCount: all.length),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, RequestStatus? status, {Color? color}) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      backgroundColor: Colors.white,
      selectedColor: color ?? AppTheme.primaryBlue,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? (color ?? AppTheme.primaryBlue)
              : AppTheme.borderLight,
        ),
      ),
      onSelected: (_) {
        setState(() => _statusFilter = isSelected ? null : status);
      },
    );
  }

  Widget _buildTransactionCard(ExpenseRequest req, AppUser currentUser) {
    final isNarrow = MediaQuery.of(context).size.width < 420;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 0.5),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        req.id,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '• ${_dateFormat.format(req.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req.itemDescription,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Requested by: ${req.requesterName} (${req.requesterEmail})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
              final amount = Column(
                crossAxisAlignment: isNarrow
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    '${AppConstants.defaultCurrencySymbol}${req.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: req.status, isCompact: true),
                ],
              );

              return isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [details, const SizedBox(height: 8), amount],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: details),
                        amount,
                      ],
                    );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Purpose: ${req.reason}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (req.isRejected && req.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Rejection Reason: ${req.rejectionReason}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.statusRejected,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Actions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (req.billImageUrl != null)
                TextButton.icon(
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('View Receipt'),
                  onPressed: () {
                    ReceiptViewerDialog.show(
                      context,
                      imageUrl: req.billImageUrl!,
                    );
                  },
                ),
              TextButton(
                onPressed: () => RequestDetailScreen.show(context, req),
                child: const Text('Review Detail'),
              ),
              if (currentUser.isSuperAdmin) ...[
                IconButton(
                  icon: const Icon(
                    Icons.edit_attributes_rounded,
                    color: AppTheme.roleSuperAdmin,
                  ),
                  tooltip: 'Override Status (Super Admin)',
                  onPressed: () => _showOverrideDialog(context, req),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    color: AppTheme.statusRejected,
                  ),
                  tooltip: 'Delete Transaction (Super Admin)',
                  onPressed: () => _confirmDelete(context, req),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
