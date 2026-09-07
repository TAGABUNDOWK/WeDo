import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_service.dart';

class WebRTCService {
  final CallService _callService = CallService();

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  MediaStream? _localStream;

  final StreamController<MediaStream> _localStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<(String peerId, MediaStream stream)>
      _remoteStreamController =
      StreamController<(String peerId, MediaStream stream)>.broadcast();
  final StreamController<(String peerId, RTCPeerConnectionState state)>
      _connectionStateController =
      StreamController<(String peerId, RTCPeerConnectionState state)>.broadcast();

  Stream<MediaStream> get onLocalStream => _localStreamController.stream;
  Stream<(String peerId, MediaStream stream)> get onRemoteStream =>
      _remoteStreamController.stream;
  Stream<(String peerId, RTCPeerConnectionState state)> get onConnectionState =>
      _connectionStateController.stream;

  Map<String, RTCPeerConnection> get peerConnections => _peerConnections;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  MediaStream? get localStream => _localStream;

  bool _isAudioOnly = false;
  Function(String peerId, String candidateJson)? onIceCandidateGenerated;
  Function(String peerId, RTCPeerConnectionState state)? onConnectionStateChanged;

  /// Normalized key: always alphabetical order so A_B == B_A lookup works.
  static String _pcKey(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  /// Public accessor for normalized key (used by CallScreen group call logic).
  static String pcKeyForTest(String uid1, String uid2) => _pcKey(uid1, uid2);

  RTCSessionDescription _applyBitrateCap(
    RTCSessionDescription desc, {
    int videoKbps = 256,
    int audioKbps = 32,
  }) {
    var sdp = desc.sdp ?? '';
    final lines = sdp.split('\n');
    final result = <String>[];
    var inVideo = false;
    var inAudio = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      result.add(line);

      if (line.startsWith('m=video')) {
        inVideo = true;
        inAudio = false;
      } else if (line.startsWith('m=audio')) {
        inAudio = true;
        inVideo = false;
      } else if (line.startsWith('m=')) {
        inVideo = false;
        inAudio = false;
      }

      if (inVideo &&
          line.startsWith('a=fmtp:') &&
          i + 1 < lines.length &&
          !lines[i + 1].startsWith('b=')) {
        result.add('b=AS:$videoKbps');
      } else if (inAudio &&
          line.startsWith('a=fmtp:') &&
          i + 1 < lines.length &&
          !lines[i + 1].startsWith('b=')) {
        result.add('b=AS:$audioKbps');
      }
    }

    return RTCSessionDescription(result.join('\n'), desc.type);
  }

  Future<void> initialize({bool audioOnly = false}) async {
    _isAudioOnly = audioOnly;

    final turnUser = dotenv.env['TURN_USERNAME'] ?? '';
    final turnPass = dotenv.env['TURN_CREDENTIAL'] ?? '';
    if (turnUser.isEmpty || turnPass.isEmpty) {
      debugPrint(
        'WARNING: TURN credentials are empty. Calls may fail behind strict firewalls.',
      );
    }

    final mediaConstraints = {
      'audio': true,
      'video': audioOnly
          ? false
          : {
              'mandatory': {
                'minWidth': '320',
                'minHeight': '240',
                'minFrameRate': '15',
              },
              'facingMode': 'user',
            },
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStreamController.add(_localStream!);
    } catch (e) {
      debugPrint('Error getting user media with video: $e');

      if (!audioOnly) {
        debugPrint('Falling back to audio-only mode');
        _isAudioOnly = true;
        try {
          final audioConstraints = {
            'audio': true,
            'video': false,
          };
          _localStream =
              await navigator.mediaDevices.getUserMedia(audioConstraints);
          _localStreamController.add(_localStream!);
        } catch (audioError) {
          debugPrint('Error getting audio-only media: $audioError');
        }
      }
    }
  }

  Future<RTCPeerConnection?> _createPeerConnection(String peerId) async {
    final turnUser = dotenv.env['TURN_USERNAME'] ?? '';
    final turnPass = dotenv.env['TURN_CREDENTIAL'] ?? '';

    final iceServers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.relay.metered.ca:80'},
    ];

    if (turnUser.isNotEmpty && turnPass.isNotEmpty) {
      iceServers.addAll([
        {
          'urls': 'turn:standard.relay.metered.ca:80',
          'username': turnUser,
          'credential': turnPass,
        },
        {
          'urls': 'turn:standard.relay.metered.ca:80?transport=tcp',
          'username': turnUser,
          'credential': turnPass,
        },
        {
          'urls': 'turn:standard.relay.metered.ca:443',
          'username': turnUser,
          'credential': turnPass,
        },
        {
          'urls': 'turns:standard.relay.metered.ca:443?transport=tcp',
          'username': turnUser,
          'credential': turnPass,
        },
      ]);
    }

    final config = {'iceServers': iceServers};

