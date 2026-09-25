import '../../widgets/request_override_dialog.dart';

import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/expense_request_model.dart';
import '../../models/user_model.dart';
import '../../config/app_theme.dart';
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
  final _deleting = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showOverrideDialog(
    BuildContext context,
    ExpenseRequest req,
  ) async {
    final actor = context.read<AuthProvider>().currentUser;
    if (actor == null || !actor.isSuperAdmin) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RequestOverrideDialog(request: req, actor: actor),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.language.tr('override_success'))),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, ExpenseRequest req) async {
    if (_deleting.contains(req.id)) return;
    final expense = context.read<ExpenseProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.language.tr('delete_transaction_title')),
        content: Text(context.language.tr('delete_transaction_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.language.tr('delete_btn')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!_deleting.add(req.id)) return;
    setState(() {});
    final success = await expense.deleteRequest(req.id);
    _deleting.remove(req.id);
    if (mounted) setState(() {});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.language.tr('transaction_deleted')
              : context.language.error(
                  expense.errorMessage ?? 'Unable to save. Please retry.',
                ),
        ),
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
      if (_statusFilter != null &&
          !(_statusFilter == RequestStatus.paid
              ? (req.hasDisbursement || req.isApproved)
              : req.status == _statusFilter)) {
        return false;
      }
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

    return RefreshIndicator(
      onRefresh: () async {
        expense.refresh();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                                Text(
                                  Provider.of<LanguageProvider>(context)
                                      .tr('all_org_transactions'),
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
                                      ? Provider.of<LanguageProvider>(context)
                                            .tr('super_admin_view_desc')
                                      : Provider.of<LanguageProvider>(context)
                                            .tr('admin_view_desc'),
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
                                hintText: Provider.of<LanguageProvider>(context)
                                    .tr('search_admin_transactions'),
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
                                    '${Provider.of<LanguageProvider>(context).tr('all')} (${expense.totalTransactionsCount})',
                                    null,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('pending')} (${expense.pendingCount})',
                                    RequestStatus.pending,
                                    color: AppTheme.statusPending,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('paid_approved')} (${expense.approvedCount})',
                                    RequestStatus.paid,
                                    color: AppTheme.statusApproved,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('rejected')} (${expense.rejectedCount})',
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
                      Text(
                        Provider.of<LanguageProvider>(context)
                            .tr('no_transactions_found'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Provider.of<LanguageProvider>(context)
                            .tr('try_adjusting_search'),
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 15,
                        ),
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
      ),
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
                        req.displayId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '• ${context.language.date(req.createdAt)}',
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
                    '${Provider.of<LanguageProvider>(context, listen: false).tr('requested_by')}${req.requesterName} (${req.requesterEmail})',
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
                    context.language.money(req.amount),
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
                    '${Provider.of<LanguageProvider>(context, listen: false).tr('purpose_prefix')}${req.reason}',
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
              '${Provider.of<LanguageProvider>(context, listen: false).tr('rejection_reason_prefix')}${req.rejectionReason}',
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
                  label: Text(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).tr('view_receipt'),
                  ),
                  onPressed: () {
                    ReceiptViewerDialog.show(
                      context,
                      imageUrl: req.billImageUrl!,
                    );
                  },
                ),
              TextButton(
                onPressed: () => RequestDetailScreen.show(context, req),
                child: Text(
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).tr('review_detail'),
                ),
              ),
              if (currentUser.isSuperAdmin) ...[
                IconButton(
                  icon: const Icon(
                    Icons.edit_attributes_rounded,
                    color: AppTheme.roleSuperAdmin,
                  ),
                  tooltip: Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).tr('override_status_tooltip'),
                  onPressed: () => _showOverrideDialog(context, req),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    color: AppTheme.statusRejected,
                  ),
                  tooltip: Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).tr('delete_transaction_tooltip'),
                  onPressed: _deleting.contains(req.id)
                      ? null
                      : () => _confirmDelete(context, req),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
