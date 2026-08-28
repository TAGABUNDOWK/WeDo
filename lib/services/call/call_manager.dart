import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../main.dart' show navigatorKey;
import '../../models/call.dart';
import '../../screens/call/call_screen.dart';
import '../../screens/call/outgoing_call_screen.dart';
import '../../utils/time_format.dart';
import '../direct/direct_service.dart';
import '../group/group_service.dart';
import 'call_service.dart';
import 'webrtc_service.dart' as webrtc;

class ActiveCallData {
  final String callId;
  final String callName;
  final CallType callType;
  final List<String> members;
  final String createdBy;
  final bool isGroup;
  final String? chatId;
  final String? groupId;
  final DateTime startedAt;

  const ActiveCallData({
    required this.callId,
    required this.callName,
    required this.callType,
    required this.members,
    required this.createdBy,
    required this.isGroup,
    this.chatId,
    this.groupId,
    required this.startedAt,
  });
}

class CallManager extends ChangeNotifier {
  static final CallManager _instance = CallManager._();
  factory CallManager() => _instance;
  CallManager._();

  final CallService _callService = CallService();
  webrtc.WebRTCService? _webrtcService;
  ActiveCallData? _activeCall;
  ActiveCallData? _outgoingCall;
  StreamSubscription? _callSub;
  StreamSubscription? _outgoingCallSub;
  StreamSubscription? _signalsSub;
  StreamSubscription? _groupCallSub;
  Timer? _groupCallDebounce;
  Timer? _callTimer;
  Timer? _reconnectTimer;
  int _callDuration = 0;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;
  final Set<String> _processedSignals = {};
  final Set<String> _pendingOfferPeers = {};
  final _currentUser = FirebaseAuth.instance.currentUser;

  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  ActiveCallData? get activeCall => _activeCall;
  ActiveCallData? get outgoingCall => _outgoingCall;
  bool get hasActiveCall => _activeCall != null;
  bool get hasOutgoingCall => _outgoingCall != null;
  webrtc.WebRTCService? get webrtcService => _webrtcService;
  int get callDuration => _callDuration;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;

  StreamController<MediaStream>? _localStreamController;
  StreamController<MediaStream>? _remoteStreamController;
  OverlayEntry? _callOverlay;

  Stream<MediaStream>? get onLocalStream => _localStreamController?.stream;
  Stream<MediaStream>? get onRemoteStream => _remoteStreamController?.stream;

  bool get hasAnyCall => _activeCall != null || _outgoingCall != null;

