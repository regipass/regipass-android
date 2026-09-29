import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// system_ui.dart bu dosyayı (BrandColors için) zaten kullanıyor; çubuk
// kuralının tek bir yerde kalması adına döngüsel içe aktarım göze alındı.
import 'system_ui.dart';

/// Web tasarım sisteminin (css/ds.css — `--rp-*` değişkenleri) Flutter
/// karşılığı. Renk isimleri eski sürümlerle uyumlu tutuldu; değerler web'in
/// yeni "profesyonel, kurumsal ama genç" görünümüne (slate nötrler + marka
/// kırmızısı) çekildi. İki taraf birlikte güncellenebilsin diye web'deki
/// karşılığı yorumlarda yazıyor.
class BrandColors {
  /// --rp-red
  static const Color red = Color(0xFFE5383B);

  /// --rp-red-600 (gradyanın koyu ucu)
  static const Color redDark = Color(0xFFBA181B);

  /// Gradyanın açık ucu (#EF4444).
  static const Color redBright = Color(0xFFEF4444);
  static const Color maroon = Color(0xFFA4161A);

  /// --rp-ink: başlıklar ve ana metin.
  static const Color black = Color(0xFF0F172A);
  static const Color ink = black;

  /// --rp-text: gövde metni.
  static const Color text = Color(0xFF334155);

  /// Koyu bindirmeler (ör. görsel üstü perde).
  static const Color blackDeep = Color(0xFF0B1220);

  /// --rp-line: kenarlık ve ayırıcı.
  static const Color grayLight = Color(0xFFE2E8F0);
  static const Color line = grayLight;

  /// --rp-line-soft / yumuşak dolgu.
  static const Color soft = Color(0xFFF1F5F9);

  /// --rp-surface-2: sayfa zemini.
  static const Color grayLighter = Color(0xFFF8FAFC);
  static const Color white = Color(0xFFFFFFFF);

  /// Birincil eylem gradyanı: `linear-gradient(135deg, #ef4444, #e5383b,
  /// #ba181b)` (--rp-grad). 135deg CSS'te sol-üstten sağ-alta akar.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[redBright, red, redDark],
    stops: <double>[0.0, 0.5, 1.0],
  );

  /// Vurgulu yüzeylerdeki üç duraklı gradyan.
  static const LinearGradient gradientRich = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[red, redDark, maroon],
    stops: <double>[0.0, 0.48, 1.0],
  );

  /// Açık kırmızı — koyu zeminde marka vurgusu, seçili segmentler.
  static const Color redSoft = Color(0xFFF26D70);

  /// Kırmızının en açık dolgusu (--rp-red-50).
  static const Color redTint = Color(0xFFFEF2F2);

  static const Color success = Color(0xFF15803D);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color danger = redDark;
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color warning = Color(0xFFB45309);
  static const Color warningBg = Color(0xFFFEF3C7);

  /// --rp-muted: ikincil metin.
  static const Color muted = Color(0xFF64748B);

  // ── Koyu mod yüzeyleri (slate tabanlı) ─────────────────────────────

  /// Sayfa zemini.
  static const Color darkBase = Color(0xFF0B1018);

  /// Kart, üst çubuk, alt çubuk, modal zemini.
  static const Color darkSurface = Color(0xFF141B26);

  /// Kart içindeki ikincil dolgu (bilgi bloğu, hap etiket zemini).
  static const Color darkSurfaceAlt = Color(0xFF1D2633);

  /// Ayırıcı ve kenarlık.
  static const Color darkBorder = Color(0xFF2A3444);

  /// Ana metin.
  static const Color darkText = Color(0xFFE8EDF4);

  /// Gövde metni.
  static const Color darkBody = Color(0xFFC8D1DD);

  /// İkincil metin.
  static const Color darkMuted = Color(0xFF97A3B6);

  // Geri bildirim tonlarının koyu modda okunabilir karşılıkları.
  static const Color successBgDark = Color(0xFF12301F);
  static const Color successOnDark = Color(0xFF6EE7A0);
  static const Color dangerBgDark = Color(0xFF3A1719);
  static const Color dangerOnDark = Color(0xFFFF8A8F);
  static const Color infoBgDark = Color(0xFF15243F);
  static const Color infoOnDark = Color(0xFF8AB4FF);

  // ── Giriş öncesi ekranların koyu varyantı ─────────────────────────
  // Giriş/kayıt/şifre/Keşfet ekranları artık temayı izliyor (açık temada
  // web'deki gibi beyaz zemin + yumuşak kırmızı ışıma). Aşağıdaki token'lar
  // bu ekranların KOYU mod karşılığıdır; renkleri [AuthColors] seçer.

  /// Zeminin en koyu tonu.
  static const Color loginBase = Color(0xFF0B1018);

  /// Zeminin üst katmanı / koyu kart.
  static const Color loginSurface = Color(0xFF141B26);

  /// Kart dolgusu (beyazın çok düşük opaklığı).
  static const Color loginGlass = Color(0x14FFFFFF);

  /// Kart kenarlığı.
  static const Color loginGlassBorder = Color(0x24FFFFFF);

  /// Koyu zemin üzerindeki ikincil metin.
  static const Color loginMuted = Color(0xFF97A3B6);

  /// Koyu zeminde kullanılacak kırmızı (~5:1 kontrast, WCAG AA).
  static const Color redOnDark = Color(0xFFF26D70);

  static const RadialGradient loginGlow = RadialGradient(
    center: Alignment(-0.9, 1.1),
    radius: 1.35,
    colors: <Color>[Color(0x40A4161A), Color(0x00A4161A)],
  );

  static const RadialGradient loginGlowSecondary = RadialGradient(
    center: Alignment(1.0, -0.85),
    radius: 1.1,
    colors: <Color>[Color(0x2EE5383B), Color(0x00E5383B)],
  );
}

