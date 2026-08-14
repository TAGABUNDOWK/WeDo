import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../widgets/animated_background.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback? onSplashComplete;

  const SplashPage({super.key, this.onSplashComplete});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  late final AnimationController _moveController;
  late final Animation<double> _logoY;
  late final Animation<double> _moveScale;

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoY = Tween<double>(begin: 0, end: -80).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
    );

    _moveScale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.stop();
    _moveController.stop();
    _entranceController.dispose();
    _moveController.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_isExiting || !_entranceController.isCompleted) return;
    _isExiting = true;

    _moveController.forward().then((_) {
      if (mounted) {
        widget.onSplashComplete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            const AnimatedBackground(),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(color: Colors.white.withValues(alpha: 0.03)),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _entranceController,
                  _moveController,
                ]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _logoY.value),
                      child: Transform.scale(
                        scale: _logoScale.value * _moveScale.value,
                        child: Image.asset(
                          'assets/images/WeDo-Logo.png',
                          width: 220,
                          height: 220,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                size: 80,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
