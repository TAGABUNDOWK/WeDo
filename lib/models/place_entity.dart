import 'package:geolocator/geolocator.dart';

class PlaceEntity {
  final String id;
  final String name;
  final String amenity;
  final double latitude;
  final double longitude;
  final double? distanceFromUser;

  const PlaceEntity({
    required this.id,
    required this.name,
    required this.amenity,
    required this.latitude,
    required this.longitude,
    this.distanceFromUser,
  });
 
  PlaceEntity copyWith({double? distanceFromUser}) {
    return PlaceEntity(
      id: id,
      name: name,
      amenity: amenity,
      latitude: latitude,
      longitude: longitude,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
    );
  }

  String get formattedDistance {
    if (distanceFromUser == null) return '';
    final meters = distanceFromUser!;
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
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
