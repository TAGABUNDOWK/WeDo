import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/place_entity.dart';

class OverpassService {
  static const String _endpoint = 'https://overpass-api.de/api/interpreter';
  static const String _userAgent = 'WeDoApp/1.0 (contact: dev@wedo.app)';

  static const String _amenityTags = 'cinema|theatre|nightclub|karaoke';
  static const String _foodAmenityTags =
      'cafe|restaurant|bar|pub|ice_cream|fast_food|food_court|bakery|juice_bar';
  static const String _leisureTags =
      'park|garden|bowling_alley|amusement_arcade|fitness_centre|sports_centre|swimming_pool|skatepark|nature_reserve';
  static const String _tourismTags = 'art_gallery|museum|viewpoint|camp_site';
  static const String _shopTags = 'books|marketplace|clothes|electronics|mall';

  static final Map<String, _CacheEntry<String?>> _labelCache = {};
  static final Map<String, _CacheEntry<List<String>>> _poiCache = {};

  Future<String?> labelArea(double lat, double lng) async {
    final key = _roundKey(lat, lng);
    final cached = _labelCache[key];
    if (cached != null && !cached.isExpired()) {
      return cached.value;
    }

    final query =
        '[out:json][timeout:15];node["place"](around:20000,$lat,$lng);out tags 5;';
    List<Map<String, dynamic>> result;
    try {
      result = await _fetch(query);
    } catch (_) {
      return null;
    }

    for (final element in result) {
      final tags = element['tags'] as Map<String, dynamic>?;
      final name = tags?['name'];
      if (name is String && name.isNotEmpty) {
        _labelCache[key] = _CacheEntry(name, const Duration(minutes: 60));
        return name;
      }
    }
    return null;
  }

  Future<List<String>> nearbyStudyPlaces(
    double lat,
    double lng, {
    int radiusM = 10000,
  }) async {
    final key = _roundKey(lat, lng);
    final cached = _poiCache[key];
    if (cached != null && !cached.isExpired()) {
      return cached.value;
    }

    final query =
        '[out:json][timeout:20];node["amenity"~"^(school|library|university|college|community_centre|study)\$"](around:$radiusM,$lat,$lng);out tags 50;';
    List<Map<String, dynamic>> result;
    try {
      result = await _fetch(query);
    } catch (_) {
      return const [];
    }

    final names = <String>{};
    for (final element in result) {
      final tags = element['tags'] as Map<String, dynamic>?;
      final name = tags?['name'];
      if (name is String && name.isNotEmpty) {
        names.add(name);
      }
      if (names.length >= 8) break;
    }

    final list = names.take(8).toList();
    _poiCache[key] = _CacheEntry(list, const Duration(minutes: 30));
    return list;
  }

  Future<List<PlaceEntity>> getHangoutPlaces(
    double lat,
    double lng, {
    int radiusM = 5000,
  }) async {
    final query = '''
[out:json][timeout:30];
(
  node["amenity"~"^($_amenityTags)\$"](around:$radiusM,$lat,$lng);
  way["amenity"~"^($_amenityTags)\$"](around:$radiusM,$lat,$lng);
  node["leisure"~"^($_leisureTags)\$"](around:$radiusM,$lat,$lng);
  way["leisure"~"^($_leisureTags)\$"](around:$radiusM,$lat,$lng);
  node["tourism"~"^($_tourismTags)\$"](around:$radiusM,$lat,$lng);
  way["tourism"~"^($_tourismTags)\$"](around:$radiusM,$lat,$lng);
  node["shop"~"^($_shopTags)\$"](around:$radiusM,$lat,$lng);
  way["shop"~"^($_shopTags)\$"](around:$radiusM,$lat,$lng);
);
out center tags;
''';
    final result = await _fetch(query);

    return _parsePlaces(result, lat, lng);
  }

