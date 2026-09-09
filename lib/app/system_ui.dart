/// Cihazın sistem çubuklarının (üstteki durum/bildirim çubuğu + alttaki
/// gezinme çubuğu) nasıl görüneceğini belirleyen kurallar.
///
/// Kural tek cümle: **durum çubuğu her ekranda görünür kalır; iki çubuk da
/// saydamdır ve altlarındaki tema zemini görünür (edge-to-edge), oturum
/// açıldıktan sonra arkalarına buzlu cam katmanı çizilir ve alttaki gezinme
/// çubuğu KENDİSİNE 3 saniye dokunulmadığında gizlenir.**
///
/// Gizlenme kuralı [AutoHideNavigationBar] içinde: sayaç yalnızca çubuğun
/// kendi şeridine yapılan dokunuşla yenilenir. Ekranın geri kalanına dokunmak
/// çubuğu ne geri getirir ne de gizlenmesini erteler; gizli çubuk, şeridine
/// dokunulduğu anda geri gelir.
///
/// Çubuk renkleri her koşulda saydamdır: rengi, altında duran uygulama
/// zemini (yani seçili tema) verir. Panele girildikten sonra [SystemBarsFrost]
/// bu zemini ayrıca bulanıklaştırıp üzerine ince bir katman serer — çubuklar
/// kaybolmadan uygulamanın parçasıymış gibi görünür.
///
/// PLATFORM NOTU: Buzlu cam efekti Android/iOS'un kendi çubuk çiziminde değil,
/// çubukların ARKASINDAKİ uygulama katmanında üretilir. Bu yüzden çubuk
/// renkleri saydam bırakılır; sistemin kendi kontrast dolgusunu araya
/// sokmaması için `systemStatusBarContrastEnforced` ve
/// `systemNavigationBarContrastEnforced` kapalıdır.
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Çubukların arkasına buzlu cam serilsin mi?
///
/// Oturum çözülmeden (açılış perdesi sürerken) buzlu cama geçilmez: perde
/// kapanır kapanmaz efektin belirmesi, açılışta göze çarpan bir renk
/// sıçraması yaratırdı.
bool shouldFrostSystemBars({
  required bool isSignedIn,
  required bool isLoading,
}) => isSignedIn && !isLoading;

/// Her iki çubuğun da açık olduğu katman listesi.
List<SystemUiOverlay> get visibleSystemOverlays => SystemUiOverlay.values;

/// Alt çubuk gizliyken açık kalan katmanlar: yalnızca durum çubuğu.
///
/// Listede [SystemUiOverlay.top] kaldığı için içerik durum çubuğunun altına
/// uzanmaya devam eder; motor yalnızca "alt çubuğu gizle" bayrağını ekler.
const List<SystemUiOverlay> topOnlySystemOverlays = <SystemUiOverlay>[
  SystemUiOverlay.top,
];

/// Alt gezinme çubuğu, kendisine bu süre boyunca dokunulmazsa gizlenir.
const Duration kNavigationBarIdleDelay = Duration(seconds: 3);

/// Gizli çubuğu geri çağıran şeridin yüksekliği (mantıksal piksel).
///
/// Çubuk gizliyken güvenli alan sıfırlanır, yani "çubuğun yeri" artık
/// MediaQuery'den okunamaz; ekranın en alt bandı bu sabitle tanımlanır.
///
/// DAR TUTULUYOR: çubuk gizlenince uygulamanın kendi alt sekme çubuğu ekranın
/// en altına iniyor. Şerit çubuğun gerçek yüksekliği kadar (üç düğmeli
/// gezinmede ~48) olsaydı sekmelere her basışta sistem çubuğu geri gelirdi.
const double kNavigationBarTouchStrip = 12;

/// Çubukları görünür tutar ve içeriği altlarına kadar uzatır.
Future<void> applyVisibleSystemBars() => SystemChrome.setEnabledSystemUIMode(
  SystemUiMode.edgeToEdge,
  overlays: visibleSystemOverlays,
);

/// Yalnızca alttaki gezinme çubuğunu gizler; durum çubuğu yerinde kalır.
Future<void> hideSystemNavigationBar() => SystemChrome.setEnabledSystemUIMode(
  SystemUiMode.manual,
  overlays: topOnlySystemOverlays,
);

