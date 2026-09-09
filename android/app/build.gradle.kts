import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps anahtarı `android/local.properties` dosyasından okunur; o dosya
// .gitignore'da olduğu için anahtar depoya girmez. Anahtar tanımlı değilse
// derleme yine başarılı olur, harita yalnızca boş görünür — böylece anahtarı
// olmayan bir geliştirici de projeyi derleyebilir.
val mapsApiKey: String = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}.getProperty("MAPS_API_KEY") ?: ""

// Yayın imzası `android/key.properties` dosyasından okunur. Hem o dosya hem
// keystore .gitignore'da olduğu için parola depoya girmez
// (bkz. android/key.properties.example).
//
// Dosya yoksa yayın yapısı hata ayıklama anahtarıyla imzalanır: anahtarı
// olmayan bir geliştirici `flutter run --release` çalıştırabilsin diye.
// ⚠️ Öyle imzalanan bir yapı Play Store'a YÜKLENEMEZ ve Google girişi
// `DEVELOPER_ERROR` verir — yayın anahtarının SHA parmak izi Firebase'e
// kayıtlı olmadığı sürece.
val keystoreProperties: Properties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore: Boolean = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "app.regipass.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications, zamanlanmış bildirimleri eski Android
        // sürümlerinde de çalıştırabilmek için java.time API'lerini kullanır;
        // bu bayrak olmadan derleme "Call requires API level 26" ile durur.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // regipass.app alan adının ters-DNS karşılığı. Firebase'deki Android
        // uygulama kaydı da bu adla yapılmalı — ikisi eşleşmezse Google
        // Sign-In "DEVELOPER_ERROR" verir.
        applicationId = "app.regipass.mobile"
        // Flutter varsayılanı (API 24) firebase_auth 6.x'in istediği 23 ve
        // mobile_scanner/ML Kit'in istediği 21'in üzerinde — elle sabitlemek
        // yalnızca tavanı düşürür, bu yüzden varsayılan bırakıldı.
        minSdk = flutter.minSdkVersion
        // Google Play artık yeni yüklemelerde API 36 hedefi şart koşuyor, o
        // yüzden Flutter'ın varsayılanı (36) kullanılıyor. Tek görünür etkisi
        // şu: API 36, edge-to-edge muafiyetini yok saydığı için alttaki
        // gezinme çubuğu Android 16 cihazlarda kendiliğinden gizlenmez
        // (bkz. lib/app/system_ui.dart -> AutoHideNavigationBar ve
        // res/values-v36/styles.xml). Uygulama o cihazlarda iki çubukla
        // çalışmaya devam eder.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AndroidManifest'teki ${MAPS_API_KEY} yer tutucusunu doldurur.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
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

// Desugaring kitaplığı: yukarıdaki `isCoreLibraryDesugaringEnabled` bayrağı
// yalnızca bu bağımlılıkla birlikte iş görür.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
