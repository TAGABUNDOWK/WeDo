import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/call.dart';
import '../../services/call/call_manager.dart';
import '../../services/call/call_service.dart';
import '../../services/direct/direct_service.dart';
import '../../services/group/group_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final Call call;
  final String callerName;

  const IncomingCallScreen({
    super.key,
    required this.call,
    required this.callerName,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final CallManager _callManager = CallManager();
  StreamSubscription? _callSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _playRingtone();
    _listenForCallEnd();
  }

  void _playRingtone() async {
    try {
      await _ringtonePlayer.setAsset('assets/audio/ringtone.wav');
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringtonePlayer.play();
    } catch (e) {
      debugPrint('Error playing incoming ringtone: $e');
    }
  }

  void _listenForCallEnd() {
    final callService = CallService();
    _callSub = callService.getCallStream(widget.call.id).listen((call) {
      if (call == null || call.status == CallStatus.ended) {
        _ringtonePlayer.stop();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callSub?.cancel();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  void _acceptCall() async {
    _ringtonePlayer.stop();
    if (!mounted) return;

    try {
      await _callManager.startNewCall(
        callData: ActiveCallData(
          callId: widget.call.id,
          callName: widget.callerName,
          callType: widget.call.type,
          members: widget.call.members,
          createdBy: widget.call.createdBy,
          isGroup: widget.call.groupId != null,
          chatId: widget.call.chatId,
          groupId: widget.call.groupId,
          startedAt: DateTime.now(),
        ),
        audioOnly: widget.call.type == CallType.audio,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: widget.call.id,
              callName: widget.callerName,
              callType: widget.call.type,
              members: widget.call.members,
              createdBy: widget.call.createdBy,
              isGroup: widget.call.groupId != null,
              chatId: widget.call.chatId,
              groupId: widget.call.groupId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept call: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _declineCall() {
    _ringtonePlayer.stop();
    _sendMissedCallMessage();
    final callService = CallService();
    callService.endCall(widget.call.id);
    Navigator.of(context).pop();
  }

  void _sendMissedCallMessage() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final callTypeStr = widget.call.type == CallType.video ? 'video' : 'audio';

    if (widget.call.groupId != null) {
      GroupService().sendCallMessage(
        groupId: widget.call.groupId!,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? currentUser.email ?? 'Unknown',
        callType: callTypeStr,
        callStatus: 'missed',
        durationSeconds: 0,
      );
    } else if (widget.call.chatId != null) {
      DirectService().sendCallMessage(
        chatId: widget.call.chatId!,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? currentUser.email ?? 'Unknown',
        callType: callTypeStr,
        callStatus: 'missed',
        durationSeconds: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.type == CallType.video;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _declineCall();
      },
      child: Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A2E), Color(0xFF2D1B69)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
                            child: Text(
                              widget.callerName.isNotEmpty
                                  ? widget.callerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 44,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      widget.callerName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 15,
                      ),
                    ),
                    if (widget.call.groupId != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Group Call',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _declineCall,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Decline',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 64),
                    GestureDetector(
                      onTap: _acceptCall,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isVideo ? Icons.videocam : Icons.call,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
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
    ),
    );
  }
}
