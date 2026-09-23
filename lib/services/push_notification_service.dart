import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level function to handle background messages from Firebase.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp();

      // Request permissions for iOS and newer Android versions
      // Don't await this so it doesn't block the Splash Screen
      _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      ).then((settings) {
        debugPrint('User granted permission: ${settings.authorizationStatus}');
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );
        }
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  }

  Future<String?> getDeviceToken() async {
    try {
      // Add a timeout to prevent the app from hanging if FCM is unavailable
      String? token = await _fcm.getToken().timeout(const Duration(seconds: 5));
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }
}
