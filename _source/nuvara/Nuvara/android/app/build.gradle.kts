import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (never committed; see README "Release builds"):
//   storeFile=/path/to/nuvara-upload.jks  storePassword=…  keyAlias=upload  keyPassword=…
val keystoreProperties = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
val hasReleaseKey = keystoreProperties["storeFile"] != null

android {
    namespace = "com.nuvara.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nuvara.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties (a developer machine) release builds fall back to the debug key so
            // `flutter run --release` still works. Such a build must never be shipped: the build prints a warning.
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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

if (!hasReleaseKey) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.name.contains("Release") }) {
            logger.warn("WARNING: android/key.properties not found. This release build is signed with the DEBUG key and must not be distributed.")
        }
    }
}
