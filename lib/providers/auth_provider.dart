import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/demo_data_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  UserRole? get userRole => _currentUser?.role;

  AuthProvider() {
    // Default to the first demo user (Office Boy) so user can see it right away or log in
    _currentUser = DemoDataService().findUserByEmail('officeboy@company.com');
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(email: email, password: password);
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signUp(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  // Quick switch role button for 1-click effortless testing & demos
  void switchRole(UserRole role) {
    String targetEmail;
    switch (role) {
      case UserRole.superAdmin:
        targetEmail = 'superadmin@company.com';
        break;
      case UserRole.admin:
        targetEmail = 'admin@company.com';
        break;
      case UserRole.finance:
        targetEmail = 'finance@company.com';
        break;
      case UserRole.officeBoy:
        targetEmail = 'officeboy@company.com';
        break;
    }

    final user = DemoDataService().findUserByEmail(targetEmail);
    if (user != null) {
      _currentUser = user;
      _authService.setDemoUser(user);
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
