import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';

/// Web'deki `setFeedback(message, isError)` deseninin karşılığı.
/// `warning`: İP-K — ödeme bekleniyor, kontenjan dolu (bekleme listesi).
enum FeedbackTone { info, success, error, warning }

const Color _warningFg = BrandColors.warning;
const Color _warningBg = BrandColors.warningBg;
const Color _warningOnDark = Color(0xFFFFC870);
const Color _warningBgDark = Color(0x33F5A623);

/// Ton renkleri görünüme göre değişir: açık moddaki pastel zeminler koyu
/// yüzeyde göz alacak kadar parlak kalıyordu.
({Color bg, Color fg}) feedbackToneColors(
  BuildContext context,
  FeedbackTone tone,
) {
  if (context.isDarkMode) {
    return switch (tone) {
      FeedbackTone.success => (
        bg: BrandColors.successBgDark,
        fg: BrandColors.successOnDark,
      ),
      FeedbackTone.error => (
        bg: BrandColors.dangerBgDark,
        fg: BrandColors.dangerOnDark,
      ),
      FeedbackTone.info => (
        bg: BrandColors.infoBgDark,
        fg: BrandColors.infoOnDark,
      ),
      FeedbackTone.warning => (bg: _warningBgDark, fg: _warningOnDark),
    };
  }

  return switch (tone) {
    FeedbackTone.success => (
      bg: BrandColors.successBg,
      fg: BrandColors.success,
    ),
    FeedbackTone.error => (bg: BrandColors.dangerBg, fg: BrandColors.danger),
    FeedbackTone.info => (bg: BrandColors.infoBg, fg: BrandColors.info),
    FeedbackTone.warning => (bg: _warningBg, fg: _warningFg),
  };
}

/// Açılmış bir pencerenin ya da alt sayfanın ÜSTÜNDE beliren kısa bildirim.
///
/// [showTopFeedback] bir `MaterialBanner` çizer ve banner Scaffold'un
/// gövdesine yerleşir — yani üstünde açık bir pop-up/alt sayfa varsa perdenin
/// altında kalır ve hiç görünmez. "Kopyalandı" gibi geri bildirimlerin çoğu
/// tam da böyle bir pencerenin içinden tetikleniyor; bu yüzden bu bildirim
/// KÖK katmana (rootOverlay) çizilir ve her şeyin üstünde durur.
void showFloatingToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline,
  Duration duration = const Duration(milliseconds: 1800),
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  // Aynı anda iki bildirim üst üste binmesin: yenisi eskisini kaldırır.
  _activeToast?.remove();

  final ({Color bg, Color fg}) tones = feedbackToneColors(
    context,
    FeedbackTone.success,
  );

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext overlayContext) => Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.of(overlayContext).viewInsets.bottom + 48,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: tones.bg,
                borderRadius: BorderRadius.circular(BrandShape.pillRadius),
                boxShadow: BrandShape.card,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 18, color: tones.fg),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: tones.fg,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  _activeToast = entry;
  overlay.insert(entry);

  Timer(duration, () {
    if (_activeToast != entry) return;
    _activeToast = null;
    entry.remove();
  });
}

/// Ekrandaki tek bildirim. Kaldırılan bir `OverlayEntry` ikinci kez
/// kaldırılamaz, o yüzden zamanlayıcı da bu referansı kontrol eder.
OverlayEntry? _activeToast;

