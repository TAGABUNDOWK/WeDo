import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/splash/splash_page.dart';
import 'screens/auth/welcome/welcome_page.dart';
import 'screens/home/home_page.dart';
import 'screens/chat/group/group_info_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;
  final _isLoggedIn = FirebaseAuth.instance.currentUser != null;

  void _onSplashComplete() {
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeDo',
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
            : _isLoggedIn
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