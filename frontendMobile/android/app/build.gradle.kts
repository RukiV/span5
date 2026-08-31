plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties

// Load keystore properties from a file not committed to version control.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.fbs.akademiafbs"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.fbs.akademiafbs"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AppAuth (via flutter_appauth) se RedirectUriReceiverActivity benodig
        // die herleiding-skema van ons msauth:// redirect URI.
        manifestPlaceholders["appAuthRedirectScheme"] = "msauth"
        // Google Maps API key, gelees uit die nie-gecommitteerde keystore.properties
        // (of 'n GOOGLE_MAPS_API_KEY env-var) sodat dit nie in version control beland nie.
        manifestPlaceholders["googleMapsApiKey"] = keystoreProperties["googleMapsApiKey"] as String?
            ?: System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
                ?: System.getenv("KEY_ALIAS") ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String?
                ?: System.getenv("KEY_PASSWORD") ?: ""
            storeFile = (keystoreProperties["storeFile"] as? String)?.let { project.file(it) }
                ?: System.getenv("KEYSTORE_PATH")?.let { project.file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
                ?: System.getenv("KEYSTORE_PASSWORD") ?: ""
            isV1SigningEnabled = true
            isV2SigningEnabled = true
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("Release keystore not configured — APK will NOT be signed for production. " +
                    "Create keystore.properties or set KEY_ALIAS/KEY_PASSWORD/KEYSTORE_PATH/KEYSTORE_PASSWORD env vars.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
