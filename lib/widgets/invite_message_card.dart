import 'package:flutter/material.dart';
import '../models/session_entity.dart';
import '../services/session/session_service.dart';
import '../screens/session/session_preview_screen.dart';

class InviteMessageCard extends StatelessWidget {
  final String sessionId;
  final String content;
  final bool isMe;
  final String? senderName;
  final String time;

  const InviteMessageCard({
    super.key,
    required this.sessionId,
    required this.content,
    required this.isMe,
    this.senderName,
    required this.time,
  });

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

  @override
  Widget build(BuildContext context) {
    final service = SessionService();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
            StreamBuilder<SessionEntity?>(
              stream: service.getSessionStream(sessionId),
              builder: (context, snapshot) {
                final session = snapshot.data;
                final status = session?.status;
                final topic = session?.topic ?? '';
                final isActive = status == SessionStatus.lobby;

                return GestureDetector(
                  onTap: isActive
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionPreviewScreen(sessionId: sessionId),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF1A1040)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFFE4EF0).withValues(alpha: 0.4)
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getTopicEmoji(topic),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isActive
                                    ? 'PickFight: $topic'
                                    : _getStatusText(status),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? Colors.white : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (session != null) ...[
                          const SizedBox(height: 10),
                          _buildParticipantDots(service, isActive),
                        ],
                        if (isActive) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Join',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(SessionStatus? status) {
    switch (status) {
      case SessionStatus.active:
        return 'In progress';
      case SessionStatus.completed:
        return 'Session ended';
      case SessionStatus.cancelled:
        return 'Session cancelled';
      default:
        return 'Invite';
    }
  }

  Widget _buildParticipantDots(SessionService service, bool isActive) {
    return StreamBuilder<List<ParticipantEntity>>(
      stream: service.getParticipantsStream(sessionId),
      builder: (context, snapshot) {
        final participants = snapshot.data ?? [];
        final count = participants.length;

        return Row(
          children: [
            ...List.generate(
              count.clamp(0, 4),
              (i) => Container(
                margin: const EdgeInsets.only(right: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            if (count > 4)
              Container(
                margin: const EdgeInsets.only(right: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade300 : Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 4),
            Text(
              '$count player${count == 1 ? '' : 's'} already picking',
              style: TextStyle(
                fontSize: 11,
                color: isActive ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
          ],
        );
      },
    );
  }
}
