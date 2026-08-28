import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/call.dart';
import '../../services/auth/user_service.dart';
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
  final UserService _userService = UserService();
  final Map<String, String> _participantNames = {};

  Offset _pipPosition = Offset.zero;
  bool _pipInitialized = false;
  String? _focusedPeerId;

  @override
  void initState() {
    super.initState();
    _callManager.addListener(_onCallUpdate);
    _loadParticipantNames();
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

  Future<void> _loadParticipantNames() async {
    for (final uid in widget.members) {
      if (_participantNames.containsKey(uid)) continue;
      try {
        final user = await _userService.getUserDocument(uid);
        if (user != null && mounted) {
          setState(() {
            _participantNames[uid] = user.displayName.isNotEmpty
                ? user.displayName
                : (user.username.isNotEmpty ? user.username : uid);
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _participantNames[uid] = uid;
          });
        }
      }
    }
  }

  String _getParticipantName(String uid) {
    return _participantNames[uid] ?? uid;
  }

  void _initPipPosition(BoxConstraints constraints) {
    if (!_pipInitialized) {
      _pipPosition = Offset(constraints.maxWidth - 136, 16);
      _pipInitialized = true;
    }
  }

  void _snapPipToNearestCorner(BoxConstraints constraints) {
    const pipWidth = 120.0;
    const pipHeight = 160.0;
    const padding = 16.0;
    const controlsHeight = 100.0;

    final corners = [
      const Offset(padding, padding),
      Offset(constraints.maxWidth - pipWidth - padding, padding),
      Offset(padding, constraints.maxHeight - pipHeight - padding - controlsHeight),
      Offset(constraints.maxWidth - pipWidth - padding,
          constraints.maxHeight - pipHeight - padding - controlsHeight),
    ];

    final currentCenter =
        _pipPosition + const Offset(pipWidth / 2, pipHeight / 2);
    Offset nearest = corners.first;
    double minDist = double.infinity;
    for (final corner in corners) {
      final dist = (corner + const Offset(pipWidth / 2, pipHeight / 2) -
              currentCenter)
          .distance;
      if (dist < minDist) {
        minDist = dist;
        nearest = corner;
      }
    }
    setState(() {
      _pipPosition = nearest;
    });
  }

  void _onPeerTapped(String? peerId) {
    setState(() {
      _focusedPeerId = (_focusedPeerId == peerId) ? null : peerId;
    });
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
    final remoteCount = _callManager.remoteParticipantCount;

    if (widget.isGroup && remoteCount > 1) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _initPipPosition(constraints);
          return _buildGroupView(constraints);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _initPipPosition(constraints);
        return _buildSingleRemoteView(constraints);
      },
    );
  }

  Widget _buildSingleRemoteView(BoxConstraints constraints) {
    final remoteRenderer = _callManager.remoteRenderer;
    final hasRemoteStream = remoteRenderer?.srcObject != null;
    final hasLocalStream = _callManager.localRenderer?.srcObject != null;

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
                  backgroundColor:
                      const Color(0xFFFE4EF0).withValues(alpha: 0.2),
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
        if (hasLocalStream) _buildDraggablePip(constraints),
        Positioned(
          top: 16,
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
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupView(BoxConstraints constraints) {
    final renderers = _callManager.remoteRenderers;
    final hasLocalStream = _callManager.localRenderer?.srcObject != null;
    final entries = renderers.entries.toList();

    if (_focusedPeerId != null && renderers.containsKey(_focusedPeerId)) {
      return _buildFocusedPeerView(constraints, entries);
    }

    return _buildGridPeerView(constraints, entries, hasLocalStream);
  }

  Widget _buildFocusedPeerView(
      BoxConstraints constraints, List<MapEntry<String, RTCVideoRenderer>> entries) {
    final focusedEntry = entries.firstWhere(
      (e) => e.key == _focusedPeerId,
      orElse: () => entries.first,
    );
    final hasLocalStream = _callManager.localRenderer?.srcObject != null;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _onPeerTapped(focusedEntry.key),
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 320,
                height: 240,
                child: RTCVideoView(
                  focusedEntry.value,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                _getParticipantName(focusedEntry.key),
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
        _buildMiniStrip(entries, focusedEntry.key),
        if (hasLocalStream) _buildDraggablePip(constraints),
      ],
    );
  }

  Widget _buildMiniStrip(
      List<MapEntry<String, RTCVideoRenderer>> entries, String focusedId) {
    final otherEntries = entries.where((e) => e.key != focusedId).toList();
    if (otherEntries.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      right: 8,
      child: Column(
        children: otherEntries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _onPeerTapped(entry.key),
              child: Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RTCVideoView(
                        entry.value,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _getParticipantName(entry.key),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGridPeerView(
    BoxConstraints constraints,
    List<MapEntry<String, RTCVideoRenderer>> entries,
    bool hasLocalStream,
  ) {
    final count = entries.length;
    final int crossAxisCount;
    if (count <= 2) {
      crossAxisCount = 2;
    } else if (count <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return GestureDetector(
              onTap: () => _onPeerTapped(entry.key),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RTCVideoView(
                      entry.value,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getParticipantName(entry.key),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                widget.callName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
        if (hasLocalStream) _buildDraggablePip(constraints),
      ],
    );
  }

  Widget _buildDraggablePip(BoxConstraints constraints) {
    final localRenderer = _callManager.localRenderer;
    if (localRenderer == null || localRenderer.srcObject == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _pipPosition.dx,
      top: _pipPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pipPosition = Offset(
              (_pipPosition.dx + details.delta.dx)
                  .clamp(0, constraints.maxWidth - 120),
              (_pipPosition.dy + details.delta.dy)
                  .clamp(0, constraints.maxHeight - 160),
            );
          });
        },
        onPanEnd: (_) {
          _snapPipToNearestCorner(constraints);
        },
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: RTCVideoView(
              localRenderer,
              mirror: true,
              objectFit:
                  RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        ),
      ),
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
                label:
                    _callManager.isSpeakerOn ? 'Speaker' : 'Earpiece',
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
              icon: _callManager.isVideoOff
                  ? Icons.videocam_off
                  : Icons.videocam,
              label:
                  _callManager.isVideoOff ? 'Camera On' : 'Camera Off',
              onTap: _callManager.toggleVideo,
              isActive: !_callManager.isVideoOff,
            ),
          ],
          _buildControlButton(
            icon: _callManager.isSpeakerOn
                ? Icons.volume_up
                : Icons.volume_down,
            label:
                _callManager.isSpeakerOn ? 'Speaker' : 'Earpiece',
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
              color: iconColor ??
                  (isActive ? Colors.white : Colors.white70),
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
