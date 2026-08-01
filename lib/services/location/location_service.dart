import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  Future<bool> isPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<Position?> getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(locationSettings: _settings);
  }

  Future<Position?> getQuickPosition() async {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  LocationSettings get _settings => switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          ),
        TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
            accuracy: LocationAccuracy.medium,
            activityType: ActivityType.other,
            timeLimit: const Duration(seconds: 10),
          ),
        _ => const LocationSettings(accuracy: LocationAccuracy.medium),
      };
}
