plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bittu.sreyhan_diary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bittu.sreyhan_diary"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 8+.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One fixed key for every build, committed here (debug-grade, password
    // "android"). Android only installs an update over the app when the key
    // matches; with CI's throwaway keys each update would need an uninstall,
    // and uninstalling deletes the diary.
    // SHA-256 A6:12:28:86:A4:ED:FB:B6:E7:41:DD:33:BE:81:D1:19:7F:49:13:64:64:22:18:B3:39:0D:9F:7F:65:E3:B2:F4
    signingConfigs {
        getByName("debug") {
            storeFile = file("sreyhan-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Release builds ship the Flutter engine for arm64 only (see the
            // CI workflow), so drop the other ABIs' copies of plugin libraries
            // too: they can never load, and cost megabytes of download.
            ndk { abiFilters.add("arm64-v8a") }
        }
    }

    packaging {
        // The APK is downloaded and sideloaded, so download size beats the
        // small cost of Android extracting compressed libraries at install.
        jniLibs { useLegacyPackaging = true }
        // Protobuf source files bundled by Google libraries; never read at runtime.
        resources { excludes += "google/**/*.proto" }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    // Photo labels from Google Play services' model, not a bundled one.
    implementation("com.google.android.gms:play-services-mlkit-image-labeling:16.0.8")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
