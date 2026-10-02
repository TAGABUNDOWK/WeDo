import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/location/geocoding_service.dart';
import '../../services/location/location_service.dart';
import '../../utils/constants.dart';
import 'place_search_screen.dart';

class PickedLocation {
  final double latitude;
  final double longitude;
  final String? address;

  /// Non-null when the user chose to share live location.
  final Duration? liveDuration;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.liveDuration,
  });
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _fallbackCenter = LatLng(14.5995, 120.9842);

  GoogleMapController? _mapController;
  CameraPosition? _pendingCamera;
  final _locationService = LocationService();
  final _geocoding = GeocodingService();

  LatLng _center = _fallbackCenter;
  bool _locating = true;

  /// Set when the camera was moved by us (current-location button or
  /// place search) so `onCameraMove` doesn't wipe the picked address.
  bool _programmaticMove = false;

  /// Address that came from place search — reused as-is when sending.
  String? _pickedAddress;

  /// 0 = send pin point, 1 = live 15 min, 2 = live 1 hour.
  int _mode = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _goToCurrentLocation();
  }

  @override
  void dispose() {
    // The GoogleMap widget disposes its own controller on unmount.
    super.dispose();
  }

  void _moveTo(LatLng target, double zoom) {
    _programmaticMove = true;
    final controller = _mapController;
    if (controller != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
    } else {
      _pendingCamera = CameraPosition(target: target, zoom: zoom);
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        final point = LatLng(position.latitude, position.longitude);
        setState(() {
          _center = point;
          _pickedAddress = null;
        });
        _moveTo(point, 16);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push<PlaceSearchResult>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _center = LatLng(result.latitude, result.longitude);
      _pickedAddress = result.address;
    });
    _moveTo(_center, 16);
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);

    // Address from place search is used as-is; otherwise one
    // best-effort reverse geocode so the chat card can show an
    // address without ever hitting the network again.
    String? address = _pickedAddress;
    if (address == null) {
      try {
        address = await _geocoding.reverse(
          _center.latitude,
          _center.longitude,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      PickedLocation(
        latitude: _center.latitude,
        longitude: _center.longitude,
        address: address,
        liveDuration: switch (_mode) {
          1 => const Duration(minutes: 15),
          2 => const Duration(hours: 1),
          _ => null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBg,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              final pending = _pendingCamera;
              if (pending != null) {
                _pendingCamera = null;
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(pending.target, pending.zoom),
                );
              }
            },
            onCameraMove: (position) {
              _center = position.target;
              if (!_programmaticMove) _pickedAddress = null;
              setState(() {});
            },
            onCameraIdle: () => _programmaticMove = false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          // Fixed center pin: the map pans underneath it.
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -26),
                  child: const Icon(
                    Icons.location_pin,
                    size: 52,
                    color: Color(0xFFFF4D6D),
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE6190831),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: const Text(
                      'Share location',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _GlassButton(
                    icon: Icons.search,
                    onTap: _openSearch,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 172,
            child: _GlassButton(
              icon: Icons.my_location,
              onTap: _locating ? null : _goToCurrentLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xE6190831),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _modeChip(0, 'Pin point', Icons.push_pin_outlined),
                        const SizedBox(width: 8),
                        _modeChip(1, 'Live 15 min', Icons.timer_outlined),
                        const SizedBox(width: 8),
                        _modeChip(2, 'Live 1 hr', Icons.timer_outlined),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Selected location',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_center.latitude.toStringAsFixed(5)}, '
                                '${_center.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _sending ? null : _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.black,
                            disabledBackgroundColor:
                                const Color(0xFF25D366),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  _mode == 0 ? 'Send' : 'Start',
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _modeChip(int mode, String label, IconData icon) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF25D366).withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected
                ? const Color(0xFF25D366)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected
                  ? const Color(0xFF25D366)
                  : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF25D366)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? child;

  const _GlassButton({required this.icon, this.onTap, this.child});

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
          width: 44,
          height: 44,
          child: Center(
            child: child ?? Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