/// Ekranın ÜSTÜNDE, uygulama çubuğunun hemen altında beliren geçici uyarı.
///
/// Neden `SnackBar` değil: SnackBar her zaman ekranın altından çıkar ve
/// öğrenci kabuğundaki yüzen alt gezinme çubuğuna yapışık görünüyordu — hem
/// çubuğu örtüyor hem de kullanıcının gözünün olduğu yerin (formun) tam
/// tersinde kalıyordu. `MaterialBanner` ise Scaffold'un gövdesinin en üstüne,
/// AppBar'ın hemen altına yerleşir.
///
/// [duration] sonunda kendi kapanır; kullanıcı sağdaki çarpıyla erken de
/// kapatabilir.
void showTopFeedback(
  BuildContext context,
  String message, {
  FeedbackTone tone = FeedbackTone.error,
  Duration duration = const Duration(seconds: 4),
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ({Color bg, Color fg}) tones = feedbackToneColors(context, tone);
  final IconData icon = switch (tone) {
    FeedbackTone.success => Icons.check_circle_outline,
    FeedbackTone.error => Icons.error_outline,
    FeedbackTone.info => Icons.info_outline,
    FeedbackTone.warning => Icons.hourglass_top_outlined,
  };

  // Üst üste binen uyarılar sıraya girip birbirini bekletmesin: yenisi
  // eskisinin yerini alır.
  messenger.clearMaterialBanners();

  final ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>
  controller = messenger.showMaterialBanner(
    MaterialBanner(
      backgroundColor: tones.bg,
      dividerColor: Colors.transparent,
      elevation: 2,
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      leading: Icon(icon, size: 20, color: tones.fg),
      content: Text(
        message,
        style: TextStyle(color: tones.fg, fontSize: 13.5, height: 1.35),
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.close, size: 18, color: tones.fg),
          onPressed: messenger.hideCurrentMaterialBanner,
        ),
      ],
    ),
  );

  // Kendiliğinden kapanma. Kullanıcı önce kapatırsa `closed` tamamlanır ve
  // zamanlayıcı iptal edilir; aksi hâlde kapanmış bir denetleyici ikinci kez
  // kapatılmaya çalışılırdı.
  final Timer timer = Timer(duration, controller.close);
  unawaited(controller.closed.then((_) => timer.cancel()));
}

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    required this.message,
    this.tone = FeedbackTone.info,
    super.key,
  });

  final String? message;
  final FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final String? text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final ({Color bg, Color fg}) tones = feedbackToneColors(context, tone);
    final Color bg = tones.bg;
    final Color fg = tones.fg;
    final IconData icon = switch (tone) {
      FeedbackTone.success => Icons.check_circle_outline,
      FeedbackTone.error => Icons.error_outline,
      FeedbackTone.info => Icons.info_outline,
      FeedbackTone.warning => Icons.hourglass_top_outlined,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Düz marka sembolü — kırmızı zemin/rozet olmadan, kaynak logoyla birebir.
///
/// Sembol `assets/brand/regipass_mark.svg` — kelime logosundan ayıklanan tek
/// dolu yol. Kaynak logonun tamamı (`regipass_kirmizi.svg`) burada
/// kullanılamaz: içindeki `<filter>`/`feColorMatrix` zincirini flutter_svg
/// desteklemiyor. Tam logo için bkz. [BrandLogo].
///
/// Not: açılış ekranındaki (splash) rozetli/parlak sembol kasıtlı olarak
/// bunu kullanmıyor — `splash_screen.dart` içindeki `_SplashMark` bakınız.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 32, this.color = BrandColors.red, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/regipass_mark.svg',
      width: size * 0.857,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// Marka logosunun kendisi — kırmızı sembol + "Regipass" yazısı, zeminsiz.
///
/// `assets/brand/regipass_logo.svg`, kelime logosunun (`regipass_kirmizi.svg`)
/// düzleştirilmiş hâli: kaynaktaki `<filter>`/`feColorMatrix` zinciri
/// flutter_svg tarafından desteklenmediği için yazı, maskedeki harf yolları +
/// radyal gradyan olarak yeniden kuruldu (bkz. `tool/build_logo_full.py`).
///
/// Kaynaktaki siyah kare zemin alınmıyor: logo açık temada beyaz kartların,
/// koyu temada koyu gri zeminlerin üstünde duruyor; kare oralarda yamalı
/// görünüyordu. Görsel saydam ve içeriğine daraltılmış, yani logonun kapladığı
/// yer harflerin kendisi kadar.
///
/// [size] logonun GENİŞLİĞİdir; yükseklik [aspectRatio] ile hesaplanır.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.size = 120, super.key});

  /// Kaynak görselin en/boy oranı (viewBox: 1198.52 x 478).
  static const double aspectRatio = 1198.52 / 478;

  /// [size] genişliğindeki bir logonun yüksekliği.
  static double heightFor(double width) => width / aspectRatio;

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/regipass_logo.svg',
      width: size,
      height: heightFor(size),
    );
  }
}

