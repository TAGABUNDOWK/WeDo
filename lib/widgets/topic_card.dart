import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class TopicCard extends StatelessWidget {
  final String label;
  final String? description;
  final Widget icon;
  final VoidCallback? onTap;
  final String? buttonText;
  final double? width;
  final double? height;

  const TopicCard({
    super.key,
    required this.label,
    this.description,
    required this.icon,
    this.onTap,
    this.buttonText,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final w = width ?? Responsive.cardWidth(context);
    final h = height ?? Responsive.cardHeight(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF220C3E),
              Color(0xFF130623),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFE4EF0).withValues(alpha: 0.50),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.20),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF800DD8).withValues(alpha: 0.15),
              blurRadius: 32,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Subtle corner accents matching cyberpunk reference aesthetic
              const CustomPaint(
                painter: _CornerPatternPainter(),
              ),

              // Card contents
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top glowing icon container
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFE4EF0).withValues(alpha: 0.35),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: icon,
                        ),
                      ),
                    ),

                    // Title & Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStyledTitle(label),
                          if (description != null && description!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              description!,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Action button inside card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE4EF0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFE4EF0).withValues(alpha: 0.65),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            buttonText ?? 'START CHALLENGE',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTitle(String text) {
    final words = text.trim().toUpperCase().split(RegExp(r'\s+'));
    if (words.length <= 1) {
      return Text(
        text.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      );
    }

    final firstPart = words.sublist(0, words.length - 1).join(' ');
    final lastWord = words.last;

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
        children: [
          TextSpan(
            text: '$firstPart ',
            style: const TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: lastWord,
            style: const TextStyle(color: Color(0xFFFE4EF0)),
          ),
        ],
      ),
    );
  }
}

/// Draws subtle cyberpunk dotted matrix and speed accents in the card corners
class _CornerPatternPainter extends CustomPainter {
  const _CornerPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFFFE4EF0)
      ..style = PaintingStyle.fill;

    // Top-left dot matrix
    const spacing = 8.0;
    const maxCols = 8;
    const maxRows = 8;
    for (int r = 0; r < maxRows; r++) {
      for (int c = 0; c < maxCols; c++) {
        final dist = (r * r + c * c) / (maxRows * maxRows + maxCols * maxCols);
        if (dist > 1.0) continue;
        final alpha = ((1.0 - dist) * 0.35).clamp(0.0, 0.35);
        dotPaint.color = const Color(0xFFFE4EF0).withValues(alpha: alpha);
        canvas.drawCircle(
          Offset(12.0 + c * spacing, 12.0 + r * spacing),
          1.2,
          dotPaint,
        );
      }
    }

    // Bottom-right dot matrix
    for (int r = 0; r < maxRows; r++) {
      for (int c = 0; c < maxCols; c++) {
        final dist = (r * r + c * c) / (maxRows * maxRows + maxCols * maxCols);
        if (dist > 1.0) continue;
        final alpha = ((1.0 - dist) * 0.30).clamp(0.0, 0.30);
        dotPaint.color = const Color(0xFF800DD8).withValues(alpha: alpha);
        canvas.drawCircle(
          Offset(size.width - 12.0 - c * spacing, size.height - 12.0 - r * spacing),
          1.2,
          dotPaint,
        );
      }
    }

    // Bottom-left diagonal speed accents
    final linePaint = Paint()
      ..color = const Color(0xFFFE4EF0).withValues(alpha: 0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final offset = i * 7.0;
      canvas.drawLine(
        Offset(8 + offset, size.height - 8),
        Offset(8, size.height - 8 - offset),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
