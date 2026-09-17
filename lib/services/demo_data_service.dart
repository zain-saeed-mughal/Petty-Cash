import 'dart:async';
import '../models/user_model.dart';
import '../models/expense_request_model.dart';

class DemoDataService {
  static final DemoDataService _instance = DemoDataService._internal();
  factory DemoDataService() => _instance;
  DemoDataService._internal() {
    _initializeDemoData();
  }

  final List<AppUser> _users = [];
  final List<ExpenseRequest> _requests = [];

  final _requestsStreamController = StreamController<List<ExpenseRequest>>.broadcast();
  final _usersStreamController = StreamController<List<AppUser>>.broadcast();

  Stream<List<ExpenseRequest>> get requestsStream => _requestsStreamController.stream;
  Stream<List<AppUser>> get usersStream => _usersStreamController.stream;

  void _initializeDemoData() {
    final now = DateTime.now();

    // Default Seed Users (One for each role)
    _users.addAll([
      AppUser(
        uid: 'demo_super_admin_01',
        name: 'Zain Saeed Mughal',
        email: 'superadmin@company.com',
        role: UserRole.superAdmin,
        createdAt: now.subtract(const Duration(days: 120)),
      ),
      AppUser(
        uid: 'demo_admin_02',
        name: 'Admin',
        email: 'admin@company.com',
        role: UserRole.admin,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      AppUser(
        uid: 'demo_finance_03',
        name: 'Finance',
        email: 'finance@company.com',
        role: UserRole.finance,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      AppUser(
        uid: 'demo_office_boy_04',
        name: 'Office Boy',
        email: 'officeboy@company.com',
        role: UserRole.officeBoy,
        createdAt: now.subtract(const Duration(days: 30)),
      ),

    ]);

    // Sample Expense Requests
    _requests.addAll([
      // Start with a clean slate
    ]);

    _notifyRequests();
    _notifyUsers();
  }

  void _notifyRequests() {
    _requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _requestsStreamController.add(List.unmodifiable(_requests));
  }

  void _notifyUsers() {
    _usersStreamController.add(List.unmodifiable(_users));
  }

  // Auth / Users
  List<AppUser> get allUsers => List.unmodifiable(_users);

  AppUser? findUserByEmail(String email) {
    try {
      return _users.firstWhere(
        (u) => u.email.trim().toLowerCase() == email.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  AppUser? findUserByUid(String uid) {
    try {
      return _users.firstWhere((u) => u.uid == uid);
    } catch (_) {
      return null;
    }
  }

  void addUser(AppUser user) {
    _users.add(user);
    _notifyUsers();
  }

  void updateUser(AppUser user) {
    final index = _users.indexWhere((u) => u.uid == user.uid);
    if (index != -1) {
      _users[index] = user;
      _notifyUsers();
    }
  }

  void removeUser(String uid) {
    _users.removeWhere((u) => u.uid == uid);
    _notifyUsers();
  }

  // Requests
  List<ExpenseRequest> get allRequests => List.unmodifiable(_requests);

  Stream<List<ExpenseRequest>> getRequestsForUser(String uid) {
    return requestsStream.map(
      (list) => list.where((r) => r.requestedBy == uid).toList(),
    );
  }

  Stream<List<ExpenseRequest>> getPendingRequests() {
    return requestsStream.map(
      (list) => list.where((r) => r.status == RequestStatus.pending).toList(),
    );
  }

  void addRequest(ExpenseRequest req) {
    _requests.insert(0, req);
    _notifyRequests();
  }

  void updateRequestStatus(
    String requestId,
    RequestStatus status, {
    String? rejectionReason,
    String? reviewerId,
    String? reviewerName,
  }) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final old = _requests[index];
      _requests[index] = old.copyWith(
        status: status,
        rejectionReason: rejectionReason ?? old.rejectionReason,
        reviewedBy: reviewerId ?? old.reviewedBy,
        reviewedByName: reviewerName ?? old.reviewedByName,
        updatedAt: DateTime.now(),
      );
      _notifyRequests();
    }
  }

  void updateRequest(ExpenseRequest request) {
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index != -1) {
      _requests[index] = request;
      _notifyRequests();
    }
  }

  void deleteRequest(String requestId) {
    _requests.removeWhere((r) => r.id == requestId);
    _notifyRequests();
  }
}
