import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/splash/splash_page.dart';
import 'screens/auth/welcome/welcome_page.dart';
import 'screens/home/home_page.dart';
import 'screens/chat/group/group_info_screen.dart';
import 'screens/session/waiting_lobby_screen.dart';
import 'services/auth/user_service.dart';
import 'services/session/lobby_return_store.dart';

class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  const MyApp({super.key, this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;
  User? _user;
  late final StreamSubscription<User?> _authSub;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _validateAuth();
  }

  Future<void> _validateAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        final doc = await _userService.getUserDocument(user.uid);
        if (doc == null || !doc.isEmailVerified) {
          await FirebaseAuth.instance.signOut();
          if (mounted) setState(() => _user = null);
        } else {
          if (mounted) setState(() => _user = FirebaseAuth.instance.currentUser);
        }
      } catch (e) {
        await FirebaseAuth.instance.signOut();
        if (mounted) setState(() => _user = null);
      }
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        try {
          final doc = await _userService.getUserDocument(user.uid);
          if (doc == null) {
            await FirebaseAuth.instance.signOut();
            if (mounted) setState(() => _user = null);
          } else {
            if (mounted) setState(() => _user = user);
          }
        } catch (e) {
          await FirebaseAuth.instance.signOut();
          if (mounted) setState(() => _user = null);
        }
      } else {
        if (mounted) setState(() => _user = null);
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  void _onSplashComplete() {
    setState(() => _showSplash = false);
  }

  void _returnToLobby(String sessionId) {
    final navigator = widget.navigatorKey?.currentState;
    if (navigator == null) return;
    LobbyReturnStore.instance.clear();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => WaitingLobbyScreen(sessionId: sessionId, isHost: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeDo',
      navigatorKey: widget.navigatorKey,
      builder: (context, child) {
        return ValueListenableBuilder<String?>(
          valueListenable: LobbyReturnStore.instance.parked,
          builder: (context, parkedSessionId, _) {
            return Stack(
              children: [
                if (child != null) child,
                if (parkedSessionId != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    right: 12,
                    child: _ReturnToLobbyButton(
                      onPressed: () => _returnToLobby(parkedSessionId),
                    ),
                  ),
              ],
            );
          },
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF190831),
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _showSplash
            ? SplashPage(
                key: const ValueKey('splash'),
                onSplashComplete: _onSplashComplete,
              )
            : _user != null
                ? const HomePage(key: ValueKey('home'))
                : const WelcomePage(key: ValueKey('welcome')),
      ),
      routes: {
        '/group-info': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return GroupInfoScreen(groupId: args as String? ?? '');
        },
      },
    );
  }
}

class _ReturnToLobbyButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ReturnToLobbyButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF66BB6A),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF66BB6A).withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Back to Lobby',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}