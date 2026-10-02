import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../models/message.dart';
import '../../services/direct/direct_service.dart';
import '../../services/group/group_service.dart';
import '../../services/location/geocoding_service.dart';
import '../../services/location/location_service.dart';
import '../../services/location/routing_service.dart';
import '../../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

/// Full-screen view of a shared location: route line + ETA + live
/// distance from the device GPS, address chip, and a deep link into
/// the real Google Maps app for turn-by-turn navigation.
///
/// When opened for a live-location message (groupId/chatId +
/// messageId), the destination pin follows the sender's position in
/// real time until `liveUntil` passes.
class LocationDetailScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime? liveUntil;
  final String? groupId;
  final String? chatId;
  final String? messageId;

  const LocationDetailScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.liveUntil,
    this.groupId,
    this.chatId,
    this.messageId,
  });

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  GoogleMapController? _mapController;
  final _routing = RoutingService();
  final _geocoding = GeocodingService();
  final _locationService = LocationService();
  final _groupService = GroupService();
  final _directService = DirectService();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<ChatMessage>? _messageSub;
  Timer? _ticker;

  Position? _myPosition;
  RouteResult? _route;
  LatLng? _routeFrom;
  LatLng? _routeTo;
  bool _loadingRoute = false;
  bool _routeFitted = false;
  DateTime? _lastFetchAttempt;
  String _profile = 'foot';

  String? _address;
  bool _loadingAddress = false;

  late double _destLat;
  late double _destLng;
  late DateTime? _liveUntil;
  bool _isLive = false;
  DateTime? _lastFixAt;

  bool get _hasLiveStream =>
      widget.messageId != null &&
      (widget.groupId != null || widget.chatId != null);

  /// Live share whose window has passed → render the map-free view.
  bool get _ended => _liveUntil != null && !_isLive;

  @override
  void initState() {
    super.initState();
    _destLat = widget.latitude;
    _destLng = widget.longitude;
    _address = widget.address;
    _liveUntil = widget.liveUntil;
    _isLive = _liveUntil != null && _liveUntil!.isAfter(DateTime.now());

    if (!_ended) {
      _initMyPosition();
      _initLiveStream();
      if (_isLive) _startTicker();
    }
    if (_address == null) _loadAddress();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _positionSub?.cancel();
    _messageSub?.cancel();
    // Note: the GoogleMap widget disposes its own controller on unmount.
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final live =
          _liveUntil != null && _liveUntil!.isAfter(DateTime.now());
      if (live) {
        setState(() {});
      } else {
        // Expired while open: drop all live work. On rebuild the map
        // unmounts (its widget disposes the platform controller) and
        // the minimal ended view is shown instead.
        _positionSub?.cancel();
        _positionSub = null;
        _messageSub?.cancel();
        _messageSub = null;
        _mapController = null;
        _ticker?.cancel();
        _ticker = null;
        setState(() => _isLive = false);
      }
    });
  }

  Future<void> _initMyPosition() async {
    try {
      final granted = await _locationService.isPermissionGranted();
      if (!granted || !mounted) return;
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (!mounted) return;
        setState(() => _myPosition = position);
        _fetchRouteIfNeeded();
      }, onError: (_) {});
    } catch (_) {}
  }

  void _initLiveStream() {
    if (!_hasLiveStream) return;
    final stream = widget.groupId != null
        ? _groupService.watchMessage(
            groupId: widget.groupId!,
            messageId: widget.messageId!,
          )
        : _directService.watchMessage(
            chatId: widget.chatId!,
            messageId: widget.messageId!,
          );
    _messageSub = stream.listen((msg) {
      if (!mounted) return;
      setState(() {
        if (msg.latitude != null) {
          _destLat = msg.latitude!;
          _destLng = msg.longitude!;
        }
        if (msg.updatedAt != null) _lastFixAt = msg.updatedAt;
        if (msg.liveUntil != null) _liveUntil = msg.liveUntil;
        _isLive = _liveUntil != null && _liveUntil!.isAfter(DateTime.now());
      });
      _fetchRouteIfNeeded();
    }, onError: (_) {});
  }

  Future<void> _loadAddress() async {
    setState(() => _loadingAddress = true);
    final result = await _geocoding.reverse(_destLat, _destLng);
    if (!mounted) return;
    setState(() {
      if (result != null) _address = result;
      _loadingAddress = false;
    });
  }

  Future<void> _fetchRouteIfNeeded({bool force = false}) async {
    if (_ended || _loadingRoute || _myPosition == null) return;

    final from = LatLng(_myPosition!.latitude, _myPosition!.longitude);
    final to = LatLng(_destLat, _destLng);

    if (!force) {
      if (_route != null && _routeFrom != null && _routeTo != null) {
        final movedFrom = Geolocator.distanceBetween(
          from.latitude,
          from.longitude,
          _routeFrom!.latitude,
          _routeFrom!.longitude,
        );
        final movedTo = Geolocator.distanceBetween(
          to.latitude,
          to.longitude,
          _routeTo!.latitude,
          _routeTo!.longitude,
        );
        if (movedFrom < 100 && movedTo < 100) return;
      } else if (_lastFetchAttempt != null &&
          DateTime.now().difference(_lastFetchAttempt!) <
              const Duration(seconds: 60)) {
        // Previous fetch failed — back off to respect the ~1 req/s
        // community-server policy.
        return;
      }
    }

    _lastFetchAttempt = DateTime.now();
    setState(() => _loadingRoute = true);
    final result = await _routing.getRoute(
      from: ll.LatLng(from.latitude, from.longitude),
      to: ll.LatLng(to.latitude, to.longitude),
      profile: _profile,
    );
    if (!mounted) return;
    setState(() {
      _route = result;
      _routeFrom = result != null ? from : null;
      _routeTo = result != null ? to : null;
      _loadingRoute = false;
      if (!_routeFitted && _mapController != null) {
        _routeFitted = true;
        _fitRoute();
      }
    });
  }

  void _fitRoute() {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[
      if (_myPosition != null)
        LatLng(_myPosition!.latitude, _myPosition!.longitude),
      LatLng(_destLat, _destLng),
      ..._routePoints,
    ];
    if (points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    try {
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          70,
        ),
      );
    } catch (_) {}
  }

  /// Route points converted from latlong2 (RoutingService) to the
  /// google_maps_flutter LatLng type.
  List<LatLng> get _routePoints {
    final route = _route;
    if (route == null) return const [];
    return route.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
  }

  void _setProfile(String profile) {
    if (_profile == profile) return;
    setState(() => _profile = profile);
    _fetchRouteIfNeeded(force: true);
  }

  double? get _straightMeters {
    final pos = _myPosition;
    if (pos == null) return null;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _destLat,
      _destLng,
    );
  }

  String? get _etaText {
    final straight = _straightMeters;
    if (straight == null) return null;
    final route = _route;
    if (route != null && route.distanceMeters > 0) {
      return _formatDuration(
        straight / route.distanceMeters * route.durationSeconds,
      );
    }
    final speed = _profile == 'foot' ? 1.35 : 11.0;
    return _formatDuration(straight / speed);
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static String _formatDuration(double seconds) {
    final mins = (seconds / 60).round();
    if (mins < 1) return 'under 1 min';
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  String _countdownText() {
    final remaining = _liveUntil!.difference(DateTime.now());
    if (remaining.isNegative) return 'ended';
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openInGoogleMaps() async {
    final url =
        'https://maps.google.com/?daddr=$_destLat,$_destLng'
        '&dir_action=navigate';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening Google Maps: $e');
    }
  }

  void _copyCoordinates() {
    Clipboard.setData(ClipboardData(text: '$_destLat, $_destLng'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coordinates copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBg,
      body: Stack(
        children: [
          if (!_ended)
            GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_destLat, _destLng),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_route != null && !_routeFitted) {
                _routeFitted = true;
                _fitRoute();
              }
            },
            polylines: {
              if (_route != null) ...[
                Polyline(
                  polylineId: const PolylineId('route-outline'),
                  points: _routePoints,
                  width: 9,
                  color: Colors.white.withValues(alpha: 0.55),
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _routePoints,
                  width: 5,
                  color: const Color(0xFF7D56F5),
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
              ],
            },
            markers: {
              Marker(
                markerId: const MarkerId('dest'),
                position: LatLng(_destLat, _destLng),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          if (_ended) _buildEndedPane(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _GlassCircleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildAddressChip()),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: _ended ? _buildEndedActions() : _buildBottomCard(),
            ),
          ),
        ],
      ),
    );
  }

  /// Map-free body for expired live shares: a single card that only
  /// says the share ended (no tiles, no route, no GPS).
  Widget _buildEndedPane() {
    return Positioned.fill(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xE6190831),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 46,
                color: Colors.white.withValues(alpha: 0.38),
              ),
              const SizedBox(height: 14),
              const Text(
                'Live sharing ended',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_destLat.toStringAsFixed(5)}, '
                '${_destLng.toStringAsFixed(5)}',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No longer updating',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Actions for expired live shares: deep-link out to Google Maps or
  /// copy coordinates — no stats (no GPS/route needed).
  Widget _buildEndedActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xE6190831),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _openInGoogleMaps,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              icon: const Icon(Icons.directions, size: 18),
              label: const Text(
                'Open in Google Maps',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _GlassCircleButton(
            icon: Icons.copy_outlined,
            size: 42,
            onTap: _copyCoordinates,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE6190831),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 16,
            color: _isLive
                ? const Color(0xFF25D366)
                : Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _address != null
                ? Text(
                    _address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _loadingAddress ? 'Finding address…' : 'Shared location',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    final straight = _straightMeters;
    final eta = _etaText;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xE6190831),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLive) _buildLiveRow(),
          if (!_isLive && widget.liveUntil != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.stop_circle_outlined,
                      size: 16, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(
                    'Live sharing ended',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _statColumn(
                  'Distance',
                  straight == null ? '—' : _formatDistance(straight),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _statColumn('ETA', eta ?? '—'),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _profileChip('foot', 'Walk', Icons.directions_walk),
                  const SizedBox(height: 6),
                  _profileChip('car', 'Drive', Icons.directions_car),
                ],
              ),
            ],
          ),
          if (straight == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Turn on location to see distance',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openInGoogleMaps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text(
                    'Open in Google Maps',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GlassCircleButton(
                icon: Icons.copy_outlined,
                size: 42,
                onTap: _copyCoordinates,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRow() {
    final ago = _lastFixAt == null
        ? null
        : DateTime.now().difference(_lastFixAt!).inSeconds;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF25D366)),
          const SizedBox(width: 6),
          Text(
            'Live • ${_countdownText()} left',
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF25D366),
            ),
          ),
          if (ago != null) ...[
            const SizedBox(width: 8),
            Text(
              'updated ${ago}s ago',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
          const Spacer(),
          if (_loadingRoute)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF25D366),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _profileChip(String profile, String label, IconData icon) {
    final selected = _profile == profile;
    return GestureDetector(
      onTap: () => _setProfile(profile),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _GlassCircleButton({
    required this.icon,
    this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6190831),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}
