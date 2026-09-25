import '../../widgets/account_app_bar.dart';

import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';

import '../../widgets/receipt_image.dart';

import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/expense_request_model.dart';
import '../../config/app_theme.dart';
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
  bool _isProcessing = false;

  Future<void> _handleApprove() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final expense = Provider.of<ExpenseProvider>(context, listen: false);
    final reviewer = auth.currentUser;

    if (reviewer == null || !reviewer.canApproveRequests) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.tr('no_permission_approve'))),
        );
      }
      return;
    }

    final current = expense.findRequest(widget.request.id) ?? widget.request;
    if (!current.isPending && !current.isApproved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.tr('request_not_pending_approve'))),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('approve_process_payment')),
        content: Text(
          '${lang.tr('approve_confirm_msg_prefix')}${widget.request.itemDescription}${lang.tr('approve_confirm_msg_middle')}${context.language.money(widget.request.amount)}${lang.tr('approve_confirm_msg_end')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusApproved,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(lang.tr('confirm_approval')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final success = await expense.approveRequest(
        requestId: widget.request.id,
        expectedVersion: current.version,
        reviewer: reviewer,
        markAsPaidImmediately: true,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.language.error(
                expense.errorMessage ?? lang.tr('unable_to_save_retry'),
              ),
            ),
          ),
        );
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.tr('expense_approved_marked_paid')),
            backgroundColor: AppTheme.statusApproved,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleReject() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final expense = Provider.of<ExpenseProvider>(context, listen: false);
    final reviewer = auth.currentUser;

    if (reviewer == null || !reviewer.canApproveRequests) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.tr('no_permission_reject'))),
        );
      }
      return;
    }

    final current = expense.findRequest(widget.request.id) ?? widget.request;
    if (!current.isPending && !current.isApproved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.tr('request_not_pending_reject'))),
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

    if (reason != null && reason.trim().isNotEmpty && mounted) {
      setState(() => _isProcessing = true);
      final success = await expense.rejectRequest(
        requestId: widget.request.id,
        expectedVersion: current.version,
        rejectionReason: reason,
        reviewer: reviewer,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.language.error(
                expense.errorMessage ?? lang.tr('unable_to_save_retry'),
              ),
            ),
          ),
        );
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.tr('expense_rejected_reason_logged')),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleVerifySettlement() async {
    if (_isProcessing) return;
    final expenseProvider = Provider.of<ExpenseProvider>(
      context,
      listen: false,
    );
    setState(() => _isProcessing = true);

    try {
      final success = await expenseProvider.verifySettlement(
        requestId: widget.request.id,
        expectedVersion:
            (expenseProvider.findRequest(widget.request.id) ?? widget.request)
                .version,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t('Settlement Verified')),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.language.error(
                  expenseProvider.errorMessage ?? 'Verification failed',
                ),
              ),
              backgroundColor: AppTheme.statusRejected,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final req =
        context.watch<ExpenseProvider>().findRequest(widget.request.id) ??
        widget.request;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: const AccountAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(context.t('Back to requests')),
                ),
                const SizedBox(height: 8),
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(status: req.status),
                          Text(
                            context.language.date(req.createdAt),
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
                        context.language.money(req.amount),
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
                      Text(
                        context.t('Requester Information'),
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
                      Text(
                        context.t('Purpose & Reason for Purchase'),
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
                              Text(
                                lang.tr('rejection_explanation'),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              context.t('Attached Bill / Receipt'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (req.billImageUrl != null)
                            Flexible(
                              child: TextButton.icon(
                                icon: const Icon(
                                  Icons.zoom_in_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  lang.tr('full_view_zoom'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () {
                                  ReceiptViewerDialog.show(
                                    context,
                                    imageUrl: req.billImageUrl!,
                                    title:
                                        '${lang.tr('receipt_prefix')}${req.itemDescription}',
                                  );
                                },
                              ),
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
                              title:
                                  '${lang.tr('receipt_prefix')}${req.itemDescription}',
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 280,
                              width: double.infinity,
                              color: const Color(0xFF0F172A),
                              child: Center(
                                child: ReceiptImage(
                                  imageUrl: req.billImageUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white54,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.image_not_supported_rounded,
                                        color: Colors.white54,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        lang.tr('unable_display_preview'),
                                        style: const TextStyle(
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
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFFCBD5E1),
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                context.t(
                                  'No receipt attached for this request',
                                ),
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
                if ((req.isPending || req.isApproved) &&
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
                          label: Text(
                            context.t('Reject'),
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
                          label: Text(
                            context.t('Approve & Pay'),
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

                // Verify Settlement Button for Pending Settlement
                if (req.isPendingSettlement &&
                    (Provider.of<AuthProvider>(context)
                            .currentUser
                            ?.canApproveRequests ??
                        false)) ...[
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
                          : const Icon(Icons.verified, color: Colors.white),
                      label: Text(
                        context.t('Verify Settlement'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isProcessing ? null : _handleVerifySettlement,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Show Settlement Info if exists
                if (req.isAdvance && req.settlementAmount != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('Advance Settlement Details'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              context.t('Advance Amount:'),
                              style: const TextStyle(color: Colors.black87),
                            ),
                            Text(
                              context.language.money(req.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              context.t('Amount Spent:'),
                              style: const TextStyle(color: Colors.black87),
                            ),
                            Text(
                              context.language.money(req.settlementAmount ?? 0),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              context.t('Returned via:'),
                              style: const TextStyle(color: Colors.black87),
                            ),
                            Text(
                              context.t(req.settlementMethod ?? 'None'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (req.settlementNote != null &&
                            req.settlementNote!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.t('Note:'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            req.settlementNote!,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ],
                    ),
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
