import 'package:flutter/material.dart';

/// css/theme.css içindeki tasarım token'larının Flutter karşılığı.
/// Renk isimleri web ile aynı tutuldu ki iki taraf birlikte güncellenebilsin.
class BrandColors {
  static const Color red = Color(0xFFE5383B);
  static const Color redDark = Color(0xFFBA181B);
  static const Color maroon = Color(0xFFA4161A);
  static const Color black = Color(0xFF161A1D);
  static const Color blackDeep = Color(0xFF161214);
  static const Color grayLight = Color(0xFFD3D3D3);
  static const Color grayLighter = Color(0xFFF5F3F4);
  static const Color white = Color(0xFFFFFFFF);

  /// Marka gradyanı: `linear-gradient(135deg, red, redDark)`.
  /// 135deg CSS'te sol-üstten sağ-alta akar.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[red, redDark],
  );

  /// Dil düğmesi / vurgulu yüzeylerdeki üç duraklı gradyan.
  static const LinearGradient gradientRich = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[red, redDark, maroon],
    stops: <double>[0.0, 0.48, 1.0],
  );

  /// Açık kırmızı — seçili segment düğmeleri gibi, marka kırmızısının
  /// tam yoğunluğunun ağır kalacağı yerlerde kullanılır.
  static const Color redSoft = Color(0xFFF0686C);

  /// Kırmızının en açık dolgusu (seçilmemiş segment zemini).
  static const Color redTint = Color(0xFFFDECED);

  static const Color success = Color(0xFF15803D);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color danger = redDark;
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color muted = Color(0xFF6B7280);

  // ── Koyu mod yüzeyleri ──────────────────────────────────────────────
  // Uygulama içi (giriş sonrası) ekranların koyu karşılıkları. Giriş ekranı
  // kendi ayrı koyu paletini kullanmaya devam eder (aşağıdaki login* token'lar).

  /// Sayfa zemini.
  static const Color darkBase = Color(0xFF101316);

  /// Kart, üst çubuk, alt çubuk, modal zemini.
  static const Color darkSurface = Color(0xFF191D22);

  /// Kart içindeki ikincil dolgu (bilgi bloğu, hap etiket zemini).
  static const Color darkSurfaceAlt = Color(0xFF232931);

  /// Ayırıcı ve kenarlık.
  static const Color darkBorder = Color(0xFF333A43);

  /// Ana metin.
  static const Color darkText = Color(0xFFECEFF3);

  /// İkincil metin.
  static const Color darkMuted = Color(0xFF98A1AB);

  // Geri bildirim tonlarının koyu modda okunabilir karşılıkları: açık
  // moddaki pastel zeminler koyu yüzeyde göz alıyor.
  static const Color successBgDark = Color(0xFF16351F);
  static const Color successOnDark = Color(0xFF6EE7A0);
  static const Color dangerBgDark = Color(0xFF3A1618);
  static const Color dangerOnDark = Color(0xFFFF8A8F);
  static const Color infoBgDark = Color(0xFF15243F);
  static const Color infoOnDark = Color(0xFF8AB4FF);

  // ── Giriş ekranı (koyu yüzey) ───────────────────────────────────────
  // Giriş ekranı uygulamanın geri kalanından ayrı bir renk dünyası
  // kullanır: koyu zemin sayesinde tek parlak nokta kırmızı CTA olur ve
  // göz oraya kilitlenir. Açık zeminde aynı etki için CTA'yı büyütmek
  // gerekirdi, bu da arka plandaki hareketle yarışırdı.

  /// Zeminin en koyu tonu (marka siyahından bir tık daha derin).
  static const Color loginBase = Color(0xFF0E1113);

  /// Zeminin üst katmanı — radyal ışımanın oturduğu ton.
  static const Color loginSurface = Color(0xFF161A1D);

  /// Buzlu cam kartın dolgusu (beyazın çok düşük opaklığı).
  static const Color loginGlass = Color(0x14FFFFFF);

  /// Buzlu cam kartın kenarlığı.
  static const Color loginGlassBorder = Color(0x24FFFFFF);

  /// Koyu zemin üzerindeki ikincil metin.
  static const Color loginMuted = Color(0xFF8A9199);

  /// Koyu zeminde kullanılacak kırmızı.
  ///
  /// Marka kırmızısı (#E5383B) koyu zeminde kontrastı düşük kalıp yorucu
  /// oluyor. Bu ton koyu yüzeyde ~5:1 kontrast veriyor (WCAG AA metin eşiği
  /// 4.5:1) ve düz kırmızıya göre daha karakterli duruyor. Keşfet ekranındaki
  /// metinler, vurgular ve dünya simgesi bunu kullanır.
  static const Color redOnDark = Color(0xFFEE4466);

  /// Köşelerden yayılan marun→kırmızı ışıma. Ekranın tamamını boyamaz;
  /// yalnızca kenarlarda hafif bir sıcaklık bırakır.
  static const RadialGradient loginGlow = RadialGradient(
    center: Alignment(-0.9, 1.1),
    radius: 1.35,
    colors: <Color>[Color(0x59A4161A), Color(0x00A4161A)],
  );

  static const RadialGradient loginGlowSecondary = RadialGradient(
    center: Alignment(1.0, -0.85),
    radius: 1.1,
    colors: <Color>[Color(0x3DE5383B), Color(0x00E5383B)],
  );
}

