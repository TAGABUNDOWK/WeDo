import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/constants.dart';
import '../../../models/event.dart';
import '../../../services/event/event_service.dart';
import '../../../services/group/group_service.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final String? groupId;
  final String? chatId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.groupId,
    this.chatId,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _eventService = EventService();
  final _groupService = GroupService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  ChatEvent? _event;
  Map<String, String> _memberNames = {};
  bool _isLoading = true;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final event = await _eventService.getEvent(
      widget.eventId,
      chatId: widget.chatId,
      groupId: widget.groupId,
    );

    if (event == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    Map<String, String> names = {};
    if (widget.groupId != null) {
      final members = await _groupService.getGroupMembersWithNames(widget.groupId!);
      for (final m in members) {
        names[m['uid'] as String] = m['displayName'] as String;
      }
    }

    if (mounted) {
      setState(() {
        _event = event;
        _memberNames = names;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
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

  String _formatFullDateTime(DateTime dt) => '${_formatDate(dt)} at ${_formatTime(dt)}';

  String _getCreatorName() {
    return _memberNames[_event!.createdBy] ?? 'Unknown';
  }

  List<String> _getAttendeeInitials({int limit = 3}) {
    final keys = _event!.rsvps.keys.toList();
    final names = <String>[];
    for (final uid in keys) {
      if (names.length >= limit) break;
      final name = _memberNames[uid] ?? uid;
      if (name.isNotEmpty) {
        final parts = name.trim().split(RegExp(r'\s+'));
        final initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'
            : name.substring(0, name.length.clamp(0, 2));
        names.add(initials.toUpperCase());
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lavenderAccent))
          : _event == null
              ? const Center(
                  child: Text(
                    'Event not found',
                    style: TextStyle(color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans'),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Text(
                          'EVENT DETAILS',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _event!.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'WITH ${_getCreatorName().toUpperCase()}',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),

                        // Social Proof - Overlapping Avatars
                        if (_event!.rsvps.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildSocialProof(),
                        ],

                        // Metadata
                        const SizedBox(height: 24),
                        const _GlassThinDivider(),
                        _buildMetadataRow(
                          icon: Icons.calendar_today_outlined,
                          text: _formatFullDateTime(_event!.date),
                        ),
                        if (_event!.endDate != null) ...[
                          const _GlassThinDivider(),
                          _buildMetadataRow(
                            icon: Icons.schedule_outlined,
                            text: 'Ends at ${_formatTime(_event!.endDate!)}',
                          ),
                        ],
                        if (_event!.location != null && _event!.location!.isNotEmpty) ...[
                          const _GlassThinDivider(),
                          _buildMetadataRow(
                            icon: Icons.location_on_outlined,
                            text: _event!.location!,
                          ),
                        ],
                        if (_event!.dressCode != null && _event!.dressCode!.isNotEmpty) ...[
                          const _GlassThinDivider(),
                          _buildMetadataRow(
                            icon: Icons.checkroom_outlined,
                            text: _event!.dressCode!,
                          ),
                        ],
                        const _GlassThinDivider(),

                        // Status Indicator
                        const SizedBox(height: 20),
                        _StatusBadge(eventDate: _event!.date, endDate: _event!.endDate),

                        // RSVP Action Row
                        const SizedBox(height: 20),
                        _RsvpActionRow(
                          event: _event!,
                          currentUid: _currentUser?.uid ?? '',
                          memberNames: _memberNames,
                          onRsvpChanged: () => _loadData(),
                        ),

                        // Responses List
                        if (_event!.rsvps.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Responses',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._event!.rsvps.entries.map((entry) {
                            return _ResponseTile(
                              name: _memberNames[entry.key] ?? entry.key,
                              response: entry.value,
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSocialProof() {
    final initials = _getAttendeeInitials(limit: 3);
    final totalRsvps = _event!.rsvps.length;
    final extra = totalRsvps - initials.length;

    return Row(
      children: [
        SizedBox(
          width: 36 * initials.length.toDouble() - 8 * (initials.length - 1).clamp(0, initials.length),
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < initials.length; i++)
                Positioned(
                  left: i * 28.0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF211635),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.midnightBg,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials[i],
                        style: const TextStyle(
                          color: AppColors.lavenderAccent,
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.lavenderAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '+$extra',
              style: const TextStyle(
                color: AppColors.lavenderAccent,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          '$totalRsvps ${totalRsvps == 1 ? 'person' : 'people'} going',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.lavenderAccent, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Glass Card Widget
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Thin Divider
class _GlassThinDivider extends StatelessWidget {
  const _GlassThinDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }
}

// Status Badge
class _StatusBadge extends StatelessWidget {
  final DateTime eventDate;
  final DateTime? endDate;

  const _StatusBadge({required this.eventDate, this.endDate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isStarted = now.isAfter(eventDate);
    final isEnded = endDate != null && now.isAfter(endDate!);

    String text;
    IconData icon;
    Color bgColor;
    List<BoxShadow>? glow;

    if (isEnded) {
      text = 'Ended';
      icon = Icons.check_circle;
      bgColor = AppColors.glassBg;
      glow = null;
    } else if (isStarted && endDate != null) {
      final remaining = endDate!.difference(now);
      text = 'Happening now \u2014 Ends in ${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
      icon = Icons.play_circle_filled;
      bgColor = AppColors.neonMagenta;
      glow = [
        BoxShadow(
          color: AppColors.neonMagenta.withValues(alpha: 0.4),
          offset: const Offset(0, 0),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ];
    } else if (isStarted) {
      text = 'Happening now';
      icon = Icons.play_circle_filled;
      bgColor = AppColors.neonMagenta;
      glow = [
        BoxShadow(
          color: AppColors.neonMagenta.withValues(alpha: 0.4),
          offset: const Offset(0, 0),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ];
    } else {
      final diff = eventDate.difference(now);
      if (diff.inMinutes < 60) {
        text = 'Starts in ${diff.inMinutes}m ${diff.inSeconds % 60}s';
      } else if (diff.inHours < 24) {
        text = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        text = 'Starts in ${diff.inDays}d ${diff.inHours % 24}h';
      }
      icon = Icons.access_time;
      bgColor = AppColors.glassBg;
      glow = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
        children: [
          Icon(
            icon,
            size: 18,
            color: isEnded
                ? AppColors.textSecondary
                : isStarted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: isEnded
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// RSVP Action Row
class _RsvpActionRow extends StatefulWidget {
  final ChatEvent event;
  final String currentUid;
  final Map<String, String> memberNames;
  final VoidCallback onRsvpChanged;

  const _RsvpActionRow({
    required this.event,
    required this.currentUid,
    required this.memberNames,
    required this.onRsvpChanged,
  });

  @override
  State<_RsvpActionRow> createState() => _RsvpActionRowState();
}

class _RsvpActionRowState extends State<_RsvpActionRow> {
  final _eventService = EventService();

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
    widget.onRsvpChanged();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final now = DateTime.now();
    final isStarted = now.isAfter(event.date);
    final isEnded = event.endDate != null && now.isAfter(event.endDate!);
    final isLocked = !isStarted || isEnded;
    final myRsvp = event.myRsvp(widget.currentUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _RsvpButton(
                label: 'Yes',
                count: event.yesCount,
                isSelected: myRsvp == 'yes',
                isActive: true,
                isLocked: isLocked,
                icon: Icons.check,
                onTap: () => _rsvp('yes'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RsvpButton(
                label: 'Maybe',
                count: event.maybeCount,
                isSelected: myRsvp == 'maybe',
                isActive: false,
                isLocked: isLocked,
                icon: Icons.help_outline,
                onTap: () => _rsvp('maybe'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RsvpButton(
                label: 'No',
                count: event.noCount,
                isSelected: myRsvp == 'no',
                isActive: false,
                isLocked: isLocked,
                icon: Icons.close,
                onTap: () => _rsvp('no'),
              ),
            ),
          ],
        ),
        if (isLocked) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                'RSVPs locked \u2014 event has ${isEnded ? "ended" : "not started"}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// RSVP Button
class _RsvpButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isActive;
  final bool isLocked;
  final IconData icon;
  final VoidCallback onTap;

  const _RsvpButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isActive,
    this.isLocked = false,
    required this.icon,
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontFamily: 'PlusJakartaSans',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(height: 2),
              Text(
                '($count)',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Response Tile
class _ResponseTile extends StatelessWidget {
  final String name;
  final String response;

  const _ResponseTile({required this.name, required this.response});

  @override
  Widget build(BuildContext context) {
    final color = response == 'yes'
        ? Colors.green
        : response == 'no'
            ? Colors.red
            : Colors.orange;
    final icon = response == 'yes'
        ? Icons.check_circle
        : response == 'no'
            ? Icons.cancel
            : Icons.help_outline;

    final initials = name.trim().split(RegExp(r'\s+'));
    final displayInitials = initials.length >= 2
        ? '${initials[0][0]}${initials[1][0]}'
        : name.substring(0, name.length.clamp(0, 2));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF211635),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                displayInitials.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.lavenderAccent,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }
}
