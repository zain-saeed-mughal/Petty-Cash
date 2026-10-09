import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../providers/core_flow_provider.dart';

class UserAccountDialog extends StatefulWidget {
  final AppUser actor;
  final AppUser? user;
  const UserAccountDialog({super.key, required this.actor, this.user});
  @override
  State<UserAccountDialog> createState() => _UserAccountDialogState();
}

class _UserAccountDialogState extends State<UserAccountDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _email;
  final _password = TextEditingController();
  late UserRole _role;
  String? _officeId;
  late bool _active;
  bool _busy = false, _showPassword = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.name);
    _email = TextEditingController(text: widget.user?.email);
    _role = widget.user?.role ?? UserRole.officeBoy;
    _officeId = widget.user?.officeId ?? widget.actor.officeId;
    _active = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final provider = context.read<UserProvider>();
    final name = _name.text.trim(),
        email = _email.text.trim().toLowerCase(),
        password = _password.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = widget.user == null
        ? await provider.addUser(
            name: name,
            email: email,
            password: password,
            role: _role,
            officeId: _officeId,
          )
        : await provider.updateUser(
            widget.user!.copyWith(
              name: name,
              email: email,
              password: password.isEmpty ? null : password,
              role: _role,
              isActive: _active,
              officeId: _officeId,
            ),
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) {
      Navigator.pop(context, {
        'name': name,
        'email': email,
        'password': password,
      });
    } else {
      setState(
        () => _error = provider.errorMessage ?? 'Unable to save this account.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offices = context.watch<CoreFlowProvider>().offices;
    final selectedOfficeId = offices.isNotEmpty
        ? (offices.any((o) => o.id == _officeId) ? _officeId : offices.first.id)
        : _officeId;
    if (_officeId != selectedOfficeId) {
      _officeId = selectedOfficeId;
    }
    final roles = widget.actor.isSuperAdmin
        ? UserRole.values
        : [UserRole.officeBoy, UserRole.finance];
    final selectedRole = roles.contains(_role) ? _role : roles.first;
    if (_role != selectedRole) {
      _role = selectedRole;
    }
    final self = widget.user?.uid == widget.actor.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          widget.user == null
              ? context.t('Create account')
              : context.t('Edit account'),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: context.t('Full name'),
                      helperText: context.t('Example: Sara Khan'),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? context.t('Enter a name')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    textDirection: TextDirection.ltr,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: context.t('Email address'),
                      helperText: context.t('Example: sara@example.com'),
                    ),
                    validator: (v) =>
                        v == null ||
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(v.trim())
                        ? context.t('Enter a valid email address')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    maxLength: 8,
                    textDirection: TextDirection.ltr,
                    enabled: !_busy,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: widget.user == null
                          ? context.t('Temporary password')
                          : context.t('New password (optional)'),
                      helperText: context.t('6 to 8 characters'),
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? context.t('Hide password')
                            : context.t('Show password'),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (widget.user == null || (v?.isNotEmpty ?? false)) &&
                            ((v?.length ?? 0) < 6 || (v?.length ?? 0) > 8)
                        ? context.t('Use 6 to 8 characters')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (offices.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedOfficeId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.t('Office'),
                        helperText: context.t('Choose this person\'s office'),
                      ),
                      items: offices
                          .map(
                            (office) => DropdownMenuItem(
                              value: office.id,
                              child: Text(
                                office.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy || !widget.actor.isSuperAdmin
                          ? null
                          : (value) => setState(() => _officeId = value),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.t('Role'),
                      helperText: context.t('Choose what this person can do'),
                    ),
                    items: roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              context.t(r.displayName),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy || self
                        ? null
                        : (v) {
                            if (v != null) setState(() => _role = v);
                          },
                  ),
                  if (widget.user != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('Account active')),
                      value: _active,
                      onChanged: _busy || self
                          ? null
                          : (v) => setState(() => _active = v),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        context.language.error(_error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: Text(context.t('Cancel')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          context.t('Save account'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
