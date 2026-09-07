import 'dart:math';
import 'package:flutter/material.dart';
import '../models/chat_theme.dart';

class ChatBackground extends StatelessWidget {
  final ChatBackgroundStyle? style;
  final Color color;
  final double opacity;

  const ChatBackground({
    super.key,
    this.style,
    required this.color,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    final s = style;
    if (s == null || s == ChatBackgroundStyle.none) return const SizedBox.shrink();

    return Positioned.fill(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _ChatBackgroundPainter(style: s, color: color),
        ),
      ),
    );
  }
}

class _ChatBackgroundPainter extends CustomPainter {
  final ChatBackgroundStyle style;
  final Color color;

  _ChatBackgroundPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case ChatBackgroundStyle.none:
        break;
      case ChatBackgroundStyle.dotGrid:
        _paintDotGrid(canvas, size);
        break;
      case ChatBackgroundStyle.waves:
        _paintWaves(canvas, size);
        break;
      case ChatBackgroundStyle.clouds:
        _paintClouds(canvas, size);
        break;
      case ChatBackgroundStyle.leaves:
        _paintLeaves(canvas, size);
        break;
      case ChatBackgroundStyle.bokeh:
        _paintBokeh(canvas, size);
        break;
      case ChatBackgroundStyle.starfield:
        _paintStarfield(canvas, size);
        break;
      case ChatBackgroundStyle.geometric:
        _paintGeometric(canvas, size);
        break;
      case ChatBackgroundStyle.petals:
        _paintPetals(canvas, size);
        break;
    }
  }

  void _paintDotGrid(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const spacing = 24.0;
    const dotRadius = 2.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint..color = color);
      }
    }
  }

  void _paintWaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const waveHeight = 12.0;
    const waveLength = 120.0;
    const spacing = 40.0;

    for (double y = -waveHeight; y < size.height + waveHeight; y += spacing) {
      final path = Path();
      path.moveTo(0, y);

      for (double x = 0; x <= size.width; x += 1) {
        final dy = y + waveHeight * sin((x / waveLength) * 2 * pi);
        path.lineTo(x, dy);
      }

      canvas.drawPath(
        path,
        paint..color = color.withValues(alpha: 0.6 + (y % spacing) / spacing * 0.4),
      );
    }
  }

  void _paintClouds(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final random = Random(42);
    final cloudCenters = [
      Offset(size.width * 0.2, size.height * 0.15),
      Offset(size.width * 0.7, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.4),
      Offset(size.width * 0.15, size.height * 0.6),
      Offset(size.width * 0.8, size.height * 0.55),
      Offset(size.width * 0.4, size.height * 0.8),
      Offset(size.width * 0.9, size.height * 0.85),
      Offset(size.width * 0.1, size.height * 0.9),
    ];

    for (final center in cloudCenters) {
      final radius = 30.0 + random.nextDouble() * 40;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: radius * 2.5, height: radius * 1.5),
        paint..color = color.withValues(alpha: 0.3 + random.nextDouble() * 0.3),
      );
    }
  }

  void _paintLeaves(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(7);

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final leafSize = 6.0 + random.nextDouble() * 10;
      final angle = random.nextDouble() * 2 * pi;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final path = Path();
      path.moveTo(0, -leafSize);
      path.quadraticBezierTo(leafSize * 0.6, -leafSize * 0.3, leafSize * 0.3, 0);
      path.quadraticBezierTo(leafSize * 0.6, leafSize * 0.3, 0, leafSize);
      path.quadraticBezierTo(-leafSize * 0.6, leafSize * 0.3, -leafSize * 0.3, 0);
      path.quadraticBezierTo(-leafSize * 0.6, -leafSize * 0.3, 0, -leafSize);

      canvas.drawPath(path, paint..color = color.withValues(alpha: 0.4 + random.nextDouble() * 0.3));
      canvas.restore();
    }
  }

  void _paintBokeh(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(99);

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 15.0 + random.nextDouble() * 45;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = color.withValues(alpha: 0.15 + random.nextDouble() * 0.2),
      );
    }
  }

  void _paintStarfield(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(13);

    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 0.5 + random.nextDouble() * 2.0;
      final alpha = 0.3 + random.nextDouble() * 0.7;

      canvas.drawCircle(
        Offset(x, y),
        starSize,
        paint..color = color.withValues(alpha: alpha),
      );
    }

    // A few larger "bright" stars with a glow
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;

      canvas.drawCircle(
        Offset(x, y),
        3,
        paint..color = color.withValues(alpha: 0.8),
      );
      canvas.drawCircle(
        Offset(x, y),
        6,
        paint..color = color.withValues(alpha: 0.2),
      );
    }
  }

  void _paintGeometric(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const hexRadius = 30.0;
    final hexHeight = hexRadius * sqrt(3);
    const hexWidth = hexRadius * 2;

    for (double row = -1; row < size.height / hexHeight + 1; row++) {
      for (double col = -1; col < size.width / (hexWidth * 0.75) + 1; col++) {
        final offsetX = col * hexWidth * 0.75;
        final offsetY = row * hexHeight + (col % 2 != 0 ? hexHeight / 2 : 0);

        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = pi / 3 * i - pi / 6;
          final px = offsetX + hexRadius * cos(angle);
          final py = offsetY + hexRadius * sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();

        canvas.drawPath(
          path,
          paint..color = color.withValues(alpha: 0.4),
        );
      }
    }
  }

  void _paintPetals(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(21);

    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final petalSize = 5.0 + random.nextDouble() * 12;
      final angle = random.nextDouble() * 2 * pi;
      final alpha = 0.3 + random.nextDouble() * 0.4;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      // Draw a 5-petal flower
      for (int p = 0; p < 5; p++) {
        canvas.rotate(pi * 2 / 5);
        final path = Path();
        path.moveTo(0, 0);
        path.quadraticBezierTo(petalSize * 0.5, -petalSize, 0, -petalSize * 1.5);
        path.quadraticBezierTo(-petalSize * 0.5, -petalSize, 0, 0);
        canvas.drawPath(path, paint..color = color.withValues(alpha: alpha));
      }

      // Center dot
      canvas.drawCircle(Offset.zero, petalSize * 0.25, paint..color = color.withValues(alpha: alpha + 0.1));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackgroundPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.color != color;
}
