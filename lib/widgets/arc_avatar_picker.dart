import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scrollable curved avatar picker hugging the left edge of the screen.
///
/// Avatars travel along a semicircular arc whose centre sits off-screen to
/// the left. A fixed arrow marks the vertical centre of the arc; whatever
/// avatar aligns with it is the current selection. Drags snap to the nearest
/// avatar via a short tween animation.
///
/// The [reveal] animation drives the staggered top-to-bottom entrance
/// (shared with the WeDo slider toggle) and disables hit-testing while the
/// picker is mostly hidden.
enum ArcSide { left, right }

class ArcAvatarPicker extends StatefulWidget {
  const ArcAvatarPicker({
    super.key,
    required this.avatars,
    required this.reveal,
    required this.onAvatarSelected,
    this.initialIndex = 0,
    this.arrowAsset = 'assets/icons/Arrow-1.png',
    this.onCloseRequested,
    this.side = ArcSide.left,
  });

  final List<String> avatars;
  final Animation<double> reveal;
  final ValueChanged<String> onAvatarSelected;
  final int initialIndex;
  final String arrowAsset;
  final VoidCallback? onCloseRequested;
  final ArcSide side;

  @override
  State<ArcAvatarPicker> createState() => _ArcAvatarPickerState();
}

class _ArcAvatarPickerState extends State<ArcAvatarPicker>
    with SingleTickerProviderStateMixin {
  static const double _angleStep = 0.30;
  static const double _radius = 340;
  static const double _visibleExtent = 115;
  static const double _angularSpread = 1.15;
  static const double _trackWidth = 84;
  static const double _maxAvatarSize = 72;
  static const double _minAvatarSize = 26;
  static const double _maxFrameSize = 85;
  static const double _minFrameSize = 53;
  static const double _frameAngularSpread = 1.0;
  static const double _frameRadius = 300;

  late double _scrollOffset;
  late int _selectedIndex;

  late final AnimationController _snapCtrl;
  late final CurvedAnimation _snapAnim;
  Tween<double>? _snapTween;
  int? _pendingSelection;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, widget.avatars.length - 1);
    _scrollOffset = _selectedIndex * _angleStep;
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _snapAnim = CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic);
    _snapAnim.addListener(_onSnapTick);
    _snapAnim.addStatusListener(_onSnapStatus);
  }

  @override
  void dispose() {
    _snapAnim.removeListener(_onSnapTick);
    _snapAnim.removeStatusListener(_onSnapStatus);
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    if (_snapTween != null) {
      setState(() => _scrollOffset = _snapTween!.evaluate(_snapAnim));
    }
  }

  void _onSnapStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final idx = _pendingSelection;
    _pendingSelection = null;
    if (idx == null || idx == _selectedIndex) return;
    setState(() => _selectedIndex = idx);
    widget.onAvatarSelected(widget.avatars[idx]);
  }

  void _cancelSnap() {
    if (_snapCtrl.isAnimating) _snapCtrl.stop();
  }

  void _snapToIndex(int idx) {
    if (idx == _selectedIndex && !_snapCtrl.isAnimating) {
      _scrollOffset = idx * _angleStep;
      return;
    }
    _pendingSelection = idx;
    _snapTween = Tween<double>(
      begin: _scrollOffset,
      end: idx * _angleStep,
    );
    _snapCtrl.forward(from: 0);
  }

  void _handleDragStart(DragStartDetails details) => _cancelSnap();

  void _handleDragUpdate(DragUpdateDetails details) {
    _cancelSnap();
    final r = widget.side == ArcSide.right ? _frameRadius : _radius;
    setState(() {
      _scrollOffset = (_scrollOffset - details.delta.dy / r).clamp(
        -_angleStep * 0.55,
        (widget.avatars.length - 1 + 0.55) * _angleStep,
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final r = widget.side == ArcSide.right ? _frameRadius : _radius;
    final flingVelocity = details.velocity.pixelsPerSecond.dy;
    final projected = _scrollOffset - flingVelocity / r * 0.12;
    final idx = (projected / _angleStep)
        .round()
        .clamp(0, widget.avatars.length - 1);
    _snapToIndex(idx);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    final vy = details.velocity.pixelsPerSecond.dy;
    if (widget.side == ArcSide.left) {
      if (vx < -400 && vx.abs() > vy.abs() * 1.5) {
        widget.onCloseRequested?.call();
      }
    } else {
      if (vx > 400 && vx.abs() > vy.abs() * 1.5) {
        widget.onCloseRequested?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.reveal,
      builder: (context, _) {
        final revealValue = widget.reveal.value;
        return IgnorePointer(
          ignoring: revealValue < 0.5,
          child: Opacity(
            opacity: revealValue.clamp(0.0, 1.0),
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final centerY = constraints.maxHeight / 2;
                  const centerXLeft = _visibleExtent - _radius;
                  const frameCenterXLeft = _visibleExtent - _frameRadius;
                  final isRight = widget.side == ArcSide.right;
                  final centerX = isRight
                      ? constraints.maxWidth - frameCenterXLeft
                      : centerXLeft;
                  final maxW = constraints.maxWidth;

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _handleDragStart,
                    onVerticalDragUpdate: _handleDragUpdate,
                    onVerticalDragEnd: _handleDragEnd,
                    onHorizontalDragEnd: _handleHorizontalDragEnd,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ArcTrackPainter(
                              centerX: centerX,
                              centerY: centerY,
                            ),
                          ),
                        ),
                        for (var i = 0; i < widget.avatars.length; i++)
                          _buildAvatar(i, centerX, centerY, maxW),
                        Positioned(
                          left: isRight
                              ? maxW - _visibleExtent + 50
                              : _visibleExtent - 38 - 50,
                          top: centerY - 19,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: isRight
                                ? (Matrix4.identity()..scale(-1.0, 1.0))
                                : Matrix4.identity(),
                            child: Image.asset(
                              widget.arrowAsset,
                              width: 38,
                              height: 38,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.arrow_left_rounded,
                                    color: Color(0xFFFE4EF0),
                                    size: 38,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(int index, double centerX, double centerY, double maxWidth) {
    final isRightSide = widget.side == ArcSide.right;
    final spread = isRightSide ? _frameAngularSpread : _angularSpread;
    final angle = index * _angleStep - _scrollOffset;
    if (angle < -spread || angle > spread) {
      return const SizedBox.shrink();
    }

    final proximityRaw = (1 - angle.abs() / spread).clamp(0.0, 1.0);
    final proximity = Curves.easeInOutCubic.transform(proximityRaw);
    final minSize = isRightSide ? _minFrameSize : _minAvatarSize;
    final maxSize = isRightSide ? _maxFrameSize : _maxAvatarSize;
    final size = minSize + (maxSize - minSize) * proximity;
    final opacity = 0.30 + 0.70 * proximity;

    final r = isRightSide ? _frameRadius : _radius;
    final xLeft = _visibleExtent - r + r * math.cos(angle);
    final x = isRightSide ? maxWidth - xLeft : xLeft;
    final y = centerY + r * math.sin(angle);

    final isSelected = index == _selectedIndex;

    final startInterval = (index * 0.06).clamp(0.0, 0.7);
    final entranceRaw =
        ((widget.reveal.value - startInterval) / (1 - startInterval))
            .clamp(0.0, 1.0);
    final entrance = Curves.easeOutBack.transform(entranceRaw);

    final isRight = widget.side == ArcSide.right;
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: Transform.translate(
        offset: Offset((1 - entrance) * (isRight ? 28 : -28), 0),
        child: Opacity(
          opacity: (opacity * entrance).clamp(0.0, 1.0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _snapToIndex(index),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: isRight ? BoxShape.rectangle : BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFE4EF0).withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
                color: Colors.transparent,
              ),
              child: isRight
                  ? Image.asset(
                      widget.avatars[index],
                      fit: BoxFit.contain,
                      width: size,
                      height: size,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image,
                              color: Colors.white54, size: 22),
                    )
                  : ClipOval(
                      child: Image.asset(
                        widget.avatars[index],
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcTrackPainter extends CustomPainter {
  _ArcTrackPainter({required this.centerX, required this.centerY});

  final double centerX;
  final double centerY;

  @override
  void paint(Canvas canvas, Size size) {
    // Arc track hidden (opacity 0) — only avatars + arrow remain visible.
  }

  @override
  bool shouldRepaint(covariant _ArcTrackPainter oldDelegate) =>
      oldDelegate.centerX != centerX || oldDelegate.centerY != centerY;
}
