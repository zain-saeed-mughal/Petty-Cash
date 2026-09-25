import 'app_error.dart';

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../models/expense_request_model.dart';
import '../models/notification_model.dart';
import 'supabase_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  SupabaseClient get _client =>
      SupabaseService().client ??
      (throw StateError('The service is unavailable. Please retry.'));

  Future<ExpenseRequest> getRequest(String id) async {
    final row = await _client.from('requests').select().eq('id', id).single();
    return ExpenseRequest.fromMap(row);
  }

  Future<ExpenseRequest> createRequest(ExpenseRequest request) async {
    final row = await _client.rpc(
      'submit_request',
      params: {
        'request_id': request.id,
        'item_description': request.itemDescription,
        'request_amount': request.amount,
        'request_reason': request.reason,
        'receipt_path': request.billImageUrl,
        'p_request_type': request.requestType,
      },
    );
    return ExpenseRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<ExpenseRequest> settleAdvanceRequest(
    String requestId,
    int expectedVersion,
    double settlementAmount,
    String? settlementMethod,
    String? settlementNote,
  ) async {
    final row = await _client.rpc(
      'settle_advance_request',
      params: {
        'p_request_id': requestId,
        'p_expected_version': expectedVersion,
        'p_settlement_amount': settlementAmount,
        'p_settlement_method': settlementMethod ?? 'None',
        'p_settlement_note': settlementNote ?? '',
      },
    );
    return ExpenseRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<ExpenseRequest> verifyAdvanceSettlement(
    String requestId,
    int expectedVersion,
  ) async {
    final row = await _client.rpc(
      'verify_advance_settlement',
      params: {
        'p_request_id': requestId,
        'p_expected_version': expectedVersion,
      },
    );
    return ExpenseRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<ExpenseRequest> reviewRequest(
    ExpenseRequest request,
    RequestStatus status, {
    String? note,
    bool override = false,
  }) async {
    final row = await _client.rpc(
      'review_request',
      params: {
        'request_id': request.id,
        'expected_version': request.version,
        'new_status': status.displayName,
        'review_note': note,
        'is_override': override,
      },
    );
    return ExpenseRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteRequest(String id) async {
    await _client.rpc('delete_request', params: {'request_id': id});
  }

  // Fetch every page; a capped Realtime snapshot cannot define a financial total.
  Stream<List<Map<String, dynamic>>> _watch(
    String table,
    String key, {
    String? userId,
  }) {
    late StreamController<List<Map<String, dynamic>>> output;
    RealtimeChannel? channel;
    Timer? debounce;
    Timer? poll;
    bool disposed = false, fetching = false, dirty = false;
    var revision = 0;
    var snapshotReady = false;
    final requestRows = <String, Map<String, dynamic>>{};
    Future<void> refresh() async {
      if (disposed) return;
      if (fetching) {
        dirty = true;
        return;
      }
      fetching = true;
      try {
        if (table == 'requests') {
          // Keep a session-scoped snapshot and fetch only changed rows/tombstones.
          // Stage a complete batch before publishing so a failed page is retryable.
          var nextRevision = revision;
          var changed = false;
          final staged = Map<String, Map<String, dynamic>>.from(requestRows);
          bool more;
          do {
            final result = Map<String, dynamic>.from(
              await _client.rpc(
                'sync_requests',
                params: {'after_revision': nextRevision, 'page_size': 500},
              ),
            );
            if (disposed) return;
            for (final entry in result['changes'] as List) {
              changed = true;
              final change = Map<String, dynamic>.from(entry);
              final id = change['id'] as String;
              if (change['deleted'] == true) {
                staged.remove(id);
              } else {
                staged[id] = Map<String, dynamic>.from(change['request']);
              }
            }
            nextRevision = (result['cursor'] as num).toInt();
            more = result['has_more'] == true;
          } while (more);
          requestRows
            ..clear()
            ..addAll(staged);
          revision = nextRevision;
          if (changed || !snapshotReady) {
            snapshotReady = true;
            output.add(requestRows.values.toList());
          }
          return;
        }
        final rows = <Map<String, dynamic>>[];
        const size = 500;
        for (var offset = 0; ; offset += size) {
          var query = _client.from(table).select();
          if (userId != null) query = query.eq('user_id', userId);
          final page = await query.order(key).range(offset, offset + size - 1);
          if (disposed) return;
          rows.addAll(page);
          if (page.length < size) break;
        }
        output.add(rows);
      } catch (error, stack) {
        // Publish the next successful snapshot even if no rows changed, so
        // providers clear a transient refresh error.
        if (table == 'requests') snapshotReady = false;
        if (!disposed) output.addError(error, stack);
      } finally {
        fetching = false;
        if (dirty && !disposed) {
          dirty = false;
          unawaited(refresh());
        }
      }
    }

    output = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        channel = _client
            .channel('app-$table-${DateTime.now().microsecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              callback: (_) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 250), refresh);
              },
            )
            .subscribe((status, error) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                unawaited(refresh());
              }
            });
        poll = Timer.periodic(
          const Duration(seconds: 45),
          (_) => unawaited(refresh()),
        );
        unawaited(refresh());
      },
      onCancel: () async {
        disposed = true;
        debounce?.cancel();
        poll?.cancel();
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return output.stream;
  }

  Stream<List<ExpenseRequest>> streamAllRequests() =>
      _watch('requests', 'id').map((rows) {
        final result = rows.map((r) => ExpenseRequest.fromMap(r)).toList();
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return result;
      });
  Stream<List<AppUser>> streamAllUsers() => _watch(
    'users',
    'uid',
  ).map((rows) => rows.map((r) => AppUser.fromMap(r)).toList());
  Stream<List<AppNotification>> streamUserNotifications(String uid) =>
      _watch('notifications', 'id', userId: uid).map((rows) {
        final result = rows.map((r) => AppNotification.fromMap(r)).toList();
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return result;
      });
  Future<void> _manageUser(
    Map<String, dynamic> body, {
    bool refreshSession = true,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('Your session expired. Sign out and sign in again.');
    }
    try {
      final response = await _client.functions.invoke(
        'manage-user',
        body: body,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      if (response.status != 200 ||
          response.data is! Map ||
          response.data['ok'] != true) {
        throw StateError(accountServiceMessage(response.status, response.data));
      }
    } on FunctionException catch (error) {
      if (error.status == 401 && refreshSession) {
        await _client.auth.refreshSession();
        return _manageUser(body, refreshSession: false);
      }
      throw StateError(accountServiceMessage(error.status, error.details));
    }
  }

  Future<void> createUser(AppUser user) => _manageUser({
    'action': 'create',
    'name': user.name,
    'email': user.email,
    'password': user.password,
    'role': user.role.roleCode,
    'isActive': user.isActive,
  });
  Future<void> updateUser(AppUser user) => _manageUser({
    'action': 'update',
    'uid': user.uid,
    'name': user.name,
    'email': user.email,
    'password': user.password?.isNotEmpty == true ? user.password : null,
    'role': user.role.roleCode,
    'isActive': user.isActive,
  });
  Future<void> deleteUser(String uid) =>
      _manageUser({'action': 'delete', 'uid': uid});
  Future<void> markNotificationAsRead(String id) async {
    final rows = await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .select('id');
    if (rows.isEmpty) {
      throw StateError('Notification was not updated. Refresh and try again.');
    }
  }

  Future<void> markAllAsRead(String uid) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String id) async {
    final rows = await _client
        .from('notifications')
        .delete()
        .eq('id', id)
        .select('id');
    if (rows.isEmpty) {
      throw StateError('Notification was not removed. Refresh and try again.');
    }
  }
}
