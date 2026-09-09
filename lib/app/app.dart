import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/keyboard.dart';
import '../domain/account_expiry.dart';
import '../domain/routing.dart';
import '../features/auth/auth_actions.dart';
import '../features/landing/splash_screen.dart';
import '../features/notifications/notification_sync.dart';
import '../features/shared/offline_banner.dart';
import '../features/shared/phone_field.dart';
import '../l10n/app_strings.dart';
import '../models/profiles.dart';
import '../services/device_permission_service.dart';
import '../state/providers.dart';
import '../state/theme_mode.dart';
import 'router.dart';
import 'system_ui.dart';
import 'theme.dart';

class RegipassApp extends ConsumerStatefulWidget {
  const RegipassApp({super.key});

  @override
  ConsumerState<RegipassApp> createState() => _RegipassAppState();
}

class _RegipassAppState extends ConsumerState<RegipassApp>
    with WidgetsBindingObserver {
  /// Son uygulanan sistem çubuğu stili. Her build'de platform kanalına mesaj
  /// göndermemek için tutulur.
  Brightness? _appliedChrome;
  bool _startupResolved = false;
  bool _devicePermissionsRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Çubuklar görünür, içerik altlarına kadar uzanır
    // (bkz. lib/app/system_ui.dart).
    unawaited(applyVisibleSystemBars());

    // Telefon sahiplik dizinini geçmişe dönük doldur: hesabında doğrulanmış
    // numarası olan her kullanıcı, uygulamayı açtığında kendi kaydını bir kez
    // yazar. Dizin dolu oldukça "bu numara başkasına ait" uyarısı SMS
    // gönderilmeden ÖNCE verilebiliyor (bkz. phone_directory_repository.dart).
    ref.listenManual<AsyncValue<User?>>(authStateProvider, (
      AsyncValue<User?>? previous,
      AsyncValue<User?> next,
    ) {
      final User? user = next.value;
      if (user == null) return;
      unawaited(
        ref.read(phoneDirectoryRepositoryProvider).ensureSelfClaim(user),
      );
    }, fireImmediately: true);

    // Telefonunu doğrulamayan öğrencinin kaydı süre dolunca silinir
    // (bkz. lib/domain/account_expiry.dart).
    ref.listenManual<Session>(sessionProvider, (Session? _, Session next) {
      unawaited(_purgeUnverifiedStudent(next));
      unawaited(_syncPasswordResetHint(next));
    }, fireImmediately: true);
  }

  /// Aynı kaydı iki kez silmeye kalkmamak için kilit: `sessionProvider`,
  /// profil akışının her güncellemesinde yeniden yayın yapıyor.
  bool _purging = false;
  String? _lastPasswordResetHint;

  /// Eski kullanıcıların parola kurtarma kaydına mevcut rollerini ekler.
  /// Yalnızca Auth tarafından doğrulanmış ortak telefon yazılır; profil
  /// içindeki doğrulanmamış iletişim numarası kurtarma numarası sayılmaz.
  Future<void> _syncPasswordResetHint(Session session) async {
    if (session.isLoading || !session.isSignedIn || session.isAdmin) return;
    if (session.isProbingAccount || session.isResettingPassword) return;

    final User? user = session.user;
    final String email = (user?.email ?? '').trim();
    final String phone = (user?.phoneNumber ?? '').trim();
    final List<String> roles = _hintRoles(session);
    if (email.isEmpty || phone.isEmpty || roles.isEmpty) return;

    final String signature = '$email|$phone|${roles.join(',')}';
    if (_lastPasswordResetHint == signature) return;
    _lastPasswordResetHint = signature;

    final bool saved = await ref
        .read(phoneHintRepositoryProvider)
        .write(
          email: email,
          maskedPhone: maskE164ForDisplay(phone),
          roles: roles,
        );
    if (!saved && _lastPasswordResetHint == signature) {
      // Yazma düşerse imza sıfırlanır ve bir sonraki oturum senkronu tekrar
      // dener; nedeni [PhoneHintRepository.write] günlüğe yazıyor.
      _lastPasswordResetHint = null;
    }
  }

  /// İpucu belgesine yazılacak rol listesi.
  ///
  /// Tamamlanmış roller esas alınır. Hiçbiri yoksa hesap onboarding'in
  /// ortasındadır: telefon Auth tarafında ZATEN doğrulanmıştır, dolayısıyla
  /// kurtarma ipucu da yazılabilmelidir. `roles` alanı kurallar gereği en az
  /// bir geçerli değer istiyor; o yüzden o an yürüyen rol yazılır ve
  /// onboarding bitince imza değişip belge kendiliğinden tazelenir.
  List<String> _hintRoles(Session session) {
    final List<String> completed = <String>[
      if (session.hasStudentRole) UserRole.student,
      if (session.hasClubRole) UserRole.club,
    ];
    if (completed.isNotEmpty) return completed;

    final String? inProgress =
        session.pendingRole ??
        session.activeRole ??
        (session.studentProfile != null
            ? UserRole.student
            : session.clubProfile != null
            ? UserRole.club
            : null);
    return UserRole.isValid(inProgress)
        ? <String>[inProgress!]
        : const <String>[];
  }

  /// Süresi dolmuş doğrulanmamış öğrenci kaydını siler ve oturumu kapatır.
  ///
  /// Silme başarısız olursa (çevrimdışı, kural reddi) hiçbir şey yapılmaz:
  /// hesap doğrulama kapısında kalmaya devam eder ve sonraki açılışta
  /// yeniden denenir.
  Future<void> _purgeUnverifiedStudent(Session session) async {
    if (_purging || session.isLoading || !session.isSignedIn) return;
    if (session.isAdmin) return;
    // Kayıt ekranının yoklaması sırasında açılan oturum bir giriş değildir;
    // o hesap adına silme kararı verilmez (bkz. authProbeProvider).
    if (session.isProbingAccount) return;

    final User? user = session.user;
    final StudentProfile? profile = session.studentProfile;
    if (user == null || profile == null) return;

    final bool expired = isPhoneVerifyGraceExpired(
      phoneVerified: profile.phoneVerified,
      createdAtMs: profile.createdAtMs,
      now: DateTime.now(),
    );
    if (!expired) return;

    _purging = true;
    try {
      await ref
          .read(accountCleanupRepositoryProvider)
          .deleteUnverifiedStudent(
            user: user,
            profile: profile,
            // Hesapta kulüp rolü de varsa Auth hesabı ve `users` dokümanı
            // kulüp için ayakta kalmalı; yalnızca öğrenci tarafı silinir.
            keepAccount: session.hasClubRole,
          );
    } catch (_) {
      _purging = false;
      return;
    }

    ref
        .read(signOutNoticeProvider.notifier)
        .show('auth.notice.unverifiedPhoneRemoved');
    await logout(ref);
    _purging = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Başka bir uygulamadan (ör. kamera, tarayıcı) dönüşte sistem, kendi
    // yerleşim modunu geri koyabiliyor; edge-to-edge yeniden bildirilir.
    //
    // Android'de bunu [AutoHideNavigationBar] yapıyor: dönüşte çubukları geri
    // getirip gizlenme sayacını da yeniden kuruyor. Aynı bildirim buradan da
    // gönderilirse gizlenme durumu iki yerden yönetilmiş olurdu.
    if (state == AppLifecycleState.resumed && !autoHideNavigationBarSupported) {
      unawaited(applyVisibleSystemBars());
    }
  }

  @override
  void didChangePlatformBrightness() {
    // Telefon koyu/açık moda geçtiğinde uygulama da elle bir şey yapılmadan
    // aynı tarafa döner; kullanıcının önceki seçimi bu noktada geçersizleşir.
    if (!mounted) return;

    ref
        .read(themeModeProvider.notifier)
        .syncWithDeviceBrightness(
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        );
  }

  /// Çubukların simge stilini seçili görünüme göre ayarlar: koyu modda açık
  /// simge, açık modda koyu simge. Çubukların zemini her koşulda saydam;
  /// rengini altlarındaki tema veriyor (bkz. [systemBarsStyle]).
  void _syncSystemChrome(Brightness brightness) {
    if (_appliedChrome == brightness) return;
    _appliedChrome = brightness;

    SystemChrome.setSystemUIOverlayStyle(
      systemBarsStyle(brightness: brightness),
    );
  }

  void _markStartupResolved(Session session) {
    if (_startupResolved || session.isLoading) return;

    // `build` sırasında doğrudan setState çağrısı yapmak yerine bir sonraki
    // kareyi bekliyoruz. Böylece Firebase oturumu/profil verisi çözülene kadar
    // neon açılış ekranı kesintisiz görünür.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_startupResolved) {
        setState(() => _startupResolved = true);
        _requestDevicePermissions();
      }
    });
  }

  /// Bildirimler sesli/uyarı şeklinde gösterilebilsin, QR okuma ekranı
  /// kameraya anında erişebilsin ve harita/etkinlik girişi konumu
  /// kullanabilsin diye üç izin ilk kullanılabilir anda istenir. Kullanıcı
  /// daha önce seçim yaptıysa işletim sistemi tekrar pencere açmaz.
  void _requestDevicePermissions() {
    if (_devicePermissionsRequested) return;
    _devicePermissionsRequested = true;
    unawaited(DevicePermissionService.requestStartupPermissions());
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(routerProvider);
    final String language = ref.watch(languageProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final Session session = ref.watch(sessionProvider);
    _markStartupResolved(session);

    // Buzlu cam yalnızca panele girildikten sonra: giriş öncesi ekranlarda
    // çubuklar açılıştaki sade hâlinde kalır.
    final bool frosted = shouldFrostSystemBars(
      isSignedIn: session.isSignedIn,
      isLoading: session.isLoading || !_startupResolved,
    );

    // themeMode yalnızca açık ya da koyudur (cihaz takibi provider tarafında
    // yapılır). `system` yine de bir ihtimal olarak cihazdan okunuyor; bu
    // widget MaterialApp'in üstünde olduğu için ağaçta MediaQuery yok.
    final Brightness resolved = switch (themeMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    _syncSystemChrome(resolved);

    // Ban tespitinde oturumu kapat. Web'de her sayfa bunu kendi
    // onAuthStateChanged bloğunda yapıyordu; burada tek dinleyici yeterli.
    ref.listen<Session>(sessionProvider, (
      Session? previous,
      Session next,
    ) async {
      if (next.isLoading || !next.isSignedIn || next.isAdmin) return;
      // Yoklama oturumunu kayıt ekranı kendisi kapatıyor; buradan çıkış
      // yapılırsa yarım hesap temizliği de çalışır ve var olan hesaba
      // dokunulmuş olurdu (bkz. authProbeProvider).
      if (next.isProbingAccount) return;

      final String? role = next.resolvedRole;
      if (role == null) return;

      final String target = role == UserRole.club
          ? getClubRouteByStatus(next.clubProfile)
          : getStudentRouteByStatus(next.studentProfile);

      if (target != Routes.banned) return;

      await logout(ref);
    });

    return LanguageScope(
      language: language,
      child: MaterialApp.router(
        title: 'Regipass',
        debugShowCheckedModeBanner: false,
        theme: buildRegipassTheme(),
        darkTheme: buildRegipassTheme(brightness: Brightness.dark),
        themeMode: themeMode,
        routerConfig: router,
        // Kaydırma başlar başlamaz klavye kapanır — ekranlarda da pop-up ve
        // alt sayfaların içindeki listelerde de (bkz. lib/core/keyboard.dart).
        scrollBehavior: const RegipassScrollBehavior(),
        // NotificationSync görünmez: yalnızca bildirim izni, etkinlik
        // alarmları ve gelen duyurular için ağaçta canlı bir dinleyici
        // gerekiyor (bkz. features/notifications/notification_sync.dart).
        builder: (BuildContext context, Widget? child) => AnnotatedRegion<SystemUiOverlayStyle>(
          // Uygulama genelinin çubuk stili. Aynı stil [_syncSystemChrome]
          // ile de bildiriliyor: oradaki çağrı ilk kare çizilmeden önce ve
          // tema değiştiğinde geçerli. Buradaki katman kalıcı zemini kurar —
          // kendi stilini dayatan bir ekran ([DarkScreenSystemBars]) ya da
          // bir AppBar ağaçtan çıktığında çubuklar bu stile geri döner.
          value: systemBarsStyle(brightness: resolved),
          child: AutoHideNavigationBar(
            // Alttaki sistem çubuğu, KENDİSİNE 3 saniye dokunulmazsa gizlenir;
            // şeridine dokunulduğunda geri gelir (bkz. lib/app/system_ui.dart).
            // Dinleyici yönlendiricinin üstünde: hangi ekran/pop-up açık olursa
            // olsun aynı kural işler.
            child: NotificationSync(
              child: OfflineBanner(
                // Sistem çubuklarının şeridi her şeyin üstünde buğulanır; açılan
                // sayfa ya da pencere ne olursa olsun çubukların altı aynı görünür
                // (bkz. lib/app/system_ui.dart).
                child: SystemBarsFrost(
                  enabled: frosted,
                  child: _StartupGate(
                    showSplash: !_startupResolved,
                    // İkisi de yönlendiricinin (dolayısıyla açılan her pencerenin)
                    // üstünde: boşluğa dokununca klavye kapanır, çok satırlı bir
                    // alan yazılırken klavyenin üstünde "Bitti" çubuğu belirir.
                    child: KeyboardDoneBar(
                      child: DismissKeyboardOnTap(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// İlk Firebase oturumu ile profil akışları çözülene kadar rotanın üzerinde
/// duran açılış perdesi. Sonraki giriş/çıkışlarda tekrar gösterilmez.
class _StartupGate extends StatefulWidget {
  const _StartupGate({required this.showSplash, required this.child});

  final bool showSplash;
  final Widget child;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  /// Perde yalnızca silinme animasyonu bitene kadar ağaçta kalır.
  ///
  /// Görünmez de olsa ağaçta bırakılırsa açılış ekranının nefes alma ve
  /// yükleme çubuğu animasyonları uygulamanın tüm ömrü boyunca her karede
  /// çalışmaya devam ediyordu.
  bool _splashInTree = true;

  @override
  void didUpdateWidget(_StartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Perde yeniden istenirse (ör. sıcak yeniden yükleme) geri gelsin.
    if (widget.showSplash && !_splashInTree) {
      setState(() => _splashInTree = true);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      widget.child,
      if (_splashInTree)
        IgnorePointer(
          ignoring: !widget.showSplash,
          child: AnimatedOpacity(
            opacity: widget.showSplash ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            onEnd: () {
              if (!widget.showSplash && mounted) {
                setState(() => _splashInTree = false);
              }
            },
            child: const SplashScreen(),
          ),
        ),
    ],
  );
}
