/// Giriş ve kayıt ekranlarının paylaştığı görsel parçalar.
///
/// İki ekran da aynı sahneyi kullanıyor (koyu zemin + çapraz akan yazı +
/// buzlu cam kart). Parçalar burada toplandı ki tasarım tek yerden
/// değiştirilebilsin.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../landing/diagonal_marquee.dart';
import '../shared/common_widgets.dart';

/// Giriş öncesi ekranların zemini.
///
/// Açık temada web'deki giriş sayfasıyla aynı: beyaz zemin, köşelerden
/// yumuşak kırmızı ışıma. Koyu temada slate koyu zemin + hafif ışıma +
/// çapraz akan soluk yazı ve okunabilirlik perdesi.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthColors ac = context.authColors;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(decoration: BoxDecoration(color: ac.base)),
        DecoratedBox(decoration: BoxDecoration(gradient: ac.glow)),
        DecoratedBox(decoration: BoxDecoration(gradient: ac.glowSecondary)),
        if (ac.isDark) ...<Widget>[
          const DiagonalMarquee(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: <Color>[
                  ac.base.withValues(alpha: 0.85),
                  ac.base.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Form kartı (web `.auth-card`): açık temada beyaz, ince slate kenarlık ve
/// yumuşak katmanlı gölge; koyu temada koyu yüzey.
class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AuthColors ac = context.authColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(BrandShape.largeRadius),
        border: Border.all(color: ac.cardBorder),
        boxShadow: ac.isDark
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 32,
                  offset: Offset(0, 16),
                ),
              ]
            : const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Marka logosu — zeminsiz kaynak görselin kendisi ([BrandLogo]).
class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({this.compact = false, super.key});

  /// Kayıt ekranı gibi içeriği yoğun sayfalarda daha küçük çizilir.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BrandLogo(size: compact ? 150 : 190);
  }
}

/// Koyu zemine uygun metin alanı.
class AuthField extends StatelessWidget {
  const AuthField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.enabled,
    this.focusNode,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.suffix,
    this.inputFormatters,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  /// Uzunluk sınırı ve zararlı kalıp elemesi (bkz. core/input_guard.dart).
  /// Her çağrı yerinde açıkça verilir: e-posta kutusu temizlenir, şifre
  /// kutusu yalnızca uzunlukla sınırlanır.
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final AuthColors ac = context.authColors;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: TextStyle(color: ac.text, fontSize: 15.5),
      cursorColor: BrandColors.red,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: ac.muted, fontSize: 15),
        prefixIcon: Icon(icon, color: ac.muted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: ac.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: border(ac.fieldBorder),
        enabledBorder: border(ac.fieldBorder),
        disabledBorder: border(ac.fieldBorder),
        focusedBorder: border(BrandColors.red, 1.6),
      ),
    );
  }
}

/// Birincil eylem düğmesi — web'deki gradyanlı hap düğme (--rp-grad).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !loading && onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.55,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: BrandColors.gradient,
              borderRadius: BorderRadius.circular(BrandShape.pillRadius),
              boxShadow: enabled ? BrandShape.raised : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(BrandShape.pillRadius),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: BrandColors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: BrandColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AuthColors ac = context.authColors;
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: ac.cardBorder, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: ac.muted, fontSize: 13)),
        ),
        Expanded(child: Divider(color: ac.cardBorder, height: 1)),
      ],
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.iconSize = 22,
    this.leading,
    this.borderless = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final double iconSize;
  final Widget? leading;
  final bool enabled;
  final VoidCallback onPressed;

  /// Kenarlığı dışarıdan bir sarmalayıcı (ör. GlowingBorder) çiziyorsa true.
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    final AuthColors ac = context.authColors;
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: ac.text,
          disabledForegroundColor: ac.muted,
          backgroundColor: ac.isDark ? const Color(0x0FFFFFFF) : ac.card,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: borderless ? BorderSide.none : BorderSide(color: ac.cardBorder),
          shape: const StadiumBorder(),
        ),
        onPressed: enabled ? onPressed : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            leading ?? Icon(icon, size: iconSize),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google'ın dört renkli G işareti; Material Icons'taki tek renkli
