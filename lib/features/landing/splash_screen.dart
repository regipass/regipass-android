import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../shared/common_widgets.dart';

/// Açılış ekranı — oturum durumu çözülene kadar gösterilir.
///
/// Zemin uygulamanın görünümünü izler: açık temada beyaz, koyu temada
/// [BrandColors.darkBase]. Aynı iki renk yerel (Android/iOS) açılış
/// perdesinde de tanımlı; böylece sistem perdesinden Flutter'ın ilk karesine
/// geçerken zemin hiç değişmiyor.
///
/// Animasyon bilerek "ucuz" tutuldu: ışımanın bulanıklık ve yayılma değerleri
/// sabit, nefes alma etkisi yalnızca hazır bulanıklaştırılmış katmanın
/// saydamlığından geliyor. Blur yarıçapını her karede değiştirmek gölgeyi her
/// karede yeniden çizdiriyordu; açılışta (Firebase + cihaz depoları
/// hazırlanırken) bu, kare atlamalarına ve yükleme çubuğunun takılmasına yol
/// açıyordu.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Logonun genişliği; yüksekliği görselin oranından gelir.
  static const double _markWidth = 210;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  /// 0.45 -> sönük, 1 -> parlak. Yumuşak bir nefes alma eğrisi.
  late final Animation<double> _glow = Tween<double>(begin: 0.45, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    // Marka kırmızısı koyu zeminde kontrastı düşük kalıyor; koyu temada
    // uygulamanın geri kalanıyla aynı ton (redOnDark) kullanılıyor.
    final Color barColor = dark ? BrandColors.redOnDark : BrandColors.red;

    return Scaffold(
      backgroundColor: dark ? BrandColors.darkBase : BrandColors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Neon: logonun arkasında iç içe iki halka. Yakın olan kırmızı ve
            // keskin, uzak olan marun ve yayvan — ikisi birlikte tek bir ışık
            // kaynağı izlenimi veriyor. Katman `RepaintBoundary` içinde bir kez
            // rasterleştirilir, sonra yalnızca saydamlığı değişir.
            Stack(
              alignment: Alignment.center,
              // Işıma logonun sınırlarının çok dışına taşıyor; `Stack`
              // varsayılanı (hardEdge) onu kare gibi keserdi.
              clipBehavior: Clip.none,
              children: <Widget>[
                FadeTransition(
                  opacity: _glow,
                  child: const RepaintBoundary(
                    child: _SplashGlow(width: _markWidth),
                  ),
                ),
                const BrandLogo(size: _markWidth),
              ],
            ),

            const SizedBox(height: 34),

            // İnce bir ilerleme ipucu: ışıma nefes alırken bu da uygulamanın
            // takılmadığını gösteriyor.
            _SplashProgressBar(
              color: barColor,
              trackColor: dark
                  ? BrandColors.white.withValues(alpha: 0.12)
                  : BrandColors.red.withValues(alpha: 0.14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logonun arkasındaki sabit ışıma katmanı.
///
/// Kendi başına hiçbir şey çizmez; yalnızca iki bulanık gölge bırakır. Kutusu
/// logonun kapladığı alanla aynı: ışık harflerin ardından geliyormuş gibi
/// görünüyor.
class _SplashGlow extends StatelessWidget {
  const _SplashGlow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: BrandLogo.heightFor(width),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Tam yuvarlak köşe: logo artık zeminsiz, ışığın kenarı da köşeli
          // durmasın.
          borderRadius: BorderRadius.circular(999),
          // Negatif yayılma: gölge logonun kutusunun içinde başlıyor, dışarı
          // yalnızca dağılan ışık sızıyor. Pozitif yayılmayla kutu bir çerçeve
          // gibi okunuyordu.
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: BrandColors.red.withValues(alpha: 0.55),
              blurRadius: 90,
              spreadRadius: -16,
            ),
            BoxShadow(
              color: BrandColors.maroon.withValues(alpha: 0.30),
              blurRadius: 170,
              spreadRadius: -8,
            ),
          ],
        ),
      ),
    );
  }
}

/// Akan yükleme çubuğu.
///
/// Material'ın `LinearProgressIndicator`'ı yerine elle yazıldı: burada her
/// karede yalnızca küçük bir dikdörtgen ötelenir (`Transform`), çubuğun
/// kendisi yeniden boyanmaz. Kenarları saydama giden gradyan sayesinde
/// başlangıç/bitiş kesik durmuyor ve akış kesintisiz okunuyor.
class _SplashProgressBar extends StatefulWidget {
  const _SplashProgressBar({required this.color, required this.trackColor});

  final Color color;
  final Color trackColor;

  @override
  State<_SplashProgressBar> createState() => _SplashProgressBarState();
}

class _SplashProgressBarState extends State<_SplashProgressBar>
    with SingleTickerProviderStateMixin {
  static const double _width = 108;
  static const double _height = 3;
  static const double _runnerWidth = 54;

  /// Sabit hızlı (eğrisiz) tekrar: uçlarda yavaşlayan bir eğri, çubuğun
  /// takıldığı izlenimini veriyordu.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BrandShape.pillRadius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: widget.trackColor),
              AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  // Tamamen solda (görünmez) konumdan tamamen sağda
                  // (görünmez) konuma doğrusal geçiş.
                  final double dx =
                      -_runnerWidth +
                      (_width + _runnerWidth) * _controller.value;

                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: _runnerWidth,
                    height: _height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            widget.color.withValues(alpha: 0),
                            widget.color,
                            widget.color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
