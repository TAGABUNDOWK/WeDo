import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/splash/splash_page.dart';
import 'screens/auth/welcome/welcome_page.dart';
import 'screens/home/home_page.dart';
import 'screens/chat/group/group_info_screen.dart';
import 'services/auth/user_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeDo',
      navigatorKey: widget.navigatorKey,
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