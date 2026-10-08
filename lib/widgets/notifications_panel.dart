import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../services/push_notification_service.dart';
import '../screens/core/core_dashboard_screens.dart';
import '../providers/core_flow_provider.dart';
import '../config/app_theme.dart';

class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SizedBox(
          width: 440,
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.t('Notifications'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.primaryNavy,
                      ),
                    ),
                    if (provider.unreadCount > 0)
                      TextButton(
                        onPressed: () => provider.markAllAsRead(),
                        child: Text(context.t('Mark all as read')),
                      ),
                    IconButton(
                      tooltip: context.t('Close'),
                      onPressed: () => Navigator.maybePop(context),
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : null),
                    ),
                  ],
                ),
              ),
              if (PushNotificationService().supported)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(context.t('Enable device notifications')),
                      onPressed: () async {
                        final ok = await PushNotificationService().enable();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? context.t('Device notifications enabled.')
                                    : PushNotificationService().lastError ??
                                          'Unable to enable notifications.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    context.language.error(provider.errorMessage!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (provider.isLoading) const LinearProgressIndicator(),
              Divider(height: 1, color: isDark ? Colors.white12 : null),
              Expanded(
                child: provider.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 40,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              provider.errorMessage == null
                                  ? context.t('You are all caught up.')
                                  : context.t('Notifications are unavailable.'),
                              style: TextStyle(
                                color: isDark ? Colors.white70 : null,
                              ),
                            ),
                            if (provider.errorMessage != null)
                              TextButton(
                                onPressed: provider.refresh,
                                child: Text(context.t('Try again')),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          provider.refresh();
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: provider.notifications.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: isDark ? Colors.white12 : null),
                          itemBuilder: (context, index) {
                            final n = provider.notifications[index];
                            return Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: AppTheme.statusRejected,
                                alignment: AlignmentDirectional.centerEnd,
                                padding: const EdgeInsets.all(20),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              // Persist first. Failed deletes retain the item and display the provider error.
                              confirmDismiss: (_) =>
                                  provider.deleteNotification(n.id),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                tileColor: n.isRead
                                    ? null
                                    : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xffeff6ff)),
                                title: Text(
                                  context.language.notificationTitle(n),
                                  style: TextStyle(
                                    fontWeight: n.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Text(
                                      context.language.notificationBody(n),
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      context.language.date(
                                        n.createdAt.toLocal(),
                                        pattern: 'dd MMM, hh:mm a',
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white38 : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  if (!n.isRead) {
                                    await provider.markAsRead(n.id);
                                  }
                                  if (n.relatedCoreAdvanceId != null ||
                                      n.relatedReimbursementId != null) {
                                    if (!context.mounted) return;
                                    final flows = context
                                        .read<CoreFlowProvider>();
                                    final advance = flows.advances
                                        .where(
                                          (a) => a.id == n.relatedCoreAdvanceId,
                                        )
                                        .firstOrNull;
                                    final repayment = flows.reimbursements
                                        .where(
                                          (r) =>
                                              r.id == n.relatedReimbursementId,
                                        )
                                        .firstOrNull;
                                    if (advance == null && repayment == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.t(
                                              'This request is unavailable.',
                                            ),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final nav = Navigator.of(context);
                                    nav.pop(); // Close notifications bottom sheet first
                                    await nav.push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => Scaffold(
                                          appBar: AppBar(
                                            title: Text(context.t('Details')),
                                          ),
                                          body: Consumer<CoreFlowProvider>(
                                            builder: (ctx, liveFlow, _) {
                                              final liveAdvance = n.relatedCoreAdvanceId != null
                                                  ? liveFlow.advances
                                                      .where((a) => a.id == n.relatedCoreAdvanceId)
                                                      .firstOrNull
                                                  : null;
                                              final liveRepayment = n.relatedReimbursementId != null
                                                  ? liveFlow.reimbursements
                                                      .where((r) => r.id == n.relatedReimbursementId)
                                                      .firstOrNull
                                                  : null;
                                              if (liveAdvance == null && liveRepayment == null) {
                                                return Center(
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(24.0),
                                                    child: Text(
                                                      context.t('This request is no longer available.'),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return ListView(
                                                padding: const EdgeInsets.all(16),
                                                children: [
                                                  if (liveAdvance != null)
                                                    CoreAdvanceCard(
                                                      advance: liveAdvance,
                                                    ),
                                                  if (liveRepayment != null)
                                                    CoreReimbursementCard(
                                                      request: liveRepayment,
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  if (n.relatedAdvanceId != null ||
                                      n.relatedExpenseId != null ||
                                      n.relatedAdvanceRequestId != null ||
                                      n.relatedRequestId != null) {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: Text(
                                          context.t('Previous notification'),
                                        ),
                                        content: Text(
                                          '${context.language.notificationBody(n)}\n\n'
                                          '${context.t('This request is archived.')}',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext),
                                            child: Text(context.t('Close')),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
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
