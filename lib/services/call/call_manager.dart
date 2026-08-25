import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/call.dart';
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
  StreamSubscription? _callSub;
  StreamSubscription? _signalsSub;
  StreamSubscription? _groupCallSub;
  Timer? _groupCallDebounce;
  Timer? _callTimer;
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
  bool get hasActiveCall => _activeCall != null;
  webrtc.WebRTCService? get webrtcService => _webrtcService;
  int get callDuration => _callDuration;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;

  StreamController<MediaStream>? _localStreamController;
  StreamController<MediaStream>? _remoteStreamController;

  Stream<MediaStream>? get onLocalStream => _localStreamController?.stream;
  Stream<MediaStream>? get onRemoteStream => _remoteStreamController?.stream;

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
    _isSpeakerOn = false;
    _processedSignals.clear();
    _pendingOfferPeers.clear();

    _webrtcService = webrtc.WebRTCService();
    _localStreamController = StreamController<MediaStream>.broadcast();
    _remoteStreamController = StreamController<MediaStream>.broadcast();

    await _webrtcService!.initialize(audioOnly: audioOnly);

    _webrtcService!.onLocalStream.listen((stream) {
      _localStreamController?.add(stream);
      notifyListeners();
    });

    _webrtcService!.onRemoteStream.listen((stream) {
      _remoteStreamController?.add(stream);
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

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (!callData.isGroup) {
          endActiveCall();
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
        final fromUid = data['fromUid'] as String;
        final type = data['type'] as String;

        if (type == 'offer') {
          _webrtcService!.handleOffer(
            callId: callData.callId,
            fromUid: fromUid,
            toUid: user.uid,
            sdpJson: data['sdp'] as String,
          );
        } else if (type == 'answer') {
          _webrtcService!.handleAnswer(
            fromUid: fromUid,
            toUid: user.uid,
            sdpJson: data['sdp'] as String,
          );
        } else if (type == 'candidate') {
          _webrtcService!.handleIceCandidate(
            fromUid: fromUid,
            toUid: user.uid,
            candidateJson: data['candidate'] as String,
          );
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

  void _sendCallMessage() {
    final user = _currentUser;
    if (user == null || _activeCall == null) return;

    final uid = user.uid;
    final userName = user.displayName ?? user.email ?? 'Unknown';
    final callTypeStr =
        _activeCall!.callType == CallType.video ? 'video' : 'audio';
    final duration = _callDuration;

    if (_activeCall!.isGroup && _activeCall!.groupId != null) {
      GroupService().sendCallMessage(
        groupId: _activeCall!.groupId!,
        senderId: uid,
        senderName: userName,
        callType: callTypeStr,
        callStatus: 'active',
        durationSeconds: duration,
      );
    } else if (_activeCall!.chatId != null) {
      DirectService().sendCallMessage(
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

    final callId = _activeCall!.callId;

    _callTimer?.cancel();
    _callSub?.cancel();
    _signalsSub?.cancel();
    _groupCallSub?.cancel();
    _groupCallDebounce?.cancel();

    _sendCallMessage();

    try {
      await _callService.leaveCall(callId, _currentUser?.uid ?? '');
    } catch (e) {
      debugPrint('Error leaving call: $e');
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
