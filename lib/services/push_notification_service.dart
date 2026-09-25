import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();
  final messages = StreamController<RemoteMessage>.broadcast();
  final openedRequests = StreamController<String>.broadcast();
  String? _uid, _token;
  String _language = 'en';
  RemoteMessage? _pendingOpen;
  Future<void> _registration = Future.value();
  void setLanguage(String language) {
    if (_language == language) return;
    _language = language;
    final token = _token;
    if (token != null && _uid != null) unawaited(_register(token, _generation));
  }

  void flushPendingOpen() {
    final message = _pendingOpen;
    if (message != null && _uid != null && openedRequests.hasListener) {
      _pendingOpen = null;
      _open(message);
    }
  }

  int _generation = 0;
  bool _initialized = false;
  Future<void>? _initializing;
  String? lastError;
  bool get supported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    if (_initialized || !supported) return;
    try {
      if (Firebase.apps.isEmpty) {
        const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
        const appId = String.fromEnvironment('FIREBASE_APP_ID');
        const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
        const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
        if (kIsWeb &&
            [apiKey, appId, projectId, senderId].any((v) => v.isEmpty)) {
          throw StateError(
            'Push notifications are not configured for this web deployment.',
          );
        }
        await Firebase.initializeApp(
          options: apiKey.isEmpty
              ? null
              : const FirebaseOptions(
                  apiKey: apiKey,
                  appId: appId,
                  messagingSenderId: senderId,
                  projectId: projectId,
                  iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
                ),
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen((m) {
        if (_uid != null && m.data['user_id'] == _uid) messages.add(m);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) {
          if (_uid != null) unawaited(_register(token, _generation));
        },
        onError: (Object e) {
          lastError = 'Device registration could not be refreshed.';
        },
      );
      _initialized = true;
      lastError = null;
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      lastError = 'Push notifications are unavailable. In-app notifications still work.';
      _initializing = null;
    }
  }

  void _open(RemoteMessage message) {
    final id = message.data['request_id'];
    if (id is! String || id.isEmpty) return;
    if (_uid == null || !openedRequests.hasListener) {
      _pendingOpen = message;
    } else if (message.data['user_id'] == _uid) {
      openedRequests.add(id);
    }
  }

  Future<void> _register(String token, int generation) =>
      _registration = _registration.then((_) async {
        final client = SupabaseService().client;
        if (client == null || _uid == null || generation != _generation) return;
        _token = token;
        try {
          await client
              .rpc(
                'register_device_language',
                params: {
                  'device_token': token,
                  'device_language': _language,
                  'device_platform':
                      (kIsWeb ||
                          (defaultTargetPlatform != TargetPlatform.android &&
                              defaultTargetPlatform != TargetPlatform.iOS))
                      ? 'web'
                      : (defaultTargetPlatform == TargetPlatform.android
                            ? 'android'
                            : 'iOS'),
                },
              )
              .timeout(const Duration(seconds: 10));
          if (generation == _generation) {
            _token = token;
            lastError = null;
          }
        } catch (_) {
          if (generation == _generation) {
            lastError =
                'Notifications could not register this device. Try again.';
          }
        }
      });

  Future<void> bindUser(String? uid) async {
    if (_uid == uid) return;
    final oldToken = _token;
    _uid = uid;
    _token = null;
    final generation = ++_generation;
    if (uid == null) {
      _pendingOpen = null;
      await _registration;
      if (oldToken != null) {
        try {
          await SupabaseService().client
              ?.rpc('unregister_device', params: {'device_token': oldToken})
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
      if (_initialized) {
        try {
          await FirebaseMessaging.instance.deleteToken().timeout(
            const Duration(seconds: 5),
          );
        } catch (_) {}
      }
      return;
    }
    await initialize();
    if (!_initialized || generation != _generation) return;
    flushPendingOpen();
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await getDeviceToken();
        if (token != null) await _register(token, generation);
      }
    } catch (_) {
      lastError = 'Unable to check notification permission.';
    }
  }

  Future<bool> enable() async {
    await initialize();
    if (!_initialized || _uid == null) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        lastError = 'Allow notifications in your device or browser settings.';
        return false;
      }
      final token = await getDeviceToken();
      if (token == null) return false;
      await _register(token, _generation);
      return lastError == null;
    } catch (_) {
      lastError = 'Notifications could not be enabled. Please try again.';
      return false;
    }
  }

  Future<String?> getDeviceToken() async {
    if (!_initialized) return null;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        if (await FirebaseMessaging.instance.getAPNSToken() == null) {
          lastError =
              'Apple notification registration is pending. Try again shortly.';
          return null;
        }
      }
      const vapid = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
      if (kIsWeb && vapid.isEmpty) {
        lastError = 'Web push is not configured.';
        return null;
      }
      return await FirebaseMessaging.instance
          .getToken(vapidKey: kIsWeb ? vapid : null)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      lastError = 'Device notification registration failed.';
      return null;
    }
  }
}
