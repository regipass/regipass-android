import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kReleaseMode;

import '../firebase_options.dart';

/// Demo sürümü (demo.regipass.com'un mobil karşılığı).
///
/// YALNIZCA şu ayarla derlenince açılır (mağaza sürümünde her zaman kapalı):
///
///     flutter run --dart-define=REGIPASS_DEMO=true
///
/// Açıkken uygulama canlı proje yerine **regipass-demos** projesine bağlanır,
/// giriş ekranında "Öğrenci / Kulüp olarak dene" düğmeleri çıkar (şifre yok;
/// sunucudaki `demoSignIn` hazır hesaba jeton verir) ve ortak demo hesabını
/// bozabilecek düğmeler (kayıt, Google/Apple, şifremi unuttum) gizlenir.
///
/// Ekran görüntüsü için ayrıca `--dart-define=REGIPASS_SHOTS=true`:
/// QR'lar https://regipass.com gösterir; kamerası olmayan simülatörde kapı
/// ekranı örnek bir okutma sahnesiyle açılır. Bkz. docs/demo-mobil.md.
///
/// Mağaza sürümü bu ayar OLMADAN derlenir; ayar yoksa demo her zaman kapalı.
/// Telefona kurulan ayrı "Regipass Demo" uygulaması: scripts/demo-ios.sh.
const bool kDemoMode = bool.fromEnvironment('REGIPASS_DEMO');

/// Ekran görüntüsü kipi (yalnız demo ile birlikte).
const bool kShotsMode =
    kDemoMode && !kReleaseMode && bool.fromEnvironment('REGIPASS_SHOTS');

/// Ekran görüntüsündeki tüm QR'ların içeriği.
const String kShotsQrData = 'https://regipass.com';

/// Demo projesinin (regipass-demos) iOS uygulaması: "Regipass Demo".
/// Anahtar, web demosunun kullandığı tarayıcı anahtarıyla aynı (herkese açık
/// yapılandırma değeri; gizli değil).
const FirebaseOptions _demoIos = FirebaseOptions(
  apiKey: 'AIzaSyAs_Nb7TawrpPhkatXoKSis0itSpe0lqG0',
  appId: '1:216973453535:ios:e7c8cc14a1b44ab1d5216a',
  messagingSenderId: '216973453535',
  projectId: 'regipass-demos',
  storageBucket: 'regipass-demos.firebasestorage.app',
  iosBundleId: 'com.regipassbeta.mobile',
);

/// Uygulamanın bağlanacağı Firebase projesi.
FirebaseOptions get appFirebaseOptions {
  if (!kDemoMode) return DefaultFirebaseOptions.currentPlatform;
  if (defaultTargetPlatform == TargetPlatform.iOS) return _demoIos;
  throw UnsupportedError(
    'Demo sürümü şimdilik yalnızca iOS simülatöründe çalışır '
    '(regipass-demos projesinde Android uygulaması kayıtlı değil).',
  );
}