/// Liste boşken gösterilen kart (web `.empty-state`).
class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // İlk satır başlık gibi okunur (web `.empty-state h3` + p).
    final int newline = message.indexOf('\n');
    final String title = newline < 0 ? message : message.substring(0, newline);
    final String? body = newline < 0 ? null : message.substring(newline + 1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: context.cardDecoration(),
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.inbox_outlined,
              size: 30,
              color: context.brandInk,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: body == null
                ? TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: context.inkBody,
                  )
                : Theme.of(context).textTheme.titleMedium,
          ),
          if (body != null && body.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.inkMuted,
                height: 1.55,
                fontSize: 14.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Durum etiketi (web `.status-pill` / `.scope-pill`).
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    this.tone = FeedbackTone.info,
    super.key,
  });

  final String label;
  final FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    // Nötr ton hap etiketlerde zemin rengiyle aynı aileden olmalı; banner'daki
    // mavi bilgi zemini burada fazla gürültü yapardı.
    final ({Color bg, Color fg}) tones = tone == FeedbackTone.info
        ? (bg: context.subtleFill, fg: context.inkBody)
        : feedbackToneColors(context, tone);

    final Color bg = tones.bg;
    final Color fg = tones.fg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
        border: Border.all(
          color: tone == FeedbackTone.info
              ? context.hairline.withValues(alpha: 0.7)
              : fg.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (tone != FeedbackTone.info) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etkinlik kapağı — adres boşsa ya da görsel yüklenemezse gri marka perdesi.
///
/// Kulüp etkinliğe görsel eklemediğinde kapak boş kalır ([isAutoCoverUrl]);
/// o durumda ağdan bir şey çekilmez, kartın içine soluk gri bir Regipass
/// logosu çizilir. Eskiden bu boşluk havuzdan rastgele bir doğa fotoğrafıyla
/// dolduruluyordu — etkinlikle ilgisi olmayan fotoğraflar kart listelerini
/// yanıltıyordu.
class EventImage extends StatelessWidget {
  const EventImage({required this.url, this.height = 160, super.key});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return EventCoverPlaceholder(height: height);

    // Eski etkinliklerde görsel belgeye base64 (`data:`) gömülüydü (İP-H ile
    // Storage'a taşınıyor; geçişte hâlâ görülebilir). `Image.network` bu adresleri
    // çözemediği için gömülü görselin baytları burada ayrıştırılır —
    // aksi hâlde yüklenen her görsel kartlarda kırık görünüyor.
    if (url.startsWith('data:')) {
      final Uint8List? bytes = _cachedDataUrlBytes(url);
      if (bytes == null) return EventCoverPlaceholder(height: height);

      return Image.memory(
        bytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, _, _) =>
            EventCoverPlaceholder(height: height),
      );
    }

    // İP-H: görsel diskte önbelleklenir (her açılışta yeniden inmez) ve
    // ekrandaki genişliğe göre küçültülerek çözülür (bellek + hız).
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
        final double w = constraints.maxWidth.isFinite ? constraints.maxWidth : 600;
        return CachedNetworkImage(
          imageUrl: url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          memCacheWidth: (w * dpr).round().clamp(200, 1600),
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (BuildContext context, String _) =>
              Container(height: height, color: context.subtleFill),
          errorWidget: (BuildContext context, String _, Object _) =>
              EventCoverPlaceholder(height: height),
        );
      },
    );
  }
}

