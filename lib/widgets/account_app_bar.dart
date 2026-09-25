import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/context_l10n.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import 'notifications_panel.dart';

/// The same compact account controls on every dashboard, in both directions.
class AccountAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AccountAppBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.currentUser?.name ?? context.t('User');
    final language = context.language;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 12,
      title: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: context.t('Language'),
            initialValue: language.currentLanguage,
            onSelected: language.setLanguage,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(
                value: 'ur',
                child: Text(
                  'اردو',
                  style: TextStyle(fontFamily: 'NotoSansArabic'),
                ),
              ),
            ],
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceMuted,
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Center(
                child: Icon(
                  Icons.language_rounded,
                  size: 20,
                  color: AppTheme.primaryNavy,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: name,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryNavy.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      key: const ValueKey('account-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Consumer<NotificationProvider>(
            builder: (context, notifications, _) => IconButton(
              tooltip: context.t('Notifications'),
              icon: Badge(
                isLabelVisible: notifications.unreadCount > 0,
                label: Text(
                  notifications.unreadCount > 99
                      ? '99+'
                      : '${notifications.unreadCount}',
                ),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const NotificationsPanel(),
              ),
            ),
          ),
          IconButton(
            tooltip: context.t('Sign Out'),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: Text(context.t('Sign Out')),
                content: Text(
                  context.t('Are you sure you want to sign out of Petty Cash?'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: Text(context.t('Cancel')),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialog);
                      auth.signOut();
                    },
                    child: Text(context.t('Sign Out')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
