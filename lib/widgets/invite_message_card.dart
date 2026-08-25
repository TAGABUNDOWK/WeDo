import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/session_entity.dart';
import '../services/session/session_service.dart';
import '../screens/session/session_preview_screen.dart';
import '../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

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
                  style: const TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            StreamBuilder<SessionEntity?>(
              stream: service.getSessionStream(sessionId),
              builder: (context, snapshot) {
                final session = snapshot.data;
                final status = session?.status;
                final topic = session?.topic ?? '';
                final isActive = status == SessionStatus.lobby;
                final isCancelled = status == SessionStatus.cancelled;

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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.eventCardBg
                              : isCancelled
                                  ? const Color(0xFF3D1A1A).withValues(alpha: 0.6)
                                  : AppColors.glassBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 1,
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
                                      fontFamily: _fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isCancelled
                                          ? const Color(0xFFEF5350)
                                          : isActive
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (isCancelled)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.cancel_outlined,
                                      color: Color(0xFFEF5350),
                                      size: 18,
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFE4EF0),
                                        Color(0xFF800DD8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Join',
                                    style: TextStyle(
                                      fontFamily: _fontFamily,
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
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                time,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 10,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
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
                  color: isActive ? const Color(0xFF4CAF50) : AppColors.textSecondary,
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
                  color: isActive
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.6)
                      : AppColors.textSecondary.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 4),
            Text(
              '$count player${count == 1 ? '' : 's'} already picking',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 11,
                color: isActive
                    ? AppColors.textSecondary
                    : AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}
