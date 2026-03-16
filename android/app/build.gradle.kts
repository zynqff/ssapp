plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")  // добавить
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sscollective.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.sscollective.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- БЛОК ПОДПИСИ ПРИЛОЖЕНИЯ ---
    signingConfigs {
        create("release") {
            // Эти переменные подтянутся из твоего YAML-скрипта на GitHub
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            
            val ksPath = System.getenv("KEYSTORE_PATH")
            if (!ksPath.isNullOrEmpty()) {
                storeFile = file(ksPath)
            }
        }
    }

    buildTypes {
        release {
            // Используем созданную выше конфигурацию "release"
            signingConfig = signingConfigs.getByName("release")
            
            // Оптимизация и сжатие кода (рекомендуется для релизных APK)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
