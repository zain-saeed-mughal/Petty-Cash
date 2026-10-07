import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/submit_payment_expense_dialog.dart';

String _label(BuildContext context, String en, String ur) =>
    context.read<LanguageProvider>().isRtl ? ur : en;

class NewRequestScreen extends StatelessWidget {
  final VoidCallback? onRequestSubmitted;
  const NewRequestScreen({super.key, this.onRequestSubmitted});

  Future<void> _openExpense(BuildContext context, String flow) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SubmitPaymentExpenseDialog(initialFlowType: flow),
    );
    if (saved == true) onRequestSubmitted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final payments = context.watch<PaymentProvider>();
    final actor = context.watch<AuthProvider>().currentUser;
    final language = context.watch<LanguageProvider>();
    final total = payments.overview
        .where((row) => row.officeBoyId == actor?.uid)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(
                    context,
                    'What do you need to do?',
                    'آپ کیا کرنا چاہتے ہیں؟',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _label(
                    context,
                    'Choose where the money comes from. Each type is tracked separately.',
                    'رقم کہاں سے آئی؟ ہر قسم کا حساب الگ رکھا جائے گا۔',
                  ),
                ),
                const SizedBox(height: 20),
                if (payments.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      language.error(payments.error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                _ChoiceCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: _label(
                    context,
                    'I need money in advance',
                    'مجھے پہلے ایڈوانس چاہیے',
                  ),
                  subtitle: _label(
                    context,
                    'Ask Finance for an amount. After approval, confirm the money you received.',
                    'فنانس سے رقم مانگیں۔ منظوری کے بعد وصولی کی تصدیق کریں۔',
                  ),
                  action: _label(context, 'Request advance', 'ایڈوانس مانگیں'),
                  onPressed: () async {
                    final saved = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const _RequestAdvanceDialog(),
                    );
                    if (saved == true) onRequestSubmitted?.call();
                  },
                ),
                const SizedBox(height: 12),
                _ChoiceCard(
                  icon: Icons.shopping_bag_outlined,
                  title: _label(
                    context,
                    'I spent from an advance',
                    'میں نے ایڈوانس سے خرچ کیا',
                  ),
                  subtitle: _label(
                    context,
                    'Select the advance and add the item. Available: ${language.money(total?.availableBalance ?? 0)}.',
                    'ایڈوانس منتخب کریں اور سامان درج کریں۔ دستیاب: ${language.money(total?.availableBalance ?? 0)}۔',
                  ),
                  action: _label(
                    context,
                    'Add advance expense',
                    'ایڈوانس کا خرچ درج کریں',
                  ),
                  onPressed: () => _openExpense(context, 'float'),
                ),
                const SizedBox(height: 12),
                _ChoiceCard(
                  icon: Icons.person_outline_rounded,
                  title: _label(
                    context,
                    'I paid from my own pocket',
                    'میں نے اپنی جیب سے ادا کیا',
                  ),
                  subtitle: _label(
                    context,
                    'Record what you bought. Finance will review and repay it separately.',
                    'خریداری درج کریں۔ فنانس اس کا الگ جائزہ لے کر رقم واپس کرے گا۔',
                  ),
                  action: _label(
                    context,
                    'Ask for repayment',
                    'رقم واپسی کی درخواست',
                  ),
                  onPressed: () => _openExpense(context, 'reimbursement'),
                ),
                const SizedBox(height: 18),
                Text(
                  _label(
                    context,
                    'You can check decisions, balances and receipts in Money & Expenses.',
                    'فیصلے، بیلنس اور رسیدیں رقم اور خرچ میں دیکھیں۔',
                  ),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, action;
  final VoidCallback onPressed;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.borderLight),
      boxShadow: AppTheme.premiumShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 30),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF475569))),
        const SizedBox(height: 12),
        FilledButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}

class _RequestAdvanceDialog extends StatefulWidget {
  const _RequestAdvanceDialog();
  @override
  State<_RequestAdvanceDialog> createState() => _RequestAdvanceDialogState();
}

class _RequestAdvanceDialogState extends State<_RequestAdvanceDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  final _requestId = const Uuid().v4();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final saved = await context.read<PaymentProvider>().requestAdvance(
      id: _requestId,
      amount: double.parse(_amount.text.trim()),
      purpose: _purpose.text.trim(),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_label(context, 'Request an advance', 'ایڈوانس کی درخواست')),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _label(
                  context,
                  'Finance will review this request. Your balance increases after you confirm receipt.',
                  'فنانس اس درخواست کا جائزہ لے گا۔ وصولی کی تصدیق کے بعد رقم بیلنس میں آئے گی۔',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: _label(context, 'Amount (PKR)', 'رقم (روپے)'),
                  helperText: _label(
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
                    return _label(
                      context,
                      'Enter a valid amount.',
                      'درست رقم درج کریں۔',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _purpose,
                maxLength: 2000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _label(
                    context,
                    'What is the money for?',
                    'رقم کس کام کے لیے چاہیے؟',
                  ),
                  helperText: _label(
                    context,
                    'Example: paper and printer ink',
                    'مثال: کاغذ اور پرنٹر کی سیاہی',
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? _label(
                        context,
                        'Tell Finance why you need it.',
                        'فنانس کو وجہ بتائیں۔',
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: Text(_label(context, 'Cancel', 'منسوخ')),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_label(context, 'Send to Finance', 'فنانس کو بھیجیں')),
      ),
    ],
  );
}
