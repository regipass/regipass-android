/// Tüm metin alanlarının paylaştığı giriş koruması.
///
/// [sanitize.dart] kaydetme anında çalışır — yani zararlı metin controller'a
/// girer, ekranda görünür, ancak Firestore'a yazılmadan önce temizlenir. Bu
/// dosya bir adım öne geçip **yazım anında** eler: `<script>` yazmayı deneyen
/// kullanıcı karakterin ekrana geldiğini bile görmez, dolayısıyla o metin
/// hiçbir controller'da, hiçbir taslakta, hiçbir kayıtta bulunamaz.
///
/// İki katman birlikte çalışır (biri diğerinin yerini almaz):
///   1. Burası — yazarken/yapıştırırken eleme + uzunluk sınırı.
///   2. `sanitize.dart` — kaydetmeden hemen önceki son temizlik. Metin
///      alanına hiç uğramadan (derin bağlantı, kopyalanan taslak, ileride
///      eklenecek bir alan) gelen değerler için ağ hâlâ orada.
///
/// **Sayaç bilinçli olarak gösterilmiyor.** [TextField.maxLength] verildiğinde
/// Flutter alanın altına "12/80" sayacı çizer; bunun yerine sınır bir
/// biçimlendiriciyle ([BoundedLengthTextInputFormatter]) uygulanıyor. Sonuç
/// aynı — gereğinden uzun metin kabul edilmiyor — ama kullanıcı "kaç karakter
/// kaldı" muhasebesiyle uğraşmıyor.
library;

import 'package:flutter/services.dart';

/// Alan türlerine göre üst sınırlar.
///
/// Değerler `sanitize.dart`'ın kaydetme anındaki kırpma sınırlarının altında
/// tutuldu: alan zaten sınırı aştırmadığı için kaydederken sessizce kesilen
/// metin oluşmaz — kullanıcı ne yazdıysa o kaydedilir.
///
/// Sınırların amacı aşırı uzun girdinin (kopyalanmış bir kitap, üretilmiş
/// megabaytlık bir dize) belleği, Firestore belge boyutunu ve alt katmanları
/// zorlamasını engellemek; günlük kullanımda kimsenin çarpmayacağı kadar
/// geniş, kötüye kullanımda ise kesin duracak kadar dar seçildiler.
class InputLimits {
  const InputLimits._();

  /// Ad ve soyad. `sanitizeName` 100'de kırpar.
  static const int name = 50;

  /// E-posta — RFC 5321'in izin verdiği en uzun adres.
  static const int email = 254;

  /// Şifre. Firebase çok daha uzununa izin veriyor; buradaki sınır yalnızca
  /// saçma uzunlukta girdiyi keser. Mevcut şifresi bundan uzun olan kimsenin
  /// giriş yapamaz hâle gelmemesi için bilerek yüksek tutuldu.
  static const int password = 128;

  /// Öğrenci numarası. `sanitizeText` 30'da kırpar.
  static const int studentNumber = 20;

  /// Kısa tek satırlık serbest metin: kulüp adı, hedef kitle, konum adı.
  static const int shortText = 100;

  /// Etkinlik ve duyuru başlıkları.
  static const int title = 120;

  /// Arama kutuları — hiçbir yere yazılmaz, yalnızca filtreler.
  static const int search = 80;

  /// Bağlantı/dosya yolu kutuları. `sanitizeUrl` 500'de kırpar.
  static const int url = 500;

  /// Orta boy serbest metin: etkinlik amacı, yönetici düzeltme notu.
  static const int paragraph = 500;

  /// Yöneticinin kulübe gönderdiği not. Web'deki
  /// `MAX_CLUB_MESSAGE_LENGTH` ile aynı: iki istemci aynı diziye yazıyor,
  /// sınırın farklı olması kulübün gördüğü metni platforma göre değiştirirdi.
  static const int adminMessage = 1000;

  /// Uzun serbest metin: etkinlik açıklaması, kulüp amacı/içerikleri.
  /// `sanitizeLongText` 2000'de kırpar.
  static const int longText = 1500;

