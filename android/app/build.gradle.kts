import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// PUSH: google-services.json is not in the repo (like Ionic). Without it the
// app builds and runs, push is just unavailable (docs/push-setup.md).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn("google-services.json not found, google-services plugin not applied. Push Notifications won't work")
}

android {
    namespace = "de.attendix.attendix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Same applicationId as the Ionic app, so the Flutter app ships as an
        // update of the Play Store app (the Kotlin namespace stays de.attendix.attendix).
        applicationId = "io.stephanus.attendix"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // STORE_SWITCH: must stay <= 24 (Android 7) like the Ionic app, so its
        // Play Store users keep getting the update. Flutter 3.50 defaults to 24
        // (FlutterExtension.minSdkVersion); pin it if a Flutter upgrade raises it.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Play upload key: android/key.properties (gitignored, never committed)
    // with storeFile, storePassword, keyAlias, keyPassword. Without it the
    // release build is signed with the debug key (local testing only).
    val keyProperties = Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
    val hasUploadKey = keyProperties.getProperty("storeFile") != null

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                logger.warn("android/key.properties not found, release build is signed with the debug key")
                signingConfigs.getByName("debug")
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

// DB_REVIEW_REST (F2): Android live plan notification (NotificationCompat) and
// LivePlanMessagingService (RemoteMessage). The plugins only declare these as
// `implementation`, so the app module needs them on its own compile classpath.
// Same Firebase BoM as firebase_core 3.15.x (FirebaseSDKVersion).
dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    implementation("com.google.firebase:firebase-messaging")
}
