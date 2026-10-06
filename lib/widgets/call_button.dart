import 'package:flutter/material.dart';
import '../models/call.dart';
import '../services/call/call_manager.dart';
import '../utils/safe_nav.dart';

class BeatingCircle extends StatefulWidget {
  final Widget child;
  const BeatingCircle({super.key, required this.child});

  @override
  State<BeatingCircle> createState() => BeatingCircleState();
}

class BeatingCircleState extends State<BeatingCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFE4EF0)
                  .withValues(alpha: 0.4 + (_ctrl.value * 0.5)),
              width: 2,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class CallButtons extends StatefulWidget {
  final String chatId;
  final bool isGroup;
  final VoidCallback onStartAudioCall;
  final VoidCallback onStartVideoCall;
  final VoidCallback? onRejoin;
  final VoidCallback? onReturnToCall;

  /// True when a call for this chat is running even though this device is
  /// not part of it (late join).
  final bool callAvailable;
  final CallType? availableCallType;

  const CallButtons({
    super.key,
    required this.chatId,
    required this.isGroup,
    required this.onStartAudioCall,
    required this.onStartVideoCall,
    this.onRejoin,
    this.onReturnToCall,
    this.callAvailable = false,
    this.availableCallType,
  });

  @override
  State<CallButtons> createState() => _CallButtonsState();
}

class _CallButtonsState extends State<CallButtons> {
  final CallManager _mgr = CallManager();

  @override
  void initState() {
    super.initState();
    _mgr.addListener(_onChange);
  }

  @override
  void dispose() {
    _mgr.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    // CallManager can notify during another widget's build pass, so the
    // rebuild has to be deferred.
    safeNav(() {
      if (mounted) setState(() {});
    }, label: 'call buttons update');
  }

  @override
  Widget build(BuildContext context) {
    bool matches(String? id) => id == widget.chatId;
    final active = _mgr.activeCall;
    final outgoing = _mgr.outgoingCall;
    final left = _mgr.leftCall;
    final localInCall = (active != null && matches(widget.isGroup ? active.groupId : active.chatId)) ||
        (outgoing != null && matches(widget.isGroup ? outgoing.groupId : outgoing.chatId));
    final canRejoin = !localInCall &&
        left != null &&
        matches(widget.isGroup ? left.groupId : left.chatId);
    final activeType = active != null && matches(widget.isGroup ? active.groupId : active.chatId)
        ? active.callType
        : (outgoing != null && matches(widget.isGroup ? outgoing.groupId : outgoing.chatId)
            ? outgoing.callType
            : null);
    final engaged = localInCall || widget.callAvailable;
    final callType = activeType ??
        (widget.callAvailable ? widget.availableCallType : null);
    final inCall = localInCall || (widget.callAvailable && !canRejoin);
    final audioActive = engaged && callType == CallType.audio;
    final videoActive = engaged && callType == CallType.video;

    VoidCallback resolve(VoidCallback start) {
      if (canRejoin && widget.onRejoin != null) return widget.onRejoin!;
      if (inCall && widget.onReturnToCall != null) return widget.onReturnToCall!;
      return start;
    }

    Widget callBtn(
      String asset,
      IconData fallback,
      bool beating,
      VoidCallback onTap, {
      double size = 24,
      double fallbackSize = 22,
    }) {
      final btn = GestureDetector(
        onTap: onTap,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            fallback,
            color: Colors.white,
            size: fallbackSize,
          ),
        ),
      );
      if (!beating) return btn;
      return BeatingCircle(child: btn);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        callBtn(
          'assets/icons/call.png',
          Icons.phone,
          audioActive,
          resolve(widget.onStartAudioCall),
          size: 16,
          fallbackSize: 14,
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: callBtn(
            'assets/icons/camera-on.png',
            Icons.videocam,
            videoActive,
            resolve(widget.onStartVideoCall),
            size: 33,
            fallbackSize: 31,
          ),
        ),
      ],
    );
  }
}
