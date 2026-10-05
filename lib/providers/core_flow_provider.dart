import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/core_flow_models.dart';
import '../models/user_model.dart';
import '../services/app_error.dart';
import '../services/database_service.dart';

class CoreFlowProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _ready = <String>{};
  final _errors = <String, String>{};
  final _busy = <String>{};
  String? _identity;
  int _generation = 0;
  bool _disposed = false;
  List<OfficeRecord> offices = [];
  List<CoreAdvance> advances = [];
  List<CoreAdvanceItem> items = [];
  List<CoreBalance> balances = [];
  List<CoreReimbursement> reimbursements = [];
  List<CoreActivity> activity = [];

  bool get isLoading =>
      _identity != null && _ready.length < 6 && _errors.isEmpty;
  String? get error => _errors.values.firstOrNull;
  bool isBusy(String key) => _busy.contains(key);
  double balanceFor(String uid) => balances
      .where((row) => row.officeBoyId == uid)
      .fold(0, (sum, row) => sum + row.remaining);
  CoreBalance? balanceForAdvance(String id) =>
      balances.where((row) => row.advanceId == id).firstOrNull;

  void updateUser(AppUser? user) {
    final identity = user == null
        ? null
        : '${user.uid}:${user.role.roleCode}:${user.officeId}';
    if (_identity == identity) return;
    _identity = identity;
    refresh();
  }

  void refresh() {
    _generation++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _ready.clear();
    _errors.clear();
    offices = [];
    advances = [];
    items = [];
    balances = [];
    reimbursements = [];
    activity = [];
    if (_identity == null) {
      notifyListeners();
      return;
    }
    final generation = _generation;
    void add<T>(
      String name,
      Stream<List<T>> stream,
      void Function(List<T>) save,
    ) {
      _subscriptions.add(
        stream.listen(
          (rows) {
            if (_disposed || generation != _generation) return;
            save(rows);
            _ready.add(name);
            _errors.remove(name);
            notifyListeners();
          },
          onError: (Object e) {
            if (_disposed || generation != _generation) return;
            _errors[name] = userMessage(e);
            notifyListeners();
          },
        ),
      );
    }

    add('offices', _db.streamOffices(), (rows) => offices = rows);
    add('advances', _db.streamCoreAdvances(), (rows) {
      advances = rows;
      unawaited(_loadBalances(generation));
    });
    add('items', _db.streamCoreAdvanceItems(), (rows) {
      items = rows;
      unawaited(_loadBalances(generation));
    });
    add(
      'reimbursements',
      _db.streamCoreReimbursements(),
      (rows) => reimbursements = rows,
    );
    add('activity', _db.streamCoreActivity(), (rows) => activity = rows);
    unawaited(_loadBalances(generation));
    notifyListeners();
  }

  Future<void> _loadBalances(int generation) async {
    try {
      final rows = await _db.getCoreBalances();
      if (_disposed || generation != _generation) return;
      balances = rows;
      _ready.add('balances');
      _errors.remove('balances');
      notifyListeners();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _errors['balances'] = userMessage(e);
      notifyListeners();
    }
  }

  Future<bool> _run(String key, Future<void> Function() action) async {
    if (!_busy.add(key)) return false;
    final generation = _generation;
    notifyListeners();
    try {
      await action();
      if (!_disposed && generation == _generation) {
        _errors.remove('action');
        unawaited(_loadBalances(generation));
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _errors['action'] = userMessage(e);
        notifyListeners();
      }
      return false;
    } finally {
      _busy.remove(key);
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> requestAdvance({
    String? id,
    required String purpose,
    required double amount,
    required String method,
    String? accountName,
    String? accountDetails,
  }) => _run('request-advance', () async {
    final row = await _db.requestCoreAdvance(
      id: id ?? const Uuid().v4(),
      purpose: purpose,
      amount: amount,
      method: method,
      accountName: accountName,
      accountDetails: accountDetails,
    );
    advances = [row, ...advances.where((entry) => entry.id != row.id)];
  });

  Future<bool> clearAdvance(String id, String method, String? note) =>
      _run(id, () async {
        final row = await _db.clearCoreAdvance(id, method, note);
        advances = [row, ...advances.where((entry) => entry.id != row.id)];
      });

  Future<bool> addItem({
    String? id,
    required String advanceId,
    required String item,
    required double amount,
    String? billPath,
  }) => _run('add-item', () async {
    final row = await _db.logCoreAdvanceItem(
      id: id ?? const Uuid().v4(),
      advanceId: advanceId,
      item: item,
      amount: amount,
      billPath: billPath,
    );
    items = [row, ...items.where((entry) => entry.id != row.id)];
  });

  Future<bool> reviewAdvanceItem(
    String id,
    String decision,
    String? reason,
  ) => _run(id, () async {
    final row = await _db.reviewCoreAdvanceItem(id, decision, reason);
    items = [row, ...items.where((entry) => entry.id != row.id)];
  });

  Future<bool> directAllotAdvance({
    String? id,
    required String officeBoyId,
    required double amount,
    required String purpose,
    required String method,
  }) => _run('direct-allot', () async {
    final row = await _db.directAllotAdvanceV2(
      id: id ?? const Uuid().v4(),
      officeBoyId: officeBoyId,
      amount: amount,
      purpose: purpose,
      method: method,
    );
    advances = [row, ...advances.where((entry) => entry.id != row.id)];
  });

  Future<bool> respondToDirectAdvance(String id, String decision) =>
      _run(id, () async {
        await _db.respondToDirectAdvanceV2(id, decision);
        final index = advances.indexWhere((a) => a.id == id);
        if (index != -1) {
          final old = advances[index];
          advances = List.from(advances)..[index] = CoreAdvance(
            id: old.id,
            officeBoyId: old.officeBoyId,
            officeId: old.officeId,
            purpose: old.purpose,
            method: old.method,
            status: decision == 'approve' ? 'cleared' : 'declined',
            accountName: old.accountName,
            accountDetails: old.accountDetails,
            clearedMethod: old.clearedMethod,
            financeNote: old.financeNote,
            amount: old.amount,
            createdAt: old.createdAt,
            clearedAt: old.clearedAt,
          );
        }
      });

  Future<bool> requestReimbursement({
    String? id,
    required String item,
    required double amount,
    required String method,
    String? billPath,
    String? accountName,
    String? accountDetails,
  }) => _run('request-reimbursement', () async {
    final row = await _db.submitCoreReimbursement(
      id: id ?? const Uuid().v4(),
      item: item,
      amount: amount,
      method: method,
      billPath: billPath,
      accountName: accountName,
      accountDetails: accountDetails,
    );
    reimbursements = [
      row,
      ...reimbursements.where((entry) => entry.id != row.id),
    ];
  });

  Future<bool> reviewReimbursement(
    String id,
    String decision,
    String? reason,
  ) => _run(id, () async {
    final row = await _db.reviewCoreReimbursement(id, decision, reason);
    reimbursements = [
      row,
      ...reimbursements.where((entry) => entry.id != row.id),
    ];
  });

  Future<bool> markReimbursementPaid(String id, String method) =>
      _run(id, () async {
        final row = await _db.markCoreReimbursementPaid(id, method);
        reimbursements = [
          row,
          ...reimbursements.where((entry) => entry.id != row.id),
        ];
      });

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