/// `g_mobiledata` simgesinin yerine kullanılır.
class GoogleMark extends StatelessWidget {
  const GoogleMark({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/google_g.svg',
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
}

/// Koyu zeminde hata/bilgi şeridi.
class AuthFeedback extends StatelessWidget {
  const AuthFeedback({required this.message, required this.tone, super.key});

  final String message;
  final FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final Color accent = feedbackToneColors(context, tone).fg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: context.isDarkMode ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(BrandShape.smallRadius),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            tone == FeedbackTone.error
                ? Icons.error_outline
                : Icons.info_outline,
            size: 17,
            color: accent,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: accent, fontSize: 13.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Koyu zemine uygun, çerçevesiz üst çubuk düğmesi.
class AuthGhostButton extends StatelessWidget {
  const AuthGhostButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AuthColors ac = context.authColors;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: ac.text,
        disabledForegroundColor: ac.muted,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: StadiumBorder(side: BorderSide(color: ac.cardBorder)),
        backgroundColor: ac.chip,
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Koyu zemine uygun dil değiştirici. Giriş, kayıt ve Keşfet ekranları kullanır.
///
/// [accent] verilirse etiket o renkte çizilir (Keşfet'te kırmızı).
/// [animatedGlobe] true ise dünya simgesi kırmızı ile beyaz arasında nabız
/// gibi gidip gelir — yalnızca Keşfet'te açık, giriş ekranı sade kalsın diye.
class LanguageToggleDark extends ConsumerWidget {
  const LanguageToggleDark({
    this.accent,
    this.animatedGlobe = false,
    super.key,
  });

  final Color? accent;
  final bool animatedGlobe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String language = ref.watch(languageProvider);
    final AuthColors ac = context.authColors;
    final Color labelColor = accent ?? ac.text;

    return PopupMenuButton<String>(
      tooltip: context.t('nav.languageSelectAria'),
      color: ac.card,
      onSelected: (String value) =>
          ref.read(languageProvider.notifier).setLanguage(value),
      itemBuilder: (BuildContext context) => kSupportedLanguages
          .map(
            (String code) => PopupMenuItem<String>(
              value: code,
              child: Row(
                children: <Widget>[
                  Icon(
                    code == language ? Icons.check : Icons.language,
                    size: 16,
                    color: code == language ? BrandColors.red : ac.muted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.t('language.$code'),
                    style: TextStyle(color: ac.text),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ac.chip,
          borderRadius: BorderRadius.circular(BrandShape.pillRadius),
          border: Border.all(color: ac.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (animatedGlobe)
              const _PulsingGlobe(size: 16)
            else
              Icon(Icons.language, size: 16, color: labelColor),
            const SizedBox(width: 6),
            Text(
              language.toUpperCase(),
              style: TextStyle(
                color: labelColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kırmızıdan beyaza kısa bir parıltı geçiren dünya simgesi.
///
/// Zamanlama web'deki `glitterSweep` ile birebir aynı (css/lang.css):
/// 3.6 saniyelik döngü, parıltı ilk %20'de yükselir, %45'te söner, kalan
/// süre boyunca simge kırmızı kalır. Sürekli gidip gelen bir nabız değil —
/// arada bir parlayıp geçen bir ışıltı; bu yüzden göze çarpmadan fark edilir.
///
/// Cihazda "hareketi azalt" açıksa animasyon çalışmaz, simge kırmızıda kalır.
class _PulsingGlobe extends StatefulWidget {
  const _PulsingGlobe({required this.size});

  final double size;

  @override
  State<_PulsingGlobe> createState() => _PulsingGlobeState();
}

class _PulsingGlobeState extends State<_PulsingGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // css/lang.css: animation: glitterSweep 3.6s linear infinite;
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// glitterSweep opaklık eğrisi: 0% -> 0, 20% -> 0.95, 45% -> 0, 100% -> 0.
  static double _glint(double t) {
    if (t < 0.20) return t / 0.20 * 0.95;
    if (t < 0.45) return 0.95 * (1 - (t - 0.20) / 0.25);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Icon(
        Icons.language,
        size: widget.size,
        color: context.authColors.accent,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => Icon(
        Icons.language,
        size: widget.size,
        color: Color.lerp(
          context.authColors.accent,
          context.authColors.isDark ? BrandColors.white : BrandColors.redBright,
          _glint(_controller.value),
        ),
      ),
    );
  }
}

/// Sabit yerleşim kabuğu: normalde kaydırma yok, yalnızca klavye açılıp
/// içerik sığmadığında kaydırmaya izin verilir — küçük ekranlarda taşma
/// hatası yerine kullanılabilir bir form kalır.
class AuthFixedBody extends StatelessWidget {
  const AuthFixedBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    // Klavye payı kaydırma görünümünün İÇİNE değil, DIŞINA veriliyor: böylece
    // görünür alan gerçekten klavyenin üstünde biten bir pencere olur.
    // Payı içeriye (padding) vermek yalnızca boşluk ekliyordu; pencere hâlâ
    // klavyenin altına uzandığı için Flutter odaktaki alanı "zaten görünüyor"
    // sayıyor ve telefon alanı klavyenin altında kalıyordu.
    //
    // Pay yalnızca klavye yüksekliği değiştiğinde oynar; klavye kapalıyken
    // düzen tam olarak eskisi gibi ortalanır.
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: child,
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
