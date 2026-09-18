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
      _subscription = _databaseService.streamUserNotifications(uid).listen(
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
    try {
      await _databaseService.markNotificationAsRead(notificationId);
      // The stream will automatically update the list
    } catch (e) {
      debugPrint('Failed to mark as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;
    try {
      await _databaseService.markAllAsRead(_currentUserId!);
    } catch (e) {
      debugPrint('Failed to mark all as read: $e');
    }
  }
}
