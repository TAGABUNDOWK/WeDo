import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MeshGradientBackground extends StatelessWidget {
  final Widget? child;

  const MeshGradientBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _MeshGradientPainter(),
        if (child != null) child!,
      ],
    );
  }
}

class _MeshGradientPainter extends StatelessWidget {
  const _MeshGradientPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _MeshGradientPaintPainter(),
    );
  }
}

class _MeshGradientPaintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.screen;

    final rect = Offset.zero & size;

    final gradient1 = ui.Gradient.radial(
      Offset(size.width * 0.2, size.height * 0.1),
      size.width * 0.6,
      [
        const Color(0xFF1A3A6B).withValues(alpha: 0.8),
        const Color(0xFF0D1B2A).withValues(alpha: 0.0),
      ],
      [0.0, 1.0],
    );
    paint.shader = gradient1;
    canvas.drawRect(rect, paint);

    final gradient2 = ui.Gradient.radial(
      Offset(size.width * 0.8, size.height * 0.3),
      size.width * 0.5,
      [
        const Color(0xFF2D1B69).withValues(alpha: 0.6),
        const Color(0xFF0D1B2A).withValues(alpha: 0.0),
      ],
      [0.0, 1.0],
    );
    paint.shader = gradient2;
    canvas.drawRect(rect, paint);

    final gradient3 = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.7),
      size.width * 0.7,
      [
        const Color(0xFF0F3460).withValues(alpha: 0.5),
        const Color(0xFF0D1B2A).withValues(alpha: 0.0),
      ],
      [0.0, 1.0],
    );
    paint.shader = gradient3;
    canvas.drawRect(rect, paint);

    final gradient4 = ui.Gradient.radial(
      Offset(size.width * 0.1, size.height * 0.9),
      size.width * 0.4,
      [
        const Color(0xFF3182CE).withValues(alpha: 0.15),
        const Color(0xFF0D1B2A).withValues(alpha: 0.0),
      ],
      [0.0, 1.0],
    );
    paint.shader = gradient4;
    canvas.drawRect(rect, paint);

    final bgPaint = Paint()..color = const Color(0xFF0D1B2A);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      bgPaint,
    );

    paint.blendMode = ui.BlendMode.screen;
    paint.shader = gradient1;
    canvas.drawRect(rect, paint);
    paint.shader = gradient2;
    canvas.drawRect(rect, paint);
    paint.shader = gradient3;
    canvas.drawRect(rect, paint);
    paint.shader = gradient4;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
