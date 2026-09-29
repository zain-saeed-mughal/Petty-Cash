import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/payment_models.dart';
import '../models/user_model.dart';
import '../services/app_error.dart';
import '../services/database_service.dart';

class PaymentProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _busy = {};
  Timer? _overviewDebounce;
  String? _identity;
  int _generation = 0;
  int _overviewVersion = 0;
  bool _disposed = false;
  bool _loading = false;
  bool _advancesReady = false,
      _expensesReady = false,
      _requestsReady = false,
      _overviewReady = false;
  String? _error;
  List<AdvanceRecord> _advances = [];
  List<AdvanceRequestRecord> _advanceRequests = [];
  List<AdvanceBalance> _advanceBalances = [];
  List<PaymentExpense> _expenses = [];
  List<PaymentActivity> _activity = [];
  List<Map<String, dynamic>> _ledger = [];
  List<FloatSummary> _overview = [];
  DateTime? _reportFrom, _reportTo;

  bool get isLoading => _loading;
  String? get error => _error;
  List<AdvanceRecord> get advances => _advances;
  List<AdvanceRequestRecord> get advanceRequests => _advanceRequests;
  List<AdvanceBalance> get advanceBalances => _advanceBalances;
  List<PaymentExpense> get expenses => _expenses;
  List<PaymentActivity> get activity => _activity;
  List<Map<String, dynamic>> get ledger => _ledger;
  List<FloatSummary> get overview => _overview;
  DateTime? get reportFrom => _reportFrom;
  DateTime? get reportTo => _reportTo;
  bool isBusy(String id) => _busy.contains(id);

  void updateUser(AppUser? user) {
    final identity = user == null ? null : '${user.uid}:${user.role.roleCode}';
    if (_identity == identity) return;
    _identity = identity;
    _generation++;
    _overviewVersion++;
    _overviewDebounce?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _advances = [];
    _advanceRequests = [];
    _advanceBalances = [];
    _expenses = [];
    _activity = [];
    _ledger = [];
    _overview = [];
    _reportFrom = _reportTo = null;
    _error = null;
    _busy.clear();
    _loading = identity != null;
    _advancesReady = _expensesReady = _requestsReady = _overviewReady = false;
    if (identity != null) _subscribe();
  }

  void _subscribe() {
    final generation = _generation;
    void fail(Object error) {
      if (_disposed || generation != _generation) return;
      _error = userMessage(error);
      _loading = false;
      notifyListeners();
    }

    _subscriptions.add(
      _db.streamAdvances().listen((rows) {
        if (_disposed || generation != _generation) return;
        _advances = rows;
        _advancesReady = true;
        _error = null;
        _loading =
            !(_advancesReady &&
                _expensesReady &&
                _requestsReady &&
                _overviewReady);
        notifyListeners();
        _queueOverview();
      }, onError: fail),
    );
    _subscriptions.add(
      _db.streamPaymentExpenses().listen((rows) {
        if (_disposed || generation != _generation) return;
        _expenses = rows;
        _expensesReady = true;
        _error = null;
        _loading =
            !(_advancesReady &&
                _expensesReady &&
                _requestsReady &&
                _overviewReady);
        notifyListeners();
        _queueOverview();
      }, onError: fail),
    );
    _subscriptions.add(
      _db.streamAdvanceRequests().listen((rows) {
        if (_disposed || generation != _generation) return;
        _advanceRequests = rows;
        _requestsReady = true;
        _error = null;
        _loading =
            !(_advancesReady &&
                _expensesReady &&
                _requestsReady &&
                _overviewReady);
        notifyListeners();
      }, onError: fail),
    );
    _subscriptions.add(
      _db.streamPaymentActivity().listen((rows) {
        if (_disposed || generation != _generation) return;
        _activity = rows;
        notifyListeners();
      }, onError: fail),
    );
    _subscriptions.add(
      _db.streamFloatLedger().listen((rows) {
        if (_disposed || generation != _generation) return;
        _ledger = rows;
        notifyListeners();
        _queueOverview();
      }, onError: fail),
    );
    unawaited(refreshOverview());
  }

  void _queueOverview() {
    _overviewDebounce?.cancel();
    _overviewDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(refreshOverview());
    });
  }

  Future<void> refreshOverview() async {
    final generation = _generation;
    final version = ++_overviewVersion;
    try {
      final results = await Future.wait<dynamic>([
        _db.getPaymentOverview(from: _reportFrom, to: _reportTo),
        _db.getAdvanceBalances(),
      ]);
      if (_disposed ||
          generation != _generation ||
          version != _overviewVersion) {
        return;
      }
      _overview = results[0] as List<FloatSummary>;
      _advanceBalances = results[1] as List<AdvanceBalance>;
      _overviewReady = true;
      _error = null;
      _loading =
          !(_advancesReady &&
              _expensesReady &&
              _requestsReady &&
              _overviewReady);
      notifyListeners();
    } catch (error) {
      if (_disposed ||
          generation != _generation ||
          version != _overviewVersion) {
        return;
      }
      _error = userMessage(error);
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setReportRange(DateTime? from, DateTime? to) async {
    _reportFrom = from;
    _reportTo = to;
    notifyListeners();
    await refreshOverview();
  }

  void refresh() {
    if (_identity == null) return;
    _loading = true;
    _advancesReady = _expensesReady = _requestsReady = _overviewReady = false;
    _generation++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _subscribe();
    notifyListeners();
  }

  Future<bool> _perform(String key, Future<void> Function() action) async {
    if (!_busy.add(key)) return false;
    final generation = _generation;
    notifyListeners();
    try {
      await action();
      if (!_disposed && generation == _generation) {
        _error = null;
        _queueOverview();
        notifyListeners();
      }
      return true;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _error = userMessage(error);
        notifyListeners();
      }
      return false;
    } finally {
      _busy.remove(key);
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> giveAdvance({
    String? id,
    required String officeBoyId,
    required double amount,
    required String method,
    String? note,
  }) => _perform('give-advance', () async {
    final row = await _db.giveAdvance(
      id: id ?? const Uuid().v4(),
      officeBoyId: officeBoyId,
      amount: amount,
      method: method,
      note: note,
    );
    _advances = [row, ..._advances.where((item) => item.id != row.id)];
  });

  Future<bool> requestAdvance({
    String? id,
    required double amount,
    required String purpose,
  }) => _perform('request-advance', () async {
    final row = await _db.requestAdvance(
      id: id ?? const Uuid().v4(),
      amount: amount,
      purpose: purpose,
    );
    _advanceRequests = [
      row,
      ..._advanceRequests.where((item) => item.id != row.id),
    ];
  });

  Future<bool> reviewAdvanceRequest(
    String id,
    String decision, {
    String? method,
    String? reason,
  }) => _perform(id, () async {
    final row = await _db.reviewAdvanceRequest(
      id,
      decision,
      method: method,
      reason: reason,
    );
    _advanceRequests = [
      row,
      ..._advanceRequests.where((item) => item.id != row.id),
    ];
    refresh();
  });

  Future<bool> confirmAdvance(String id, String method) =>
      _perform(id, () async {
        final row = await _db.confirmAdvance(id, method);
        _advances = [row, ..._advances.where((item) => item.id != row.id)];
      });

  Future<bool> submitExpense({
    String? id,
    required String flowType,
    required String item,
    required double amount,
    required String reason,
    String? billPath,
    String? advanceId,
  }) => _perform('submit-expense', () async {
    final row = await _db.submitPaymentExpense(
      id: id ?? const Uuid().v4(),
      flowType: flowType,
      item: item,
      amount: amount,
      reason: reason,
      billPath: billPath,
      advanceId: advanceId,
    );
    _expenses = [row, ..._expenses.where((expense) => expense.id != row.id)];
  });

  Future<bool> reviewExpense(
    String id,
    String decision, {
    String? reason,
  }) => _perform(id, () async {
    final row = await _db.reviewPaymentExpense(id, decision, reason: reason);
    _expenses = [row, ..._expenses.where((expense) => expense.id != row.id)];
  });

  Future<bool> acknowledgeRejection(String id) => _perform(id, () async {
    final row = await _db.acknowledgePaymentRejection(id);
    _expenses = [row, ..._expenses.where((expense) => expense.id != row.id)];
  });

  Future<bool> clearPayment(String id, String method) => _perform(id, () async {
    final row = await _db.clearReimbursementPayment(id, method);
    _expenses = [row, ..._expenses.where((expense) => expense.id != row.id)];
  });

  Future<bool> confirmPayment(String id, String method) => _perform(
    id,
    () async {
      final row = await _db.confirmReimbursementPayment(id, method);
      _expenses = [row, ..._expenses.where((expense) => expense.id != row.id)];
    },
  );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _overviewDebounce?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
