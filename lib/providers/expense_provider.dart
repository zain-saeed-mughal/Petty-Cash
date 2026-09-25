import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/expense_request_model.dart';
import '../models/user_model.dart';
import '../services/app_error.dart';
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

  String? _identity;
  bool _disposed = false;
  int _generation = 0;
  final Stream<List<ExpenseRequest>> Function() _requestStream;
  ExpenseProvider({Stream<List<ExpenseRequest>> Function()? requests})
    : _requestStream = requests ?? DatabaseService().streamAllRequests;
  void updateUser(AppUser? user) {
    final identity = user == null ? null : '${user.uid}:${user.role.roleCode}';
    if (identity == _identity) return;
    _identity = identity;
    _generation++;
    _requestsSubscription?.cancel();
    _allRequests = [];
    _errorMessage = null;
    _isLoading = false;
    _searchQuery = '';
    _statusFilter = null;
    if (identity != null) _initSubscription();
  }

  void refresh() {
    if (_identity != null) {
      _initSubscription();
      notifyListeners();
    }
  }

  ExpenseRequest? findRequest(String id) {
    for (final r in _allRequests) {
      if (r.id == id) return r;
    }
    return null;
  }

  void _accept(ExpenseRequest request) {
    _allRequests = [request, ..._allRequests.where((r) => r.id != request.id)];
    _errorMessage = null;
    if (!_disposed) notifyListeners();
  }

  void _initSubscription() {
    _isLoading = true;
    final generation = ++_generation;

    _requestsSubscription?.cancel();
    _requestsSubscription = _requestStream().listen(
      (requests) {
        if (_disposed || generation != _generation) return;
        _errorMessage = null;
        _allRequests = requests;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        if (_disposed || generation != _generation) return;
        _errorMessage = userMessage(err);
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
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
      if (!req.needsFinanceReview) return false;
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
  double get totalSpent =>
      _allRequests.fold(0.0, (sum, r) => sum + r.disbursedAmount);

  double get verifiedExpenses =>
      _allRequests.fold(0.0, (sum, r) => sum + r.verifiedExpense);
  double get returnedAmount =>
      _allRequests.fold(0.0, (sum, r) => sum + r.verifiedReturn);
  double get outstandingAdvances =>
      _allRequests.fold(0.0, (sum, r) => sum + r.outstandingAdvance);

  double get pendingAmount => _allRequests
      .where((r) => r.needsFinanceReview)
      .fold(0.0, (sum, r) => sum + r.amount);

  int get pendingCount =>
      _allRequests.where((r) => r.needsFinanceReview).length;

  int get approvedCount => _allRequests
      .where((r) => r.status == RequestStatus.approved || r.hasDisbursement)
      .length;

  int get rejectedCount =>
      _allRequests.where((r) => r.status == RequestStatus.rejected).length;

  int get totalTransactionsCount => _allRequests.length;

  double get approvalRate {
    final reviewedCount = approvedCount + rejectedCount;
    if (reviewedCount == 0) return 0.0;
    return (approvedCount / reviewedCount) * 100;
  }

  Future<bool> submitRequest({
    required AppUser user,
    required String itemDescription,
    required double amount,
    required String reason,
    String? billImageUrl,
    String? requestId,
    String requestType = 'reimbursement',
  }) async {
    final generation = _generation;
    try {
      final now = DateTime.now().toUtc();
      final request = ExpenseRequest(
        id: requestId ?? _uuid.v4(),
        requestedBy: user.uid,
        requesterName: user.name,
        requesterEmail: user.email,
        itemDescription: itemDescription.trim(),
        amount: amount,
        reason: reason.trim(),
        billImageUrl: billImageUrl,
        createdAt: now,
        updatedAt: now,
        requestType: requestType,
      );
      final saved = await _databaseService.createRequest(request);
      if (!_disposed && generation == _generation) _accept(saved);
      return true;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> _review(
    String id,
    RequestStatus status, {
    String? note,
    bool override = false,
    int? expectedVersion,
  }) async {
    final generation = _generation;
    try {
      final request = findRequest(id);
      if (request == null) {
        throw StateError('Request not found. Refresh and try again.');
      }
      if (expectedVersion != null && expectedVersion != request.version) {
        throw StateError(
          'This request changed. Please review its latest details.',
        );
      }
      final saved = await _databaseService.reviewRequest(
        request,
        status,
        note: note,
        override: override,
      );
      if (!_disposed && generation == _generation) _accept(saved);
      return true;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> approveRequest({
    required String requestId,
    required AppUser reviewer,
    bool markAsPaidImmediately = true,
    int? expectedVersion,
  }) => _review(
    requestId,
    markAsPaidImmediately ? RequestStatus.paid : RequestStatus.approved,
    expectedVersion: expectedVersion,
  );
  Future<bool> rejectRequest({
    required String requestId,
    required String rejectionReason,
    required AppUser reviewer,
    int? expectedVersion,
  }) => _review(
    requestId,
    RequestStatus.rejected,
    note: rejectionReason,
    expectedVersion: expectedVersion,
  );
  Future<bool> overrideStatus({
    required String requestId,
    required RequestStatus newStatus,
    required AppUser adminUser,
    String? note,
    int? expectedVersion,
  }) => _review(
    requestId,
    newStatus,
    note: note,
    override: true,
    expectedVersion: expectedVersion,
  );

  Future<bool> settleAdvance({
    required String requestId,
    required double settlementAmount,
    required String settlementMethod,
    String? note,
    int? expectedVersion,
  }) async {
    final generation = _generation;
    try {
      final request = findRequest(requestId);
      if (request == null) throw StateError('Request not found.');
      if (expectedVersion != null && expectedVersion != request.version) {
        throw StateError(
          'This request changed. Please review its latest details.',
        );
      }
      final saved = await _databaseService.settleAdvanceRequest(
        requestId,
        request.version,
        settlementAmount,
        settlementMethod,
        note,
      );
      if (!_disposed && generation == _generation) _accept(saved);
      return true;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> verifySettlement({
    required String requestId,
    int? expectedVersion,
  }) async {
    final generation = _generation;
    try {
      final request = findRequest(requestId);
      if (request == null) throw StateError('Request not found.');
      if (expectedVersion != null && expectedVersion != request.version) {
        throw StateError(
          'This request changed. Please review its latest details.',
        );
      }
      final saved = await _databaseService.verifyAdvanceSettlement(
        requestId,
        request.version,
      );
      if (!_disposed && generation == _generation) _accept(saved);
      return true;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> deleteRequest(String requestId) async {
    final generation = _generation;
    try {
      await _databaseService.deleteRequest(requestId);
      if (!_disposed && generation == _generation) {
        _allRequests.removeWhere((r) => r.id == requestId);
        _errorMessage = null;
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    }
  }
}
