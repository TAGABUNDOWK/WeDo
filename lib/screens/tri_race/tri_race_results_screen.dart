import 'package:flutter/material.dart';
import '../../models/tri_race_entity.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../services/tri_race/tri_race_refresh_notifier.dart';
import '../../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

class TriRaceResultsScreen extends StatefulWidget {
  final String raceId;
  const TriRaceResultsScreen({super.key, required this.raceId});

  @override
  State<TriRaceResultsScreen> createState() => _TriRaceResultsScreenState();
}

class _TriRaceResultsScreenState extends State<TriRaceResultsScreen> {
  final _service = TriRaceService();
  final Map<String, String> _displayNames = {};
  final Set<String> _nameQueued = {};

  // Resolve real profile display names (users/{id}.display_name) once per uid
  // so gmail fallbacks never show in the results.
  void _resolveNames(List<TriRaceParticipant> participants) {
    final missing = participants
        .map((p) => p.userId)
        .where((id) => !_nameQueued.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _nameQueued.addAll(missing);
    _service.fetchDisplayNames(missing).then((names) {
      if (!mounted) return;
      setState(() => _displayNames.addAll(names));
    });
  }

  @override
  void dispose() {
    // Restore portrait when leaving results
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      appBar: AppBar(
        backgroundColor: const Color(0xFF190831),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Race Results',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: StreamBuilder<TriRace?>(
        stream: _service.getTriRaceStream(widget.raceId),
        builder: (context, raceSnapshot) {
          if (raceSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final race = raceSnapshot.data;
          if (race == null) {
            return const Center(child: Text('Race not found', style: TextStyle(color: Colors.white)));
          }

          return StreamBuilder<List<TriRaceParticipant>>(
            stream: _service.getParticipantsStream(widget.raceId),
            builder: (context, participantSnapshot) {
              final participants = participantSnapshot.data ?? [];
              _resolveNames(participants);
              final sorted = List<TriRaceParticipant>.from(participants)
                ..sort((a, b) => (a.placement ?? 999).compareTo(b.placement ?? 999));

              final winner = sorted.isNotEmpty ? sorted.first : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ── Winner Card ──
                    if (winner != null) ...[
                      _WinnerCard(
                        winner: winner,
                        totalPlayers: participants.length,
                        names: _displayNames,
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Leaderboard ──
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Leaderboard',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...sorted.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value;
                      return _LeaderboardRow(
                        participant: p,
                        rank: i + 1,
                        names: _displayNames,
                      );
                    }),
                    const SizedBox(height: 32),

                    // ── Back Home Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          TriRaceRefreshNotifier.instance.notifyRefresh();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Back to Home',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  final TriRaceParticipant winner;
  final int totalPlayers;
  final Map<String, String> names;
  const _WinnerCard({
    required this.winner,
    required this.totalPlayers,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(winner.avatarColor.replaceFirst('#', '0xFF')));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D2B00), Color(0xFF7A5A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            '🏆',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            names[winner.userId] ?? winner.username,
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalPlayers players',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: CustomPaint(
                  size: const Size(18, 16),
                  painter: _MiniTrianglePainter(Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '1st Place',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final TriRaceParticipant participant;
  final int rank;
  final Map<String, String> names;
  const _LeaderboardRow({
    required this.participant,
    required this.rank,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(participant.avatarColor.replaceFirst('#', '0xFF')));
    final medals = ['🥇', '🥈', '🥉'];
    final medal = rank <= 3 ? medals[rank - 1] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: rank == 1
            ? const Color(0xFF7A5A00).withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: rank == 1
            ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3))
            : Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 20))
                : Text(
                    '$rank',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(18, 16),
              painter: _MiniTrianglePainter(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  names[participant.userId] ?? participant.username,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: rank == 1 ? const Color(0xFFFFD700) : Colors.white,
                  ),
                ),
                if (participant.finishTimeMs != null)
                  Text(
                    '${(participant.finishTimeMs! / 1000).toStringAsFixed(2)}s',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTrianglePainter extends CustomPainter {
  final Color color;
  _MiniTrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
