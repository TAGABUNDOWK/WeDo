import 'package:flutter/material.dart';
import '../models/call.dart';
import '../services/call/call_manager.dart';

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

class CallButtons extends StatelessWidget {
  final String chatId;
  final bool isGroup;
  final VoidCallback onStartAudioCall;
  final VoidCallback onStartVideoCall;

  const CallButtons({
    super.key,
    required this.chatId,
    required this.isGroup,
    required this.onStartAudioCall,
    required this.onStartVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CallManager(),
      builder: (context, _) {
        final mgr = CallManager();
        bool matches(String? id) => id == chatId;
        final active = mgr.activeCall;
        final outgoing = mgr.outgoingCall;
        final inCall = (active != null && matches(isGroup ? active.groupId : active.chatId)) ||
            (outgoing != null && matches(isGroup ? outgoing.groupId : outgoing.chatId));
        final activeType = active != null && matches(isGroup ? active.groupId : active.chatId)
            ? active.callType
            : (outgoing != null && matches(isGroup ? outgoing.groupId : outgoing.chatId)
                ? outgoing.callType
                : null);
        final audioActive = inCall && activeType == CallType.audio;
        final videoActive = inCall && activeType == CallType.video;

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
              onStartAudioCall,
              size: 18,
              fallbackSize: 16,
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: callBtn(
                'assets/icons/video-call.png',
                Icons.videocam,
                videoActive,
                onStartVideoCall,
                size: 18,
                fallbackSize: 16,
              ),
            ),
          ],
        );
      },
    );
  }
}
