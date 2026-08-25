import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'marquee_content.dart';

/// Giriş ekranının arka planındaki çapraz akan yazı katmanı.
///
/// Sol alttan sağ üste doğru, birbirinden farklı hızlarda kayan satırlar.
/// Tasarım kararları:
///
///  * **Düşük kontrast.** Yazılar beyazın %6-9 opaklığında. Araştırmadaki
///    ortak uyarı: arka plandaki hareket formla yarışmamalı. Buradaki katman
///    ancak dikkatle bakınca okunur — dokular gibi hissedilir, içerik gibi
///    değil.
///  * **Aynı yön, farklı hız.** Satırlar zıt yönlere aksaydı ekran "makaslar"
///    ve göz sürekli yön değiştirmek zorunda kalırdı. Tek yön + hız farkı
///    sakin bir paralaks veriyor.
///  * **Çok yavaş.** En hızlı satır bile saniyede ~18 piksel; bir kelimenin
///    ekranı geçmesi yarım dakikadan uzun sürüyor.
///  * **Hareket azaltma desteği.** Cihazda "hareketi azalt" açıksa animasyon
///    hiç başlatılmaz, katman sabit durur. Vestibüler bozukluk, migren ve
///    ADHD için önemli; ayrıca düşük pilde/zayıf cihazda işlemciyi meşgul
///    etmez.
class DiagonalMarquee extends StatelessWidget {
  const DiagonalMarquee({super.key});

  /// Satırların eğimi. Negatif açı saat yönünün tersine döndürür; böylece
  /// satırların +x yönü ekranda sağ-yukarı doğru bakar.
  static const double _angleDegrees = -32;

  /// Satır tanımları: (yazı boyutu, opaklık, hız px/sn, kaydırma).
  ///
  /// Satır sayısı, döndürülmüş katmanın ekranı boşluksuz kaplamasına yetecek
  /// kadar (satırlar tüm yüksekliğe eşit dağıtılıyor).
  static const List<({double size, double opacity, double pps, double shift})>
      _rows = <({double opacity, double pps, double shift, double size})>[
    (size: 22, opacity: 0.09, pps: 18, shift: 0.0),
    (size: 17, opacity: 0.06, pps: 11, shift: 0.35),
    (size: 27, opacity: 0.08, pps: 15, shift: 0.7),
    (size: 15, opacity: 0.05, pps: 8, shift: 0.15),
    (size: 24, opacity: 0.07, pps: 13, shift: 0.55),
    (size: 19, opacity: 0.06, pps: 10, shift: 0.85),
    (size: 29, opacity: 0.05, pps: 16, shift: 0.25),
    (size: 16, opacity: 0.07, pps: 9, shift: 0.65),
    (size: 21, opacity: 0.06, pps: 12, shift: 0.45),
    (size: 26, opacity: 0.05, pps: 14, shift: 0.9),
    (size: 18, opacity: 0.08, pps: 10, shift: 0.05),
    (size: 23, opacity: 0.06, pps: 17, shift: 0.75),
  ];

