import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Çevresinde dönen ışık olan çerçeve.
///
/// Web'deki `glitterSweep` efekti butonun **yüzeyinden** geçen bir parıltıydı;
/// buradaki ise kenar boyunca **dolanan** bir ışık yayı — asıl istenen bu.
///
/// Çizim tek bir `SweepGradient` ile yapılır: gradyanın büyük kısmı saydam,
/// dar bir dilimi parlak. Gradyan döndürüldükçe parlak dilim kenarda dolaşıyor
/// gibi görünür. Bu, kenar boyunca hareket eden ayrı bir nesne çizmekten çok
/// daha ucuz — her karede yalnızca iki `drawRRect` çağrısı var.
class GlowingBorder extends StatefulWidget {
  const GlowingBorder({
    required this.child,
    this.radius = 14,
    this.color = BrandColors.red,
    this.strokeWidth = 1.6,
    this.duration = const Duration(milliseconds: 2600),
    super.key,
  });

  final Widget child;
  final double radius;
  final Color color;
  final double strokeWidth;
  final Duration duration;

  @override
  State<GlowingBorder> createState() => _GlowingBorderState();
}

class _GlowingBorderState extends State<GlowingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Cihazda "hareketi azalt" açıksa ışık dolaşmaz; yerine sabit, soluk bir
    // kenarlık kalır. Giriş ekranındaki akan yazı katmanıyla aynı kural.
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

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => CustomPaint(
        painter: _GlowPainter(
          progress: _controller.value,
          radius: widget.radius,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
          // Hareket kapalıyken tek renkli sakin bir kenarlık çizilir.
          static: reduceMotion,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.progress,
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.static,
  });

  final double progress;
  final double radius;
  final Color color;
  final double strokeWidth;
  final bool static;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );

    if (static) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color.withValues(alpha: 0.2),
      );
      return;
    }

    // Parlak dilim gradyanın yaklaşık %18'lik bölümünü kaplar; gerisi saydam.
    // Kenarlarda yumuşak geçiş olması için opaklık kademeli iniyor.
    final SweepGradient gradient = SweepGradient(
      colors: <Color>[
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.275),
        BrandColors.white.withValues(alpha: 0.475),
        color.withValues(alpha: 0.275),
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.0),
      ],
      stops: const <double>[0.0, 0.62, 0.74, 0.80, 0.86, 0.98, 1.0],
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final Shader shader = gradient.createShader(rect);

    // Önce yumuşak dış ışıma, sonra keskin çizgi — ikisi üst üste gelince
    // ışık "yayılıyor" hissi veriyor.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 3.2
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..shader = shader,
    );

    // Dolanan ışığın altında sürekli görünen soluk bir taban kenarlık:
    // ışık uzaktayken buton kenarsız görünmesin.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = BrandColors.loginGlassBorder,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.static != static ||
      oldDelegate.color != color;
}
