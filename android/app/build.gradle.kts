import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Loaded from android/key.properties (gitignored — see android/keystore/README.md).
// Falls back to the debug key when absent, so `flutter run` still works for
// anyone who hasn't generated a release keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.majbourreisen.clinic_manager_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.majbourreisen.clinic_manager_flutter.demo"
        // Android 8.0+ — Storage Access Framework (external-drive access via
        // file_picker) is solid from here on; older devices aren't a
        // realistic target for this app regardless. See the Android tablet
        // recommendations given to the clinic separately (Android 10+ in
        // practice, for OTG/driver reliability).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // rootProject, not the bare file() this module's own dir
                // would resolve against — storeFile in key.properties is
                // "keystore/…", relative to android/ (where key.properties
                // itself lives), same as keystorePropertiesFile below.
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // No keystore generated yet — falls back to the debug key so
                // `flutter run --release` still works, but this build must
                // never be the one handed to the client (see android/keystore/README.md).
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
