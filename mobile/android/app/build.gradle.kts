import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// gitignored along with the keystore itself. When the file is absent — a fresh
// clone, or CI without the secret — release builds fall back to the debug key
// so the build still runs, and `signingConfigs` simply has no `release` entry.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.codevioso.resumestudio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The app's identity to Android and to Play. Changed from the
        // scaffold's `com.resumeforge.resume_forge` when the product was named
        // Resivo, which was only safe because nothing had shipped yet — after
        // a release this string can never change without becoming a different
        // app. The Dart package is still `resume_forge`; that is an internal
        // import path, invisible to users, and renaming it would churn every
        // file for no benefit.
        applicationId = "com.codevioso.resumestudio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // storeFile is resolved against android/, so key.properties can
                // name the keystore without an absolute machine-specific path.
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
                signingConfigs.getByName("debug")
            }
            // Minification is deliberately left off. The PDF stack (dart_pdf,
            // printing/PDFium) reaches native and platform code in ways R8 is
            // happy to strip, and a shrunk release that fails only at export
            // time is worse than a slightly larger APK. Turn it on behind a
            // real export test, not blind.
            isMinifyEnabled = false
            isShrinkResources = false
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
