import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/admin_division.dart';
import '../../../models/place_entity.dart';
import '../../../services/location/location_service.dart';
import '../../../services/location/overpass_service.dart';
import '../../../services/session/session_service.dart';
import '../waiting_lobby_screen.dart';

class CityPlacesScreen extends StatefulWidget {
  final AdminDivision city;
  final PlaceCategory category;

  const CityPlacesScreen({
    super.key,
    required this.city,
    required this.category,
  });

  @override
  State<CityPlacesScreen> createState() => _CityPlacesScreenState();
}

class _CityPlacesScreenState extends State<CityPlacesScreen> {
  final _locationService = LocationService();
  final _overpassService = OverpassService();
  final _sessionService = SessionService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _bg = const Color(0xFF190831);

  List<PlaceEntity> _places = [];
  bool _isLoading = true;
  bool _noPlacesFound = false;
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
      _noPlacesFound = false;
    });

    try {
      final position = await _locationService.getQuickPosition();

      final allPlaces = await _overpassService.getCityPlacesByCategory(
        widget.city.latitude,
        widget.city.longitude,
        category: widget.category,
        userLat: position?.latitude,
        userLng: position?.longitude,
      );

      final withDistance = allPlaces.map((p) {
        if (position == null) return p;
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

      if (picked.length < 2) {
        setState(() {
          _noPlacesFound = true;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _places = picked;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _noPlacesFound = true;
        _isLoading = false;
      });
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
        topic: widget.city.name,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.city.name,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      floatingActionButton: _places.length >= 2
          ? Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _isCreatingSession ? null : _startSession,
                backgroundColor: Colors.transparent,
                elevation: 0,
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
              ),
            )
          : null,
      body: _isLoading
          ? _buildSearching()
          : _noPlacesFound
              ? _buildNoPlacesFound()
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
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finding places in ${widget.city.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPlacesFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'No places found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'No places found in ${widget.city.name}. Try a different category or city.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
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
                  onPressed: _load,
                  child: const Text('Retry'),
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
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFE4EF0),
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
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      PlaceEntity.friendlyAmenity(place.amenity),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
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
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    place.formattedDistance,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFE4EF0),
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
