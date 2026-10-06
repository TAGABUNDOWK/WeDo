import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'models/call.dart';
import 'services/auth/user_service.dart';
import 'services/call/call_manager.dart';
import 'services/call/call_service.dart';
import 'screens/call/incoming_call_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

int _errorCount = 0;

void _reportError(String tag, Object error, StackTrace stack) {
  _errorCount += 1;
  // stdout instead of print/debugPrint so long stacks are not linted or
  // throttled - they have to survive intact, they are the whole point here.
  stdout.writeln('===== [ERR#$_errorCount] $tag =====');
  stdout.writeln(error);
  stdout.writeln(stack);
  stdout.writeln('===== [/ERR#$_errorCount] =====');
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

bool incomingCallFlowActive = false;

void _handleIncomingCall(Map<String, dynamic> data) {
  final callId = data['callId'] as String?;
  if (callId == null) return;
  // Already talking (or already showing a ring screen) - don't stack another
  // listener route on top of the app.
  if (incomingCallFlowActive || CallManager().hasAnyCall) return;

  final context = navigatorKey.currentContext;
  if (context == null) return;

  incomingCallFlowActive = true;
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _IncomingCallListener(callId: callId),
    ),
  );
}

void main() {
  // Everything - binding init, error hooks and runApp - must happen in the
  // same zone, otherwise Flutter logs a "Zone mismatch" warning and
  // zone-sensitive callbacks (e.g. pointer events) get confused.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      _reportError(
        'FRAMEWORK',
        details.exception,
        details.stack ?? StackTrace.current,
      );
      FlutterError.presentError(details);
    };

    WidgetsBinding.instance.platformDispatcher.onError = (
      Object error,
      StackTrace stack,
    ) {
      _reportError('UNCAUGHT', error, stack);
      return true;
    };

    _appMain();
  }, (Object error, StackTrace stack) {
    _reportError('ZONE', error, stack);
  });
}

Future<void> _appMain() async {
  await dotenv.load();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp(navigatorKey: navigatorKey));

  try {
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
  } catch (e) {
    debugPrint('FCM initialization failed: $e');
  }
}

class _IncomingCallListener extends StatefulWidget {
  final String callId;
  const _IncomingCallListener({required this.callId});

  @override
  State<_IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<_IncomingCallListener> {
  final _callService = CallService();
  final _userService = UserService();
  StreamSubscription<Call?>? _callSub;
  bool _navigated = false;
  bool _handedOff = false;
  bool _replaced = false;
  bool _closed = false;
  bool _handling = false;
  bool _pendingClose = false;

  @override
  void initState() {
    super.initState();
    _listenForCall();
  }

  static bool _isTerminal(CallStatus status) {
    return status == CallStatus.ended ||
        status == CallStatus.declined ||
        status == CallStatus.missed ||
        status == CallStatus.cancelled;
  }

  /// Pops this loading route, but never once another route has replaced it -
  /// a late Firestore snapshot must not pop the screen underneath. Close
  /// requests arriving while a previous snapshot is still being handled are
  /// deferred until that handler is done.
  void _close() {
    if (_closed || _replaced || !mounted) return;
    if (_handling) {
      _pendingClose = true;
      return;
    }
    _closed = true;
    Navigator.of(context).pop();
  }

  void _listenForCall() {
    _callSub = _callService.getCallStream(widget.callId).listen((call) async {
      if (call == null || _isTerminal(call.status)) {
        _navigated = true;
        _close();
        return;
      }
      if (_navigated || !mounted) return;
      _navigated = true;
      _handling = true;
      try {
        if (CallManager().hasAnyCall) {
          // Already in a call - nothing to show for this push.
          _close();
          return;
        }

        var callerDisplayName = call.createdBy;
        try {
          final userDoc = await _userService.getUserDocument(call.createdBy);
          if (userDoc != null && userDoc.displayName.isNotEmpty) {
            callerDisplayName = userDoc.displayName;
          }
        } catch (_) {}

        if (!mounted) return;

        if (call.status == CallStatus.active) {
          // The call got going while the push was in flight (we were late).
          // Join it rather than leaving the user on a loading screen forever.
          // _handedOff stays false so dispose() clears the flow flag: from
          // here on the call itself (hasAnyCall) guards against duplicates.
          final joined = await CallManager()
              .joinExistingCall(call, callerDisplayName, replaceTop: true);
          if (!mounted) return;
          if (joined) {
            _replaced = true;
            return;
          }
          _close();
          return;
        }

        if (call.status == CallStatus.ringing) {
          _handedOff = true;
          _replaced = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                call: call,
                callerName: callerDisplayName,
              ),
            ),
          );
        } else {
          _close();
        }
      } finally {
        _handling = false;
        if (_pendingClose) {
          _pendingClose = false;
          _close();
        }
      }
    });
  }

  @override
  void dispose() {
    // When we handed over to a screen that owns the flow, that screen clears
    // the flag - only clear it here if this route is the end of the line.
    if (!_handedOff) incomingCallFlowActive = false;
    _callSub?.cancel();
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
