import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/system_ui.dart';
import 'app/theme.dart';
import 'features/landing/splash_screen.dart';
import 'firebase_options.dart';
import 'services/notification_read_store.dart';
import 'services/notification_service.dart';
import 'services/role_session_store.dart';
import 'state/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Sistem çubuklarını beklemeden uygula. Önceden bu Future'ın, Firebase'in,
  // tarih verisinin ve SharedPreferences'ın tamamı bitmeden runApp çağrılmıyor;
  // bu da logo ekranının bile gecikmiş görünmesine neden oluyordu.
  unawaited(applyVisibleSystemBars());

  // Açılış perdesi cihazın görünümünü izliyor (bkz. splash_screen.dart), sistem
  // çubukları da ilk kareden itibaren aynı tarafta olmalı; aksi halde koyu
  // modda alt gezinme çubuğu bir an beyaz parlıyordu.
  final bool dark =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  SystemChrome.setSystemUIOverlayStyle(
    systemBarsStyle(brightness: dark ? Brightness.dark : Brightness.light),
  );

  // İlk Flutter karesinde splash görünür; Firebase ve cihaz depoları onun
  // arkasında paralel olarak hazırlanır.
  runApp(const _BootstrapApp());
}

/// Firebase'i başlatır ve telefon doğrulamasının cihaz kontrolünü ayarlar.
///
/// `forceRecaptchaFlow: false`: Android'de SMS göndermeden önceki bot kontrolü
/// Play Integrity ile SESSİZCE yapılır; reCAPTCHA yalnızca son çare olarak
/// (Play Integrity yanıt vermezse) devreye girer. Uygulamanın kullanıcıyı bir
/// tarayıcı/WebView reCAPTCHA sayfasına atmasının sebebi bu son çareye
/// düşmesidir.
///
/// **Bu ayar tek başına yetmez** — Play Integrity çalışmıyorsa Firebase yine
/// reCAPTCHA'ya düşer. Konsol tarafındaki koşullar için:
/// `docs/telefon-dogrulama-recaptcha.md`.
Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await FirebaseAuth.instance.setSettings(
      // Geliştirme kolaylığı: `--dart-define=PHONE_TEST_MODE=true` ile
      // derlenen yapılarda cihaz doğrulaması tamamen atlanır — reCAPTCHA
      // sayfası hiç açılmaz, SMS de gönderilmez. Firebase Console >
      // Authentication > Phone > "Test için telefon numaraları" listesindeki
      // numara + sabit kod ikilisiyle çalışır. Yayın yapılarında kapalıdır.
      appVerificationDisabledForTesting: _phoneTestMode,
      forceRecaptchaFlow: false,
    );
  } catch (_) {
    // Ayar uygulanamazsa (platform desteklemiyorsa) varsayılan davranış sürer.
  }
}

/// Yalnızca `--dart-define=PHONE_TEST_MODE=true` ile açılır. Release yapısında
/// yanlışlıkla açık kalmasın diye ayrıca `kReleaseMode` ile kapatılır.
const bool _phoneTestMode =
    bool.fromEnvironment('PHONE_TEST_MODE') && !kReleaseMode;

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  RoleSessionStore? _roleSessionStore;
  NotificationReadStore? _notificationReadStore;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Birbirinden bağımsız başlangıç işlerini aynı anda başlatıyoruz.
    final Future<RoleSessionStore> roleSessionStore = RoleSessionStore.create();
    final Future<NotificationReadStore> readStore =
        NotificationReadStore.create();

    // Bildirim eklentisi perdenin arkasında hazırlanır. Beklenmiyor: izin
    // kutusu açılışta değil, kullanıcı panele girdiğinde çıkar ve kanal
    // kurulumunun ilk kareyi geciktirmesi için bir sebep yok.
    unawaited(NotificationService.instance.init());

    await Future.wait<void>(<Future<void>>[
      _initFirebase(),
      initializeDateFormatting('tr_TR'),
      initializeDateFormatting('en_US'),
    ]);

    final RoleSessionStore readyStore = await roleSessionStore;
    final NotificationReadStore readyReadStore = await readStore;
    if (!mounted) return;
    setState(() {
      _roleSessionStore = readyStore;
      _notificationReadStore = readyReadStore;
    });
  }

  @override
  Widget build(BuildContext context) {
    final RoleSessionStore? roleSessionStore = _roleSessionStore;
    final NotificationReadStore? notificationReadStore = _notificationReadStore;
    if (roleSessionStore == null || notificationReadStore == null) {
      // Tercih henüz okunmadı (SharedPreferences bu perdenin arkasında
      // yükleniyor); bu ilk aşamada cihazın görünümü esas alınır — provider
      // da ilk karede aynı şeyi yapıyor, dolayısıyla perde devralınırken
      // zemin rengi değişmiyor.
      return MaterialApp(
        title: 'Regipass',
        debugShowCheckedModeBanner: false,
        theme: buildRegipassTheme(),
        darkTheme: buildRegipassTheme(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      );
    }

    return ProviderScope(
      // Liste türü yazılmıyor: `Override` sınıfı flutter_riverpod'dan dışa
      // aktarılmıyor; tür, parametreden zaten çıkarılıyor.
      // ignore: always_specify_types
      overrides: [
        roleSessionStoreProvider.overrideWithValue(roleSessionStore),
        notificationReadStoreProvider.overrideWithValue(notificationReadStore),
      ],
      child: const RegipassApp(),
    );
  }
}
