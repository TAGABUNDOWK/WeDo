import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/friend_entity.dart';
import '../../models/user_stats_entity.dart';
import '../../services/leaderboard/leaderboard_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/auth/user_service.dart';
import '../../services/session/session_service.dart';
import '../../services/tri_race/tri_race_service.dart';
import 'leaderboard_podium.dart';
import 'leaderboard_list_row.dart';

const _font = 'PlusJakartaSans';
const _magenta = Color(0xFFFF4FD8);
const _violetStart = Color(0xFF8A2BE2);
const _violetEnd = Color(0xFFB341F5);
const _gold = Color(0xFFFFC93C);

/// Embedded leaderboard for the Home tab — full top-10 podium + list,
/// scope tabs, category dropdown, and a pinned current-user row.
class LeaderboardSection extends StatefulWidget {
  const LeaderboardSection({super.key});

  @override
  State<LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<LeaderboardSection> {
  final LeaderboardService _service = LeaderboardService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendService _friendService = FriendService();

  LeaderboardScope _scope = LeaderboardScope.overall;
  LeaderboardCategory _category = LeaderboardCategory.pickFightWins;
  final Set<String> _favorites = <String>{};
  List<String> _friendUids = const [];
  StreamSubscription<List<FriendEntity>>? _friendsSub;
  Timer? _friendsTimer;

  String get _uid => _auth.currentUser?.uid ?? '';

  int get _listUpperBound => 10;

  @override
  void initState() {
    super.initState();
    _backfillStats();
    _subscribeFriends();
    _friendsTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (!mounted) return;
        if (_scope == LeaderboardScope.friends) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _friendsTimer?.cancel();
    super.dispose();
  }

  Future<void> _backfillStats() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      final user = await UserService().getUserDocument(uid);
      final sessionService = SessionService();
      final triRaceService = TriRaceService();
      final totalMatches =
          await sessionService.getUserTotalMatches(uid) +
          await triRaceService.getUserTotalTriRaces(uid);
      final pickFightWins = await sessionService.getUserPickFightWins(uid);
      final triRaceWins = await triRaceService.getUserTriRaceWins(uid);
      await _service.ensureUserStats(
        uid: uid,
        displayName: user?.displayName ?? '',
        avatarAsset: user?.avatarAsset,
        totalMatchesPlayed: totalMatches,
        pickFightWins: pickFightWins,
        triRaceWins: triRaceWins,
      );
    } catch (_) {}
  }

  void _subscribeFriends() {
    final uid = _uid;
    if (uid.isEmpty) return;
    _friendsSub = _friendService.getFriendsStream(uid).listen((friends) {
      final uids = <String>[];
      for (final f in friends) {
        final other = f.otherUserId(uid);
        if (other.isNotEmpty) uids.add(other);
      }
      uids.add(uid);
      if (!mounted) return;
      setState(() => _friendUids = uids);
    });
  }

  void _toggleFavorite(UserStatsEntity entry) {
    setState(() {
      if (!_favorites.remove(entry.userId)) {
        _favorites.add(entry.userId);
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildScopeTabs(),
        const SizedBox(height: 12),
        _buildCategoryDropdown(),
        const SizedBox(height: 10),
        _buildShowing(),
        const SizedBox(height: 18),
        _buildStandings(),
        const SizedBox(height: 14),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('✦',
                    style: TextStyle(color: _gold, fontSize: 16)),
                const SizedBox(width: 10),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_gold, Color(0xFFFFF3D6), _gold],
                  ).createShader(bounds),
                  child: const Text(
                    'Leaderboards',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Color(0x99F5A623), blurRadius: 18),
                        Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('✦',
                    style: TextStyle(color: _gold, fontSize: 16)),
              ],
            ),
            Positioned(
              right: 0,
              child: GestureDetector(
                onTap: _showLeaderboardInfo,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.question_mark_rounded,
                    size: 14,
                    color: Color(0xFFB9AFCB),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Climb the arcade trophy ranks',
          style: TextStyle(
            fontFamily: _font,
            fontSize: 12,
            color: Color(0xFFB9AFCB),
          ),
        ),
      ],
    );
  }

  void _showLeaderboardInfo() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Leaderboard Info',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, a1, a2, child) {
        return FadeTransition(
          opacity: a1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, a1, a2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.82,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1233),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.leaderboard,
                          color: Color(0xFFFE4EF0),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'How Leaderboards Work',
                          style: TextStyle(
                            fontFamily: _font,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, color: Colors.white54, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _infoRow(
                    Icons.autorenew,
                    'Daily Refresh',
                    'Rankings are recomputed every day at midnight (Asia/Manila).',
                  ),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.bolt,
                    'Instant Personal Rank',
                    'Your own rank updates right after every match — no need to wait for the daily refresh.',
                  ),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.emoji_events,
                    'What Counts',
                    'Wins in PickFight and TriRace, plus total matches played.',
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF800DD8), Color(0xFFFE4EF0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Got it',
                          style: TextStyle(
                            fontFamily: _font,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFFE4EF0), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  color: Color(0xFFB9AFCB),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScopeTabs() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          _scopeTab(LeaderboardScope.overall, 'Overall'),
          _scopeTab(LeaderboardScope.friends, 'Friends'),
        ],
      ),
    );
  }

  Widget _scopeTab(LeaderboardScope scope, String label) {
    final active = _scope == scope;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _scope = scope),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_violetStart, _violetEnd],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _violetEnd.withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: _font,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFFB9AFCB),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return PopupMenuButton<LeaderboardCategory>(
      offset: const Offset(0, 48),
      color: const Color(0xFF241040),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (category) => setState(() => _category = category),
      itemBuilder: (context) =>
          LeaderboardCategory.all.map((c) {
            return PopupMenuItem<LeaderboardCategory>(
              value: c,
              child: Row(
                children: [
                  Icon(
                    c == _category ? Icons.check : null,
                    color: _magenta,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.label,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart, size: 18, color: _violetEnd),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _category.label,
                style: const TextStyle(
                  fontFamily: _font,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.expand_more, size: 20, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildShowing() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.emoji_events, size: 16, color: _gold),
        const SizedBox(width: 6),
        const Text(
          'Showing: ',
          style: TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFFB9AFCB),
          ),
        ),
        Text(
          _category.label,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _magenta,
          ),
        ),
      ],
    );
  }

  // ── Standings (podium + list + pinned row) ──────────────────────────────

  Widget _buildStandings() {
    if (_scope == LeaderboardScope.overall) {
      return StreamBuilder<List<UserStatsEntity>>(
        stream: _service.overallStandingsStream(_category.field),
        builder: (context, snap) =>
            _standings(snap.data ?? const [], snap.connectionState, snap.hasError),
      );
    }
    return FutureBuilder<List<UserStatsEntity>>(
      future: _service.friendsStandings(_category.field, _friendUids),
      builder: (context, fs) =>
          _standings(fs.data ?? const [], fs.connectionState, fs.hasError),
    );
  }

  Widget _standings(
    List<UserStatsEntity> raw,
    ConnectionState state,
    bool hasError,
  ) {
    if (hasError) {
      return _errorState();
    }
    if (state == ConnectionState.waiting && raw.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: _magenta),
        ),
      );
    }
    final sorted = _service.sortBy(_category.field, raw);
    if (sorted.isEmpty) {
      return _emptyState('No players on the board yet — go play a match!');
    }

    final podium = sorted.take(3).toList();
    final rest = sorted.skip(3).take(_listUpperBound - 3).toList();

    return Column(
      children: [
        LeaderboardPodium(
          entries: podium,
          currentUid: _uid,
          field: _category.field,
          favorites: _favorites,
          onStarToggle: _toggleFavorite,
        ),
        const SizedBox(height: 14),
        _buildListContainer(rest, podium, sorted),
      ],
    );
  }

  Widget _buildListContainer(
    List<UserStatsEntity> rest,
    List<UserStatsEntity> podium,
    List<UserStatsEntity> sorted,
  ) {
    final uid = _uid;
    final userInTop = uid.isNotEmpty &&
        (sorted.take(_listUpperBound).any((e) => e.userId == uid));

    Widget rows = const SizedBox.shrink();
    if (rest.isNotEmpty) {
      rows = Column(
        children: [
          for (final (index, entry) in rest.indexed) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            LeaderboardListRow(
              entry: entry,
              rank: index + 4,
              field: _category.field,
              isCurrentUser: entry.userId == uid,
              favorited: _favorites.contains(entry.userId),
              onStarToggle: () => _toggleFavorite(entry),
            ),
          ],
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          if (rest.isNotEmpty) rows,
          if (!userInTop && uid.isNotEmpty) ...[
            if (rest.isNotEmpty)
              Divider(height: 18, thickness: 1, color: Colors.white.withValues(alpha: 0.10)),
            _pinnedCurrentUserRow(),
          ],
          if (rest.isEmpty && (userInTop || uid.isEmpty))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'There aren’t enough players ranked yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  color: Color(0xFFB9AFCB),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pinnedCurrentUserRow() {
    final uid = _uid;
    return StreamBuilder<UserStatsEntity?>(
      stream: _service.getUserStatsStream(uid),
      builder: (context, snap) {
        final own = snap.data;
        if (own == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _magenta,
                ),
              ),
            ),
          );
        }
        return FutureBuilder<int>(
          future: _service.getUserRank(uid, _category.field),
          builder: (context, rankSnap) {
            final rank = rankSnap.data ?? 0;
            return LeaderboardListRow(
              entry: own,
              rank: rank,
              field: _category.field,
              rankLabel: '..',
              nameOverride: 'You',
              isCurrentUser: true,
              favorited: true,
              onStarToggle: () {},
              score: '${own.scoreFor(_category.field)}',
            );
          },
        );
      },
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('✦', style: TextStyle(color: _gold, fontSize: 12)),
        const SizedBox(width: 8),
        Text(
          'Keep playing to climb higher!',
          style: TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 8),
        const Text('✦', style: TextStyle(color: _gold, fontSize: 12)),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 34, color: Color(0xFFB9AFCB)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: Color(0xFFB9AFCB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFFB9AFCB), size: 28),
          const SizedBox(height: 8),
          const Text(
            'Couldn’t load leaderboards.',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: Color(0xFFB9AFCB),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() {}),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontFamily: _font,
                fontWeight: FontWeight.w700,
                color: _magenta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}