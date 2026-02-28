import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/app_router.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  late final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'aurum_notifications',
    'Aurum Notifications',
    description: 'Canal principal de notificaciones de Aurum',
    importance: Importance.high,
  );

  bool _initialized = false;
  bool _firebaseReady = false;
  String? _lastRegisteredToken;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
    _bindAuthChanges();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (_) => _openNotificationsInbox(),
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Push disabled: Firebase no configurado. $e');
      return;
    }

    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }

      _messaging.onTokenRefresh.listen((token) async {
        if (token.isEmpty) return;
        await _registerToken(token);
      });

      FirebaseMessaging.onMessage.listen((message) {
        _showLocalFromRemote(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleRemoteTap(message);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleRemoteTap(initialMessage);
      }
    } catch (e) {
      debugPrint('Error inicializando FCM: $e');
    }
  }

  void _bindAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      if (!_firebaseReady) return;

      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed ||
          event.event == AuthChangeEvent.userUpdated) {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _registerToken(token);
        }
      }
    });
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.functions.invoke(
        'notifications-register-device',
        body: {
          'fcm_token': token,
          'platform': _platformName(),
          'device_label': 'flutter-app',
          'app_version': '1.0.0',
        },
      );
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('No se pudo registrar token push: $e');
    }
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'android';
    }
  }

  Future<void> _showLocalFromRemote(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    if (title == null && body == null) return;

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title ?? 'Aurum',
      body: body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleRemoteTap(RemoteMessage _) {
    _openNotificationsInbox();
  }

  void _openNotificationsInbox() {
    appRouter.go('/notifications');
  }
}
