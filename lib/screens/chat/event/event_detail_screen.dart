import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/event.dart';
import '../../../models/user_entity.dart';
import '../../../services/auth/user_service.dart';
import '../../../services/event/event_service.dart';
import '../../../services/group/group_service.dart';
import '../../../utils/constants.dart';

/// Full-screen event details.
///
/// Data comes from a Firestore stream ([EventService.getEventStream]) — the
/// same source the chat card uses — so the screen can never wedge in a
/// half-loaded state: every stream snapshot maps to an explicit UI state
/// (loading / error + retry / not found / content), and RSVP changes made on
/// this screen reflect automatically.
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
  final _userService = UserService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  late Stream<ChatEvent?> _eventStream;
  final Map<String, String> _memberNames = {};
  final Map<String, UserEntity> _userCache = {};
  final Set<String> _attendeeFetchAttempts = {};

  @override
  void initState() {
    super.initState();
    _eventStream = _newEventStream();
    _loadMemberNames();
  }

  Stream<ChatEvent?> _newEventStream() => _eventService.getEventStream(
        widget.eventId,
        chatId: widget.chatId,
        groupId: widget.groupId,
      );

  void _retryStream() {
    setState(() => _eventStream = _newEventStream());
  }

  /// Loads group display names for the creator/responses list. Failures are
  /// swallowed — the screen degrades to showing user ids/initials instead of
  /// blocking on this fetch.
  Future<void> _loadMemberNames() async {
    final groupId = widget.groupId;
    if (groupId == null) return;
    try {
      final members = await _groupService.getGroupMembersWithNames(groupId);
      final names = <String, String>{};
      for (final m in members) {
        final uid = m['uid'];
        final name = m['displayName'];
        if (uid is String && name is String && name.isNotEmpty) {
          names[uid] = name;
        }
      }
      if (names.isNotEmpty && mounted) {
        setState(() => _memberNames.addAll(names));
      }
    } catch (_) {
      // Degrade silently — names are cosmetic.
    }
  }

  /// Fetches user profiles (photo/display name) for respondents in the
  /// background. Content renders immediately; profiles hydrate when ready.
  /// Each uid is attempted at most once and individual failures are ignored.
  void _ensureAttendeesLoaded(ChatEvent event) {
    final missing = event.rsvps.keys
        .where((uid) => !_attendeeFetchAttempts.contains(uid))
        .toList();
    if (missing.isEmpty) return;
    _attendeeFetchAttempts.addAll(missing);

    Future.wait(missing.map((uid) async {
      try {
        final user = await _userService.getUserDocument(uid);
        if (user != null) _userCache[uid] = user;
      } catch (_) {
        // Degrade to initials for this user.
      }
    })).whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  String _displayNameFor(String uid) {
    final memberName = _memberNames[uid];
    if (memberName != null && memberName.isNotEmpty) return memberName;
    final cachedName = _userCache[uid]?.displayName;
    if (cachedName != null && cachedName.isNotEmpty) return cachedName;
    return uid;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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

  String _formatFullDateTime(DateTime dt) =>
      '${_formatDate(dt)} at ${_formatTime(dt)}';

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
      body: StreamBuilder<ChatEvent?>(
        stream: _eventStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StatusMessage(
              icon: Icons.error_outline,
              title: 'Something went wrong',
              subtitle: 'The event could not be loaded.',
              actionLabel: 'Retry',
              onAction: _retryStream,
            );
          }

          final event = snapshot.data;
          if (event != null) {
            return _buildContent(event);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.lavenderAccent,
              ),
            );
          }

          return const _StatusMessage(
            icon: Icons.event_busy,
            title: 'Event not found',
            subtitle: 'It may have been deleted.',
          );
        },
      ),
    );
  }

  Widget _buildContent(ChatEvent event) {
    _ensureAttendeesLoaded(event);

    final currentUid = _currentUser?.uid ?? '';
    final creatorName =
        _memberNames[event.createdBy] ?? 'Unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              event.title,
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
              'WITH ${creatorName.toUpperCase()}',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            if (event.rsvps.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSocialProof(event),
            ],

            const SizedBox(height: 24),
            const _ThinDivider(),
            _MetadataRow(
              icon: Icons.calendar_today_outlined,
              text: _formatFullDateTime(event.date),
            ),
            if (event.endDate != null) ...[
              const _ThinDivider(),
              _MetadataRow(
                icon: Icons.schedule_outlined,
                text: 'Ends at ${_formatTime(event.endDate!)}',
              ),
            ],
            if (event.location != null && event.location!.isNotEmpty) ...[
              const _ThinDivider(),
              _MetadataRow(
                icon: Icons.location_on_outlined,
                text: event.location!,
              ),
            ],
            if (event.dressCode != null && event.dressCode!.isNotEmpty) ...[
              const _ThinDivider(),
              _MetadataRow(
                icon: Icons.checkroom_outlined,
                text: event.dressCode!,
              ),
            ],
            const _ThinDivider(),

            const SizedBox(height: 20),
            _StatusPill(eventDate: event.date, endDate: event.endDate),

            const SizedBox(height: 20),
            _RsvpRow(event: event, currentUid: currentUid),

            if (event.rsvps.isNotEmpty) ...[
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
              for (final entry in event.rsvps.entries)
                _ResponseTile(
                  name: _displayNameFor(entry.key),
                  uid: entry.key,
                  response: entry.value,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSocialProof(ChatEvent event) {
    final uids = event.rsvps.keys.take(3).toList();
    final total = event.rsvps.length;
    final extra = total - uids.length;
    final stackWidth =
        uids.isEmpty ? 0.0 : 36.0 + (uids.length - 1) * 28.0;

    return Row(
      children: [
        if (uids.isNotEmpty) ...[
          SizedBox(
            width: stackWidth,
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < uids.length; i++)
                  Positioned(
                    left: i * 28.0,
                    child: _buildAvatar(uids[i], 36),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (extra > 0) ...[
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
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            '$total ${total == 1 ? 'person' : 'people'} going',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String uid, double size) {
    final user = _userCache[uid];
    final photoUrl = user?.photoUrl;
    final avatarAsset = user?.avatarAsset;
    final hasAvatarAsset = avatarAsset != null && avatarAsset.isNotEmpty;
    final hasAvatarUrl = photoUrl != null && photoUrl.isNotEmpty;
    final initial =
        uid.isNotEmpty ? uid.substring(0, 1).toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF211635),
        border: Border.all(
          color: AppColors.midnightBg,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasAvatarAsset
            ? Image.asset(
                avatarAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _avatarFallback(initial, size),
              )
            : hasAvatarUrl
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _avatarFallback(initial, size),
                  )
                : _avatarFallback(initial, size),
      ),
    );
  }

  Widget _avatarFallback(String initial, double size) {
    return Container(
      color: const Color(0xFF211635),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.lavenderAccent,
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w700,
          fontSize: size * 0.33,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared, self-contained pieces
// ---------------------------------------------------------------------------

/// Full-body placeholder for the error / not-found states so the screen can
/// never render as a blank page.
class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: AppColors.lavenderAccent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: AppColors.lavenderAccent,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetadataRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.lavenderAccent, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live status pill (starts-in / happening-now / ended). Owns its own 1-second
/// timer so only this small widget rebuilds, not the whole screen.
class _StatusPill extends StatefulWidget {
  final DateTime eventDate;
  final DateTime? endDate;

  const _StatusPill({required this.eventDate, this.endDate});

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isStarted = now.isAfter(widget.eventDate);
    final isEnded = widget.endDate != null && now.isAfter(widget.endDate!);

    String text;
    IconData icon;
    Color bgColor;
    List<BoxShadow>? glow;

    if (isEnded) {
      text = 'Ended';
      icon = Icons.check_circle;
      bgColor = AppColors.glassBg;
      glow = null;
    } else if (isStarted && widget.endDate != null) {
      final remaining = widget.endDate!.difference(now);
      text =
          'Happening now \u2014 Ends in ${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
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
      final diff = widget.eventDate.difference(now);
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isEnded || !isStarted
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isEnded ? AppColors.textSecondary : AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-option RSVP row. Writes through the single shared path
/// ([EventService.submitResponse]) which toggles off a repeated tap and
/// no-ops once the event has ended; the stream pushes the updated counts.
class _RsvpRow extends StatelessWidget {
  final ChatEvent event;
  final String currentUid;

  const _RsvpRow({required this.event, required this.currentUid});

  Future<void> _submit(EventResponse response) async {
    if (event.isEnded || currentUid.isEmpty) return;
    try {
      await EventService().submitResponse(
        event: event,
        uid: currentUid,
        response: response,
      );
    } catch (_) {
      // Silent — the stream simply won't change and counts stay put.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = event.isEnded;
    final myResponse = event.myResponse(currentUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _RsvpButton(
                label: EventResponse.interested.label,
                count: event.interestedCount,
                isSelected: myResponse == EventResponse.interested,
                isLocked: isLocked,
                icon: Icons.check,
                onTap: () => _submit(EventResponse.interested),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RsvpButton(
                label: EventResponse.notSure.label,
                count: event.notSureCount,
                isSelected: myResponse == EventResponse.notSure,
                isLocked: isLocked,
                icon: Icons.question_mark,
                onTap: () => _submit(EventResponse.notSure),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RsvpButton(
                label: EventResponse.notInterested.label,
                count: event.notInterestedCount,
                isSelected: myResponse == EventResponse.notInterested,
                isLocked: isLocked,
                icon: Icons.close,
                onTap: () => _submit(EventResponse.notInterested),
              ),
            ),
          ],
        ),
        if (isLocked) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Responses closed \u2014 event has ended',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isLocked;
  final IconData icon;
  final VoidCallback onTap;

  const _RsvpButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isLocked,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isSelected) {
      bgColor = AppColors.lavenderAccent;
      borderColor = AppColors.lavenderAccent;
      textColor = AppColors.midnightBg;
    } else if (isLocked) {
      bgColor = AppColors.glassBg;
      borderColor = AppColors.glassBorder;
      textColor = AppColors.textSecondary.withValues(alpha: 0.4);
    } else {
      bgColor = Colors.transparent;
      borderColor = AppColors.glassBorder;
      textColor = AppColors.textSecondary;
    }
    final iconColor = textColor;

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
              textAlign: TextAlign.center,
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

class _ResponseTile extends StatelessWidget {
  final String name;
  final String uid;
  final String response;

  const _ResponseTile({
    required this.name,
    required this.uid,
    required this.response,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return uid.isNotEmpty ? uid.substring(0, 1).toUpperCase() : '?';
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed
        .substring(0, trimmed.length.clamp(0, 2))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = EventResponse.parse(response);
    final Color color;
    final IconData icon;
    switch (parsed) {
      case EventResponse.interested:
        color = Colors.green;
        icon = Icons.check_circle;
      case EventResponse.notInterested:
        color = Colors.red;
        icon = Icons.cancel;
      case EventResponse.notSure:
        color = Colors.orange;
        icon = Icons.help_outline;
      case null:
        color = Colors.orange;
        icon = Icons.help_outline;
    }

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
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: const TextStyle(
                color: AppColors.lavenderAccent,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }
}