  /// Sayı kutuları — hepsi zaten yalnızca rakam kabul ediyor, buradaki sınır
  /// `int.tryParse` taşmasını ve anlamsız uzunlukta rakam dizisini keser.
  static const int money = 9;
  static const int quota = 6;
  static const int sessionCount = 3;
  static const int percent = 3;

  /// SMS doğrulama kodu.
  static const int verificationCode = 6;
}

/// Yazım anında XSS/script kalıplarını eleyen biçimlendirici.
///
/// Ne elenir:
///   * `<` ve `>` — her HTML/SVG etiketi bu iki karakterle başlar. İkisi de
///     hiç geçemeyince `<script>`, `<img onerror=...>`, `<iframe>` gibi
///     yükler daha kurulamadan dağılır.
///   * `javascript:`, `vbscript:`, `data:text/html` — etiket olmadan da
///     bağlantı alanlarında çalışabilen protokoller.
///   * Görünmez karakterler: kontrol karakterleri, sıfır genişlikli
///     birleştiriciler ve iki yönlü (bidi) yazım işaretleri. Bunlar ekranda
///     hiçbir iz bırakmadan metnin gerçek içeriğini değiştirebildikleri için
///     (ör. gösterilen ad ile kayıtlı ad farklı olur) baştan atılıyor.
///
/// `onclick=` gibi olay yakalayıcı kalıpları burada **elenmez**: bir etiketin
/// içine girmeden zararsızlar ve `<` zaten geçemiyor. Canlı elenselerdi
/// Türkçe'de "onay=" gibi masum yazımlar kullanıcının gözü önünde silinirdi.
/// Kaydetme anındaki `detectHarmfulInput`/`sanitizeText` o kalıbı yakalamaya
/// devam ediyor.
class SafeTextInputFormatter extends TextInputFormatter {
  const SafeTextInputFormatter({this.multiline = false});

  /// Çok satırlı alanlarda satır sonları korunur. Tek satırlıklarda —
  /// yapıştırılan çok satırlı metin alanı bozmasın diye — boşluğa çevrilir.
  final bool multiline;

  static final RegExp _markup = RegExp(r'[<>]');

  static final RegExp _scheme = RegExp(
    r'(javascript|vbscript)\s*:|data\s*:\s*text\s*/\s*html',
    caseSensitive: false,
  );

  /// Görünmez karakterler: C0/C1 kontrol karakterleri, sıfır genişlikli
  /// birleştiriciler ve bidi (iki yönlü yazım) yön işaretleri. Sekme, satır
  /// sonu ve satır başı burada sayılmaz — onlar aşağıda ayrıca ele alınıyor.
  ///
  /// Kod birimi aralıklarıyla yazıldı: aynı listeyi bir düzenli ifadeye
  /// gömmek, kaynakta gözle görülmeyen karakterler bırakır ve dosyayı
  /// düzenleyen bir sonraki kişi neyi elediğini okuyamaz.
  static bool _isInvisible(int unit) =>
      (unit < 0x20 && unit != 0x09 && unit != 0x0A && unit != 0x0D) ||
      (unit >= 0x7F && unit <= 0x9F) ||
      (unit >= 0x200B && unit <= 0x200F) ||
      (unit >= 0x202A && unit <= 0x202E) ||
      (unit >= 0x2060 && unit <= 0x2064) ||
      (unit >= 0x2066 && unit <= 0x2069) ||
      unit == 0xFEFF;

