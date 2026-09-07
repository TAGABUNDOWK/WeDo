import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/wheel_option.dart';

class SpinWheelPainter extends CustomPainter {
  final List<WheelOption> options;
  final double rotation;
  final double pointerAngle;
  final double pointerScale;
  final double hubScale;

  SpinWheelPainter({
    required this.options,
    required this.rotation,
    this.pointerAngle = -math.pi / 2,
    this.pointerScale = 1.0,
    this.hubScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (options.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final segmentAngle = 2 * math.pi / options.length;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Ambient glow behind the wheel - layer 1 (purple)
    final glowPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(Offset.zero, radius + 14, glowPaint);

    // Second glow layer tinted pink
    final glowPaint2 = Paint()
      ..color = const Color(0xFFFE4EF0).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset.zero, radius + 22, glowPaint2);

    // Third glow layer - vibrant outer ring
    final glowPaint3 = Paint()
      ..color = const Color(0xFFC026D3).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(Offset.zero, radius + 30, glowPaint3);

    // Draw segments
    for (int i = 0; i < options.length; i++) {
      final startAngle = i * segmentAngle;
      final sweepAngle = segmentAngle;
      final option = options[i];

      final segmentPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            option.color.withValues(alpha: 0.65),
            option.color,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: radius),
        )
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(0, 0);
      path.arcTo(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        sweepAngle,
        false,
      );
      path.close();

      canvas.drawPath(path, segmentPaint);

      // Draw divider line glow (skip for single option)
      if (options.length > 1) {
        final dividerGlowPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

        final dividerEnd = Offset(
          radius * math.cos(startAngle),
          radius * math.sin(startAngle),
        );
        canvas.drawLine(Offset.zero, dividerEnd, dividerGlowPaint);

        // Draw divider line
        final dividerPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        canvas.drawLine(Offset.zero, dividerEnd, dividerPaint);
      }
    }

    // Draw labels
    if (options.length == 1) {
      final option = options[0];
      const fontSize = 14.0;

      final textPainter = TextPainter(
        text: TextSpan(
          text: option.label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 3,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
    } else {
      final labelRadius = radius * 0.62;
      final arcWidth = segmentAngle * labelRadius;

      final maxLabelLen =
          options.map((o) => o.label.length).fold(0, math.max);

      double fontSize = maxLabelLen > 0
          ? (arcWidth / (maxLabelLen * 0.6)).clamp(7.0, 14.0)
          : 14.0;

      final maxChars = (arcWidth / (fontSize * 0.6)).floor().clamp(3, 30);

      for (int i = 0; i < options.length; i++) {
        final startAngle = i * segmentAngle;
        final midAngle = startAngle + segmentAngle / 2;
        final option = options[i];

        final labelX = labelRadius * math.cos(midAngle);
        final labelY = labelRadius * math.sin(midAngle);

        final displayLabel = option.label.length > maxChars
            ? '${option.label.substring(0, maxChars)}...'
            : option.label;

        canvas.save();
        canvas.translate(labelX, labelY);

        // Flip text in bottom half so labels stay upright
        final normalizedMid = midAngle % (2 * math.pi);
        final inBottomHalf = normalizedMid > math.pi / 2 &&
            normalizedMid < 3 * math.pi / 2;

        if (inBottomHalf) {
          canvas.rotate(midAngle - math.pi / 2);
        } else {
          canvas.rotate(midAngle + math.pi / 2);
        }

        final textPainter = TextPainter(
          text: TextSpan(
            text: displayLabel,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );

        canvas.restore();
      }
    }

    // Draw outer rim
    final rimPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF6D28D9),
          Color(0xFF8B5CF6),
          Color(0xFFC026D3),
          Color(0xFFD946EF),
          Color(0xFF6D28D9),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(Offset.zero, radius, rimPaint);

    // Draw center hub (with pulse scale)
    canvas.save();
    canvas.scale(hubScale);

    // Hub shadow - outer glow
    final hubShadowPaint = Paint()
      ..color = const Color(0xFFFE4EF0).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset.zero, 40, hubShadowPaint);

    // Hub outer glow ring
    final hubOuterGlow = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, 34, hubOuterGlow);

    // Hub body
    final hubPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF55F0), Color(0xFF9333EA)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 30));
    canvas.drawCircle(Offset.zero, 30, hubPaint);

    // Hub border - stronger
    final hubBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset.zero, 30, hubBorderPaint);

    // Inner hub highlight
    final hubHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(-8, -10), 10, hubHighlightPaint);

    // SPIN text on hub
    final spinTextPainter = TextPainter(
      text: const TextSpan(
        text: 'SPIN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    spinTextPainter.layout();
    spinTextPainter.paint(
      canvas,
      Offset(-spinTextPainter.width / 2, -spinTextPainter.height / 2),
    );

    canvas.restore();

    canvas.restore();

    // Draw pointer (outside rotation transform)
    _drawPointer(canvas, center, radius, pointerScale);
  }

  void _drawPointer(Canvas canvas, Offset center, double radius, double scale) {
    final pointerPaint = Paint()
      ..color = const Color(0xFFFE4EF0)
      ..style = PaintingStyle.fill;

    final pointerPath = Path();
    const pointerSize = 22.0;
    final pointerY = center.dy - radius - 4;

    pointerPath.moveTo(center.dx, pointerY + pointerSize + 6);
    pointerPath.lineTo(center.dx - pointerSize / 2, pointerY);
    pointerPath.lineTo(center.dx + pointerSize / 2, pointerY);
    pointerPath.close();

    // Pointer glow halo
    final glowPaint = Paint()
      ..color = const Color(0xFFFE4EF0).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(pointerPath, glowPaint);

    // Pointer shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(pointerPath.shift(const Offset(0, 3)), shadowPaint);

    // Apply bounce scale from the pointer tip
    canvas.save();
    canvas.translate(center.dx, pointerY + pointerSize + 6);
    canvas.scale(scale);
    canvas.translate(-center.dx, -(pointerY + pointerSize + 6));

    canvas.drawPath(pointerPath, pointerPaint);

    // Pointer border - stronger
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(pointerPath, borderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.options != options ||
        oldDelegate.pointerScale != pointerScale ||
        oldDelegate.hubScale != hubScale;
  }
}
