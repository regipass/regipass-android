import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../domain/account_expiry.dart';
import '../domain/routing.dart';
import '../features/auth/auth_actions.dart';
import '../features/landing/splash_screen.dart';
import '../features/notifications/notification_sync.dart';
import '../features/shared/offline_banner.dart';
import '../l10n/app_strings.dart';
import '../models/profiles.dart';
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

  /// Gezinme çubuğunun son uygulanan görünürlüğü (bkz. lib/app/system_ui.dart).
  bool? _appliedNavHidden;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
    ref.listenManual<Session>(
      sessionProvider,
      (Session? _, Session next) => unawaited(_purgeUnverifiedStudent(next)),
      fireImmediately: true,
    );
  }

  /// Aynı kaydı iki kez silmeye kalkmamak için kilit: `sessionProvider`,
  /// profil akışının her güncellemesinde yeniden yayın yapıyor.
  bool _purging = false;

  /// Süresi dolmuş doğrulanmamış öğrenci kaydını siler ve oturumu kapatır.
  ///
  /// Silme başarısız olursa (çevrimdışı, kural reddi) hiçbir şey yapılmaz:
  /// hesap doğrulama kapısında kalmaya devam eder ve sonraki açılışta
  /// yeniden denenir.
  Future<void> _purgeUnverifiedStudent(Session session) async {
    if (_purging || session.isLoading || !session.isSignedIn) return;
    if (session.isAdmin) return;

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
            keepAccount: session.appUser?.hasClubRole ?? false,
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
    // Başka bir uygulamadan dönüşte Android gezinme çubuğunu geri getirir;
    // panelin içindeysek gizli kalması gerekiyor.
    if (state == AppLifecycleState.resumed && _appliedNavHidden == true) {
      restoreSystemNavigationBarVisibility();
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

  @override
  void didChangeMetrics() {
    // Kullanıcı ekranın altından yukarı kaydırınca çubuk geçici olarak geri
    // gelir ve alt güvenli alan büyür. Aynı modu tekrar uygulamak onu yeniden
    // gizler; mod değişmediği için bu döngüye girmez.
    if (_appliedNavHidden != true) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _appliedNavHidden == true) {
        restoreSystemNavigationBarVisibility();
      }
    });
  }

  /// Oturum durumuna göre cihazın alt gezinme çubuğunu gizler/gösterir.
  void _syncSystemNavigationBar(Session session) {
    final bool hide = shouldHideSystemNavigationBar(
      isSignedIn: session.isSignedIn,
      isLoading: session.isLoading,
    );

    if (_appliedNavHidden == hide) return;
    _appliedNavHidden = hide;

    applySystemNavigationBarVisibility(hideNavigationBar: hide);
  }

  /// Durum ve gezinme çubuğu, seçili görünümle aynı tarafta olmalı: koyu
  /// modda koyu zemin + açık simge, açık modda tersi.
  void _syncSystemChrome(Brightness brightness) {
    if (_appliedChrome == brightness) return;
    _appliedChrome = brightness;

    final bool dark = brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: dark
            ? BrandColors.darkSurface
            : BrandColors.white,
        systemNavigationBarDividerColor: dark
            ? BrandColors.darkBorder
            : BrandColors.grayLight,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(routerProvider);
    final String language = ref.watch(languageProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final Session session = ref.watch(sessionProvider);
    _markStartupResolved(session);
    _syncSystemNavigationBar(session);

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
        // NotificationSync görünmez: yalnızca bildirim izni, etkinlik
        // alarmları ve gelen duyurular için ağaçta canlı bir dinleyici
        // gerekiyor (bkz. features/notifications/notification_sync.dart).
        builder: (BuildContext context, Widget? child) => NotificationSync(
          child: OfflineBanner(
            child: _StartupGate(
              showSplash: !_startupResolved,
              child: child ?? const SizedBox.shrink(),
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
