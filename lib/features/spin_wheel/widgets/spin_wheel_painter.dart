import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/wheel_option.dart';

class SpinWheelPainter extends CustomPainter {
  final List<WheelOption> options;
  final double rotation;
  final double pointerAngle;

  SpinWheelPainter({
    required this.options,
    required this.rotation,
    this.pointerAngle = -math.pi / 2,
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

    // Draw segments
    for (int i = 0; i < options.length; i++) {
      final startAngle = i * segmentAngle;
      final sweepAngle = segmentAngle;
      final option = options[i];

      final segmentPaint = Paint()
        ..color = option.color
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

      // Draw divider line (skip for single option)
      if (options.length > 1) {
        final dividerPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        final dividerEnd = Offset(
          radius * math.cos(startAngle),
          radius * math.sin(startAngle),
        );
        canvas.drawLine(Offset.zero, dividerEnd, dividerPaint);
      }
    }

    // Draw labels
    if (options.length == 1) {
      final option = options[0];
      final fontSize = 14.0;

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
        canvas.rotate(midAngle + math.pi / 2);

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

    // Draw center hub shadow
    final hubShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, 32, hubShadowPaint);

    // Draw center hub
    final hubPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 28));
    canvas.drawCircle(Offset.zero, 28, hubPaint);

    // Draw hub border
    final hubBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, 28, hubBorderPaint);

    // Draw SPIN text on hub
    final spinTextPainter = TextPainter(
      text: TextSpan(
        text: 'SPIN',
        style: const TextStyle(
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

    // Draw pointer (outside rotation transform)
    _drawPointer(canvas, center, radius);
  }

  void _drawPointer(Canvas canvas, Offset center, double radius) {
    final pointerPaint = Paint()
      ..color = const Color(0xFFFE4EF0)
      ..style = PaintingStyle.fill;

    final pointerPath = Path();
    const pointerSize = 16.0;
    final pointerY = center.dy - radius - 2;

    pointerPath.moveTo(center.dx, pointerY + pointerSize + 4);
    pointerPath.lineTo(center.dx - pointerSize / 2, pointerY);
    pointerPath.lineTo(center.dx + pointerSize / 2, pointerY);
    pointerPath.close();

    // Pointer shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(pointerPath.shift(const Offset(0, 2)), shadowPaint);

    canvas.drawPath(pointerPath, pointerPaint);

    // Pointer border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(pointerPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.options != options;
  }
}
