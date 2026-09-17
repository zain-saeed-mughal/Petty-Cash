import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/expense_request_model.dart';
import '../config/app_constants.dart';
import 'supabase_service.dart';
import 'demo_data_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // ==========================================
  // EXPENSE REQUESTS
  // ==========================================

  // Create new request
  Future<void> createRequest(ExpenseRequest request) async {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        await client
            .from(AppConstants.requestsCollection)
            .insert(request.toMap());
        return;
      } catch (e) {
        debugPrint('Supabase createRequest error, adding to demo service: $e');
      }
    }
    DemoDataService().addRequest(request);
  }

  // Stream requests submitted by a specific user (for Office Boy)
  Stream<List<ExpenseRequest>> streamUserRequests(String uid) {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        return client
            .from(AppConstants.requestsCollection)
            .stream(primaryKey: ['id'])
            .eq('requestedBy', uid)
            .order('createdAt', ascending: false)
            .map((data) => data
                .map((map) => ExpenseRequest.fromMap(map, docId: map['id']))
                .toList());
      } catch (e) {
        debugPrint('Supabase streamUserRequests fallback: $e');
      }
    }
    return DemoDataService().getRequestsForUser(uid);
  }

  // Stream all pending requests (for Finance review)
  Stream<List<ExpenseRequest>> streamPendingRequests() {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        return client
            .from(AppConstants.requestsCollection)
            .stream(primaryKey: ['id'])
            .eq('status', AppConstants.statusPending)
            .order('createdAt', ascending: false)
            .map((data) => data
                .map((map) => ExpenseRequest.fromMap(map, docId: map['id']))
                .toList());
      } catch (e) {
        debugPrint('Supabase streamPendingRequests fallback: $e');
      }
    }
    return DemoDataService().getPendingRequests();
  }

  // Stream all transactions (for Admin, Super Admin, Finance History)
  Stream<List<ExpenseRequest>> streamAllRequests() {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        return client
            .from(AppConstants.requestsCollection)
            .stream(primaryKey: ['id'])
            .order('createdAt', ascending: false)
            .map((data) => data
                .map((map) => ExpenseRequest.fromMap(map, docId: map['id']))
                .toList());
      } catch (e) {
        debugPrint('Supabase streamAllRequests fallback: $e');
      }
    }
    return DemoDataService().requestsStream;
  }

  // Update status (Approve, Reject, or Super Admin Override)
  Future<void> updateRequestStatus({
    required String requestId,
    required RequestStatus status,
    String? rejectionReason,
    String? reviewerId,
    String? reviewerName,
  }) async {
    final client = SupabaseService().client;
    if (client != null) {
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

        await client
            .from(AppConstants.requestsCollection)
            .update(updateData)
            .eq('id', requestId);
        return;
      } catch (e) {
        debugPrint('Supabase updateRequestStatus error, using demo service: $e');
      }
    }

    DemoDataService().updateRequestStatus(
      requestId,
      status,
      rejectionReason: rejectionReason,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
    );
  }

  // Edit an existing request
  Future<void> updateRequest(ExpenseRequest request) async {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        await client
            .from(AppConstants.requestsCollection)
            .update(request.toMap())
            .eq('id', request.id);
        return;
      } catch (e) {
        debugPrint('Supabase updateRequest fallback: $e');
      }
    }
    
    // Fallback for Demo/Offline mode
    DemoDataService().updateRequest(request);
  }

  // Delete request (Super Admin only)
  Future<void> deleteRequest(String requestId) async {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        await client
            .from(AppConstants.requestsCollection)
            .delete()
            .eq('id', requestId);
        return;
      } catch (e) {
        debugPrint('Supabase deleteRequest fallback: $e');
      }
    }
    DemoDataService().deleteRequest(requestId);
  }

  // ==========================================
  // USERS MANAGEMENT
  // ==========================================

  // Stream all users
  Stream<List<AppUser>> streamAllUsers() {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        return client
            .from(AppConstants.usersCollection)
            .stream(primaryKey: ['uid'])
            .map((data) => data
                .map((map) => AppUser.fromMap(map, docId: map['uid']))
                .toList());
      } catch (e) {
        debugPrint('Supabase streamAllUsers fallback: $e');
      }
    }
    return DemoDataService().usersStream;
  }

  // Create or register a user
  Future<void> createUser(AppUser user) async {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        await client
            .from(AppConstants.usersCollection)
            .insert(user.toMap());
        return;
      } catch (e) {
        debugPrint('Supabase createUser fallback: $e');
      }
    }
    DemoDataService().addUser(user);
  }

  // Update user
  Future<void> updateUser(AppUser user) async {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        await client
            .from(AppConstants.usersCollection)
            .update(user.toMap())
            .eq('uid', user.uid);
        return;
      } catch (e) {
        debugPrint('Supabase updateUser fallback: $e');
      }
    }
    DemoDataService().updateUser(user);
  }

  // Remove / delete user
  Future<void> deleteUser(String uid) async {
    final client = SupabaseService().client;
    if (client != null) {
      try {
        await client.from(AppConstants.usersCollection).delete().eq('uid', uid);
        return;
      } catch (e) {
        debugPrint('Supabase deleteUser fallback: $e');
      }
    }
    DemoDataService().removeUser(uid);
  }
}
