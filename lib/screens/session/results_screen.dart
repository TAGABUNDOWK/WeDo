import 'package:flutter/material.dart';
import '../../models/session_entity.dart';
import '../../services/session/session_service.dart';
import '../../services/session/session_refresh_notifier.dart';

class ResultsScreen extends StatefulWidget {
  final String sessionId;

  const ResultsScreen({super.key, required this.sessionId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> with TickerProviderStateMixin {
  final _service = SessionService();
  final _bg = const Color(0xFF190831);
  static const _accent = Color(0xFFFFD700);
  static const _shieldBlue = Color(0xFF2196F3);

  late final AnimationController _shieldPulseController;
  final Map<String, String> _displayNames = {};
  final Set<String> _nameQueued = {};

  @override
  void initState() {
    super.initState();
    _shieldPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shieldPulseController.dispose();
    super.dispose();
  }

  void _resolveNames(List<String> userIds) {
    final missing = userIds.where((id) => !_nameQueued.contains(id)).toList();
    if (missing.isEmpty) return;
    _nameQueued.addAll(missing);
    _service.fetchDisplayNames(missing).then((names) {
      if (!mounted) return;
      setState(() => _displayNames.addAll(names));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Results',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<SessionEntity?>(
        stream: _service.getSessionStream(widget.sessionId),
        builder: (context, sessionSnapshot) {
          if (sessionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final session = sessionSnapshot.data;
          if (session == null) {
            return const Center(child: Text('Session not found'));
          }

          if (session.status != SessionStatus.completed) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Waiting for results...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }

          return _buildResults(session);
        },
      ),
    );
  }

  Widget _buildResults(SessionEntity session) {
    final results = session.aggregatedResults ?? {};
    if (results.isEmpty) {
      return const Center(child: Text('No results available', style: TextStyle(color: Colors.white)));
    }

    final cardTally = results['cardTally'] as Map<String, dynamic>? ?? {};
    final winnerCardId = results['winnerCardId'] as String? ?? '';
    final winnerCardTitle = results['winnerCardTitle'] as String? ?? '';
    final winnerCardEmoji = results['winnerCardEmoji'] as String? ?? '';
    final totalParticipants = results['totalParticipants'] as int? ?? 0;
    final standings = results['standings'] as Map<String, dynamic>? ?? {};
    final speedShieldCardId = results['speedShieldWinnerCardId'] as String? ?? '';

    _resolveNames(standings.keys.toList());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWinnerHero(winnerCardTitle, winnerCardEmoji, totalParticipants),
          const SizedBox(height: 28),
          _buildSectionHeader('Card Tally', 'X marks = players who eliminated this card (Speed Shield absorbs 1)'),
          const SizedBox(height: 12),
          _buildCardTally(cardTally, winnerCardId, speedShieldCardId),
          if (standings.isNotEmpty) ...[
            const SizedBox(height: 28),
            _buildSectionHeader('Leaderboard', 'Ranked by decision time (fastest first)'),
            const SizedBox(height: 12),
            _buildStandings(standings),
          ],
          const SizedBox(height: 28),
          _buildBackButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWinnerHero(String title, String emoji, int totalParticipants) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 52),
          const SizedBox(height: 10),
          const Text(
            'WINNING CARD',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          if (emoji.isNotEmpty)
            Text(emoji, style: const TextStyle(fontSize: 44)),
          if (emoji.isNotEmpty) const SizedBox(height: 8),
          Text(
            title.isNotEmpty ? title : 'No winner',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$totalParticipants player${totalParticipants == 1 ? '' : 's'} voted',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String explainer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          explainer,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCardTally(Map<String, dynamic> cardTally, String winnerCardId, String speedShieldCardId) {
    if (cardTally.isEmpty) return const SizedBox.shrink();

    final sorted = cardTally.entries.toList()
      ..sort((a, b) {
        final aData = a.value as Map<String, dynamic>;
        final bData = b.value as Map<String, dynamic>;
        return (bData['eliminationCount'] as int)
            .compareTo(aData['eliminationCount'] as int);
      });

    return AnimatedBuilder(
      animation: _shieldPulseController,
      builder: (context, _) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final entry = sorted[index];
            final cardId = entry.key;
            final data = entry.value as Map<String, dynamic>;
            final title = data['title'] as String? ?? '';
            final emoji = data['emoji'] as String? ?? '';
            final eliminations = data['eliminationCount'] as int? ?? 0;
            final isWinner = cardId == winnerCardId;
            final isSpeedShield = cardId == speedShieldCardId;
            final shieldAbsorbed = data['shieldAbsorbed'] as bool? ?? false;

            return _buildCardTile(
              title: title,
              emoji: emoji,
              eliminations: eliminations,
              isWinner: isWinner,
              isSpeedShield: isSpeedShield,
              shieldAbsorbed: shieldAbsorbed,
            );
          },
        );
      },
    );
  }

  Widget _buildCardTile({
    required String title,
    required String emoji,
    required int eliminations,
    required bool isWinner,
    required bool isSpeedShield,
    required bool shieldAbsorbed,
  }) {
    final isBoth = isWinner && isSpeedShield;
    // The shield is "used up" only when it actually absorbed an X mark;
    // sessions saved before this field existed render as intact.
    final shieldUsed = isSpeedShield && shieldAbsorbed;
    final showBluePulse = isSpeedShield;
    final pulseAlpha = 0.15 + (_shieldPulseController.value * 0.30);

    final borderColor = showBluePulse
        ? _shieldBlue
        : isWinner
            ? _accent
            : Colors.white.withValues(alpha: 0.08);

    final borderWidth = (showBluePulse || isWinner) ? 2.0 : 1.0;

    final boxShadow = showBluePulse
        ? [
            BoxShadow(
              color: _shieldBlue.withValues(alpha: pulseAlpha),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : isWinner
            ? [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null;

    final bgColor = showBluePulse
        ? _shieldBlue.withValues(alpha: 0.08)
        : isWinner
            ? _accent.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.35);

    final shieldIcon = shieldUsed ? Icons.shield_outlined : Icons.shield;

    String label;
    Color labelColor;
    FontWeight labelWeight;
    if (isBoth) {
      label = 'Shielded Winner';
      labelColor = _shieldBlue;
      labelWeight = FontWeight.w700;
    } else if (isSpeedShield) {
      label = shieldUsed ? 'Shield Used' : 'Shielded';
      labelColor = _shieldBlue;
      labelWeight = FontWeight.w700;
    } else if (isWinner) {
      label = 'Safe';
      labelColor = const Color(0xFF4CAF50);
      labelWeight = FontWeight.w700;
    } else {
      label = 'Safe';
      labelColor = Colors.white.withValues(alpha: 0.4);
      labelWeight = FontWeight.w600;
    }

    // Shielded cards always show their (shield-adjusted) X count under the
    // label; other cards keep the original behaviour of hiding marks on the
    // winning card.
    final showXMarks = eliminations > 0 && (isSpeedShield || !isWinner);

    return CustomPaint(
      painter: shieldUsed
          ? _BrokenShieldBorderPainter(color: _shieldBlue, strokeWidth: borderWidth)
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: shieldUsed
              ? null
              : Border.all(color: borderColor, width: borderWidth),
          boxShadow: boxShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isBoth)
                  const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(Icons.emoji_events, color: _accent, size: 14),
                  ),
                if (showBluePulse)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(shieldIcon, color: _shieldBlue, size: 14),
                  ),
                if (emoji.isNotEmpty)
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                if (emoji.isNotEmpty) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: (isWinner || isSpeedShield) ? FontWeight.w700 : FontWeight.w600,
                      color: showBluePulse
                          ? _shieldBlue
                          : isWinner
                              ? _accent
                              : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: labelWeight,
              ),
            ),
            if (showXMarks) ...[
              const SizedBox(height: 4),
              _buildEliminationMarks(eliminations),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEliminationMarks(int eliminations) {
    return Row(
      children: [
        ...List.generate(
          eliminations.clamp(0, 5),
          (i) => const Padding(
            padding: EdgeInsets.only(right: 3),
            child: Icon(Icons.close, color: Colors.redAccent, size: 14),
          ),
        ),
        if (eliminations > 5)
          Text(
            '\u00d7$eliminations',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  Widget _buildStandings(Map<String, dynamic> standings) {
    final entries = standings.entries.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final data = entry.value as Map<String, dynamic>;
        final storedName = data['userName'] as String? ?? 'Player';
        final resolvedName = _displayNames[entry.key] ?? storedName;
        return _buildStandingCard(
          rank: index + 1,
          userName: resolvedName,
          elapsedTimeMs: data['elapsedTimeMs'] as int? ?? 0,
          timeoutCount: data['timeoutCount'] as int? ?? 0,
        );
      },
    );
  }

  Widget _buildStandingCard({
    required int rank,
    required String userName,
    required int elapsedTimeMs,
    required int timeoutCount,
  }) {
    final timeSeconds = (elapsedTimeMs / 1000).toStringAsFixed(1);
    final isFirst = rank == 1;
    final isMedal = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isFirst
            ? _accent.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFirst ? _accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
          width: isFirst ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank / medal
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isFirst
                  ? _accent
                  : rank == 2
                      ? Colors.grey.shade400
                      : rank == 3
                          ? const Color(0xFFCD7F32)
                          : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isMedal
                  ? Text(
                      rank == 1 ? '\u{1F947}' : rank == 2 ? '\u{1F948}' : '\u{1F949}',
                      style: const TextStyle(fontSize: 18),
                    )
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isFirst ? FontWeight.w700 : FontWeight.w600,
                    color: isFirst ? _accent : Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$timeSeconds s${timeoutCount > 0 ? ' \u00b7 $timeoutCount timeout${timeoutCount == 1 ? '' : 's'}' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // Time pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isFirst ? _accent.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFirst ? _accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Text(
              '$timeSeconds s',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isFirst ? _accent : const Color(0xFFFE4EF0),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        SessionRefreshNotifier.instance.notifyRefresh();
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Back to Home',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed blue outline drawn in place of the tile's solid border once the
/// Speed Shield has absorbed an X mark ("used up" / broken shield).
class _BrokenShieldBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _BrokenShieldBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      (size.width - strokeWidth).clamp(0.0, double.infinity),
      (size.height - strokeWidth).clamp(0.0, double.infinity),
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));

    const dashLength = 5.0;
    const gapLength = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashLength),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BrokenShieldBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
