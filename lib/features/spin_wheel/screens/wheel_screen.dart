import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../widgets/animated_background.dart';
import '../models/wheel_option.dart';
import '../data/wheel_history_repository.dart';
import '../widgets/spin_wheel_painter.dart';
import '../widgets/wheel_option_chip.dart';
import '../widgets/options_editor_sheet.dart';
import '../widgets/spin_result_sheet.dart';
import 'wheel_history_screen.dart';

class WheelScreen extends StatefulWidget {
  const WheelScreen({super.key});

  @override
  State<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen>
    with SingleTickerProviderStateMixin {
  final _repository = WheelHistoryRepository();
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  List<WheelOption> _options = [];
  bool _isSpinning = false;
  double _currentRotation = 0;

  static const _wheelColors = [
    Color(0xFF6D28D9),
    Color(0xFF7C3AED),
    Color(0xFF8B5CF6),
    Color(0xFFA78BFA),
    Color(0xFF9333EA),
    Color(0xFFC026D3),
    Color(0xFFD946EF),
    Color(0xFF5B21B6),
  ];

  @override
  void initState() {
    super.initState();

    _options = [
      const WheelOption(label: 'Option 1', color: Color(0xFF6D28D9)),
      const WheelOption(label: 'Option 2', color: Color(0xFF7C3AED)),
      const WheelOption(label: 'Option 3', color: Color(0xFF8B5CF6)),
      const WheelOption(label: 'Option 4', color: Color(0xFFA78BFA)),
    ];

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
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Color _getColorForIndex(int index) {
    return _wheelColors[index % _wheelColors.length];
  }

  void _addDefaultOptions() {
    if (_options.length < 4) {
      while (_options.length < 4) {
        _options.add(WheelOption(
          label: 'Option ${_options.length + 1}',
          color: _getColorForIndex(_options.length),
        ));
      }
    }
  }

  Future<void> _spin() async {
    if (_isSpinning || _options.length <= 1) return;

    setState(() => _isSpinning = true);

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

    // Save to Firestore
    _repository.saveSpin(
      options: _options,
      winningOption: winningOption,
      winningIndex: _pendingWinningIndex!,
    );

    setState(() => _isSpinning = false);

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
      },
    );
  }

  void _removeOption(int index) {
    if (_isSpinning || _options.isEmpty) return;
    setState(() {
      _options.removeAt(index);
    });
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
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WheelHistoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.history,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
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
                      animation: _spinAnimation,
                      builder: (context, _) {
                        return SizedBox(
                          width: 320,
                          height: 320,
                          child: CustomPaint(
                            painter: SpinWheelPainter(
                              options: _options,
                              rotation: _isSpinning
                                  ? _spinAnimation.value
                                  : _currentRotation,
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
