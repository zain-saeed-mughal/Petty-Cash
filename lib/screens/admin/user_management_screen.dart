import 'package:flutter/material.dart';
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
              Expanded(child: Text('Create New User Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
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
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter full name' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Corporate Email', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter corporate email';
                      if (!v.contains('@')) return 'Please enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Temporary Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please assign a temporary password' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role Assignment', prefixIcon: Icon(Icons.badge_outlined)),
                    items: allowedRoles.map((r) {
                      return DropdownMenuItem(value: r, child: Text(r.displayName));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  final success = await userProvider.addUser(
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                    role: selectedRole,
                  );
                  if (success) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Account for ${nameController.text} created successfully!'),
                        backgroundColor: AppTheme.statusApproved,
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

  void _showEditUserDialog(BuildContext context, AppUser userToEdit, AppUser currentUser) {
    final nameController = TextEditingController(text: userToEdit.name);
    final allowedRoles = currentUser.isSuperAdmin
        ? [UserRole.officeBoy, UserRole.finance, UserRole.admin]
        : [UserRole.officeBoy, UserRole.finance];

    UserRole selectedRole = allowedRoles.contains(userToEdit.role) ? userToEdit.role : allowedRoles.first;
    bool isActive = userToEdit.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Account: ${userToEdit.name}'),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Assigned Role'),
                  items: allowedRoles.map((r) => DropdownMenuItem(value: r, child: Text(r.displayName))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('Account Active'),
                  subtitle: Text(isActive ? 'User can log in' : 'Access suspended'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
              ],
            ),
          ),
        ),
        actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                final updated = userToEdit.copyWith(
                  name: nameController.text.trim(),
                  role: selectedRole,
                  isActive: isActive,
                );
                final success = await userProvider.updateUser(updated);
                if (success) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Account updated successfully!'), backgroundColor: AppTheme.statusApproved),
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
        content: Text('Are you sure you want to remove ${userToDelete.name} (${userToDelete.email})? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRejected),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              final success = await userProvider.deleteUser(userToDelete.uid);
              if (success) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('User account removed.'), backgroundColor: AppTheme.statusRejected),
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
        return u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User Accounts Management',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser.isSuperAdmin
                              ? 'Super Admin: Manage all organizational users, Finance, Admins & Staff'
                              : 'Admin: Manage Office Boy and Finance accounts',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add User'),
                    onPressed: () => _showAddUserDialog(context, currentUser),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Filter Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search users by name or email...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All Users (${manageable.length})', null),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Office Boy (${manageable.where((u) => u.isOfficeBoy).length})',
                            UserRole.officeBoy,
                            color: AppTheme.roleOfficeBoy,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Finance (${manageable.where((u) => u.isFinance).length})',
                            UserRole.finance,
                            color: AppTheme.roleFinance,
                          ),
                          if (currentUser.isSuperAdmin) ...[
                            const SizedBox(width: 8),
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
              const SizedBox(height: 20),

              // Users List Table / Cards
              if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.people_outline_rounded, size: 56, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text('No Users Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Try adjusting your search criteria or create a new user account.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final u = filtered[index];
                    return _buildUserCard(u, currentUser);
                  },
                ),
            ],
          ),
        ),
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
          color: isSelected ? (color ?? AppTheme.primaryBlue) : AppTheme.borderLight,
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

    final canEdit = currentUser.isSuperAdmin || (currentUser.isAdmin && (user.isOfficeBoy || user.isFinance));
    final canDelete = (currentUser.isSuperAdmin && user.uid != currentUser.uid) ||
        (currentUser.isAdmin && (user.isOfficeBoy || user.isFinance));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.primaryNavy),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.role.displayName,
                        style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            _dateFormat.format(user.createdAt),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          const SizedBox(width: 8),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
              tooltip: 'Edit User',
              onPressed: () => _showEditUserDialog(context, user, currentUser),
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.statusRejected),
              tooltip: 'Remove User',
              onPressed: () => _confirmDeleteUser(context, user),
            ),
        ],
      ),
    );
  }
}
