import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';
import 'push_notification_service.dart';

class AuthService {
  static final AuthService _instance=AuthService._internal();
  factory AuthService()=>_instance;
  AuthService._internal();
  AppUser? _currentActiveUser;
  AppUser? get currentUser=>_currentActiveUser;
  SupabaseClient? get _client=>SupabaseService().client;

  Future<AppUser?> restoreSession() async {
    final client=_client;
    final uid=client?.auth.currentSession?.user.id;
    if(client==null||uid==null) { _currentActiveUser=null; return null; }
    final data=await client.from('users').select().eq('uid',uid).maybeSingle();
    if(data==null||data['isActive']!=true) {
      await signOut(); return null;
    }
    return _currentActiveUser=AppUser.fromMap(data);
  }
  Future<AppUser?> signIn({required String email,required String password}) async {
    final client=_client;
    if(client==null) throw StateError('Connection unavailable. Restart and try again.');
    try {
      await client.auth.signInWithPassword(email:email.trim().toLowerCase(),password:password);
      final user=await restoreSession();
      if(user==null) throw StateError('Your account is inactive or has not been provisioned. Contact an administrator.');
      return user;
    } catch(_) {
      _currentActiveUser=null;
      await client.auth.signOut(scope:SignOutScope.local);
      rethrow;
    }
  }
  Future<AppUser?> signUp({required String name,required String email,required String password,UserRole role=UserRole.officeBoy}) async {
    throw StateError('Please ask an administrator to create your account.');
  }
  Future<void> signOut() async {
    await PushNotificationService().bindUser(null);
    _currentActiveUser=null;
    // Local sign-out always removes this device's session, including offline use.
    await _client?.auth.signOut(scope:SignOutScope.local);
  }
}

