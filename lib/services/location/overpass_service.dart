import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/place_category.dart';
import '../../models/place_entity.dart';

/// Free OpenStreetMap Overpass fallback for PickFight place topics.
/// Google Places (New) is the primary source (see
/// `PlacesSearchService`); this fetcher keeps the feature alive when the
/// API key, quota, or billing is unavailable.
class OverpassService {
  static const String _endpoint = 'https://overpass-api.de/api/interpreter';
  static const String _userAgent = 'WeDoApp/1.0 (contact: dev@wedo.app)';

  Future<List<PlaceEntity>> getPlacesByCategory(
    double lat,
    double lng, {
    required PlaceCategory category,
    int radiusM = 5000,
  }) async {
    final query = _buildCategoryQuery(category, radiusM, lat, lng);
    final result = await _fetch(query);
    return _parsePlaces(result, lat, lng);
  }

  Future<List<PlaceEntity>> getCityPlacesByCategory(
    double cityLat,
    double cityLng, {
    required PlaceCategory category,
    double? userLat,
    double? userLng,
    int radiusM = 20000,
  }) async {
    final query = _buildCategoryQuery(category, radiusM, cityLat, cityLng);
    final result = await _fetch(query);
    return _parsePlaces(result, userLat, userLng);
  }

  String _buildCategoryQuery(
    PlaceCategory category,
    int radiusM,
    double lat,
    double lng,
  ) {
    final buffers = <String>[];

    for (final tag in category.osmTags) {
      final filter = '["${tag.key}"~"^(${tag.values})\$"]'
          '(around:$radiusM,$lat,$lng)';
      buffers.add('node$filter;');
      buffers.add('way$filter;');
    }

    return '[out:json][timeout:30];\n(\n${buffers.join('\n')}\n);\n'
        'out center tags;\n';
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
}
