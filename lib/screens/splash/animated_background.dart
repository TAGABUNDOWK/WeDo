import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget? child;

  const AnimatedBackground({super.key, this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late final List<_CircleAnimation> _circles;
  late final List<_StarAnimation> _stars;

  @override
  void initState() {
    super.initState();
    _circles = List.generate(3, (i) => _CircleAnimation(i, this));
    _stars = List.generate(8, (i) => _StarAnimation(i, this));
  }

  @override
  void dispose() {
    for (final c in _circles) {
      c.dispose();
    }
    for (final s in _stars) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Base gradient background
        const _BaseGradient(),

        // Layer 2: Floating blurred circles
        ..._circles.map((c) => c.build(context)),

        // Layer 3: Dotted grid overlay
        const _DottedGrid(),

        // Layer 4: Twinkling stars
        ..._stars.map((s) => s.build(context)),

        // Child content (login form, etc.)
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

// Layer 1: Base gradient with nebula glow
class _BaseGradient extends StatelessWidget {
  const _BaseGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF190831),
        gradient: RadialGradient(
          center: Alignment(0.3, -0.1),
          radius: 1.2,
          colors: [
            Color(0xFF3D1566),
            Color(0xFF190831),
          ],
          stops: [0.0, 1.0],
        ),
      ),
    );
  }
}

// Layer 2: Floating blurred circles
class _CircleAnimation {
  final int index;
  final TickerProvider vsync;
  late final AnimationController _controllerX;
  late final AnimationController _controllerY;
  late final Animation<double> _animX;
  late final Animation<double> _animY;

  static const _colors = [
    Color(0xFFFE4EF0),
    Color(0xFF800DD8),
    Color(0xFFFE4EF0),
  ];

  static const _sizes = [280.0, 320.0, 240.0];

  // Base positions: upper-left, middle-right, bottom-left
  static const _basePositions = [
    [0.05, 0.08],   // upper left
    [0.70, 0.45],   // middle right
    [0.05, 0.65],   // bottom lower left
  ];

  _CircleAnimation(this.index, this.vsync) {
    final rng = math.Random(index * 42);

    _controllerX = AnimationController(
      vsync: vsync,
      duration: Duration(seconds: 5 + rng.nextInt(5)),
    );
    _controllerY = AnimationController(
      vsync: vsync,
      duration: Duration(seconds: 6 + rng.nextInt(4)),
    );

    final baseX = _basePositions[index][0];
    final baseY = _basePositions[index][1];
    final driftX = 0.20;
    final driftY = 0.20;

    final startX = baseX - driftX / 2;
    final endX = baseX + driftX / 2;

    double startY;
    double endY;
    if (index == 2) {
      startY = baseY;
      endY = baseY;
    } else {
      startY = baseY - driftY / 2;
      endY = baseY + driftY / 2;
    }

    _animX = Tween<double>(begin: startX, end: endX).animate(
      CurvedAnimation(parent: _controllerX, curve: Curves.easeInOut),
    );
    _animY = Tween<double>(begin: startY, end: endY).animate(
      CurvedAnimation(parent: _controllerY, curve: Curves.easeInOut),
    );

    _controllerX.repeat(reverse: true);
    _controllerY.repeat(reverse: true);
  }

  void dispose() {
    _controllerX.dispose();
    _controllerY.dispose();
  }

  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controllerX, _controllerY]),
      builder: (context, _) {
        final size = _sizes[index];
        return Positioned(
          left: MediaQuery.of(context).size.width * _animX.value,
          top: MediaQuery.of(context).size.height * _animY.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: _colors[index].withOpacity(0.3),
                  blurRadius: 120,
                  spreadRadius: 60,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Layer 3: Dotted grid overlay
class _DottedGrid extends StatelessWidget {
  const _DottedGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    const spacingX = 28.0;
    const spacingY = 28.0;
    const dotRadius = 1.5;

    for (double x = spacingX / 2; x < size.width; x += spacingX) {
      for (double y = spacingY / 2; y < size.height; y += spacingY) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Layer 4: Twinkling stars
class _StarAnimation {
  final int index;
  final TickerProvider vsync;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  late final double _x;
  late final double _y;
  late final double _size;
  late final double _rotation;

  static const _totalStars = 8;
  static const _sizeRanges = [
    [22.0, 32.0],  // small
    [36.0, 50.0],  // medium
    [54.0, 72.0],  // large
  ];

  // Fixed positions: 5 from top to bottom, 2 in center, 1 bottom right
  static const _fixedPositions = [
    [0.20, 0.08],  // top
    [0.75, 0.22],  // upper middle
    [0.15, 0.40],  // middle
    [0.80, 0.65],  // lower middle
    [0.25, 0.85],  // bottom
    [0.42, 0.45],  // center left
    [0.58, 0.50],  // center right
    [0.82, 0.92],  // bottom right
  ];

  _StarAnimation(this.index, this.vsync) {
    final rng = math.Random(index * 137);

    _x = _fixedPositions[index][0];
    _y = _fixedPositions[index][1];
    _rotation = rng.nextDouble() * math.pi * 2;

    final sizeCategory = rng.nextInt(3);
    final minSize = _sizeRanges[sizeCategory][0];
    final maxSize = _sizeRanges[sizeCategory][1];
    _size = minSize + rng.nextDouble() * (maxSize - minSize);

    _controller = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 2200 + rng.nextInt(1200)),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    final staggerMs = 300 + index * 600;
    _startWithDelay(staggerMs);
  }

  bool _disposed = false;

  void _startWithDelay(int staggerMs) {
    Future.delayed(Duration(milliseconds: staggerMs), () {
      if (!_disposed) {
        _controller.repeat();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _controller.dispose();
  }

  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Positioned(
          left: MediaQuery.of(context).size.width * _x - _size / 2,
          top: MediaQuery.of(context).size.height * _y - _size / 2,
          child: Transform.rotate(
            angle: _rotation,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Opacity(
                opacity: _opacityAnim.value,
                child: Image.asset(
                  'assets/icons/gemini.png',
                  width: _size,
                  height: _size,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.auto_awesome,
                      size: _size,
                      color: Colors.white,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
