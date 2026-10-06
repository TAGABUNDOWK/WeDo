import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../main.dart' show navigatorKey;
import '../../models/call.dart';
import '../../screens/call/call_screen.dart';
import '../../screens/call/outgoing_call_screen.dart';
import '../../utils/safe_nav.dart';
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
  MediaStream? _outgoingLocalStream;
  StreamSubscription? _signalsSub;
  StreamSubscription? _participantsSub;
  StreamSubscription? _webrtcLocalStreamSub;
  StreamSubscription? _webrtcRemoteStreamSub;
  Timer? _groupCallDebounce;
  Timer? _callTimer;
  Timer? _heartbeatTimer;
  Timer? _outgoingRingTimeout;
  int _callDuration = 0;
  final ValueNotifier<int> _durationNotifier = ValueNotifier<int>(0);
  ValueListenable<int> get callDurationListenable => _durationNotifier;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;
  final Map<String, String> _processedSignals = {};
  final Set<String> _pendingOfferPeers = {};
  final Set<String> _outgoingOfferPeers = {};
  final Map<String, DateTime> _noPcSince = {};
  final Set<String> _departedPeers = {};
  final Map<String, Timer> _reconnectTimers = {};
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isTransitioningToActive = false;
  bool _isRejoining = false;
  bool _outgoingScreenVisible = false;
  int _participantCount = 0;
  final Map<String, bool> _peerVideoOff = {};
  ActiveCallData? _leftCall;
  StreamSubscription? _leftWatchCallSub;
  StreamSubscription? _leftWatchParticipantsSub;

  RTCVideoRenderer? _localRenderer;
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Set<String> _rendererReady = {};
  final Map<String, MediaStream> _pendingRemoteStreams = {};
  final Set<String> _reconnectingPeers = {};

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
  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;
  RTCVideoRenderer? get remoteRenderer =>
      _remoteRenderers.isNotEmpty ? _remoteRenderers.values.first : null;
  int get remoteParticipantCount => _remoteRenderers.length;

  /// True when [uid]'s camera is off - peers publish this on their
  /// participant doc, because a receiver cannot detect the sender muting
  /// its video track (the local `track.enabled` check would keep showing
  /// the black texture instead of the profile picture).
  bool isPeerVideoOff(String uid) => _peerVideoOff[uid] ?? false;

  /// Participants Firestore currently reports as `active` in the call this
  /// device is in (or is waiting to rejoin). 0 when there is no such call.
  int get participantCount => _participantCount;
  bool get isTransitioningToActive => _isTransitioningToActive;

  StreamController<MediaStream>? _localStreamController;
  StreamController<MediaStream>? _remoteStreamController;
  OverlayEntry? _callOverlay;

  Stream<MediaStream>? get onLocalStream => _localStreamController?.stream;
  Stream<MediaStream>? get onRemoteStream => _remoteStreamController?.stream;

  bool get hasAnyCall => _activeCall != null || _outgoingCall != null;
  bool get hasLeftCall => _leftCall != null;
  String? get leftCallId => _leftCall?.callId;
  ActiveCallData? get leftCall => _leftCall;

  void setOutgoingLocalStream(MediaStream? stream) {
    _outgoingLocalStream = stream;
  }

  void _startHeartbeat(String callId, String uid) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        await _callService
            .touchParticipant(callId, uid)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Call heartbeat failed: $e');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

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

    _outgoingRingTimeout?.cancel();
    _outgoingRingTimeout = Timer(const Duration(seconds: 45), () {
      if (_outgoingCall != null && _outgoingCall!.callId == callId) {
        cancelOutgoingCall();
      }
    });

    _outgoingCallSub?.cancel();
    _outgoingCallSub = _callService.getCallStream(callId).listen((call) async {
      if (call == null ||
          call.status == CallStatus.ended ||
          call.status == CallStatus.declined ||
          call.status == CallStatus.missed ||
          call.status == CallStatus.cancelled) {
        final outgoing = _outgoingCall;
        if (outgoing != null) {
          _outgoingCallSub?.cancel();
          _outgoingCallSub = null;
          _outgoingRingTimeout?.cancel();
          _outgoingRingTimeout = null;
          if (_activeCall == null) {
            _outgoingLocalStream?.getTracks().forEach((t) => t.stop());
          }
          _outgoingLocalStream = null;
          _outgoingCall = null;
          removeCallOverlay();
          notifyListeners();
          try {
            await _sendMissedCallMessageForCall(outgoing);
          } catch (e) {
            debugPrint('Error sending missed call message: $e');
          }
        }
      } else if (call.status == CallStatus.active) {
        final outgoing = _outgoingCall;
        if (outgoing != null && !_isTransitioningToActive) {
          _isTransitioningToActive = true;
          _outgoingCallSub?.cancel();
          _outgoingCallSub = null;
          _outgoingRingTimeout?.cancel();
          _outgoingRingTimeout = null;
          // The preview stream is camera-only and is not handed to WebRTC
          // (it has no mic track), so stop it here - otherwise the native
          // camera stays lit for the rest of the call.
          _outgoingLocalStream?.getTracks().forEach((t) => t.stop());
          _outgoingLocalStream = null;
          _outgoingCall = null;
          removeCallOverlay();
          notifyListeners();

          final newCallData = ActiveCallData(
            callId: outgoing.callId,
            callName: outgoing.callName,
            callType: outgoing.callType,
            members: outgoing.members,
            createdBy: outgoing.createdBy,
            isGroup: outgoing.isGroup,
            chatId: outgoing.chatId,
            groupId: outgoing.groupId,
            startedAt: DateTime.now(),
          );

          try {
            await startNewCall(
              callData: newCallData,
              audioOnly: outgoing.callType == CallType.audio,
            );

            // Only swap the outgoing screen for the call screen when that
            // screen is actually the one on top - otherwise a replace would
            // destroy the chat route underneath the minimized overlay.
            if (_outgoingScreenVisible) {
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
          } finally {
            _isTransitioningToActive = false;
          }
        }
      }
    });
  }

  /// Toggled by [OutgoingCallScreen] so the transition above knows whether
  /// it is safe to replace the top route.
  void setOutgoingScreenVisible(bool visible) {
    _outgoingScreenVisible = visible;
  }

  void cancelOutgoingCall() {
    if (_isTransitioningToActive) return;
    final outgoing = _outgoingCall;
    _outgoingCallSub?.cancel();
    _outgoingCallSub = null;
    _outgoingRingTimeout?.cancel();
    _outgoingRingTimeout = null;
    if (_activeCall == null) {
      _outgoingLocalStream?.getTracks().forEach((t) => t.stop());
    }
    _outgoingLocalStream = null;
    _outgoingCall = null;
    removeCallOverlay();
    notifyListeners();
    if (outgoing != null) {
      // Without this the callee keeps ringing until the scheduled timeout.
      _callService.endCall(outgoing.callId).catchError((Object e) {
        debugPrint('Error ending cancelled call: $e');
      });
    }
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
        onReturnToCall: returnToCall,
        // Hanging up a group call only removes you from it; the call dies
        // by itself once the last participant leaves.
        onEndCall: _activeCall == null
            ? _cancelOutgoingFromOverlay
            : (_activeCall!.isGroup ? leaveGroupCall : endActiveCall),
      ),
    );
    overlay.insert(_callOverlay!);
  }

  void removeCallOverlay() {
    _callOverlay?.remove();
    _callOverlay = null;
  }

  void returnToCall() {
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
    cancelOutgoingCall();
  }

  Future<void> startNewCall({
    required ActiveCallData callData,
    bool audioOnly = false,
  }) async {
    try {
      await _startNewCallInternal(callData: callData, audioOnly: audioOnly);
    } catch (e) {
      debugPrint('Error starting call: $e');
      if (_activeCall != null && _activeCall!.callId == callData.callId) {
        _abortCallStart();
      }
      rethrow;
    }
  }

  /// Local-only teardown for a [startNewCall] that failed half way through,
  /// so the app never believes it is in a call that never came up.
  void _abortCallStart() {
    _callTimer?.cancel();
    _callTimer = null;
    _stopHeartbeat();
    _callSub?.cancel();
    _callSub = null;
    _signalsSub?.cancel();
    _signalsSub = null;
    _participantsSub?.cancel();
    _participantsSub = null;
    _webrtcLocalStreamSub?.cancel();
    _webrtcLocalStreamSub = null;
    _webrtcRemoteStreamSub?.cancel();
    _webrtcRemoteStreamSub = null;
    _groupCallDebounce?.cancel();
    for (final t in _reconnectTimers.values) {
      t.cancel();
    }
    _reconnectTimers.clear();
    _reconnectingPeers.clear();
    _pendingOfferPeers.clear();
    _outgoingOfferPeers.clear();
    _noPcSince.clear();
    _departedPeers.clear();
    _processedSignals.clear();
    _activeCall = null;
    _participantCount = 0;
    _peerVideoOff.clear();
    _callDuration = 0;
    _durationNotifier.value = 0;
    WakelockPlus.disable();
    removeCallOverlay();

    final oldWebrtc = _webrtcService;
    final oldLocalCtrl = _localStreamController;
    final oldRemoteCtrl = _remoteStreamController;
    final oldLocalRenderer = _localRenderer;
    final oldRemoteRenderers =
        Map<String, RTCVideoRenderer>.from(_remoteRenderers);
    _webrtcService = null;
    _localStreamController = null;
    _remoteStreamController = null;
    _localRenderer = null;
    _remoteRenderers.clear();
    _rendererReady.clear();
    _pendingRemoteStreams.clear();

    notifyListeners();

    Future.microtask(() async {
      await oldWebrtc?.dispose();
      await oldLocalCtrl?.close();
      await oldRemoteCtrl?.close();
      oldLocalRenderer?.srcObject = null;
      await oldLocalRenderer?.dispose();
      for (final renderer in oldRemoteRenderers.values) {
        renderer.srcObject = null;
        await renderer.dispose();
      }
    });
  }

  Future<void> _startNewCallInternal({
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
    _durationNotifier.value = 0;
    _isMuted = false;
    _isVideoOff = false;
    _isSpeakerOn = !audioOnly;
    _processedSignals.clear();
    _pendingOfferPeers.clear();
    _outgoingOfferPeers.clear();
    _noPcSince.clear();
    _departedPeers.clear();
    _leftCall = null;
    _stopLeftCallWatch();
    _participantCount = 0;
    _peerVideoOff.clear();

    _webrtcService = webrtc.WebRTCService();
    _localStreamController = StreamController<MediaStream>.broadcast();
    _remoteStreamController = StreamController<MediaStream>.broadcast();

    _webrtcService!.onWarning = (message) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    await _webrtcService!.initialize(
      audioOnly: audioOnly,
      existingStream: _outgoingLocalStream,
    );
    _outgoingLocalStream = null;

    await _webrtcService!.setSpeakerOn(_isSpeakerOn);

    _localRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();

    if (_webrtcService!.localStream != null) {
      _webrtcService!.setAudioEnabled(!_isMuted);
      _webrtcService!.setVideoEnabled(!_isVideoOff);
      _localRenderer!.srcObject = _webrtcService!.localStream;
      _localStreamController?.add(_webrtcService!.localStream!);
      notifyListeners();
    }

    _webrtcLocalStreamSub = _webrtcService!.onLocalStream.listen((stream) {
      _localStreamController?.add(stream);
      _localRenderer?.srcObject = stream;
      _webrtcService?.setAudioEnabled(!_isMuted);
      _webrtcService?.setVideoEnabled(!_isVideoOff);
      notifyListeners();
    });

    _webrtcRemoteStreamSub =
        _webrtcService!.onRemoteStream.listen((pair) {
      final (peerId, stream) = pair;
      _remoteStreamController?.add(stream);

      final existing = _remoteRenderers[peerId];
      if (existing == null) {
        final renderer = RTCVideoRenderer();
        _remoteRenderers[peerId] = renderer;
        _pendingRemoteStreams[peerId] = stream;
        renderer.initialize().then((_) {
          if (!identical(_remoteRenderers[peerId], renderer)) {
            try {
              renderer.dispose();
            } catch (_) {}
            return;
          }
          _rendererReady.add(peerId);
          final pending = _pendingRemoteStreams.remove(peerId);
          renderer.srcObject = pending ?? stream;
          notifyListeners();
        }).catchError((Object e) {
          debugPrint('Error initializing remote renderer: $e');
          _pendingRemoteStreams.remove(peerId);
          if (identical(_remoteRenderers[peerId], renderer)) {
            _remoteRenderers.remove(peerId);
            _rendererReady.remove(peerId);
          }
          try {
            renderer.dispose();
          } catch (_) {}
          notifyListeners();
        });
      } else if (_rendererReady.contains(peerId)) {
        existing.srcObject = stream;
        notifyListeners();
      } else {
        // Renderer is still initializing; assign once ready.
        _pendingRemoteStreams[peerId] = stream;
      }
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
        _reconnectTimers[peerId]?.cancel();
        _reconnectTimers.remove(peerId);
        _reconnectTimers['single']?.cancel();
        _reconnectTimers.remove('single');
        _reconnectTimers['offer_$peerId']?.cancel();
        _reconnectTimers.remove('offer_$peerId');
        _reconnectingPeers.remove(peerId);
        _outgoingOfferPeers.remove(peerId);
        _noPcSince.remove(peerId);
        return;
      }

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _purgeSignalsForPeer(peerId);
        _noPcSince.putIfAbsent(peerId, () => DateTime.now());
        if (callData.isGroup && !_reconnectingPeers.contains(peerId)) {
          _disposeRemoteRenderer(peerId);
          notifyListeners();

          _reconnectingPeers.add(peerId);
          _pendingOfferPeers.remove(peerId);
          _reconnectTimers[peerId]?.cancel();
          _reconnectTimers[peerId] = Timer(const Duration(seconds: 3), () {
            _reconnectTimers.remove(peerId);
            _reconnectingPeers.remove(peerId);
            if (_activeCall != null &&
                callData.isGroup &&
                !_departedPeers.contains(peerId)) {
              final key = webrtc.WebRTCService.pcKeyForTest(_currentUser?.uid ?? '', peerId);
              _webrtcService?.peerConnections.remove(key)?.close();
              _pendingOfferPeers.remove(peerId);
              _outgoingOfferPeers.remove(peerId);
              _createGroupOfferTo(peerId);
            }
          });
        } else if (!callData.isGroup) {
          _disposeRemoteRenderer(peerId);
          notifyListeners();

          if (_reconnectTimers.isEmpty) {
            _reconnectTimers['single'] = Timer(const Duration(seconds: 5), () {
              _reconnectTimers.remove('single');
              endActiveCall();
            });
          }
        }
      }
    };

    await _callService.joinCall(callData.callId, user.uid);
    _startHeartbeat(callData.callId, user.uid);
    if (audioOnly) {
      // No camera track at all on an audio call - tell peers right away so
      // they never wait for video that cannot arrive.
      unawaited(_publishVideoState(callData.callId, user.uid, videoOff: true));
    }

    _callSub = _callService.getCallStream(callData.callId).listen((call) {
      if (call == null ||
          call.status == CallStatus.ended ||
          call.status == CallStatus.declined ||
          call.status == CallStatus.missed ||
          call.status == CallStatus.cancelled) {
        endActiveCall();
      } else if (call.status == CallStatus.active && callData.isGroup) {
        _groupCallDebounce?.cancel();
        _groupCallDebounce = Timer(const Duration(milliseconds: 300), () {
          _createGroupOffers();
        });
      }
    });

    _signalsSub = _callService
        .getSignalsForUser(callData.callId, user.uid)
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fromUid = data['fromUid'] as String?;
        final type = data['type'] as String?;
        if (fromUid == null || type == null) continue;

        final signature = _signalSignature(data);
        if (_processedSignals[doc.id] == signature) continue;
        _processedSignals[doc.id] = signature;

        try {
          if (type == 'offer') {
            final sdp = data['sdp'] as String?;
            if (sdp == null) continue;
            if (callData.isGroup && !_resolveOfferGlare(user.uid, fromUid)) {
              continue;
            }
            _webrtcService!.handleOffer(
              callId: callData.callId,
              fromUid: fromUid,
              toUid: user.uid,
              sdpJson: sdp,
            );
          } else if (type == 'answer') {
            final sdp = data['sdp'] as String?;
            if (sdp == null) continue;
            _outgoingOfferPeers.remove(fromUid);
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

    _participantsSub =
        _callService.getParticipantsStream(callData.callId).listen((snapshot) {
      final docs = snapshot.docs.map((doc) => doc.data()).toList();
      _updateParticipantCount(docs);
      _applyVideoOffStates(docs, user.uid);

      if (!callData.isGroup) return;
      for (final data in docs) {
        final uid = data['uid'] as String?;
        if (uid == null || uid == user.uid) continue;
        // Stale heartbeats count as gone: a peer whose app crashed leaves an
        // 'active' doc behind, and offering to it (or keeping its zombie
        // renderer) would strand the call in a black screen forever.
        if (CallService.isLiveParticipant(data)) {
          _departedPeers.remove(uid);
          if (!_pendingOfferPeers.contains(uid) &&
              !_reconnectingPeers.contains(uid)) {
            _createGroupOfferTo(uid);
          }
        } else {
          _departedPeers.add(uid);
          _purgeSignalsForPeer(uid);
          _reconnectTimers[uid]?.cancel();
          _reconnectTimers.remove(uid);
          _reconnectTimers['offer_$uid']?.cancel();
          _reconnectTimers.remove('offer_$uid');
          _reconnectingPeers.remove(uid);
          _pendingOfferPeers.remove(uid);
          _outgoingOfferPeers.remove(uid);
          _noPcSince.remove(uid);
          final key = webrtc.WebRTCService.pcKeyForTest(user.uid, uid);
          _webrtcService?.peerConnections.remove(key)?.close();
          _disposeRemoteRenderer(uid);
          notifyListeners();
        }
      }
    });

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
      _durationNotifier.value = _callDuration;
    });

    WakelockPlus.enable();
    notifyListeners();
  }

  void _purgeSignalsForPeer(String peerId) {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    _processedSignals.remove('offer_${peerId}_$uid');
    _processedSignals.remove('offer_${uid}_$peerId');
    _processedSignals.remove('answer_${peerId}_$uid');
    _processedSignals.remove('answer_${uid}_$peerId');
  }

  /// Recomputes the number of participants Firestore reports as active and
  /// notifies only when it actually changed. Stale heartbeats don't count -
  /// otherwise a zombie doc would make an empty call look occupied.
  void _updateParticipantCount(List<Map<String, dynamic>> docs) {
    var count = 0;
    for (final data in docs) {
      if (CallService.isLiveParticipant(data)) count++;
    }
    if (count == _participantCount) return;
    _participantCount = count;
    notifyListeners();
  }

  /// Mirrors each live peer's `videoOff` flag into [_peerVideoOff], pruning
  /// entries for peers that have left, so the UI can swap the black video
  /// texture for the peer's profile picture.
  void _applyVideoOffStates(List<Map<String, dynamic>> docs, String myUid) {
    var changed = false;
    final liveUids = <String>{};
    for (final data in docs) {
      final uid = data['uid'] as String?;
      if (uid == null || uid == myUid) continue;
      if (!CallService.isLiveParticipant(data)) continue;
      liveUids.add(uid);
      final off = data['videoOff'] == true;
      if ((_peerVideoOff[uid] ?? false) != off) {
        changed = true;
        if (off) {
          _peerVideoOff[uid] = true;
        } else {
          _peerVideoOff.remove(uid);
        }
      }
    }
    for (final uid in _peerVideoOff.keys.toList()) {
      if (!liveUids.contains(uid)) {
        _peerVideoOff.remove(uid);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  String _signalSignature(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final payload = data['sdp'] ?? data['candidate'] ?? '';
    return '$type:$payload';
  }

  void _disposeRemoteRenderer(String peerId) {
    final renderer = _remoteRenderers.remove(peerId);
    _rendererReady.remove(peerId);
    _pendingRemoteStreams.remove(peerId);
    if (renderer == null) return;
    try {
      renderer.srcObject = null;
      renderer.dispose();
    } catch (e) {
      debugPrint('Error disposing remote renderer: $e');
    }
  }

  bool _pcNeedsOffer(RTCPeerConnection? pc) {
    if (pc == null) return true;
    final state = pc.connectionState;
    return state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
        state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        state == RTCPeerConnectionState.RTCPeerConnectionStateClosed;
  }

  /// Resolves simultaneous offers deterministically: the lexicographically
  /// smaller uid is the designated offerer and wins a true glare. The larger
  /// uid's offer is accepted only when we have no offer of our own in flight,
  /// which also lets either side recover a dead connection.
  bool _resolveOfferGlare(String myUid, String peerUid) {
    final iAmDesignated = myUid.compareTo(peerUid) < 0;
    final haveLocalOffer = _outgoingOfferPeers.contains(peerUid) ||
        _pendingOfferPeers.contains(peerUid);

    if (iAmDesignated && haveLocalOffer) return false;

    _outgoingOfferPeers.remove(peerUid);
    _noPcSince.remove(peerUid);
    _reconnectTimers['offer_$peerUid']?.cancel();
    _reconnectTimers.remove('offer_$peerUid');
    return true;
  }

  void _createGroupOfferTo(String peerId) {
    final user = _currentUser;
    if (user == null || _activeCall == null) return;
    final uid = user.uid;
    if (_departedPeers.contains(peerId)) return;
    if (_pendingOfferPeers.contains(peerId)) return;

    final key = webrtc.WebRTCService.pcKeyForTest(uid, peerId);
    if (!_pcNeedsOffer(_webrtcService!.peerConnections[key])) return;

    if (uid.compareTo(peerId) > 0) {
      // The smaller uid initiates the first offer. The larger uid only
      // offers as delayed recovery, so both sides never race an initial one.
      final since = _noPcSince.putIfAbsent(peerId, () => DateTime.now());
      final elapsed = DateTime.now().difference(since);
      const grace = Duration(seconds: 6);
      if (elapsed < grace) {
        _reconnectTimers['offer_$peerId']?.cancel();
        _reconnectTimers['offer_$peerId'] =
            Timer(grace - elapsed, () {
          _reconnectTimers.remove('offer_$peerId');
          _createGroupOfferTo(peerId);
        });
        return;
      }
    }

    _pendingOfferPeers.add(peerId);
    _outgoingOfferPeers.add(peerId);
    _webrtcService!
        .createOffer(
      callId: _activeCall!.callId,
      fromUid: uid,
      toUid: peerId,
    )
        .then((_) {
      _pendingOfferPeers.remove(peerId);
    }).catchError((_) {
      _pendingOfferPeers.remove(peerId);
      _outgoingOfferPeers.remove(peerId);
    });
  }

  void _createGroupOffers() {
    final user = _currentUser;
    if (user == null || _activeCall == null) return;
    final uid = user.uid;
    for (final memberUid in _activeCall!.members) {
      if (memberUid == uid) continue;
      _createGroupOfferTo(memberUid);
    }
  }

  Future<void> _sendCallMessageFor(
    ActiveCallData? call,
    int duration,
    String callStatus,
  ) async {
    if (call == null) return;

    final user = _currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userName = user.displayName ?? user.email ?? 'Unknown';
    final callTypeStr = call.callType == CallType.video ? 'video' : 'audio';

    if (call.isGroup && call.groupId != null) {
      await GroupService().sendCallMessage(
        groupId: call.groupId!,
        senderId: uid,
        senderName: userName,
        callType: callTypeStr,
        callStatus: callStatus,
        durationSeconds: duration,
      );
    } else if (call.chatId != null) {
      await DirectService().sendCallMessage(
        chatId: call.chatId!,
        senderId: uid,
        senderName: userName,
        callType: callTypeStr,
        callStatus: callStatus,
        durationSeconds: duration,
      );
    }
  }

  /// Remote bookkeeping after the call has been torn down locally: the chat
  /// message, the participant's leave and (once nobody is left) the data
  /// cleanup. Runs detached with a hard timeout per step, because a Firestore
  /// write on a dead connection used to hang forever and leave the user
  /// stuck on a black call screen with no working end button.
  ///
  /// Returns when everything best-effort has been attempted; failures are
  /// logged, never surfaced, since the call is already over locally.
  Future<void> _finishRemoteHangup({
    required String callId,
    required String? uid,
    required ActiveCallData? callContext,
    required int duration,
    required String callMessageStatus,
    required bool isLeave,
  }) async {
    const budget = Duration(seconds: 5);

    try {
      await _sendCallMessageFor(callContext, duration, callMessageStatus)
          .timeout(budget);
    } catch (e) {
      debugPrint('Error sending call message: $e');
    }

    var callFinished = false;
    if (uid != null && uid.isNotEmpty) {
      try {
        callFinished =
            await _callService.leaveCall(callId, uid).timeout(budget);
      } catch (e) {
        debugPrint('Error leaving call: $e');
      }
      if (isLeave || !callFinished) {
        try {
          await _callService
              .deleteUserSignals(callId, uid)
              .timeout(budget);
        } catch (e) {
          debugPrint('Error deleting user call signals: $e');
        }
      }
    } else {
      try {
        await _callService.endCall(callId).timeout(budget);
        callFinished = true;
      } catch (e) {
        debugPrint('Error ending call: $e');
      }
    }

    if (callFinished) {
      // Only wipe the call's signals/participants once nobody is in it any
      // more - doing this while others are still talking silently destroys
      // their signaling and makes rejoin impossible for everyone.
      await Future.delayed(const Duration(seconds: 2));
      try {
        await _callService.cleanupCallData(callId, uid).timeout(budget);
      } catch (e) {
        debugPrint('Error cleaning up call data: $e');
      }
      // We optimistically offered a rejoin while leaving; drop it now that
      // the call is confirmed dead.
      if (isLeave && _leftCall?.callId == callId) {
        _clearLeftCall();
      }
    }
  }

  Future<void> endActiveCall() {
    if (_activeCall == null) return Future<void>.value();
    // Callers race each other here (the call-doc listener, the connection
    // watchdog and the UI can all fire at once) - share one teardown so the
    // "call ended" message and the Firestore writes happen exactly once.
    return _endCallFuture ??= _endActiveCallInternal().whenComplete(() {
      _endCallFuture = null;
    });
  }

  Future<void>? _endCallFuture;

  Future<void> _endActiveCallInternal() async {
    removeCallOverlay();

    final callId = _activeCall!.callId;
    final uid = _currentUser?.uid;
    final callContext = _activeCall;
    final duration = _callDuration;
    final callMessageStatus = duration > 0 ? 'active' : 'ended';

    // Local teardown first: every subscription, timer and reference is torn
    // down before we touch Firestore, so a hanging remote write can never
    // freeze the UI on a call the user already left.
    _callTimer?.cancel();
    _stopHeartbeat();
    _callSub?.cancel();
    _signalsSub?.cancel();
    _participantsSub?.cancel();
    _webrtcLocalStreamSub?.cancel();
    _webrtcLocalStreamSub = null;
    _webrtcRemoteStreamSub?.cancel();
    _webrtcRemoteStreamSub = null;
    _groupCallDebounce?.cancel();
    for (final t in _reconnectTimers.values) {
      t.cancel();
    }
    _reconnectTimers.clear();
    _reconnectingPeers.clear();

    _activeCall = null;
    _callDuration = 0;
    _durationNotifier.value = 0;
    _participantCount = 0;
    _peerVideoOff.clear();
    _processedSignals.clear();
    _pendingOfferPeers.clear();
    _outgoingOfferPeers.clear();
    _noPcSince.clear();
    _departedPeers.clear();
    _leftCall = null;
    _stopLeftCallWatch();
    WakelockPlus.disable();

    final oldWebrtc = _webrtcService;
    final oldLocalCtrl = _localStreamController;
    final oldRemoteCtrl = _remoteStreamController;
    final oldLocalRenderer = _localRenderer;
    final oldRemoteRenderers =
        Map<String, RTCVideoRenderer>.from(_remoteRenderers);
    _webrtcService = null;
    _localStreamController = null;
    _remoteStreamController = null;
    _localRenderer = null;
    _remoteRenderers.clear();
    _rendererReady.clear();
    _pendingRemoteStreams.clear();

    notifyListeners();

    unawaited(_finishRemoteHangup(
      callId: callId,
      uid: uid,
      callContext: callContext,
      duration: duration,
      callMessageStatus: callMessageStatus,
      isLeave: false,
    ));

    Future.microtask(() async {
      if (oldWebrtc != null) {
        await oldWebrtc.dispose();
      }

      await oldLocalCtrl?.close();
      await oldRemoteCtrl?.close();

      oldLocalRenderer?.srcObject = null;
      oldLocalRenderer?.dispose();

      for (final renderer in oldRemoteRenderers.values) {
        renderer.srcObject = null;
        renderer.dispose();
      }
    });
  }

  Future<void> leaveGroupCall() {
    if (_activeCall == null) return Future<void>.value();
    if (!_activeCall!.isGroup) return endActiveCall();
    return _leaveFuture ??= _leaveGroupCallInternal().whenComplete(() {
      _leaveFuture = null;
    });
  }

  Future<void>? _leaveFuture;

  Future<void> _leaveGroupCallInternal() async {
    final callId = _activeCall!.callId;
    final uid = _currentUser?.uid;
    final callContext = _activeCall;
    final duration = _callDuration;
    final callMessageStatus = duration > 0 ? 'active' : 'ended';

    removeCallOverlay();

    _callTimer?.cancel();
    _stopHeartbeat();
    _callSub?.cancel();
    _signalsSub?.cancel();
    _participantsSub?.cancel();
    _webrtcLocalStreamSub?.cancel();
    _webrtcLocalStreamSub = null;
    _webrtcRemoteStreamSub?.cancel();
    _webrtcRemoteStreamSub = null;
    _groupCallDebounce?.cancel();
    for (final t in _reconnectTimers.values) {
      t.cancel();
    }
    _reconnectTimers.clear();
    _reconnectingPeers.clear();
    _pendingOfferPeers.clear();
    _outgoingOfferPeers.clear();
    _noPcSince.clear();
    _processedSignals.clear();
    _departedPeers.clear();
    _peerVideoOff.clear();

    _activeCall = null;
    _callDuration = 0;
    _durationNotifier.value = 0;
    _participantCount = 0;
    WakelockPlus.disable();

    // Optimistically keep offering a rejoin until the detached leaveCall
    // (or the watch on the call/participants docs) proves nobody is left.
    _leftCall = callContext;
    _startLeftCallWatch(callId);

    final oldWebrtc = _webrtcService;
    final oldLocalCtrl = _localStreamController;
    final oldRemoteCtrl = _remoteStreamController;
    final oldLocalRenderer = _localRenderer;
    final oldRemoteRenderers =
        Map<String, RTCVideoRenderer>.from(_remoteRenderers);
    _webrtcService = null;
    _localStreamController = null;
    _remoteStreamController = null;
    _localRenderer = null;
    _remoteRenderers.clear();
    _rendererReady.clear();
    _pendingRemoteStreams.clear();

    notifyListeners();

    unawaited(_finishRemoteHangup(
      callId: callId,
      uid: uid,
      callContext: callContext,
      duration: duration,
      callMessageStatus: callMessageStatus,
      isLeave: true,
    ));

    Future.microtask(() async {
      if (oldWebrtc != null) {
        await oldWebrtc.dispose();
      }

      await oldLocalCtrl?.close();
      await oldRemoteCtrl?.close();

      oldLocalRenderer?.srcObject = null;
      oldLocalRenderer?.dispose();

      for (final renderer in oldRemoteRenderers.values) {
        renderer.srcObject = null;
        renderer.dispose();
      }
    });
  }

  void _stopLeftCallWatch() {
    _leftWatchCallSub?.cancel();
    _leftWatchCallSub = null;
    _leftWatchParticipantsSub?.cancel();
    _leftWatchParticipantsSub = null;
  }

  void _clearLeftCall() {
    _stopLeftCallWatch();
    if (_leftCall == null) return;
    _leftCall = null;
    _participantCount = 0;
    notifyListeners();
  }

  void _startLeftCallWatch(String callId) {
    _stopLeftCallWatch();
    final myUid = _currentUser?.uid;

    _leftWatchCallSub = _callService.getCallStream(callId).listen(
      (call) {
        if (_leftCall == null) return;
        if (call == null ||
            call.status == CallStatus.ended ||
            call.status == CallStatus.declined ||
            call.status == CallStatus.missed ||
            call.status == CallStatus.cancelled) {
          _clearLeftCall();
        }
      },
      onError: (Object _) {},
    );

    _leftWatchParticipantsSub = _callService
        .getParticipantsStream(callId)
        .listen(
      (snapshot) {
        if (_leftCall == null) return;
        _updateParticipantCount(snapshot.docs.map((doc) => doc.data()).toList());
        final hasOtherActive = snapshot.docs.any((doc) {
          final data = doc.data();
          final uid = data['uid'] as String? ?? doc.id;
          return CallService.isLiveParticipant(data) && uid != myUid;
        });
        if (!hasOtherActive) {
          _clearLeftCall();
        }
      },
      onError: (Object _) {},
    );
  }

  Future<bool> _hasOtherActiveParticipant(
      String callId, String myUid) async {
    try {
      final snapshot = await _callService
          .getParticipantsStream(callId)
          .first
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.any((doc) {
        final data = doc.data();
        final uid = data['uid'] as String? ?? doc.id;
        return CallService.isLiveParticipant(data) && uid != myUid;
      });
    } catch (_) {
      // Can't verify; assume someone is still there so rejoin stays available.
      return true;
    }
  }

  Future<void> rejoinCall() async {
    if (_isRejoining) return;
    final left = _leftCall;
    if (left == null || _activeCall != null) return;

    final user = _currentUser;
    if (user == null) return;

    _isRejoining = true;
    try {
      final callId = left.callId;
      final Call? callDoc;
      try {
        callDoc = await _callService
            .getCallStream(callId)
            .first
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        return;
      }

      if (callDoc == null ||
          callDoc.status == CallStatus.ended ||
          callDoc.status == CallStatus.declined ||
          callDoc.status == CallStatus.missed ||
          callDoc.status == CallStatus.cancelled) {
        _clearLeftCall();
        return;
      }

      final hasOtherActive = await _hasOtherActiveParticipant(
          callId, user.uid);
      if (!hasOtherActive) {
        _clearLeftCall();
        return;
      }

      final resolvedCall = callDoc;
      final callName = left.callName;
      _leftCall = null;
      _stopLeftCallWatch();
      _participantCount = 0;

      try {
        await startNewCall(
          callData: ActiveCallData(
            callId: callId,
            callName: callName,
            callType: resolvedCall.type,
            members: resolvedCall.members,
            createdBy: resolvedCall.createdBy,
            isGroup: resolvedCall.groupId != null,
            chatId: resolvedCall.chatId,
            groupId: resolvedCall.groupId,
            startedAt: DateTime.now(),
          ),
          audioOnly: resolvedCall.type == CallType.audio,
        );
      } catch (e) {
        debugPrint('Error rejoining call: $e');
        if (_activeCall == null) {
          _leftCall = left;
          _startLeftCallWatch(callId);
        }
        notifyListeners();
        return;
      }

      // Push (not replace): the chat screen underneath must survive so the
      // user returns to it when the call is over.
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: callId,
            callName: callName,
            callType: resolvedCall.type,
            members: resolvedCall.members,
            createdBy: resolvedCall.createdBy,
            isGroup: resolvedCall.groupId != null,
            chatId: resolvedCall.chatId,
            groupId: resolvedCall.groupId,
          ),
        ),
      );
    } finally {
      _isRejoining = false;
    }
  }

  /// Joins a call that is already in progress (late join) - for members who
  /// never got, or never answered, the original ring.
  ///
  /// With [replaceTop] the current top route is swapped for [CallScreen]
  /// instead of a new route being pushed (used when the top route is a
  /// throw-away incoming-call route).
  Future<bool> joinExistingCall(
    Call call,
    String callName, {
    bool replaceTop = false,
  }) async {
    if (_isRejoining) return false;
    final user = _currentUser;
    if (user == null) return false;
    if (_activeCall != null || _outgoingCall != null) {
      // Already busy in some call (possibly this one) - the caller should
      // have used returnToCall()/rejoinCall() instead.
      return false;
    }
    if (!call.members.contains(user.uid)) return false;

    _isRejoining = true;
    try {
      final callDoc = await _callService
          .getCallStream(call.id)
          .first
          .timeout(const Duration(seconds: 10));
      if (callDoc == null ||
          callDoc.status == CallStatus.ended ||
          callDoc.status == CallStatus.missed ||
          callDoc.status == CallStatus.cancelled ||
          callDoc.status == CallStatus.declined) {
        return false;
      }

      await startNewCall(
        callData: ActiveCallData(
          callId: callDoc.id,
          callName: callName,
          callType: callDoc.type,
          members: callDoc.members,
          createdBy: callDoc.createdBy,
          isGroup: callDoc.groupId != null,
          chatId: callDoc.chatId,
          groupId: callDoc.groupId,
          startedAt: DateTime.now(),
        ),
        audioOnly: callDoc.type == CallType.audio,
      );

      final nav = navigatorKey.currentState;
      if (nav == null) return false;
      final route = MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callDoc.id,
          callName: callName,
          callType: callDoc.type,
          members: callDoc.members,
          createdBy: callDoc.createdBy,
          isGroup: callDoc.groupId != null,
          chatId: callDoc.chatId,
          groupId: callDoc.groupId,
        ),
      );
      if (replaceTop) {
        nav.pushReplacement(route);
      } else {
        nav.push(route);
      }
      return true;
    } catch (e) {
      debugPrint('Error joining call: $e');
      return false;
    } finally {
      _isRejoining = false;
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _webrtcService?.setAudioEnabled(!_isMuted);
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoOff = !_isVideoOff;
    _webrtcService?.setVideoEnabled(!_isVideoOff);
    notifyListeners();

    final call = _activeCall;
    final uid = _currentUser?.uid;
    if (call == null || uid == null) return;
    unawaited(_publishVideoState(call.callId, uid, videoOff: _isVideoOff));
  }

  /// Publishes the camera state on our participant doc. Peers can't detect a
  /// remote mute (their track just renders black), so without this flag the
  /// other side would stare at a black rectangle instead of our photo.
  Future<void> _publishVideoState(
    String callId,
    String uid, {
    required bool videoOff,
  }) async {
    try {
      await _callService
          .setVideoState(callId, uid, videoOff: videoOff)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error publishing video state: $e');
    }
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
    if (!mounted) return;
    // trackOutgoingCall() notifies while OutgoingCallScreen.initState is still
    // running, i.e. inside a build pass - defer the setState.
    safeNav(() {
      if (mounted) setState(() {});
    }, label: 'call banner update');
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
                          ValueListenableBuilder<int>(
                            valueListenable: _callManager.callDurationListenable,
                            builder: (context, value, _) => Text(
                              isActive
                                  ? (_callManager.activeCall?.isGroup == true
                                      ? '${_callManager.participantCount} in call \u2022 ${formatSeconds(value)}'
                                      : formatSeconds(value))
                                  : 'Ringing...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
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
