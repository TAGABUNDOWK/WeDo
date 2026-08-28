import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/call.dart';
import '../../utils/constants.dart';

class CallService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Map<String, List<Map<String, dynamic>>> _iceBuffer = {};
  final Map<String, Timer> _iceFlushTimers = {};

  CollectionReference<Map<String, dynamic>> get _calls =>
      _db.collection(AppConstants.callsCollection);

  CollectionReference<Map<String, dynamic>> _signals(String callId) =>
      _calls.doc(callId).collection(AppConstants.callSignalsSubcollection);

  CollectionReference<Map<String, dynamic>> _participants(String callId) =>
      _calls.doc(callId).collection(AppConstants.callParticipantsSubcollection);

  Future<String> startCall({
    String? groupId,
    String? chatId,
    required String createdBy,
    required CallType type,
    required List<String> members,
  }) async {
    final docRef = _calls.doc();
    final call = Call(
      id: docRef.id,
      groupId: groupId,
      chatId: chatId,
      type: type,
      status: CallStatus.ringing,
      createdBy: createdBy,
      members: members,
      createdAt: DateTime.now(),
    );

    await docRef.set(call.toFirestore());
    return docRef.id;
  }

  Future<void> joinCall(String callId, String uid) async {
    final doc = await _calls.doc(callId).get();
    final status = doc.data()?['status'] as String?;
    if (status == 'ended' || status == 'missed') return;

    await _calls.doc(callId).update({
      'status': CallStatus.active.value,
      'startedAt': FieldValue.serverTimestamp(),
    });

    await _participants(callId).doc(uid).set({
      'uid': uid,
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  Future<void> endCall(String callId) async {
    await _calls.doc(callId).update({
      'status': CallStatus.ended.value,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveCall(String callId, String uid) async {
    await _participants(callId).doc(uid).update({
      'status': 'left',
    });

    final activeParticipants = await _participants(callId)
        .where('status', isEqualTo: 'active')
        .get();

    final callDoc = await _calls.doc(callId).get();
    final callData = callDoc.data();
    final createdBy = callData?['createdBy'] as String?;
    final groupId = callData?['groupId'] as String?;

    final isGroupCall = groupId != null && groupId.isNotEmpty;

    if (activeParticipants.docs.isEmpty) {
      await endCall(callId);
    } else if (!isGroupCall && uid == createdBy) {
      await endCall(callId);
    }
  }

  Stream<Call?> getCallStream(String callId) {
    return _calls.doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Call.fromFirestore(doc);
    });
  }

  Stream<List<Call>> getIncomingCallsStream(String uid) {
    return _calls
        .where('members', arrayContains: uid)
        .where('status', isEqualTo: CallStatus.ringing.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Call.fromFirestore).toList());
  }

  Stream<List<Call>> getUserCallsStream(String uid) {
    return _calls
        .where('members', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(Call.fromFirestore).toList());
  }

  Future<void> sendOffer({
    required String callId,
    required String fromUid,
    required String toUid,
    required String sdp,
  }) async {
    await _signals(callId).doc('offer_${fromUid}_$toUid').set({
      'fromUid': fromUid,
      'toUid': toUid,
      'type': 'offer',
      'sdp': sdp,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendAnswer({
    required String callId,
    required String fromUid,
    required String toUid,
    required String sdp,
  }) async {
    await _signals(callId).doc('answer_${fromUid}_$toUid').set({
      'fromUid': fromUid,
      'toUid': toUid,
      'type': 'answer',
      'sdp': sdp,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendIceCandidate({
    required String callId,
    required String fromUid,
    required String toUid,
    required String candidate,
  }) async {
    final bufferKey = '${callId}_${fromUid}_$toUid';
    _iceBuffer.putIfAbsent(bufferKey, () => []).add({
      'fromUid': fromUid,
      'toUid': toUid,
      'type': 'candidate',
      'candidate': candidate,
    });

    if ((_iceBuffer[bufferKey]?.length ?? 0) >= 5) {
      _flushIceBuffer(bufferKey, callId);
    } else {
      _iceFlushTimers[bufferKey]?.cancel();
      _iceFlushTimers[bufferKey] = Timer(const Duration(milliseconds: 500), () {
        _flushIceBuffer(bufferKey, callId);
      });
    }
  }

  Future<void> _flushIceBuffer(String bufferKey, String callId) async {
    _iceFlushTimers[bufferKey]?.cancel();
    _iceFlushTimers.remove(bufferKey);
    final candidates = _iceBuffer.remove(bufferKey);
    if (candidates == null || candidates.isEmpty) return;

    final batch = _db.batch();
    for (final data in candidates) {
      final ref = _signals(callId).doc();
      batch.set(ref, {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error flushing ICE buffer: $e');
    }
  }

  Future<void> markSignalProcessed(
    String callId,
    String signalId,
    String uid,
  ) async {
    try {
      await _signals(callId).doc(signalId).update({
        'processedBy': FieldValue.arrayUnion([uid]),
      });
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSignalsForUser(
    String callId,
    String uid,
  ) {
    return _signals(callId)
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> deleteCallSignals(String callId) async {
    for (final key in _iceBuffer.keys.toList()) {
      if (key.startsWith('${callId}_')) {
        _iceFlushTimers[key]?.cancel();
        _iceFlushTimers.remove(key);
        _iceBuffer.remove(key);
      }
    }
    final signals = await _signals(callId).get();
    final batch = _db.batch();
    for (final doc in signals.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> cleanupCallData(String callId) async {
    await deleteCallSignals(callId);
    final participants = await _participants(callId).get();
    final batch = _db.batch();
    for (final doc in participants.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  void dispose() {
    for (final timer in _iceFlushTimers.values) {
      timer.cancel();
    }
    _iceFlushTimers.clear();
    _iceBuffer.clear();
  }
}
