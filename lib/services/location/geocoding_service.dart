import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/maps_key.dart';

class GeocodedPlace {
  final double latitude;
  final double longitude;
  final String? address;

  const GeocodedPlace({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

/// Reverse/forward geocoding with a two-step chain:
/// 1. Google Geocoding API (10k free monthly calls) — best quality.
/// 2. Nominatim (keyless, free) as automatic fallback.
///
/// Nominatim policy: max 1 request/second + valid User-Agent —
/// results are cached in-memory here.
class GeocodingService {
  static const _userAgent = 'WeDoApp/1.0 (school project)';

  final Map<String, String?> _cache = {};

  String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  /// Short human-readable address for a coordinate, or null.
  Future<String?> reverse(double lat, double lng) async {
    final key = _key(lat, lng);
    if (_cache.containsKey(key)) return _cache[key];

    String? result = await _googleReverse(lat, lng);
    result ??= await _nominatimReverse(lat, lng);

    _cache[key] = result;
    return result;
  }

  /// Resolves a Places Autocomplete place_id to coordinates + address
  /// via the Geocoding API (avoids a separate Place Details call).
  Future<GeocodedPlace?> resolvePlaceId(String placeId) async {
    if (!mapsApiKeyIsConfigured) return null;

    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?place_id=$placeId'
          '&key=$mapsApiKey';
      final response = await http
          .get(Uri.parse(url), headers: mapsAndroidHeaders)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;
      final results = json['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final location = (first['geometry'] as Map?)?['location'] as Map?;
      if (location == null) return null;

      return GeocodedPlace(
        latitude: (location['lat'] as num).toDouble(),
        longitude: (location['lng'] as num).toDouble(),
        address: _shorten(first['formatted_address'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _googleReverse(double lat, double lng) async {
    if (!mapsApiKeyIsConfigured) return null;

    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=$lat,$lng'
          '&key=$mapsApiKey';
      final response = await http
          .get(Uri.parse(url), headers: mapsAndroidHeaders)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;
      final results = json['results'] as List?;
      if (results == null || results.isEmpty) return null;

      return _shorten(
        (results.first as Map<String, dynamic>)['formatted_address']
            as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _nominatimReverse(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse',
      ).replace(
        queryParameters: {
          'format': 'jsonv2',
          'lat': lat.toString(),
          'lon': lng.toString(),
          'zoom': '18',
        },
      );

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = json['display_name'] as String?;
      if (displayName == null || displayName.isEmpty) return null;

      return _shorten(displayName);
    } catch (_) {
      return null;
    }
  }

  /// Keeps only the first few segments so chips/cards stay compact
  /// ("123 Sampaguita St, Tondo, Manila, Metro Manila").
  static String? _shorten(String? address) {
    if (address == null || address.isEmpty) return null;
    return address.split(', ').take(4).join(', ');
  }
}
