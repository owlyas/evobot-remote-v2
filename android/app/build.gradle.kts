plugins {
    id("com.android.application")
    kotlin("android")
}

android {
    compileSdk = 33

    defaultConfig {
        applicationId = "com.example.evobot"
        minSdk = 21
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.polidea.flutter_blue_plus:flutter_blue_plus:1.5.2") // example
}

// Add BLE permissions to manifest automatically (if using manifest placeholders)
android.applicationVariants.all {
    val variant = this
    variant.mergedManifestsProvider.get().forEach { manifest ->
        manifest.manifestPlaceholders["BLUETOOTH_SCAN"] = "android.permission.BLUETOOTH_SCAN"
        manifest.manifestPlaceholders["BLUETOOTH_CONNECT"] = "android.permission.BLUETOOTH_CONNECT"
    }
}