/// Kendiliğinden gizlenme yalnızca Android'de çalışır.
///
/// iOS'ta ekranın altındaki çizgiyi (home indicator) sistem kendi kuralına
/// göre yönetir, web'de böyle bir çubuk yoktur.
///
/// ANDROID SÜRÜM NOTU: `edgeToEdge` dışındaki modlar, Android 15'ten (API 35)
/// itibaren yalnızca tema `android:windowOptOutEdgeToEdgeEnforcement` ile
/// muafiyet isterse uygulanır (bkz. android/app/src/main/res/values/styles.xml).
/// Android 16 ve sonrasında bu muafiyet kaldırıldığı için çubuk gizlenmez —
/// uygulama o cihazlarda bugünkü gibi iki çubukla çalışmaya devam eder.
bool get autoHideNavigationBarSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Çubukların renk/simge stili.
///
/// İki çubuk da her ekranda saydamdır: rengini altlarındaki uygulama zemini,
/// yani seçili tema verir. Sistemin kendi kontrast dolgusu da kapalı; açılırsa
/// saydamlığın üstüne gri bir bant çizerdi.
///
/// Simgeler seçili görünümle ters tarafta olmalı: koyu modda açık simge, açık
/// modda koyu simge.
SystemUiOverlayStyle systemBarsStyle({required Brightness brightness}) {
  final bool dark = brightness == Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Zemini uygulama temasından bağımsız KOYU olan ekranların çubuk stili.
///
/// Giriş öncesi ekranlar (giriş, kayıt, şifre sıfırlama, Keşfet) açık temada da
/// gece görünümünde kalıyor. Çubuk simgeleri ise uygulamanın temasını izliyor
/// ([systemBarsStyle]); açık temada o ekranların üstüne koyu simge çiziliyor ve
/// simgeler koyu zeminde kaybolduğu için çubuk şeridi düz siyah bir bant gibi
/// okunuyordu. Bu sarmalayıcı yalnızca simgeleri açık renge sabitler —
/// çubukların zemini yine saydam, altındaki ekran görünmeye devam eder.
///
/// `AnnotatedRegion` bilerek: kural yalnızca bu ekranlar ağaçtayken geçerlidir,
/// ekrandan çıkıldığında uygulama genelindeki stil (bkz. lib/app/app.dart)
/// kendiliğinden geri döner.
class DarkScreenSystemBars extends StatelessWidget {
  const DarkScreenSystemBars({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: systemBarsStyle(brightness: Brightness.dark),
    child: child,
  );
}

/// Buzlu camın bulanıklık yarıçapı.
const double _kFrostBlur = 18;

/// Cam katmanının opaklığı. Çubuk simgeleri okunur kalacak kadar var, altındaki
/// içerik seçilecek kadar az.
const double _kFrostAlphaLight = 0.42;
const double _kFrostAlphaDark = 0.34;

/// Sistem çubuklarının kapladığı şeritlere buzlu cam serer.
///
/// Yönlendiricinin (ve dolayısıyla açılan tüm sayfa/pencerelerin) ÜSTÜNDE
/// durur; hangi ekran açık olursa olsun çubukların altı aynı görünür.
/// Dokunuşları geçirir, yerleşimi değiştirmez: yalnızca güvenli alan
/// yüksekliği kadar iki şeridin boyanmasıdır.
class SystemBarsFrost extends StatelessWidget {
  const SystemBarsFrost({
    required this.enabled,
    required this.child,
    super.key,
  });

  /// Buzlu cam yalnızca panele girildikten sonra çizilir.
  final bool enabled;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    // Klavye açıkken alt güvenli alan sıfırlanır; o an alt şerit hiç
    // çizilmez, yoksa klavyenin üstünde asılı bir bant kalırdı.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        if (padding.top > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: padding.top,
            child: _FrostStrip(dark: dark),
          ),
        if (padding.bottom > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: padding.bottom,
            child: _FrostStrip(dark: dark),
          ),
      ],
    );
  }
}

