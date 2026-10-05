import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petty_cash/config/app_theme.dart';
import 'package:petty_cash/providers/language_provider.dart';

class AppStatusBadge extends StatelessWidget {
  final String status;
  final bool isCompact;

  const AppStatusBadge({super.key, required this.status, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;
    IconData icon;
    String labelEn;
    String labelUr;

    final normalized = status.toLowerCase();

    switch (normalized) {
      case 'pending':
      case 'pending_finance_review':
        textColor = AppTheme.statusPending;
        bgColor = AppTheme.statusPendingBg;
        icon = Icons.hourglass_top_rounded;
        labelEn = 'Pending';
        labelUr = 'زیر التوا';
        break;
      case 'awaiting_office_boy_approval':
        textColor = AppTheme.statusPending;
        bgColor = AppTheme.statusPendingBg;
        icon = Icons.touch_app_rounded;
        labelEn = 'Needs Approval';
        labelUr = 'منظوری درکار ہے';
        break;
      case 'cleared':
      case 'payment cleared':
      case 'approved':
      case 'received':
        textColor = AppTheme.statusApproved;
        bgColor = AppTheme.statusApprovedBg;
        icon = Icons.check_circle_outline_rounded;
        labelEn = 'Approved';
        labelUr = 'منظور شدہ';
        if (normalized == 'cleared') {
          labelEn = 'Cleared';
          labelUr = 'مل گئی';
        }
        break;
      case 'paid':
        textColor = AppTheme.statusPaid;
        bgColor = AppTheme.statusPaidBg;
        icon = Icons.verified_rounded;
        labelEn = 'Paid';
        labelUr = 'ادا شدہ';
        break;
      case 'fully_utilized':
        textColor = AppTheme.primaryNavy;
        bgColor = AppTheme.borderLight;
        icon = Icons.done_all_rounded;
        labelEn = 'Fully Used';
        labelUr = 'استعمال شدہ';
        break;
      case 'rejected':
      case 'declined':
        textColor = AppTheme.statusRejected;
        bgColor = AppTheme.statusRejectedBg;
        icon = Icons.cancel_outlined;
        labelEn = normalized == 'declined' ? 'Declined' : 'Rejected';
        labelUr = 'مسترد';
        break;
      case 'rejection acknowledged':
        textColor = AppTheme.statusApproved;
        bgColor = AppTheme.statusApprovedBg;
        icon = Icons.fact_check_outlined;
        labelEn = 'Acknowledged';
        labelUr = 'تسلیم شدہ';
        break;
      default:
        textColor = AppTheme.statusPending;
        bgColor = AppTheme.statusPendingBg;
        icon = Icons.info_outline;
        labelEn = status;
        labelUr = status;
        break;
    }

    final isUrdu = context.watch<LanguageProvider>().isRtl;
    final displayLabel = isUrdu ? labelUr : labelEn;

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
              displayLabel,
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
            displayLabel,
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
