import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials. Read from android/key.properties, which is
// gitignored together with the .jks: this app keeps its data in a local SQLite
// file, so a lost or changed signing key means installed copies can no longer
// be updated — Android forces an uninstall, and the uninstall deletes the data.
//
// Falls back to the debug key so a fresh clone still builds, but the resulting
// APK must never be handed out for distribution.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.example.fes_distribution"
    compileSdk = flutter.compileSdkVersion

    // ndkVersion is deliberately not set. Pinning it makes AGP auto-provision the
    // ~2 GB NDK even though nothing here compiles from C/C++ source: the Flutter
    // engine and plugins (sqlite3_flutter_libs, mobile_scanner) ship prebuilt .so
    // files inside their AARs. A debug build does not strip debug symbols, so the
    // NDK is not needed. Drop this line back in if a future plugin adds native code.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.fes_distribution"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "android/key.properties is missing. Create a release keystore " +
                        "(keytool -genkeypair -keystore android/app/<name>.jks -storetype PKCS12 " +
                        "-alias fes-distribution -keyalg RSA -keysize 2048 -validity 10950) and add " +
                        "storeFile / storePassword / keyAlias / keyPassword to that file. " +
                        "Signing a release with the debug key breaks updates on every installed phone."
                )
            }
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