/// Yazı aileleri — web ile aynı: başlıklar Montserrat, gövde Inter.
/// Fontlar uygulamaya gömülü (assets/fonts, SIL OFL 1.1).
class BrandFonts {
  static const String heading = 'Montserrat';
  static const String body = 'Inter';
}

/// Gömülü fontların lisanslarını [LicenseRegistry]'ye ekler (main()).
void registerBrandFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (String family, String file) in <(String, String)>[
      ('Montserrat', 'assets/fonts/OFL-Montserrat.txt'),
      ('Inter', 'assets/fonts/OFL-Inter.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(<String>[
        family,
      ], await rootBundle.loadString(file));
    }
  });
}

/// Ortak yuvarlaklık ve gölge değerleri (kartlar, modaller, hap etiketler).
/// Web: --rp-radius-sm 12 / --rp-radius 16 / --rp-radius-lg 22 / --rp-radius-xl 28.
class BrandShape {
  static const double smallRadius = 12;
  static const double controlRadius = 14;
  static const double cardRadius = 18;
  static const double largeRadius = 22;
  static const double sheetRadius = 28;
  static const double pillRadius = 999;

  /// --rp-shadow-sm + --rp-shadow: ince, katmanlı, slate tonlu.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// --rp-shadow-red: birincil eylemin altındaki sıcak gölge.
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x33E5383B), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

/// Sayfa geçişlerini anlık yapar.
///
/// Uygulama rotalarının verisi ayrı yüklendiği için Material'ın varsayılan
/// kaydırma/fade animasyonu, özellikle kısa ekranlarda "yavaş geçiyor" hissi
/// veriyordu. Bu yapı tüm platformlarda yalnızca yeni sayfayı çizer.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

const PageTransitionsTheme _instantPageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: _InstantPageTransitionsBuilder(),
    TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
    TargetPlatform.linux: _InstantPageTransitionsBuilder(),
    TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
    TargetPlatform.windows: _InstantPageTransitionsBuilder(),
    TargetPlatform.fuchsia: _InstantPageTransitionsBuilder(),
  },
);

