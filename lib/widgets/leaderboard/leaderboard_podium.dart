import 'package:flutter/material.dart';
import '../../models/user_stats_entity.dart';
import 'leaderboard_avatar.dart';

const _font = 'PlusJakartaSans';

class _Tier {
  final String crown;
  final Color crownColor;
  final List<Color> gradient;
  final Color glow;
  final double avatarSize;
  final double ringGlow;
  final double blockHeight;
  final String medal;
  final Color scoreColor;

  const _Tier({
    required this.crown,
    required this.crownColor,
    required this.gradient,
    required this.glow,
    required this.avatarSize,
    required this.ringGlow,
    required this.blockHeight,
    required this.medal,
    required this.scoreColor,
  });
}

const _gold = _Tier(
  crown: '♛',
  crownColor: Color(0xFFFFC93C),
  gradient: [Color(0xFFFFC93C), Color(0xFFF5A623)],
  glow: Color(0xFFFFC93C),
  avatarSize: 68,
  ringGlow: 22,
  blockHeight: 96,
  medal: '1',
  scoreColor: Color(0xFFFFE08A),
);

const _silver = _Tier(
  crown: '♛',
  crownColor: Color(0xFFC9CDD6),
  gradient: [Color(0xFFC9CDD6), Color(0xFF9EA4B0)],
  glow: Color(0xFFC9CDD6),
  avatarSize: 54,
  ringGlow: 12,
  blockHeight: 90,
  medal: '2',
  scoreColor: Color(0xFFE7EAF0),
);

const _bronze = _Tier(
  crown: '♛',
  crownColor: Color(0xFFD98A4B),
  gradient: [Color(0xFFD98A4B), Color(0xFFB5652E)],
  glow: Color(0xFFD98A4B),
  avatarSize: 54,
  ringGlow: 12,
  blockHeight: 90,
  medal: '3',
  scoreColor: Color(0xFFF0B37E),
);

/// Top-3 podium: 2nd (left), 1st (center, elevated), 3rd (right).
class LeaderboardPodium extends StatelessWidget {
  final List<UserStatsEntity> entries;
  final String currentUid;
  final String field;
  final Set<String> favorites;
  final void Function(UserStatsEntity)? onStarToggle;

  const LeaderboardPodium({
    super.key,
    required this.entries,
    required this.currentUid,
    required this.field,
    required this.favorites,
    this.onStarToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // entries are provided in rank order [1st, 2nd, 3rd]; reorder visually.
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length >= 2 ? entries[1] : null;
    final third = entries.length >= 3 ? entries[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (second != null)
          Expanded(child: _column(second, rank: 2, tier: _silver)),
        if (first != null)
          Expanded(child: _column(first, rank: 1, tier: _gold)),
        if (third != null)
          Expanded(child: _column(third, rank: 3, tier: _bronze)),
      ],
    );
  }

  Widget _column(UserStatsEntity entry, {required int rank, required _Tier tier}) {
    final isCurrent = entry.userId == currentUid;
    final favorited = favorites.contains(entry.userId);

    return Padding(
      padding: EdgeInsets.only(bottom: rank == 1 ? 0 : 24, top: rank == 1 ? 8 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tier.crown,
            style: TextStyle(
              fontSize: rank == 1 ? 26 : 20,
              color: tier.crownColor,
              shadows: [
                Shadow(
                  color: tier.glow.withValues(alpha: 0.8),
                  blurRadius: rank == 1 ? 14 : 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _avatar(entry, tier, isCurrent),
          const SizedBox(height: 6),
          _block(entry, tier, isCurrent, favorited),
        ],
      ),
    );
  }

  Widget _avatar(UserStatsEntity entry, _Tier tier, bool isCurrent) {
    const ring = 9.0;
    return SizedBox(
      width: tier.avatarSize + ring * 2,
      height: tier.avatarSize + ring * 2,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tier.gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? const Color(0xFFFF4FD8).withValues(alpha: 0.75)
                  : tier.glow.withValues(alpha: 0.5),
              blurRadius: tier.ringGlow,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: LeaderboardAvatar(asset: entry.avatarAsset, size: tier.avatarSize),
          ),
        ),
      ),
    );
  }

  Widget _block(UserStatsEntity entry, _Tier tier, bool isCurrent, bool favorited) {
    return Container(
      width: 96,
      height: tier.blockHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFFF4FD8).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.14),
          width: 1.5,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFFFF4FD8).withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tier.gradient.first.withValues(alpha: 0.32),
            tier.gradient.last.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4FD8).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF4FD8),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${entry.scoreFor(field)}',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tier.scoreColor,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onStarToggle == null
                      ? null
                      : () => onStarToggle!(entry),
                  child: Icon(
                    favorited ? Icons.star : Icons.star_outline,
                    size: 15,
                    color: favorited ? const Color(0xFFFFC93C) : Colors.white54,
                  ),
                ),
              ],
            ),
            _medal(tier.medal),
          ],
        ),
      ),
    );
  }

  Widget _medal(String numeral) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        numeral,
        style: const TextStyle(
          fontFamily: _font,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}