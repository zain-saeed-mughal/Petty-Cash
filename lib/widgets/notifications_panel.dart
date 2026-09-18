import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../config/app_theme.dart';
import 'package:intl/intl.dart';

class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = Provider.of<NotificationProvider>(context);
    final notifications = notifProvider.notifications;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      notifProvider.markAllAsRead();
                    },
                    child: const Text('Mark all as read'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Flexible(
            child: notifications.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return ListTile(
                        tileColor: notif.isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
                        leading: CircleAvatar(
                          backgroundColor: notif.isRead ? Colors.grey.shade200 : Colors.blue.shade100,
                          child: Icon(
                            Icons.notifications_active,
                            color: notif.isRead ? Colors.grey : AppTheme.primaryBlue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(notif.message),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy - hh:mm a').format(notif.createdAt),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (!notif.isRead) {
                            notifProvider.markAsRead(notif.id);
                          }
                          // Could navigate to request detail here if relatedRequestId is not null
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
