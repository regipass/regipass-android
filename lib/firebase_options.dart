import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase yapılandırması — `flutterfire configure` tarafından üretilir.
///
/// Android applicationId: `app.regipassapp.mobile`; iOS bundle ID:
/// `app.regipass.mobile`.
///
/// ⚠️ Google Sign-In ve Telefon (SMS) doğrulaması için bu dosya TEK BAŞINA
/// yetmez. Firebase Console > Proje ayarları > Android uygulaması altına
/// SHA-1 ve SHA-256 parmak izleri eklenmelidir. Eklenmediği sürece
/// `google-services.json` içinde Android OAuth istemcisi (`client_type: 1`)
/// oluşmaz ve Google girişi `DEVELOPER_ERROR` ile düşer.
///
/// Parmak izini almak için: `cd android && ./gradlew signingReport`
///
/// NOT: Bu dosyayı elle düzenlemeyin — `flutterfire configure` her
/// çalıştığında üzerine yazılır.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Regipass yalnızca Android ve iOS için yapılandırıldı '
          '($defaultTargetPlatform desteklenmiyor).',
        );
    }
  }

  /// js/core/firebase.js ile birebir aynı — bu değerler doğrulanmıştır.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAtuvgWGNk3H37VxSvh-KMMhDszSJqVUa8',
    appId: '1:738082064551:web:96b3d0367a838bc904b382',
    messagingSenderId: '738082064551',
    projectId: 'eventapp-604a5',
    authDomain: 'regipass.com',
    storageBucket: 'eventapp-604a5.firebasestorage.app',
    measurementId: 'G-KDR4SDH4W2',
  );


  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD3ql3O4j6SwnYKeM3CNUwaYOdJhw0IyJo',
    appId: '1:738082064551:android:be8069a17d52262504b382',
    messagingSenderId: '738082064551',
    projectId: 'eventapp-604a5',
    databaseURL: 'https://eventapp-604a5-default-rtdb.firebaseio.com',
    storageBucket: 'eventapp-604a5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBL70q7Ki7jJI-frylGM9JARuuJdWnY5gM',
    appId: '1:738082064551:ios:e9fc0d3ac944fd3f04b382',
    messagingSenderId: '738082064551',
    projectId: 'eventapp-604a5',
    databaseURL: 'https://eventapp-604a5-default-rtdb.firebaseio.com',
    storageBucket: 'eventapp-604a5.firebasestorage.app',
    iosClientId: '738082064551-8ar660fj2b8j8sukqbhhkvfn3hhv62ts.apps.googleusercontent.com',
    iosBundleId: 'app.regipass.mobile',
  );
}
