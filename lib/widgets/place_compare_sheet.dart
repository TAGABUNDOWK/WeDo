import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/event.dart';
import '../models/place_entity.dart';
import '../screens/chat/event/event_detail_screen.dart';
import '../services/location/location_service.dart';

/// Bottom sheet shown when a place-type PickFight event card is tapped in a
/// chat. Shows the place details plus a live straight-line distance from the
/// viewer's current location, and lets them open the place in Maps.
Future<void> showPlaceCompareSheet(BuildContext context, ChatEvent event) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF190831),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PlaceCompareSheet(event: event),
  );
}

class _PlaceCompareSheet extends StatefulWidget {
  final ChatEvent event;

  const _PlaceCompareSheet({required this.event});

  @override
  State<_PlaceCompareSheet> createState() => _PlaceCompareSheetState();
}

class _PlaceCompareSheetState extends State<_PlaceCompareSheet> {
  final _locationService = LocationService();
  StreamSubscription<Position>? _positionSub;
  Position? _position;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _position = position;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 25,
        ),
      ).listen((position) {
        if (mounted) setState(() => _position = position);
      }, onError: (_) {});
    } catch (_) {}
  }

  double? get _meters {
    final position = _position;
    final lat = widget.event.latitude;
    final lng = widget.event.longitude;
    if (position == null || lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      lat,
      lng,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Uri? get _mapsUri {
    final placeId = widget.event.placeId;
    if (placeId != null && placeId.isNotEmpty) {
      return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query_place_id=$placeId');
    }
    final lat = widget.event.latitude;
    final lng = widget.event.longitude;
    if (lat != null && lng != null) {
      return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    }
    return null;
  }

  Future<void> _openMaps() async {
    final uri = _mapsUri;
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openEventDetails() {
    final event = widget.event;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          groupId: event.groupId,
          chatId: event.chatId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;
    final meters = _meters;
    final tagLabel =
        (event.tag == null || event.tag!.isEmpty) ? null : PlaceEntity.friendlyAmenity(event.tag!);
    final rating = (event.rating == null || event.rating!.isEmpty)
        ? null
        : event.rating!;
    final address = (event.address == null || event.address!.isEmpty)
        ? null
        : event.address!;

    String distanceLabel;
    String distanceSubLabel;
    if (meters != null) {
      distanceLabel = _formatDistance(meters);
      distanceSubLabel = 'straight-line from your current location · updates as you move';
    } else if (_loading) {
      distanceLabel = '…';
      distanceSubLabel = 'measuring your distance';
    } else if (event.distanceSnapshot != null &&
        event.distanceSnapshot!.isNotEmpty) {
      distanceLabel = event.distanceSnapshot!;
      distanceSubLabel = 'from the host at game time · turn on location to see your distance';
    } else {
      distanceLabel = '—';
      distanceSubLabel = 'turn on location to see distance';
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: hasImage
                    ? Image.network(
                        event.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: const Color(0xFF2D1B69)),
                      )
                    : Container(
                        color: const Color(0xFF2D1B69),
                        child: const Icon(Icons.place_rounded,
                            color: Colors.white24, size: 56),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (tagLabel != null) _chip(tagLabel, Icons.place_outlined),
                if (rating != null) _chip(rating, Icons.star_rounded,
                    color: Colors.amber),
                if (event.location != null && event.location!.isNotEmpty)
                  _chip(event.location!, Icons.event_outlined),
              ],
            ),
            if (address != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFE4EF0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.near_me_rounded,
                        color: Color(0xFFFE4EF0), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          distanceLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          distanceSubLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _mapsUri != null ? _openMaps : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'Open in Maps',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _openEventDetails,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Event Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
      ),
    );
  }

  Widget _chip(String text, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.white70),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
