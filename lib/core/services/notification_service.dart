import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import '../../firebase_options.dart';
import '../utils/device_helper.dart';
import '../../main.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';

class NotificationService with WidgetsBindingObserver {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _currentUserId;
  static Map<String, dynamic>? pendingRoute;

  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;

    try {
      await _requestPermissions();

      FlutterAppBadgeControl.removeBadge();

      // ✅ IMPORTANT FIX: Register background handler
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.max,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosInit =
      DarwinInitializationSettings();

      const InitializationSettings initSettings =
      InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );

      // ✅ App opened from terminated state (FCM)
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(
          jsonEncode(initialMessage.data.isNotEmpty
              ? initialMessage.data
              : {"route": null}),
        );
      }

      // ✅ App opened from local notification
      final details =
      await _localNotifications.getNotificationAppLaunchDetails();

      if (details?.didNotificationLaunchApp ?? false) {
        _handleNotificationTap(details?.notificationResponse?.payload);
      }

      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // Background tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(jsonEncode(message.data));
      });

      // Token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        if (_currentUserId != null) {
          registerToken(_currentUserId!, tokenOverride: newToken);
        }
      });

      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification init error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _requestPermissions() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> registerToken(String uid, {String? tokenOverride}) async {
    try {
      _currentUserId = uid;

      String? token = tokenOverride ?? await _fcm.getToken();
      if (token == null) return;

      final deviceId = await DeviceHelper.getDeviceId();
      final deviceInfo = await DeviceHelper.getDeviceInfo();

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'deviceId': deviceId,
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'deviceInfo': deviceInfo,
        'isActive': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Token register error: $e');
    }
  }

  Future<void> removeToken(String uid) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('fcmTokens')
            .doc(token)
            .delete();
      }
      await _fcm.deleteToken();
      _currentUserId = null;
    } catch (e) {
      debugPrint('Remove token error: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'Push notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    try {
      final data = json.decode(payload);

      FlutterAppBadgeControl.removeBadge();

      if (data is Map<String, dynamic>) {
        final route = data['route'];
        if (route == null) return;

        pendingRoute = data;

        if (rootNavigatorKey.currentState != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            pendingRoute = null;
            rootNavigatorKey.currentState?.pushNamed(route, arguments: data);
          });
        }
      }
    } catch (e) {
      debugPrint('Notification tap error: $e');
    }
  }

  static void checkPendingRoute() {
    final pending = pendingRoute;

    if (pending != null && pending.containsKey('route')) {
      pendingRoute = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        rootNavigatorKey.currentState?.pushNamed(
          pending['route'],
          arguments: pending,
        );
      });
    }
  }

  Future<void> createInAppNotification({
    required String uid,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? payload,
    bool showLocalPush = true,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'payload': payload,
        'fcmSent': showLocalPush,
        'source': 'client',
      });

      if (showLocalPush) {
        await showPushNotification(
          title: title,
          body: body,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('In-app notification error: $e');
    }
  }

  Future<void> showPushNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentUserId != null) {
      debugPrint('🔄 [NOTIFICATION] App resumed. Re-registering FCM token for $_currentUserId');
      registerToken(_currentUserId!);
    }
  }
}

/// ✅ REQUIRED BACKGROUND HANDLER
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint("Background message: ${message.messageId}");
}

/// helper
String jsonEncode(dynamic data) => json.encode(data);