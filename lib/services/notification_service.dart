import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  // Initialize notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _requestPermissions();
      await _initializeLocalNotifications();
      await _getToken();
      await _setupMessageHandlers();

      _isInitialized = true;
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Notification service error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else {
        print('User declined permission');
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      // Android settings
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS settings - FIXED: Removed the old onDidReceiveLocalNotification
      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // FIXED: Correct method name for notification tap
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap, // Correct for v16+
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }
    } catch (e) {
      print('Error initializing local notifications: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      print('Error creating notification channel: $e');
    }
  }

  Future<void> _getToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $_fcmToken');
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  Future<void> _setupMessageHandlers() async {
    try {
      // Foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background messages (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    } catch (e) {
      print('Error setting up message handlers: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      print('Foreground message: ${message.messageId}');

      RemoteNotification? notification = message.notification;

      if (notification != null) {
        _showLocalNotification(
          id: message.hashCode,
          title: notification.title ?? 'New Message',
          body: notification.body ?? 'You have a new message',
        );
      }
    } catch (e) {
      print('Error handling foreground message: $e');
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    try {
      print('Background message opened: ${message.messageId}');
      // Navigate to specific chat based on data
    } catch (e) {
      print('Error handling background message: $e');
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Background message: ${message.messageId}");
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(id: id);
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  // FIXED: Correct parameter type for v16+
  void _onNotificationTap(NotificationResponse response) {
    try {
      print('Notification tapped: ${response.payload}');

      if (response.payload != null) {
        // Handle navigation based on payload
        // You can use a navigator key here
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  // Subscribe to user's topic
  Future<void> subscribeToUser(String userId) async {
    try {
      if (userId.isNotEmpty) {
        await _firebaseMessaging.subscribeToTopic('user_$userId');
      }
    } catch (e) {
      print('Error subscribing: $e');
    }
  }

  // Unsubscribe from user's topic
  Future<void> unsubscribeFromUser(String userId) async {
    try {
      if (userId.isNotEmpty) {
        await _firebaseMessaging.unsubscribeFromTopic('user_$userId');
      }
    } catch (e) {
      print('Error unsubscribing: $e');
    }
  }
}