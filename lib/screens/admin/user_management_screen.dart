import 'package:petty_cash/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/core_flow_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/user_model.dart';
import '../../config/app_theme.dart';
import '../../widgets/user_account_dialog.dart';
import '../../widgets/app_toast.dart';

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
      showAppToast(
        context,
        message: context.t('Account created successfully!'),
        type: ToastType.success,
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t('Account Created'),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$name ${Provider.of<LanguageProvider>(context, listen: false).tr('can_use_temp_creds')}',
                style: TextStyle(
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _credentialRow(
                context,
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).tr('email_label'),
                email,
                isDark,
              ),
              const SizedBox(height: 10),
              _credentialRow(
                context,
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).tr('temp_password_label'),
                temporaryPassword,
                isDark,
              ),
              const SizedBox(height: 14),
              Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).tr('share_password_securely'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                Provider.of<LanguageProvider>(context, listen: false).tr('done'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(
    BuildContext context,
    String label,
    String value,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip:
                '${Provider.of<LanguageProvider>(context, listen: false).tr('copy_tooltip')}$label',
            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF8B5CF6)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).tr('copied_to_clipboard'),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
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
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserAccountDialog(actor: currentUser, user: userToEdit),
    );
    if (result != null && context.mounted) {
      showAppToast(
        context,
        message: context.t('Account updated successfully'),
        type: ToastType.success,
      );
    }
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
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    final success = await provider.deleteUser(user.uid);
    if (context.mounted) {
      if (success) {
        showAppToast(
          context,
          message: langProvider.tr('account_deactivated'),
          type: ToastType.warning,
        );
      } else {
        showAppToast(
          context,
          message: langProvider.error(
            provider.errorMessage ?? langProvider.tr('unable_to_deactivate'),
          ),
          type: ToastType.error,
        );
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      // Header & Add Button (+ icon, Purple, non-blue)
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
                                    color: isDark ? Colors.white : AppTheme.primaryNavy,
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // + Icon Add Button (Purple gradient, NOT blue)
                          InkWell(
                            onTap: () => _showAddUserDialog(context, currentUser),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    Provider.of<LanguageProvider>(context).tr('add_btn'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Small Compact Search & Filter Bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : AppTheme.borderLight,
                            width: 0.8,
                          ),
                          boxShadow: isDark ? null : AppTheme.premiumShadow,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 42,
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : AppTheme.primaryNavy,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  hintText: Provider.of<LanguageProvider>(context)
                                      .tr('search_users_hint'),
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            size: 16,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('all_users')} (${manageable.length})',
                                    null,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('office_boy')} (${manageable.where((u) => u.isOfficeBoy).length})',
                                    UserRole.officeBoy,
                                    color: AppTheme.roleOfficeBoy,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildFilterChip(
                                    '${Provider.of<LanguageProvider>(context).tr('finance')} (${manageable.where((u) => u.isFinance).length})',
                                    UserRole.finance,
                                    color: AppTheme.roleFinance,
                                    isDark: isDark,
                                  ),
                                  if (currentUser.isSuperAdmin) ...[
                                    const SizedBox(width: 10),
                                    _buildFilterChip(
                                      '${Provider.of<LanguageProvider>(context).tr('admin')} (${manageable.where((u) => u.isAdmin).length})',
                                      UserRole.admin,
                                      color: AppTheme.roleAdmin,
                                      isDark: isDark,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
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
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: _buildUserCard(filtered[index], currentUser, isDark),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, UserRole? role, {Color? color, bool isDark = false}) {
    final isSelected = _roleFilter == role;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      selectedColor: color ?? const Color(0xFF7C3AED),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? (color ?? const Color(0xFF7C3AED))
              : (isDark ? const Color(0xFF334155) : AppTheme.borderLight),
        ),
      ),
      onSelected: (_) {
        setState(() => _roleFilter = isSelected ? null : role);
      },
    );
  }

  Widget _buildUserCard(AppUser user, AppUser currentUser, [bool isDark = false]) {
    final offices = context.watch<CoreFlowProvider>().offices;
    final officeName = offices
        .where((office) => office.id == user.officeId)
        .map((office) => office.name)
        .firstOrNull;
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
      case UserRole.manager:
        roleColor = AppTheme.roleManager;
        break;
    }

    final canEdit =
        currentUser.isSuperAdmin ||
        (currentUser.isAdmin && (user.isOfficeBoy || user.isFinance));
    final canDelete =
        currentUser.isSuperAdmin &&
        user.isOfficeBoy &&
        user.uid != currentUser.uid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppTheme.borderLight,
          width: 0.8,
        ),
        boxShadow: isDark ? null : AppTheme.premiumShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Avatar
          CircleAvatar(
            radius: 23,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // 2. Info Block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Name + Role Badge
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppTheme.primaryNavy,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: roleColor.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
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

                // Middle Row: Email + Office
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${context.t('Office')}: ${officeName ?? context.t('Not assigned')}',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Bottom Row: Created At Date
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.language.date(user.createdAt),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 3. Trailing Fixed Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit)
                Tooltip(
                  message: Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).tr('edit_user_tooltip'),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showEditUserDialog(context, user, currentUser),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).tr('remove_user_tooltip'),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _confirmDeleteUser(context, user),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF991B1B)
                                : const Color(0xFFFECACA),
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
