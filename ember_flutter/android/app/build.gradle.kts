plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.chaquo.python")
}

android {
    namespace = "com.example.ember_flutter"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ember_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.clear()
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }


    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

chaquopy {
    defaultConfig {
        val userHome = System.getProperty("user.home")
        val candidatePaths = listOf(
            File(userHome, "AppData/Roaming/uv/python/cpython-3.11-windows-x86_64-none/python.exe"),
            File(userHome, "AppData/Roaming/uv/python/cpython-3.11.14-windows-x86_64-none/python.exe"),
            File("C:/Python311/python.exe"),
        )
        val pyExe = candidatePaths.firstOrNull { it.exists() }
        if (pyExe != null) {
            buildPython(pyExe.absolutePath)
        }

        version = "3.11"
        pip {
            options("--default-timeout=120")
            install("ytmusicapi>=1.7.0")
            install("yt-dlp>=2024.0.0")
            install("requests>=2.31.0")
        }
    }
    sourceSets {
        getByName("main") {
            srcDir("../../../ember")
        }
    }
}
