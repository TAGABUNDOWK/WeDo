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

class _Participant {
  final String uid;
  final RTCVideoRenderer? renderer;
  final bool isLocal;

  const _Participant({
    required this.uid,
    this.renderer,
    required this.isLocal,
  });
}

class _CallScreenState extends State<CallScreen> {
  final CallManager _callManager = CallManager();
  final UserService _userService = UserService();
  final Map<String, String> _participantNames = {};
  final Map<String, String> _participantPhotos = {};

  Offset _pipPosition = Offset.zero;
  bool _pipInitialized = false;
  String? _focusedPeerId;
  bool _isEndingCall = false;

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
    if (widget.isGroup) {
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
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (_focusedPeerId != null && renderers.containsKey(_focusedPeerId)) {
      final entries = renderers.entries.toList();
      return _buildFocusedPeerView(constraints, entries);
    }

    final participants = <_Participant>[];
    if (hasLocalStream) {
      participants.add(_Participant(
        uid: myUid,
        renderer: _callManager.localRenderer,
        isLocal: true,
      ));
    }
    for (final entry in renderers.entries) {
      participants.add(_Participant(
        uid: entry.key,
        renderer: entry.value,
        isLocal: false,
      ));
    }

    final count = participants.length;

    if (count == 0) {
      return Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildParticipantAvatar(uid: myUid, radius: 60),
                const SizedBox(height: 16),
                const Text(
                  'Waiting for others to join...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          _buildCallHeader(),
        ],
      );
    }

    if (count == 1) {
      return Stack(
        children: [
          _buildParticipantTile(participants[0], constraints),
          _buildCallHeader(),
        ],
      );
    }

    if (count == 2) {
      return Stack(
        children: [
          _buildTwoParticipantLayout(participants, constraints),
          _buildCallHeader(),
        ],
      );
    }

    if (count == 3) {
      return Stack(
        children: [
          _buildThreeParticipantLayout(participants, constraints),
          _buildCallHeader(),
        ],
      );
    }

    if (count == 4) {
      return Stack(
        children: [
          _buildFourParticipantLayout(participants, constraints),
          _buildCallHeader(),
        ],
      );
    }

    return Stack(
      children: [
        _buildGridParticipantView(participants, constraints),
        _buildCallHeader(),
      ],
    );
  }

  Widget _buildCallHeader() {
    return Positioned(
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
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(_Participant participant, BoxConstraints constraints) {
    final hasVideo = participant.renderer != null && _hasActiveVideo(participant.renderer!);

    return Positioned.fill(
      child: GestureDetector(
        onTap: participant.isLocal ? null : () => _onPeerTapped(participant.uid),
        child: hasVideo
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 320,
                  height: 240,
                  child: RTCVideoView(
                    participant.renderer!,
                    mirror: participant.isLocal,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              )
            : Container(
                color: const Color(0xFF2D1B69),
                child: Center(
                  child: _buildParticipantAvatar(uid: participant.uid, radius: 60),
                ),
              ),
      ),
    );
  }

  Widget _buildTwoParticipantLayout(List<_Participant> participants, BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _buildParticipantTileInContainer(participants[0]),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _buildParticipantTileInContainer(participants[1]),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeParticipantLayout(List<_Participant> participants, BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _buildParticipantTileInContainer(participants[0]),
          ),
        ),
        Expanded(
          flex: 1,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _buildParticipantTileInContainer(participants[1]),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _buildParticipantTileInContainer(participants[2]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFourParticipantLayout(List<_Participant> participants, BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _buildParticipantTileInContainer(participants[0]),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _buildParticipantTileInContainer(participants[1]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _buildParticipantTileInContainer(participants[2]),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _buildParticipantTileInContainer(participants[3]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantTileInContainer(_Participant participant) {
    final hasVideo = participant.renderer != null && _hasActiveVideo(participant.renderer!);

    return GestureDetector(
      onTap: participant.isLocal ? null : () => _onPeerTapped(participant.uid),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasVideo)
              RTCVideoView(
                participant.renderer!,
                mirror: participant.isLocal,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Container(
                color: const Color(0xFF2D1B69),
                child: Center(
                  child: _buildParticipantAvatar(uid: participant.uid, radius: 32),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasVideo ? Icons.videocam : Icons.videocam_off,
                      color: hasVideo ? Colors.green : Colors.white54,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getParticipantName(participant.uid),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridParticipantView(List<_Participant> participants, BoxConstraints constraints) {
    final count = participants.length;
    final crossAxisCount = count <= 4 ? 2 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return _buildParticipantTileInContainer(participants[index]);
      },
    );
  }

  Widget _buildFocusedPeerView(
      BoxConstraints constraints, List<MapEntry<String, RTCVideoRenderer>> entries) {
    final focusedEntry = entries.firstWhere(
      (e) => e.key == _focusedPeerId,
      orElse: () => entries.first,
    );
    final hasVideo = _hasActiveVideo(focusedEntry.value);

    final miniParticipants = <_Participant>[];
    final localRenderer = _callManager.localRenderer;
    if (localRenderer != null && localRenderer.srcObject != null) {
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      miniParticipants.add(_Participant(
        uid: myUid,
        renderer: localRenderer,
        isLocal: true,
      ));
    }
    for (final entry in entries) {
      if (entry.key != _focusedPeerId) {
        miniParticipants.add(_Participant(
          uid: entry.key,
          renderer: entry.value,
          isLocal: false,
        ));
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _onPeerTapped(focusedEntry.key),
            child: hasVideo
                ? FittedBox(
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
                  )
                : Container(
                    color: const Color(0xFF2D1B69),
                    child: Center(
                      child: _buildParticipantAvatar(
                        uid: focusedEntry.key,
                        radius: 60,
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
        _buildMiniStripFromParticipants(miniParticipants),
      ],
    );
  }

  Widget _buildMiniStripFromParticipants(List<_Participant> participants) {
    if (participants.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      right: 8,
      child: Column(
        children: participants.map((participant) {
          final hasVideo = participant.renderer != null && _hasActiveVideo(participant.renderer!);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: participant.isLocal ? null : () => _onPeerTapped(participant.uid),
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
                      if (hasVideo)
                        RTCVideoView(
                          participant.renderer!,
                          mirror: participant.isLocal,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      else
                        Container(
                          color: const Color(0xFF2D1B69),
                          child: Center(
                            child: _buildParticipantAvatar(
                              uid: participant.uid,
                              radius: 20,
                            ),
                          ),
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
                            participant.isLocal
                                ? 'You'
                                : _getParticipantName(participant.uid),
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
              if (widget.isGroup)
                _buildControlButton(
                  icon: Icons.exit_to_app,
                  label: 'Leave',
                  onTap: _leaveGroupCall,
                  isActive: true,
                  backgroundColor: Colors.orange.shade800,
                  iconColor: Colors.white,
                )
              else
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
          if (widget.isGroup)
            _buildControlButton(
              icon: Icons.exit_to_app,
              label: 'Leave',
              onTap: _leaveGroupCall,
              isActive: true,
              backgroundColor: Colors.orange.shade800,
              iconColor: Colors.white,
            )
          else
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
