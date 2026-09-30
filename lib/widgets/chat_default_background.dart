import 'package:flutter/material.dart';

class ChatDefaultBackground extends StatelessWidget {
  const ChatDefaultBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF190831)),
        const _DottedGrid(),
        Positioned(
          top: 60,
          left: -300,
          child: Transform.rotate(
            angle: -0.285,
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/images/Ears-overlay1.png',
                width: 800,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          // Offset by the keyboard inset so the overlay stays pinned to
          // the physical screen bottom instead of riding up with it.
          bottom: -10 - MediaQuery.of(context).viewInsets.bottom,
          right: -255,
          child: Transform.rotate(
            angle: -0.3454,
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/images/Eyes-overlay1.png',
                width: 750,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chat background dotted grid (same pattern as Home screen) ────────────────

class _DottedGrid extends StatelessWidget {
  const _DottedGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.infinite, painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
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
