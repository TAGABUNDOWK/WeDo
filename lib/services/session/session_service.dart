import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/topic_entity.dart';
import '../../models/session_entity.dart';
import '../../utils/constants.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _sessions =>
      _db.collection(AppConstants.sessionsCollection);

  CollectionReference _participants(String sessionId) =>
      _sessions.doc(sessionId).collection(AppConstants.participantsSubcollection);

  CollectionReference get _topics =>
      _db.collection(AppConstants.topicsCollection);

  CollectionReference _cards(String topicId) =>
      _topics.doc(topicId).collection(AppConstants.cardsSubcollection);

  // ──────────────────────────── Topics & Cards ────────────────────────────

  Future<List<TopicEntity>> getTopics() async {
    try {
      final snap = await _topics.get();
      return snap.docs
          .map((doc) => TopicEntity.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } on FirebaseException catch (e) {
      throw SessionException('Failed to load topics: ${e.message}');
    }
  }

  Future<List<CardEntity>> getCards(String topicId) async {
    try {
      final snap = await _cards(topicId).get();
      return snap.docs
          .map((doc) => CardEntity.fromMap(
                doc.id,
                topicId,
                doc.data() as Map<String, dynamic>,
              ))
          .toList();
    } on FirebaseException catch (e) {
      throw SessionException('Failed to load cards: ${e.message}');
    }
  }

  List<CardEntity> pickRandomCards(List<CardEntity> cards, {int count = 10}) {
    final shuffled = List<CardEntity>.from(cards)..shuffle(Random());
    return shuffled.take(count).toList();
  }

  // ──────────────────────────── Session CRUD ──────────────────────────────

  /// Generates a unique 6-char alphanumeric session code.
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();

    for (int attempt = 0; attempt < 10; attempt++) {
      final code = String.fromCharCodes(
        Iterable.generate(6, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
      );
      final existing = await _sessions.doc(code).get();
      if (!existing.exists) return code;
    }
    throw SessionException('Failed to generate unique session code. Try again.');
  }

  /// Creates a new session document with status "lobby".
  /// Returns the generated 6-char session code.
  Future<String> createSession({
    required String hostId,
    required String topic,
    required List<Map<String, dynamic>> cards,
  }) async {
    try {
      final code = await _generateUniqueCode();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final sessionData = {
        'sessionId': code,
        'hostId': hostId,
        'topic': topic,
        'status': SessionStatus.lobby.value,
        'cards': cards,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
      };

      await _sessions.doc(code).set(sessionData);
      return code;
    } on FirebaseException catch (e) {
      throw SessionException('Failed to create session: ${e.message}');
    }
  }

  /// Validates a session code exists and is in "lobby" status.
  Future<SessionEntity> validateSessionCode(String code) async {
    try {
      final doc = await _sessions.doc(code).get();
      if (!doc.exists) {
        throw SessionException('Session not found. Check the code and try again.');
      }
      final session = SessionEntity.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
      if (session.status != SessionStatus.lobby) {
        throw SessionException('Session already started or ended.');
      }
      return session;
    } on FirebaseException catch (e) {
      throw SessionException('Failed to validate session: ${e.message}');
    }
  }

  /// Adds a participant to a session's participants subcollection.
  Future<void> joinSession({
    required String sessionId,
    required String userId,
    required String userName,
  }) async {
    try {
      final participantDoc = _participants(sessionId).doc(userId);
      final existing = await participantDoc.get();
      if (existing.exists) return;

      await participantDoc.set({
        'userName': userName,
        'status': ParticipantStatus.active.value,
        'eliminatedCardIds': [],
        'timeoutCount': 0,
      });
    } on FirebaseException catch (e) {
      throw SessionException('Failed to join session: ${e.message}');
    }
  }

  // ──────────────────────────── Real-time Streams ─────────────────────────

  /// Streams the session document in real-time.
  Stream<SessionEntity?> getSessionStream(String sessionId) {
    return _sessions.doc(sessionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SessionEntity.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    });
  }

  /// Streams the participants subcollection in real-time.
  Stream<List<ParticipantEntity>> getParticipantsStream(String sessionId) {
    return _participants(sessionId).snapshots().map((snap) {
      return snap.docs
          .map((doc) => ParticipantEntity.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ))
          .toList();
    });
  }

  // ──────────────────────────── Session Actions ───────────────────────────

  /// Host starts the session: status "lobby" → "active".
  Future<void> startSession(String sessionId, String hostId) async {
    try {
      final doc = await _sessions.doc(sessionId).get();
      if (!doc.exists) throw SessionException('Session not found.');
      final data = doc.data() as Map<String, dynamic>;
      if (data['hostId'] != hostId) {
        throw SessionException('Only the host can start the session.');
      }
      await _sessions.doc(sessionId).update({'status': SessionStatus.active.value});
    } on FirebaseException catch (e) {
      throw SessionException('Failed to start session: ${e.message}');
    }
  }

  /// Host cancels the session: status → "cancelled".
  Future<void> cancelSession(String sessionId, String hostId) async {
    try {
      final doc = await _sessions.doc(sessionId).get();
      if (!doc.exists) throw SessionException('Session not found.');
      final data = doc.data() as Map<String, dynamic>;
      if (data['hostId'] != hostId) {
        throw SessionException('Only the host can cancel the session.');
      }
      await _sessions.doc(sessionId).update({'status': SessionStatus.cancelled.value});
    } on FirebaseException catch (e) {
      throw SessionException('Failed to cancel session: ${e.message}');
    }
  }

  /// Writes a participant's completion data when they finish the swiping game.
  Future<void> updateParticipantResult({
    required String sessionId,
    required String userId,
    required int elapsedTimeMs,
    required String chosenWinnerCardId,
    required List<String> eliminatedCardIds,
    required int timeoutCount,
  }) async {
    try {
      await _participants(sessionId).doc(userId).update({
        'status': ParticipantStatus.finished.value,
        'elapsedTimeMs': elapsedTimeMs,
        'chosenWinnerCardId': chosenWinnerCardId,
        'eliminatedCardIds': eliminatedCardIds,
        'timeoutCount': timeoutCount,
      });
    } on FirebaseException catch (e) {
      throw SessionException('Failed to save result: ${e.message}');
    }
  }

  /// Aggregates results from all finished participants.
  /// Computes card tally, winner card, and time-based standings.
  /// Should be called by the host or first finisher.
  Future<void> aggregateResults(String sessionId) async {
    try {
      final sessionDoc = await _sessions.doc(sessionId).get();
      if (!sessionDoc.exists) return;
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final sessionCards = (sessionData['cards'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final participantsSnap = await _participants(sessionId).get();
      final participants = participantsSnap.docs
          .map((doc) => ParticipantEntity.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ))
          .toList();

      final finished = participants.where((p) => p.status == ParticipantStatus.finished).toList();
      if (finished.isEmpty) return;

      // ── Card Tally: count eliminations per card across all participants ──
      final Map<String, int> eliminationCounts = {};
      for (final card in sessionCards) {
        final cardId = card['id'] as String;
        eliminationCounts[cardId] = 0;
      }
      for (final p in finished) {
        for (final cardId in p.eliminatedCardIds) {
          eliminationCounts[cardId] = (eliminationCounts[cardId] ?? 0) + 1;
        }
      }

      final Map<String, dynamic> cardTally = {};
      for (final card in sessionCards) {
        final cardId = card['id'] as String;
        cardTally[cardId] = {
          'title': card['title'] as String? ?? '',
          'eliminationCount': eliminationCounts[cardId] ?? 0,
        };
      }

      // ── Winner Card: most chosen as winner by participants ──
      final Map<String, int> winnerVotes = {};
      for (final p in finished) {
        if (p.chosenWinnerCardId != null && p.chosenWinnerCardId!.isNotEmpty) {
          winnerVotes[p.chosenWinnerCardId!] =
              (winnerVotes[p.chosenWinnerCardId!] ?? 0) + 1;
        }
      }

      String winnerCardId = '';
      String winnerCardTitle = '';
      if (winnerVotes.isNotEmpty) {
        final sortedVotes = winnerVotes.entries.toList()
          ..sort((a, b) {
            if (b.value != a.value) return b.value.compareTo(a.value);
            final aElims = eliminationCounts[a.key] ?? 999;
            final bElims = eliminationCounts[b.key] ?? 999;
            return aElims.compareTo(bElims);
          });
        winnerCardId = sortedVotes.first.key;
        final winnerCard = sessionCards.firstWhere(
          (c) => c['id'] == winnerCardId,
          orElse: () => {},
        );
        winnerCardTitle = winnerCard['title'] as String? ?? '';
      }

      // ── Standings: sorted by elapsed time (fastest first) ──
      final Map<String, dynamic> standings = {};
      for (final p in finished) {
        standings[p.id] = {
          'userName': p.userName,
          'elapsedTimeMs': p.elapsedTimeMs,
          'timeoutCount': p.timeoutCount,
          'chosenWinnerCardId': p.chosenWinnerCardId,
        };
      }

      final sortedEntries = standings.entries.toList()
        ..sort((a, b) {
          final timeA = a.value['elapsedTimeMs'] as int? ?? 999999;
          final timeB = b.value['elapsedTimeMs'] as int? ?? 999999;
          return timeA.compareTo(timeB);
        });

      final orderedStandings = <String, dynamic>{};
      for (final entry in sortedEntries) {
        orderedStandings[entry.key] = entry.value;
      }

      await _sessions.doc(sessionId).update({
        'status': SessionStatus.completed.value,
        'aggregatedResults': {
          'cardTally': cardTally,
          'winnerCardId': winnerCardId,
          'winnerCardTitle': winnerCardTitle,
          'totalParticipants': finished.length,
          'standings': orderedStandings,
        },
      });
    } on FirebaseException catch (e) {
      throw SessionException('Failed to aggregate results: ${e.message}');
    }
  }
}

/// Typed exception for session operations.
class SessionException implements Exception {
  final String message;
  const SessionException(this.message);

  @override
  String toString() => 'SessionException: $message';
}