/// Kapağı olmayan etkinliğin perdesi: gri zemin + soluk gri Regipass logosu.
///
/// Logo tek renge boyanır (kaynaktaki kırmızı ve gradyan burada göz alırdı);
/// zemin ile logo arasında yalnızca bir ton fark var, perde kartın bir
/// parçası gibi durur.
class EventCoverPlaceholder extends StatelessWidget {
  const EventCoverPlaceholder({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: context.subtleFill,
      alignment: Alignment.center,
      // Dikey pay yüksekliğe oranlı: aynı perde 62 px'lik satır görselinde de
      // 200 px'lik pencere kapağında da aynı görünsün.
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: height * 0.3),
      child: SvgPicture.asset(
        'assets/brand/regipass_logo.svg',
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(context.hairline, BlendMode.srcIn),
      ),
    );
  }
}

/// Kulübün logosu — yüklenmemişse marka gradyanlı grup simgesi.
///
/// Etkinliklerde ve kulüp hesabında aynı kutu kullanılır: logo her yerde aynı
/// köşe yarıçapıyla ve kırpılmadan (`contain`) görünür.
class ClubLogoBox extends StatelessWidget {
  const ClubLogoBox({
    required this.logoUrl,
    this.size = 40,
    this.radius = 12,
    this.fill = false,
    super.key,
  });

  final String logoUrl;
  final double size;
  final double radius;

  /// Görsel kutuyu boşluksuz doldursun mu?
  ///
  /// Listelerdeki küçük rozetlerde logonun tamamı görünsün diye kenarda pay
  /// bırakılır. Hesap ekranındaki büyük kutuda ise kullanıcı seçtiği
  /// fotoğrafın alana tam oturmasını bekler; orada taşan kısım kırpılır.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final BorderRadius corners = BorderRadius.circular(radius);

    if (logoUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: BrandColors.gradient,
          borderRadius: corners,
        ),
        child: Icon(
          Icons.groups_outlined,
          color: BrandColors.white,
          size: size * 0.52,
        ),
      );
    }

    // Logolar çoğunlukla saydam PNG: koyu temada kaybolmasın diye kutunun
    // zemini her zaman boyanır.
    final Widget image = CachedNetworkImage(
      imageUrl: logoUrl,
      fit: fill ? BoxFit.cover : BoxFit.contain,
      width: fill ? double.infinity : null,
      height: fill ? double.infinity : null,
      memCacheWidth: (size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2)).round().clamp(64, 1024),
      fadeInDuration: Duration.zero,
      errorWidget: (BuildContext context, String _, Object _) => Icon(
        Icons.groups_outlined,
        color: context.hairline,
        size: size * 0.52,
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: corners,
        border: Border.all(color: context.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: fill
          ? image
          : Padding(padding: EdgeInsets.all(size * 0.08), child: image),
    );
  }
}

/// Çözülmüş `data:` görsellerinin küçük önbelleği.
///
/// `Image.memory` görseli bayt dizisinin KİMLİĞİYLE tanır. Her çizimde
/// base64 yeniden çözülünce yeni bir dizi — dolayısıyla yeni bir görsel —
/// oluşuyor, sık yenilenen ekranlarda (kulüp etkinlik detayı gibi canlı
/// akışlar) kapak her karede yeniden çözülüp boş görünüyordu.
final Map<String, Uint8List> _dataUrlCache = <String, Uint8List>{};

Uint8List? _cachedDataUrlBytes(String url) {
  final Uint8List? hit = _dataUrlCache.remove(url);
  if (hit != null) {
    _dataUrlCache[url] = hit; // en son kullanılan sona
    return hit;
  }
  final Uint8List? bytes = _decodeDataUrl(url);
  if (bytes == null) return null;
  _dataUrlCache[url] = bytes;
  if (_dataUrlCache.length > 24) _dataUrlCache.remove(_dataUrlCache.keys.first);
  return bytes;
}

