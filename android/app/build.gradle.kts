import java.util.Properties
import java.io.FileInputStream
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Google Play build, and only it, links Play's in-app review library. The
// F-Droid recipe and the GitHub APKs run `flutter build apk` without this
// property, so they carry no Play code at all: F-Droid's reproducible build has
// to match the published APK byte for byte, so a runtime check alone could not
// keep the library out. The release workflow passes -PplayStore=true to
// `flutter build appbundle` alone.
//
// Everything Play-specific sits in play-store.gradle and src/play/, which
// the F-Droid recipe deletes before building (rm:), so its scanner never meets
// a Play library -- and the APK it rebuilds is unchanged, since neither is used
// without the property.
val playStoreBuild = (findProperty("playStore") as String?) == "true"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.magicgrants.skylight"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.1.13356709"

    dependenciesInfo {
        includeInApk = false // fdroid rejects extra signing blocks
        includeInBundle = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // One StoreReview or the other: Play's review flow, or a no-op.
    sourceSets {
        getByName("main") {
            java.srcDir(if (playStoreBuild) "src/play/kotlin" else "src/foss/kotlin")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.magicgrants.skylight"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                val storeFilePath = keystoreProperties["storeFile"] as String
                storeFile = if (storeFilePath.startsWith("/")) {
                    file(storeFilePath)  // Absolute path (local build)
                } else {
                    file(storeFilePath)  // Relative path (CI build)
                }
                storePassword = keystoreProperties["storePassword"] as String
                storeType = "JKS"  // Explicitly specify keystore type
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // FIDO2 security keys (FHSE wallet-file protection; SecurityKeyOperations.kt):
    // Yubico's yubikit-android, Apache-2.0, from Maven Central. No Google Play
    // Services or other proprietary code, so the F-Droid build stays clean.
    // `android` is USB/NFC discovery and transports; `fido` is the CTAP2 layer;
    // `management` reads the key's serial number (to tell registered keys apart).
    // Held at 3.1.0: 3.2.x's AAR requires compileSdk 37, above what Flutter and
    // AGP 8.12 use here (36).
    implementation("com.yubico.yubikit:android:3.1.0")
    implementation("com.yubico.yubikit:fido:3.1.0")
    implementation("com.yubico.yubikit:management:3.1.0")
}

if (playStoreBuild) {
    apply(from = "play-store.gradle")
}

flutter {
    source = "../.."
}
