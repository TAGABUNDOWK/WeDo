import 'package:geolocator/geolocator.dart';

class PlaceEntity {
  final String id;
  final String name;
  final String amenity;
  final double latitude;
  final double longitude;
  final double? distanceFromUser;

  // Rich data from Google Places (New); null on Overpass results.
  final double? rating;
  final int? ratingCount;
  final String? summary;

  /// Photo resource names (`places/{id}/photos/{photo}`) ranked best-first
  /// by resolution/aspect heuristics; empty on Overpass results.
  final List<String> photoCandidates;
  final String? priceLevel;
  final String? address;

  /// Signed, key-free CDN URL of the place's cover photo. Resolved once
  /// via `GooglePlacesService.resolveCoverUrl`; null until resolved.
  String? coverUrl;

  PlaceEntity({
    required this.id,
    required this.name,
    required this.amenity,
    required this.latitude,
    required this.longitude,
    this.distanceFromUser,
    this.rating,
    this.ratingCount,
    this.summary,
    this.photoCandidates = const [],
    this.priceLevel,
    this.address,
    this.coverUrl,
  });

  PlaceEntity copyWith({double? distanceFromUser, String? coverUrl}) {
    return PlaceEntity(
      id: id,
      name: name,
      amenity: amenity,
      latitude: latitude,
      longitude: longitude,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      rating: rating,
      ratingCount: ratingCount,
      summary: summary,
      photoCandidates: photoCandidates,
      priceLevel: priceLevel,
      address: address,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  String get formattedDistance {
    if (distanceFromUser == null) return '';
    final meters = distanceFromUser!;
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  /// `"4.5 (123)"`, or '' when Google returned no rating.
  String get ratingLabel {
    final r = rating;
    if (r == null) return '';
    final count = ratingCount ?? 0;
    return count > 0 ? '${r.toStringAsFixed(1)} ($count)' : r.toStringAsFixed(1);
  }

  /// Google editorial summary when available, else the OSM amenity label.
  String get friendlySummary {
    final s = summary;
    if (s != null && s.isNotEmpty) return s;
    return friendlyAmenity(amenity);
  }

  static double distanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  static String friendlyAmenity(String tag) {
    switch (tag) {
      case 'cafe':
        return 'Cafe';
      case 'restaurant':
        return 'Restaurant';
      case 'bar':
        return 'Bar';
      case 'pub':
        return 'Pub';
      case 'ice_cream':
        return 'Ice Cream';
      case 'cinema':
        return 'Cinema';
      case 'theatre':
        return 'Theater';
      case 'fast_food':
        return 'Fast Food';
      case 'food_court':
        return 'Food Court';
      case 'bakery':
        return 'Bakery';
      case 'nightclub':
        return 'Nightclub';
      case 'karaoke':
        return 'Karaoke';
      case 'juice_bar':
        return 'Juice Bar';
      case 'park':
        return 'Park';
      case 'garden':
        return 'Garden';
      case 'bowling_alley':
        return 'Bowling';
      case 'amusement_arcade':
        return 'Arcade';
      case 'fitness_centre':
        return 'Gym';
      case 'sports_centre':
        return 'Sports Center';
      case 'swimming_pool':
        return 'Pool';
      case 'skatepark':
        return 'Skatepark';
      case 'nature_reserve':
        return 'Nature Reserve';
      case 'art_gallery':
        return 'Art Gallery';
      case 'museum':
        return 'Museum';
      case 'viewpoint':
        return 'Viewpoint';
      case 'camp_site':
        return 'Camp Site';
      case 'books':
        return 'Bookstore';
      case 'marketplace':
        return 'Market';
      case 'clothes':
        return 'Clothing';
      case 'electronics':
        return 'Electronics';
      case 'mall':
        return 'Mall';
      case 'department_store':
        return 'Department Store';
      case 'hotel':
      case 'motel':
      case 'hostel':
      case 'guest_house':
        return 'Hotel';
      case 'hairdresser':
        return 'Salon';
      case 'beauty':
        return 'Beauty Salon';
      case 'resort':
        return 'Resort';
      case 'beach_resort':
        return 'Beach Resort';
      case 'beach':
        return 'Beach';
      default:
        return tag;
    }
  }
}
