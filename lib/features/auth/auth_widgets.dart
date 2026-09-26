/// Giriş ve kayıt ekranlarının paylaştığı görsel parçalar.
///
/// İki ekran da aynı sahneyi kullanıyor (koyu zemin + çapraz akan yazı +
/// buzlu cam kart). Parçalar burada toplandı ki tasarım tek yerden
/// değiştirilebilsin.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../landing/diagonal_marquee.dart';
import '../shared/common_widgets.dart';

/// Koyu zemin + iki köşeden ışıma + çapraz akan yazı + okunabilirlik perdesi.
///
/// Katman sırası önemli: perde en üstte, çünkü akan yazıların form alanında
/// sönmesini o sağlıyor.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(color: BrandColors.loginSurface),
        ),
        DecoratedBox(
          decoration: BoxDecoration(gradient: BrandColors.loginGlow),
        ),
        DecoratedBox(
          decoration: BoxDecoration(gradient: BrandColors.loginGlowSecondary),
        ),
        DiagonalMarquee(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: <Color>[Color(0xCC0E1113), Color(0x330E1113)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Buzlu cam kart — arka plandaki hareketin form alanına sızmasını engeller.
class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            color: BrandColors.loginGlass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BrandColors.loginGlassBorder),
          ),
          child: child,
        ),
      ),
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
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
      style: const TextStyle(color: BrandColors.white, fontSize: 15.5),
      cursorColor: BrandColors.red,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: BrandColors.loginMuted, fontSize: 15),
        prefixIcon: Icon(icon, color: BrandColors.loginMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0x14FFFFFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: border(BrandColors.loginGlassBorder),
        enabledBorder: border(BrandColors.loginGlassBorder),
        disabledBorder: border(BrandColors.loginGlassBorder),
        focusedBorder: border(BrandColors.red, 1.5),
      ),
    );
  }
}

/// Birincil eylem düğmesi — ekrandaki tek parlak nokta.
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
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.red,
          foregroundColor: BrandColors.white,
          disabledBackgroundColor: BrandColors.red.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: loading ? null : onPressed,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
    return Row(
      children: <Widget>[
        const Expanded(
          child: Divider(color: BrandColors.loginGlassBorder, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: BrandColors.loginMuted,
              fontSize: 12.5,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: BrandColors.loginGlassBorder, height: 1),
        ),
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
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.white,
          disabledForegroundColor: BrandColors.loginMuted,
          backgroundColor: const Color(0x0FFFFFFF),
          side: borderless
              ? BorderSide.none
              : const BorderSide(color: BrandColors.loginGlassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: enabled ? onPressed : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            leading ?? Icon(icon, size: iconSize),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
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
    final Color accent = switch (tone) {
      FeedbackTone.success => const Color(0xFF4ADE80),
      FeedbackTone.error => const Color(0xFFFF6B6E),
      FeedbackTone.info => const Color(0xFF7DB3FF),
      FeedbackTone.warning => const Color(0xFFFFC870),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
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
              style: TextStyle(color: accent, fontSize: 13, height: 1.35),
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
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: BrandColors.white,
        disabledForegroundColor: BrandColors.loginMuted,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandShape.pillRadius),
        ),
        backgroundColor: const Color(0x14FFFFFF),
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
    final Color labelColor = accent ?? BrandColors.white;

    return PopupMenuButton<String>(
      tooltip: context.t('nav.languageSelectAria'),
      color: BrandColors.loginSurface,
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
                    color: code == language
                        ? BrandColors.red
                        : BrandColors.loginMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.t('language.$code'),
                    style: const TextStyle(color: BrandColors.white),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(BrandShape.pillRadius),
          border: Border.all(color: BrandColors.loginGlassBorder),
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
        color: BrandColors.redOnDark,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => Icon(
        Icons.language,
        size: widget.size,
        color: Color.lerp(
          BrandColors.redOnDark,
          BrandColors.white,
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
