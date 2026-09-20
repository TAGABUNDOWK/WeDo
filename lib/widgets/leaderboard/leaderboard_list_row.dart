import 'package:flutter/material.dart';
import '../../models/user_stats_entity.dart';
import 'leaderboard_avatar.dart';

const _font = 'PlusJakartaSans';

/// A single ranked list row (ranks 4+) or the pinned current-user row.
class LeaderboardListRow extends StatelessWidget {
  final UserStatsEntity entry;
  final int rank;
  final String field;
  final bool isCurrentUser;
  final String? rankLabel;
  final bool favorited;
  final VoidCallback onStarToggle;
  final String? score;
  final String? nameOverride;

  const LeaderboardListRow({
    super.key,
    required this.entry,
    required this.rank,
    required this.field,
    required this.isCurrentUser,
    required this.favorited,
    required this.onStarToggle,
    this.rankLabel,
    this.score,
    this.nameOverride,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isCurrentUser
            ? const Color(0xFFFF4FD8).withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFFFF4FD8).withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.06),
          width: isCurrentUser ? 1.4 : 1,
        ),
        boxShadow: isCurrentUser
            ? [
                BoxShadow(
                  color: const Color(0xFFFF4FD8).withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              rankLabel ?? '#$rank',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCurrentUser
                    ? const Color(0xFFFF4FD8)
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
          LeaderboardAvatar(asset: entry.avatarAsset, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nameOverride ?? entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _font,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isCurrentUser
                    ? const Color(0xFFFF4FD8)
                    : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score ?? '${entry.scoreFor(field)}',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isCurrentUser
                  ? const Color(0xFFFF4FD8)
                  : Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onStarToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                favorited ? Icons.star : Icons.star_outline,
                size: 20,
                color: favorited
                    ? const Color(0xFFFFC93C)
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}