import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/app_error.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<AppUser> _allUsers = [];
  StreamSubscription<List<AppUser>>? _usersSubscription;
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  UserRole? _roleFilter;

  List<AppUser> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  UserRole? get roleFilter => _roleFilter;

  String? _identity;
  bool _disposed = false;
  int _generation = 0;
  UserProvider();
  void updateUserSession(AppUser? user) {
    final identity = user == null ? null : '${user.uid}:${user.role.roleCode}';
    if (identity == _identity) return;
    _identity = identity;
    _generation++;
    _usersSubscription?.cancel();
    _allUsers = [];
    _errorMessage = null;
    _isLoading = false;
    _searchQuery = '';
    _roleFilter = null;
    if (identity != null) _initSubscription();
  }

  void refresh() {
    if (_identity != null) {
      _initSubscription();
      notifyListeners();
    }
  }

  void _initSubscription() {
    _isLoading = true;
    final generation = ++_generation;

    _usersSubscription?.cancel();
    _usersSubscription = _databaseService.streamAllUsers().listen(
      (users) {
        if (_disposed || generation != _generation) return;
        _errorMessage = null;
        _allUsers = users;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        if (_disposed || generation != _generation) return;
        _errorMessage = userMessage(err);
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _usersSubscription?.cancel();
    super.dispose();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  void setRoleFilter(UserRole? role) {
    _roleFilter = role;
    notifyListeners();
  }

  List<AppUser> get filteredUsers {
    return _allUsers.where((user) {
      if (_roleFilter != null && user.role != _roleFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final matchName = user.name.toLowerCase().contains(_searchQuery);
        final matchEmail = user.email.toLowerCase().contains(_searchQuery);
        return matchName || matchEmail;
      }
      return true;
    }).toList();
  }

  // Filtered list based on managing actor:
  // Admin can only see and manage Office Boy & Finance
  // Super Admin sees all
  List<AppUser> getManageableUsers(AppUser currentUser) {
    return filteredUsers.where((user) {
      if (currentUser.isSuperAdmin) return true;
      if (currentUser.isAdmin) {
        // Admin can only manage Office Boy and Finance
        return user.role == UserRole.officeBoy || user.role == UserRole.finance;
      }
      return false;
    }).toList();
  }

  Future<bool> addUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final newUser = AppUser(
        uid: '', // RPC will generate the actual UID in the database
        name: name.trim(),
        email: email.trim().toLowerCase(),
        role: role,
        password: password,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _databaseService.createUser(newUser);
      if (!_disposed) {
        _errorMessage = null;
        refresh();
      }
      return true;
    } catch (e) {
      if (!_disposed) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateUser(AppUser user) async {
    try {
      await _databaseService.updateUser(user);
      if (!_disposed) {
        _errorMessage = null;
        refresh();
      }
      return true;
    } catch (e) {
      if (!_disposed) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> deleteUser(String uid) async {
    try {
      await _databaseService.deleteUser(uid);
      if (!_disposed) {
        _errorMessage = null;
        refresh();
      }
      return true;
    } catch (e) {
      if (!_disposed) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    }
  }
}
