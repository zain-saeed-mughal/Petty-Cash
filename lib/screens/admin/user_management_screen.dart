import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../config/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  UserRole? _roleFilter;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddUserDialog(BuildContext context, AppUser currentUser) {
    final parentContext = context;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    // Roles available to be assigned based on current actor
    final List<UserRole> allowedRoles = currentUser.isSuperAdmin
        ? [UserRole.officeBoy, UserRole.finance, UserRole.admin]
        : [UserRole.officeBoy, UserRole.finance];

    UserRole selectedRole = allowedRoles.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.person_add_rounded, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create New User Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter full name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Corporate Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter corporate email';
                        }
                        if (!v.contains('@')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Temporary Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please assign a temporary password'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role Assignment',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: allowedRoles.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(r.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);
                  final userProvider = Provider.of<UserProvider>(
                    context,
                    listen: false,
                  );
                  final success = await userProvider.addUser(
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                    role: selectedRole,
                  );
                  if (!parentContext.mounted) return;
                  if (success) {
                    final createdName = nameController.text.trim();
                    final createdEmail = emailController.text
                        .trim()
                        .toLowerCase();
                    final temporaryPassword = passwordController.text.trim();
                    navigator.pop();
                    _showTemporaryCredentialsDialog(
                      parentContext,
                      name: createdName,
                      email: createdEmail,
                      temporaryPassword: temporaryPassword,
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to create account: ${userProvider.errorMessage}',
                        ),
                        backgroundColor: AppTheme.statusRejected,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Account'),
            ),
          ],
        ),
      ),
    );
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
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppTheme.statusApproved),
            SizedBox(width: 8),
            Expanded(child: Text('Account Created')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$name can use these temporary credentials:'),
              const SizedBox(height: 16),
              _credentialRow('Email', email),
              const SizedBox(height: 10),
              _credentialRow('Temporary password', temporaryPassword),
              const SizedBox(height: 14),
              const Text(
                'Share this password securely. It is shown only once and is not saved in the profile.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
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
            tooltip: 'Copy $label',
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
            },
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(
    BuildContext context,
    AppUser userToEdit,
    AppUser currentUser,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: userToEdit.name);
    final emailController = TextEditingController(text: userToEdit.email);
    final passwordController = TextEditingController();
    final allowedRoles = currentUser.isSuperAdmin
        ? [UserRole.officeBoy, UserRole.finance, UserRole.admin]
        : [UserRole.officeBoy, UserRole.finance];

    if (userToEdit.role == UserRole.superAdmin) {
      allowedRoles.insert(0, UserRole.superAdmin);
    }

    UserRole selectedRole = allowedRoles.contains(userToEdit.role)
        ? userToEdit.role
        : allowedRoles.first;
    bool isActive = userToEdit.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Account: ${userToEdit.name}'),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Corporate Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Invalid email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'New Password (optional)',
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'Only set this when changing credentials',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Role',
                      ),
                      items: allowedRoles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: userToEdit.isSuperAdmin
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() => selectedRole = val);
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      title: const Text('Account Active'),
                      subtitle: Text(
                        isActive ? 'User can log in' : 'Access suspended',
                      ),
                      value: isActive,
                      onChanged: userToEdit.isSuperAdmin
                          ? null
                          : (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ), // Column
              ), // Form
            ), // SingleChildScrollView
          ), // Container
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                final newPassword = passwordController.text.trim();
                final updated = userToEdit.copyWith(
                  name: nameController.text.trim(),
                  email: emailController.text.trim().toLowerCase(),
                  password: newPassword.isEmpty ? null : newPassword,
                  role: selectedRole,
                  isActive: isActive,
                );
                final success = await userProvider.updateUser(updated);
                if (success) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Account updated successfully!'),
                      backgroundColor: AppTheme.statusApproved,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteUser(BuildContext context, AppUser userToDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
          'Are you sure you want to remove ${userToDelete.name} (${userToDelete.email})? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              final success = await userProvider.deleteUser(userToDelete.uid);
              if (success) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('User account removed.'),
                    backgroundColor: AppTheme.statusRejected,
                  ),
                );
              }
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
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

    return CustomScrollView(
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
                              const Text(
                                'User Accounts Management',
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
                                    ? 'Super Admin: Manage all organizational users, Finance, Admins & Staff'
                                    : 'Admin: Manage Office Boy and Finance accounts',
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
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: const Text('Add'),
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
                              hintText: 'Search users by name or email...',
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
                                  'All Users (${manageable.length})',
                                  null,
                                ),
                                const SizedBox(width: 12),
                                _buildFilterChip(
                                  'Office Boy (${manageable.where((u) => u.isOfficeBoy).length})',
                                  UserRole.officeBoy,
                                  color: AppTheme.roleOfficeBoy,
                                ),
                                const SizedBox(width: 12),
                                _buildFilterChip(
                                  'Finance (${manageable.where((u) => u.isFinance).length})',
                                  UserRole.finance,
                                  color: AppTheme.roleFinance,
                                ),
                                if (currentUser.isSuperAdmin) ...[
                                  const SizedBox(width: 12),
                                  _buildFilterChip(
                                    'Admin (${manageable.where((u) => u.isAdmin).length})',
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
                    const Text(
                      'No Users Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try adjusting your search criteria or create a new user account.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
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
                      user.role.displayName,
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
          _dateFormat.format(user.createdAt),
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
                tooltip: 'Edit User',
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
                tooltip: 'Remove User',
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
