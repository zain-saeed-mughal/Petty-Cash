import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
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
  String? _presetImageUrl;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await StorageService().pickReceiptImage(source: source);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
          _presetImageUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _chooseSampleBill(String url, String name) {
    setState(() {
      _presetImageUrl = url;
      _selectedImageBytes = null;
      _selectedImageName = name;
    });
  }

  void _clearImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _presetImageUrl = null;
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final expense = Provider.of<ExpenseProvider>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session expired. Please sign in again.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? uploadedUrl = _presetImageUrl;

    // Upload picked image if present
    if (_selectedImageBytes != null) {
      final filename = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      uploadedUrl = await StorageService().uploadReceiptImage(
        imageBytes: _selectedImageBytes!,
        fileName: filename,
      );
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final success = await expense.submitRequest(
      user: user,
      itemDescription: _itemController.text.trim(),
      amount: amount,
      reason: _reasonController.text.trim(),
      billImageUrl: uploadedUrl,
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense request submitted successfully! Status is now Pending.'),
          backgroundColor: AppTheme.statusApproved,
        ),
      );

      // Clear Form
      _itemController.clear();
      _amountController.clear();
      _reasonController.clear();
      _clearImage();

      widget.onRequestSubmitted?.call();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(expense.errorMessage ?? 'Failed to submit request'),
          backgroundColor: AppTheme.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Submit Petty Cash Expense',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Fill in the details, attach bill/receipt photo, and send for Finance approval.',
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
                      // Item Description
                      const Text(
                        'Item Description *',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _itemController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. A4 Copy Paper, Kitchen Coffee & Milk, Hardware Repair...',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please describe the item or service';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Amount Spent
                      const Text(
                        'Amount Spent *',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(left: 14, right: 6, top: 12),
                            child: Text(
                              AppConstants.defaultCurrencySymbol,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                            ),
                          ),
                          hintText: '0.00',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter the amount spent';
                          final num? parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) return 'Please enter a valid amount greater than 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Purpose / Reason
                      const Text(
                        'Purpose / Reason for Purchase *',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Explain why this expenditure was required (e.g. Pantry weekly replenishment, client visitor refreshments...)',
                          alignLabelWithHint: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please explain the reason for this expense';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Bill / Receipt Photo Upload Section
                      const Text(
                        'Bill / Receipt Photo (Optional but Recommended)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 8),

                      // Image Preview or Empty State
                      if (_selectedImageBytes != null || _presetImageUrl != null) ...[
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
                                  const Icon(Icons.check_circle_rounded, color: AppTheme.statusApproved, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedImageName ?? 'Receipt Attached',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.zoom_in, size: 16),
                                    label: const Text('View Full'),
                                    onPressed: () {
                                      final url = _presetImageUrl ??
                                          'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}';
                                      ReceiptViewerDialog.show(context, imageUrl: url);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.statusRejected),
                                    tooltip: 'Remove',
                                    onPressed: _clearImage,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  final url = _presetImageUrl ??
                                      'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}';
                                  ReceiptViewerDialog.show(context, imageUrl: url);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 180,
                                    width: double.infinity,
                                    color: Colors.black12,
                                    child: _selectedImageBytes != null
                                        ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                                        : Image.network(_presetImageUrl!, fit: BoxFit.cover),
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
                              const Icon(Icons.add_photo_alternate_outlined, size: 40, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              const Text(
                                'Upload Bill or Receipt Photo',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.primaryNavy),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'PNG, JPG, or JPEG up to 10MB',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                                    label: const Text('Choose Photo'),
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                    label: const Text('Use Camera'),
                                    onPressed: () => _pickImage(ImageSource.camera),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Preset demo receipts for testing
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: StorageService.sampleBills.map((bill) {
                                  return ActionChip(
                                    avatar: const Icon(Icons.receipt, size: 14),
                                    label: Text(bill['title']!, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => _chooseSampleBill(bill['url']!, bill['title']!),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(_isSubmitting ? 'Submitting Expense Request...' : 'Submit Expense Request'),
                          onPressed: _isSubmitting ? null : _submitRequest,
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
