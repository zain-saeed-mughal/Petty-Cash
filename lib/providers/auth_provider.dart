import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/push_notification_service.dart';
import '../services/app_error.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService=AuthService();
  AppUser? _currentUser;
  bool _isLoading=false, _disposed=false, _checking=false;
  String? _errorMessage;
  int _generation=0;
  Timer? _profileTimer;
  StreamSubscription<AuthState>? _authEvents;
  AppUser? get currentUser=>_currentUser;
  bool get isLoading=>_isLoading;
  String? get errorMessage=>_errorMessage;
  bool get isAuthenticated=>_currentUser!=null;
  UserRole? get userRole=>_currentUser?.role;
  AuthProvider();
  void _emit(){ if(!_disposed) notifyListeners(); }
  void _watch(){
    if(_profileTimer!=null) return;
    _authEvents=SupabaseService().client?.auth.onAuthStateChange.listen((event){
      if(event.session==null && _currentUser!=null) {
        _currentUser=null; unawaited(PushNotificationService().bindUser(null)); _emit();
      }
    });
    _profileTimer=Timer.periodic(const Duration(seconds:30),(_)=>refreshProfile());
  }
  Future<void> refreshProfile() async {
    if(_checking||_isLoading||_currentUser==null) return;
    _checking=true;
    final generation=_generation;
    final uid=_currentUser?.uid;
    try {
      final profile=await _authService.restoreSession();
      if(!_disposed&&generation==_generation&&_currentUser?.uid==uid) { _currentUser=profile; _emit(); }
    } catch(_) {
      // A transient network error must not impersonate a successful empty profile.
      // Server policies still check active status on every protected operation.
    } finally { _checking=false; }
  }
  Future<void> restoreSession() async {
    _isLoading=true; _errorMessage=null; _emit();
    try {
      _currentUser=await _authService.restoreSession();
      _watch();
      unawaited(PushNotificationService().bindUser(_currentUser?.uid));
    } catch(e) { _currentUser=null; _errorMessage=userMessage(e); }
    finally { _isLoading=false; _emit(); }
  }
  void clearError(){ _errorMessage=null; _emit(); }
  Future<bool> signIn(String email,String password) async {
    if(_isLoading) return false;
    _isLoading=true; _errorMessage=null; _emit();
    try {
      _currentUser=await _authService.signIn(email:email,password:password);
      _watch();
      unawaited(PushNotificationService().bindUser(_currentUser?.uid));
      return _currentUser!=null;
    } catch(e) { _currentUser=null; _errorMessage=userMessage(e); return false; }
    finally { _isLoading=false; _emit(); }
  }
  Future<bool> signUp({required String name,required String email,required String password}) async {
    _errorMessage='Ask an administrator to create your account.'; _emit(); return false;
  }
  Future<void> signOut() async {
    _generation++;
    _currentUser=null; _errorMessage=null; _emit();
    try { await _authService.signOut(); }
    catch(e) { _errorMessage=userMessage(e); _emit(); }
  }
  @override void dispose(){
    _disposed=true; _profileTimer?.cancel(); _authEvents?.cancel(); super.dispose();
  }
}