/// Uygulama içi yüzey renkleri. Widget'lar sabit renk yazmak yerine bunları
/// okur; koyu mod böylece tek yerden yönetilir.
extension BrandSurfaces on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Kart / çubuk / modal zemini.
  Color get surface => isDarkMode ? BrandColors.darkSurface : BrandColors.white;

  /// Sayfa zemini.
  Color get canvas =>
      isDarkMode ? BrandColors.darkBase : BrandColors.grayLighter;

  /// Kart içindeki ikincil dolgu.
  Color get subtleFill =>
      isDarkMode ? BrandColors.darkSurfaceAlt : BrandColors.soft;

  /// Ayırıcı ve kenarlık.
  Color get hairline =>
      isDarkMode ? BrandColors.darkBorder : BrandColors.grayLight;

  /// Başlık / ana metin (--rp-ink).
  Color get ink => isDarkMode ? BrandColors.darkText : BrandColors.black;

  /// Gövde metni (--rp-text).
  Color get inkBody => isDarkMode ? BrandColors.darkBody : BrandColors.text;

  /// İkincil metin (--rp-muted).
  Color get inkMuted => isDarkMode ? BrandColors.darkMuted : BrandColors.muted;

  /// Marka kırmızısının o modda okunaklı tonu.
  Color get brandInk => isDarkMode ? BrandColors.redSoft : BrandColors.redDark;

  /// Kırmızının soluk dolgusu (çip, rozet zemini).
  Color get brandTint => isDarkMode
      ? BrandColors.red.withValues(alpha: 0.16)
      : BrandColors.redTint;

  /// Web kartı: ince slate kenarlık + yumuşak katmanlı gölge.
  BoxDecoration cardDecoration({double radius = BrandShape.cardRadius}) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: hairline),
        boxShadow: isDarkMode ? null : BrandShape.card,
      );

  /// Giriş öncesi ekranların (giriş, kayıt, şifre, Keşfet) paleti.
  AuthColors get authColors => isDarkMode ? AuthColors.dark : AuthColors.light;
}

/// Giriş öncesi ekranların renkleri.
///
/// Açık tema web'deki giriş sayfasıyla aynı: beyaz zemin, köşelerden yumuşak
/// kırmızı ışıma, beyaz kart, hap düğmeler. Koyu temada aynı düzen slate
/// koyu yüzeylerle çizilir.
@immutable
class AuthColors {
  const AuthColors({
    required this.isDark,
    required this.base,
    required this.card,
    required this.cardBorder,
    required this.field,
    required this.fieldBorder,
    required this.text,
    required this.body,
    required this.muted,
    required this.accent,
    required this.chip,
    required this.glow,
    required this.glowSecondary,
    required this.marqueeOpacity,
  });

  final bool isDark;
  final Color base;
  final Color card;
  final Color cardBorder;
  final Color field;
  final Color fieldBorder;
  final Color text;
  final Color body;
  final Color muted;

  /// Zemin üstündeki kırmızı vurgu (bağlantılar, simgeler).
  final Color accent;

  /// Üst çubuktaki hap düğmelerin dolgusu.
  final Color chip;
  final RadialGradient glow;
  final RadialGradient glowSecondary;

  /// Arkada akan yazının görünürlük çarpanı.
  final double marqueeOpacity;

  static const AuthColors light = AuthColors(
    isDark: false,
    base: BrandColors.white,
    card: BrandColors.white,
    cardBorder: BrandColors.grayLight,
    field: BrandColors.white,
    fieldBorder: BrandColors.grayLight,
    text: BrandColors.black,
    body: BrandColors.text,
    muted: BrandColors.muted,
    accent: BrandColors.redDark,
    chip: BrandColors.white,
    glow: RadialGradient(
      center: Alignment(-1.0, -1.05),
      radius: 1.1,
      colors: <Color>[Color(0x2EE5383B), Color(0x00E5383B)],
    ),
    glowSecondary: RadialGradient(
      center: Alignment(1.1, 0.9),
      radius: 1.0,
      colors: <Color>[Color(0x1FEF4444), Color(0x00EF4444)],
    ),
    marqueeOpacity: 0,
  );

