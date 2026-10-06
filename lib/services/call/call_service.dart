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
    final data = doc.data();
    final status = data?['status'] as String?;
    if (status == 'ended' || status == 'missed') return;

    final updateData = <String, dynamic>{
      'status': CallStatus.active.value,
    };

    if (status != CallStatus.active.value) {
      updateData['startedAt'] = FieldValue.serverTimestamp();
    }

    await _calls.doc(callId).update(updateData);

    await _participants(callId).doc(uid).set({
      'uid': uid,
      'joinedAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'status': 'active',
      'videoOff': false,
    });
  }

  /// Refreshes this member's liveness marker. A heartbeat is written every
  /// 20s while a call is active, so everyone else (and the scheduled reaper)
  /// can tell a live participant from a doc left behind by a crashed or
  /// force-closed app - without it a call could never be ended by anyone.
  Future<void> touchParticipant(String callId, String uid) async {
    await _participants(callId).doc(uid).update({
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Publishes whether this member's camera is off so peers can show their
  /// profile picture instead of a black video texture (a receiver cannot
  /// detect the sender muting its track).
  Future<void> setVideoState(
    String callId,
    String uid, {
    required bool videoOff,
  }) async {
    await _participants(callId).doc(uid).update({'videoOff': videoOff});
  }

  /// A participant counts as being in the call only while their status is
  /// 'active' AND their heartbeat is fresh. Docs written before the
  /// heartbeat existed (no `lastSeen` field) keep the old status-only
  /// behaviour, so mixed app versions never end a live call early.
  static bool isLiveParticipant(
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    if (data['status'] != 'active') return false;
    final lastSeen = data['lastSeen'];
    if (lastSeen is! Timestamp) return true;
    // abs(): tolerate modest client/server clock skew in either direction.
    final age = (now ?? DateTime.now()).difference(lastSeen.toDate()).abs();
    return age <= const Duration(seconds: 90);
  }

  /// An already-active call in [chatId] that [uid] is a member of - used to
  /// stop the direct-chat button from firing a second, parallel call.
  Future<Call?> findActiveDirectCall(String chatId, String uid) async {
    // Status-only query: served by the automatic single-field index, so no
    // composite index is required for this lookup.
    final snap =
        await _calls.where('status', isEqualTo: CallStatus.active.value).get();
    for (final doc in snap.docs) {
      final call = Call.fromFirestore(doc);
      if (call.chatId == chatId && call.members.contains(uid)) return call;
    }
    return null;
  }

  Future<void> endCall(String callId) async {
    await _calls.doc(callId).update({
      'status': CallStatus.ended.value,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineCall(String callId) async {
    await _calls.doc(callId).update({
      'status': CallStatus.declined.value,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  static const Set<String> _terminalStatuses = {
    'ended',
    'missed',
    'declined',
    'cancelled',
  };

  /// Marks [uid] as having left the call and returns `true` when the call
  /// itself is now finished (it was already terminal, it is a 1:1 call, or
  /// nobody is left in it any more).
  Future<bool> leaveCall(String callId, String uid) async {
    await _participants(callId).doc(uid).update({
      'status': 'left',
    });

    final callDoc = await _calls.doc(callId).get();
    final callData = callDoc.data();
    final groupId = callData?['groupId'] as String?;
    final status = callData?['status'] as String?;

    // Someone else already ended it - we are just cleaning ourself up, but
    // the call data still needs tearing down by whichever client sees this.
    if (status != null && _terminalStatuses.contains(status)) return true;

    final isGroupCall = groupId != null && groupId.isNotEmpty;

    if (!isGroupCall) {
      await endCall(callId);
      return true;
    }

    final activeParticipants = await _participants(callId)
        .where('status', isEqualTo: 'active')
        .get();

    // The call is over as soon as the last participant walks out, whoever
    // that happens to be - not just when the creator is the one leaving.
    // Docs whose heartbeat went stale (crashed/killed apps) don't count as
    // being here any more, otherwise a zombie participant could keep a call
    // alive that nobody can end.
    final anyoneLive =
        activeParticipants.docs.any((doc) => isLiveParticipant(doc.data()));
    if (!anyoneLive) {
      await endCall(callId);
      return true;
    }

    return false;
  }

  /// Every call belonging to [groupId]. Filtering happens on the client so
  /// the query stays a single-field equality filter (no composite index).
  Stream<List<Call>> getGroupCallsStream(String groupId) {
    return _calls
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snap) => snap.docs.map(Call.fromFirestore).toList());
  }

  Future<void> deleteUserSignals(String callId, String uid) async {
    final inbound =
        await _signals(callId).where('toUid', isEqualTo: uid).get();
    final outbound =
        await _signals(callId).where('fromUid', isEqualTo: uid).get();

    final docsById =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in inbound.docs) {
      docsById[doc.id] = doc;
    }
    for (final doc in outbound.docs) {
      docsById[doc.id] = doc;
    }
    if (docsById.isEmpty) return;

    final batch = _db.batch();
    for (final doc in docsById.values) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<Call?> getCallStream(String callId) {
    return _calls.doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Call.fromFirestore(doc);
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getParticipantsStream(
      String callId) {
    return _participants(callId).snapshots();
  }

  Future<String?> getParticipantStatus(String callId, String uid) async {
    final doc = await _participants(callId).doc(uid).get();
    return doc.data()?['status'] as String?;
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
      if (candidates.isNotEmpty) {
        _iceBuffer[bufferKey] = candidates;
        _iceFlushTimers[bufferKey] = Timer(
          const Duration(milliseconds: 500),
          () => _flushIceBuffer(bufferKey, callId),
        );
      }
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

  /// Best-effort cleanup after a call is over. Clients may only delete their
  /// OWN participant doc (see firestore.rules), so everything else is left to
  /// the scheduled reaper - a batch that touched other members' docs would be
  /// denied and fail atomically, deleting nothing at all.
  Future<void> cleanupCallData(String callId, String? uid) async {
    await deleteCallSignals(callId);
    if (uid == null || uid.isEmpty) return;
    try {
      await _participants(callId).doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting own participant doc: $e');
    }
  }

  void dispose() {
    for (final timer in _iceFlushTimers.values) {
      timer.cancel();
    }
    _iceFlushTimers.clear();
    _iceBuffer.clear();
  }
}
