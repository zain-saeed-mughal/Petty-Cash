import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/context_l10n.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 16,
      title: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: name,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: isDark
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                        : const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFF7C3AED),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Builder(
            builder: (context) {
              final theme = Provider.of<ThemeProvider?>(context, listen: true);
              if (theme == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: context.t(
                  theme.isDarkMode ? 'Light Mode' : 'Dark Mode',
                ),
                icon: Icon(
                  theme.isDarkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_outlined,
                ),
                onPressed: theme.toggleTheme,
              );
            },
          ),
          Builder(
            builder: (context) {
              final notifications = Provider.of<NotificationProvider?>(
                context,
                listen: true,
              );
              final unread = notifications?.unreadCount ?? 0;
              return IconButton(
                tooltip: context.t('Notifications'),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const NotificationsPanel(),
                ),
              );
            },
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
                    onPressed: () => auth.signOut(),
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