  @override
  Widget build(BuildContext context) {
    // Cihaz "hareketi azalt" diyorsa satırlar sabit kalır.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Size screen = MediaQuery.sizeOf(context);

    // Döndürülmüş katmanın ekranı boşluksuz kaplaması için köşegenden büyük
    // bir alan gerekir; 1.5 kat her eğimde güvenli.
    final double extent = math.max(screen.width, screen.height) * 1.5;

    // İlk karede pencere boyutu 0x0 gelebiliyor (Android'de görüldü).
    // Sıfır genişlikte yerleşim yapmaya çalışmak yerine katmanı atlıyoruz;
    // boyut gelince yeniden çizilecek.
    if (extent <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      // Katman yalnızca dekoratif — dokunuşları alttaki forma geçirir ve
      // ekran okuyucular tarafından okunmaz.
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: ClipRect(
            child: OverflowBox(
              maxWidth: extent,
              maxHeight: extent,
              child: Transform.rotate(
                angle: _angleDegrees * math.pi / 180,
                // Satırlar tüm yüksekliğe eşit dağıtılır; aksi hâlde
                // döndürülmüş katman ekranın ortasında dar bir şerit olarak
                // kalır ve köşeler boş görünürdü.
                child: SizedBox(
                  width: extent,
                  height: extent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      for (int i = 0; i < _rows.length; i++)
                        _MarqueeRow(
                          seed: i,
                          fontSize: _rows[i].size,
                          opacity: _rows[i].opacity,
                          pixelsPerSecond: _rows[i].pps,
                          startShift: _rows[i].shift,
                          width: extent,
                          animate: !reduceMotion,
                        ),
                    ],
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

/// Tek bir kayan satır.
///
/// İçerik iki kez yan yana çizilir; kaydırma bir kopyanın genişliği kadar
/// ilerleyince başa döner — dikiş görünmez. Genişlik ilk kareden sonra
/// ölçülür, sonrasında ölçüm tekrarlanmaz.
class _MarqueeRow extends StatefulWidget {
  const _MarqueeRow({
    required this.seed,
    required this.fontSize,
    required this.opacity,
    required this.pixelsPerSecond,
    required this.startShift,
    required this.width,
    required this.animate,
  });

  final int seed;
  final double fontSize;
  final double opacity;
  final double pixelsPerSecond;

  /// 0..1 — satırın başlangıç konumu. Satırların aynı hizada başlamasını
  /// önler, aksi hâlde dikey bir "sütun" izlenimi oluşurdu.
  final double startShift;

  final double width;
  final bool animate;

  @override
  State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, value: widget.startShift);

  final GlobalKey _copyKey = GlobalKey();
  double _copyWidth = 0;
  late final List<String> _items = _buildItems(widget.seed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  @override
  void didUpdateWidget(_MarqueeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hareket azaltma ayarı çalışırken değişebilir.
    if (widget.animate != oldWidget.animate) _measureAndStart();
  }

  /// Bir kopyanın gerçek genişliğini ölçer ve süreyi hıza göre kurar.
  void _measureAndStart() {
    if (!mounted) return;

    final RenderBox? box =
        _copyKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    _copyWidth = box.size.width;
    if (_copyWidth <= 0) return;

    if (!widget.animate) {
      _controller.stop();
      setState(() {});
      return;
    }

    _controller
      ..duration = Duration(
        milliseconds:
            (_copyWidth / widget.pixelsPerSecond * 1000).round().clamp(1000, 600000),
      )
      ..repeat();

    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Kulüp adı, etkinlik adı ve emojiyi karıştırarak satır içeriği üretir.
  /// `seed` sabit olduğu için satırlar birbirinden farklı ama uygulama
  /// yeniden çizildiğinde aynı kalır — içeriğin zıplamasını önler.
  static List<String> _buildItems(int seed) {
    final math.Random random = math.Random(seed * 7919);
    final List<String> clubs = List<String>.of(kMarqueeClubs)..shuffle(random);
    final List<String> events = List<String>.of(kMarqueeEvents)..shuffle(random);
    final List<String> emojis = List<String>.of(kMarqueeEmojis)..shuffle(random);

    final List<String> items = <String>[];
    for (int i = 0; i < 7; i++) {
      items.add(clubs[i % clubs.length]);
      items.add(emojis[i % emojis.length]);
      items.add(events[i % events.length]);
      items.add(emojis[(i + 3) % emojis.length]);
    }
    return items;
  }

  Widget _buildCopy({Key? key}) {
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final String item in _items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              item,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: BrandColors.white.withValues(alpha: widget.opacity),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Satırın kendi sınırı: `Transform.translate` her karede çalışıyor ve
    // sınır olmadan 11 satırın metni birden yeniden rasterleniyordu — giriş
    // ekranındaki takılmanın kaynağı buydu. Sınırla birlikte metin bir kez
    // rasterlenip yalnızca kaydırılıyor.
    final Widget content = RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildCopy(key: _copyKey),
          _buildCopy(),
        ],
      ),
    );

    // İki kopyalık satır ekrandan çok daha geniş. OverflowBox olmadan Row
    // ebeveynin genişliğine sıkışır ve taşma hatası verir; burada doğal
    // genişliğinde yerleşmesine izin verip görünen kısmı kırpıyoruz.
    //
    // Yükseklik AÇIKÇA verilmeli: satır bir Column'un çocuğu ve Column ana
    // eksende sınırsız alan tanıyor. Yükseklik serbest bırakılırsa OverflowBox
    // kendini sonsuz boyutta konumlandırmaya çalışıp hata veriyor.
    Widget unbounded(Widget child) => SizedBox(
          width: widget.width,
          height: widget.fontSize * 1.7,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: child,
            ),
          ),
        );

    // Ölçüm tamamlanmadan kaydırma yapılamaz; ilk kare içerik yerinde çizilir.
    if (_copyWidth <= 0) return unbounded(content);

    return unbounded(
      AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          // İkinci kopya birinciyi tamamladığı için -width..0 aralığında
          // dönmek kesintisiz akış verir. Yön: sağa doğru (+x), döndürme
          // sonrası ekranda sağ-yukarı.
          final double dx = (_controller.value - 1) * _copyWidth;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: content,
      ),
    );
  }
}
