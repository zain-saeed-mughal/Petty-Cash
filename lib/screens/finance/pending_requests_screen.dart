import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../models/expense_request_model.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../widgets/status_badge.dart';
import 'request_detail_screen.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final pending = expense.pendingRequests.where((req) {
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
                    // Header Summary Banner
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0F766E),
                            Color(0xFF115E59),
                          ], // Teal/Emerald
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.premiumShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.pending_actions_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pending Expense Queue',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${expense.pendingCount} requests awaiting verification • Total Pending: ${AppConstants.defaultCurrencySymbol}${expense.pendingAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Search Bar
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
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by requester name, item description, or reason...',
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
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Pending Requests List
        if (pending.isEmpty)
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
                        Icons.task_alt_rounded,
                        size: 64,
                        color: AppTheme.statusApproved,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'All Caught Up!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'There are currently no pending expense requests waiting for review.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
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
                    child: _buildPendingCard(pending[index]),
                  ),
                );
              }, childCount: pending.length),
            ),
          ),
      ],
    );
  }

  Widget _buildPendingCard(ExpenseRequest req) {
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
            // Top Row
            LayoutBuilder(
              builder: (context, constraints) {
                final details = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(
                        Icons.receipt_rounded,
                        color: AppTheme.statusPending,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
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
                                '• ${_dateFormat.format(req.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
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
                        ],
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
                      '${AppConstants.defaultCurrencySymbol}${req.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const StatusBadge(
                      status: RequestStatus.pending,
                      isCompact: true,
                    ),
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

            // Reason quote
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Purpose: ${req.reason}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (req.billImageUrl != null)
                  Row(
                    children: const [
                      Icon(
                        Icons.attachment_rounded,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Receipt attached',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'No bill image',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.rate_review_rounded, size: 16),
                  label: const Text('Review & Decide'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => RequestDetailScreen.show(context, req),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
