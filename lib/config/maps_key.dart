import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Maps API key used by Dart-side HTTP calls
/// (Directions, Geocoding, Places Autocomplete).
///
/// The key is NOT stored in source code. It is read at startup from the
/// gitignored `.env` file (`MAPS_API_KEY=AIza...`), which [dotenv] loads
/// before runApp (see `_appMain` in main.dart).
///
/// The native map SDK reads the same `MAPS_API_KEY` from this project-root
/// `.env` file — Gradle injects it into the AndroidManifest at build time
/// (see `android/app/build.gradle.kts`).
///
/// Optional override for CI/iOS builds:
/// `flutter run --dart-define=MAPS_API_KEY=AIza...`
///
/// If no key is configured the app still works: routing and reverse
/// geocoding fall back to free OpenStreetMap services, and place search
/// reports that it needs a key.
String get mapsApiKey {
  try {
    final value = dotenv.env['MAPS_API_KEY']?.trim();
    if (value != null && value.isNotEmpty && value != 'PASTE_YOUR_KEY_HERE') {
      return value;
    }
  } catch (_) {
    // dotenv not loaded yet (should not happen after runApp).
  }
  return const String.fromEnvironment('MAPS_API_KEY');
}

bool get mapsApiKeyIsConfigured =>
    mapsApiKey.isNotEmpty && mapsApiKey != 'PASTE_YOUR_KEY_HERE';

/// Android-restricted keys validate REST calls via these headers
/// (package name + debug/release certificate SHA-1, colons stripped).
const String mapsAndroidPackage = 'com.example.choosly';
const String mapsAndroidCert = '8CC772132B8AFD5C2A3F74E2C74B4D1F122A756B';

/// Headers every Google REST request must carry when the key carries an
/// Android application restriction.
const Map<String, String> mapsAndroidHeaders = {
  'X-Android-Package': mapsAndroidPackage,
  'X-Android-Cert': mapsAndroidCert,
};
