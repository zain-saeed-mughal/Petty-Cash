import 'account_app_bar.dart';

import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
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
    if (isDesktop) {
      return Scaffold(
        appBar: const AccountAppBar(),
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
      appBar: const AccountAppBar(),
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
                  'Transactions' => context.t('Txns'),
                  'Users & Roles' => context.t('Users'),
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
}
