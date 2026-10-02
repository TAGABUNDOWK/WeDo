import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../config/maps_key.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Route provider with a two-step chain:
/// 1. Google Directions API (paid, but covered by the 10k free
///    monthly calls + $300 trial credit) — best quality/traffic.
/// 2. FOSSGIS community OSRM (keyless, free) as automatic fallback
///    so the app keeps working if the key/billing is ever missing.
///
/// OSRM policy: max ~1 request/second — callers throttle refetches.
class RoutingService {
  static const Map<String, String> _osrmHosts = {
    'foot': 'https://routing.openstreetmap.de/routed-foot',
    'bike': 'https://routing.openstreetmap.de/routed-bike',
    'car': 'https://routing.openstreetmap.de/routed-car',
  };

  static const Map<String, String> _googleModes = {
    'foot': 'walking',
    'bike': 'bicycling',
    'car': 'driving',
  };

  /// Returns a road route between [from] and [to], or null on any
  /// failure so callers can fall back to straight-line distance.
  Future<RouteResult?> getRoute({
    required LatLng from,
    required LatLng to,
    String profile = 'foot',
  }) async {
    final google = await _googleRoute(from: from, to: to, profile: profile);
    if (google != null) return google;
    return _osrmRoute(from: from, to: to, profile: profile);
  }

  Future<RouteResult?> _googleRoute({
    required LatLng from,
    required LatLng to,
    required String profile,
  }) async {
    if (!mapsApiKeyIsConfigured) return null;

    final mode = _googleModes[profile] ?? 'walking';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${from.latitude},${from.longitude}'
        '&destination=${to.latitude},${to.longitude}'
        '&mode=$mode'
        '&key=$mapsApiKey';

    try {
      final response = await http
          .get(Uri.parse(url), headers: mapsAndroidHeaders)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;

      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;

      final overview =
          (route['overview_polyline'] as Map?)?['points'] as String?;
      if (overview == null || overview.isEmpty) return null;
      final points = _decodePolyline(overview);
      if (points.isEmpty) return null;

      var distance = 0.0;
      var duration = 0.0;
      for (final leg in (route['legs'] as List?) ?? const []) {
        final legMap = leg as Map;
        distance +=
            ((legMap['distance'] as Map?)?['value'] as num?)?.toDouble() ?? 0;
        duration +=
            ((legMap['duration'] as Map?)?['value'] as num?)?.toDouble() ?? 0;
      }

      return RouteResult(
        points: points,
        distanceMeters: distance,
        durationSeconds: duration,
      );
    } catch (_) {
      return null;
    }
  }

  Future<RouteResult?> _osrmRoute({
    required LatLng from,
    required LatLng to,
    required String profile,
  }) async {
    final host = _osrmHosts[profile] ?? _osrmHosts['foot']!;
    final url =
        '$host/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&alternatives=false';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List?;
      if (coords == null || coords.isEmpty) return null;

      final points = <LatLng>[];
      for (final c in coords) {
        final pair = c as List;
        // GeoJSON is [longitude, latitude].
        points.add(
          LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          ),
        );
      }

      return RouteResult(
        points: points,
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Standard Google encoded-polyline decoder.
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var b = 0;
      var shift = 0;
      var result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
