import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../config/app_constants.dart';
import 'demo_data_service.dart';
import 'supabase_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isSupabaseAvailable = false;
  AppUser? _currentActiveUser;

  bool get isSupabaseAvailable => _isSupabaseAvailable;
  AppUser? get currentUser => _currentActiveUser;

  void initialize({bool enableSupabase = true}) {
    _isSupabaseAvailable = enableSupabase;
  }

  // Sign In with email & password
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check Demo Accounts first for instant convenience
    final demoUser = DemoDataService().findUserByEmail(cleanEmail);
    if (demoUser != null) {
      _currentActiveUser = demoUser;
      return demoUser;
    }

    // 2. Try Real Supabase Auth if available
    if (_isSupabaseAvailable && SupabaseService().client != null) {
      try {
        final authResponse = await SupabaseService().client!.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );

        final uid = authResponse.user?.id;
        if (uid != null) {
          final data = await SupabaseService()
              .client!
              .from(AppConstants.usersCollection)
              .select()
              .eq('uid', uid)
              .maybeSingle();

          if (data != null) {
            final user = AppUser.fromMap(data, docId: uid);
            _currentActiveUser = user;
            return user;
          } else {
            // Document does not exist yet, create default user
            final newUser = AppUser(
              uid: uid,
              name: authResponse.user?.userMetadata?['name'] ?? cleanEmail.split('@').first,
              email: cleanEmail,
              role: UserRole.officeBoy, // Default role
              createdAt: DateTime.now(),
            );
            await SupabaseService()
                .client!
                .from(AppConstants.usersCollection)
                .insert(newUser.toMap());
            _currentActiveUser = newUser;
            return newUser;
          }
        }
      } catch (e) {
        debugPrint('Supabase signIn error: $e');
        rethrow;
      }
    }

    throw Exception('User account not found. Please check your email or pick a quick-login demo role.');
  }

  // Sign Up with Role
  Future<AppUser?> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (_isSupabaseAvailable && SupabaseService().client != null) {
      try {
        final authResponse = await SupabaseService().client!.auth.signUp(
          email: cleanEmail,
          password: password,
          data: {'name': name.trim()},
        );

        final uid = authResponse.user?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
        final newUser = AppUser(
          uid: uid,
          name: name.trim(),
          email: cleanEmail,
          role: role,
          createdAt: DateTime.now(),
        );

        await SupabaseService()
            .client!
            .from(AppConstants.usersCollection)
            .insert(newUser.toMap());

        _currentActiveUser = newUser;
        return newUser;
      } catch (e) {
        debugPrint('Supabase signUp error: $e');
        rethrow;
      }
    } else {
      // Create local user in Demo Service
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final newUser = AppUser(
        uid: uid,
        name: name.trim(),
        email: cleanEmail,
        role: role,
        createdAt: DateTime.now(),
      );
      DemoDataService().addUser(newUser);
      _currentActiveUser = newUser;
      return newUser;
    }
  }

  // Quick switch role (for instant testing during demo)
  void setDemoUser(AppUser user) {
    _currentActiveUser = user;
  }

  // Sign Out
  Future<void> signOut() async {
    if (_isSupabaseAvailable && SupabaseService().client != null) {
      try {
        await SupabaseService().client!.auth.signOut();
      } catch (e) {
        debugPrint('Supabase signOut error: $e');
      }
    }
    _currentActiveUser = null;
  }
}
