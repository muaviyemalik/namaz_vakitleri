plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.namaz_vakitleri"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.namaz_vakitleri"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ÖNEMLİ: Bu bir DEBUG İMZASIDIR. Play Store'a gönderilebilir
            // bir yapı DEĞİLDİR. Gerçek yayın için `key.properties` ve
            // keystore gerekir (README "Yayın" bölümüne bakınız).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ---------------------------------------------------------------------------
// `perfect_volume_control` 1.0.6 UYUMLULUK DÜZELTMESİ
// ---------------------------------------------------------------------------
//
// Bu eklenti (pub.dev'de terk edilmiş) kendi android bloğunda
// `compileSdkVersion 30` sabitliyor. AndroidX'in güncel kaynakları
// `android:attr/lStar` gibi API 31'de gelen öznitelikler kullandığı için
// derleme `AAPT: error: attribute android:hardwareAccelerated not found`
// ile duruyor.
//
// Bu blok, eklentinin kendi ayarı DEĞERLENDİRİLDİKTEN SONRA compileSdk'ı
// API 36'ya çeker. Kaynak: 2026-09-21 fiziksel cihaz kurulumu notu.
//
// NEDEN `third_party/perfect_volume_control` KOPYASI YETERLİ DEĞİL:
// Kopya yalnızca derlenebilir hâle getirildi; eklentinin gradle dosyası
// hâlâ API 30 sabitliyor. Bu blok o sabiti geçersiz kılar.
subprojects {
    afterEvaluate {
        if (project.name == "perfect_volume_control") {
            project.extensions.findByName("android")?.let { androidExt ->
                (androidExt as? com.android.build.gradle.BaseExtension)?.apply {
                    compileSdkVersion(36)
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}