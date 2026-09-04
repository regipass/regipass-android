/// Doğrulama SMS'i gönderilmeden önceki **numara ön kontrolü**.
///
/// Firebase'e `verifyPhoneNumber` çağrısı yapmadan önce numaranın yapısal
/// olarak o ülkenin cep numarası olduğundan emin oluruz:
///
/// 1. numara E.164 mü ve bilinen bir ülke koduyla başlıyor mu,
/// 2. hane sayısı o ülkenin aralığında mı ([CountryCode.min]..[CountryCode.max]),
/// 3. ulusal numara o ülkenin cep operatörü ön eklerinden biriyle başlıyor mu
///    (bkz. data/mobile_prefixes.dart).
///
/// Sahiplik ("bu numara başka bir hesaba mı ait") sorgusu burada değil:
/// o Firestore'a gider, bu dosya saf mantıktır. İkisini birlikte çalıştıran
/// sarmalayıcı: `features/shared/phone_guard.dart`.
library;

import '../data/country_codes.dart';
import '../data/mobile_prefixes.dart';

final RegExp _nonDigit = RegExp(r'\D');

/// Uzun arama kodları önce denenir; aksi hâlde kısa kod uzun olanı gölgeler
/// (ör. "+1" varken "+1242" hiç denenmezdi).
///
/// Eşit uzunluktaki kodlar veri dosyasındaki sıralarını korur: `List.sort`
/// kararlı değildir ve aynı kodu paylaşan ülkelerde (NANP'nin tamamı "+1")
/// hangi ülkenin döneceği çalışmadan çalışmaya değişirdi.
final List<CountryCode> _byDialDesc = _sortedByDialLength();

List<CountryCode> _sortedByDialLength() {
  final List<int> order = List<int>.generate(kCountryCodes.length, (int i) => i)
    ..sort((int a, int b) {
      final int byLength = kCountryCodes[b].dial.length.compareTo(
        kCountryCodes[a].dial.length,
      );
      return byLength != 0 ? byLength : a.compareTo(b);
    });

  return List<CountryCode>.unmodifiable(
    order.map((int i) => kCountryCodes[i]),
  );
}

/// E.164 numaranın ülkesini bulur; numara "+" ile başlamıyorsa ya da hiçbir
/// arama koduna oturmuyorsa `null`.
CountryCode? countryForE164(String? e164) {
  final String value = (e164 ?? '').trim();
  if (!value.startsWith('+')) return null;

  for (final CountryCode c in _byDialDesc) {
    if (value.startsWith(c.dial)) return c;
  }
  return null;
}

/// Ön kontrolün takıldığı basamak.
enum PhoneNumberIssue {
  /// E.164 değil ya da bilinen hiçbir ülke koduyla başlamıyor.
  unknownCountry,

  /// Hane sayısı ülkenin aralığı dışında.
  digitCount,

  /// Ülkenin cep operatörü ön eklerine uymuyor (ör. sabit hat numarası).
  operatorPrefix,
}

/// [checkPhoneNumber] sonucu. [issue] `null` ise numara SMS'e hazırdır.
class PhoneNumberCheck {
  const PhoneNumberCheck({
    required this.issue,
    required this.country,
    required this.nationalDigits,
  });

  final PhoneNumberIssue? issue;

  /// Ülke çözülemediyse `null`.
  final CountryCode? country;

  /// Arama kodundan sonraki haneler (ülke çözülemediyse boş).
  final String nationalDigits;

  bool get isOk => issue == null;

  /// Ülkenin beklediği hane sayısı — kullanıcıya gösterilecek metin için.
  /// Tek değer ise "10", aralık ise "9-10".
  String get expectedDigits {
    final CountryCode? c = country;
    if (c == null) return '';
    return c.min == c.max ? '${c.min}' : '${c.min}-${c.max}';
  }
}

/// Numarayı SMS öncesi yapısal olarak denetler. Sıra önemlidir: ülke
/// çözülmeden hane/ön ek denetimi anlamsızdır.
PhoneNumberCheck checkPhoneNumber(String? e164) {
  final String value = (e164 ?? '').trim();
  final CountryCode? country = countryForE164(value);
  if (country == null) {
    return const PhoneNumberCheck(
      issue: PhoneNumberIssue.unknownCountry,
      country: null,
      nationalDigits: '',
    );
  }

  final String digits = value
      .substring(country.dial.length)
      .replaceAll(_nonDigit, '');

  if (digits.length < country.min || digits.length > country.max) {
    return PhoneNumberCheck(
      issue: PhoneNumberIssue.digitCount,
      country: country,
      nationalDigits: digits,
    );
  }

  if (!matchesMobilePrefix(digits, country.code)) {
    return PhoneNumberCheck(
      issue: PhoneNumberIssue.operatorPrefix,
      country: country,
      nationalDigits: digits,
    );
  }

  return PhoneNumberCheck(
    issue: null,
    country: country,
    nationalDigits: digits,
  );
}

/// Ülkenin cep ön ekleri; tanımlı değilse `null` (denetim yapılmaz).
List<String>? mobilePrefixesFor(String isoCode) =>
    kMobilePrefixes[isoCode.toUpperCase()];

/// Ön ek listesinin kullanıcıya gösterilen hâli: `50, 53, 54, 55, 56`.
String describeMobilePrefixes(String isoCode) =>
    (mobilePrefixesFor(isoCode) ?? const <String>[]).join(', ');

/// **Tamamlanmış** ulusal numara ülkenin cep ön eklerinden biriyle başlıyor
/// mu? Ülke için ön ek verisi yoksa `true` — bilmediğimiz numarayı
/// reddetmeyiz.
bool matchesMobilePrefix(String nationalDigits, String isoCode) {
  final List<String>? prefixes = mobilePrefixesFor(isoCode);
  if (prefixes == null || nationalDigits.isEmpty) return true;

  return prefixes.any((String p) => nationalDigits.startsWith(p));
}

/// **Yazılmakta olan** numara için: girilen haneler hiçbir ön ekle
/// bağdaşmıyor mu? Eksik numarada `false` döner (ör. TR'de yalnızca "5"
/// yazılmışken uyarı çıkmaz), ilk uyumsuz hanede `true` olur.
bool conflictsWithMobilePrefix(String nationalDigits, String isoCode) {
  final List<String>? prefixes = mobilePrefixesFor(isoCode);
  if (prefixes == null || nationalDigits.isEmpty) return false;

  return !prefixes.any(
    (String p) =>
        nationalDigits.startsWith(p) || p.startsWith(nationalDigits),
  );
}
