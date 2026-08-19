import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_service.dart';

class WebRTCService {
  final CallService _callService = CallService();

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  MediaStream? _localStream;

  final StreamController<MediaStream> _localStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<MediaStream> _remoteStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<RTCPeerConnectionState> _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();

  Stream<MediaStream> get onLocalStream => _localStreamController.stream;
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;
  Stream<RTCPeerConnectionState> get onConnectionState =>
      _connectionStateController.stream;

  Map<String, RTCPeerConnection> get peerConnections => _peerConnections;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  MediaStream? get localStream => _localStream;

  bool _isAudioOnly = false;
  Function(String fromUid, String candidateJson)? onIceCandidateGenerated;

  Future<void> initialize({bool audioOnly = false}) async {
    _isAudioOnly = audioOnly;

    final mediaConstraints = {
      'audio': true,
      'video': audioOnly
          ? false
          : {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
            },
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStreamController.add(_localStream!);
    } catch (e) {
      debugPrint('Error getting user media: $e');
    }
  }

  Future<RTCPeerConnection?> _createPeerConnection(String peerId) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
      ],
    };

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
        debugPrint('ICE candidate generated for $peerId: $candidateJson');
        onIceCandidateGenerated?.call(peerId, candidateJson);
      };

      pc.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          final stream = event.streams.first;
          _remoteStreams[peerId] = stream;
          _remoteStreamController.add(stream);
        }
      };

      pc.onConnectionState = (RTCPeerConnectionState state) {
        _connectionStateController.add(state);
        debugPrint('Peer connection state with $peerId: $state');
      };

      return pc;
    } catch (e) {
      debugPrint('Error creating peer connection: $e');
      return null;
    }
  }

  Future<void> createOffer({
    required String callId,
    required String fromUid,
    required String toUid,
  }) async {
    final key = '${fromUid}_$toUid';
    final pc = await _createPeerConnection(toUid);
    if (pc == null) return;
    _peerConnections[key] = pc;

    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': !_isAudioOnly,
    });

    await pc.setLocalDescription(offer);

    final sdp = jsonEncode({
      'type': offer.type,
      'sdp': offer.sdp,
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
    final key = '${fromUid}_$toUid';
    final pc = await _createPeerConnection(fromUid);
    if (pc == null) return;
    _peerConnections[key] = pc;

    final sdpData = jsonDecode(sdpJson);
    final offer = RTCSessionDescription(
      sdpData['sdp'] as String,
      sdpData['type'] as String,
    );

    await pc.setRemoteDescription(offer);

    final answer = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': !_isAudioOnly,
    });

    await pc.setLocalDescription(answer);

    final answerJson = jsonEncode({
      'type': answer.type,
      'sdp': answer.sdp,
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
    final key = '${toUid}_$fromUid';
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
  }

  Future<void> handleIceCandidate({
    required String fromUid,
    required String toUid,
    required String candidateJson,
  }) async {
    final key = '${toUid}_$fromUid';
    final pc = _peerConnections[key];
    if (pc == null) return;

    final data = jsonDecode(candidateJson);
    final candidate = RTCIceCandidate(
      data['candidate'] as String,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );

    await pc.addCandidate(candidate);
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

  Future<void> dispose() async {
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    _remoteStreams.clear();
    await _localStreamController.close();
    await _remoteStreamController.close();
    await _connectionStateController.close();
  }
}
