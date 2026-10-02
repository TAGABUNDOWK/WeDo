import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Maps API key used by Dart-side HTTP calls
/// (Directions, Geocoding, Places Autocomplete).
///
/// The key is NOT stored in source code. It is read at startup from the
/// gitignored `.env` file (`MAPS_API_KEY=AIza...`), which [dotenv] loads
/// before runApp (see `_appMain` in main.dart).
///
/// The native map SDK reads a separate copy from
/// `android/local.properties` (`MAPS_API_KEY=...`, also gitignored) —
/// keep both in sync.
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
const String mapsAndroidCert = 'A050F7C820309C0D08B0C7EF90BF5417F96ECD20';

/// Headers every Google REST request must carry when the key carries an
/// Android application restriction.
const Map<String, String> mapsAndroidHeaders = {
  'X-Android-Package': mapsAndroidPackage,
  'X-Android-Cert': mapsAndroidCert,
};
