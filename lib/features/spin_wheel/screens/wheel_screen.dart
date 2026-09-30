import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/wheel_option.dart';
import '../data/wheel_options_store.dart';
import '../data/wheel_palette.dart';
import '../widgets/spin_wheel_painter.dart';
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
  final TextEditingController _addController = TextEditingController();
  bool _isSpinning = false;
  double _currentRotation = 0;
  int? _pendingWinningIndex;

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
    _addController.dispose();
    _spinController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_isSpinning || _options.length <= 1) return;

    // Unfocus any active text field
    FocusScope.of(context).unfocus();

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
    final desired = -math.pi / 2 - targetSegmentCenter;
    final minTotalRotation = _currentRotation + fullRotations * 2 * math.pi;
    final targetRotation =
        minTotalRotation + (desired - minTotalRotation) % (2 * math.pi);

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

    _pendingWinningIndex = winningIndex;
  }

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

    final winnerIdx = _pendingWinningIndex!;
    _pendingWinningIndex = null;

    if (mounted) {
      SpinResultSheet.show(
        context,
        winningOption: winningOption,
        onSpinAgain: _spin,
        onDone: () {},
        onDelete: () {
          setState(() {
            _options.removeAt(winnerIdx);
            if (_options.length < 2) {
              _options.add(WheelOption(
                label: 'Option 2',
                color: _getColorForIndex(1),
              ));
            }
          });
          _persistOptions();
        },
      );
    }
  }

  /// Adds every non-empty line of the input as its own option, in order.
  /// Empty input falls back to a single "Option N+1" label.
  void _addOptionFromText() {
    if (_isSpinning) return;
    final lines = _addController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      lines.add('Option ${_options.length + 1}');
    }
    setState(() {
      for (final label in lines) {
        _options.add(WheelOption(
          label: label,
          color: _getColorForIndex(_options.length),
        ));
      }
    });
    _addController.clear();
    _persistOptions();
  }

  void _removeOption(int index) {
    if (_isSpinning || _options.length <= 2) return;
    setState(() {
      _options.removeAt(index);
    });
    _persistOptions();
  }

  void _reorderOption(int oldIndex, int newIndex) {
    if (_isSpinning) return;
    setState(() {
      final item = _options.removeAt(oldIndex);
      _options.insert(newIndex, item);
    });
    _persistOptions();
  }

  void _updateOptionLabel(int index, String newLabel) {
    _options[index] = WheelOption(
      label: newLabel,
      color: _options[index].color,
    );
    _persistOptions();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final wheelSize = (screenWidth * 0.72).clamp(250.0, 290.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Sparkles & Subtitle
            _buildAppBar(),

            // Scrollable Content utilizing all vertical space
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 6),

                    // Glowing Wheel
                    _buildWheel(wheelSize),

                    const SizedBox(height: 18),

                    // Integrated Edit Options Panel
                    _buildOptionsCard(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top App Bar ─────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
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
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Spin the Wheel',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.9),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Pick a random option',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balances the back icon on left
        ],
      ),
    );
  }

  // ── Neon Glowing Wheel ───────────────────────────────────────────────────

  Widget _buildWheel(double size) {
    return Center(
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
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                    blurRadius: 45,
                    spreadRadius: 6,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.30),
                    blurRadius: 65,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: const Color(0xFFC026D3).withValues(alpha: 0.18),
                    blurRadius: 85,
                    spreadRadius: 1,
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
    );
  }

  // ── Integrated Options Editor Card ──────────────────────────────────────

  Widget _buildOptionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Edit Options + Options Count Badge
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Edit Options',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_options.length} options',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFE4EF0),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Reorderable Option Rows
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _options.length,
            onReorderItem: _reorderOption,
            itemBuilder: (context, index) {
              final option = _options[index];
              return _OptionItemRow(
                key: ValueKey('option_${option.color.toARGB32()}_$index'),
                option: option,
                onChanged: (newLabel) => _updateOptionLabel(index, newLabel),
                onDelete: _options.length > 2 && !_isSpinning
                    ? () => _removeOption(index)
                    : null,
              );
            },
          ),

          const SizedBox(height: 10),

          // Add options as text — each line becomes its own option on "+".
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFE4EF0).withValues(alpha: 0.50),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'One option per line, tap + to add',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSpinning ? null : _addOptionFromText,
                  icon: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 18,
                      color: Color(0xFFFE4EF0),
                    ),
                  ),
                  tooltip: 'Add option',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reorderable Option Item Row ───────────────────────────────────────────

class _OptionItemRow extends StatefulWidget {
  final WheelOption option;
  final ValueChanged<String> onChanged;
  final VoidCallback? onDelete;

  const _OptionItemRow({
    super.key,
    required this.option,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_OptionItemRow> createState() => _OptionItemRowState();
}

class _OptionItemRowState extends State<_OptionItemRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.option.label);
  }

  @override
  void didUpdateWidget(covariant _OptionItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.option.label != _controller.text &&
        !FocusScope.of(context).hasFocus) {
      _controller.text = widget.option.label;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle icon
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Icon(
              Icons.drag_handle,
              color: Colors.white38,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),

          // Colored circle dot matching wheel segment
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: widget.option.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Editable Label Text Field (multi-line)
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Option name',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white38,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: widget.onChanged,
            ),
          ),

          // Delete button
          if (widget.onDelete != null)
            IconButton(
              padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              onPressed: widget.onDelete,
            ),
        ],
      ),
    );
  }
}
