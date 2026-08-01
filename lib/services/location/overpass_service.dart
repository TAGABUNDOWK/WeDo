import 'dart:convert';
import 'package:http/http.dart' as http;

class OverpassService {
  static const String _endpoint = 'https://overpass-api.de/api/interpreter';
  static const String _userAgent = 'WeDoApp/1.0 (contact: dev@wedo.app)';

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
