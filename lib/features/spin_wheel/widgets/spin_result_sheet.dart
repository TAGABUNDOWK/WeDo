import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wheel_option.dart';

class SpinResultSheet extends StatefulWidget {
  final WheelOption winningOption;
  final VoidCallback onSpinAgain;
  final VoidCallback onDone;
  final VoidCallback onDelete;

  const SpinResultSheet({
    super.key,
    required this.winningOption,
    required this.onSpinAgain,
    required this.onDone,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required WheelOption winningOption,
    required VoidCallback onSpinAgain,
    required VoidCallback onDone,
    required VoidCallback onDelete,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpinResultSheet(
        winningOption: winningOption,
        onSpinAgain: onSpinAgain,
        onDone: onDone,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<SpinResultSheet> createState() => _SpinResultSheetState();
}

class _SpinResultSheetState extends State<SpinResultSheet>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _scaleController;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _particles = List.generate(24, (i) {
      final rng = math.Random(i);
      return _Particle(
        color: [
          const Color(0xFF6D28D9),
          const Color(0xFF7C3AED),
          const Color(0xFF8B5CF6),
          const Color(0xFFA78BFA),
          const Color(0xFFC026D3),
          const Color(0xFFD946EF),
          const Color(0xFFFE4EF0),
        ][rng.nextInt(7)],
        angle: rng.nextDouble() * 2 * math.pi,
        speed: 80 + rng.nextDouble() * 160,
        size: 4 + rng.nextDouble() * 8,
        rotationSpeed: (rng.nextDouble() - 0.5) * 10,
      );
    });

    _confettiController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: const BoxDecoration(
        color: Color(0xFF2A1450),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Confetti particles
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                size: Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.45,
                ),
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
              );
            },
          ),

          // Content
          Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const Spacer(flex: 2),

              // Winner display
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _scaleController,
                  curve: Curves.elasticOut,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.winningOption.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              widget.winningOption.color.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'WINNER',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: widget.winningOption.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              widget.winningOption.color.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        widget.winningOption.label,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: widget.winningOption.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Buttons
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 0, 24, bottomPadding > 0 ? bottomPadding + 8 : 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDelete();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: widget.winningOption.color.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.winningOption.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDone();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSpinAgain();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFE4EF0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Spin Again',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Particle {
  final Color color;
  final double angle;
  final double speed;
  final double size;
  final double rotationSpeed;

  _Particle({
    required this.color,
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);

    for (final particle in particles) {
      final time = progress;
      final distance = particle.speed * time;
      final gravity = 50 * time * time;

      final x = center.dx + math.cos(particle.angle) * distance;
      final y = center.dy + math.sin(particle.angle) * distance + gravity;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: 1 - progress)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y),
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
