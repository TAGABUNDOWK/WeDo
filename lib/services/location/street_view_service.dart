import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../../config/maps_key.dart';
import '../../models/place_entity.dart';

/// Street View Static cover images for places.
///
/// The goal: a deterministic, real-world photo of the place itself instead
/// of a random user-contributed Places photo (selfies, menus, etc.).
///
/// Street View Static is billed **per panorama request**, so every image is
/// fetched from Google exactly once and then persisted in Firebase Storage
/// under `place_covers/{placeId}.jpg` — all later views load from Firebase
/// at no cost. The coverage probe (Street View Metadata) is free.
///
/// Failure paths return null so callers can fall back to the ranked
/// Google Places photo candidates, then to the numbered placeholder.
class StreetViewService {
  static const String _metadataEndpoint =
      'https://maps.googleapis.com/maps/api/streetview/metadata';
  static const String _imageEndpoint =
      'https://maps.googleapis.com/maps/api/streetview';

  /// Reject panoramas farther than this from the place pin — a pano down
  /// the block shows the wrong building.
  static const double _maxPanoDistanceM = 80;

  static const Duration _timeout = Duration(seconds: 10);

  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Resolved URLs for the app's lifetime (Storage URLs are stable).
  static final Map<String, String> _urlCache = {};

  /// Locations that already failed the coverage probe this run — avoids
  /// repeating the (free) metadata call for every retry.
  static final Set<String> _noCoverageKeys = {};

  /// Returns a stable Firebase Storage URL for [place]'s cached Street View
  /// image, downloading it from Google (once, ever) on the first request.
  static Future<String?> resolveCoverUrl(PlaceEntity place) async {
    if (!mapsApiKeyIsConfigured) return null;

    final key = _objectKey(place);
    final cached = _urlCache[key];
    if (cached != null) return cached;
    if (_noCoverageKeys.contains(key)) return null;

    final ref = _storage.ref('place_covers/$key.jpg');

    try {
      final existing = await ref.getDownloadURL();
      _urlCache[key] = existing;
      return existing;
    } catch (_) {
      // Not cached yet — fall through and fetch from Google.
    }

    final pano = await _findPano(place.latitude, place.longitude);
    if (pano == null) {
      _noCoverageKeys.add(key);
      return null;
    }

    // Face the camera from the pano toward the place so the actual
    // building is in frame instead of whatever lies down the street.
    final heading = _bearingDeg(pano.lat, pano.lng,
        place.latitude, place.longitude);
    final bytes = await _fetchPanorama(pano.lat, pano.lng, heading);
    if (bytes == null || bytes.isEmpty) return null;

    try {
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=2592000',
          customMetadata: {'source': 'street_view_static'},
        ),
      );
      final url = await ref.getDownloadURL();
      _urlCache[key] = url;
      return url;
    } catch (_) {
      // Storage write failed (rules/network) — serve nothing rather than
      // a URL we cannot keep; next run retries.
      return null;
    }
  }

  /// Free, unlimited coverage probe. Returns the nearest panorama when it
  /// sits within [_maxPanoDistanceM] of the place, else null.
  static Future<_Pano?> _findPano(double lat, double lng) async {
    try {
      final uri = Uri.parse(_metadataEndpoint).replace(queryParameters: {
        'location': '$lat,$lng',
        'radius': '${_maxPanoDistanceM.round()}',
        'source': 'outdoor',
        'key': mapsApiKey,
      });
      final response = await http
          .get(uri, headers: mapsAndroidHeaders)
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'OK') return null;

      final panoLat = (json['location'] as Map?)?['lat'] as num?;
      final panoLng = (json['location'] as Map?)?['lng'] as num?;
      if (panoLat == null || panoLng == null) return null;

      final distance = _haversineM(lat, lng, panoLat.toDouble(), panoLng.toDouble());
      if (distance > _maxPanoDistanceM) return null;

      return _Pano(panoLat.toDouble(), panoLng.toDouble());
    } catch (_) {
      return null;
    }
  }

  /// One billable panorama request.
  static Future<Uint8List?> _fetchPanorama(
    double lat,
    double lng,
    double? heading,
  ) async {
    try {
      final query = <String, String>{
        'size': '640x640',
        'location': '$lat,$lng',
        'radius': '${_maxPanoDistanceM.round()}',
        'source': 'outdoor',
        'key': mapsApiKey,
      };
      if (heading != null) query['heading'] = heading.toStringAsFixed(1);

      final response = await http
          .get(Uri.parse(_imageEndpoint).replace(queryParameters: query),
              headers: mapsAndroidHeaders)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length < 1024) return null; // error placeholder
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  static String _objectKey(PlaceEntity place) {
    if (place.id.isNotEmpty) return place.id;
    return '${place.latitude.toStringAsFixed(4)}_'
        '${place.longitude.toStringAsFixed(4)}';
  }

  static double _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;

  /// Initial bearing in degrees from (lat1,lng1) to (lat2,lng2).
  static double _bearingDeg(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _rad(lng2 - lng1);
    final y = sin(dLng) * cos(_rad(lat2));
    final x = cos(_rad(lat1)) * sin(_rad(lat2)) -
        sin(_rad(lat1)) * cos(_rad(lat2)) * cos(dLng);
    final deg = atan2(y, x) * 180 / pi;
    return (deg + 360) % 360;
  }
}

class _Pano {
  final double lat;
  final double lng;

  const _Pano(this.lat, this.lng);
}
