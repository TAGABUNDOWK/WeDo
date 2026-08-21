import 'package:flutter/material.dart';
import '../../models/session_entity.dart';
import '../../services/session/session_service.dart';
import 'session_entry_screen.dart';

class ResultsScreen extends StatefulWidget {
  final String sessionId;

  const ResultsScreen({super.key, required this.sessionId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _service = SessionService();
  final _bg = const Color(0xFF190831);

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
      return Center(child: Text('No results available', style: TextStyle(color: Colors.white)));
    }

    final cardTally = results['cardTally'] as Map<String, dynamic>? ?? {};
    final winnerCardId = results['winnerCardId'] as String? ?? '';
    final winnerCardTitle = results['winnerCardTitle'] as String? ?? '';
    final totalParticipants = results['totalParticipants'] as int? ?? 0;
    final standings = results['standings'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWinnerBanner(winnerCardTitle, totalParticipants),
          const SizedBox(height: 24),
          _buildSectionTitle('Card Tally'),
          const SizedBox(height: 4),
          Text(
            'X marks = how many players eliminated this card',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _buildCardTally(cardTally, winnerCardId),
          if (standings.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Leaderboard'),
            const SizedBox(height: 4),
            Text(
              'Ranked by decision time (fastest first)',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildStandings(standings),
          ],
          const SizedBox(height: 24),
          _buildBackButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWinnerBanner(String winnerCardTitle, int totalParticipants) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'WINNING CARD',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            winnerCardTitle.isNotEmpty ? winnerCardTitle : 'No winner',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalParticipants player${totalParticipants == 1 ? '' : 's'} voted',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
    );
  }

  Widget _buildCardTally(Map<String, dynamic> cardTally, String winnerCardId) {
    if (cardTally.isEmpty) return const SizedBox.shrink();

    final sorted = cardTally.entries.toList()
      ..sort((a, b) {
        final aData = a.value as Map<String, dynamic>;
        final bData = b.value as Map<String, dynamic>;
        return (bData['eliminationCount'] as int)
            .compareTo(aData['eliminationCount'] as int);
      });

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        final cardId = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final title = data['title'] as String? ?? '';
        final eliminations = data['eliminationCount'] as int? ?? 0;
        final isWinner = cardId == winnerCardId;

        return _buildCardTile(
          title: title,
          eliminations: eliminations,
          isWinner: isWinner,
        );
      },
    );
  }

  Widget _buildCardTile({
    required String title,
    required int eliminations,
    required bool isWinner,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWinner ? const Color(0x33FFD700) : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: isWinner
            ? Border.all(color: const Color(0xFFFFD700), width: 2)
            : Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isWinner)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 16),
                ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isWinner ? FontWeight.w700 : FontWeight.w600,
                    color: isWinner ? Colors.amber.shade800 : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (eliminations > 0)
            Row(
              children: List.generate(
                eliminations.clamp(0, 10),
                (i) => const Padding(
                  padding: EdgeInsets.only(right: 3),
                  child: Icon(Icons.close, color: Colors.redAccent, size: 14),
                ),
              ),
            )
          else
            const Text(
              'Safe',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
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
        return _buildStandingCard(
          rank: index + 1,
          userName: data['userName'] as String? ?? 'Player',
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
    final medal = rank == 1 ? '\u{1F947}' : rank == 2 ? '\u{1F948}' : rank == 3 ? '\u{1F949}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank == 1
                  ? Colors.amber
                  : rank == 2
                      ? Colors.grey.shade300
                      : rank == 3
                          ? Colors.brown.shade200
                          : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: medal.isNotEmpty
                  ? Text(medal, style: const TextStyle(fontSize: 18))
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: rank <= 3 ? Colors.white : Colors.blue,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$timeSeconds s${timeoutCount > 0 ? ' \u00b7 $timeoutCount timeout${timeoutCount == 1 ? '' : 's'}' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
            ),
            child: Text(
              '$timeSeconds s',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: rank == 1 ? Colors.amber.shade800 : const Color(0xFFFE4EF0),
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
        sessionRefreshEvent.value++;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)]),
          borderRadius: BorderRadius.circular(12),
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
