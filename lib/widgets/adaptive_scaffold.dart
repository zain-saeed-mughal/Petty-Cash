import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../config/app_theme.dart';
import '../config/app_constants.dart';
import '../providers/notification_provider.dart';
import 'notifications_panel.dart';
import 'data_status_view.dart';

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? badgeCount;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount,
  });
}

class AdaptiveScaffold extends StatelessWidget {
  final String title;
  final int currentIndex;
  final ValueChanged<int> onNavigationIndexChanged;
  final List<NavigationItem> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.onNavigationIndexChanged,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    Color roleColor;
    switch (user?.role) {
      case UserRole.superAdmin:
        roleColor = AppTheme.roleSuperAdmin;
        break;
      case UserRole.admin:
        roleColor = AppTheme.roleAdmin;
        break;
      case UserRole.finance:
        roleColor = AppTheme.roleFinance;
        break;
      case UserRole.officeBoy:
      default:
        roleColor = AppTheme.roleOfficeBoy;
        break;
    }

    final appBarActions = [
      ...?actions,
      // User Profile Badge
      Center(
        child: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roleColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: roleColor,
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isDesktop || screenWidth >= 380) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      user?.name ?? 'Unknown',
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),

      // Notification Bell
      Consumer<NotificationProvider>(
        builder: (context, notifProvider, child) {
          return IconButton(
            icon: Badge(
              isLabelVisible: notifProvider.unreadCount > 0,
              label: Text('${notifProvider.unreadCount}'),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF64748B),
              ),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const NotificationsPanel(),
              );
            },
          );
        },
      ),
      const SizedBox(width: 8),

      // Sign Out Button
      IconButton(
        icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
        tooltip: 'Sign Out',
        onPressed: () {
          _confirmSignOut(context, authProvider);
        },
      ),
      const SizedBox(width: 8),
    ];

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: appBarActions,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onNavigationIndexChanged,
              extended: screenWidth >= 1024,
              minExtendedWidth: 200,
              backgroundColor: Colors.white,
              selectedIconTheme: const IconThemeData(
                color: AppTheme.primaryBlue,
              ),
              selectedLabelTextStyle: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              destinations: destinations.map((d) {
                return NavigationRailDestination(
                  icon: d.badgeCount != null && d.badgeCount! > 0
                      ? Badge(
                          label: Text('${d.badgeCount}'),
                          child: Icon(d.icon),
                        )
                      : Icon(d.icon),
                  selectedIcon: d.badgeCount != null && d.badgeCount! > 0
                      ? Badge(
                          label: Text('${d.badgeCount}'),
                          child: Icon(d.selectedIcon),
                        )
                      : Icon(d.selectedIcon),
                  label: Text(d.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: DataStatusView(child: body)),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    // Mobile View
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: appBarActions,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: DataStatusView(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onNavigationIndexChanged,
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: destinations.map((d) {
          final label = screenWidth < 380
              ? switch (d.label) {
                  'Transactions' => 'Txns',
                  'Users & Roles' => 'Users',
                  _ => d.label,
                }
              : d.label;
          return NavigationDestination(
            icon: d.badgeCount != null && d.badgeCount! > 0
                ? Badge(label: Text('${d.badgeCount}'), child: Icon(d.icon))
                : Icon(d.icon),
            selectedIcon: d.badgeCount != null && d.badgeCount! > 0
                ? Badge(
                    label: Text('${d.badgeCount}'),
                    child: Icon(d.selectedIcon),
                  )
                : Icon(d.selectedIcon),
            label: label,
          );
        }).toList(),
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  void _confirmSignOut(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of Petty Cash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              auth.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
