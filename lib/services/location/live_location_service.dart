import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Foreground live-location sender session.
///
/// Streams the device position and invokes [onPosition] at most once
/// every 8 seconds (Firestore-friendly) until [duration] elapses or
/// [stop] is called. Only runs while the app is open — true background
/// sharing would require a native foreground service.
class LiveLocationService {
  StreamSubscription<Position>? _positionSub;
  Timer? _expiryTimer;
  DateTime? _lastWrite;

  bool get isActive => _positionSub != null;

  void start({
    required Duration duration,
    required Future<void> Function(double latitude, double longitude)
        onPosition,
    required void Function() onExpired,
  }) {
    stop();
    _lastWrite = null;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((position) async {
      final now = DateTime.now();
      if (_lastWrite != null &&
          now.difference(_lastWrite!) < const Duration(seconds: 8)) {
        return;
      }
      _lastWrite = now;
      try {
        await onPosition(position.latitude, position.longitude);
      } catch (_) {
        // A single failed write must not kill the session.
      }
    }, onError: (_) {
      // Permission/service issues: expiry timer still runs.
    });

    _expiryTimer = Timer(duration, () {
      stop();
      onExpired();
    });
  }

  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }
}
