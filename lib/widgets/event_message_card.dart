import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/event.dart';
import '../../models/user_entity.dart';
import '../../services/event/event_service.dart';
import '../../services/group/group_service.dart';
import '../../services/auth/user_service.dart';
import '../../services/location/location_service.dart';
import '../../utils/constants.dart';
import 'event_card_widgets.dart';
import 'place_compare_sheet.dart';

const _fontFamily = 'PlusJakartaSans';

class EventMessageCard extends StatefulWidget {
  final ChatEvent event;
  final bool isMe;
  final String senderName;
  final String currentUid;
  final VoidCallback? onTap;
  final VoidCallback? onInfoTap;

  const EventMessageCard({
    super.key,
    required this.event,
    required this.isMe,
    required this.senderName,
    required this.currentUid,
    this.onTap,
    this.onInfoTap,
  });

  @override
  State<EventMessageCard> createState() => _EventMessageCardState();
}

class _EventMessageCardState extends State<EventMessageCard> {
  final _eventService = EventService();
  final _groupService = GroupService();
  final _userService = UserService();
  late final Stream<ChatEvent?> _eventStream;
  Timer? _expiryTimer;
  final Map<String, UserEntity> _userCache = {};
  final Set<String> _requestedUids = {};
  int? _groupMemberCount;

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
    _loadGroupMemberCount();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  /// One light read of the group document so the proportional vote fills can
  /// use the real member count (direct chats are handled without a fetch).
  Future<void> _loadGroupMemberCount() async {
    final groupId = widget.event.groupId;
    if (groupId == null) return;
    try {
      final group = await _groupService.getGroup(groupId);
      if (group != null && mounted) {
        setState(() => _groupMemberCount = group.memberCount);
      }
    } catch (_) {}
  }

  void _loadAttendeeUsers(ChatEvent event) {
    for (final uid in event.rsvps.keys) {
      if (_requestedUids.contains(uid)) continue;
      _requestedUids.add(uid);
      _fetchUser(uid);
    }
  }

  Future<void> _fetchUser(String uid) async {
    final user = await _userService.getUserDocument(uid);
    if (user != null && mounted) {
      setState(() => _userCache[uid] = user);
    }
  }

  Future<void> _vote(ChatEvent event, EventResponse response) {
    return _eventService.submitResponse(
      event: event,
      uid: widget.currentUid,
      response: response,
    );
  }

  Widget _buildAvatar(String uid, double size) {
    final user = _userCache[uid];
    final photoUrl = user?.photoUrl;
    final avatarAsset = user?.avatarAsset;
    final hasAvatarAsset = avatarAsset != null && avatarAsset.isNotEmpty;
    final hasAvatarUrl = photoUrl != null && photoUrl.isNotEmpty;
    final initials = uid.isNotEmpty ? uid.substring(0, 1).toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF211635),
        border: Border.all(color: AppColors.midnightBg, width: 1.5),
      ),
      child: ClipOval(
        child: hasAvatarAsset
            ? Image.asset(
                avatarAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarFallback(initials, size),
              )
            : hasAvatarUrl
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildAvatarFallback(initials, size),
                  )
                : _buildAvatarFallback(initials, size),
      ),
    );
  }

  Widget _buildAvatarFallback(String initials, double size) {
    return Container(
      color: const Color(0xFF211635),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.lavenderAccent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatEvent?>(
      stream: _eventStream,
      initialData: widget.event,
      builder: (context, snapshot) {
        final event = snapshot.data ?? widget.event;
        _loadAttendeeUsers(event);

        final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;
        final isLocked = !event.isStarted || event.isEnded;
        final myResponse = event.myResponse(widget.currentUid);
        final participants =
            event.participantCount(groupMemberCount: _groupMemberCount);

        return GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: hasImage
                              ? Image.network(
                                  event.imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: const Color(0xFF2D1B69),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(color: const Color(0xFF2D1B69)),
                                )
                              : BackdropFilter(
                                  filter:
                                      ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                  child: Container(color: AppColors.eventCardBg),
                                ),
                        ),
                        if (hasImage)
                          const Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xB3000000),
                                    Color(0x59000000),
                                    Color(0xD9000000),
                                  ],
                                  stops: [0.0, 0.4, 1.0],
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              EventCardHeaderStrip(onInfoTap: widget.onInfoTap),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    EventInfoChips(event: event),
                                    if (event.isPlaceEvent) ...[
                                      const SizedBox(height: 8),
                                      _PlaceDistanceChip(event: event),
                                    ],
                                    const SizedBox(height: 14),
                                    EventStatusBar(
                                      eventDate: event.date,
                                      endDate: event.endDate,
                                    ),
                                    const SizedBox(height: 14),
                                    for (final response in EventResponse.values)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: EventVoteOption(
                                          label: response.label,
                                          count: event.countFor(response),
                                          total: participants,
                                          voters: event.votersFor(response),
                                          avatarBuilder: _buildAvatar,
                                          isSelected: myResponse == response,
                                          isLocked: isLocked,
                                          onTap: () => _vote(event, response),
                                        ),
                                      ),
                                    if (isLocked)
                                      EventRsvpLockRow(ended: event.isEnded),
                                    const SizedBox(height: 10),
                                    _CardFooter(event: event),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

/// Live "X from you" chip rendered only on place-type PickFight events.
/// Falls back to the host's snapshot distance, then to a location hint.
/// Tapping opens the distance-compare sheet.
class _PlaceDistanceChip extends StatefulWidget {
  final ChatEvent event;

  const _PlaceDistanceChip({required this.event});

  @override
  State<_PlaceDistanceChip> createState() => _PlaceDistanceChipState();
}

class _PlaceDistanceChipState extends State<_PlaceDistanceChip> {
  final _locationService = LocationService();
  String? _distanceText;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _loading = true);
    String? text;
    try {
      final position = await _locationService.getQuickPosition();
      final lat = widget.event.latitude;
      final lng = widget.event.longitude;
      if (position != null && lat != null && lng != null) {
        final meters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );
        text = '${_formatDistance(meters)} from you';
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _distanceText = text;
      _loading = false;
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.event.distanceSnapshot;
    final String label;
    if (_loading) {
      label = 'Measuring distance…';
    } else if (_distanceText != null) {
      label = '📍 $_distanceText';
    } else if (snapshot != null && snapshot.isNotEmpty) {
      label = '📍 $snapshot from the host — tap to compare your distance';
    } else {
      label = '📍 Turn on location to see distance';
    }

    return GestureDetector(
      onTap: () => showPlaceCompareSheet(context, widget.event),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.near_me_outlined,
                        size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  final ChatEvent event;

  const _CardFooter({required this.event});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.lavenderAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: AppColors.lavenderAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Text(
            'EVENT NAME',
            style: TextStyle(
              color: AppColors.lavenderAccent,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          event.title,
          style: const TextStyle(
            color: AppColors.lavenderAccent,
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            height: 1.15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
