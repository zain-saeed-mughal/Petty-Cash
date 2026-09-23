import 'package:flutter/material.dart';

import '../models/expense_request_model.dart';
import '../config/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final RequestStatus status;
  final bool isCompact;

  const StatusBadge({super.key, required this.status, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;
    IconData icon;

    switch (status) {
      case RequestStatus.pending:
        textColor = AppTheme.statusPending;
        bgColor = AppTheme.statusPendingBg;
        icon = Icons.hourglass_top_rounded;
        break;
      case RequestStatus.approved:
        textColor = AppTheme.statusApproved;
        bgColor = AppTheme.statusApprovedBg;
        icon = Icons.check_circle_outline_rounded;
        break;
      case RequestStatus.rejected:
        textColor = AppTheme.statusRejected;
        bgColor = AppTheme.statusRejectedBg;
        icon = Icons.cancel_outlined;
        break;
      case RequestStatus.paid:
        textColor = AppTheme.statusApproved;
        bgColor = AppTheme.statusApprovedBg;
        icon = Icons.verified_rounded;
        break;
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              status.displayName,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
