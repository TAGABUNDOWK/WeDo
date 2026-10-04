import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/maps_key.dart';
import '../../models/place_category.dart';
import '../../models/place_entity.dart';
import 'street_view_service.dart';

/// Google Places API (New) — Nearby Search + Place Photo URLs.
///
/// Requires `MAPS_API_KEY` in `.env` (or `--dart-define`) with the
/// **Places API (New)** enabled and billing attached in Google Cloud.
/// Every failure path returns an empty list so the caller can fall back
/// to the free Overpass (OpenStreetMap) fetcher.
class GooglePlacesService {
  static const String _endpoint =
      'https://places.googleapis.com/v1/places:searchNearby';

  /// Only the fields we render — FieldMask decides the billed SKU, so keep
  /// it to rating + summary + photo (Enterprise + Atmosphere tier).
  static const String _fieldMask =
      'places.id,places.displayName,places.location,places.rating,'
      'places.userRatingCount,places.editorialSummary,places.photos,'
      'places.primaryTypeDisplayName,places.shortFormattedAddress,'
      'places.priceLevel';

  /// Resolves a photo resource name (`places/{id}/photos/{photo}`) to a
  /// signed, key-free CDN URL via the `/media` endpoint's redirect.
  ///
  /// The `/media` call itself requires the Android app-restriction headers
  /// (X-Goog-Api-Key + package/cert), but the redirect `Location` it
  /// returns is a plain `lh3.googleusercontent.com` URL that loads with
  /// `Image.network` — and is safe to store in Firestore card maps.
  /// Resolved URLs are cached in-memory for the app's lifetime so each
  /// photo is billed at most once per run.
  static final Map<String, String> _coverUrlCache = {};

  static Future<String?> _resolvePhotoUrl(String photoName) async {
    if (photoName.isEmpty || !mapsApiKeyIsConfigured) {
      return null;
    }
    final cached = _coverUrlCache[photoName];
    if (cached != null) return cached;

    try {
      final request = http.Request(
        'GET',
        Uri.parse('https://places.googleapis.com/v1/$photoName/media'
            '?maxWidthPx=640&key=$mapsApiKey'),
      )
        ..followRedirects = false
        ..headers.addAll(mapsAndroidHeaders);

      final client = http.Client();
      try {
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 10));
        final location = response.headers['location'];
        if (location != null &&
            location.isNotEmpty &&
            response.statusCode >= 300 &&
            response.statusCode < 400) {
          _coverUrlCache[photoName] = location;
          return location;
        }
        return null;
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Resolves cover URLs for [places] in parallel.
  ///
  /// Source order per place:
  /// 1. **Street View** — a real photo of the building itself, fetched once
  ///    ever and cached in Firebase Storage (see [StreetViewService]).
  /// 2. **Ranked Places photo candidates** — tried best-first; only billed
  ///    when Street View has no coverage for the location.
  /// 3. `null` — the caller shows its numbered placeholder.
  ///
  /// Each entity keeps its existing cover when every source fails.
  static Future<void> resolveCoverUrls(List<PlaceEntity> places) async {
    await Future.wait(places.map((p) async {
      if (p.coverUrl != null) return;
      final url = await StreetViewService.resolveCoverUrl(p) ??
          await _resolveBestPhoto(p.photoCandidates);
      if (url != null) p.coverUrl = url;
    }));
  }

  static Future<String?> _resolveBestPhoto(List<String> candidates) async {
    for (final name in candidates) {
      final url = await _resolvePhotoUrl(name);
      if (url != null) return url;
    }
    return null;
  }

  /// Nearby Search (New): up to 20 places matching [category]'s Google
  /// types inside a [radiusM] circle around (lat, lng).
  Future<List<PlaceEntity>> getNearby(
    double lat,
    double lng, {
    required PlaceCategory category,
    int radiusM = 5000,
  }) async {
    if (!mapsApiKeyIsConfigured || category.googleTypes.isEmpty) {
      return const [];
    }

    final body = {
      'includedTypes': category.googleTypes,
      'maxResultCount': 20,
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radiusM,
        },
      },
    };

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': mapsApiKey,
              'X-Goog-FieldMask': _fieldMask,
              ...mapsAndroidHeaders,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final places = json['places'] as List? ?? [];
      return places
          .map(_parse)
          .whereType<PlaceEntity>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  PlaceEntity? _parse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    final name = (raw['displayName'] as Map?)?['text'] as String?;
    if (name == null || name.isEmpty) return null;

    final location = raw['location'] as Map?;
    final lat = location?['latitude'] as num?;
    final lng = location?['longitude'] as num?;
    if (lat == null || lng == null) return null;

    return PlaceEntity(
      id: raw['id'] as String? ?? '',
      name: name,
      amenity:
          (raw['primaryTypeDisplayName'] as Map?)?['text'] as String? ?? '',
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      rating: (raw['rating'] as num?)?.toDouble(),
      ratingCount: (raw['userRatingCount'] as num?)?.toInt(),
      summary: (raw['editorialSummary'] as Map?)?['text'] as String?,
      photoCandidates: _rankPhotos(raw['photos'] as List?),
      priceLevel: raw['priceLevel'] as String?,
      address: raw['shortFormattedAddress'] as String?,
    );
  }

  /// Picks the best cover candidates from a place's photos using the
  /// `widthPx`/`heightPx` metadata already returned by Nearby Search
  /// (no extra API call).
  ///
  /// Junk-tier photos are dropped: tiny images (< 400px wide — logos,
  /// screenshots) and extreme aspect ratios (outside 0.6–1.8 — panoramas,
  /// slivers). Survivors rank by resolution, preferring landscape/square.
  /// When nothing passes, the largest raw photo is kept as a last resort
  /// so a place never loses its image entirely. Up to three names are kept
  /// so the resolver can fall through on a failed photo.
  static List<String> _rankPhotos(List? photos) {
    if (photos == null || photos.isEmpty) return const [];

    final pass = <_ScoredPhoto>[];
    final fail = <_ScoredPhoto>[];
    for (final raw in photos) {
      if (raw is! Map) continue;
      final name = raw['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final w = (raw['widthPx'] as num?)?.toInt() ?? 0;
      final h = (raw['heightPx'] as num?)?.toInt() ?? 0;
      final hasDims = w > 0 && h > 0;

      if (!hasDims) {
        fail.add(_ScoredPhoto(name, 0, 0, 0));
        continue;
      }

      final aspect = w / h;
      final landscapeBonus = (aspect >= 0.9 && aspect <= 1.6) ? 1.2 : 1.0;
      final score = w * landscapeBonus;
      final photo = _ScoredPhoto(name, w, aspect, score);
      if (w >= 400 && aspect >= 0.6 && aspect <= 1.8) {
        pass.add(photo);
      } else {
        fail.add(photo);
      }
    }

    pass.sort((a, b) => b.score.compareTo(a.score));
    fail.sort((a, b) => b.width.compareTo(a.width));

    final ranked = pass.isNotEmpty
        ? [...pass, ...fail.take(1)]
        : fail.take(1).toList();
    return ranked
        .take(3)
        .map((p) => p.name)
        .toList(growable: false);
  }
}

class _ScoredPhoto {
  final String name;
  final int width;
  final double aspect;
  final double score;

  const _ScoredPhoto(this.name, this.width, this.aspect, this.score);
}
