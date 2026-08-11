import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/place_entity.dart';
import '../../services/location/location_service.dart';
import '../../services/location/overpass_service.dart';
import '../../services/session/session_service.dart';
import 'waiting_lobby_screen.dart';

class NearbyPlacesScreen extends StatefulWidget {
  final String title;
  final bool foodMode;

  const NearbyPlacesScreen({
    super.key,
    this.title = 'Nearby places',
    this.foodMode = false,
  });

  @override
  State<NearbyPlacesScreen> createState() => _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends State<NearbyPlacesScreen> {
  final _locationService = LocationService();
  final _overpassService = OverpassService();
  final _sessionService = SessionService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _bg = const Color(0xFFE7ECEF);

  List<PlaceEntity> _places = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  bool _isCreatingSession = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    final position = await _locationService.getQuickPosition();
    if (position == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      return;
    }

    try {
      final allPlaces = widget.foodMode
          ? await _overpassService.getNearbyFoodPlaces(
              position.latitude,
              position.longitude,
              radiusM: 5000,
            )
          : await _overpassService.getHangoutPlaces(
              position.latitude,
              position.longitude,
              radiusM: 5000,
            );

      final withDistance = allPlaces.map((p) {
        final dist = PlaceEntity.distanceBetween(
          position.latitude,
          position.longitude,
          p.latitude,
          p.longitude,
        );
        return p.copyWith(distanceFromUser: dist);
      }).toList();

      final shuffled = List<PlaceEntity>.from(withDistance)..shuffle(Random());
      final picked = shuffled.take(10).toList();

      if (!mounted) return;

      if (picked.isEmpty) {
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) _load();
        return;
      }

      setState(() {
        _places = picked;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) _load();
    }
  }

  Future<void> _startSession() async {
    if (_currentUser == null || _isCreatingSession || _places.isEmpty) return;

    setState(() => _isCreatingSession = true);

    try {
      final cardMaps = _places.map((p) => {
        'id': p.id,
        'title': p.name,
        'description': PlaceEntity.friendlyAmenity(p.amenity),
        'tag': p.amenity,
        'distance': p.formattedDistance,
      }).toList();

      final code = await _sessionService.createSession(
        hostId: _currentUser.uid,
        topic: widget.title,
        cards: cardMaps,
      );

      await _sessionService.joinSession(
        sessionId: code,
        userId: _currentUser.uid,
        userName: _currentUser.displayName ?? _currentUser.email ?? 'Host',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingLobbyScreen(sessionId: code, isHost: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: _places.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isCreatingSession ? null : _startSession,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              label: Text(_isCreatingSession ? 'Creating...' : 'Start Session'),
              icon: _isCreatingSession
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
            )
          : null,
      body: _isLoading
          ? _buildSearching()
          : _permissionDenied
              ? _buildPermissionDenied()
              : _buildList(),
    );
  }

  Widget _buildSearching() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Please wait, searching for places...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            const Text(
              'Location access needed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Allow location access to find ${widget.foodMode ? 'places to eat' : 'hangout spots'} near you.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () async {
                    await _locationService.openLocationSettings();
                    _load();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _places.length,
      itemBuilder: (context, index) {
        final place = _places[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFFFFFFF),
                offset: Offset(-6, -6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: Color(0xFFB8C6CC),
                offset: Offset(6, 6),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      PlaceEntity.friendlyAmenity(place.amenity),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              if (place.formattedDistance.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    place.formattedDistance,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
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
