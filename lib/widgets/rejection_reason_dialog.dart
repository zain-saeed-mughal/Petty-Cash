import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/app_constants.dart';

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
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.cancel_rounded, color: AppTheme.statusRejected),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Reject Expense Request',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.primaryNavy,
            ),
          )),
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
                Text(
                  'Item: "${widget.requestTitle}" (${AppConstants.defaultCurrencySymbol}${widget.amount.toStringAsFixed(2)})',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A mandatory explanation is required. The requester will see this reason on their dashboard.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 14),

                // Quick presets
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickReasons.map((preset) {
                    return ActionChip(
                      label: Text(preset, style: const TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onPressed: () {
                        setState(() {
                          _reasonController.text = preset;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    hintText: 'e.g. Please provide a stamped tax receipt or get prior supervisor approval...',
                    alignLabelWithHint: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a clear reason for rejection';
                    }
                    if (val.trim().length < 5) {
                      return 'Reason must be at least 5 characters';
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.statusRejected,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reasonController.text.trim());
            }
          },
          child: const Text('Confirm Rejection'),
        ),
      ],
    );
  }
}
