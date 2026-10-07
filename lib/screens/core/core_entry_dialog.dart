import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/core_flow_models.dart';
import '../../providers/core_flow_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';

import '../../services/storage_service.dart';

String coreText(BuildContext context, String en, String ur) =>
    context.read<LanguageProvider>().isRtl ? ur : en;

class CoreEntryDialog extends StatefulWidget {
  final String mode; // advance, item, reimbursement
  final CoreAdvance? advance;
  const CoreEntryDialog({super.key, required this.mode, this.advance});

  @override
  State<CoreEntryDialog> createState() => _CoreEntryDialogState();
}

class _CoreEntryDialogState extends State<CoreEntryDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _accountName = TextEditingController();
  final _accountDetails = TextEditingController();
  final _id = const Uuid().v4();
  String _method = 'cash';
  String? _uploadedPath;
  Uint8List? _imageBytes;
  bool _busy = false;
  String? _error;
  String? _officeBoyId;
  String? _taggedManagerId;

  @override
  void dispose() {
    final unused = _uploadedPath;
    if (unused != null) {
      StorageService().removeUnusedReceipt(unused).catchError((Object _) {});
    }
    _description.dispose();
    _amount.dispose();
    _accountName.dispose();
    _accountDetails.dispose();
    super.dispose();
  }

  Future<void> _pickBill(ImageSource source) async {
    try {
      final file = await StorageService().pickReceiptImage(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > StorageService.maxUploadBytes) {
        throw StateError(
          coreText(
            context,
            'Choose an image under 10 MB.',
            '10 ایم بی سے چھوٹی تصویر منتخب کریں۔',
          ),
        );
      }
      if (!mounted) return;
      final old = _uploadedPath;
      _uploadedPath = null;
      if (old != null) await StorageService().removeUnusedReceipt(old);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _removeBill() async {
    final old = _uploadedPath;
    setState(() {
      _uploadedPath = null;
      _imageBytes = null;
    });
    if (old != null) await StorageService().removeUnusedReceipt(old);
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null) return;
    if (widget.mode == 'item') {
      final remaining =
          context
              .read<CoreFlowProvider>()
              .balanceForAdvance(widget.advance!.id)
              ?.remaining ??
          0;
      if (amount > remaining) {
        setState(
          () => _error = coreText(
            context,
            'This exceeds your remaining advance balance.',
            'یہ رقم آپ کے باقی ایڈوانس سے زیادہ ہے۔',
          ),
        );
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_imageBytes != null && _uploadedPath == null) {
        _uploadedPath = await StorageService().uploadReceiptImage(
          imageBytes: _imageBytes!,
          fileName: 'bill',
        );
      }
      if (!mounted) return;
      final flows = context.read<CoreFlowProvider>();
      final description = _description.text.trim();
      final accountName = _method == 'card' ? _accountName.text.trim() : null;
      final accountDetails = _method == 'card'
          ? _accountDetails.text.trim()
          : null;
      final saved = switch (widget.mode) {
        'advance' => await flows.requestAdvance(
          id: _id,
          purpose: description,
          amount: amount,
          method: _method,
          accountName: accountName,
          accountDetails: accountDetails,
        ),
        'direct_advance' => await flows.directAllotAdvance(
          id: _id,
          officeBoyId: _officeBoyId!,
          purpose: description,
          amount: amount,
          method: _method,
        ),
        'item' => await flows.addItem(
          id: _id,
          advanceId: widget.advance!.id,
          item: description,
          amount: amount,
          billPath: _uploadedPath,
          taggedManagerId: _taggedManagerId,
        ),
        _ => await flows.requestReimbursement(
          id: _id,
          item: description,
          amount: amount,
          method: _method,
          billPath: _uploadedPath,
          accountName: accountName,
          accountDetails: accountDetails,
          taggedManagerId: _taggedManagerId,
        ),
      };
      if (!mounted) return;
      if (saved) {
        _uploadedPath = null;
        Navigator.pop(context, true);
      } else {
        setState(
          () => _error = context.read<LanguageProvider>().error(
            flows.error ?? 'Could not save. Please try again.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = context.read<LanguageProvider>().error(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDirectAdvance = widget.mode == 'direct_advance';
    final isAdvance = widget.mode == 'advance' || isDirectAdvance;
    final isItem = widget.mode == 'item';
    final isReimbursement = widget.mode == 'reimbursement';
    final showAccount = !isItem && _method == 'card' && !isDirectAdvance;
    final managers = context.watch<UserProvider>().allUsers.where((u) => u.isManager).toList();
    return AlertDialog(
      title: Text(
        isAdvance
            ? coreText(context, 'Request Advance', 'ایڈوانس مانگیں')
            : isItem
            ? coreText(context, 'Add Purchase', 'خریداری درج کریں')
            : coreText(
                context,
                'I Bought Something Myself',
                'میں نے اپنی رقم سے خریدا',
              ),
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isItem)
                  Text(
                    '${widget.advance!.purpose} · ${context.read<LanguageProvider>().money(context.watch<CoreFlowProvider>().balanceForAdvance(widget.advance!.id)?.remaining ?? 0)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                if (isDirectAdvance)
                  DropdownButtonFormField<String>(
                    initialValue: _officeBoyId,
                    decoration: InputDecoration(
                      labelText: coreText(context, 'Select Office Boy', 'آفس بوائے منتخب کریں'),
                      helperText: coreText(
                        context,
                        'Choose who will receive the money',
                        'رقم وصول کرنے والے شخص کو چنیں',
                      ),
                    ),
                    items: context
                        .read<UserProvider>()
                        .allUsers
                        .where((u) => u.role.name == 'officeBoy')
                        .map((u) => DropdownMenuItem(value: u.uid, child: Text(u.name)))
                        .toList(),
                    onChanged: (val) => setState(() => _officeBoyId = val),
                    validator: (value) => value == null ? coreText(context, 'Please select an office boy', 'براہِ کرم آفس بوائے منتخب کریں') : null,
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  maxLength: isAdvance ? 2000 : 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: isAdvance
                        ? coreText(
                            context,
                            'What do you need it for?',
                            'رقم کس کام کے لیے چاہیے؟',
                          )
                        : coreText(
                            context,
                            'What did you buy?',
                            'آپ نے کیا خریدا؟',
                          ),
                    helperText: isAdvance
                        ? coreText(
                            context,
                            'Example: office supplies',
                            'مثال: دفتر کا سامان',
                          )
                        : coreText(
                            context,
                            'Example: paper and printer ink',
                            'مثال: کاغذ اور پرنٹر کی سیاہی',
                          ),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? coreText(
                          context,
                          'Please enter a description.',
                          'براہِ کرم تفصیل لکھیں۔',
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: coreText(
                      context,
                      'Amount in rupees',
                      'رقم روپے میں',
                    ),
                    helperText: coreText(
                      context,
                      'Example: 500',
                      'مثال: ۵۰۰',
                    ),
                    prefixText: 'Rs. ',
                  ),
                  validator: (value) {
                    final number = double.tryParse(value?.trim() ?? '');
                    if (number == null ||
                        !number.isFinite ||
                        number <= 0 ||
                        number >= 10000000000 ||
                        !RegExp(r'^\d+(\.\d{1,2})?$')
                            .hasMatch(value?.trim() ?? '')) {
                      return coreText(
                        context,
                        'Enter a valid amount, up to 2 decimals.',
                        'درست رقم لکھیں، دو اعشاری ہندسوں تک۔',
                      );
                    }
                    return null;
                  },
                ),
                if (!isItem) ...[
                  const SizedBox(height: 16),
                  Text(
                    coreText(
                      context,
                      'How should Finance pay?',
                      'فنانس رقم کیسے دے؟',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _MethodCard(
                          label: coreText(context, 'Cash', 'نقد'),
                          icon: Icons.payments_outlined,
                          selected: _method == 'cash',
                          onTap: () => setState(() => _method = 'cash'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MethodCard(
                          label: coreText(context, 'Card', 'کارڈ'),
                          icon: Icons.credit_card_outlined,
                          selected: _method == 'card',
                          onTap: () => setState(() => _method = 'card'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (showAccount) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountName,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: coreText(
                        context,
                        'Account name (optional)',
                        'اکاؤنٹ کا نام (اختیاری)',
                      ),
                      helperText: coreText(
                        context,
                        'Name on the account',
                        'اکاؤنٹ پر درج نام',
                      ),
                    ),
                    validator: (value) => null,
                  ),
                  TextFormField(
                    controller: _accountDetails,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: coreText(
                        context,
                        'Account details (optional)',
                        'اکاؤنٹ کی تفصیل (اختیاری)',
                      ),
                      helperText: coreText(
                        context,
                        'Example: account or IBAN number',
                        'مثال: اکاؤنٹ یا آئی بین نمبر',
                      ),
                    ),
                    validator: (value) => null,
                  ),
                ],
                if (isItem || isReimbursement) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _taggedManagerId,
                    decoration: InputDecoration(
                      labelText: coreText(context, 'Tag to Manager (Optional)', 'مینیجر کو ٹیگ کریں (اختیاری)'),
                      helperText: coreText(
                        context,
                        'Choose who should review this',
                        'جائزہ لینے والے کو چنیں',
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(coreText(context, 'None', 'کوئی نہیں')),
                      ),
                      ...managers.map((m) => DropdownMenuItem(
                        value: m.uid,
                        child: Text(m.name, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _taggedManagerId = v),
                  ),
                ],
                if (!isAdvance) ...[
                  const SizedBox(height: 12),
                  Text(
                    coreText(
                      context,
                      'Bill photo (optional)',
                      'بل کی تصویر (اختیاری)',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickBill(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(coreText(context, 'Camera', 'کیمرہ')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickBill(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(coreText(context, 'Gallery', 'گیلری')),
                      ),
                    ],
                  ),
                  if (_imageBytes != null)
                    Text(
                      coreText(
                        context,
                        'Bill photo selected',
                        'بل کی تصویر منتخب ہو گئی',
                      ),
                    ),
                  if (_imageBytes != null)
                    TextButton.icon(
                      onPressed: _busy ? null : _removeBill,
                      icon: const Icon(Icons.close),
                      label: Text(
                        coreText(context, 'Remove photo', 'تصویر ہٹائیں'),
                      ),
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(coreText(context, 'Cancel', 'منسوخ کریں')),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isItem
                      ? coreText(context, 'Save Purchase', 'خریداری محفوظ کریں')
                      : coreText(context, 'Send Request', 'درخواست بھیجیں'),
                ),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _MethodCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE2E9FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFF3159E8) : const Color(0xFFD8DFE8),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}
