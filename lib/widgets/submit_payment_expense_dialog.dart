import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/payment_provider.dart';
import '../services/storage_service.dart';
import '../config/app_theme.dart';

String paymentText(BuildContext context, String en, String ur) =>
    context.read<LanguageProvider>().isRtl ? ur : en;

class SubmitPaymentExpenseDialog extends StatefulWidget {
  final String initialFlowType;
  const SubmitPaymentExpenseDialog({super.key, this.initialFlowType = 'float'});

  @override
  State<SubmitPaymentExpenseDialog> createState() =>
      _SubmitPaymentExpenseDialogState();
}

class _SubmitPaymentExpenseDialogState
    extends State<SubmitPaymentExpenseDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _item = TextEditingController();
  final _reason = TextEditingController();
  late String _flowType = widget.initialFlowType;
  String? _advanceId;
  final String _expenseId = const Uuid().v4();
  String? _uploadedPath;
  Uint8List? _imageBytes;
  bool _busy = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = StorageService();
    try {
      final file = await picker.pickReceiptImage(source: source);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final oldPath = _uploadedPath;
        _uploadedPath = null;
        if (oldPath != null) {
          await StorageService().removeUnusedReceipt(oldPath);
        }
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _removeImage() {
    final unused = _uploadedPath;
    _uploadedPath = null;
    if (unused != null) {
      StorageService().removeUnusedReceipt(unused).catchError((Object _) {});
    }
    setState(() => _imageBytes = null);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_flowType == 'float' && _advanceId == null) return;
    setState(() => _busy = true);

    final provider = context.read<PaymentProvider>();
    String? billPath;
    try {
      if (_imageBytes != null && _uploadedPath == null) {
        _uploadedPath = await StorageService().uploadReceiptImage(
          imageBytes: _imageBytes!,
          fileName: 'receipt',
        );
      }
      billPath = _uploadedPath;
      if (!mounted) return;

      final ok = await provider.submitExpense(
        id: _expenseId,
        flowType: _flowType,
        advanceId: _flowType == 'float' ? _advanceId : null,
        item: _item.text.trim(),
        amount: double.parse(_amount.text.trim()),
        reason: _reason.text.trim(),
        billPath: billPath,
      );

      if (!mounted) return;
      if (ok) {
        _uploadedPath = null;
        Navigator.pop(context, true);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    final unused = _uploadedPath;
    if (unused != null) {
      StorageService().removeUnusedReceipt(unused).catchError((Object _) {});
    }
    _amount.dispose();
    _item.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payments = context.watch<PaymentProvider>();
    final actorId = context.read<AuthProvider>().currentUser?.uid;
    final globalAvailable =
        payments.overview
            .where((row) => row.officeBoyId == actorId)
            .firstOrNull
            ?.availableBalance ??
        0.0;
    final available = payments.advanceBalances
        .where((row) => row.available > 0 && globalAvailable > 0)
        .toList();
    final selected = available
        .where((row) => row.advanceId == _advanceId)
        .firstOrNull;
    final selectedLimit = selected == null
        ? 0.0
        : (selected.available < globalAvailable
              ? selected.available
              : globalAvailable);
    return AlertDialog(
      title: Text(paymentText(context, 'Add Expense', 'خرچہ شامل کریں')),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _flowType,
                  decoration: InputDecoration(
                    labelText: paymentText(
                      context,
                      'Expense Type',
                      'خرچے کی قسم',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'float',
                      child: Text(
                        paymentText(
                          context,
                          'Paid from an advance',
                          'ایڈوانس سے ادا کیا',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'reimbursement',
                      child: Text(
                        paymentText(
                          context,
                          'Paid from my own pocket',
                          'اپنی جیب سے ادا کیا',
                        ),
                      ),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() {
                              _flowType = v;
                              _advanceId = null;
                            });
                          }
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  _flowType == 'float'
                      ? paymentText(
                          context,
                          'Choose the advance used for this purchase. The amount is reserved until Finance reviews it.',
                          'جس ایڈوانس سے خریداری کی، وہ منتخب کریں۔ فنانس کے فیصلے تک رقم روک دی جائے گی۔',
                        )
                      : paymentText(
                          context,
                          'You paid from your own pocket. Finance will review and repay you separately.',
                          'آپ نے اپنی جیب سے ادا کیا ہے۔ فنانس اس کا الگ حساب رکھ کر رقم واپس کرے گا۔',
                        ),
                ),
                if (_flowType == 'float') ...[
                  const SizedBox(height: 14),
                  if (available.isEmpty)
                    Text(
                      paymentText(
                        context,
                        'No received advance has an available balance. Request an advance or wait for receipt confirmation.',
                        'کسی موصولہ ایڈوانس میں رقم دستیاب نہیں۔ ایڈوانس مانگیں یا وصولی کی تصدیق کریں۔',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selected?.advanceId,
                      decoration: InputDecoration(
                        labelText: paymentText(
                          context,
                          'Paid from which advance?',
                          'کس ایڈوانس سے ادا کیا؟',
                        ),
                      ),
                      items: available
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.advanceId,
                              child: Text(
                                '${entry.advanceId.substring(0, 8)} · ${context.read<LanguageProvider>().money(entry.available < globalAvailable ? entry.available : globalAvailable)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _advanceId = value),
                      validator: (value) => value == null
                          ? paymentText(
                              context,
                              'Select an advance.',
                              'ایڈوانس منتخب کریں۔',
                            )
                          : null,
                    ),
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${paymentText(context, 'Available for this purchase', 'اس خریداری کے لیے دستیاب')}: ${context.read<LanguageProvider>().money(selectedLimit)}',
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _item,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: paymentText(context, 'Item Name', 'آئٹم کا نام'),
                    helperText: paymentText(
                      context,
                      'Example: printer paper',
                      'مثال: پرنٹر کا کاغذ',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return paymentText(
                        context,
                        'Please enter an item name.',
                        'براہ کرم آئٹم کا نام درج کریں۔',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: paymentText(
                      context,
                      'Amount (PKR)',
                      'رقم (روپے)',
                    ),
                    helperText: paymentText(
                      context,
                      'Example: 500',
                      'مثال: ۵۰۰',
                    ),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null ||
                        !parsed.isFinite ||
                        parsed <= 0 ||
                        parsed >= 10000000000 ||
                        !RegExp(r'^\d+(?:\.\d{1,2})?$')
                            .hasMatch(value?.trim() ?? '')) {
                      return paymentText(
                        context,
                        'Enter a valid positive amount.',
                        'درست مثبت رقم درج کریں۔',
                      );
                    }
                    if (_flowType == 'float' &&
                        selected != null &&
                        parsed > selectedLimit) {
                      return paymentText(
                        context,
                        'Amount exceeds this advance balance.',
                        'رقم اس ایڈوانس کے بیلنس سے زیادہ ہے۔',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reason,
                  maxLength: 2000,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: paymentText(
                      context,
                      'Reason / Description',
                      'وجہ / تفصیل',
                    ),
                    helperText: paymentText(
                      context,
                      'Example: printer paper ran out',
                      'مثال: پرنٹر کا کاغذ ختم ہو گیا تھا',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return paymentText(
                        context,
                        'Please enter a reason.',
                        'براہ کرم وجہ درج کریں۔',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  paymentText(
                    context,
                    'Receipt Photo (optional)',
                    'رسید کی تصویر (اختیاری)',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                if (_imageBytes != null)
                  Stack(
                    children: [
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                          image: DecorationImage(
                            image: MemoryImage(_imageBytes!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _busy ? null : _removeImage,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final camera = OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                          paymentText(context, 'Camera', 'کیمرہ'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                      final gallery = OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.image),
                        label: Text(
                          paymentText(context, 'Gallery', 'گیلری'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                      if (constraints.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            camera,
                            const SizedBox(height: 8),
                            gallery,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: camera),
                          const SizedBox(width: 12),
                          Expanded(child: gallery),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(paymentText(context, 'Cancel', 'منسوخ')),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(paymentText(context, 'Submit', 'جمع کریں')),
        ),
      ],
    );
  }
}
