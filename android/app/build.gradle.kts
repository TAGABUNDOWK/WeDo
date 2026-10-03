plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps API key: single source of truth = project-root .env (gitignored).
// Read at build time so the native Maps SDK key can be injected into the
// manifest without duplicating it in android/local.properties.
val mapsApiKey = rootProject.file("../.env")
    .takeIf { it.exists() }
    ?.readLines()
    ?.map { it.trim() }
    ?.firstOrNull { it.startsWith("MAPS_API_KEY=") }
    ?.substringAfter("MAPS_API_KEY=")
    ?.trim()
    ?: ""
if (mapsApiKey.isEmpty()) {
    logger.warn("MAPS_API_KEY missing from .env - native Google Maps will not load")
}

android {
    namespace = "com.example.choosly"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.choosly"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
