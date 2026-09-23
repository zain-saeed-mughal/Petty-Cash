import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/database_service.dart';

class NotificationProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<AppNotification> _notifications = [];
  StreamSubscription<List<AppNotification>>? _subscription;
  String? _currentUserId;

  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void updateUser(String? uid) {
    if (_currentUserId == uid) return; // No change
    _currentUserId = uid;

    _subscription?.cancel();
    _notifications.clear();

    if (uid != null) {
      _subscription = _databaseService
          .streamUserNotifications(uid)
          .listen(
            (notifs) {
              _notifications = notifs;
              notifyListeners();
            },
            onError: (err) {
              debugPrint('Notification stream error: $err');
            },
          );
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> markAsRead(String notificationId) async {
    // Optimistic update
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      final n = _notifications[index];
      _notifications[index] = AppNotification(
        id: n.id,
        userId: n.userId,
        title: n.title,
        message: n.message,
        isRead: true,
        relatedRequestId: n.relatedRequestId,
        createdAt: n.createdAt,
      );
      notifyListeners();
    }

    try {
      await _databaseService.markNotificationAsRead(notificationId);
    } catch (e) {
      debugPrint('Failed to mark as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;
    
    // Optimistic update
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        final n = _notifications[i];
        _notifications[i] = AppNotification(
          id: n.id,
          userId: n.userId,
          title: n.title,
          message: n.message,
          isRead: true,
          relatedRequestId: n.relatedRequestId,
          createdAt: n.createdAt,
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();

    try {
      await _databaseService.markAllAsRead(_currentUserId!);
    } catch (e) {
      debugPrint('Failed to mark all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    // Optimistic update for instant UI feedback
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();

    try {
      await _databaseService.deleteNotification(notificationId);
    } catch (e) {
      debugPrint('Failed to delete notification: $e');
    }
  }
}
