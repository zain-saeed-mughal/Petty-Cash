import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../models/expense_request_model.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/receipt_viewer_dialog.dart';
import 'request_detail_screen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  RequestStatus? _statusFilter;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final history = expense.paymentHistory.where((req) {
      if (_statusFilter != null && !(_statusFilter == RequestStatus.paid ? (req.isPaid || req.isApproved) : req.status == _statusFilter)) return false;
      final q = _searchController.text.toLowerCase().trim();
      if (q.isNotEmpty) {
        final matchDesc = req.itemDescription.toLowerCase().contains(q);
        final matchName = req.requesterName.toLowerCase().contains(q);
        final matchReason = req.reason.toLowerCase().contains(q);
        return matchDesc || matchName || matchReason;
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
                constraints: const BoxConstraints(maxWidth: 950),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary KPI
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Settled / Paid',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${AppConstants.defaultCurrencySymbol}${expense.totalSpent.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.statusApproved,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Settled Transactions',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${expense.approvedCount} approved / ${expense.rejectedCount} rejected',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryNavy,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

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
                              hintText: 'Search history by requester, description, or reason...',
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
                                _buildFilterChip('All Settled', null),
                                const SizedBox(width: 12),
                                _buildFilterChip(
                                  'Paid / Approved',
                                  RequestStatus.paid,
                                  color: AppTheme.statusApproved,
                                ),
                                const SizedBox(width: 12),
                                _buildFilterChip(
                                  'Rejected',
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

        // History List
        if (history.isEmpty)
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
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Payment Records Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Approved and rejected requests will appear here.',
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
                    constraints: const BoxConstraints(maxWidth: 950),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: _buildHistoryCard(history[index]),
                  ),
                );
              }, childCount: history.length),
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
        setState(() {
          _statusFilter = isSelected ? null : status;
        });
      },
    );
  }

  Widget _buildHistoryCard(ExpenseRequest req) {
    final isNarrow = MediaQuery.of(context).size.width < 420;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 0.5),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                          req.requesterName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        Text(
                          '• ${_dateFormat.format(req.updatedAt)}',
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
                    if (req.reviewedByName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reviewed by: ${req.reviewedByName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ]
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
            const SizedBox(height: 12),
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
                'Reason: ${req.rejectionReason}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.statusRejected,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing:12,runSpacing:8,
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
                  )
                else
                  const SizedBox.shrink(),
                TextButton(
                  onPressed: () => RequestDetailScreen.show(context, req),
                  child: const Text('Review Detail'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
