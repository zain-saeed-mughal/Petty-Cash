import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../config/app_constants.dart';
import 'supabase_service.dart';
import 'push_notification_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AppUser? _currentActiveUser;
  AppUser? get currentUser => _currentActiveUser;

  SupabaseClient? get _client => SupabaseService().client;

  Future<void> _updateFcmToken(AppUser user) async {
    final token = await PushNotificationService().getDeviceToken();
    if (token != null && token != user.fcmToken) {
      final client = _client;
      if (client != null) {
        try {
          await client
              .from(AppConstants.usersCollection)
              .update({'fcmToken': token})
              .eq('uid', user.uid);
          _currentActiveUser = user.copyWith(fcmToken: token);
        } catch (e) {
          debugPrint('Failed to update FCM token: $e');
        }
      }
    }
  }

  Future<AppUser?> restoreSession() async {
    final client = _client;
    if (client == null) {
      _currentActiveUser = null;
      return null;
    }

    final Session? session = client.auth.currentSession;
    final String? userId;
    if (session != null) {
      userId = session.user.id;
    } else {
      userId = null;
    }

    if (userId != null) {
      try {
        final data = await client
            .from(AppConstants.usersCollection)
            .select()
            .eq('uid', userId)
            .maybeSingle();

        if (data != null) {
          final user = AppUser.fromMap(data, docId: userId);
          if (user.isActive) {
            _currentActiveUser = user;
            await _updateFcmToken(user);
            return _currentActiveUser;
          }
          await client.auth.signOut();
          _currentActiveUser = null;
          return null;
        }
      } catch (e) {
        debugPrint('Failed to restore session profile: $e');
      }
    }

    _currentActiveUser = null;
    return null;
  }

  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not initialized. Please try again later.');
    }

    final cleanEmail = email.trim().toLowerCase();

    try {
      final authResponse = await client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      final uid = authResponse.user?.id;
      if (uid != null) {
        final data = await client
            .from(AppConstants.usersCollection)
            .select()
            .eq('uid', uid)
            .maybeSingle();

        if (data != null) {
          final user = AppUser.fromMap(data, docId: uid);
          if (!user.isActive) {
            throw Exception(
              'This account is inactive. Please contact your administrator.',
            );
          }
          _currentActiveUser = user;
          await _updateFcmToken(user);
          return _currentActiveUser;
        } else {
          throw Exception(
            'User profile not found. Please contact an Administrator.',
          );
        }
      }
      throw Exception('Authentication failed.');
    } on AuthException catch (e) {
      debugPrint('Supabase AuthException: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('Supabase signIn error: $e');
      throw Exception('An unexpected error occurred during login.');
    }
  }

  Future<AppUser?> signUp({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.officeBoy,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not initialized. Please try again later.');
    }

    final cleanEmail = email.trim().toLowerCase();

    try {
      final authResponse = await client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'name': name.trim()},
      );

      final uid = authResponse.user?.id;
      if (uid == null) {
        throw Exception('Sign up failed: No UID returned.');
      }

      final newUser = AppUser(
        uid: uid,
        name: name.trim(),
        email: cleanEmail,
        role: role,
        createdAt: DateTime.now(),
      );

      await client.from(AppConstants.usersCollection).insert(newUser.toMap());

      _currentActiveUser = newUser;
      await _updateFcmToken(newUser);
      return _currentActiveUser;
    } on AuthException catch (e) {
      debugPrint('Supabase AuthException: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('Supabase signUp error: $e');
      throw Exception('An unexpected error occurred during sign up.');
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (e) {
        debugPrint('Supabase signOut error: $e');
      }
    }
    _currentActiveUser = null;
  }
}
