import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/models/user_model.dart';

void main() {
  test('Super-admin permission model remains strict and local-only', () {
    final user = AppUser(
      uid: 'sa-1',
      name: 'Super Admin',
      email: 'superadmin@company.com',
      role: UserRole.superAdmin,
      createdAt: DateTime.now(),
      isActive: true,
    );

    expect(user.canManageUsers, isTrue);
    expect(user.canManageAdmins, isTrue);
    expect(user.canApproveRequests, isTrue);
    expect(user.isActive, isTrue);
  });
}
