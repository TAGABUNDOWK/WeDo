import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session_entity.dart';
import '../../services/session/session_service.dart';
import 'swiping_screen.dart';
import 'results_screen.dart';

class WaitingLobbyScreen extends StatefulWidget {
  final String sessionId;
  final bool isHost;

  const WaitingLobbyScreen({
    super.key,
    required this.sessionId,
    required this.isHost,
  });

  @override
  State<WaitingLobbyScreen> createState() => _WaitingLobbyScreenState();
}

class _WaitingLobbyScreenState extends State<WaitingLobbyScreen> {
  final _service = SessionService();
  final _bg = const Color(0xFFE7ECEF);
  final _currentUser = FirebaseAuth.instance.currentUser;

  bool _isConfirmingLeave = false;

  Future<void> _onPopInvoked(bool didPop, dynamic result) async {
    if (didPop || _isConfirmingLeave) return;

    _isConfirmingLeave = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Lobby?'),
        content: Text(
          widget.isHost
              ? 'This will cancel the session for all players.'
              : 'Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.isHost ? 'Cancel Session' : 'Leave',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        if (widget.isHost) {
          await _service.deleteSession(widget.sessionId, _currentUser!.uid);
        } else {
          await _service.removeParticipant(widget.sessionId, _currentUser!.uid);
        }
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    _isConfirmingLeave = false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onPopInvoked(false, null),
          ),
          title: const Text(
            'Waiting Lobby',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
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

            if (session.status == SessionStatus.cancelled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showCancelledDialog();
              });
              return const Center(
                child: Text('Session was cancelled by the host'),
              );
            }

            if (session.status == SessionStatus.completed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultsScreen(sessionId: session.sessionId),
                  ),
                );
              });
              return const Center(child: CircularProgressIndicator());
            }

            if (session.status == SessionStatus.active) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SwipingScreen(
                      sessionId: session.sessionId,
                      cards: session.cards,
                    ),
                  ),
                );
              });
              return const Center(child: CircularProgressIndicator());
            }

            return _buildLobby(session);
          },
        ),
      ),
    );
  }

  Widget _buildLobby(SessionEntity session) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Share this code with friends',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildCodeDisplay(session.sessionId),
          const SizedBox(height: 8),
          Text(
            'Topic: ${session.topic}',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Players',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<ParticipantEntity>>(
              stream: _service.getParticipantsStream(widget.sessionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final participants = snapshot.data ?? [];

                if (participants.isEmpty) {
                  return const Center(
                    child: Text(
                      'Waiting for players...',
                      style: TextStyle(color: Colors.black38),
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final isMe = p.id == _currentUser?.uid;
                    return _buildPlayerAvatar(p.userName, isMe);
                  },
                );
              },
            ),
          ),
          if (widget.isHost) ...[
            const SizedBox(height: 16),
            _buildStartButton(),
          ],
          if (!widget.isHost) ...[
            const SizedBox(height: 16),
            const Text(
              'Waiting for host to start...',
              style: TextStyle(color: Colors.black38, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCodeDisplay(String code) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Code $code copied!')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 12),
            BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(6, 6), blurRadius: 12),
          ],
        ),
        child: Text(
          code,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(String name, bool isMe) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isMe ? Colors.blue : Colors.blue.shade100,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isMe ? Colors.white : Colors.blue,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: 11,
            color: isMe ? Colors.blue : Colors.black54,
            fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return StreamBuilder<List<ParticipantEntity>>(
      stream: _service.getParticipantsStream(widget.sessionId),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;

        return GestureDetector(
          onTap: count < 1 ? null : _startSession,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: count < 1 ? Colors.blue.shade200 : Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Start Session ($count player${count == 1 ? '' : 's'})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startSession() async {
    if (_currentUser == null) return;
    try {
      await _service.startSession(widget.sessionId, _currentUser.uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showCancelledDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Cancelled'),
        content: const Text('The host closed the lobby.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