  static const AuthColors dark = AuthColors(
    isDark: true,
    base: BrandColors.loginBase,
    card: BrandColors.darkSurface,
    cardBorder: BrandColors.darkBorder,
    field: BrandColors.darkSurfaceAlt,
    fieldBorder: BrandColors.darkBorder,
    text: BrandColors.darkText,
    body: BrandColors.darkBody,
    muted: BrandColors.loginMuted,
    accent: BrandColors.redOnDark,
    chip: Color(0x14FFFFFF),
    glow: BrandColors.loginGlow,
    glowSecondary: BrandColors.loginGlowSecondary,
    marqueeOpacity: 0.6,
  );
}

TextTheme _textTheme({
  required Color ink,
  required Color body,
  required Color muted,
}) {
  TextStyle head(
    double size,
    FontWeight weight,
    double height, [
    double spacing = -0.2,
  ]) => TextStyle(
    fontFamily: BrandFonts.heading,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: ink,
  );
  TextStyle text(
    double size,
    FontWeight weight,
    double height,
    Color color, [
    double spacing = 0,
  ]) => TextStyle(
    fontFamily: BrandFonts.body,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
  );

  return TextTheme(
    displayLarge: head(44, FontWeight.w800, 1.12, -0.8),
    displayMedium: head(36, FontWeight.w800, 1.14, -0.6),
    displaySmall: head(30, FontWeight.w800, 1.18, -0.5),
    headlineLarge: head(28, FontWeight.w800, 1.2, -0.4),
    headlineMedium: head(24, FontWeight.w700, 1.25, -0.3),
    headlineSmall: head(21, FontWeight.w700, 1.28, -0.2),
    titleLarge: head(19, FontWeight.w700, 1.3, -0.1),
    titleMedium: head(16.5, FontWeight.w700, 1.32, -0.1),
    // Liste satırı / küçük başlık: Montserrat küçük punto ve dar alanda
    // ağır duruyor; Inter'in yarı kalını daha okunaklı.
    titleSmall: text(14.5, FontWeight.w600, 1.4, ink),
    bodyLarge: text(16, FontWeight.w400, 1.55, body),
    bodyMedium: text(15, FontWeight.w400, 1.5, body),
    bodySmall: text(13, FontWeight.w400, 1.45, muted),
    labelLarge: text(15, FontWeight.w600, 1.25, ink),
    labelMedium: text(13, FontWeight.w600, 1.3, body),
    labelSmall: text(11.5, FontWeight.w600, 1.3, muted, 0.2),
  );
}

