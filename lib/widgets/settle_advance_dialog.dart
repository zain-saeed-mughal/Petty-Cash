import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/context_l10n.dart';
import '../models/expense_request_model.dart';
import '../providers/expense_provider.dart';

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
    final spent = widget.request.settlementAmount ?? 0.0;
    if (spent > 0) {
      _spentController.text = spent.toString();
    }
    _noteController.text = widget.request.settlementNote ?? '';
    if (widget.request.settlementMethod != null &&
        widget.request.settlementMethod!.isNotEmpty) {
      if (['Cash', 'Card'].contains(widget.request.settlementMethod)) {
        _method = widget.request.settlementMethod!;
      }
    }
    _remaining = widget.request.amount - spent;
  }

  @override
  void dispose() {
    _spentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _calculateRemaining(String val) {
    final parsed = double.tryParse(val);
    final spent = parsed != null && parsed.isFinite ? parsed : 0;
    setState(() {
      _remaining = widget.request.amount - spent;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final spent = double.parse(_spentController.text.trim());
    final expense = context.read<ExpenseProvider>();

    final success = await expense.settleAdvance(
      requestId: widget.request.id,
      settlementAmount: spent,
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
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(context.t('Settle Cash Advance')),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.t('Advance Amount')}: ${context.language.money(widget.request.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _spentController,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.t('Amount Spent'),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    onChanged: _calculateRemaining,
                    validator: (val) {
                      final num = double.tryParse(val ?? '');
                      if (num == null ||
                          !num.isFinite ||
                          !RegExp(r'^\d+(?:\.\d{1,2})?$')
                              .hasMatch((val ?? '').trim()) ||
                          num < 0 ||
                          num > widget.request.amount) {
                        return context.t(
                          'Enter a valid amount up to the advance total.',
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
                        labelText: context.t('Return Method'),
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
