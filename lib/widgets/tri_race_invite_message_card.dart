import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/tri_race_entity.dart';
import '../../services/tri_race/tri_race_service.dart';
import '../../screens/tri_race/tri_race_preview_screen.dart';
import '../../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

class TriRaceInviteMessageCard extends StatelessWidget {
  final String raceId;
  final String content;
  final bool isMe;
  final String? senderName;
  final String time;

  const TriRaceInviteMessageCard({
    super.key,
    required this.raceId,
    required this.content,
    required this.isMe,
    this.senderName,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final service = TriRaceService();

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
            StreamBuilder<TriRace?>(
              stream: service.getTriRaceStream(raceId),
              builder: (context, snapshot) {
                final race = snapshot.data;
                final status = race?.status;
                final isActive = status == TriRaceStatus.lobby;
                final isCancelled = status == TriRaceStatus.cancelled;

                return GestureDetector(
                  onTap: isActive
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TriRacePreviewScreen(raceId: raceId),
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
                          border: Border.all(color: AppColors.glassBorder, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('🏎️', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isActive ? 'TriRace' : _getStatusText(status),
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
                                    child: Icon(Icons.cancel_outlined, color: Color(0xFFEF5350), size: 18),
                                  ),
                              ],
                            ),
                            if (race != null) ...[
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
                                      colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
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

  String _getStatusText(TriRaceStatus? status) {
    switch (status) {
      case TriRaceStatus.started:
        return 'Race in progress';
      case TriRaceStatus.finished:
        return 'Race ended';
      case TriRaceStatus.cancelled:
        return 'Race cancelled';
      default:
        return 'Invite';
    }
  }

  Widget _buildParticipantDots(TriRaceService service, bool isActive) {
    return StreamBuilder<List<TriRaceParticipant>>(
      stream: service.getParticipantsStream(raceId),
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
                  color: isActive ? const Color(0xFF4ECDC4) : AppColors.textSecondary,
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
                      ? const Color(0xFF4ECDC4).withValues(alpha: 0.6)
                      : AppColors.textSecondary.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 4),
            Text(
              '$count player${count == 1 ? '' : 's'} racing',
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
