import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val signing = Properties()
val keyFile = rootProject.file("key.properties")
if (keyFile.exists()) keyFile.inputStream().use { signing.load(it) }

android {
    namespace = "pl.jarekgadzina.dokumenty"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    defaultConfig {
        applicationId = "pl.jarekgadzina.dokumenty"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk { abiFilters += "arm64-v8a" }
    }
    // LibreOffice maps its assets directly from the APK ZIP file.
    androidResources { noCompress += "" }
    packaging {
        jniLibs { useLegacyPackaging = true }
        // Dependency notices are included in the app's licenses/NOTICE.txt bundle.
        resources.excludes += setOf("META-INF/DEPENDENCIES", "META-INF/LICENSE", "META-INF/LICENSE.txt", "META-INF/NOTICE", "META-INF/NOTICE.txt", "META-INF/versions/9/OSGI-INF/MANIFEST.MF")
    }
    signingConfigs {
        create("release") {
            if (keyFile.exists()) {
                storeFile = file(signing.getProperty("storeFile"))
                storePassword = signing.getProperty("storePassword")
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
flutter { source = "../.." }

// Read-only content:// attachments for Android sharing.
dependencies {
    implementation("androidx.core:core:1.13.1")
    implementation("com.tom-roush:pdfbox-android:2.0.27.0")
}
