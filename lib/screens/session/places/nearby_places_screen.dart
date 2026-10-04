import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/place_category.dart';
import '../../../models/place_entity.dart';
import '../../../services/location/google_places_service.dart';
import '../../../services/location/location_service.dart';
import '../../../services/location/places_search_service.dart';
import '../../../services/session/session_service.dart';
import '../../../widgets/place_detail_sheet.dart';
import '../waiting_lobby_screen.dart';

class NearbyPlacesScreen extends StatefulWidget {
  final String title;
  final PlaceCategory category;

  const NearbyPlacesScreen({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  State<NearbyPlacesScreen> createState() => _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends State<NearbyPlacesScreen> {
  final _locationService = LocationService();
  final _placesSearch = PlacesSearchService();
  final _sessionService = SessionService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _bg = const Color(0xFF190831);

  List<PlaceEntity> _places = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  bool _noPlacesFound = false;
  bool _isCreatingSession = false;
  String _searchStatus = 'Searching within 5km...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _categorySearchLabel => 'Searching for ${widget.category.label}';

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
      _noPlacesFound = false;
      _searchStatus = '$_categorySearchLabel within 5km...';
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
      List<PlaceEntity> allPlaces = [];

      const radii = [5000, 25000, 50000];
      const labels = ['5km', '25km', '50km'];

      for (var i = 0; i < radii.length; i++) {
        if (!mounted) return;
        setState(() => _searchStatus = '$_categorySearchLabel within ${labels[i]}...');

        allPlaces = await _placesSearch.nearby(
          position.latitude,
          position.longitude,
          category: widget.category,
          radiusM: radii[i],
        );

        if (allPlaces.length >= 5 || i == radii.length - 1) break;
      }

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

      if (picked.length < 2) {
        setState(() {
          _noPlacesFound = true;
          _isLoading = false;
        });
        return;
      }

      await GooglePlacesService.resolveCoverUrls(picked);
      if (!mounted) return;

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
      final cardMaps = _places.map((p) {
        final card = <String, dynamic>{
          'id': p.id,
          'title': p.name,
          'description': p.friendlySummary,
          'tag': p.amenity,
          'distance': p.formattedDistance,
          'latitude': p.latitude,
          'longitude': p.longitude,
        };
        if (p.address != null) card['address'] = p.address;
        if (p.coverUrl != null) card['posterUrl'] = p.coverUrl;
        if (p.ratingLabel.isNotEmpty) card['rating'] = p.ratingLabel;
        return card;
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
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
                label: Text(_isCreatingSession ? 'Creating...' : 'Start PickFight'),
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
          : _permissionDenied
              ? _buildPermissionDenied()
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
            Text(
              _searchStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This may take a moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white54,
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
            const Icon(Icons.location_off, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Location access needed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow location access to find places near you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
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
              'No ${widget.title.toLowerCase()} places found nearby. Try a different category or check back later.',
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
        return GestureDetector(
          onTap: () =>
              showPlaceDetailSheet(context, PlaceDetailData.fromPlace(place)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
            ),
            child: Row(
              children: [
                _buildLeading(index, place),
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
                        place.friendlySummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (place.ratingLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 12, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              place.ratingLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (place.ratingLabel.isNotEmpty &&
                        place.formattedDistance.isNotEmpty)
                      const SizedBox(height: 6),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeading(int index, PlaceEntity place) {
    final coverUrl = place.coverUrl;
    if (coverUrl == null) return _numberBadge(index);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        coverUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _numberBadge(index),
      ),
    );
  }

  Widget _numberBadge(int index) {
    return Container(
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
    );
  }
}
