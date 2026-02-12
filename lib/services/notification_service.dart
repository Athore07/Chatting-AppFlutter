import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static Future init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    String? token = await messaging.getToken();
    developer.log('FCM Token: $token', name: 'NotificationService');
  }
}
