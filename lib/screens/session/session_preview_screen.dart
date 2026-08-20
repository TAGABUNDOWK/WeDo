import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session_entity.dart';
import '../../services/session/session_service.dart';
import 'waiting_lobby_screen.dart';

class SessionPreviewScreen extends StatefulWidget {
  final String sessionId;
  const SessionPreviewScreen({super.key, required this.sessionId});

  @override
  State<SessionPreviewScreen> createState() => _SessionPreviewScreenState();
}

class _SessionPreviewScreenState extends State<SessionPreviewScreen> {
  final _service = SessionService();
  final _bg = const Color(0xFF190831);
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isJoining = false;
  String? _error;

  String _getTopicEmoji(String topic) {
    final lower = topic.toLowerCase();
    if (lower.contains('eat') || lower.contains('food') || lower.contains('restaurant')) {
      return '\ud83c\udf55';
    }
    if (lower.contains('movie') || lower.contains('watch')) {
      return '\ud83c\udfac';
    }
    if (lower.contains('place') || lower.contains('go') || lower.contains('visit')) {
      return '\ud83c\udfd0';
    }
    return '\ud83e\udd4a';
  }

  Future<void> _joinSession() async {
    if (_currentUser == null || _isJoining) return;

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final session = await _service.validateSessionCode(widget.sessionId);

      await _service.joinSession(
        sessionId: session.sessionId,
        userId: _currentUser.uid,
        userName: _currentUser.displayName ?? _currentUser.email ?? 'Player',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingLobbyScreen(sessionId: widget.sessionId, isHost: false),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Session Invite',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: StreamBuilder<SessionEntity?>(
        stream: _service.getSessionStream(widget.sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final session = snapshot.data;

          if (session == null) {
            return _buildNotFound();
          }

          if (session.status == SessionStatus.active) {
            return _buildAlreadyStarted();
          }

          if (session.status == SessionStatus.cancelled) {
            return _buildCancelled();
          }

          if (session.status == SessionStatus.completed) {
            return _buildCompleted();
          }

          if (session.expiresAt.isBefore(DateTime.now())) {
            return _buildExpired();
          }

          return StreamBuilder<List<ParticipantEntity>>(
            stream: _service.getParticipantsStream(widget.sessionId),
            builder: (context, participantSnapshot) {
              final participants = participantSnapshot.data ?? [];
              final currentUid = _currentUser?.uid;
              final isAlreadyParticipant = currentUid != null &&
                  participants.any((p) => p.id == currentUid);

              if (isAlreadyParticipant) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WaitingLobbyScreen(sessionId: widget.sessionId, isHost: false),
                    ),
                  );
                });
                return const Center(child: CircularProgressIndicator());
              }

              return _buildPreview(session);
            },
          );
        },
      ),
    );
  }

  Widget _buildPreview(SessionEntity session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getTopicEmoji(session.topic),
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'You\'ve been invited to',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            session.topic,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<ParticipantEntity>>(
            stream: _service.getParticipantsStream(widget.sessionId),
            builder: (context, snapshot) {
              final participants = snapshot.data ?? [];
              if (participants.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Already in lobby',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: participants.take(8).map((p) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  p.userName.isNotEmpty ? p.userName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Color(0xFFFE4EF0),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.userName,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    if (participants.length > 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${participants.length - 8} more',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: const Text(
              'PickFight is a quick head-to-head card swipe — help the group decide, together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 32),
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _isJoining ? null : _joinSession,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _isJoining
                          ? const LinearGradient(
                              colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                            ).withOpacity(0.5) as Gradient?
                          : const LinearGradient(
                              colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                            ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isJoining
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Join Session',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return _buildStatusScreen(
      icon: Icons.error_outline,
      title: 'Invite not found',
      subtitle: 'This invite link isn\'t valid.',
    );
  }

  Widget _buildAlreadyStarted() {
    return _buildStatusScreen(
      icon: Icons.play_circle_outline,
      title: 'Session already started',
      subtitle: 'This session started without you.',
    );
  }

  Widget _buildCancelled() {
    return _buildStatusScreen(
      icon: Icons.cancel_outlined,
      title: 'Session cancelled',
      subtitle: 'The host cancelled this session.',
    );
  }

  Widget _buildCompleted() {
    return _buildStatusScreen(
      icon: Icons.check_circle_outline,
      title: 'Session ended',
      subtitle: 'This session has already wrapped up.',
    );
  }

  Widget _buildExpired() {
    return _buildStatusScreen(
      icon: Icons.schedule,
      title: 'Invite expired',
      subtitle: 'This invite has expired.',
    );
  }

  Widget _buildStatusScreen({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white38),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Text(
                  'Back to chat',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
