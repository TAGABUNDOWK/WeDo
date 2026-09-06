import 'package:flutter/material.dart';

class SwipeReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  const SwipeReplyWrapper({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState extends State<SwipeReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  late AnimationController _animController;
  late Animation<double> _anim;

  static const double _replyThreshold = 100;
  static const double _maxDrag = 160;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _anim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _anim = Tween<double>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0);
    _animController.addListener(() {
      setState(() => _offset = _anim.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final progress = (_offset / _replyThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0) {
          setState(() {
            _offset = (_offset + details.delta.dx).clamp(0.0, _maxDrag);
          });
        } else if (_offset > 0) {
          setState(() {
            _offset = (_offset + details.delta.dx).clamp(0.0, _maxDrag);
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_offset >= _replyThreshold) {
          final startOffset = _offset;
          _anim = Tween<double>(begin: startOffset, end: _maxDrag).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
          );
          _animController.forward(from: 0).then((_) {
            widget.onReply();
            _anim = Tween<double>(begin: _maxDrag, end: 0).animate(
              CurvedAnimation(
                parent: _animController,
                curve: Curves.easeOutCubic,
              ),
            );
            _animController.forward(from: 0).then((_) {
              setState(() => _offset = 0);
            });
          });
          _animController.addListener(() {
            setState(() => _offset = _anim.value);
          });
        } else {
          _animateTo(0);
        }
      },
      onHorizontalDragCancel: () {
        _animateTo(0);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
          if (_offset > 8)
            Positioned(
              left: -8,
              top: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: progress,
                duration: Duration.zero,
                child: Container(
                  width: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
