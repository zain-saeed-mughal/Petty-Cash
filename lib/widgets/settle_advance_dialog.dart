import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/context_l10n.dart';
import '../models/expense_request_model.dart';
import '../providers/expense_provider.dart';
import '../config/app_theme.dart';

class SettleAdvanceDialog extends StatefulWidget {
  final ExpenseRequest request;

  const SettleAdvanceDialog({super.key, required this.request});

  @override
  State<SettleAdvanceDialog> createState() => _SettleAdvanceDialogState();
}

class _SettleAdvanceDialogState extends State<SettleAdvanceDialog> {
  final _form = GlobalKey<FormState>();
  final _spentController = TextEditingController();
  final _noteController = TextEditingController();
  String _method = 'Cash';
  bool _busy = false;
  String? _error;
  double _remaining = 0;

  @override
  void initState() {
    super.initState();
    final alreadySpent = widget.request.settlementAmount ?? 0.0;
    _remaining = widget.request.amount - alreadySpent;
  }

  @override
  void dispose() {
    _spentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _calculateRemaining(String val) {
    final parsed = double.tryParse(val);
    final newlySpent = parsed != null && parsed.isFinite ? parsed : 0;
    final alreadySpent = widget.request.settlementAmount ?? 0.0;
    setState(() {
      _remaining = widget.request.amount - alreadySpent - newlySpent;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final newlySpent = double.tryParse(_spentController.text.trim()) ?? 0;
    final alreadySpent = widget.request.settlementAmount ?? 0.0;
    final totalSpent = alreadySpent + newlySpent;
    final expense = context.read<ExpenseProvider>();

    final success = await expense.settleAdvance(
      requestId: widget.request.id,
      settlementAmount: totalSpent,
      settlementMethod: _method,
      note: _noteController.text.trim(),
      expectedVersion: widget.request.version,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error =
            expense.errorMessage ?? 'Unable to settle advance. Please retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final alreadySpent = widget.request.settlementAmount ?? 0.0;
    final startingBalance = widget.request.amount - alreadySpent;

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(context.t('Update Settlement')),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.t('Total Advance')}: ${context.language.money(widget.request.amount)}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                        ),
                        if (alreadySpent > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${context.t('Previously Logged')}: ${context.language.money(alreadySpent)}',
                            style: TextStyle(color: AppTheme.statusApproved, fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${context.t('Current Balance')}: ${context.language.money(startingBalance)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _spentController,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.t('New Expense Amount (if any)'),
                      prefixIcon: const Icon(Icons.add_shopping_cart_rounded),
                    ),
                    onChanged: _calculateRemaining,
                    validator: (val) {
                      final text = (val ?? '').trim();
                      if (text.isEmpty) return null; // Can submit without new expenses (e.g. just returning cash)
                      final num = double.tryParse(text);
                      if (num == null ||
                          !num.isFinite ||
                          !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text) ||
                          num < 0 ||
                          num > startingBalance) {
                        return context.t(
                          'Enter a valid amount up to the current balance.',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${context.t('Remaining Balance to Return')}: ${context.language.money(_remaining)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _remaining > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_remaining > 0) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      decoration: InputDecoration(
                        labelText: context.t('Return Method for Balance'),
                      ),
                      items: ['Cash', 'Card']
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(context.t(m)),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _method = v!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _noteController,
                    enabled: !_busy,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: context.t('Settlement Note'),
                      hintText: context.t('Any details about the expenses...'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.language.error(_error!),
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
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(context.t('Cancel')),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(
              _busy
                  ? context.t('Submitting...')
                  : context.t('Submit Settlement'),
            ),
          ),
        ],
      ),
    );
  }
}
