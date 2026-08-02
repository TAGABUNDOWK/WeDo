import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/place_entity.dart';

class OverpassService {
  static const String _endpoint = 'https://overpass-api.de/api/interpreter';
  static const String _userAgent = 'WeDoApp/1.0 (contact: dev@wedo.app)';

  static const String _amenityTags =
      'cafe|restaurant|bar|pub|ice_cream|cinema|theatre|fast_food|food_court|bakery|nightclub|karaoke|juice_bar';
  static const String _leisureTags =
      'park|garden|bowling_alley|amusement_arcade|fitness_centre|sports_centre|swimming_pool|skatepark|nature_reserve';
  static const String _tourismTags = 'art_gallery|museum|viewpoint|camp_site';
  static const String _shopTags = 'books|marketplace|clothes|electronics|mall';

  static final Map<String, _CacheEntry<String?>> _labelCache = {};
  static final Map<String, _CacheEntry<List<String>>> _poiCache = {};
  static final Map<String, _CacheEntry<List<String>>> _provinceCache = {};
  static final Map<String, _CacheEntry<List<String>>> _cityCache = {};

  Future<String?> labelArea(double lat, double lng) async {
    final key = _roundKey(lat, lng);
    final cached = _labelCache[key];
    if (cached != null && !cached.isExpired()) {
      return cached.value;
    }

    final query =
        '[out:json][timeout:15];node["place"](around:20000,$lat,$lng);out tags 5;';
    final result = await _fetch(query);
    if (result == null) return null;

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
    final result = await _fetch(query);
    if (result == null) return const [];

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

  Future<List<String>> getProvinces() async {
    const cacheKey = 'ph_provinces';
    final cached = _provinceCache[cacheKey];
    if (cached != null && !cached.isExpired()) {
      return cached.value;
    }

    const minLat = 4.6;
    const minLng = 116.9;
    const maxLat = 21.1;
    const maxLng = 126.6;
    final query = '''
[out:json][timeout:30];
relation["boundary"="administrative"]["admin_level"="4"]($minLat,$minLng,$maxLat,$maxLng);
out tags;
''';
    final result = await _fetch(query);
    if (result == null) return const [];

    final names = <String>{};
    for (final element in result) {
      final tags = element['tags'] as Map<String, dynamic>?;
      final name = tags?['name'];
      if (name is String && name.isNotEmpty) {
        names.add(name);
      }
    }

    final list = names.toList()..sort();
    _provinceCache[cacheKey] = _CacheEntry(list, const Duration(hours: 24));
    return list;
  }

  Future<List<String>> getCities(String provinceName) async {
    final cacheKey = 'cities_$provinceName';
    final cached = _cityCache[cacheKey];
    if (cached != null && !cached.isExpired()) {
      return cached.value;
    }

    final center = await _getRelationCenter(
      'administrative',
      '4',
      provinceName,
    );
    if (center == null) return const [];

    const radiusM = 50000;
    final query = '''
[out:json][timeout:30];
relation["boundary"="administrative"]["admin_level"="6"](around:$radiusM,${center['lat']},${center['lng']});
out tags;
''';
    final result = await _fetch(query);
    if (result == null) return const [];

    final names = <String>{};
    for (final element in result) {
      final tags = element['tags'] as Map<String, dynamic>?;
      final name = tags?['name'];
      if (name is String && name.isNotEmpty) {
        names.add(name);
      }
    }

    final list = names.toList()..sort();
    _cityCache[cacheKey] = _CacheEntry(list, const Duration(hours: 24));
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
    if (result == null) return const [];

    return _parsePlaces(result, lat, lng);
  }

  Future<List<PlaceEntity>> getCityPlaces(
    String provinceName,
    String cityName, {
    double? userLat,
    double? userLng,
  }) async {
    final center = await _getRelationCenter(
      'administrative',
      '6',
      cityName,
    );
    if (center == null) return const [];

    final lat = center['lat']!;
    final lng = center['lng']!;
    const radiusM = 20000;

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
    if (result == null) return const [];

    return _parsePlaces(result, userLat, userLng);
  }

  Future<Map<String, double>?> _getRelationCenter(
    String boundary,
    String adminLevel,
    String name,
  ) async {
    final query = '''
[out:json][timeout:15];
relation["boundary"="$boundary"]["admin_level"="$adminLevel"]["name"="$name"];
out center;
''';
    final result = await _fetch(query);
    if (result == null || result.isEmpty) return null;

    final element = result.first;
    final center = element['center'] as Map<String, dynamic>?;
    if (center == null) return null;

    final lat = center['lat'] as num?;
    final lon = center['lon'] as num?;
    if (lat == null || lon == null) return null;

    return {
      'lat': lat.toDouble(),
      'lng': lon.toDouble(),
    };
  }

  List<PlaceEntity> _parsePlaces(
    List<Map<String, dynamic>> elements,
    double? refLat,
    double? refLng,
  ) {
    final places = <PlaceEntity>[];
    for (final element in elements) {
      final tags = element['tags'] as Map<String, dynamic>?;
      final name = tags?['name'];
      if (name == null || (name as String).isEmpty) continue;

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
        name: name as String,
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

  Future<List<Map<String, dynamic>>?> _fetch(String query) async {
    try {
      final response = await http
          .get(Uri.parse('$_endpoint?data=${Uri.encodeQueryComponent(query)}'),
              headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = body['elements'] as List? ?? [];
      return elements.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
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
