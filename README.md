# WeDo

WeDo is a social communication and decision-making app that helps friends, groups, and communities chat, call, vote, play games, and decide what to do together — without the back-and-forth arguments.

## Features

- Messaging / group chats
- Voice & video calls
- Polls
- Sessions
- Games
- Friends
- Leaderboard
- Nearby places
- Movies & events

## Tech Stack

- Flutter
- Dart
- Firebase
  - Authentication
  - Firestore
  - Storage
  - Cloud Messaging
- Vercel (serverless API proxy)
- WebRTC
- Maps

## Requirements

- Flutter SDK
- Dart SDK ^3.12.2
- Android Studio / Xcode
- Firebase project
- Vercel account (for the `api/` backend)

## Getting Started

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure Firebase

Run FlutterFire CLI to connect your Firebase project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart`, plus `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.

### 3. Deploy the Vercel backend (API proxy)

The Flutter app does **not** hold third-party secrets. It calls a Vercel serverless backend (`https://wedo-api.vercel.app`) that keeps the real keys and talks to TMDB, Brevo, and Firebase Admin on the app's behalf.

The functions live in `api/` (see `vercel.json` for routes):

| Route | Function | Purpose |
| --- | --- | --- |
| `/tmdb` | `api/tmdb.js` | Proxy TMDB movie API |
| `/generate-otp` | `api/generate-otp.js` | Store OTP + send email via Brevo |
| `/verify-otp` | `api/verify-otp.js` | Validate OTP |
| `/verify-email-change` | `api/verify-email-change.js` | Validate email-change OTP |
| — | `api/update-email.js` | Update Firebase Auth email |

Deploy:

```bash
vercel deploy --prod
```

Then set these environment variables in the Vercel project settings (they stay on Vercel — never in the app):

```
TMDB_API=
BREVO_API_KEY=
BREVO_SENDER_NAME=
BREVO_SENDER_EMAIL=
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=
OTP_EXPIRY_MINUTES=5        # optional, defaults to 5
```

If you deploy under a different domain, update the base URLs in `lib/utils/constants.dart` (`tmdbProxyUrl`) and `lib/services/auth/otp_service.dart` (`_baseUrl`).

### 4. Create the `.env` file

The app loads client-side config via `flutter_dotenv` in `main.dart`. Create a `.env` file in the project root:

```
TURN_USERNAME=your_turn_username
TURN_CREDENTIAL=your_turn_credential
```

These are WebRTC/TURN credentials for voice & video calls (`lib/services/call/webrtc_service.dart`).

> **Warning:** `.env` values are bundled into the app binary and can be extracted from an APK — treat them as **public**. Use restricted/short-lived TURN credentials. Secrets (TMDB, Brevo, Firebase Admin) do **not** go here; they belong in Vercel env vars (step 3).

### 5. Run the app

```bash
flutter run
```

## Project Structure

```
lib/
├── models/       # Data models and entities
├── screens/      # UI pages and screen widgets
├── services/     # Business logic and authentication
├── utils/        # Helper functions, API calls, and utilities
└── widgets/      # Reusable UI components
```

## Building a Release

Build an APK:

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Other variants:

```bash
# Smaller per-CPU APKs
flutter build apk --release --split-per-abi

# App Bundle for Play Store
flutter build appbundle --release
```

> **Note:** Release builds are currently signed with debug keys (`android/app/build.gradle.kts`). Add a release keystore before publishing to the Play Store.
