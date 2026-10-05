import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/session_entity.dart';
import 'models/tri_race_entity.dart';
import 'screens/auth/splash/splash_page.dart';
import 'screens/auth/welcome/welcome_page.dart';
import 'screens/home/home_page.dart';
import 'screens/chat/group/group_info_screen.dart';
import 'screens/session/waiting_lobby_screen.dart';
import 'screens/tri_race/waiting_lobby_screen.dart' as tri_race;
import 'utils/constants.dart';
import 'services/auth/user_service.dart';
import 'services/session/lobby_return_store.dart';
import 'services/session/session_service.dart';
import 'services/tri_race/tri_race_service.dart';

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
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) setState(() => _user = user);
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

  Future<void> _returnToLobby(String sessionId) async {
    final navigator = widget.navigatorKey?.currentState;
    if (navigator == null) return;

    final isHost = LobbyReturnStore.instance.isHost;
    final lobbyType = LobbyReturnStore.instance.lobbyType;

    if (lobbyType == LobbyType.triRace) {
      final race = await TriRaceService().getTriRaceStream(sessionId).first;
      if (race == null || race.status != TriRaceStatus.lobby) {
        LobbyReturnStore.instance.clear();
        return;
      }
      LobbyReturnStore.instance.clear();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => tri_race.WaitingLobbyScreen(raceId: sessionId, isHost: isHost),
        ),
      );
    } else {
      final session = await SessionService().getSessionStream(sessionId).first;
      if (session == null || session.status != SessionStatus.lobby) {
        LobbyReturnStore.instance.clear();
        return;
      }
      LobbyReturnStore.instance.clear();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => WaitingLobbyScreen(sessionId: sessionId, isHost: isHost),
        ),
      );
    }
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
                    right: 0,
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

class _ReturnToLobbyButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _ReturnToLobbyButton({required this.onPressed});

  @override
  State<_ReturnToLobbyButton> createState() => _ReturnToLobbyButtonState();
}

class _ReturnToLobbyButtonState extends State<_ReturnToLobbyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const violet = AppColors.electricViolet;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_glow.value);
        return GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1B69),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                bottomLeft: Radius.circular(22),
              ),
              border: Border.all(
                color: violet.withValues(alpha: 0.65 + 0.35 * t),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: violet.withValues(alpha: 0.45 + 0.45 * t),
                  blurRadius: 10 + 16 * t,
                  offset: const Offset(-4, 0),
                ),
                BoxShadow(
                  color: violet.withValues(alpha: 0.16 + 0.26 * t),
                  blurRadius: 26 + 14 * t,
                  offset: const Offset(-8, 2),
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
      },
    );
  }
}