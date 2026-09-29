import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petty_cash/l10n/context_l10n.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';

class OfficeBoyOverviewScreen extends StatelessWidget {
  final VoidCallback onNewRequestTap;
  final VoidCallback onViewAllTap;
  final VoidCallback onViewPaymentsTap;

  const OfficeBoyOverviewScreen({
    super.key,
    required this.onNewRequestTap,
    required this.onViewAllTap,
    required this.onViewPaymentsTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final expense = Provider.of<ExpenseProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final payments = context.watch<PaymentProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return Center(child: Text(lang.tr('please_log_in')));
    }

    final myRequests = expense.getMyRequests(user.uid);
    final pendingCount = myRequests.where((r) => r.isPending).length;
    final approvedPaidCount = myRequests
        .where((r) => r.isApproved || r.hasDisbursement)
        .length;

    final unsettledAdvances = myRequests.where(
      (r) => r.isAdvance && (r.isPaid || r.isPendingSettlement) && !r.isSettled,
    );
    final advanceBalance = unsettledAdvances.fold<double>(
      0,
      (sum, r) => sum + r.outstandingAdvance,
    );

    final recentRequests = myRequests.take(5).toList();
    final account = payments.overview
        .where((row) => row.officeBoyId == user.uid)
        .firstOrNull;
    final pocketAwaiting = payments.expenses
        .where(
          (row) =>
              row.flowType == 'reimbursement' &&
              row.status != 'Paid' &&
              row.status != 'Rejected' &&
              row.status != 'Rejection Acknowledged',
        )
        .fold<double>(0, (sum, row) => sum + row.amount);
    final pocketRepaid = payments.expenses
        .where((row) => row.flowType == 'reimbursement' && row.status == 'Paid')
        .fold<double>(0, (sum, row) => sum + row.amount);
    final nextSteps =
        payments.advances
            .where((row) => row.status == 'Awaiting Confirmation')
            .length +
        payments.expenses
            .where(
              (row) =>
                  row.status == 'Rejected' || row.status == 'Payment Cleared',
            )
            .length;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return RefreshIndicator(
      onRefresh: () async {
        expense.refresh();
        payments.refresh();
        await payments.refreshOverview();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Banner
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF3B82F6),
                              Color(0xFF1D4ED8),
                            ], // Blue
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.premiumShadow,
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${lang.tr('welcome_user')}${user.name}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lang.isRtl
                                        ? 'اپنے پیٹی کیش اخراجات اور پیشگی رقم کا ریکارڈ رکھیں۔'
                                        : 'Keep track of your petty cash expenses and advances.',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        lang.isRtl
                            ? 'ایڈوانس اور ذاتی خرچ کا حساب'
                            : 'Advances & own-pocket expenses',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: isDesktop ? 300 : double.infinity,
                            child: StatCard(
                              title: lang.isRtl
                                  ? 'ایڈوانس میں دستیاب'
                                  : 'Advance Available',
                              value: lang.money(account?.availableBalance ?? 0),
                              icon: Icons.account_balance_wallet_outlined,
                              color: AppTheme.primaryBlue,
                              onTap: onViewPaymentsTap,
                            ),
                          ),
                          SizedBox(
                            width: isDesktop ? 300 : double.infinity,
                            child: StatCard(
                              title: lang.isRtl
                                  ? 'روکی گئی رقم'
                                  : 'Advance On Hold',
                              value: lang.money(account?.onHold ?? 0),
                              icon: Icons.lock_clock_outlined,
                              color: AppTheme.statusPending,
                              onTap: onViewPaymentsTap,
                            ),
                          ),
                          SizedBox(
                            width: isDesktop ? 300 : double.infinity,
                            child: StatCard(
                              title: lang.isRtl
                                  ? 'ذاتی خرچ، واپسی باقی'
                                  : 'Own money to be repaid',
                              value: lang.money(pocketAwaiting),
                              icon: Icons.person_outline_rounded,
                              color: Colors.deepPurple,
                              onTap: onViewPaymentsTap,
                            ),
                          ),
                          SizedBox(
                            width: isDesktop ? 300 : double.infinity,
                            child: StatCard(
                              title: lang.isRtl
                                  ? 'ذاتی خرچ واپس ملا'
                                  : 'Own money repaid',
                              value: lang.money(pocketRepaid),
                              icon: Icons.paid_outlined,
                              color: AppTheme.statusApproved,
                              onTap: onViewPaymentsTap,
                            ),
                          ),
                        ],
                      ),
                      if (nextSteps > 0) ...[
                        const SizedBox(height: 16),
                        StatCard(
                          title: lang.isRtl
                              ? 'آپ کی کارروائی باقی ہے'
                              : 'You have actions to complete',
                          value: nextSteps.toString(),
                          icon: Icons.task_alt_rounded,
                          color: AppTheme.statusPending,
                          onTap: onViewPaymentsTap,
                        ),
                      ],
                      if (myRequests.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          lang.isRtl ? 'پرانا ریکارڈ' : 'Earlier requests',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        // Earlier request Stat Cards
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isDesktop ? 300 : double.infinity,
                              child: StatCard(
                                title: lang.isRtl
                                    ? 'پرانی درخواستیں، فیصلہ باقی'
                                    : 'Earlier requests to review',
                                value: pendingCount.toString(),
                                icon: Icons.pending_actions_rounded,
                                color: AppTheme.statusPending,
                                onTap: onViewAllTap,
                              ),
                            ),
                            SizedBox(
                              width: isDesktop ? 300 : double.infinity,
                              child: StatCard(
                                title: lang.isRtl
                                    ? 'پرانی منظور یا ادا شدہ درخواستیں'
                                    : 'Earlier approved or paid',
                                value: approvedPaidCount.toString(),
                                icon: Icons.check_circle_outline_rounded,
                                color: AppTheme.statusApproved,
                                onTap: onViewAllTap,
                              ),
                            ),
                            if (advanceBalance > 0)
                              SizedBox(
                                width: isDesktop ? 300 : double.infinity,
                                child: StatCard(
                                  title: lang.isRtl
                                      ? 'پرانے ایڈوانس، حساب باقی'
                                      : 'Earlier advances still open',
                                  value: context.language.money(advanceBalance),
                                  icon: Icons.account_balance_wallet_outlined,
                                  color: Colors.purple,
                                  onTap: onViewAllTap,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Quick Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                lang.isRtl
                                    ? 'حالیہ درخواستیں'
                                    : 'Recent Requests',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: onViewAllTap,
                              child: Text(
                                lang.isRtl ? 'تمام دیکھیں' : 'View All',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (recentRequests.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  lang.tr('no_requests_yet'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: onNewRequestTap,
                                  icon: const Icon(Icons.add),
                                  label: Text(lang.tr('submit_new_expense')),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: recentRequests.map((req) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.borderLight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: req.isAdvance
                                          ? Colors.purple.withValues(alpha: 0.1)
                                          : Colors.blue.withValues(alpha: 0.1),
                                      child: Icon(
                                        req.isAdvance
                                            ? Icons
                                                  .account_balance_wallet_outlined
                                            : Icons.receipt_long_outlined,
                                        color: req.isAdvance
                                            ? Colors.purple
                                            : Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req.itemDescription,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppTheme.primaryNavy,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            context.language.date(
                                              req.createdAt,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          context.language.money(req.amount),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        StatusBadge(
                                          status: req.status,
                                          isCompact: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
