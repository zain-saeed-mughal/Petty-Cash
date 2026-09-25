import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/context_l10n.dart';
import '../models/expense_request_model.dart';
import '../models/user_model.dart';
import '../providers/expense_provider.dart';

class RequestOverrideDialog extends StatefulWidget {
  final ExpenseRequest request;
  final AppUser actor;
  const RequestOverrideDialog({
    super.key,
    required this.request,
    required this.actor,
  });
  @override
  State<RequestOverrideDialog> createState() => _RequestOverrideDialogState();
}

class _RequestOverrideDialogState extends State<RequestOverrideDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  RequestStatus? _status;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final expense = context.read<ExpenseProvider>();
    final success = await expense.overrideStatus(
      requestId: widget.request.id,
      newStatus: _status!,
      adminUser: widget.actor,
      expectedVersion: widget.request.version,
      note: _note.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = expense.errorMessage ?? 'Unable to save. Please retry.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(context.t('Super Admin Override')),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.request.itemDescription),
                const SizedBox(height: 16),
                DropdownButtonFormField<RequestStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.language.tr('force_status_to'),
                  ),
                  items: ExpenseRequest.overrideStatuses
                      .where((s) => s != widget.request.status)
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(context.t(s.displayName)),
                        ),
                      )
                      .toList(),
                  onChanged: _busy ? null : (v) => setState(() => _status = v),
                  validator: (v) =>
                      v == null ? context.t('Choose a new status') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: context.language.tr('audit_note_reason'),
                    hintText: context.language.tr('audit_note_hint'),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 5
                      ? context.t('Enter a reason of at least 5 characters')
                      : null,
                ),
                if (_error != null)
                  Text(
                    context.language.error(_error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
          onPressed: _busy ? null : _save,
          child: Text(
            _busy
                ? context.t('Saving…')
                : context.language.tr('apply_override'),
          ),
        ),
      ],
    ),
  );
}
