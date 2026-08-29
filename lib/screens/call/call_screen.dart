import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/call.dart';
import '../../services/call/call_manager.dart';
import '../../utils/time_format.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String callName;
  final CallType callType;
  final List<String> members;
  final String createdBy;
  final bool isGroup;
  final String? chatId;
  final String? groupId;

  const CallScreen({
    super.key,
    required this.callId,
    required this.callName,
    required this.callType,
    required this.members,
    required this.createdBy,
    this.isGroup = false,
    this.chatId,
    this.groupId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallManager _callManager = CallManager();

  @override
  void initState() {
    super.initState();
    _callManager.addListener(_onCallUpdate);
  }

  @override
  void dispose() {
    _callManager.removeListener(_onCallUpdate);
    super.dispose();
  }

  void _onCallUpdate() {
    if (!mounted) return;

    if (_callManager.activeCall == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {});
  }

  void _minimizeCall() {
    if (mounted) {
      _callManager.showCallOverlay();
      Navigator.of(context).pop();
    }
  }

  Future<void> _endCall() async {
    await _callManager.endActiveCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == CallType.video;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _minimizeCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0A2E),
        body: SizedBox.expand(
          child: SafeArea(
            child: isVideo
                ? Column(
                    children: [
                      Expanded(child: _buildVideoView()),
                      _buildControls(),
                    ],
                  )
                : _buildAudioView(),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    final localRenderer = _callManager.localRenderer;
    final remoteRenderer = _callManager.remoteRenderer;
    final hasRemoteStream = remoteRenderer?.srcObject != null;
    final hasLocalStream = localRenderer?.srcObject != null;

    return Stack(
      children: [
        if (hasRemoteStream)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 320,
                height: 240,
                child: RTCVideoView(
                  remoteRenderer!,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
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
                  backgroundColor: const Color(0xFFFE4EF0)
                      .withValues(alpha: 0.2),
                  child: Text(
                    widget.callName.isNotEmpty
                        ? widget.callName[0].toUpperCase()
                        : '?',
                    style:
                        const TextStyle(fontSize: 40, color: Colors.white),
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
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    localRenderer!,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: hasLocalStream ? 180 : 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                widget.callName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatSeconds(_callManager.callDuration),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14),
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
            backgroundColor:
                const Color(0xFFFE4EF0).withValues(alpha: 0.2),
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
            formatSeconds(_callManager.callDuration),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (widget.isGroup) ...[
            const SizedBox(height: 8),
            Text(
              '${widget.members.length} participants',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _callManager.isMuted ? Icons.mic_off : Icons.mic,
                label: _callManager.isMuted ? 'Unmute' : 'Mute',
                onTap: _callManager.toggleMute,
                isActive: !_callManager.isMuted,
              ),
              _buildControlButton(
                icon: _callManager.isSpeakerOn
                    ? Icons.volume_up
                    : Icons.volume_down,
                label: _callManager.isSpeakerOn ? 'Speaker' : 'Earpiece',
                onTap: _callManager.toggleSpeaker,
                isActive: true,
              ),
              _buildControlButton(
                icon: Icons.keyboard_arrow_down,
                label: 'Minimize',
                onTap: _minimizeCall,
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
            icon: _callManager.isMuted ? Icons.mic_off : Icons.mic,
            label: _callManager.isMuted ? 'Unmute' : 'Mute',
            onTap: _callManager.toggleMute,
            isActive: !_callManager.isMuted,
          ),
          if (widget.callType == CallType.video) ...[
            _buildControlButton(
              icon: Icons.cameraswitch,
              label: 'Switch',
              onTap: _callManager.switchCamera,
              isActive: true,
            ),
            _buildControlButton(
              icon:
                  _callManager.isVideoOff ? Icons.videocam_off : Icons.videocam,
              label: _callManager.isVideoOff ? 'Camera On' : 'Camera Off',
              onTap: _callManager.toggleVideo,
              isActive: !_callManager.isVideoOff,
            ),
          ],
          _buildControlButton(
            icon: _callManager.isSpeakerOn
                ? Icons.volume_up
                : Icons.volume_down,
            label: _callManager.isSpeakerOn ? 'Speaker' : 'Earpiece',
            onTap: _callManager.toggleSpeaker,
            isActive: true,
          ),
          _buildControlButton(
            icon: Icons.keyboard_arrow_down,
            label: 'Minimize',
            onTap: _minimizeCall,
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
              color:
                  iconColor ?? (isActive ? Colors.white : Colors.white70),
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
