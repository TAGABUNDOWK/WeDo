import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/tri_race_entity.dart';
import '../../utils/constants.dart';

class TriRaceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _palette = [
    '#FF6B6B',
    '#4ECDC4',
    '#45B7D1',
    '#96CEB4',
    '#FFEAA7',
    '#DDA0DD',
    '#98D8C8',
    '#F7DC6F',
  ];

  CollectionReference get _triRaces =>
      _db.collection(AppConstants.triRacesCollection);

  CollectionReference _participants(String raceId) =>
      _triRaces.doc(raceId).collection(AppConstants.participantsSubcollection);

  // ──────────────────────────── Code Generation ────────────────────────────

  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();

    for (int attempt = 0; attempt < 10; attempt++) {
      final code = String.fromCharCodes(
        Iterable.generate(6, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
      );
      final existing = await _triRaces.doc(code).get();
      if (!existing.exists) return code;
    }
    throw const TriRaceException('Failed to generate unique code. Try again.');
  }

  // ──────────────────────────── CRUD ───────────────────────────────────────

  Future<String> createTriRace({
    required String hostId,
    required String hostName,
    int maxPlayers = 4,
  }) async {
    try {
      final code = await _generateUniqueCode();
      final now = DateTime.now();

      final raceData = {
        'joinCode': code,
        'hostId': hostId,
        'status': TriRaceStatus.lobby.value,
        'maxPlayers': maxPlayers,
        'createdAt': Timestamp.fromDate(now),
        'invitedUserIds': [],
        'participantUids': [],
      };

      await _triRaces.doc(code).set(raceData);
      return code;
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to create TriRace: ${e.message}');
    }
  }

  Future<TriRace> validateJoinCode(String code) async {
    try {
      final doc = await _triRaces.doc(code).get();
      if (!doc.exists) {
        throw const TriRaceException('Race not found. Check the code and try again.');
      }
      final race = TriRace.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
      if (race.status != TriRaceStatus.lobby) {
        throw const TriRaceException('Race already started or ended.');
      }
      if (race.participantUids.length >= race.maxPlayers) {
        throw const TriRaceException('Race is full.');
      }
      return race;
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to validate code: ${e.message}');
    }
  }

  Future<void> joinTriRace({
    required String raceId,
    required String userId,
    required String userName,
  }) async {
    try {
      final participantDoc = _participants(raceId).doc(userId);
      final existing = await participantDoc.get();
      if (existing.exists) return;

      final raceDoc = await _triRaces.doc(raceId).get();
      if (!raceDoc.exists) throw const TriRaceException('Race not found.');
      final raceData = raceDoc.data() as Map<String, dynamic>;
      final participantUids = (raceData['participantUids'] as List?)?.cast<String>() ?? [];
      final colorIndex = participantUids.length % _palette.length;
      final avatarColor = _palette[colorIndex];

      final batch = _db.batch();

      batch.set(participantDoc, {
        'userId': userId,
        'username': userName,
        'joinedAt': FieldValue.serverTimestamp(),
        'avatarColor': avatarColor,
      });

      batch.update(_triRaces.doc(raceId), {
        'participantUids': FieldValue.arrayUnion([userId]),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to join TriRace: ${e.message}');
    }
  }

  // ──────────────────────────── Streams ────────────────────────────────────

  Stream<TriRace?> getTriRaceStream(String raceId) {
    return _triRaces.doc(raceId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TriRace.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    });
  }

  Stream<List<TriRaceParticipant>> getParticipantsStream(String raceId) {
    return _participants(raceId)
        .orderBy('joinedAt')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => TriRaceParticipant.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ))
          .toList();
    });
  }

  // ──────────────────────────── One-time Fetches ──────────────────────────

  Future<TriRace?> fetchTriRace(String raceId) async {
    try {
      final doc = await _triRaces.doc(raceId).get();
      if (!doc.exists) return null;
      return TriRace.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to fetch race: ${e.message}');
    }
  }

  Future<List<TriRaceParticipant>> fetchParticipants(String raceId) async {
    try {
      final snap = await _participants(raceId).orderBy('joinedAt').get();
      return snap.docs
          .map((doc) => TriRaceParticipant.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to fetch participants: ${e.message}');
    }
  }

  /// Resolves the real profile display names (users/{id}.display_name) for the
  /// given participant userIds. Bots are skipped and keys with no stored name
  /// are omitted so callers can fall back to the participant username.
  Future<Map<String, String>> fetchDisplayNames(List<String> userIds) async {
    final unique = userIds.where((id) => !id.startsWith('bot_')).toSet();
    if (unique.isEmpty) return const {};

    final names = <String, String>{};
    try {
      final docs = await Future.wait(
        unique.map((id) => _db.collection('users').doc(id).get()),
      );
      for (final doc in docs) {
        if (!doc.exists) continue;
        final data = doc.data();
        final name = (data?['display_name'] as String? ?? data?['displayName'] as String?)
            ?.trim();
        if (name != null && name.isNotEmpty) names[doc.id] = name;
      }
    } catch (_) {}

    return names;
  }

  // ──────────────────────────── Completed Queries ──────────────────────────

  Future<List<TriRace>> getUserCompletedTriRaces(String uid, {int limit = 3}) async {
    try {
      final hostSnap = await _triRaces
          .where('hostId', isEqualTo: uid)
          .where('status', isEqualTo: 'finished')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final participantSnap = await _triRaces
          .where('participantUids', arrayContains: uid)
          .where('status', isEqualTo: 'finished')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final seen = <String>{};
      final results = <TriRace>[];

      for (final d in hostSnap.docs) {
        if (seen.add(d.id)) {
          results.add(TriRace.fromMap(d.id, d.data() as Map<String, dynamic>));
        }
      }
      for (final d in participantSnap.docs) {
        if (seen.add(d.id)) {
          results.add(TriRace.fromMap(d.id, d.data() as Map<String, dynamic>));
        }
      }

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  // ──────────────────────────── Race Actions ───────────────────────────────

  /// Host starts the race: generates finishTimeMs, placement, speedSeed
  /// for all participants in a single WriteBatch.
  Future<void> startTriRace(String raceId, String hostId) async {
    try {
      final raceDoc = await _triRaces.doc(raceId).get();
      if (!raceDoc.exists) throw const TriRaceException('Race not found.');
      final raceData = raceDoc.data() as Map<String, dynamic>;
      if (raceData['hostId'] != hostId) {
        throw const TriRaceException('Only the host can start the race.');
      }

      final participantsSnap = await _participants(raceId).orderBy('joinedAt').get();
      final participants = participantsSnap.docs;
      if (participants.length < 2) {
        throw const TriRaceException('Need at least 2 participants to start.');
      }

      final rng = Random();
      final batch = _db.batch();

      // Generate finishTimeMs for each participant (6000–14000ms)
      final List<MapEntry<String, int>> finishTimes = [];
      for (final p in participants) {
        final finishMs = 6000 + rng.nextInt(8001); // 6000–14000
        finishTimes.add(MapEntry(p.id, finishMs));
      }

      // Sort ascending and enforce 400ms minimum gap
      finishTimes.sort((a, b) => a.value.compareTo(b.value));
      for (int i = 1; i < finishTimes.length; i++) {
        final prev = finishTimes[i - 1].value;
        final curr = finishTimes[i].value;
        if (curr - prev < 400) {
          finishTimes[i] = MapEntry(finishTimes[i].key, prev + 400);
        }
      }

      // Assign placements and write participant docs
      final maxFinishMs = finishTimes.last.value;
      for (int i = 0; i < finishTimes.length; i++) {
        final pId = finishTimes[i].key;
        final finishMs = finishTimes[i].value;
        final speedSeed = rng.nextDouble() * 1000;

        batch.update(_participants(raceId).doc(pId), {
          'finishTimeMs': finishMs,
          'placement': i + 1,
          'speedSeed': speedSeed,
        });
      }

      // Update main race doc
      final now = DateTime.now();
      batch.update(_triRaces.doc(raceId), {
        'status': TriRaceStatus.started.value,
        'raceStartedAt': Timestamp.fromDate(now),
        'raceDurationMs': maxFinishMs,
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to start race: ${e.message}');
    }
  }

  Future<void> removeParticipant(String raceId, String userId) async {
    try {
      final batch = _db.batch();
      batch.delete(_participants(raceId).doc(userId));
      batch.update(_triRaces.doc(raceId), {
        'participantUids': FieldValue.arrayRemove([userId]),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to leave race: ${e.message}');
    }
  }

  Future<void> addBot(String raceId) async {
    try {
      final raceDoc = await _triRaces.doc(raceId).get();
      if (!raceDoc.exists) throw const TriRaceException('Race not found.');
      final raceData = raceDoc.data() as Map<String, dynamic>;
      final participantUids = (raceData['participantUids'] as List?)?.cast<String>() ?? [];
      final maxPlayers = raceData['maxPlayers'] as int? ?? 4;

      if (participantUids.length >= maxPlayers) {
        throw const TriRaceException('Race is full.');
      }

      final botNumber = participantUids.where((uid) => uid.startsWith('bot_')).length + 1;
      final botId = 'bot_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(0, 6)}';
      final botName = 'Bot $botNumber';
      final colorIndex = participantUids.length % _palette.length;
      final avatarColor = _palette[colorIndex];

      final batch = _db.batch();

      batch.set(_participants(raceId).doc(botId), {
        'userId': botId,
        'username': botName,
        'joinedAt': FieldValue.serverTimestamp(),
        'avatarColor': avatarColor,
      });

      batch.update(_triRaces.doc(raceId), {
        'participantUids': FieldValue.arrayUnion([botId]),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to add bot: ${e.message}');
    }
  }

  Future<void> cancelTriRace(String raceId, String hostId) async {
    try {
      final doc = await _triRaces.doc(raceId).get();
      if (!doc.exists) throw const TriRaceException('Race not found.');
      final data = doc.data() as Map<String, dynamic>;
      if (data['hostId'] != hostId) {
        throw const TriRaceException('Only the host can cancel the race.');
      }
      await _triRaces.doc(raceId).update({
        'status': TriRaceStatus.cancelled.value,
        'deletedBy': hostId,
      });
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to cancel race: ${e.message}');
    }
  }

  Future<void> markTriRaceFinished(String raceId) async {
    try {
      final doc = await _triRaces.doc(raceId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] != TriRaceStatus.started.value) return;
      await _triRaces.doc(raceId).update({
        'status': TriRaceStatus.finished.value,
      });
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to finish race: ${e.message}');
    }
  }

  Future<void> markInvited({
    required String raceId,
    required String hostId,
    required List<String> invitedUserIds,
  }) async {
    try {
      final doc = await _triRaces.doc(raceId).get();
      if (!doc.exists) throw const TriRaceException('Race not found.');
      final data = doc.data() as Map<String, dynamic>;
      if (data['hostId'] != hostId) {
        throw const TriRaceException('Only the host can send invites.');
      }
      await _triRaces.doc(raceId).update({
        'invitedUserIds': FieldValue.arrayUnion(invitedUserIds),
      });
    } on FirebaseException catch (e) {
      throw TriRaceException('Failed to mark invited users: ${e.message}');
    }
  }
}

class TriRaceException implements Exception {
  final String message;
  const TriRaceException(this.message);

  @override
  String toString() => 'TriRaceException: $message';
}
