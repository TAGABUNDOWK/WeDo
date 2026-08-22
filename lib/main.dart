import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/auth/user_service.dart';
import 'services/call/call_service.dart';
import 'screens/call/incoming_call_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void _handleIncomingCall(Map<String, dynamic> data) {
  final callId = data['callId'] as String?;
  if (callId == null) return;

  final callerName = data['callerName'] as String? ?? 'Someone';

  final context = navigatorKey.currentContext;
  if (context == null) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _IncomingCallListener(callId: callId, callerName: callerName),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
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
    if (message.data.containsKey('callId')) {
      _handleIncomingCall(message.data);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Notification opened app: ${message.notification?.title}');
    if (message.data.containsKey('callId')) {
      _handleIncomingCall(message.data);
    }
  });

  runApp(MyApp(navigatorKey: navigatorKey));
}

class _IncomingCallListener extends StatefulWidget {
  final String callId;
  final String callerName;
  const _IncomingCallListener({required this.callId, required this.callerName});

  @override
  State<_IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<_IncomingCallListener> {
  final _callService = CallService();

  @override
  void initState() {
    super.initState();
    _listenForCall();
  }

  void _listenForCall() {
    _callService.getCallStream(widget.callId).listen((call) {
      if (call == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (call.status.name == 'ended') {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (call.status.name == 'ringing' && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              call: call,
              callerName: widget.callerName,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
