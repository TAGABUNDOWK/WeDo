import '../../config/maps_key.dart';
import '../../models/place_category.dart';
import '../../models/place_entity.dart';
import 'google_places_service.dart';
import 'overpass_service.dart';

/// Unified place lookup for PickFight topics:
/// 1. Google Places API (New) — rich data (stars, description, photo).
/// 2. Overpass (OpenStreetMap) — free fallback when the key is missing,
///    quota/billing fails, or Google simply has no results.
class PlacesSearchService {
  final GooglePlacesService _google = GooglePlacesService();
  final OverpassService _overpass = OverpassService();

  /// Places matching [category] within [radiusM] of (lat, lng).
  Future<List<PlaceEntity>> nearby(
    double lat,
    double lng, {
    required PlaceCategory category,
    int radiusM = 5000,
  }) async {
    if (mapsApiKeyIsConfigured) {
      final results = await _google.getNearby(
        lat,
        lng,
        category: category,
        radiusM: radiusM,
      );
      if (results.isNotEmpty) return results;
    }
    return _overpass.getPlacesByCategory(
      lat,
      lng,
      category: category,
      radiusM: radiusM,
    );
  }

  /// Places matching [category] within [radiusM] of a chosen city center.
  /// Distances (if any) are resolved against the user position.
  Future<List<PlaceEntity>> cityPlaces(
    double cityLat,
    double cityLng, {
    required PlaceCategory category,
    double? userLat,
    double? userLng,
    int radiusM = 20000,
  }) async {
    if (mapsApiKeyIsConfigured) {
      final results = await _google.getNearby(
        cityLat,
        cityLng,
        category: category,
        radiusM: radiusM,
      );
      if (results.isNotEmpty) {
        if (userLat == null || userLng == null) return results;
        return results
            .map((p) => p.copyWith(
                  distanceFromUser: PlaceEntity.distanceBetween(
                    userLat,
                    userLng,
                    p.latitude,
                    p.longitude,
                  ),
                ))
            .toList();
      }
    }
    return _overpass.getCityPlacesByCategory(
      cityLat,
      cityLng,
      category: category,
      userLat: userLat,
      userLng: userLng,
      radiusM: radiusM,
    );
  }
}
