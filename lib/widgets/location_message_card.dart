import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../screens/location/location_detail_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class LocationMessageCard extends StatefulWidget {
  final double latitude;
  final double longitude;
  final bool isMe;
  final String? senderName;
  final String? address;
  final DateTime? liveUntil;
  final String? groupId;
  final String? chatId;
  final String? messageId;

  const LocationMessageCard({
    super.key,
    required this.latitude,
    required this.longitude,
    this.isMe = false,
    this.senderName,
    this.address,
    this.liveUntil,
    this.groupId,
    this.chatId,
    this.messageId,
  });

  @override
  State<LocationMessageCard> createState() => _LocationMessageCardState();
}

class _LocationMessageCardState extends State<LocationMessageCard> {
  Timer? _timer;
  Timer? _expiryTimer;

  bool get _isLive =>
      widget.liveUntil != null &&
      widget.liveUntil!.isAfter(DateTime.now());

  /// Live share whose window has passed → render a map-free placeholder.
  bool get _ended => widget.liveUntil != null && !_isLive;

  @override
  void initState() {
    super.initState();
    if (widget.liveUntil != null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        if (!_isLive) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
      // Swap to the minimal ended view the moment the share expires
      // instead of up to 30 s later.
      final remaining = widget.liveUntil!.difference(DateTime.now());
      if (!remaining.isNegative) {
        _expiryTimer = Timer(remaining, () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _openDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationDetailScreen(
          latitude: widget.latitude,
          longitude: widget.longitude,
          address: widget.address,
          liveUntil: widget.liveUntil,
          groupId: widget.groupId,
          chatId: widget.chatId,
          messageId: widget.messageId,
        ),
      ),
    );
  }

  String _countdownLabel() {
    final remaining = widget.liveUntil!.difference(DateTime.now());
    if (remaining.isNegative) return 'ended';
    final mins = remaining.inMinutes;
    if (mins < 1) return '<1 min';
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final live = _isLive;
    final showSender =
        !widget.isMe &&
        widget.senderName != null &&
        widget.senderName!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Align(
        alignment:
            widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: _openDetail,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    height: 150,
                    child: Stack(
                      children: [
                        if (!_ended)
                          GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              widget.latitude,
                              widget.longitude,
                            ),
                            zoom: 16,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('pin'),
                              position: LatLng(
                                widget.latitude,
                                widget.longitude,
                              ),
                            ),
                          },
                          // Inert preview: the whole card is the tap
                          // target and it lives inside a scrollable
                          // list, so no map gestures may win.
                          gestureRecognizers: const {},
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                          compassEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          liteModeEnabled: false,
                        ),
                        if (_ended)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF241145),
                                    Color(0xFF150A2E),
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stop_circle_outlined,
                                    size: 34,
                                    color:
                                        Colors.white.withValues(alpha: 0.38),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Live sharing ended',
                                    style: TextStyle(
                                      fontFamily: _fontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Colors.white.withValues(alpha: 0.66),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (live)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(
                                  alpha: 0.7,
                                ),
                                borderRadius:
                                    BorderRadius.circular(50),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: Color(0xFF25D366),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Live • ${_countdownLabel()}',
                                    style: const TextStyle(
                                      fontFamily: _fontFamily,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF25D366),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.78),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  live
                                      ? Icons.wifi_tethering
                                      : _ended
                                          ? Icons.stop_circle_outlined
                                          : Icons.location_on,
                                  size: 14,
                                  color: live || !_ended
                                      ? const Color(0xFF25D366)
                                      : Colors.white.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.address ??
                                        (_ended
                                            ? 'Live sharing ended'
                                            : 'Location'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: _fontFamily,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _ended ? 'Ended' : 'View',
                                  style: TextStyle(
                                    fontFamily: _fontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _ended
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : const Color(0xFF25D366)
                                            .withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showSender)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE6190831),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '${widget.senderName} shared a location',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