ThemeData buildRegipassTheme({Brightness brightness = Brightness.light}) {
  final bool dark = brightness == Brightness.dark;

  final Color surface = dark ? BrandColors.darkSurface : BrandColors.white;
  final Color onSurface = dark ? BrandColors.darkText : BrandColors.black;
  final Color body = dark ? BrandColors.darkBody : BrandColors.text;
  final Color canvas = dark ? BrandColors.darkBase : BrandColors.grayLighter;
  final Color border = dark ? BrandColors.darkBorder : BrandColors.grayLight;
  final Color soft = dark ? BrandColors.darkSurfaceAlt : BrandColors.soft;
  final Color muted = dark ? BrandColors.darkMuted : BrandColors.muted;
  final Color accent = dark ? BrandColors.redSoft : BrandColors.redDark;
  final Color tint = dark
      ? BrandColors.red.withValues(alpha: 0.16)
      : BrandColors.redTint;

  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.red,
    brightness: brightness,
    primary: BrandColors.red,
    onPrimary: BrandColors.white,
    primaryContainer: tint,
    onPrimaryContainer: accent,
    secondary: dark ? BrandColors.redSoft : BrandColors.redDark,
    onSecondary: BrandColors.white,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: muted,
    surfaceContainerLowest: surface,
    surfaceContainerLow: dark
        ? BrandColors.darkSurface
        : BrandColors.grayLighter,
    surfaceContainer: soft,
    surfaceContainerHigh: soft,
    surfaceContainerHighest: soft,
    outline: border,
    outlineVariant: border,
    error: dark ? BrandColors.dangerOnDark : BrandColors.redDark,
  );

  final TextTheme textTheme = _textTheme(
    ink: onSurface,
    body: body,
    muted: muted,
  );

  const TextStyle buttonText = TextStyle(
    fontFamily: BrandFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
  const StadiumBorder pill = StadiumBorder();
  const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 22,
    vertical: 12,
  );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: BrandFonts.body,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    dividerColor: border,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: _instantPageTransitions,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,

    appBarTheme: AppBarTheme(
      // ÇUBUK STİLİ NEDEN BURADA DA VAR: Flutter her karede ekranın üst ve alt
      // ortasındaki `AnnotatedRegion`'a bakıp sistem çubuğu stilini kendisi
      // bildiriyor (rendering/view.dart, `_updateSystemChrome`). AppBar böyle
      // bir bölge yaratıyor ve varsayılan stilinde gezinme çubuğu alanları boş
      // olduğu için, uygulamanın `SystemChrome.setSystemUIOverlayStyle` çağrısı
      // aynı karede eziliyordu — alt çubuk temanın rengi yerine sistemin
      // varsayılanında (siyah) kalıyordu. Bölgeye kendi stilimizi vererek
      // kural her ekranda aynı kalıyor (bkz. lib/app/system_ui.dart).
      systemOverlayStyle: systemBarsStyle(brightness: brightness),
      backgroundColor: surface,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: const Color(0x140F172A),
      centerTitle: false,
      titleSpacing: 16,
      iconTheme: IconThemeData(color: onSurface, size: 22),
      actionsIconTheme: IconThemeData(color: onSurface, size: 22),
      shape: Border(bottom: BorderSide(color: border.withValues(alpha: 0.7))),
      titleTextStyle: TextStyle(
        fontFamily: BrandFonts.heading,
        color: onSurface,
        fontSize: 17.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      toolbarTextStyle: textTheme.bodyMedium,
    ),

    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: const Color(0x140F172A),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      showDragHandle: false,
      dragHandleColor: border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BrandShape.sheetRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.largeRadius),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: const Color(0x290F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        side: BorderSide(color: border),
      ),
      textStyle: textTheme.bodyMedium?.copyWith(color: onSurface),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(surface),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            side: BorderSide(color: border),
          ),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrandColors.red,
        foregroundColor: BrandColors.white,
        disabledBackgroundColor: dark
            ? BrandColors.darkSurfaceAlt
            : BrandColors.soft,
        disabledForegroundColor: muted,
        // Önceki tema gibi tam genişlik: düzenler buna göre kurulmuş.
        minimumSize: const Size.fromHeight(50),
        padding: buttonPadding,
        shape: pill,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.red,
        foregroundColor: BrandColors.white,
        disabledBackgroundColor: soft,
        disabledForegroundColor: muted,
        minimumSize: const Size(64, 50),
        padding: buttonPadding,
        shape: pill,
        textStyle: buttonText,
        elevation: 0,
        shadowColor: const Color(0x33E5383B),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        backgroundColor: dark ? Colors.transparent : BrandColors.white,
        disabledForegroundColor: muted,
        minimumSize: const Size.fromHeight(50),
        padding: buttonPadding,
        side: BorderSide(color: border),
        shape: pill,
        textStyle: buttonText,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: pill,
        textStyle: buttonText.copyWith(fontSize: 14.5),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: onSurface,
        minimumSize: const Size(44, 44),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: body,
        selectedBackgroundColor: tint,
        selectedForegroundColor: accent,
        side: BorderSide(color: border),
        textStyle: buttonText.copyWith(fontSize: 14),
        minimumSize: const Size(0, 44),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BrandColors.red,
      foregroundColor: BrandColors.white,
      shape: StadiumBorder(),
      elevation: 2,
    ),

    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      constraints: const BoxConstraints(minHeight: 50),
      border: inputBorder(border),
      enabledBorder: inputBorder(border),
      disabledBorder: inputBorder(border.withValues(alpha: 0.6)),
      focusedBorder: inputBorder(BrandColors.red, 1.6),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error, 1.6),
      labelStyle: TextStyle(
        fontFamily: BrandFonts.body,
        color: muted,
        fontSize: 15,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (Set<WidgetState> states) => TextStyle(
          fontFamily: BrandFonts.body,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.focused)
              ? accent
              : (states.contains(WidgetState.error) ? scheme.error : muted),
        ),
      ),
      hintStyle: TextStyle(
        fontFamily: BrandFonts.body,
        color: muted.withValues(alpha: 0.85),
        fontSize: 15,
      ),
      helperStyle: TextStyle(
        fontFamily: BrandFonts.body,
        color: muted,
        fontSize: 12.5,
        height: 1.4,
      ),
      errorStyle: TextStyle(
        fontFamily: BrandFonts.body,
        color: scheme.error,
        fontSize: 12.5,
        height: 1.4,
      ),
      prefixIconColor: muted,
      suffixIconColor: muted,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: soft,
      selectedColor: tint,
      disabledColor: soft,
      checkmarkColor: accent,
      side: BorderSide(color: border.withValues(alpha: 0.6)),
      labelStyle: TextStyle(
        fontFamily: BrandFonts.body,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: body,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: BrandFonts.body,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: accent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: const StadiumBorder(),
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: BorderSide(color: muted, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? BrandColors.red : null,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? BrandColors.red : muted,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? BrandColors.white
            : (dark ? BrandColors.darkMuted : BrandColors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? BrandColors.red
            : (dark ? BrandColors.darkSurfaceAlt : BrandColors.grayLight),
      ),
      trackOutlineColor: const WidgetStatePropertyAll<Color>(
        Colors.transparent,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: BrandColors.red,
      linearTrackColor: soft,
      circularTrackColor: Colors.transparent,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: onSurface,
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      ),
    ),

    expansionTileTheme: ExpansionTileThemeData(
      iconColor: accent,
      collapsedIconColor: muted,
      textColor: onSurface,
      collapsedTextColor: onSurface,
      shape: const Border(),
      collapsedShape: const Border(),
    ),

    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? BrandColors.darkSurfaceAlt : BrandColors.black,
      contentTextStyle: const TextStyle(
        fontFamily: BrandFonts.body,
        color: BrandColors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      actionTextColor: BrandColors.redSoft,
      elevation: 4,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      ),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? BrandColors.darkSurfaceAlt : BrandColors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(
        fontFamily: BrandFonts.body,
        color: BrandColors.white,
        fontSize: 12.5,
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: accent,
      unselectedLabelColor: muted,
      indicatorColor: BrandColors.red,
      dividerColor: border,
      labelStyle: buttonText.copyWith(fontSize: 14),
      unselectedLabelStyle: buttonText.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: tint,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
        (Set<WidgetState> states) => TextStyle(
          fontFamily: BrandFonts.body,
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
        (Set<WidgetState> states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(
        fontFamily: BrandFonts.body,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: BrandFonts.body,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
    ),

    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: BrandColors.red,
      headerForegroundColor: BrandColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.largeRadius),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.largeRadius),
      ),
    ),
  );
}
