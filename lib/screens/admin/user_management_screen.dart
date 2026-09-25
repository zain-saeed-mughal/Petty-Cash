import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/user_model.dart';
import '../../config/app_theme.dart';
import '../../widgets/user_account_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  UserRole? _roleFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddUserDialog(
    BuildContext context,
    AppUser currentUser,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserAccountDialog(actor: currentUser),
    );
    if (result != null && context.mounted) {
      _showTemporaryCredentialsDialog(
        context,
        name: result['name']!,
        email: result['email']!,
        temporaryPassword: result['password']!,
      );
    }
  }

  void _showTemporaryCredentialsDialog(
    BuildContext context, {
    required String name,
    required String email,
    required String temporaryPassword,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppTheme.statusApproved),
            SizedBox(width: 8),
            Expanded(child: Text(context.t('Account Created'))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$name${Provider.of<LanguageProvider>(context, listen: false).tr('can_use_temp_creds')}',
              ),
              const SizedBox(height: 16),
              _credentialRow(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).tr('email_label'),
                email,
              ),
              const SizedBox(height: 10),
              _credentialRow(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).tr('temp_password_label'),
                temporaryPassword,
              ),
              const SizedBox(height: 14),
              Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).tr('share_password_securely'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              Provider.of<LanguageProvider>(context, listen: false).tr('done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip:
                '${Provider.of<LanguageProvider>(context, listen: false).tr('copy_tooltip')}$label',
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(
    BuildContext context,
    AppUser userToEdit,
    AppUser currentUser,
  ) async {
    await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserAccountDialog(actor: currentUser, user: userToEdit),
    );
  }

  Future<void> _confirmDeleteUser(BuildContext context, AppUser user) async {
    final provider = context.read<UserProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).tr('deactivate_account_title'),
        ),
        content: Text(
          '${Provider.of<LanguageProvider>(context, listen: false).tr('deactivate_account_confirm')}${user.name}${Provider.of<LanguageProvider>(context, listen: false).tr('deactivate_account_confirm_end')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).tr('cancel'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).tr('deactivate_btn'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    final success = await provider.deleteUser(user.uid);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? langProvider.tr('account_deactivated')
                : langProvider.error(
                    provider.errorMessage ??
                        langProvider.tr('unable_to_deactivate'),
                  ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = auth.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    final manageable = userProvider.getManageableUsers(currentUser);
    final filtered = manageable.where((u) {
      if (_roleFilter != null && u.role != _roleFilter) return false;
      final q = _searchController.text.toLowerCase().trim();
      if (q.isNotEmpty) {
        return u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return RefreshIndicator(
      onRefresh: () async {
        userProvider.refresh();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Add Button
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop ? 700 : 320,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Provider.of<LanguageProvider>(context)
                                      .tr('user_accounts_management'),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryNavy,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  currentUser.isSuperAdmin
                                      ? Provider.of<LanguageProvider>(context)
                                            .tr('super_admin_manage_desc')
                                      : Provider.of<LanguageProvider>(context)
                                            .tr('admin_manage_desc'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            icon: const Icon(
                              Icons.person_add_rounded,
                              size: 16,
                            ),
                            label: Text(
                              Provider.of<LanguageProvider>(context)
                                  .tr('add_btn'),
                            ),
                            onPressed: () =>
                                _showAddUserDialog(context, currentUser),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Search & Filter Bar
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.borderLight,
                            width: 0.5,
                          ),
                          boxShadow: AppTheme.premiumShadow,
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: Provider.of<LanguageProvider>(context)
                                    .tr('search_users_hint'),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF94A3B8),
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear_rounded,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('all_users')} (${manageable.length})',
                                    null,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('office_boy')} (${manageable.where((u) => u.isOfficeBoy).length})',
                                    UserRole.officeBoy,
                                    color: AppTheme.roleOfficeBoy,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('finance')} (${manageable.where((u) => u.isFinance).length})',
                                    UserRole.finance,
                                    color: AppTheme.roleFinance,
                                  ),
                                  if (currentUser.isSuperAdmin) ...[
                                    const SizedBox(width: 12),
                                    _buildFilterChip(
                                      '${Provider.of<LanguageProvider>(context).tr('admin')} (${manageable.where((u) => u.isAdmin).length})',
                                      UserRole.admin,
                                      color: AppTheme.roleAdmin,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Users List Table / Cards
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  width: double.infinity,
                  padding: const EdgeInsets.all(64),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderLight, width: 0.5),
                    boxShadow: AppTheme.premiumShadow,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        Provider.of<LanguageProvider>(context)
                            .tr('no_users_found'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Provider.of<LanguageProvider>(context)
                            .tr('try_adjusting_search_users'),
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16)
                  .copyWith(bottom: 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: _buildUserCard(filtered[index], currentUser),
                    ),
                  );
                }, childCount: filtered.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, UserRole? role, {Color? color}) {
    final isSelected = _roleFilter == role;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      backgroundColor: Colors.white,
      selectedColor: color ?? AppTheme.primaryBlue,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? (color ?? AppTheme.primaryBlue)
              : AppTheme.borderLight,
        ),
      ),
      onSelected: (_) {
        setState(() => _roleFilter = isSelected ? null : role);
      },
    );
  }

  Widget _buildUserCard(AppUser user, AppUser currentUser) {
    Color roleColor;
    switch (user.role) {
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
        roleColor = AppTheme.roleOfficeBoy;
        break;
    }

    final canEdit =
        currentUser.isSuperAdmin ||
        (currentUser.isAdmin && (user.isOfficeBoy || user.isFinance));
    final canDelete =
        (currentUser.isSuperAdmin && user.uid != currentUser.uid) ||
        (currentUser.isAdmin && (user.isOfficeBoy || user.isFinance));
    final profile = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      context.t(user.role.displayName),
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                user.email,
                softWrap: true,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );

    final metadata = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          context.language.date(user.createdAt),
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                tooltip: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).tr('edit_user_tooltip'),
                onPressed: () =>
                    _showEditUserDialog(context, user, currentUser),
              ),
            if (canDelete)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppTheme.statusRejected,
                ),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                tooltip: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).tr('remove_user_tooltip'),
                onPressed: () => _confirmDeleteUser(context, user),
              ),
          ],
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 0.5),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: profile),
          const SizedBox(width: 8),
          metadata,
        ],
      ),
    );
  }
}
