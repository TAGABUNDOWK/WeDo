import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../widgets/animated_background.dart';
import '../models/wheel_option.dart';
import '../data/wheel_options_store.dart';
import '../data/wheel_palette.dart';
import '../widgets/spin_wheel_painter.dart';
import '../widgets/wheel_option_chip.dart';
import '../widgets/options_editor_sheet.dart';
import '../widgets/spin_result_sheet.dart';

class WheelScreen extends StatefulWidget {
  const WheelScreen({super.key});

  @override
  State<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen>
    with TickerProviderStateMixin {
  final _optionsStore = WheelOptionsStore();
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<WheelOption> _options = [];
  bool _isSpinning = false;
  double _currentRotation = 0;

  Color _getColorForIndex(int index) {
    return WheelPalette.colorForIndex(index, total: _options.length);
  }

  @override
  void initState() {
    super.initState();

    _options = _defaultOptions();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _spinAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _spinController,
        curve: Curves.decelerate,
      ),
    );

    _spinController.addListener(() {
      setState(() {});
    });

    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSpinComplete();
      }
    });

    // Pointer bounce animation
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );
    _bounceController.addListener(() {
      setState(() {});
    });

    // Hub idle pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.addListener(() {
      setState(() {});
    });
    _pulseController.repeat(reverse: true);

    _loadSavedOptions();
  }

  List<WheelOption> _defaultOptions() {
    return [
      const WheelOption(label: 'Option 1', color: Color(0xFF6D28D9)),
      const WheelOption(label: 'Option 2', color: Color(0xFF7C3AED)),
      const WheelOption(label: 'Option 3', color: Color(0xFF8B5CF6)),
      const WheelOption(label: 'Option 4', color: Color(0xFFA78BFA)),
    ];
  }

  Future<void> _loadSavedOptions() async {
    final saved = await _optionsStore.loadOptions();
    if (saved == null || saved.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _options = saved;
    });
  }

  Future<void> _persistOptions() async {
    await _optionsStore.saveOptions(_options);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _addDefaultOptions() {
    if (_options.length < 4) {
      while (_options.length < 4) {
        _options.add(WheelOption(
          label: 'Option ${_options.length + 1}',
          color: _getColorForIndex(_options.length),
        ));
      }
      _persistOptions();
    }
  }

  Future<void> _spin() async {
    if (_isSpinning || _options.length <= 1) return;

    setState(() => _isSpinning = true);

    // Pause idle pulse during spin
    _pulseController.stop();

    // Pick winner first
    final winningIndex = math.Random().nextInt(_options.length);

    // Calculate target rotation
    final segmentAngle = 2 * math.pi / _options.length;
    final targetSegmentCenter = winningIndex * segmentAngle + segmentAngle / 2;

    // Random number of full rotations (3-6)
    final fullRotations = 3 + math.Random().nextInt(4);

    // Total rotation: full rotations + offset to land on winning segment
    // Pointer is at top (-pi/2), so we need to account for that
    final desired = -math.pi / 2 - targetSegmentCenter;
    final minTotalRotation = _currentRotation + fullRotations * 2 * math.pi;
    final targetRotation = minTotalRotation + (desired - minTotalRotation) % (2 * math.pi);

    // Random duration (4-5.5 seconds)
    final duration = 4000 + math.Random().nextInt(1500);
    _spinController.duration = Duration(milliseconds: duration);

    final tween = Tween<double>(
      begin: _currentRotation,
      end: targetRotation,
    );

    _spinAnimation = tween.animate(
      CurvedAnimation(
        parent: _spinController,
        curve: Curves.decelerate,
      ),
    );

    _spinController.forward(from: 0);

    // Store winning index for completion
    _pendingWinningIndex = winningIndex;
  }

  int? _pendingWinningIndex;

  void _onSpinComplete() {
    if (_pendingWinningIndex == null) return;

    final winningOption = _options[_pendingWinningIndex!];
    _currentRotation = _spinAnimation.value;

    setState(() => _isSpinning = false);

    // Trigger pointer bounce
    _bounceController.forward(from: 0).then((_) {
      _bounceController.reverse();
    });

    // Resume idle pulse
    _pulseController.repeat(reverse: true);

    // Capture index before clearing
    final winnerIdx = _pendingWinningIndex!;
    _pendingWinningIndex = null;

    // Show result
    if (mounted) {
      SpinResultSheet.show(
        context,
        winningOption: winningOption,
        onSpinAgain: _spin,
        onDone: () {},
        onDelete: () {
          setState(() {
            _options.removeAt(winnerIdx);
          });
          _persistOptions();
        },
      );
    }
  }

  void _openEditor() {
    OptionsEditorSheet.show(
      context,
      initialOptions: _options,
      onOptionsChanged: (newOptions) {
        setState(() {
          _options = newOptions;
          _addDefaultOptions();
        });
        _persistOptions();
      },
    );
  }

  void _removeOption(int index) {
    if (_isSpinning || _options.isEmpty) return;
    setState(() {
      _options.removeAt(index);
    });
    _persistOptions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        showStars: false,
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Spin the Wheel',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Wheel
              Expanded(
                flex: 4,
                child: Center(
                  child: GestureDetector(
                    onTap: (_isSpinning || _options.length <= 1) ? null : _spin,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _spinAnimation,
                        _bounceAnimation,
                        _pulseAnimation,
                      ]),
                      builder: (context, _) {
                        return Container(
                          width: 320,
                          height: 320,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                              BoxShadow(
                                color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                                blurRadius: 60,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: SpinWheelPainter(
                              options: _options,
                              rotation: _isSpinning
                                  ? _spinAnimation.value
                                  : _currentRotation,
                              pointerScale: _bounceAnimation.value,
                              hubScale: _pulseAnimation.value,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Option chips
              SizedBox(
                height: 44,
                child: _options.isEmpty
                    ? const Center(
                        child: Text(
                          'Add at least 2 options to spin',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _options.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return WheelOptionChip(
                            option: _options[index],
                            onRemove: _options.length > 1
                                ? () => _removeOption(index)
                                : null,
                            isSpinning: _isSpinning,
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Edit button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isSpinning ? null : _openEditor,
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: _isSpinning
                          ? Colors.white24
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                    label: Text(
                      'Edit Options',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isSpinning
                            ? Colors.white24
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _isSpinning
                            ? Colors.white12
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