  Future<List<PlaceEntity>> getCityPlaces(
    double cityLat,
    double cityLng, {
    double? userLat,
    double? userLng,
    int radiusM = 20000,
  }) async {
    final query = '''
[out:json][timeout:30];
(
  node["amenity"~"^($_amenityTags)\$"](around:$radiusM,$cityLat,$cityLng);
  way["amenity"~"^($_amenityTags)\$"](around:$radiusM,$cityLat,$cityLng);
  node["leisure"~"^($_leisureTags)\$"](around:$radiusM,$cityLat,$cityLng);
  way["leisure"~"^($_leisureTags)\$"](around:$radiusM,$cityLat,$cityLng);
  node["tourism"~"^($_tourismTags)\$"](around:$radiusM,$cityLat,$cityLng);
  way["tourism"~"^($_tourismTags)\$"](around:$radiusM,$cityLat,$cityLng);
  node["shop"~"^($_shopTags)\$"](around:$radiusM,$cityLat,$cityLng);
  way["shop"~"^($_shopTags)\$"](around:$radiusM,$cityLat,$cityLng);
);
out center tags;
''';
    final result = await _fetch(query);

    return _parsePlaces(result, userLat, userLng);
  }

  Future<List<PlaceEntity>> getNearbyFoodPlaces(
    double lat,
    double lng, {
    int radiusM = 5000,
  }) async {
    final query = '''
[out:json][timeout:30];
(
  node["amenity"~"^($_foodAmenityTags)\$"](around:$radiusM,$lat,$lng);
  way["amenity"~"^($_foodAmenityTags)\$"](around:$radiusM,$lat,$lng);
);
out center tags;
''';
    final result = await _fetch(query);
    return _parsePlaces(result, lat, lng);
  }

  Future<List<PlaceEntity>> getCityFoodPlaces(
    double cityLat,
    double cityLng, {
    double? userLat,
    double? userLng,
    int radiusM = 20000,
  }) async {
    final query = '''
[out:json][timeout:30];
(
  node["amenity"~"^($_foodAmenityTags)\$"](around:$radiusM,$cityLat,$cityLng);
  way["amenity"~"^($_foodAmenityTags)\$"](around:$radiusM,$cityLat,$cityLng);
);
out center tags;
''';
    final result = await _fetch(query);
    return _parsePlaces(result, userLat, userLng);
  }

  List<PlaceEntity> _parsePlaces(
    List<Map<String, dynamic>> elements,
    double? refLat,
    double? refLng,
  ) {
    final places = <PlaceEntity>[];
    for (final element in elements) {
      final tags = element['tags'] as Map<String, dynamic>?;
      final name = tags?['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final lat = element['lat'] as double? ??
          (element['center'] as Map<String, dynamic>?)?['lat'] as double?;
      final lng = element['lon'] as double? ??
          (element['center'] as Map<String, dynamic>?)?['lon'] as double?;
      if (lat == null || lng == null) continue;

      if (tags == null) continue;
      final amenity = _resolveAmenity(tags);
      if (amenity.isEmpty) continue;

      final id = '${element['type']}_${element['id']}';

      double? distance;
      if (refLat != null && refLng != null) {
        distance = PlaceEntity.distanceBetween(refLat, refLng, lat, lng);
      }

      places.add(PlaceEntity(
        id: id,
        name: name,
        amenity: amenity,
        latitude: lat,
        longitude: lng,
        distanceFromUser: distance,
      ));
    }
    return places;
  }

  String _resolveAmenity(Map<String, dynamic> tags) {
    for (final key in ['amenity', 'leisure', 'tourism', 'shop', 'sport', 'natural']) {
      final val = tags[key];
      if (val is String && val.isNotEmpty) return val;
    }
    return '';
  }

  Future<List<Map<String, dynamic>>> _fetch(String query) async {
    final response = await http
        .get(Uri.parse('$_endpoint?data=${Uri.encodeQueryComponent(query)}'),
            headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Overpass API HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = body['elements'] as List? ?? [];
    return elements.cast<Map<String, dynamic>>();
  }

  static String _roundKey(double lat, double lng) {
    return '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime _createdAt;
  final Duration _ttl;

  _CacheEntry(this.value, this._ttl) : _createdAt = DateTime.now();

  bool isExpired() =>
      DateTime.now().difference(_createdAt) > _ttl;
}
