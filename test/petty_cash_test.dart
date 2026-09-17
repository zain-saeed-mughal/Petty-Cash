import 'package:flutter_test/flutter_test.dart';
import 'package:petty_cash/models/user_model.dart';
import 'package:petty_cash/models/expense_request_model.dart';
import 'package:petty_cash/services/demo_data_service.dart';
import 'package:petty_cash/providers/expense_provider.dart';

void main() {
  group('Petty Cash Models & RBAC Permissions', () {
    test('User roles and permission helpers', () {
      final superAdmin = AppUser(
        uid: 'sa_1',
        name: 'Super Admin User',
        email: 'sa@company.com',
        role: UserRole.superAdmin,
        createdAt: DateTime.now(),
      );

      final admin = AppUser(
        uid: 'adm_1',
        name: 'Admin User',
        email: 'adm@company.com',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );

      final finance = AppUser(
        uid: 'fin_1',
        name: 'Finance User',
        email: 'fin@company.com',
        role: UserRole.finance,
        createdAt: DateTime.now(),
      );

      final officeBoy = AppUser(
        uid: 'ob_1',
        name: 'Office Boy User',
        email: 'ob@company.com',
        role: UserRole.officeBoy,
        createdAt: DateTime.now(),
      );

      // Super Admin Permissions
      expect(superAdmin.canManageUsers, isTrue);
      expect(superAdmin.canManageAdmins, isTrue);
      expect(superAdmin.canDeleteTransactions, isTrue);
      expect(superAdmin.canOverrideStatus, isTrue);

      // Admin Permissions
      expect(admin.canManageUsers, isTrue);
      expect(admin.canManageAdmins, isFalse);
      expect(admin.canDeleteTransactions, isFalse);
      expect(admin.canOverrideStatus, isFalse);

      // Finance Permissions
      expect(finance.canApproveRequests, isTrue);
      expect(finance.canManageUsers, isFalse);

      // Office Boy Permissions
      expect(officeBoy.canApproveRequests, isFalse);
      expect(officeBoy.canManageUsers, isFalse);
    });

    test('Expense Request flow and statuses', () {
      final req = ExpenseRequest(
        id: 'REQ-TEST-1',
        requestedBy: 'ob_1',
        requesterName: 'Ali Khan',
        itemDescription: 'Notebooks and Pens',
        amount: 25.0,
        reason: 'Restocking desk stationery',
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(req.isPending, isTrue);
      expect(req.isApproved, isFalse);
      expect(req.isRejected, isFalse);

      final approvedReq = req.copyWith(
        status: RequestStatus.approved,
        reviewedBy: 'fin_1',
        reviewedByName: 'Elena',
      );
      expect(approvedReq.isApproved, isTrue);

      final rejectedReq = req.copyWith(
        status: RequestStatus.rejected,
        rejectionReason: 'Invalid receipt image',
      );
      expect(rejectedReq.isRejected, isTrue);
      expect(rejectedReq.rejectionReason, equals('Invalid receipt image'));
    });
  });

  group('Demo Data Service & Expense Provider', () {
    test('Seeded accounts are initialized for all 4 roles', () {
      final demo = DemoDataService();
      expect(demo.findUserByEmail('superadmin@company.com')?.role, equals(UserRole.superAdmin));
      expect(demo.findUserByEmail('admin@company.com')?.role, equals(UserRole.admin));
      expect(demo.findUserByEmail('finance@company.com')?.role, equals(UserRole.finance));
      expect(demo.findUserByEmail('officeboy@company.com')?.role, equals(UserRole.officeBoy));
    });

    test('Office Boy receives only their requests', () {
      final provider = ExpenseProvider();
      final myRequests = provider.getMyRequests('demo_office_boy_04');
      for (final req in myRequests) {
        expect(req.requestedBy, equals('demo_office_boy_04'));
      }
    });

    test('Finance pending requests contain only pending status', () {
      final provider = ExpenseProvider();
      final pending = provider.pendingRequests;
      for (final req in pending) {
        expect(req.status, equals(RequestStatus.pending));
      }
    });
  });
}
