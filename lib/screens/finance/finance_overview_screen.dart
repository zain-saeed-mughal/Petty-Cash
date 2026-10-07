import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petty_cash/l10n/context_l10n.dart';

import '../../providers/expense_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';

class FinanceOverviewScreen extends StatelessWidget {
  final VoidCallback onViewPendingTap;
  final VoidCallback onViewHistoryTap;
  final VoidCallback onViewPaymentsTap;

  const FinanceOverviewScreen({
    super.key,
    required this.onViewPendingTap,
    required this.onViewHistoryTap,
    required this.onViewPaymentsTap,
  });

  @override
  Widget build(BuildContext context) {
    final expense = Provider.of<ExpenseProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final payments = context.watch<PaymentProvider>();
    final newQueue =
        payments.advanceRequests
            .where((row) => row.status == 'Pending')
            .length +
        payments.expenses
            .where(
              (row) =>
                  row.status == 'Pending' ||
                  (row.flowType == 'reimbursement' && row.status == 'Approved'),
            )
            .length;
    final availableFloat = payments.overview.fold<double>(
      0,
      (sum, row) => sum + row.availableBalance,
    );
    final heldFloat = payments.overview.fold<double>(
      0,
      (sum, row) => sum + row.onHold,
    );
    final spentFloat = payments.overview.fold<double>(
      0,
      (sum, row) => sum + row.totalSpent,
    );

    final pendingCount = expense.pendingCount;
    final pendingAmount = expense.pendingAmount;

    final allPaid = expense.allRequests.where((r) => r.isPaid || r.isSettled);
    final totalPaidAmount = allPaid.fold<double>(0, (sum, r) {
      if (r.isAdvance && r.isSettled) {
        return sum + (r.settlementAmount ?? r.amount);
      } else if (!r.isAdvance && r.isPaid) {
        return sum + r.amount;
      }
      return sum;
    });

    final unsettledAdvances = expense.allRequests.where(
      (r) => r.isAdvance && (r.isPaid || r.isPendingSettlement) && !r.isSettled,
    );
    final totalOutstandingAdvance = unsettledAdvances.fold<double>(
      0,
      (sum, r) => sum + r.outstandingAdvance,
    );

    final recentPending = expense.pendingRequests.take(5).toList();

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
                      // Welcome / Header Banner
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0F766E),
                              Color(0xFF115E59),
                            ], // Teal/Emerald
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
                                Icons.account_balance_rounded,
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
                                    lang.isRtl
                                        ? 'فنانس ڈیش بورڈ'
                                        : 'Finance Dashboard',
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
                                        ? 'تمام اخراجات اور پیشگی رقوم کا مکمل جائزہ۔'
                                        : 'See requests, advances, and repayments in one place.',
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
                            : 'Advances and personal spending',
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
                                  ? 'فیصلے کے منتظر'
                                  : 'Waiting for Finance',
                              value: newQueue.toString(),
                              icon: Icons.pending_actions_outlined,
                              color: AppTheme.statusPending,
                              onTap: onViewPaymentsTap,
                            ),
                          ),
                          SizedBox(
                            width: isDesktop ? 300 : double.infinity,
                            child: StatCard(
                              title: lang.isRtl
                                  ? 'ملازمین کے پاس دستیاب'
                                  : 'Money with staff',
                              value: lang.money(availableFloat),
                              icon: Icons.account_balance_wallet_outlined,
                              color: AppTheme.primaryBlue,
                              onTap: onViewPaymentsTap,
                            ),
                          ),
                          SizedBox(
                            width: isDesktop ? 300 : double.infinity,
                            child: StatCard(
                              title: lang.isRtl
                                  ? 'جائزے تک روکی گئی'
                                  : 'Money held for review',
                              value: lang.money(heldFloat),
                              icon: Icons.lock_clock_outlined,
                              color: Colors.deepPurple,
                              onTap: onViewPaymentsTap,
                            ),
                          ),
                          SizedBox(
                            width: isDesktop ? 300 : double.infinity,
                            child: StatCard(
                              title: lang.isRtl
                                  ? 'ایڈوانس سے خرچ'
                                  : 'Spent from advances',
                              value: lang.money(spentFloat),
                              icon: Icons.shopping_bag_outlined,
                              color: AppTheme.statusApproved,
                              onTap: onViewPaymentsTap,
                            ),
                          ),
                        ],
                      ),
                      if (expense.allRequests.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          lang.isRtl ? 'پرانا ریکارڈ' : 'Previous requests',
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
                                    : 'Requests to review',
                                value: pendingCount.toString(),
                                subtitle: context.language.money(pendingAmount),
                                icon: Icons.pending_actions_rounded,
                                color: AppTheme.statusPending,
                                onTap: onViewPendingTap,
                              ),
                            ),
                            SizedBox(
                              width: isDesktop ? 300 : double.infinity,
                              child: StatCard(
                                title: lang.isRtl
                                    ? 'پرانی ادا شدہ درخواستیں'
                                    : 'Paid requests',
                                value: context.language.money(totalPaidAmount),
                                icon: Icons.check_circle_outline_rounded,
                                color: AppTheme.statusApproved,
                                onTap: onViewHistoryTap,
                              ),
                            ),
                            if (totalOutstandingAdvance > 0)
                              SizedBox(
                                width: isDesktop ? 300 : double.infinity,
                                child: StatCard(
                                  title: lang.isRtl
                                      ? 'پرانے ایڈوانس، حساب باقی'
                                      : 'Advances still open',
                                  value: context.language.money(
                                    totalOutstandingAdvance,
                                  ),
                                  icon: Icons.account_balance_wallet_outlined,
                                  color: Colors.purple,
                                  onTap: onViewPendingTap,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Quick Actions & Pending List
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                lang.isRtl
                                    ? 'پرانی درخواستیں جن پر فیصلہ باقی ہے'
                                    : 'Requests waiting for review',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: onViewPendingTap,
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

                        if (recentPending.isEmpty)
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
                                  Icons.task_alt_rounded,
                                  size: 48,
                                  color: AppTheme.statusApproved,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  lang.tr('all_caught_up'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lang.tr('no_pending_requests'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: recentPending.map((req) {
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
                                      backgroundColor: const Color(0xFFFEF3C7),
                                      child: Icon(
                                        req.isAdvance
                                            ? Icons
                                                  .account_balance_wallet_outlined
                                            : Icons.receipt_rounded,
                                        color: AppTheme.statusPending,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req.requesterName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppTheme.primaryNavy,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            req.itemDescription,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.schedule_rounded,
                                                size: 13,
                                                color: Color(0xFF94A3B8),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                context.language.date(req.createdAt),
                                                style: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                        Wrap(
                                          alignment: WrapAlignment.end,
                                          spacing: 4,
                                          runSpacing: 2,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.payments_outlined,
                                              size: 15,
                                              color: AppTheme.primaryBlue,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              context.language.money(req.amount),
                                              maxLines: 2,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primaryNavy,
                                              ),
                                            ),
                                          ],
                                        ),
                                          const SizedBox(height: 4),
                                          StatusBadge(
                                            status: req.status,
                                            isCompact: true,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: req.isAdvance
                                                ? Colors.purple.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            req.isAdvance
                                                ? context.language.format(
                                                    'Advance',
                                                    'ایڈوانس',
                                                    {},
                                                  )
                                                : context.language.format(
                                                    'Expense',
                                                    'خرچہ',
                                                    {},
                                                  ),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: req.isAdvance
                                                  ? Colors.purple
                                                  : Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          ),
                                        ],
                                      ),
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
