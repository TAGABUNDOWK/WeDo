import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final Map<String, String> _participantPhotos = {};

  Offset _pipPosition = Offset.zero;
  bool _pipInitialized = false;
  bool _isEndingCall = false;

  bool _pinchTriggered = false;
  bool _showFlipFlash = false;

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

    if (_callManager.activeCall == null && !_isEndingCall) {
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
    if (_isEndingCall) return;
    _isEndingCall = true;
    await _callManager.endActiveCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _leaveGroupCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;
    await _callManager.leaveGroupCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _flipCamera() {
    _callManager.switchCamera();
    if (!mounted) return;
    setState(() => _showFlipFlash = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showFlipFlash = false);
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _pinchTriggered = false;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_pinchTriggered && details.scale < 0.8) {
      _pinchTriggered = true;
      _minimizeCall();
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _pinchTriggered = false;
  }

  Future<void> _loadParticipantNames() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null && !_participantNames.containsKey(myUid)) {
      try {
        final user = await _userService.getUserDocument(myUid);
        if (user != null && mounted) {
          setState(() {
            _participantNames[myUid] = user.displayName.isNotEmpty
                ? user.displayName
                : (user.username.isNotEmpty ? user.username : myUid);
            if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
              _participantPhotos[myUid] = user.photoUrl!;
            } else if (user.avatarAsset != null && user.avatarAsset!.isNotEmpty) {
              _participantPhotos[myUid] = 'asset:${user.avatarAsset!}';
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _participantNames[myUid] = myUid;
          });
        }
      }
    }

    for (final uid in widget.members) {
      if (_participantNames.containsKey(uid)) continue;
      try {
        final user = await _userService.getUserDocument(uid);
        if (user != null && mounted) {
          setState(() {
            _participantNames[uid] = user.displayName.isNotEmpty
                ? user.displayName
                : (user.username.isNotEmpty ? user.username : uid);
            if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
              _participantPhotos[uid] = user.photoUrl!;
            } else if (user.avatarAsset != null && user.avatarAsset!.isNotEmpty) {
              _participantPhotos[uid] = 'asset:${user.avatarAsset!}';
            }
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

  String? _getParticipantPhoto(String uid) {
    return _participantPhotos[uid];
  }

  bool _hasActiveVideo(RTCVideoRenderer renderer) {
    final stream = renderer.srcObject;
    if (stream == null) return false;
    final videoTracks = stream.getVideoTracks();
    if (videoTracks.isEmpty) return false;
    return videoTracks.any((track) => track.enabled);
  }

  bool get _hasRemoteStream => _callManager.remoteRenderer?.srcObject != null;

  bool get _hasLocalStream => _callManager.localRenderer?.srcObject != null;

  Widget _buildParticipantAvatar({
    required String uid,
    required double radius,
  }) {
    final name = _getParticipantName(uid);
    final photo = _getParticipantPhoto(uid);
    final hasPhoto = photo != null && photo.isNotEmpty;
    final isAsset = hasPhoto && photo.startsWith('asset:');

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
      backgroundImage: hasPhoto
          ? (isAsset
              ? AssetImage(photo.replaceFirst('asset:', ''))
              : NetworkImage(photo))
          : null,
      child: !hasPhoto
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: radius,
                color: const Color(0xFFFE4EF0),
              ),
            )
          : null,
    );
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
    const controlsHeight = 120.0;

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
        body: LayoutBuilder(
          builder: (context, constraints) {
            _initPipPosition(constraints);

            return Stack(
              children: [
                if (isVideo) ...[
                  _buildVideoBackground(),
                  if (!_hasRemoteStream) _buildWaitingOverlay(),
                  _buildFloatingHeader(),
                  if (_hasRemoteStream && _hasLocalStream)
                    _buildDraggablePip(constraints),
                  _buildFlipFlash(),
                ] else ...[
                  _buildAudioCenterContent(),
                  _buildAudioChevron(),
                ],
                _buildFloatingControls(includeCamera: isVideo),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullBleedVideo(RTCVideoRenderer renderer, {required bool mirror}) {
    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: 320,
          height: 240,
          child: RTCVideoView(
            renderer,
            mirror: mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBackground() {
    final remote = _callManager.remoteRenderer;
    final local = _callManager.localRenderer;

    Widget feed;
    if (remote != null && _hasActiveVideo(remote)) {
      feed = _buildFullBleedVideo(remote, mirror: false);
    } else if (local != null && _hasActiveVideo(local)) {
      feed = _buildFullBleedVideo(local, mirror: true);
    } else {
      final remoteUid = remote != null && _callManager.remoteRenderers.isNotEmpty
          ? _callManager.remoteRenderers.keys.first
          : null;
      feed = Positioned.fill(
        child: Container(
          color: const Color(0xFF2D1B69),
          child: remoteUid != null
              ? Center(
                  child: _buildParticipantAvatar(uid: remoteUid, radius: 60),
                )
              : null,
        ),
      );
    }

    return Positioned.fill(
      child: GestureDetector(
        onDoubleTap: _flipCamera,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            feed,
            const Positioned.fill(
              child: ColoredBox(color: Color(0x8C000000)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildWaitingAvatar(radius: 38),
              const SizedBox(height: 16),
              const Text(
                'Waiting for participants to connect...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingAvatar({required double radius}) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    String? peerUid;
    if (!widget.isGroup) {
      for (final uid in widget.members) {
        if (uid != myUid) {
          peerUid = uid;
          break;
        }
      }
    }

    if (peerUid != null && _participantPhotos.containsKey(peerUid)) {
      return _buildParticipantAvatar(uid: peerUid, radius: radius);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
      child: Text(
        widget.callName.isNotEmpty ? widget.callName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFloatingHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: _minimizeCall,
                icon: const Icon(
                  Icons.chevron_left,
                  color: Color(0xFFFE4EF0),
                  size: 32,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.callName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatSeconds(_callManager.callDuration),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioChevron() {
    return Positioned(
      top: 0,
      left: 4,
      child: SafeArea(
        bottom: false,
        child: IconButton(
          onPressed: _minimizeCall,
          icon: const Icon(
            Icons.chevron_left,
            color: Color(0xFFFE4EF0),
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildAudioCenterContent() {
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
        ],
      ),
    );
  }

  Widget _buildFlipFlash() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _showFlipFlash ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.cameraswitch,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggablePip(BoxConstraints constraints) {
    final localRenderer = _callManager.localRenderer;
    if (localRenderer == null || localRenderer.srcObject == null) {
      return const SizedBox.shrink();
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hasLocalVideo = _hasActiveVideo(localRenderer);

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
            child: hasLocalVideo
                ? RTCVideoView(
                    localRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: const Color(0xFF2D1B69),
                    child: Center(
                      child: _buildParticipantAvatar(
                        uid: myUid,
                        radius: 30,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingControls({required bool includeCamera}) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (includeCamera)
                _buildFloatingControlButton(
                  asset: _callManager.isVideoOff
                      ? 'assets/icons/camera-off.png'
                      : 'assets/icons/camera-on.png',
                  fallbackIcon: _callManager.isVideoOff
                      ? Icons.videocam_off
                      : Icons.videocam,
                  onTap: _callManager.toggleVideo,
                  dimmed: _callManager.isVideoOff,
                ),
              _buildFloatingControlButton(
                asset: _callManager.isMuted
                    ? 'assets/icons/mic-on.png'
                    : 'assets/icons/mic-off.png',
                fallbackIcon: _callManager.isMuted ? Icons.mic : Icons.mic_off,
                onTap: _callManager.toggleMute,
                dimmed: _callManager.isMuted,
              ),
              _buildFloatingControlButton(
                asset: _callManager.isSpeakerOn
                    ? 'assets/icons/speaker-high.png'
                    : 'assets/icons/speaker-low.png',
                fallbackIcon: _callManager.isSpeakerOn
                    ? Icons.volume_up
                    : Icons.volume_down,
                onTap: _callManager.toggleSpeaker,
              ),
              _buildFloatingControlButton(
                asset: 'assets/icons/call.png',
                fallbackIcon: Icons.call_end,
                backgroundColor:
                    widget.isGroup ? Colors.orange.shade800 : Colors.red,
                iconColor: const Color(0xFFFE4EF0),
                iconRotation: -135 * math.pi / 180,
                onTap: widget.isGroup ? _leaveGroupCall : _endCall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingControlButton({
    String? asset,
    required IconData fallbackIcon,
    required VoidCallback onTap,
    bool dimmed = false,
    Color? backgroundColor,
    Color? iconColor,
    double iconRotation = 0,
  }) {
    final Color bg = backgroundColor ??
        (dimmed
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.20));
    final Color fg = iconColor ?? const Color(0xFFFE4EF0);

    final Widget button = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: iconRotation,
        child: asset != null
            ? Image.asset(
                asset,
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                color: fg,
                errorBuilder: (context, error, stackTrace) => Icon(
                  fallbackIcon,
                  color: fg,
                  size: 26,
                ),
              )
            : Icon(
                fallbackIcon,
                color: fg,
                size: 28,
              ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: backgroundColor == null
            ? ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: button,
                ),
              )
            : button,
      ),
    );
  }
}
