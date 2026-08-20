import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session_entity.dart';
import '../../services/session/session_service.dart';
import 'swiping_screen.dart';
import 'results_screen.dart';
import 'invite_picker_screen.dart';

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
  final _bg = const Color(0xFF190831);
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
              ? 'This will cancel the PickFight for all players.'
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
              widget.isHost ? 'Cancel PickFight' : 'Leave',
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
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onPopInvoked(false, null),
          ),
          title: const Text(
            'PickFight Lobby',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
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
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildCodeDisplay(session.sessionId),
          const SizedBox(height: 8),
          Text(
            'Topic: ${session.topic}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (widget.isHost) ...[
            const SizedBox(height: 16),
            _buildInviteButton(session),
          ],
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Players',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
                      style: TextStyle(color: Colors.white54),
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
              style: TextStyle(color: Colors.white54, fontSize: 13),
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
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Text(
          code,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: Color(0xFFFE4EF0),
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
            color: isMe ? const Color(0xFFFE4EF0) : Colors.white.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isMe ? Colors.white : const Color(0xFFFE4EF0),
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
            color: isMe ? const Color(0xFFFE4EF0) : Colors.white70,
            fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildInviteButton(SessionEntity session) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvitePickerScreen(
              sessionId: widget.sessionId,
              hostId: _currentUser!.uid,
              topic: session.topic,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_alt_1, size: 18, color: Color(0xFFFE4EF0)),
            SizedBox(width: 8),
            Text(
              'Invite Friends',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFE4EF0),
              ),
            ),
          ],
        ),
      ),
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
              gradient: count < 1
                  ? const LinearGradient(colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)])
                      .withOpacity(0.5) as Gradient?
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
              child: Text(
                'Start PickFight ($count player${count == 1 ? '' : 's'})',
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
        title: const Text('PickFight Cancelled'),
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
