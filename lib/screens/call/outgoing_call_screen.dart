import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/call.dart';
import '../../services/call/call_service.dart';
import '../../services/direct/direct_service.dart';
import '../../services/group/group_service.dart';
import 'call_screen.dart';

class OutgoingCallScreen extends StatefulWidget {
  final Call call;
  final String callName;

  const OutgoingCallScreen({
    super.key,
    required this.call,
    required this.callName,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final _currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription? _callSub;
  bool _callWasActive = false;

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
    _listenForCallStatus();
  }

  void _playRingtone() async {
    try {
      await _ringtonePlayer.setAsset('assets/audio/ringtone.wav');
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringtonePlayer.play();
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  void _listenForCallStatus() {
    _callSub = _callService.getCallStream(widget.call.id).listen((call) {
      if (call == null || call.status == CallStatus.ended) {
        if (!_callWasActive) {
          _sendMissedCallMessage();
        }
        _endCall();
        return;
      }

      if (call.status == CallStatus.active) {
        _callWasActive = true;
        _ringtonePlayer.stop();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CallScreen(
                callId: call.id,
                callName: widget.callName,
                callType: call.type,
                members: call.members,
                createdBy: call.createdBy,
                isGroup: call.groupId != null,
                chatId: call.chatId,
                groupId: call.groupId,
              ),
            ),
          );
        }
      }
    });
  }

  void _sendMissedCallMessage() {
    if (_currentUser == null) return;

    final callTypeStr = widget.call.type == CallType.video ? 'video' : 'audio';

    if (widget.call.groupId != null) {
      GroupService().sendCallMessage(
        groupId: widget.call.groupId!,
        senderId: _currentUser.uid,
        senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
        callType: callTypeStr,
        callStatus: 'missed',
        durationSeconds: 0,
      );
    } else if (widget.call.chatId != null) {
      DirectService().sendCallMessage(
        chatId: widget.call.chatId!,
        senderId: _currentUser.uid,
        senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
        callType: callTypeStr,
        callStatus: 'missed',
        durationSeconds: 0,
      );
    }
  }

  void _endCall() {
    _callSub?.cancel();
    _ringtonePlayer.stop();
    _callService.endCall(widget.call.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callSub?.cancel();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.type == CallType.video;

    return Scaffold(
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
                              widget.callName.isNotEmpty
                                  ? widget.callName[0].toUpperCase()
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
                      widget.callName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isVideo ? 'Video Call' : 'Audio Call',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ringing...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFE4EF0),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _endCall,
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
                            'Cancel',
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
    );
  }
}
