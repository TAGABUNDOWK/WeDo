import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session_entity.dart';
import '../../services/session/session_service.dart';
import 'results_screen.dart';

class AllSessionsScreen extends StatefulWidget {
  const AllSessionsScreen({super.key});

  @override
  State<AllSessionsScreen> createState() => _AllSessionsScreenState();
}

class _AllSessionsScreenState extends State<AllSessionsScreen> {
  final _service = SessionService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  List<SessionEntity> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final user = _currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final sessions = await _service.getUserCompletedSessions(user.uid, limit: 10);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessions = const [];
        _isLoading = false;
      });
    }
  }

  String _getTopicEmoji(String topic) {
    final lower = topic.toLowerCase();
    if (lower.contains('eat') || lower.contains('food') || lower.contains('restaurant')) {
      return '🍕';
    }
    if (lower.contains('movie') || lower.contains('watch')) {
      return '🎬';
    }
    if (lower.contains('place') || lower.contains('go') || lower.contains('visit')) {
      return '🏰';
    }
    return '🃏';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'All Sessions',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: _currentUser == null
          ? const Center(child: Text('Not logged in', style: TextStyle(color: Colors.white70)))
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _sessions.isEmpty
                  ? const Center(
                      child: Text(
                        'No completed sessions yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) => _buildSessionCard(_sessions[index]),
                    ),
    );
  }

  Widget _buildSessionCard(SessionEntity session) {
    final results = session.aggregatedResults ?? {};
    final winnerTitle = results['winnerCardTitle'] as String? ?? '';
    final totalPlayers = results['totalParticipants'] as int? ?? 0;
    final emoji = _getTopicEmoji(session.topic);
    final isCancelled = session.status == SessionStatus.cancelled;

    return GestureDetector(
      onTap: isCancelled
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResultsScreen(sessionId: session.sessionId),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.topic,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.people, color: Colors.white.withValues(alpha: 0.5), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$totalPlayers player${totalPlayers != 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _timeAgo(session.createdAt),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                      ),
                    ],
                  ),
                  if (winnerTitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber.withValues(alpha: 0.7), size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            winnerTitle,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.redAccent.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCancelled ? 'Cancelled' : 'Completed',
                    style: TextStyle(
                      color: isCancelled ? Colors.redAccent : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.sessionId,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
