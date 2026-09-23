import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/expense_request_model.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/receipt_viewer_dialog.dart';
import '../../widgets/audit_trail_widget.dart';
import '../../widgets/rejection_reason_dialog.dart';

class RequestDetailScreen extends StatefulWidget {
  final ExpenseRequest request;

  const RequestDetailScreen({super.key, required this.request});

  static Future<void> show(BuildContext context, ExpenseRequest request) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RequestDetailScreen(request: request)),
    );
  }

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final DateFormat _dateFormat = DateFormat('MMMM dd, yyyy • hh:mm a');
  bool _isProcessing = false;

  Future<void> _handleApprove() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final expense = Provider.of<ExpenseProvider>(context, listen: false);
    final reviewer = auth.currentUser;

    if (reviewer == null || !reviewer.canApproveRequests) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You do not have permission to approve this request.',
            ),
          ),
        );
      }
      return;
    }

    if (!widget.request.isPending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This request is no longer pending and cannot be approved.',
            ),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & Process Payment'),
        content: Text(
          'Are you sure you want to approve "${widget.request.itemDescription}" for ${AppConstants.defaultCurrencySymbol}${widget.request.amount.toStringAsFixed(2)}? This will mark the expense as Paid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusApproved,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      final success = await expense.approveRequest(
        requestId: widget.request.id,
        reviewer: reviewer,
        markAsPaidImmediately: true,
      );
      setState(() => _isProcessing = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense request approved and marked as Paid!'),
            backgroundColor: AppTheme.statusApproved,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleReject() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final expense = Provider.of<ExpenseProvider>(context, listen: false);
    final reviewer = auth.currentUser;

    if (reviewer == null || !reviewer.canApproveRequests) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to reject this request.'),
          ),
        );
      }
      return;
    }

    if (!widget.request.isPending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This request is no longer pending and cannot be rejected.',
            ),
          ),
        );
      }
      return;
    }

    // Show mandatory rejection reason dialog
    final reason = await RejectionReasonDialog.show(
      context,
      requestTitle: widget.request.itemDescription,
      amount: widget.request.amount,
    );

    if (reason != null && reason.trim().isNotEmpty) {
      setState(() => _isProcessing = true);
      final success = await expense.rejectRequest(
        requestId: widget.request.id,
        rejectionReason: reason,
        reviewer: reviewer,
      );
      setState(() => _isProcessing = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Expense request rejected. Reason logged for requester.',
            ),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(title: Text('Expense Review: ${req.id}')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatusBadge(status: req.status),
                          Text(
                            _dateFormat.format(req.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        req.itemDescription,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppConstants.defaultCurrencySymbol}${req.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryBlue,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Requester & Purpose Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requester Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.roleOfficeBoy.withValues(
                              alpha: 0.15,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: AppTheme.roleOfficeBoy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.requesterName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                                Text(
                                  req.requesterEmail,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      const Text(
                        'Purpose & Reason for Purchase',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        req.reason,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                          height: 1.5,
                        ),
                      ),

                      // Rejection reason if already rejected
                      if (req.isRejected && req.rejectionReason != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.statusRejectedBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.statusRejected.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rejection Explanation:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.statusRejected,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                req.rejectionReason!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7F1D1D),
                                ),
                              ),
                              if (req.reviewedByName != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Reviewed by: ${req.reviewedByName}',
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Bill / Receipt Image Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Attached Bill / Receipt',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (req.billImageUrl != null)
                            TextButton.icon(
                              icon: const Icon(Icons.zoom_in_rounded, size: 16),
                              label: const Text('Full View & Zoom'),
                              onPressed: () {
                                ReceiptViewerDialog.show(
                                  context,
                                  imageUrl: req.billImageUrl!,
                                  title: 'Receipt: ${req.itemDescription}',
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (req.billImageUrl != null &&
                          req.billImageUrl!.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            ReceiptViewerDialog.show(
                              context,
                              imageUrl: req.billImageUrl!,
                              title: 'Receipt: ${req.itemDescription}',
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 280,
                              width: double.infinity,
                              color: const Color(0xFF0F172A),
                              child: Center(
                                child: CachedNetworkImage(
                                  imageUrl: req.billImageUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white54,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_not_supported_rounded,
                                            color: Colors.white54,
                                            size: 48,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Unable to display preview',
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Column(
                            children: const [
                              Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFFCBD5E1),
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No receipt attached for this request',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Approval / Rejection Action Buttons (Shown only when Pending and the reviewer can approve)
                if (req.isPending &&
                    (Provider.of<AuthProvider>(context)
                            .currentUser
                            ?.canApproveRequests ??
                        false)) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // Reject Button
                      SizedBox(
                        width: isDesktop ? null : double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.statusRejected,
                          ),
                          label: const Text(
                            'Reject',
                            style: TextStyle(
                              color: AppTheme.statusRejected,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppTheme.statusRejected,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 32,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isProcessing ? null : _handleReject,
                        ),
                      ),

                      // Approve Button
                      SizedBox(
                        width: isDesktop ? null : double.infinity,
                        child: ElevatedButton.icon(
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                ),
                          label: const Text(
                            'Approve & Pay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.statusApproved,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 32,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isProcessing ? null : _handleApprove,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Audit Trail
                if (req.auditLogs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AuditTrailWidget(auditLogs: req.auditLogs),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
