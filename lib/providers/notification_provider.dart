import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../services/app_error.dart';

class NotificationProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<AppNotification> _notifications = [];
  StreamSubscription<List<AppNotification>>? _subscription;
  String? _currentUserId;
  String? _errorMessage;
  int _generation = 0;
  bool _disposed = false, _isLoading = false;
  final Set<String> _busy = {};
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  void updateUser(String? uid) {
    if (_currentUserId == uid) return;
    _currentUserId = uid;
    _generation++;
    _subscription?.cancel();
    _notifications = [];
    _errorMessage = null;
    _busy.clear();
    _isLoading = uid != null;
    if (uid != null) _listen(uid);
  }

  void _listen(String uid) {
    final generation = ++_generation;
    _subscription?.cancel();
    _subscription = _databaseService
        .streamUserNotifications(uid)
        .listen(
          (rows) {
            if (_disposed || generation != _generation) return;
            _notifications = rows;
            _errorMessage = null;
            _isLoading = false;
            notifyListeners();
          },
          onError: (Object e) {
            if (_disposed || generation != _generation) return;
            _errorMessage = userMessage(e);
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void refresh() {
    if (_currentUserId != null) {
      _isLoading = true;
      _listen(_currentUserId!);
      notifyListeners();
    }
  }

  Future<bool> _run(
    String key,
    Future<void> Function() action,
    void Function() accept,
  ) async {
    if (!_busy.add(key)) return false;
    final generation = _generation;
    try {
      await action();
      if (!_disposed && generation == _generation) {
        accept();
        _errorMessage = null;
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _errorMessage = userMessage(e);
        notifyListeners();
      }
      return false;
    } finally {
      _busy.remove(key);
    }
  }

  AppNotification _read(AppNotification n) => AppNotification(
    id: n.id,
    userId: n.userId,
    title: n.title,
    message: n.message,
    isRead: true,
    relatedRequestId: n.relatedRequestId,
    createdAt: n.createdAt,
  );
  Future<bool> markAsRead(String id) =>
      _run(id, () => _databaseService.markNotificationAsRead(id), () {
        _notifications = _notifications
            .map((n) => n.id == id ? _read(n) : n)
            .toList();
      });
  Future<bool> markAllAsRead() async {
    final uid = _currentUserId;
    if (uid == null) return false;
    return _run('all', () => _databaseService.markAllAsRead(uid), () {
      _notifications = _notifications.map(_read).toList();
    });
  }

  Future<bool> deleteNotification(String id) =>
      _run(id, () => _databaseService.deleteNotification(id), () {
        _notifications.removeWhere((n) => n.id == id);
      });
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }
}
