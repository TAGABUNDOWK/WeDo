import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_stats_entity.dart';
import '../../utils/constants.dart';

/// Leaderboard stat categories. Field name maps to the Firestore `userStats`
/// key; changing the order here changes the dropdown order.
class LeaderboardCategory {
  final String field;
  final String label;

  const LeaderboardCategory._(this.field, this.label);

  static const totalMatchesPlayed =
      LeaderboardCategory._('total_matches_played', 'Total Matches Played');
  static const pickFightWins =
      LeaderboardCategory._('pick_fight_wins', 'PickFight Wins');
  static const triRaceWins =
      LeaderboardCategory._('tri_race_wins', 'TriRace Wins');

  static const all = [pickFightWins, totalMatchesPlayed, triRaceWins];

  /// Returns the precomputed rank field name in the `leaderboards` collection
  /// for this category.
  String get rankField => 'rank_$field';
}

enum LeaderboardScope { overall, friends }

class LeaderboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _stats =>
      _db.collection(AppConstants.userStatsCollection);

  CollectionReference<Map<String, dynamic>> get _leaderboards =>
      _db.collection(AppConstants.leaderboardsCollection);

  // ── Leaderboard reads (from derived `leaderboards` collection) ──────────

  /// Overall standings streamed from the `leaderboards` snapshot collection,
  /// ordered by the precomputed rank field ascending (rank 1 first).
  Stream<List<UserStatsEntity>> overallStandingsStream(
    String field, {
    int limit = 30,
  }) {
    final rankField = 'rank_$field';
    return _leaderboards
        .orderBy(rankField, descending: false)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserStatsEntity.fromMap(d.id, d.data()))
            .toList());
  }

  /// Friends-only standings from the `leaderboards` snapshot collection.
  /// `whereIn` supports up to 10 values per query, so larger lists are
  /// chunked and merged client-side.
  Future<List<UserStatsEntity>> friendsStandings(
    String field,
    List<String> uids,
  ) async {
    if (uids.isEmpty) return const [];
    final all = <UserStatsEntity>[];
    for (var i = 0; i < uids.length; i += 10) {
      final chunk =
          uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10);
      final snap =
          await _leaderboards.where('user_id', whereIn: chunk).limit(100).get();
      all.addAll(
        snap.docs.map((d) => UserStatsEntity.fromMap(d.id, d.data())),
      );
    }
    return all;
  }

  /// Resolves a user's rank from the precomputed `leaderboards` doc.
  /// Returns 1 if the doc doesn't exist yet (bootstrap fallback).
  Future<int> getUserRank(String uid, String field) async {
    try {
      final rankField = 'rank_$field';
      final doc = await _leaderboards.doc(uid).get();
      if (!doc.exists) return 1;
      return (doc.data()?[rankField] as num?)?.toInt() ?? 1;
    } catch (e) {
      return 1;
    }
  }

  /// Live stream of a single user's stats document (from `userStats`).
  /// Used by the pinned "You" row to show live score numbers.
  Stream<UserStatsEntity?> getUserStatsStream(String uid) {
    return _stats.doc(uid).snapshots().map(
          (snap) => snap.exists
              ? UserStatsEntity.fromMap(snap.id, snap.data() ?? const {})
              : null,
        );
  }

  // ── Sort helper ────────────────────────────────────────────────────────

  /// Sorts a list by [field] descending with an alphabetical tiebreaker.
  List<UserStatsEntity> sortBy(String field, List<UserStatsEntity> entries) {
    final copy = List<UserStatsEntity>.from(entries);
    copy.sort((a, b) {
      final score = b.scoreFor(field).compareTo(a.scoreFor(field));
      if (score != 0) return score;
      return a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase());
    });
    return copy;
  }

  // ── Writes to `userStats` (source of truth — unchanged) ────────────────

  /// Lazily backfills a user's stats doc when it is missing, and refreshes
  /// their denormalized identity. Existing counters are never overwritten.
  /// Also writes a bootstrap fallback to the `leaderboards` collection so the
  /// user appears on the board immediately without waiting for a recompute.
  Future<void> ensureUserStats({
    required String uid,
    required String displayName,
    String? avatarAsset,
    required int totalMatchesPlayed,
    required int pickFightWins,
    required int triRaceWins,
  }) async {
    final ref = _stats.doc(uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'user_id': uid,
        'display_name': displayName,
        'avatar_asset': avatarAsset,
        'total_matches_played': totalMatchesPlayed,
        'pick_fight_wins': pickFightWins,
        'tri_race_wins': triRaceWins,
      });
    } else {
      await ref.set({
        'display_name': displayName,
        'avatar_asset': avatarAsset,
      }, SetOptions(merge: true));
    }

    // Bootstrap: write the leaderboard doc so the user shows up immediately.
    await _backfillLeaderboardDoc(
      uid: uid,
      displayName: displayName,
      avatarAsset: avatarAsset,
      totalMatchesPlayed: totalMatchesPlayed,
      pickFightWins: pickFightWins,
      triRaceWins: triRaceWins,
    );
  }

  /// Writes a bootstrap leaderboard doc for a single user. This gives the
  /// user a leaderboard entry immediately (rank will be recomputed by the
  /// scheduled function within 5 minutes).
  Future<void> _backfillLeaderboardDoc({
    required String uid,
    required String displayName,
    String? avatarAsset,
    required int totalMatchesPlayed,
    required int pickFightWins,
    required int triRaceWins,
  }) async {
    try {
      await _leaderboards.doc(uid).set({
        'user_id': uid,
        'display_name': displayName,
        'avatar_asset': avatarAsset,
        'total_matches_played': totalMatchesPlayed,
        'pick_fight_wins': pickFightWins,
        'tri_race_wins': triRaceWins,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Records a finished PickFight session against every participant's stats:
  /// total matches +1 for all, a win +1 for the speed-shield winner.
  Future<void> recordPickFightResult({
    required List<String> participantIds,
    required String winnerId,
  }) async {
    await _recordResult(
      participantIds: participantIds,
      winnerId: winnerId,
      winsField: 'pick_fight_wins',
    );
  }

  /// Records a finished TriRace against every participant's stats.
  Future<void> recordTriRaceResult({
    required List<String> participantIds,
    required String winnerId,
  }) async {
    await _recordResult(
      participantIds: participantIds,
      winnerId: winnerId,
      winsField: 'tri_race_wins',
    );
  }

  Future<void> _recordResult({
    required List<String> participantIds,
    required String winnerId,
    required String winsField,
  }) async {
    final real = participantIds.where(_isRealUser).toSet();
    if (real.isEmpty) return;

    final identities = await _fetchIdentities(real);
    final batch = _db.batch();

    for (final id in real) {
      // Always write all three counters so every stats doc is orderable on
      // each leaderboard category (missing fields are excluded by orderBy).
      // Zero-increments materialize the win fields; the winner's extra +1
      // is applied below.
      final batchRef = _stats.doc(id);
      batch.set(batchRef, {
        'user_id': id,
        'total_matches_played': FieldValue.increment(1),
        'pick_fight_wins': FieldValue.increment(0),
        'tri_race_wins': FieldValue.increment(0),
        if (identities[id] != null) ...identities[id]!,
      }, SetOptions(merge: true));
    }

    if (_isRealUser(winnerId) && real.contains(winnerId)) {
      batch.set(_stats.doc(winnerId), {
        'user_id': winnerId,
        winsField: FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
    } catch (e) {
      // Never block gameplay on leaderboard bookkeeping.
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchIdentities(
    Iterable<String> uids,
  ) async {
    final output = <String, Map<String, dynamic>>{};
    try {
      final docs = await Future.wait(
        uids.map(
            (id) => _db.collection(AppConstants.usersCollection).doc(id).get()),
      );
      for (final doc in docs) {
        if (!doc.exists) continue;
        final data = doc.data() ?? const {};
        output[doc.id] = {
          'display_name': data['display_name'] as String? ?? '',
          'avatar_asset': data['avatar_asset'] as String?,
        };
      }
    } catch (_) {}
    return output;
  }

  bool _isRealUser(String uid) => uid.isNotEmpty && !uid.startsWith('bot_');
}
