import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/call.dart';
import '../../services/call/call_service.dart';
import '../../services/call/webrtc_service.dart';
import '../../services/direct/direct_service.dart';
import '../../services/group/group_service.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String callName;
  final CallType callType;
  final List<String> members;
  final bool isGroup;
  final String? chatId;
  final String? groupId;

  const CallScreen({
    super.key,
    required this.callId,
    required this.callName,
    required this.callType,
    required this.members,
    this.isGroup = false,
    this.chatId,
    this.groupId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  final WebRTCService _webrtcService = WebRTCService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;
  Timer? _callTimer;
  int _callDuration = 0;
  StreamSubscription? _callSub;
  StreamSubscription? _signalsSub;

  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    final audioOnly = widget.callType == CallType.audio;

    // Initialize WebRTC and get local media
    await _webrtcService.initialize(audioOnly: audioOnly);

    // Initialize renderers
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();

    // Listen for local stream
    _webrtcService.onLocalStream.listen((stream) {
      if (mounted) {
        setState(() {
          _localRenderer!.srcObject = stream;
        });
      }
    });

    // Listen for remote stream
    _webrtcService.onRemoteStream.listen((stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer!.srcObject = stream;
        });
      }
    });

    // Set up ICE candidate callback
    _webrtcService.onIceCandidateGenerated = (peerId, candidateJson) {
      final toUid = peerId;
      _callService.sendIceCandidate(
        callId: widget.callId,
        fromUid: _currentUser!.uid,
        toUid: toUid,
        candidate: candidateJson,
      );
    };

    // Join the call
    await _callService.joinCall(widget.callId, _currentUser!.uid);

    // Listen for call status changes
    _callSub = _callService.getCallStream(widget.callId).listen((call) {
      if (call == null || call.status == CallStatus.ended) {
        _endCall();
        return;
      }
    });

    // Listen for signaling messages
    _signalsSub = _callService
        .getSignalsForUser(widget.callId, _currentUser!.uid)
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fromUid = data['fromUid'] as String;
        final type = data['type'] as String;

        if (type == 'offer') {
          _webrtcService.handleOffer(
            callId: widget.callId,
            fromUid: fromUid,
            toUid: _currentUser!.uid,
            sdpJson: data['sdp'] as String,
          );
        } else if (type == 'answer') {
          _webrtcService.handleAnswer(
            fromUid: fromUid,
            toUid: _currentUser!.uid,
            sdpJson: data['sdp'] as String,
          );
        } else if (type == 'candidate') {
          _webrtcService.handleIceCandidate(
            fromUid: fromUid,
            toUid: _currentUser!.uid,
            candidateJson: data['candidate'] as String,
          );
        }
      }
    });

    // Create offers for all other members
    for (final memberUid in widget.members) {
      if (memberUid != _currentUser!.uid) {
        await _webrtcService.createOffer(
          callId: widget.callId,
          fromUid: _currentUser!.uid,
          toUid: memberUid,
        );
      }
    }

    // Start call duration timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    _callSub?.cancel();
    _signalsSub?.cancel();
    _callService.leaveCall(widget.callId, _currentUser!.uid);
    _webrtcService.dispose();

    _sendCallMessage();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _sendCallMessage() {
    if (_currentUser == null) return;

    final callTypeStr = widget.callType == CallType.video ? 'video' : 'audio';
    final duration = _callDuration;

    if (widget.isGroup && widget.groupId != null) {
      GroupService().sendCallMessage(
        groupId: widget.groupId!,
        senderId: _currentUser!.uid,
        senderName: _currentUser!.displayName ?? _currentUser!.email ?? 'Unknown',
        callType: callTypeStr,
        callStatus: 'active',
        durationSeconds: duration,
      );
    } else if (widget.chatId != null) {
      DirectService().sendCallMessage(
        chatId: widget.chatId!,
        senderId: _currentUser!.uid,
        senderName: _currentUser!.displayName ?? _currentUser!.email ?? 'Unknown',
        callType: callTypeStr,
        callStatus: 'active',
        durationSeconds: duration,
      );
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _webrtcService.toggleAudio();
  }

  void _toggleVideo() {
    setState(() => _isVideoOff = !_isVideoOff);
    _webrtcService.toggleVideo();
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
  }

  void _switchCamera() {
    _webrtcService.switchCamera();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callSub?.cancel();
    _signalsSub?.cancel();
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == CallType.video;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A2E),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: isVideo ? _buildVideoView() : _buildAudioView(),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    final hasRemoteStream = _remoteRenderer?.srcObject != null;
    final hasLocalStream = _localRenderer?.srcObject != null;

    return Stack(
      children: [
        if (hasRemoteStream)
          Center(
            child: RTCVideoView(
              _remoteRenderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          )
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                  child: Text(
                    widget.callName.isNotEmpty
                        ? widget.callName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connecting...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        if (hasLocalStream)
          Positioned(
            top: 16,
            right: 16,
            width: 120,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RTCVideoView(
                _localRenderer!,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
        Positioned(
          top: 16,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.callName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDuration(_callDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 70,
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
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_callDuration),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (widget.isGroup) ...[
            const SizedBox(height: 8),
            Text(
              '${widget.members.length} participants',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? 'Unmute' : 'Mute',
            onTap: _toggleMute,
            isActive: !_isMuted,
          ),
          if (widget.callType == CallType.video) ...[
            _buildControlButton(
              icon: Icons.cameraswitch,
              label: 'Switch',
              onTap: _switchCamera,
              isActive: true,
            ),
            _buildControlButton(
              icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
              label: _isVideoOff ? 'Camera On' : 'Camera Off',
              onTap: _toggleVideo,
              isActive: !_isVideoOff,
            ),
          ],
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
            onTap: _toggleSpeaker,
            isActive: true,
          ),
          _buildControlButton(
            icon: Icons.call_end,
            label: 'End',
            onTap: _endCall,
            isActive: true,
            backgroundColor: Colors.red,
            iconColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor ??
                  (isActive
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.3)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor ?? (isActive ? Colors.white : Colors.white70),
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