  void trackOutgoingCall({
    required String callId,
    required String callName,
    required CallType callType,
    required List<String> members,
    required String createdBy,
    required bool isGroup,
    String? chatId,
    String? groupId,
  }) {
    _outgoingCall = ActiveCallData(
      callId: callId,
      callName: callName,
      callType: callType,
      members: members,
      createdBy: createdBy,
      isGroup: isGroup,
      chatId: chatId,
      groupId: groupId,
      startedAt: DateTime.now(),
    );
    notifyListeners();

    _outgoingCallSub?.cancel();
    _outgoingCallSub = _callService.getCallStream(callId).listen((call) async {
      if (call == null || call.status == CallStatus.ended) {
        final outgoing = _outgoingCall;
        cancelOutgoingCall();
        if (outgoing != null) {
          _sendMissedCallMessageForCall(outgoing);
        }
      } else if (call.status == CallStatus.active) {
        final outgoing = _outgoingCall;
        if (outgoing != null) {
          cancelOutgoingCall();
          await startNewCall(
            callData: ActiveCallData(
              callId: outgoing.callId,
              callName: outgoing.callName,
              callType: outgoing.callType,
              members: outgoing.members,
              createdBy: outgoing.createdBy,
              isGroup: outgoing.isGroup,
              chatId: outgoing.chatId,
              groupId: outgoing.groupId,
              startedAt: DateTime.now(),
            ),
            audioOnly: outgoing.callType == CallType.audio,
          );

          navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(
              builder: (_) => CallScreen(
                callId: outgoing.callId,
                callName: outgoing.callName,
                callType: outgoing.callType,
                members: outgoing.members,
                createdBy: outgoing.createdBy,
                isGroup: outgoing.isGroup,
                chatId: outgoing.chatId,
                groupId: outgoing.groupId,
              ),
            ),
          );
        }
      }
    });
  }

  void cancelOutgoingCall() {
    _outgoingCallSub?.cancel();
    _outgoingCallSub = null;
    _outgoingCall = null;
    removeCallOverlay();
    notifyListeners();
  }

  Future<void> _sendMissedCallMessageForCall(ActiveCallData call) async {
    final user = _currentUser;
    if (user == null) return;

    final callTypeStr = call.callType == CallType.video ? 'video' : 'audio';
    final senderName = user.displayName ?? user.email ?? 'Unknown';

    if (call.isGroup && call.groupId != null) {
      await GroupService().sendCallMessage(
        groupId: call.groupId!,
        senderId: user.uid,
        senderName: senderName,
        callType: callTypeStr,
        callStatus: 'missed',
        durationSeconds: 0,
      );
    } else if (call.chatId != null) {
      await DirectService().sendCallMessage(
        chatId: call.chatId!,
        senderId: user.uid,
        senderName: senderName,
        callType: callTypeStr,
        callStatus: 'missed',
        durationSeconds: 0,
      );
    }
  }

  void showCallOverlay() {
    if (_callOverlay != null) return;
    if (_activeCall == null && _outgoingCall == null) return;
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _callOverlay = OverlayEntry(
      builder: (_) => _CallOverlayBanner(
        onReturnToCall: _returnToCallFromOverlay,
        onEndCall: _activeCall != null ? endActiveCall : _cancelOutgoingFromOverlay,
      ),
    );
    overlay.insert(_callOverlay!);
  }

  void removeCallOverlay() {
    _callOverlay?.remove();
    _callOverlay = null;
  }

  void _returnToCallFromOverlay() {
    final active = _activeCall;
    final outgoing = _outgoingCall;

    removeCallOverlay();

    if (active != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: active.callId,
            callName: active.callName,
            callType: active.callType,
            members: active.members,
            createdBy: active.createdBy,
            isGroup: active.isGroup,
            chatId: active.chatId,
            groupId: active.groupId,
          ),
        ),
      );
    } else if (outgoing != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => OutgoingCallScreen(
            call: Call(
              id: outgoing.callId,
              type: outgoing.callType,
              status: CallStatus.ringing,
              createdBy: outgoing.createdBy,
              members: outgoing.members,
              createdAt: outgoing.startedAt,
              chatId: outgoing.chatId,
              groupId: outgoing.groupId,
            ),
            callName: outgoing.callName,
          ),
        ),
      );
    }
  }

  void _cancelOutgoingFromOverlay() {
    final outgoing = _outgoingCall;
    if (outgoing != null) {
      _callService.endCall(outgoing.callId);
    }
    cancelOutgoingCall();
  }

  Future<void> startNewCall({
    required ActiveCallData callData,
    bool audioOnly = false,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    if (_activeCall != null) {
      await endActiveCall();
    }

    _activeCall = callData;
    _callDuration = 0;
    _isMuted = false;
    _isVideoOff = false;
    _isSpeakerOn = audioOnly;
    _processedSignals.clear();
    _pendingOfferPeers.clear();

    _webrtcService = webrtc.WebRTCService();
    _localStreamController = StreamController<MediaStream>.broadcast();
    _remoteStreamController = StreamController<MediaStream>.broadcast();

    await _webrtcService!.initialize(audioOnly: audioOnly);

    if (_isSpeakerOn) {
      await _webrtcService!.setSpeakerOn(true);
    }

    _localRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();

    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();

    _webrtcService!.onLocalStream.listen((stream) {
      _localStreamController?.add(stream);
      _localRenderer?.srcObject = stream;
      notifyListeners();
    });

    _webrtcService!.onRemoteStream.listen((stream) {
      _remoteStreamController?.add(stream);
      _remoteRenderer?.srcObject = stream;
      notifyListeners();
    });

    _webrtcService!.onIceCandidateGenerated = (peerId, candidateJson) {
      _callService.sendIceCandidate(
        callId: callData.callId,
        fromUid: user.uid,
        toUid: peerId,
        candidate: candidateJson,
      );
    };

    _webrtcService!.onConnectionStateChanged = (peerId, state) {
      debugPrint('Connection state with $peerId: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        return;
      }

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (!callData.isGroup && _reconnectTimer == null) {
          _reconnectTimer = Timer(const Duration(seconds: 5), () {
            _reconnectTimer = null;
            endActiveCall();
          });
        }
      }
    };

    await _callService.joinCall(callData.callId, user.uid);

    _callSub = _callService.getCallStream(callData.callId).listen((call) {
      if (call == null || call.status == CallStatus.ended) {
        endActiveCall();
      }
    });

    _signalsSub = _callService
        .getSignalsForUser(callData.callId, user.uid)
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        if (_processedSignals.contains(doc.id)) continue;
        _processedSignals.add(doc.id);

        final data = doc.data();
        final fromUid = data['fromUid'] as String?;
        final type = data['type'] as String?;
        if (fromUid == null || type == null) continue;

        try {
          if (type == 'offer') {
            final sdp = data['sdp'] as String?;
            if (sdp == null) continue;
            _webrtcService!.handleOffer(
              callId: callData.callId,
              fromUid: fromUid,
              toUid: user.uid,
              sdpJson: sdp,
            );
          } else if (type == 'answer') {
            final sdp = data['sdp'] as String?;
            if (sdp == null) continue;
            _webrtcService!.handleAnswer(
              fromUid: fromUid,
              toUid: user.uid,
              sdpJson: sdp,
            );
          } else if (type == 'candidate') {
            final candidateJson = data['candidate'] as String?;
            if (candidateJson == null) continue;
            _webrtcService!.handleIceCandidate(
              fromUid: fromUid,
              toUid: user.uid,
              candidateJson: candidateJson,
            );
          }
        } catch (e) {
          debugPrint('Error handling signal $type: $e');
        }
      }
    });

    if (callData.isGroup) {
      _groupCallSub =
          _callService.getCallStream(callData.callId).listen((call) {
        if (call == null || call.status != CallStatus.active) return;
        _groupCallDebounce?.cancel();
        _groupCallDebounce = Timer(const Duration(milliseconds: 500), () {
          _createGroupOffers();
        });
      });
    }

    if (callData.createdBy == user.uid && !callData.isGroup) {
      for (final memberUid in callData.members) {
        if (memberUid != user.uid) {
          await _webrtcService!.createOffer(
            callId: callData.callId,
            fromUid: user.uid,
            toUid: memberUid,
          );
        }
      }
    }

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      notifyListeners();
    });

    WakelockPlus.enable();
    notifyListeners();
  }

  void _createGroupOffers() {
    final user = _currentUser;
    if (user == null || _activeCall == null) return;
    final uid = user.uid;
    for (final memberUid in _activeCall!.members) {
      if (memberUid == uid) continue;
      if (_pendingOfferPeers.contains(memberUid)) continue;

      final key = webrtc.WebRTCService.pcKeyForTest(uid, memberUid);
      if (_webrtcService!.peerConnections.containsKey(key)) continue;

      _pendingOfferPeers.add(memberUid);
      _webrtcService!
          .createOffer(
        callId: _activeCall!.callId,
        fromUid: uid,
        toUid: memberUid,
      )
          .then((_) {
        _pendingOfferPeers.remove(memberUid);
      }).catchError((_) {
        _pendingOfferPeers.remove(memberUid);
      });
    }
  }

  Future<void> _sendCallMessage() async {
    final user = _currentUser;
    if (user == null || _activeCall == null) return;

    final uid = user.uid;
    final userName = user.displayName ?? user.email ?? 'Unknown';
    final callTypeStr =
        _activeCall!.callType == CallType.video ? 'video' : 'audio';
    final duration = _callDuration;

    if (_activeCall!.isGroup && _activeCall!.groupId != null) {
      await GroupService().sendCallMessage(
        groupId: _activeCall!.groupId!,
        senderId: uid,
        senderName: userName,
        callType: callTypeStr,
        callStatus: 'active',
        durationSeconds: duration,
      );
    } else if (_activeCall!.chatId != null) {
      await DirectService().sendCallMessage(
        chatId: _activeCall!.chatId!,
        senderId: uid,
        senderName: userName,
        callType: callTypeStr,
        callStatus: 'active',
        durationSeconds: duration,
      );
    }
  }

  Future<void> endActiveCall() async {
    if (_activeCall == null) return;

    removeCallOverlay();

    final callId = _activeCall!.callId;

    _callTimer?.cancel();
    _callSub?.cancel();
    _signalsSub?.cancel();
    _groupCallSub?.cancel();
    _groupCallDebounce?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _sendCallMessage();

    final uid = _currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _callService.leaveCall(callId, uid);
      } catch (e) {
        debugPrint('Error leaving call: $e');
      }
    } else {
      try {
        await _callService.endCall(callId);
      } catch (e) {
        debugPrint('Error ending call: $e');
      }
    }

    if (_webrtcService != null) {
      await _webrtcService!.dispose();
      _webrtcService = null;
    }

    _localStreamController?.close();
    _remoteStreamController?.close();
    _localStreamController = null;
    _remoteStreamController = null;

    _localRenderer?.srcObject = null;
    _remoteRenderer?.srcObject = null;
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    _localRenderer = null;
    _remoteRenderer = null;

    _activeCall = null;
    _callDuration = 0;
    _processedSignals.clear();
    _pendingOfferPeers.clear();

    WakelockPlus.disable();
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _callService.cleanupCallData(callId);
    });
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _webrtcService?.toggleAudio();
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoOff = !_isVideoOff;
    _webrtcService?.toggleVideo();
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _webrtcService?.setSpeakerOn(_isSpeakerOn);
    notifyListeners();
  }

  void switchCamera() {
    _webrtcService?.switchCamera();
  }
}

