import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/expense_request_model.dart';
import '../models/notification_model.dart';
import '../config/app_constants.dart';
import 'supabase_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Helper to get client
  SupabaseClient get _client => SupabaseService().client!;

  // ==========================================
  // EXPENSE REQUESTS
  // ==========================================

  Future<void> createRequest(ExpenseRequest request) async {
    try {
      await _client
          .from(AppConstants.requestsCollection)
          .insert(request.toMap());
    } catch (e) {
      debugPrint('Supabase createRequest error: $e');
      rethrow;
    }
  }

  Stream<List<ExpenseRequest>> streamUserRequests(String uid) {
    return _client
        .from(AppConstants.requestsCollection)
        .stream(primaryKey: ['id'])
        .eq('requestedBy', uid)
        .order('createdAt', ascending: false)
        .map((data) => data
            .map((map) => ExpenseRequest.fromMap(map, docId: map['id']))
            .toList());
  }

  Stream<List<ExpenseRequest>> streamPendingRequests() {
    return _client
        .from(AppConstants.requestsCollection)
        .stream(primaryKey: ['id'])
        .eq('status', AppConstants.statusPending)
        .order('createdAt', ascending: false)
        .map((data) => data
            .map((map) => ExpenseRequest.fromMap(map, docId: map['id']))
            .toList());
  }

  Stream<List<ExpenseRequest>> streamAllRequests() {
    return _client
        .from(AppConstants.requestsCollection)
        .stream(primaryKey: ['id'])
        .order('createdAt', ascending: false)
        .map((data) => data
            .map((map) => ExpenseRequest.fromMap(map, docId: map['id']))
            .toList());
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required RequestStatus status,
    String? rejectionReason,
    String? reviewerId,
    String? reviewerName,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': status.displayName,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }
      if (reviewerId != null) {
        updateData['reviewedBy'] = reviewerId;
      }
      if (reviewerName != null) {
        updateData['reviewedByName'] = reviewerName;
      }

      await _client
          .from(AppConstants.requestsCollection)
          .update(updateData)
          .eq('id', requestId);
    } catch (e) {
      debugPrint('Supabase updateRequestStatus error: $e');
      rethrow;
    }
  }

  Future<void> updateRequest(ExpenseRequest request) async {
    try {
      await _client
          .from(AppConstants.requestsCollection)
          .update(request.toMap())
          .eq('id', request.id);
    } catch (e) {
      debugPrint('Supabase updateRequest error: $e');
      rethrow;
    }
  }

  Future<void> deleteRequest(String requestId) async {
    try {
      await _client
          .from(AppConstants.requestsCollection)
          .delete()
          .eq('id', requestId);
    } catch (e) {
      debugPrint('Supabase deleteRequest error: $e');
      rethrow;
    }
  }

  // ==========================================
  // USERS MANAGEMENT
  // ==========================================

  Stream<List<AppUser>> streamAllUsers() {
    return _client
        .from(AppConstants.usersCollection)
        .stream(primaryKey: ['uid'])
        .map((data) => data
            .map((map) => AppUser.fromMap(map, docId: map['uid']))
            .toList());
  }

  Future<void> createUser(AppUser user) async {
    try {
      await _client.rpc('admin_create_user', params: {
        'user_email': user.email,
        'user_password': user.password ?? '',
        'user_name': user.name,
        'user_role': user.role.roleCode,
      });
    } catch (e) {
      debugPrint('Supabase createUser RPC error: $e');
      if ((user.uid).trim().isEmpty) {
        throw Exception('A valid user UID is required when the RPC fallback is used.');
      }
      try {
        await _client.from(AppConstants.usersCollection).insert({
          'uid': user.uid,
          'name': user.name,
          'email': user.email,
          'role': user.role.roleCode,
          'createdAt': user.createdAt.toUtc().toIso8601String(),
          'isActive': user.isActive,
        });
      } catch (fallbackError) {
        debugPrint('Supabase fallback createUser error: $fallbackError');
        rethrow;
      }
    }
  }

  Future<void> updateUser(AppUser user) async {
    try {
      final updatedProfile = {
        'name': user.name,
        'email': user.email,
        'role': user.role.roleCode,
        'createdAt': user.createdAt.toUtc().toIso8601String(),
        'isActive': user.isActive,
      };

      await _client.from(AppConstants.usersCollection).update(updatedProfile).eq('uid', user.uid);

      final password = (user.password ?? '').trim();
      if (password.isNotEmpty) {
        try {
          await _client.rpc('update_user_credentials', params: {
            'user_id': user.uid,
            'new_email': user.email,
            'new_password': password,
          });
        } catch (rpcError) {
          debugPrint('RPC update_user_credentials failed: $rpcError');
        }
      }
    } catch (e) {
      debugPrint('Supabase updateUser error: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      // First attempt to call the RPC function to completely delete from auth.users
      // (which automatically cascades to public.users)
      try {
        await _client.rpc('delete_user', params: {'user_id': uid});
      } catch (rpcError) {
        // Fallback: If RPC is not created, at least delete from public.users
        debugPrint('RPC delete_user failed (missing function?), falling back to table delete: $rpcError');
        await _client.from(AppConstants.usersCollection).delete().eq('uid', uid);
      }
    } catch (e) {
      debugPrint('Supabase deleteUser error: $e');
      rethrow;
    }
  }

  // ==========================================
  // NOTIFICATIONS
  // ==========================================

  Future<void> createNotification(AppNotification notification) async {
    try {
      await _client
          .from('notifications')
          .insert(notification.toMap());
    } catch (e) {
      debugPrint('Supabase createNotification error: $e');
      rethrow;
    }
  }

  Stream<List<AppNotification>> streamUserNotifications(String uid) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((data) => data
            .map((map) => AppNotification.fromMap(map, docId: map['id']))
            .toList());
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Supabase markNotificationAsRead error: $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead(String uid) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Supabase markAllAsRead error: $e');
      rethrow;
    }
  }
}