  String _clean(String value) {
    final String stripped = value
        .replaceAll(_scheme, '')
        .replaceAll(_markup, '');

    final StringBuffer out = StringBuffer();
    for (final int unit in stripped.codeUnits) {
      if (_isInvisible(unit)) continue;

      switch (unit) {
        // Sekme her zaman boşluğa iner: hizalama görevi yok, yalnızca
        // metnin içinde görünmez bir sıçrama bırakır.
        case 0x09:
          out.write(' ');
        // Satır başı (CR) tek başına hiçbir şey ifade etmez; çok satırlı
        // alanda CRLF'in LF'i zaten aşağıdaki dalda yazılıyor.
        case 0x0D:
          if (!multiline) out.write(' ');
        case 0x0A:
          out.write(multiline ? '\n' : ' ');
        default:
          out.writeCharCode(unit);
      }
    }

    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String cleaned = _clean(newValue.text);
    if (cleaned == newValue.text) return newValue;

    // İmleç, elenen karakter sayısı kadar geri alınır; yoksa metnin sonuna
    // sıçrar ve kullanıcı yazmaya kaldığı yerden devam edemez.
    final int removed = newValue.text.length - cleaned.length;
    final int offset = (newValue.selection.end - removed).clamp(
      0,
      cleaned.length,
    );

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}

/// Uzunluk sınırı — ama alana **dışarıdan** yüklenmiş uzun metni kesmeden.
///
/// Hazır [LengthLimitingTextInputFormatter] sınırı aşan her değeri kırpar.
/// Alanların çoğu var olan kaydı düzenlemek için de açılıyor ve o kayıtlar
/// webden gelmiş olabilir; web tarafındaki sınırlar burada uyguladığımızdan
/// gevşek. O hâlde 1800 karakterlik bir kulüp amacını düzenlemeye açan kulüp,
/// tek bir tuşa bastığı anda metnin son 300 karakterini kaybederdi — üstelik
/// hiçbir uyarı görmeden.
///
/// Bu yüzden iki durum ayrılıyor:
///   * Alan sınırın içindeyken — normal hâl — fazlası kırpılır. Yapıştırılan
///     uzun metin sınıra kadar alınır, gerisi düşer.
///   * Alan zaten sınırdan uzunken, metin yalnızca **kısalabilir**. Kullanıcı
///     silebilir, düzeltebilir; uzatan hiçbir düzenleme kabul edilmez. Böylece
///     eski kayıt ne bozulur ne de daha da şişer.
///
/// Sınırın içindeki normal hâlde kırpma işi Flutter'ın kendi
/// [LengthLimitingTextInputFormatter]'ına devrediliyor: sınır bir grafem
/// kümesinin (ör. emoji, birleşik harf) ortasına düşerse onu ikiye bölmüyor ve
/// imleci doğru yere koyuyor.
class BoundedLengthTextInputFormatter extends TextInputFormatter {
  const BoundedLengthTextInputFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxLength) return newValue;

    if (oldValue.text.length > maxLength) {
      return newValue.text.length < oldValue.text.length ? newValue : oldValue;
    }

    return LengthLimitingTextInputFormatter(
      maxLength,
    ).formatEditUpdate(oldValue, newValue);
  }
}

/// Metin alanlarının standart biçimlendirici listesi: önce zararlı kalıpları
/// ele, sonra uzunluğu sınırla.
///
/// Sıra önemli — eleme kırpmadan önce yapılır ki elenen karakterler sınırdan
/// yer çalmasın.
List<TextInputFormatter> guardedInput(
  int maxLength, {
  bool multiline = false,
}) => <TextInputFormatter>[
  SafeTextInputFormatter(multiline: multiline),
  BoundedLengthTextInputFormatter(maxLength),
];

/// Yalnızca uzunluk sınırı — içeriğe dokunulmaz.
///
/// Şifre alanları için: geçerli bir şifre `<`, `>` ya da `javascript:`
/// içerebilir. Şifreyi sessizce temizlemek kullanıcıyı kendi hesabından eder,
/// üstelik şifre metni hiçbir zaman bir belgeye yazılmadığı (Firebase'e
/// doğrulama için gidip orada karılıyor) için elemenin güvenlik faydası da
/// yok. Kalan tek gerçek risk aşırı uzunluk; sınırlanan da o.
List<TextInputFormatter> lengthOnlyInput(int maxLength) => <TextInputFormatter>[
  BoundedLengthTextInputFormatter(maxLength),
];

/// Yalnızca rakam kabul eden, uzunluğu sınırlı sayı kutuları için.
List<TextInputFormatter> digitsInput(int maxLength) => <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  BoundedLengthTextInputFormatter(maxLength),
];