/// `data:image/jpeg;base64,...` adresinden baytları çıkarır.
///
/// Bozuk ya da base64 olmayan bir gövde geldiğinde null döner; çağıran taraf
/// yer tutucu gösterir.
Uint8List? _decodeDataUrl(String url) {
  final int comma = url.indexOf(',');
  if (comma < 0) return null;

  final String header = url.substring(0, comma);
  if (!header.contains('base64')) return null;

  try {
    return base64Decode(url.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// Tam ekran yükleniyor göstergesi.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: BrandColors.red));
}

/// Oturum sayısı kadar bölmesi olan ilerleme çubuğu.
///
/// Bölme sayısı oturum sayısına eşit olduğu için "kaçıncı oturumdayız"
/// bilgisi ayrıca yazılmaz; dolu bölmeler bunu zaten gösterir. Bölmeler çok
/// inceleşmesin diye 12'den fazla oturumda tek parça çubuğa düşülür.
class SessionProgressBar extends StatelessWidget {
  const SessionProgressBar({
    required this.total,
    required this.completed,
    this.done = false,
    this.height = 8,
    super.key,
  });

  /// Toplam oturum sayısı.
  final int total;

  /// Dolu gösterilecek bölme sayısı (aktif oturum dahil).
  final int completed;

  /// Tüm oturumlar tamamlandı mı — çubuk yeşile döner.
  final bool done;

  final double height;

  @override
  Widget build(BuildContext context) {
    final int slots = total < 1 ? 1 : total;
    final int filled = completed.clamp(0, slots);
    final Color fill = done ? BrandColors.success : BrandColors.red;
    final Color empty = context.isDarkMode
        ? BrandColors.darkSurfaceAlt
        : BrandColors.grayLight;

    if (slots > 12) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: filled / slots,
          minHeight: height,
          backgroundColor: empty,
          valueColor: AlwaysStoppedAnimation<Color>(fill),
        ),
      );
    }

    return Row(
      children: <Widget>[
        for (int index = 0; index < slots; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: height,
              decoration: BoxDecoration(
                color: index < filled ? fill : empty,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Sayfanın üstündeki başlık bloğu (web `.hero` → açık başlık alanı):
/// küçük kırmızı çizgi/üst başlık, Montserrat başlık ve soluk açıklama.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.center = false,
    this.padding = const EdgeInsets.fromLTRB(4, 4, 4, 18),
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final bool center;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final TextAlign align = center ? TextAlign.center : TextAlign.start;
    final CrossAxisAlignment cross = center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    final Widget column = Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (eyebrow != null && eyebrow!.isNotEmpty) ...<Widget>[
          Text(
            eyebrow!.toUpperCase(),
            textAlign: align,
            style: TextStyle(
              fontFamily: BrandFonts.heading,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: context.brandInk,
            ),
          ),
          const SizedBox(height: 8),
        ] else ...<Widget>[
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              gradient: BrandColors.gradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          textAlign: align,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: align,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: context.inkMuted,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: trailing == null
          ? SizedBox(width: double.infinity, child: column)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(child: column),
                const SizedBox(width: 12),
                trailing!,
              ],
            ),
    );
  }
}

/// Başlıklı bölüm kartı: solda tonlu simge kutusu, başlık + açıklama ve
/// altında içerik. Uzun yönetim ekranlarını (kulüp etkinlik detayı, form
/// bölümleri) nefes alan bloklara ayırır.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 18),
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: context.cardDecoration(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.brandTint,
                    borderRadius: BorderRadius.circular(BrandShape.smallRadius),
                  ),
                  child: Icon(icon, size: 20, color: context.brandInk),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: icon == null ? 0 : 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Kapak görselinin sol üstüne oturan tarih hapı (web `.event-date-pill`).
class EventDatePill extends StatelessWidget {
  const EventDatePill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.schedule_rounded, size: 14, color: context.brandInk),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
          ),
        ],
      ),
    );
  }
}
