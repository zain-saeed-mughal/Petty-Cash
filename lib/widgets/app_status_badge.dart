import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petty_cash/config/app_theme.dart';
import 'package:petty_cash/providers/language_provider.dart';

class AppStatusBadge extends StatelessWidget {
  final String status;
  final bool isCompact;
  /// Set to true when the badge is shown to the person who *received* the money
  /// (e.g. Office Boy's own advance card). Changes 'Sent' → 'Received'.
  final bool isRecipient;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
    this.isRecipient = false,
  });

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
        labelEn = 'Waiting';
        labelUr = 'انتظار میں';
        break;
      case 'awaiting_office_boy_approval':
        textColor = AppTheme.statusPending;
        bgColor = AppTheme.statusPendingBg;
        if (isRecipient) {
          icon = Icons.touch_app_rounded;
          labelEn = 'Confirm receipt';
          labelUr = 'وصولی بتائیں';
        } else {
          icon = Icons.hourglass_top_rounded;
          labelEn = 'Awaiting confirmation';
          labelUr = 'تصدیق کا انتظار';
        }
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
          if (isRecipient) {
            labelEn = 'Received';
            labelUr = 'پیسے مل گئے';
          } else {
            labelEn = 'Sent';
            labelUr = 'بھیج دی';
          }
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
        labelEn = 'All done';
        labelUr = 'مکمل';
        break;
      case 'rejected':
      case 'declined':
        textColor = AppTheme.statusRejected;
        bgColor = AppTheme.statusRejectedBg;
        icon = Icons.cancel_outlined;
        labelEn = normalized == 'declined' ? 'Not accepted' : 'Sent back';
        labelUr = normalized == 'declined' ? 'منظور نہیں' : 'واپس';
        break;
      case 'rejection acknowledged':
        textColor = AppTheme.statusApproved;
        bgColor = AppTheme.statusApprovedBg;
        icon = Icons.fact_check_outlined;
        labelEn = 'Seen';
        labelUr = 'دیکھ لیا';
        break;
      default:
        textColor = AppTheme.statusPending;
        bgColor = AppTheme.statusPendingBg;
        icon = Icons.info_outline;
        labelEn = 'In progress';
        labelUr = 'جاری ہے';
        break;
    }

    final isUrdu = context.watch<LanguageProvider>().isRtl;
    final displayLabel = isUrdu ? labelUr : labelEn;

    if (isCompact) {
      return Tooltip(
        message: displayLabel,
        child: Container(
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
              Flexible(
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
