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

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  final CallService _callService = CallService();
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final _currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription? _callSub;
  bool _callWasActive = false;

  @override
  void initState() {
    super.initState();
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
        senderId: _currentUser!.uid,
        senderName: _currentUser!.displayName ?? _currentUser!.email ?? 'Unknown',
        callType: callTypeStr,
        callStatus: 'missed',
        durationSeconds: 0,
      );
    } else if (widget.call.chatId != null) {
      DirectService().sendCallMessage(
        chatId: widget.call.chatId!,
        senderId: _currentUser!.uid,
        senderName: _currentUser!.displayName ?? _currentUser!.email ?? 'Unknown',
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
    _callSub?.cancel();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.type == CallType.video;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A2E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              isVideo ? 'Video Call' : 'Audio Call',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
              child: Text(
                widget.callName.isNotEmpty
                    ? widget.callName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.callName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ringing...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            if (widget.call.groupId != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Group Call',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
            const Spacer(flex: 3),
            GestureDetector(
              onTap: _endCall,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
