import 'package:flutter/material.dart';
import 'screens/splash/splash_page.dart';
import 'screens/welcome/welcome_page.dart';
import 'screens/group/group_info_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

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
            : const WelcomePage(
                key: ValueKey('welcome'),
              ),
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