class _CallOverlayBanner extends StatefulWidget {
  final VoidCallback onReturnToCall;
  final VoidCallback onEndCall;

  const _CallOverlayBanner({
    required this.onReturnToCall,
    required this.onEndCall,
  });

  @override
  State<_CallOverlayBanner> createState() => _CallOverlayBannerState();
}

class _CallOverlayBannerState extends State<_CallOverlayBanner> {
  final _callManager = CallManager();

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
    if (mounted) setState(() {});
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFFFE4EF0).withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFFFE4EF0),
          size: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCall = _callManager.activeCall;
    final outgoingCall = _callManager.outgoingCall;
    if (activeCall == null && outgoingCall == null) return const SizedBox.shrink();

    final call = activeCall ?? outgoingCall!;
    final isActive = activeCall != null;
    final isVideo = call.callType == CallType.video;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: widget.onReturnToCall,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [const Color(0xFF2D1B69), const Color(0xFF1A0A2E)]
                    : [const Color(0xFF1A0A2E), const Color(0xFF2D1B69)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    isVideo ? Icons.videocam : Icons.call,
                    color: const Color(0xFFFE4EF0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        call.callName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isActive
                                ? formatSeconds(_callManager.callDuration)
                                : 'Ringing...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isActive) ...[
                  _buildControlButton(
                    icon: _callManager.isMuted ? Icons.mic_off : Icons.mic,
                    isActive: !_callManager.isMuted,
                    onTap: () => _callManager.toggleMute(),
                  ),
                  const SizedBox(width: 6),
                  if (isVideo) ...[
                    _buildControlButton(
                      icon: _callManager.isVideoOff
                          ? Icons.videocam_off
                          : Icons.videocam,
                      isActive: !_callManager.isVideoOff,
                      onTap: () => _callManager.toggleVideo(),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _buildControlButton(
                    icon: _callManager.isSpeakerOn
                        ? Icons.volume_up
                        : Icons.volume_down,
                    isActive: true,
                    onTap: () => _callManager.toggleSpeaker(),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: widget.onEndCall,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onReturnToCall,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 16,
                    ),
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
