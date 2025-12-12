plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.helloworld"
    compileSdk = 35  // KITA PAKSA KE VERSI 34 (Android 14)
    buildToolsVersion "35.0.0"  // <--- TAMBAHKAN BARIS INI (PAKSA KE 35)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // Ubah ke 1.8 (Standar Flutter)
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        // Ganti ID aplikasi ini sesuai keinginanmu nanti
        applicationId = "com.example.helloworld"
        
        minSdk = flutter.minSdkVersion        // Minimal Android 5.0 (Standar)
        targetSdk = 35     // Target Android 14
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ... (biarkan kode atasnya seperti semula) ...

subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.android {
                if (namespace == null) {
                    namespace = project.group.toString()
                }
                compileSdkVersion 35
                buildToolsVersion "35.0.0" // KITA PAKSA SEMUA ORANG PAKAI INI
            }
        }
    }
}