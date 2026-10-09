import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class RejectionReasonDialog extends StatefulWidget {
  final String requestTitle;
  final double amount;

  const RejectionReasonDialog({
    super.key,
    required this.requestTitle,
    required this.amount,
  });

  static Future<String?> show(
    BuildContext context, {
    required String requestTitle,
    required double amount,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          RejectionReasonDialog(requestTitle: requestTitle, amount: amount),
    );
  }

  @override
  State<RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<RejectionReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  final List<String> _quickReasons = [
    'Missing official tax receipt / invoice',
    'Receipt image is blurry or unreadable',
    'Amount exceeds petty cash limit for this category',
    'Duplicate request already submitted',
    'Unapproved expenditure purpose',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final primaryTextColor = isDark ? Colors.white : AppTheme.primaryNavy;
    final secondaryTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bodyTextColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    return AlertDialog(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.statusRejected
                  .withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cancel_rounded,
              color: AppTheme.statusRejected,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.t('Reject Expense Request'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: primaryTextColor,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.language.format(
                            'Item: {item} ({amount})',
                            'تفصیل: {item} ({amount})',
                            {
                              'item': widget.requestTitle,
                              'amount': context.language.money(widget.amount),
                            },
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.t(
                    'Tell the person why you sent this back.',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: bodyTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // Quick presets
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickReasons.map((preset) {
                    final isSelected =
                        _reasonController.text == context.t(preset);
                    return ActionChip(
                      label: Text(
                        context.t(preset),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? (isDark
                                  ? Colors.white
                                  : AppTheme.statusRejected)
                              : bodyTextColor,
                        ),
                      ),
                      backgroundColor: isSelected
                          ? AppTheme.statusRejected
                              .withValues(alpha: isDark ? 0.25 : 0.12)
                          : (isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9)),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.statusRejected.withValues(alpha: 0.6)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      onPressed: () {
                        setState(() {
                          _reasonController.text = context.t(preset);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryTextColor,
                  ),
                  decoration: InputDecoration(
                    labelText: context.t('Rejection Reason *'),
                    labelStyle: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                    ),
                    hintText: context.t(
                      'e.g. Please add a clear receipt photo',
                    ),
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(
                        color: AppTheme.statusRejected,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(
                        color: AppTheme.statusRejected,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return context.t(
                        'Please provide a clear reason for rejection',
                      );
                    }
                    if (val.trim().length < 5) {
                      return context.t('Reason must be at least 5 characters');
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: secondaryTextColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(context.t('Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusRejected,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.of(context).pop(_reasonController.text.trim());
                }
              },
              child: Text(
                context.t('Send back'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