/// Ortak yuvarlaklık ve gölge değerleri (kartlar, modaller, hap etiketler).
class BrandShape {
  static const double cardRadius = 16;
  static const double controlRadius = 12;
  static const double pillRadius = 999;

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x2EBA181B), blurRadius: 24, offset: Offset(0, 10)),
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
///
/// Giriş/Keşfet ekranları bu erişimcileri kullanmaz — onlar her iki modda da
/// kendi sabit koyu paletinde kalır (bkz. `BrandColors.login*`).
extension BrandSurfaces on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Kart / çubuk / modal zemini.
  Color get surface => isDarkMode ? BrandColors.darkSurface : BrandColors.white;

  /// Sayfa zemini.
  Color get canvas =>
      isDarkMode ? BrandColors.darkBase : BrandColors.grayLighter;

  /// Kart içindeki ikincil dolgu.
  Color get subtleFill =>
      isDarkMode ? BrandColors.darkSurfaceAlt : BrandColors.grayLighter;

  /// Ayırıcı ve kenarlık.
  Color get hairline =>
      isDarkMode ? BrandColors.darkBorder : BrandColors.grayLight;

  /// Ana metin.
  Color get ink => isDarkMode ? BrandColors.darkText : BrandColors.black;

  /// İkincil metin.
  Color get inkMuted => isDarkMode ? BrandColors.darkMuted : BrandColors.muted;

  /// Marka kırmızısının o modda okunaklı tonu.
  Color get brandInk => isDarkMode ? BrandColors.redSoft : BrandColors.redDark;
}

ThemeData buildRegipassTheme({Brightness brightness = Brightness.light}) {
  final bool dark = brightness == Brightness.dark;

  final Color surface = dark ? BrandColors.darkSurface : BrandColors.white;
  final Color onSurface = dark ? BrandColors.darkText : BrandColors.black;
  final Color canvas = dark ? BrandColors.darkBase : BrandColors.grayLighter;
  final Color border = dark ? BrandColors.darkBorder : BrandColors.grayLight;
  final Color muted = dark ? BrandColors.darkMuted : BrandColors.muted;
  final Color accent = dark ? BrandColors.redSoft : BrandColors.redDark;

  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.red,
    brightness: brightness,
    primary: BrandColors.red,
    onPrimary: BrandColors.white,
    secondary: BrandColors.maroon,
    surface: surface,
    onSurface: onSurface,
    error: dark ? BrandColors.dangerOnDark : BrandColors.redDark,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    pageTransitionsTheme: _instantPageTransitions,

    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
    dialogTheme: DialogThemeData(backgroundColor: surface),
    popupMenuTheme: PopupMenuThemeData(color: surface),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrandColors.red,
        foregroundColor: BrandColors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),

    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        borderSide: const BorderSide(color: BrandColors.red, width: 1.6),
      ),
      labelStyle: TextStyle(color: muted),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: dark
          ? BrandColors.darkSurfaceAlt
          : BrandColors.grayLighter,
      side: BorderSide.none,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      ),
    ),

    dividerTheme: DividerThemeData(color: border, thickness: 1),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: BrandColors.red.withValues(alpha: 0.12),
      elevation: 3,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
        (Set<WidgetState> states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
        (Set<WidgetState> states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
    ),

    textTheme: TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
      bodyMedium: TextStyle(color: onSurface),
      bodySmall: TextStyle(color: muted),
    ),
  );
}
