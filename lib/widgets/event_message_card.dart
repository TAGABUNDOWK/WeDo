import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../services/event/event_service.dart';
import '../../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

class EventMessageCard extends StatefulWidget {
  final ChatEvent event;
  final bool isMe;
  final String senderName;
  final String currentUid;
  final VoidCallback? onTap;
  final List<String> attendeeNames;
  final VoidCallback? onInfoTap;

  const EventMessageCard({
    super.key,
    required this.event,
    required this.isMe,
    required this.senderName,
    required this.currentUid,
    this.onTap,
    this.attendeeNames = const [],
    this.onInfoTap,
  });

  @override
  State<EventMessageCard> createState() => _EventMessageCardState();
}

class _EventMessageCardState extends State<EventMessageCard> {
  final _eventService = EventService();
  late final Stream<ChatEvent?> _eventStream;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _eventStream = _eventService.getEventStream(
      widget.event.id,
      chatId: widget.event.chatId,
      groupId: widget.event.groupId,
    );
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _rsvp(String response) async {
    final event = widget.event;
    final now = DateTime.now();
    final isStarted = now.isAfter(event.date);
    final isEnded = event.endDate != null && now.isAfter(event.endDate!);
    if (!isStarted || isEnded) return;
    await _eventService.rsvpEvent(
      eventId: widget.event.id,
      uid: widget.currentUid,
      response: response,
      chatId: widget.event.chatId,
      groupId: widget.event.groupId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatEvent?>(
      stream: _eventStream,
      initialData: widget.event,
      builder: (context, snapshot) {
        final event = snapshot.data ?? widget.event;
        final myResponse = event.myRsvp(widget.currentUid);

        return GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.eventCardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AppBarSection(
                            event: event,
                            onInfoTap: widget.onInfoTap,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'EVENT DETAILS',
                                  style: TextStyle(
                                    fontFamily: _fontFamily,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontFamily: _fontFamily,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _AttendeeRow(
                                  event: event,
                                  attendeeNames: widget.attendeeNames,
                                  currentUid: widget.currentUid,
                                ),
                                const SizedBox(height: 8),
                                _MetadataSection(event: event),
                                const SizedBox(height: 8),
                                _StatusBadge(event: event),
                                const SizedBox(height: 10),
                                _RsvpRow(
                                  event: event,
                                  currentUid: widget.currentUid,
                                  myResponse: myResponse,
                                  onRsvp: _rsvp,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.senderName.isNotEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.eventCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder, width: 0.5),
                    ),
                    child: Text(
                      'Event Created by ${widget.senderName}',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 10,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AppBarSection extends StatelessWidget {
  final ChatEvent event;
  final VoidCallback? onInfoTap;

  const _AppBarSection({required this.event, this.onInfoTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'Event',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onInfoTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  final ChatEvent event;
  final List<String> attendeeNames;
  final String currentUid;

  const _AttendeeRow({
    required this.event,
    required this.attendeeNames,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final respondents = event.rsvps.keys.toList();
    if (respondents.isEmpty) {
      return Text(
        'No responses yet',
        style: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          color: AppColors.textSecondary.withValues(alpha: 0.6),
        ),
      );
    }

    final displayNames = <String>[];
    for (final uid in respondents) {
      final nameIdx = attendeeNames.indexOf(uid);
      displayNames.add(nameIdx != -1 ? attendeeNames[nameIdx] : uid.substring(0, 6));
    }

    final visibleCount = displayNames.length.clamp(0, 4);
    final overflow = displayNames.length - visibleCount;

    return Row(
      children: [
        SizedBox(
          width: visibleCount * 22.0,
          height: 24,
          child: Stack(
            children: List.generate(visibleCount, (i) {
              return Positioned(
                left: i * 16.0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF211635),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.midnightBg,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      displayNames[i].isNotEmpty
                          ? displayNames[i][0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lavenderAccent,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (overflow > 0) ...[
          const SizedBox(width: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lavenderAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              '+$overflow',
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.lavenderAccent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetadataSection extends StatelessWidget {
  final ChatEvent event;

  const _MetadataSection({required this.event});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetadataRow(
          icon: Icons.calendar_today_outlined,
          text: '${_formatDate(event.date)} at ${_formatTime(event.date)}${event.endDate != null ? ' - ${_formatTime(event.endDate!)}' : ''}',
        ),
        if (event.location != null && event.location!.isNotEmpty) ...[
          const SizedBox(height: 5),
          _MetadataRow(
            icon: Icons.location_on_outlined,
            text: event.location!,
          ),
        ],
        if (event.dressCode != null && event.dressCode!.isNotEmpty) ...[
          const SizedBox(height: 5),
          _MetadataRow(
            icon: Icons.checkroom_outlined,
            text: event.dressCode!,
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }
}

class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetadataRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.lavenderAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ChatEvent event;

  const _StatusBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isStarted = now.isAfter(event.date);
    final isEnded = event.endDate != null && now.isAfter(event.endDate!);

    String text;
    Color bgColor;
    Color textColor;
    IconData icon;
    List<BoxShadow>? glow;

    if (isEnded) {
      text = 'Ended';
      bgColor = AppColors.glassBg;
      textColor = AppColors.textSecondary;
      icon = Icons.check_circle;
      glow = null;
    } else if (isStarted && event.endDate != null) {
      final remaining = event.endDate!.difference(now);
      text = 'Happening now \u2014 Ends in ${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
      bgColor = AppColors.neonMagenta;
      textColor = AppColors.textPrimary;
      icon = Icons.play_circle_filled;
      glow = [
        BoxShadow(
          color: AppColors.neonMagenta.withValues(alpha: 0.4),
          offset: Offset.zero,
          blurRadius: 14,
          spreadRadius: 1,
        ),
      ];
    } else if (isStarted) {
      text = 'Happening now';
      bgColor = AppColors.neonMagenta;
      textColor = AppColors.textPrimary;
      icon = Icons.play_circle_filled;
      glow = [
        BoxShadow(
          color: AppColors.neonMagenta.withValues(alpha: 0.4),
          offset: Offset.zero,
          blurRadius: 14,
          spreadRadius: 1,
        ),
      ];
    } else {
      final diff = event.date.difference(now);
      if (diff.inMinutes < 60) {
        text = 'Starts in ${diff.inMinutes}m ${diff.inSeconds % 60}s';
      } else if (diff.inHours < 24) {
        text = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        text = 'Starts in ${diff.inDays}d ${diff.inHours % 24}h';
      }
      bgColor = AppColors.glassBg;
      textColor = AppColors.textSecondary;
      icon = Icons.access_time;
      glow = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: glow,
        border: Border.all(
          color: isStarted && !isEnded
              ? AppColors.neonMagenta.withValues(alpha: 0.5)
              : AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpRow extends StatelessWidget {
  final ChatEvent event;
  final String currentUid;
  final String? myResponse;
  final Future<void> Function(String) onRsvp;

  const _RsvpRow({
    required this.event,
    required this.currentUid,
    required this.myResponse,
    required this.onRsvp,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isStarted = now.isAfter(event.date);
    final isEnded = event.endDate != null && now.isAfter(event.endDate!);
    final isLocked = !isStarted || isEnded;

    return Row(
      children: [
        Expanded(
          child: _RsvpButton(
            label: 'Yes',
            count: event.yesCount,
            isSelected: myResponse == 'yes',
            isActive: true,
            isLocked: isLocked,
            onTap: () => onRsvp('yes'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RsvpButton(
            label: 'Maybe',
            count: event.maybeCount,
            isSelected: myResponse == 'maybe',
            isActive: false,
            isLocked: isLocked,
            onTap: () => onRsvp('maybe'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RsvpButton(
            label: 'No',
            count: event.noCount,
            isSelected: myResponse == 'no',
            isActive: false,
            isLocked: isLocked,
            onTap: () => onRsvp('no'),
          ),
        ),
      ],
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isActive;
  final bool isLocked;
  final VoidCallback onTap;

  const _RsvpButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isActive,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final Color iconColor;

    if (isSelected && isActive) {
      bgColor = AppColors.lavenderAccent;
      borderColor = AppColors.lavenderAccent;
      textColor = AppColors.midnightBg;
      iconColor = AppColors.midnightBg;
    } else if (isSelected) {
      bgColor = AppColors.lavenderAccent;
      borderColor = AppColors.lavenderAccent;
      textColor = AppColors.midnightBg;
      iconColor = AppColors.midnightBg;
    } else if (isLocked) {
      bgColor = AppColors.glassBg;
      borderColor = AppColors.glassBorder;
      textColor = AppColors.textSecondary.withValues(alpha: 0.4);
      iconColor = AppColors.textSecondary.withValues(alpha: 0.4);
    } else {
      bgColor = Colors.transparent;
      borderColor = AppColors.glassBorder;
      textColor = AppColors.textSecondary;
      iconColor = AppColors.textSecondary;
    }

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(
                    isActive ? Icons.check : (label == 'Maybe' ? Icons.help_outline : Icons.close),
                    size: 11,
                    color: iconColor,
                  ),
                  const SizedBox(width: 2),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            if (count > 0) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.glassBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.midnightBg
                        : AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
