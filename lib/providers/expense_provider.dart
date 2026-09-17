import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/expense_request_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<ExpenseRequest> _allRequests = [];
  StreamSubscription<List<ExpenseRequest>>? _requestsSubscription;
  bool _isLoading = false;
  String? _errorMessage;

  // Filter & Search states
  String _searchQuery = '';
  RequestStatus? _statusFilter;

  List<ExpenseRequest> get allRequests => _allRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  RequestStatus? get statusFilter => _statusFilter;

  ExpenseProvider() {
    _initSubscription();
  }

  void _initSubscription() {
    _isLoading = true;
    notifyListeners();

    _requestsSubscription?.cancel();
    _requestsSubscription = _databaseService.streamAllRequests().listen(
      (requests) {
        _allRequests = requests;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = err.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  void setStatusFilter(RequestStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  // Filtered requests for Office Boy (Only own requests)
  List<ExpenseRequest> getMyRequests(String uid) {
    return _allRequests.where((req) {
      if (req.requestedBy != uid) return false;
      if (_statusFilter != null && req.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final matchDesc = req.itemDescription.toLowerCase().contains(
          _searchQuery,
        );
        final matchReason = req.reason.toLowerCase().contains(_searchQuery);
        return matchDesc || matchReason;
      }
      return true;
    }).toList();
  }

  // Pending requests for Finance approval
  List<ExpenseRequest> get pendingRequests {
    return _allRequests.where((req) {
      if (req.status != RequestStatus.pending) return false;
      if (_searchQuery.isNotEmpty) {
        final matchDesc = req.itemDescription.toLowerCase().contains(
          _searchQuery,
        );
        final matchName = req.requesterName.toLowerCase().contains(
          _searchQuery,
        );
        return matchDesc || matchName;
      }
      return true;
    }).toList();
  }

  // Payment history for Finance (Approved, Paid, or Rejected)
  List<ExpenseRequest> get paymentHistory {
    return _allRequests.where((req) {
      if (req.status == RequestStatus.pending) return false;
      if (_statusFilter != null && req.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final matchDesc = req.itemDescription.toLowerCase().contains(
          _searchQuery,
        );
        final matchName = req.requesterName.toLowerCase().contains(
          _searchQuery,
        );
        return matchDesc || matchName;
      }
      return true;
    }).toList();
  }

  // All transactions (Admin & Super Admin)
  List<ExpenseRequest> get filteredAllTransactions {
    return _allRequests.where((req) {
      if (_statusFilter != null && req.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final matchDesc = req.itemDescription.toLowerCase().contains(
          _searchQuery,
        );
        final matchName = req.requesterName.toLowerCase().contains(
          _searchQuery,
        );
        final matchReason = req.reason.toLowerCase().contains(_searchQuery);
        return matchDesc || matchName || matchReason;
      }
      return true;
    }).toList();
  }

  // Analytics getters
  double get totalSpent => _allRequests
      .where(
        (r) =>
            r.status == RequestStatus.approved ||
            r.status == RequestStatus.paid,
      )
      .fold(0.0, (sum, r) => sum + r.amount);

  double get pendingAmount => _allRequests
      .where((r) => r.status == RequestStatus.pending)
      .fold(0.0, (sum, r) => sum + r.amount);

  int get pendingCount =>
      _allRequests.where((r) => r.status == RequestStatus.pending).length;

  int get approvedCount => _allRequests
      .where(
        (r) =>
            r.status == RequestStatus.approved ||
            r.status == RequestStatus.paid,
      )
      .length;

  int get rejectedCount =>
      _allRequests.where((r) => r.status == RequestStatus.rejected).length;

  int get totalTransactionsCount => _allRequests.length;

  double get approvalRate {
    final reviewedCount = approvedCount + rejectedCount;
    if (reviewedCount == 0) return 0.0;
    return (approvedCount / reviewedCount) * 100;
  }

  // Actions
  Future<bool> submitRequest({
    required AppUser user,
    required String itemDescription,
    required double amount,
    required String reason,
    String? billImageUrl,
  }) async {
    try {
      final newId = 'REQ-${_uuid.v4().substring(0, 8).toUpperCase()}';
      final request = ExpenseRequest(
        id: newId,
        requestedBy: user.uid,
        requesterName: user.name,
        requesterEmail: user.email,
        itemDescription: itemDescription.trim(),
        amount: amount,
        reason: reason.trim(),
        billImageUrl: billImageUrl,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        auditLogs: [
          AuditLogEntry(
            timestamp: DateTime.now(),
            action: 'Created request',
            performerId: user.uid,
            performerName: user.name,
          ),
        ],
      );

      await _databaseService.createRequest(request);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Finance Approval
  Future<bool> approveRequest({
    required String requestId,
    required AppUser reviewer,
    bool markAsPaidImmediately = true,
  }) async {
    try {
      final status = markAsPaidImmediately
          ? RequestStatus.paid
          : RequestStatus.approved;
      final currentReq = _allRequests.firstWhere((r) => r.id == requestId);
      final newLogs = List<AuditLogEntry>.from(currentReq.auditLogs);
      newLogs.add(
        AuditLogEntry(
          timestamp: DateTime.now(),
          action: 'Status changed to ${status.displayName}',
          performerId: reviewer.uid,
          performerName: reviewer.name,
        ),
      );

      final updated = currentReq.copyWith(
        status: status,
        reviewedBy: reviewer.uid,
        reviewedByName: reviewer.name,
        updatedAt: DateTime.now(),
        auditLogs: newLogs,
      );

      await _databaseService.updateRequest(updated);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Finance Rejection with mandatory reason
  Future<bool> rejectRequest({
    required String requestId,
    required String rejectionReason,
    required AppUser reviewer,
  }) async {
    if (rejectionReason.trim().isEmpty) {
      _errorMessage = 'Rejection reason is mandatory';
      notifyListeners();
      return false;
    }

    try {
      final currentReq = _allRequests.firstWhere((r) => r.id == requestId);
      final newLogs = List<AuditLogEntry>.from(currentReq.auditLogs);
      newLogs.add(
        AuditLogEntry(
          timestamp: DateTime.now(),
          action: 'Status changed to Rejected',
          performerId: reviewer.uid,
          performerName: reviewer.name,
          notes: rejectionReason.trim(),
        ),
      );

      final updated = currentReq.copyWith(
        status: RequestStatus.rejected,
        rejectionReason: rejectionReason.trim(),
        reviewedBy: reviewer.uid,
        reviewedByName: reviewer.name,
        updatedAt: DateTime.now(),
        auditLogs: newLogs,
      );

      await _databaseService.updateRequest(updated);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Super Admin: Override status
  Future<bool> overrideStatus({
    required String requestId,
    required RequestStatus newStatus,
    required AppUser adminUser,
    String? note,
  }) async {
    try {
      final currentReq = _allRequests.firstWhere((r) => r.id == requestId);
      final newLogs = List<AuditLogEntry>.from(currentReq.auditLogs);
      newLogs.add(
        AuditLogEntry(
          timestamp: DateTime.now(),
          action: 'Status overridden to ${newStatus.displayName}',
          performerId: adminUser.uid,
          performerName: adminUser.name,
          notes: note,
        ),
      );

      final updated = currentReq.copyWith(
        status: newStatus,
        rejectionReason: note,
        reviewedBy: adminUser.uid,
        reviewedByName: '${adminUser.name} (Override)',
        updatedAt: DateTime.now(),
        auditLogs: newLogs,
      );

      await _databaseService.updateRequest(updated);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Super Admin: Delete request
  Future<bool> deleteRequest(String requestId) async {
    try {
      await _databaseService.deleteRequest(requestId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
