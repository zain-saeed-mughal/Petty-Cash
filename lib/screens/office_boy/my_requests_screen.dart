import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/expense_request_model.dart';
import '../../config/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/receipt_viewer_dialog.dart';
import '../../widgets/settle_advance_dialog.dart';

class MyRequestsScreen extends StatefulWidget {
  final VoidCallback? onNewRequestTap;

  const MyRequestsScreen({super.key, this.onNewRequestTap});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  RequestStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final expense = Provider.of<ExpenseProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return Center(child: Text(lang.tr('please_log_in')));
    }

    // Office Boy can ONLY see their own requests
    final allMyRequests = expense.getMyRequests(currentUser.uid);
    final filtered = allMyRequests.where((req) {
      if (_statusFilter != null &&
          !(_statusFilter == RequestStatus.paid
              ? (req.hasDisbursement || req.isApproved)
              : req.status == _statusFilter)) {
        return false;
      }
      final query = _searchController.text.toLowerCase().trim();
      if (query.isNotEmpty) {
        final matchDesc = req.itemDescription.toLowerCase().contains(query);
        final matchReason = req.reason.toLowerCase().contains(query);
        return matchDesc || matchReason;
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
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Title & Action Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('My Expense History'),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryNavy,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  context.language.format(
                                    'Showing requests submitted by {name}',
                                    '{name} کی جمع کردہ درخواستیں',
                                    {'name': currentUser.name},
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (widget.onNewRequestTap != null) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(lang.tr('new_btn')),
                              onPressed: widget.onNewRequestTap,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Advance Wallet Summary
                      if (allMyRequests.any(
                        (r) =>
                            r.isAdvance &&
                            (r.isPaid || r.isPendingSettlement) &&
                            !r.isSettled,
                      )) ...[
                        Builder(
                          builder: (context) {
                            final unsettledAdvances = allMyRequests.where(
                              (r) =>
                                  r.isAdvance &&
                                  (r.isPaid || r.isPendingSettlement) &&
                                  !r.isSettled,
                            );
                            final balance = unsettledAdvances.fold<double>(
                              0,
                              (sum, r) => sum + r.outstandingAdvance,
                            );
                            return Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryNavy,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: AppTheme.premiumShadow,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.language.format(
                                            'Active Advance Balance',
                                            'آپ کے پاس موجود ایڈوانس رقم',
                                            {},
                                          ),
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.language.money(balance),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      // Search & Filter Bar
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
                                hintText: context.t(
                                  'Search my requests by description or purpose...',
                                ),
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

                            // Filter Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    '${context.t('All')} (${allMyRequests.length})',
                                    null,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    '${context.t('Pending')} (${allMyRequests.where((r) => r.isPending).length})',
                                    RequestStatus.pending,
                                    color: AppTheme.statusPending,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    '${context.t('Approved / Paid')} (${allMyRequests.where((r) => r.isApproved || r.hasDisbursement).length})',
                                    RequestStatus.paid,
                                    color: AppTheme.statusApproved,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    '${context.t('Rejected')} (${allMyRequests.where((r) => r.isRejected).length})',
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
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 950),
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
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.t('No Expense Requests Found'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isNotEmpty ||
                                _statusFilter != null
                            ? context.t(
                                'Try clearing your search query or filter chips.',
                              )
                            : context.t(
                                'You haven\'t submitted any expense requests yet.',
                              ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
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
                      constraints: const BoxConstraints(maxWidth: 950),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: _buildRequestCard(filtered[index]),
                    ),
                  );
                }, childCount: filtered.length),
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
        setState(() {
          _statusFilter = isSelected ? null : status;
        });
      },
    );
  }

  Widget _buildRequestCard(ExpenseRequest req) {
    final isNarrow = MediaQuery.of(context).size.width < 420;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: req.isRejected
              ? AppTheme.statusRejected.withValues(alpha: 0.3)
              : AppTheme.borderLight,
          width: req.isRejected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Item name, Amount & Status Badge
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          context.language.date(req.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      req.itemDescription,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                      ),
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
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge(status: req.status),
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
            const SizedBox(height: 12),

            // Purpose / Reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      req.reason,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Rejection Reason Callout (CRITICAL REQUIREMENT: visible to Office Boy)
            if (req.isRejected &&
                req.rejectionReason != null &&
                req.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusRejectedBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.statusRejected.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppTheme.statusRejected,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('Reason for Rejection:'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.statusRejected,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            req.rejectionReason!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7F1D1D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (req.reviewedByName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              context.language.format(
                                'Reviewed by: {name}',
                                'جائزہ لینے والا: {name}',
                                {'name': req.reviewedByName},
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Receipt Attachment Action
            if (req.billImageUrl != null && req.billImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: Text(context.t('View receipt')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      ReceiptViewerDialog.show(
                        context,
                        imageUrl: req.billImageUrl!,
                        title:
                            '${context.t('Receipt')}: ${req.itemDescription}',
                      );
                    },
                  ),
                ],
              ),
            ],

            // Advance Settlement Action
            if ((req.isPaid || req.isPendingSettlement) &&
                req.isAdvance &&
                !req.isSettled) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.calculate, size: 16),
                label: Text(
                  context.t(
                    req.isPendingSettlement
                        ? 'Update Settlement'
                        : 'Settle Advance',
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => SettleAdvanceDialog(request: req),
                  ).then((settled) {
                    if (!mounted) return;
                    if (settled == true) {
                      context.read<ExpenseProvider>().refresh();
                    }
                  });
                },
              ),
            ],
            if (req.isAdvance && req.isSettled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusApprovedBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.statusApproved.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppTheme.statusApproved,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('Advance Settled'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.statusApproved,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${context.t('Spent')}: ${context.language.money(req.settlementAmount ?? 0)}\n${context.t('Returned via')}: ${context.t(req.settlementMethod ?? 'None')}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (req.settlementNote != null &&
                              req.settlementNote!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              req.settlementNote!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF064E3B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