    try {
      final pc = await createPeerConnection(config);

      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await pc.addTrack(track, _localStream!);
        }
      }

      pc.onIceCandidate = (RTCIceCandidate candidate) {
        final candidateJson = jsonEncode({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
        onIceCandidateGenerated?.call(peerId, candidateJson);
      };

      pc.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          final stream = event.streams.first;
          _remoteStreams[peerId] = stream;
          _remoteStreamController.add((peerId, stream));
        }
      };

      pc.onConnectionState = (RTCPeerConnectionState state) {
        _connectionStateController.add((peerId, state));
        onConnectionStateChanged?.call(peerId, state);
        debugPrint('Peer connection state with $peerId: $state');

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _handlePeerDisconnect(peerId);
        }
      };

      return pc;
    } catch (e) {
      debugPrint('Error creating peer connection: $e');
      return null;
    }
  }

  void _handlePeerDisconnect(String peerId) {
    _remoteStreams.remove(peerId);
    debugPrint('Remote stream removed for disconnected peer: $peerId');
  }

  Future<void> _disposePeerConnection(String key) async {
    final pc = _peerConnections.remove(key);
    if (pc != null) {
      try {
        await pc.close();
      } catch (_) {}
    }
    _pendingCandidates.remove(key);
  }

  Future<void> _flushPendingCandidates(String key, RTCPeerConnection pc) async {
    final candidates = _pendingCandidates.remove(key);
    if (candidates == null || candidates.isEmpty) return;
    debugPrint('Flushing ${candidates.length} buffered ICE candidates for $key');
    for (final c in candidates) {
      try {
        await pc.addCandidate(c);
      } catch (e) {
        debugPrint('Error adding buffered ICE candidate: $e');
      }
    }
  }

  Future<void> createOffer({
    required String callId,
    required String fromUid,
    required String toUid,
  }) async {
    final key = _pcKey(fromUid, toUid);
    await _disposePeerConnection(key);

    final pc = await _createPeerConnection(toUid);
    if (pc == null) return;
    _peerConnections[key] = pc;

    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': !_isAudioOnly,
    });

    final cappedOffer = _isAudioOnly ? offer : _applyBitrateCap(offer);
    await pc.setLocalDescription(cappedOffer);

    final sdp = jsonEncode({
      'type': cappedOffer.type,
      'sdp': cappedOffer.sdp,
    });

    await _callService.sendOffer(
      callId: callId,
      fromUid: fromUid,
      toUid: toUid,
      sdp: sdp,
    );
  }

  Future<void> handleOffer({
    required String callId,
    required String fromUid,
    required String toUid,
    required String sdpJson,
  }) async {
    final key = _pcKey(fromUid, toUid);
    await _disposePeerConnection(key);

    final pc = await _createPeerConnection(fromUid);
    if (pc == null) return;
    _peerConnections[key] = pc;

    final sdpData = jsonDecode(sdpJson);
    final offer = RTCSessionDescription(
      sdpData['sdp'] as String,
      sdpData['type'] as String,
    );

    await pc.setRemoteDescription(offer);

    await _flushPendingCandidates(key, pc);

    final answer = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': !_isAudioOnly,
    });

    final cappedAnswer = _isAudioOnly ? answer : _applyBitrateCap(answer);
    await pc.setLocalDescription(cappedAnswer);

    final answerJson = jsonEncode({
      'type': cappedAnswer.type,
      'sdp': cappedAnswer.sdp,
    });

    await _callService.sendAnswer(
      callId: callId,
      fromUid: toUid,
      toUid: fromUid,
      sdp: answerJson,
    );
  }

  Future<void> handleAnswer({
    required String fromUid,
    required String toUid,
    required String sdpJson,
  }) async {
    final key = _pcKey(fromUid, toUid);
    final pc = _peerConnections[key];
    if (pc == null) {
      debugPrint('No peer connection found for $key');
      return;
    }

    final sdpData = jsonDecode(sdpJson);
    final answer = RTCSessionDescription(
      sdpData['sdp'] as String,
      sdpData['type'] as String,
    );

    await pc.setRemoteDescription(answer);

    await _flushPendingCandidates(key, pc);
  }

  Future<void> handleIceCandidate({
    required String fromUid,
    required String toUid,
    required String candidateJson,
  }) async {
    final key = _pcKey(fromUid, toUid);
    final data = jsonDecode(candidateJson);
    final candidate = RTCIceCandidate(
      data['candidate'] as String,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );

    final pc = _peerConnections[key];
    if (pc == null) {
      debugPrint('PC not ready, buffering ICE candidate for $key');
      _pendingCandidates.putIfAbsent(key, () => []).add(candidate);
      return;
    }

    try {
      await pc.addCandidate(candidate);
    } catch (e) {
      debugPrint('Error adding ICE candidate, buffering: $e');
      _pendingCandidates.putIfAbsent(key, () => []).add(candidate);
    }
  }

  Future<void> toggleAudio() async {
    if (_localStream == null) return;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !track.enabled;
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream == null) return;
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = !track.enabled;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> setSpeakerOn(bool enabled) async {
    await Helper.setSpeakerphoneOn(enabled);
  }

  Future<void> dispose() async {
    for (final key in _peerConnections.keys.toList()) {
      await _disposePeerConnection(key);
    }

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    _remoteStreams.clear();
    _pendingCandidates.clear();
    _callService.dispose();
    await _localStreamController.close();
    await _remoteStreamController.close();
    await _connectionStateController.close();
  }
}
