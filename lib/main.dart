import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/auth/user_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && token != null) {
      await UserService().updateFcmToken(currentUser.uid, token);
    }
  }

  messaging.onTokenRefresh.listen((token) async {
    debugPrint('FCM Token refreshed: $token');
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await UserService().updateFcmToken(currentUser.uid, token);
    }
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Notification opened app: ${message.notification?.title}');
  });

  runApp(const MyApp());
}
