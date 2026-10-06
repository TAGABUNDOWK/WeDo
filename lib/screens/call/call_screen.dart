import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/call.dart';
import '../../services/auth/user_service.dart';
import '../../services/call/call_manager.dart';
import '../../utils/safe_nav.dart';
import '../../utils/time_format.dart';
import '../chat/group/group_chat_screen.dart';

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
  String _lastCallSignature = '';
  final Set<RTCVideoRenderer> _attachedRenderers = {};

  bool _pinchTriggered = false;
  bool _showFlipFlash = false;

  @override
  void initState() {
    super.initState();
    _callManager.addListener(_onCallUpdate);
    _syncRendererListeners();
    _loadParticipantNames();
  }

  @override
  void dispose() {
    _callManager.removeListener(_onCallUpdate);
    for (final renderer in _attachedRenderers) {
      renderer.removeListener(_onRendererChanged);
    }
    _attachedRenderers.clear();
    super.dispose();
  }

  /// Remote/local renderers change size or render their first frame without
  /// CallManager ever knowing - listen to them directly so the avatar ->
  /// video switch does not wait for an unrelated notification.
  void _syncRendererListeners() {
    final wanted = <RTCVideoRenderer>{
      ..._callManager.remoteRenderers.values,
      if (_callManager.localRenderer != null) _callManager.localRenderer!,
    };
    for (final renderer in wanted) {
      if (_attachedRenderers.add(renderer)) {
        renderer.addListener(_onRendererChanged);
      }
    }
    final stale = _attachedRenderers.difference(wanted).toList();
    for (final renderer in stale) {
      _attachedRenderers.remove(renderer);
      renderer.removeListener(_onRendererChanged);
    }
  }

  void _onRendererChanged() {
    if (!mounted) return;
    safeNav(() {
      if (mounted) setState(() {});
    }, label: 'call renderer update');
  }

  /// Everything the call screen actually renders, so a stream of CallManager
  /// notifications (ICE, offers, answers, connection state...) does not
  /// rebuild a screen full of video textures for nothing.
  String _computeCallSignature() {
    final mgr = _callManager;
    final buffer = StringBuffer()
      ..write(mgr.activeCall?.callId ?? '')
      ..write('|${mgr.participantCount}')
      ..write('|${mgr.isMuted}|${mgr.isVideoOff}|${mgr.isSpeakerOn}')
      ..write('|${mgr.localRenderer?.srcObject != null}')
      ..write('|${mgr.remoteRenderers.keys.join(',')}');
    if (mgr.localRenderer != null) {
      buffer.write('|L${_hasActiveVideo(mgr.localRenderer!)}');
    }
    for (final entry in mgr.remoteRenderers.entries) {
      // Video-off is part of the signature: a peer toggling their camera
      // must repaint the tile from video back to avatar (or vice versa)
      // even when no frame event ever fires.
      buffer.write(
          '|${entry.key}:${_hasActiveVideo(entry.value)}:${mgr.isPeerVideoOff(entry.key)}');
    }
    return buffer.toString();
  }

  void _onCallUpdate() {
    if (!mounted) return;
    // CallManager can notify synchronously from another widget's initState,
    // i.e. during a build pass. Defer so setState/navigation never run there.
    safeNav(() {
      if (!mounted) return;
      if (_callManager.activeCall == null && !_isEndingCall) {
        _exitToChat();
        return;
      }
      _syncRendererListeners();
      final signature = _computeCallSignature();
      if (signature == _lastCallSignature) return;
      _lastCallSignature = signature;
      setState(() {});
    }, label: 'call update');
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
    await _hangUp(_callManager.endActiveCall);
  }

  Future<void> _leaveGroupCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;
    await _hangUp(_callManager.leaveGroupCall);
  }

  /// Runs a teardown with a hard deadline. CallManager has already cleared
  /// its local state synchronously, so if the remote Firestore writes stall
  /// (offline, dead network) we still leave the screen - an end button that
  /// hangs forever used to trap people on a black call they couldn't exit.
  Future<void> _hangUp(Future<void> Function() teardown) async {
    try {
      await teardown().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Call teardown did not finish cleanly: $e');
    }
    if (!mounted) return;
    try {
      _exitToChat();
    } catch (e) {
      debugPrint('Error leaving call screen: $e');
      // Navigation failed, so the latch must open again or the button dies.
      _isEndingCall = false;
    }
  }

  /// Ends the call screen and lands back on the originating group chat (or
  /// simply pops for direct calls). If the group chat is not in the stack
  /// (e.g. the call was opened from the overlay on the home screen), a fresh
  /// GroupChatScreen for this group is pushed instead.
  void _exitToChat() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final groupId = widget.isGroup ? widget.groupId : null;
    if (groupId == null || groupId.isEmpty) {
      nav.pop();
      return;
    }

    const prefix = '/group-chat/';
    var found = false;
    nav.popUntil((route) {
      final name = route.settings.name;
      if (name != null &&
          name.startsWith(prefix) &&
          name.substring(prefix.length) == groupId) {
        found = true;
        return true;
      }
      return route.isFirst;
    });
    if (!found) {
      nav.push(
        MaterialPageRoute(
          settings: RouteSettings(name: '$prefix$groupId'),
          builder: (_) => GroupChatScreen(groupId: groupId),
        ),
      );
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

  void _focusPeer(String peerId) {
    if (_focusedPeerId == peerId) return;
    setState(() {
      _focusedPeerId = peerId;
    });
  }

  void _clearFocus() {
    if (_focusedPeerId == null) return;
    setState(() {
      _focusedPeerId = null;
    });
  }

  Future<void> _loadParticipantNames() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final pending = <String>{
      if (myUid != null && !_participantNames.containsKey(myUid)) myUid,
      for (final uid in widget.members)
        if (!_participantNames.containsKey(uid)) uid,
    };
    if (pending.isEmpty) return;

    // All lookups at once - a sequential await per member made joining a
    // large group crawl one Firestore round trip at a time.
    final results = await Future.wait(pending.map((uid) async {
      var name = uid;
      String? photo;
      try {
        final user = await _userService.getUserDocument(uid);
        if (user != null) {
          name = user.displayName.isNotEmpty
              ? user.displayName
              : (user.username.isNotEmpty ? user.username : uid);
          if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
            photo = user.photoUrl!;
          } else if (user.avatarAsset != null &&
              user.avatarAsset!.isNotEmpty) {
            photo = 'asset:${user.avatarAsset!}';
          }
        }
      } catch (_) {}
      return (uid, name, photo);
    }));

    if (!mounted) return;
    setState(() {
      for (final (uid, name, photo) in results) {
        _participantNames[uid] = name;
        if (photo != null) _participantPhotos[uid] = photo;
      }
    });
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
    // No size event yet means no frame has arrived (e.g. a zombie renderer
    // left behind by a peer who never wrote a "left" status) — treat as video
    // off so the avatar+name fallback shows instead of a black texture.
    if (renderer.value.width <= 0 || renderer.value.height <= 0) return false;
    final videoTracks = stream.getVideoTracks();
    if (videoTracks.isEmpty) return false;
    return videoTracks.any((track) => track.enabled);
  }

  /// Whether the tile for remote peer [uid] should show live video. A peer
  /// muting their camera doesn't change anything on our side (their track
  /// keeps sending black frames), so their `videoOff` flag on the
  /// participant doc is what turns the black rectangle into their photo.
  bool _peerHasVideo(String uid) {
    if (_callManager.isPeerVideoOff(uid)) return false;
    final renderer = _callManager.remoteRenderers[uid];
    return renderer != null && _hasActiveVideo(renderer);
  }

  bool get _hasRemoteStream =>
      _callManager.remoteRenderers.values.any((r) => r.srcObject != null);

  bool get _hasLocalStream => _callManager.localRenderer?.srcObject != null;

  /// Whether the tile for [participant] shows video: local frames directly,
  /// remote frames only when their camera is actually on.
  bool _hasVideoFor(_Participant participant) {
    if (participant.isLocal) {
      final renderer = participant.renderer;
      return renderer != null && _hasActiveVideo(renderer);
    }
    return _peerHasVideo(participant.uid);
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
      _pipPosition = widget.isGroup
          ? Offset(16, constraints.maxHeight - 160 - 140)
          : Offset(constraints.maxWidth - 136, 16);
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
                  if (widget.isGroup) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: _focusedPeerId != null ? _flipCamera : null,
                      child: _buildGroupView(constraints),
                    ),
                    // With nobody else's video on screen the PiP would just
                    // duplicate the full-bleed self view - hide it until a
                    // remote renderer exists.
                    if (_hasLocalStream &&
                        _callManager.remoteRenderers.isNotEmpty)
                      _buildDraggablePip(constraints),
                  ] else ...[
                    _buildVideoBackground(),
                    if (_hasRemoteStream && _hasLocalStream)
                      _buildDraggablePip(constraints),
                  ],
                  if (!_hasRemoteStream) _buildWaitingOverlay(),
                  _buildFloatingHeader(),
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

  Widget _buildGroupView(BoxConstraints constraints) {
    final renderers = _callManager.remoteRenderers;

    // Drop stale focus (e.g. renderer disposed during a group reconnect).
    if (_focusedPeerId != null && !renderers.containsKey(_focusedPeerId)) {
      _focusedPeerId = null;
    }

    if (_focusedPeerId != null) {
      return _buildFocusedPeerView(constraints, renderers.entries.toList());
    }

    final participants = <_Participant>[];
    for (final entry in renderers.entries) {
      participants.add(_Participant(
        uid: entry.key,
        renderer: entry.value,
        isLocal: false,
      ));
    }

    switch (participants.length) {
      case 0:
        // Nobody's video is in yet (waiting to connect, or we're the last
        // one left). Show our own feed full screen instead of the bare
        // near-black scaffold, which read as a frozen/black screen; the
        // shared waiting overlay is rendered on top by build().
        return _buildAloneInCallView();
      case 1:
        return Stack(children: [
          _buildParticipantTile(participants[0], constraints),
        ]);
      case 2:
        return _buildTwoParticipantLayout(participants, constraints);
      case 3:
        return _buildThreeParticipantLayout(participants, constraints);
      case 4:
        return _buildFourParticipantLayout(participants, constraints);
      default:
        return _buildGridParticipantView(participants, constraints);
    }
  }

  /// Background while no remote video exists: our own mirrored camera when
  /// it is running, otherwise the call's background colour - never an empty
  /// (near-black) scaffold.
  Widget _buildAloneInCallView() {
    final local = _callManager.localRenderer;
    if (local != null && _hasActiveVideo(local)) {
      return Stack(children: [_buildFullBleedVideo(local, mirror: true)]);
    }
    return const ColoredBox(color: Color(0xFF2D1B69));
  }

  /// True when a group call has no one but us still in it.
  bool get _isAloneInGroupCall =>
      widget.isGroup && _callManager.participantCount <= 1;

  Widget _buildParticipantLabel(
    String text, {
    required bool hasVideo,
    double fontSize = 11,
  }) {
    return Container(
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
            text,
            style: TextStyle(color: Colors.white, fontSize: fontSize),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(
      _Participant participant, BoxConstraints constraints) {
    final hasVideo = _hasVideoFor(participant);
    final label = participant.isLocal
        ? 'You'
        : _getParticipantName(participant.uid);

    return Positioned.fill(
      child: GestureDetector(
        key: ValueKey(participant.uid),
        behavior: HitTestBehavior.opaque,
        onTap: participant.isLocal ? null : () => _focusPeer(participant.uid),
        child: Stack(
          fit: StackFit.expand,
          children: [
            hasVideo
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 320,
                      height: 240,
                      child: RTCVideoView(
                        participant.renderer!,
                        mirror: participant.isLocal,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFF2D1B69),
                    child: Center(
                      child: _buildParticipantAvatar(
                          uid: participant.uid, radius: 60),
                    ),
                  ),
            Positioned(
              left: 8,
              bottom: 96,
              child: _buildParticipantLabel(label,
                  hasVideo: hasVideo, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoParticipantLayout(
      List<_Participant> participants, BoxConstraints constraints) {
    return Column(
      children: [
        for (final participant in participants)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _buildParticipantTileInContainer(participant),
            ),
          ),
      ],
    );
  }

  Widget _buildThreeParticipantLayout(
      List<_Participant> participants, BoxConstraints constraints) {
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

  Widget _buildFourParticipantLayout(
      List<_Participant> participants, BoxConstraints constraints) {
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
    final hasVideo = _hasVideoFor(participant);
    final label = participant.isLocal
        ? 'You'
        : _getParticipantName(participant.uid);

    return GestureDetector(
      key: ValueKey(participant.uid),
      behavior: HitTestBehavior.opaque,
      onTap: participant.isLocal ? null : () => _focusPeer(participant.uid),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                      uid: participant.uid, radius: 32),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: _buildParticipantLabel(label, hasVideo: hasVideo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridParticipantView(
      List<_Participant> participants, BoxConstraints constraints) {
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
    final hasVideo = _peerHasVideo(focusedEntry.key);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _clearFocus,
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
          left: 8,
          bottom: 96,
          child: _buildParticipantLabel(
            _getParticipantName(focusedEntry.key),
            hasVideo: hasVideo,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoBackground() {
    final remote = _callManager.remoteRenderer;
    final local = _callManager.localRenderer;
    final remoteUid = remote != null && _callManager.remoteRenderers.isNotEmpty
        ? _callManager.remoteRenderers.keys.first
        : null;

    Widget feed;
    if (remoteUid != null && _peerHasVideo(remoteUid) && remote != null) {
      feed = Stack(
        fit: StackFit.expand,
        children: [
          _buildFullBleedVideo(remote, mirror: false),
          const ColoredBox(color: Color(0x8C000000)),
        ],
      );
    } else if (remoteUid != null) {
      // Peer's camera is off (or no frame yet): show their profile picture
      // and name. No dark scrim here — with it the avatar-only background
      // rendered as a near-black screen.
      feed = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildParticipantAvatar(uid: remoteUid, radius: 72),
            const SizedBox(height: 16),
            Text(
              _getParticipantName(remoteUid),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (local != null && _hasActiveVideo(local)) {
      // Pre-connect: only my own video is available.
      feed = Stack(
        fit: StackFit.expand,
        children: [
          _buildFullBleedVideo(local, mirror: true),
          const ColoredBox(color: Color(0x8C000000)),
        ],
      );
    } else {
      feed = const ColoredBox(color: Color(0xFF2D1B69));
    }

    return Positioned.fill(
      child: GestureDetector(
        onDoubleTap: _flipCamera,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        behavior: HitTestBehavior.opaque,
        child: feed,
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    final local = _callManager.localRenderer;
    final localShowsVideo = local != null && _hasActiveVideo(local);

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Our own face is already full screen - don't stamp an avatar
              // on top of it.
              if (!localShowsVideo) ...[
                _buildWaitingAvatar(radius: 38),
                const SizedBox(height: 16),
              ],
              Text(
                _isAloneInGroupCall
                    ? 'You\u2019re the only one in this call'
                    : 'Waiting for participants to connect...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingAvatar({required double radius}) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    String? shownUid;
    if (!widget.isGroup) {
      for (final uid in widget.members) {
        if (uid != myUid) {
          shownUid = uid;
          break;
        }
      }
    } else if (_isAloneInGroupCall) {
      // Alone in a group call: nobody else's picture to show but our own.
      shownUid = myUid;
    }

    if (shownUid != null && _participantPhotos.containsKey(shownUid)) {
      return _buildParticipantAvatar(uid: shownUid, radius: radius);
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
                    ValueListenableBuilder<int>(
                      valueListenable: _callManager.callDurationListenable,
                      builder: (context, value, _) => Text(
                        widget.isGroup && _callManager.participantCount > 0
                            ? '${formatSeconds(value)} \u2022 ${_callManager.participantCount} in call'
                            : formatSeconds(value),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
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
          ValueListenableBuilder<int>(
            valueListenable: _callManager.callDurationListenable,
            builder: (context, value, _) => Text(
              formatSeconds(value),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          if (widget.isGroup) ...[
            const SizedBox(height: 8),
            Text(
              _callManager.participantCount > 0
                  ? '${_callManager.participantCount} participants'
                  : 'Waiting for other participants to join...',
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                        ? 'assets/icons/mic-off.png'
                        : 'assets/icons/mic-on.png',
                    fallbackIcon:
                        _callManager.isMuted ? Icons.mic_off : Icons.mic,
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
        child: button,
      ),
    );
  }
}