/// Tek bir buzlu cam şeridi.
class _FrostStrip extends StatelessWidget {
  const _FrostStrip({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    // ClipRect şart: BackdropFilter sınırlandırılmazsa bulanıklık şeridin
    // dışına taşar ve tüm ekranı yumuşatır.
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _kFrostBlur, sigmaY: _kFrostBlur),
        child: ColoredBox(
          color: (dark ? BrandColors.darkSurface : BrandColors.white)
              .withValues(alpha: dark ? _kFrostAlphaDark : _kFrostAlphaLight),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

/// Alt gezinme çubuğunu, kendisine dokunulmadığı sürece gizler.
///
/// Kural: çubuğa [kNavigationBarIdleDelay] boyunca dokunulmazsa gizlenir.
/// Ekranın geri kalanı bu kuralın dışında — uygulamayı kullanmak çubuğu ne
/// geri getirir ne de gizlenmesini erteler. Gizli çubuk, kapladığı şeride
/// (ekranın en alt bandına) dokunulduğu anda geri gelir ve sayaç yeniden
/// başlar.
///
/// Şerit [kNavigationBarTouchStrip] kadar incedir; uygulamanın alt sekme
/// çubuğuna basarken sistem çubuğunun geri gelmemesi için bilerek dar.
///
/// Yönlendiricinin üstünde durur; hangi ekran, alt sayfa ya da pop-up açık
/// olursa olsun aynı kural işler. Dokunuşlar dinlenir ama TÜKETİLMEZ:
/// [Listener] olayı gördüğü hâlde altındaki ekranlara geçirir.
///
/// Klavye açıkken çubuk gizlenmez; yazarken yerleşimin altından kayması hem
/// sıçrama yaratır hem de klavyeyle çakışırdı. Klavye kapanınca sayaç yeniden
/// kurulur.
///
/// Desteklenmeyen platformlarda ([autoHideNavigationBarSupported] false)
/// hiçbir şey yapmaz, doğrudan [child]'ı döndürür.
class AutoHideNavigationBar extends StatefulWidget {
  const AutoHideNavigationBar({required this.child, super.key});

  final Widget child;

  @override
  State<AutoHideNavigationBar> createState() => _AutoHideNavigationBarState();
}

class _AutoHideNavigationBarState extends State<AutoHideNavigationBar>
    with WidgetsBindingObserver {
  Timer? _hideTimer;
  bool _hidden = false;
  bool _keyboardOpen = false;

  /// Ekranın yüksekliği: dokunuşun alt şeride denk gelip gelmediği bundan
  /// hesaplanır.
  double _screenHeight = 0;

  /// Parmağın çubuk üzerinde gezindiği sürece sayacın boşuna yenilenmemesi
  /// için son yenileme anı.
  DateTime? _lastTouch;

  /// Sistemin kendiliğinden geri getirdiği çubuğu tekrar gizlerken art arda
  /// mesaj göndermemek için son bildirim anı.
  DateTime? _lastReassert;

  bool get _enabled => autoHideNavigationBarSupported;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;

    WidgetsBinding.instance.addObserver(this);
    _scheduleHide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) return;

    _screenHeight = MediaQuery.sizeOf(context).height;

    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardOpen == _keyboardOpen) return;
    _keyboardOpen = keyboardOpen;

    if (keyboardOpen) {
      // Klavye açılırken çubuk gizliyse geri getirilir: klavyenin üstündeki
      // "Bitti" çubuğu (bkz. lib/core/keyboard.dart) sistem çubuğunun yerini
      // hesaba katarak yerleşiyor.
      _hideTimer?.cancel();
      _hideTimer = null;
      _show();
    } else {
      _scheduleHide();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled || state != AppLifecycleState.resumed) return;

    // Başka bir uygulamadan (ör. kamera, tarayıcı) dönüşte sistem kendi
    // yerleşim modunu geri koyabiliyor; çubuklar önce görünür hâle getirilip
    // sayaç yeniden kurulur.
    _show(force: true);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Dokunuş, çubuğu geri çağıran alt şeride denk geliyor mu?
  bool _isOnNavigationBar(Offset position) {
    if (_screenHeight <= 0) return false;

    return position.dy >= _screenHeight - kNavigationBarTouchStrip;
  }

  /// Çubuğu geri getirir. [force] yalnızca uygulamaya dönüşte kullanılır:
  /// çubuk zaten görünürken bile yerleşim modu platforma yeniden bildirilir.
  void _show({bool force = false}) {
    if (!_hidden && !force) return;
    _hidden = false;
    unawaited(applyVisibleSystemBars());
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_keyboardOpen) return;

    _hideTimer = Timer(kNavigationBarIdleDelay, () {
      _hideTimer = null;
      if (!mounted || _hidden || _keyboardOpen) return;
      _hidden = true;
      unawaited(hideSystemNavigationBar());
    });
  }

  /// Çubuğa dokunuldu: geri gelir ve sayaç sıfırdan işler.
  void _touchedNavigationBar({bool throttle = false}) {
    final DateTime now = DateTime.now();

    // Parmak çubuğun üstünde gezinirken saniyede onlarca olay gelir; sayaç
    // yarım saniyeden sık yenilenmez.
    if (throttle &&
        _lastTouch != null &&
        now.difference(_lastTouch!) < const Duration(milliseconds: 500)) {
      return;
    }

    _lastTouch = now;
    _show();
    _scheduleHide();
  }

  /// Çubuk dışına dokunmak kuralı işletmez.
  ///
  /// Tek istisna: Android, çubuğu gizli tutarken ekrana dokunulduğunda onu
  /// kendiliğinden geri gösterebiliyor. Uygulama o dokunuşta kararı yeniden
  /// bildirir, yoksa çubuk sayaç dolmadan açık kalırdı.
  void _touchedElsewhere() {
    if (!_hidden) return;

    final DateTime now = DateTime.now();
    if (_lastReassert != null &&
        now.difference(_lastReassert!) < const Duration(milliseconds: 500)) {
      return;
    }

    _lastReassert = now;
    unawaited(hideSystemNavigationBar());
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    return Listener(
      // translucent: çocuk o noktada bir şey çizmese bile olay buraya ulaşır;
      // olay yine de aşağıya geçtiği için hiçbir dokunuş kaybolmaz.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        if (_isOnNavigationBar(event.position)) {
          _touchedNavigationBar();
        } else {
          _touchedElsewhere();
        }
      },
      onPointerMove: (PointerMoveEvent event) {
        if (!_isOnNavigationBar(event.position)) return;
        _touchedNavigationBar(throttle: true);
      },
      // Parmak kalkarken de sayılır: üç saniye, dokunuşun bittiği andan
      // itibaren işler.
      onPointerUp: (PointerUpEvent event) {
        if (!_isOnNavigationBar(event.position)) return;
        _touchedNavigationBar();
      },
      child: widget.child,
    );
  }
}
