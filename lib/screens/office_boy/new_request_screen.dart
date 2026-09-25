import 'package:petty_cash/l10n/context_l10n.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../services/app_error.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/storage_service.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../widgets/receipt_viewer_dialog.dart';

class NewRequestScreen extends StatefulWidget {
  final VoidCallback? onRequestSubmitted;

  const NewRequestScreen({super.key, this.onRequestSubmitted});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isSubmitting = false;
  String _requestId = const Uuid().v4();
  String? _uploadedPath;
  String _requestType = 'reimbursement';

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSubmitting) return;
    try {
      final file = await StorageService().pickReceiptImage(source: source);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        if (bytes.length > StorageService.maxUploadBytes) {
          throw StateError(context.t("Choose an image under 10 MB."));
        }
        StorageService.imageMime(bytes);
        _discardUploadedReceipt();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.language.error(userMessage(e)))),
        );
      }
    }
  }

  void _discardUploadedReceipt() {
    final path = _uploadedPath;
    _uploadedPath = null;
    if (path != null) {
      StorageService().removeUnusedReceipt(path).catchError((Object _) {});
    }
  }

  void _clearImage() {
    _discardUploadedReceipt();
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().currentUser;
    final expense = context.read<ExpenseProvider>();
    if (user == null) return;
    final item = _itemController.text.trim(),
        reason = _reasonController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount >= 10000000000 ||
        (amount * 100 - (amount * 100).round()).abs() > 0.00001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Enter a positive amount with at most two decimal places.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      if (_selectedImageBytes != null && _uploadedPath == null) {
        _uploadedPath = await StorageService().uploadReceiptImage(
          imageBytes: _selectedImageBytes!,
          fileName: _selectedImageName ?? 'receipt',
        );
      }
      if (!mounted) return;
      final success = await expense.submitRequest(
        user: user,
        itemDescription: item,
        amount: amount,
        reason: reason,
        billImageUrl: _uploadedPath,
        requestId: _requestId,
        requestType: _requestType,
      );
      if (!mounted) return;
      if (!success) {
        throw StateError(
          expense.errorMessage ?? 'Unable to submit. Please retry.',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('Request submitted for approval.'))),
      );
      _requestId = const Uuid().v4();
      _uploadedPath = null;
      _itemController.clear();
      _amountController.clear();
      _reasonController.clear();
      _clearImage();
      widget.onRequestSubmitted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.language.error(userMessage(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.tr('submit_expense_title'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            lang.tr('submit_expense_subtitle'),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form
              Container(
                padding: EdgeInsets.all(isDesktop ? 28 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            segments: [
                              ButtonSegment(
                                value: 'reimbursement',
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    lang.text('Reimbursement'),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                              ),
                              ButtonSegment(
                                value: 'advance',
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    lang.text('Cash Advance'),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                              ),
                            ],
                            selected: {_requestType},
                            onSelectionChanged: _isSubmitting
                                ? null
                                : (val) {
                                    setState(() {
                                      _requestType = val.first;
                                    });
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Item Description
                      Text(
                        lang.tr('item_desc_label'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        enabled: !_isSubmitting,
                        controller: _itemController,
                        decoration: InputDecoration(
                          hintText: lang.tr('item_desc_hint'),
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return lang.tr('item_desc_error');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Amount Spent
                      Text(
                        lang.tr('amount_label'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        enabled: !_isSubmitting,
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(
                              left: 14,
                              right: 6,
                              top: 12,
                            ),
                            child: Text(
                              context.language.isRtl
                                  ? 'روپے '
                                  : AppConstants.defaultCurrencySymbol,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          ),
                          hintText: '0.00',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return lang.tr('amount_empty_error');
                          }
                          final value = double.tryParse(val.trim());
                          if (value == null || !value.isFinite || value <= 0) {
                            return lang.tr('amount_invalid_error');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Purpose / Reason
                      Text(
                        lang.tr('purpose_label'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        enabled: !_isSubmitting,
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: lang.tr('purpose_hint'),
                          alignLabelWithHint: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return lang.tr('purpose_error');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Bill / Receipt Photo Upload Section
                      Text(
                        lang.tr('receipt_label'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Image Preview or Empty State
                      if (_selectedImageBytes != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.statusApproved,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedImageName ??
                                          context.t('Receipt Attached'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    child: Text(
                                      context.t('View Full'),
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    onPressed: () {
                                      final url =
                                          'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}';
                                      ReceiptViewerDialog.show(
                                        context,
                                        imageUrl: url,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppTheme.statusRejected,
                                    ),
                                    tooltip: context.t('Remove'),
                                    onPressed: _isSubmitting
                                        ? null
                                        : _clearImage,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  final url =
                                      'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}';
                                  ReceiptViewerDialog.show(
                                    context,
                                    imageUrl: url,
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 180,
                                    width: double.infinity,
                                    color: Colors.black12,
                                    child: _selectedImageBytes != null
                                        ? Image.memory(
                                            _selectedImageBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.t('Upload Bill or Receipt Photo'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.t('PNG, JPG, or JPEG up to 10MB'),
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        context.t('Gallery'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed: () =>
                                          _pickImage(ImageSource.gallery),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        context.t('Camera'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed: () =>
                                          _pickImage(ImageSource.camera),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 62),
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitRequest,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isSubmitting)
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  const Icon(Icons.send_rounded),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _isSubmitting
                                        ? lang.tr('submitting')
                                        : lang.tr('submit_btn'),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
