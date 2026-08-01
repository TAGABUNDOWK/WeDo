import 'dart:math' as math;

class Geohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode(double lat, double lng, [int precision = 6]) {
    final latInterval = [-90.0, 90.0];
    final lngInterval = [-180.0, 180.0];
    final result = StringBuffer();
    var hash = 0;
    var bits = 0;
    var even = true;

    while (result.length < precision) {
      if (even) {
        final mid = (lngInterval[0] + lngInterval[1]) / 2;
        if (lng >= mid) {
          hash = (hash << 1) | 1;
          lngInterval[0] = mid;
        } else {
          hash <<= 1;
          lngInterval[1] = mid;
        }
      } else {
        final mid = (latInterval[0] + latInterval[1]) / 2;
        if (lat >= mid) {
          hash = (hash << 1) | 1;
          latInterval[0] = mid;
        } else {
          hash <<= 1;
          latInterval[1] = mid;
        }
      }
      even = !even;
      bits++;
      if (bits == 5) {
        result.write(_base32[hash]);
        bits = 0;
        hash = 0;
      }
    }
    return result.toString();
  }

  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final a = sinLat * sinLat +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * sinLng * sinLng;
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  static List<String> coveringPrefixes(
    double lat,
    double lng,
    double radiusKm, {
    int prefixPrecision = 4,
  }) {
    const latKmPerDeg = 110.574;
    final lngKmPerDeg = 110.574 * math.cos(_toRad(lat));
    final dLat = radiusKm / latKmPerDeg;
    final dLng = radiusKm / lngKmPerDeg;
    final minLat = lat - dLat;
    final maxLat = lat + dLat;
    final minLng = lng - dLng;
    final maxLng = lng + dLng;

    final bits = prefixPrecision * 5;
    final latBits = (bits / 2).ceil();
    final lngBits = (bits / 2).floor();
    final cellLatDeg = 180.0 / (1 << latBits);
    final cellLngDeg = 360.0 / (1 << lngBits);

    final prefixes = <String>{};
    final stepLat = cellLatDeg * 0.5;
    final stepLng = cellLngDeg * 0.5;
    for (double la = minLat; la <= maxLat; la += stepLat) {
      for (double lo = minLng; lo <= maxLng; lo += stepLng) {
        prefixes.add(encode(la, lo, prefixPrecision));
      }
    }
    return prefixes.toList();
  }
}
