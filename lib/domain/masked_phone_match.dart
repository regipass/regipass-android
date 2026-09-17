/// Maskeli kurtarma ipucu ile kullanıcının yazdığı numaranın **SMS
/// gönderilmeden önce** karşılaştırılması.
///
/// "Şifremi unuttum" ekranı giriş yapılmamış bir kullanıcıya hizmet eder;
/// e-postaya bağlı tam numara istemciye hiçbir zaman verilmez (bkz.
/// `services/phone_hint_repository.dart`). İstemcinin elindeki tek bilgi
/// maskedir:
///
/// ```
/// +90 XXX XXX XX 67     // TR — arama kodu görünür, son iki hane açık
/// +XXXXXXXXX71          // TR dışı, Cloud Function biçimi — arama kodu gizli
/// +1 XXX XXX XX7 1      // TR dışı, istemci biçimi — arama kodu görünür
/// ```
///
/// Maske az bilgi taşır ama **yanlış numarayı elemeye yeter**: arama kodu,
/// hane sayısı ve son haneler. Üçü de tutuyorsa numara doğru olabilir; biri
/// bile tutmuyorsa kesinlikle yanlıştır ve SMS göndermenin anlamı yoktur.
///
/// Bu dosya saf mantıktır — ağ yok, Flutter yok, tek kaynak `phone_precheck`.
/// Nihai yetki hâlâ SMS sonrası e-posta eşleşmesindedir
/// (`forgot_password_screen.dart#_applyCredential`); burada yapılan iş o
/// denetimin ucuz ve erken çalışan kopyasıdır, yerine geçmez.
library;

import '../data/country_codes.dart';
import 'phone_precheck.dart';

/// İpucunun hangi basamakta tutmadığı.
enum MaskedPhoneMismatch {
  /// İpucu tam numarayı taşıyordu ve numara birebir tutmadı. Maskeli ipuçları
  /// bunu üretemez — yalnızca [kRevealPasswordResetPhone] açıkken görülür.
  exact,

  /// Arama kodu farklı (ör. ipucu +90, yazılan +49).
  country,

  /// Hane sayısı farklı.
  length,

  /// Maskede açık duran son haneler tutmuyor.
  suffix,
}

/// Maskeden çıkarılabilen bilgiler.
class MaskedPhoneHint {
  const MaskedPhoneHint({
    required this.dial,
    required this.nationalDigitCount,
    required this.totalDigitCount,
    required this.visibleSuffix,
  });

  /// Maskede açıkça duran arama kodu (`+90`). Maske arama kodunu da
  /// gizliyorsa (`+XXXXXXXXX71`) `null` — o zaman ülke denetimi yapılamaz,
  /// yalnızca toplam hane sayısı ve son haneler karşılaştırılır.
  final String? dial;

  /// Arama kodundan sonraki hane sayısı. [dial] `null` ise `0`.
  final int nationalDigitCount;

  /// `+` işaretinden sonraki tüm haneler (arama kodu dâhil).
  final int totalDigitCount;

  /// Maskede açık bırakılmış son haneler (`67`). Maske hiçbir haneyi
  /// göstermiyorsa boş.
  final String visibleSuffix;
}

/// Maskeyi çözümler. Maske tanınmıyorsa `null` döner ve çağıran taraf
/// **karşılaştırma yapmadan** devam etmelidir: elde ölçüt yokken kullanıcıyı
/// kurtarma akışından çıkarmak, yanlış numaraya SMS gitmesinden daha kötüdür.
MaskedPhoneHint? parseMaskedPhone(String? masked) {
  final String value = (masked ?? '').trim();
  if (!value.startsWith('+')) return null;

  // Boşluk, tire, parantez gibi ayraçlar atılır; yalnızca hane ve maske
  // karakteri kalır. Büyük/küçük 'x' ikisi de maske sayılır.
  final StringBuffer body = StringBuffer();
  for (int i = 1; i < value.length; i++) {
    final String ch = value[i];
    if (ch == 'X' || ch == 'x') {
      body.write('X');
    } else if (ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39) {
      body.write(ch);
    }
  }

  final String digitsAndMask = body.toString();
  final int firstMask = digitsAndMask.indexOf('X');
  // Hiç maske karakteri yoksa bu bir maske değil (ya ham numara ya da bozuk
  // veri). Ham numarayla karşılaştırma yapmak ipucunun tam numarayı
  // sızdırdığı anlamına gelirdi; böyle bir veriye güvenmiyoruz.
  if (firstMask < 0) return null;

  final String national = digitsAndMask.substring(firstMask);
  final String dialDigits = digitsAndMask.substring(0, firstMask);

  // Sondaki açık haneler.
  int end = national.length;
  while (end > 0 && national[end - 1] != 'X') {
    end--;
  }

  return MaskedPhoneHint(
    dial: dialDigits.isEmpty ? null : '+$dialDigits',
    nationalDigitCount: dialDigits.isEmpty ? 0 : national.length,
    totalDigitCount: digitsAndMask.length,
    visibleSuffix: national.substring(end),
  );
}

/// İpucu maskesiz, kullanılabilir bir E.164 numara mı? Değilse `null`.
///
/// `phone_hints` belgesi hem maske hem tam numara taşıyabiliyor (bkz.
/// `kRevealPasswordResetPhone`). Denetim ipucunun ne kadarını açtığına göre
/// kendini ayarlar; çağıran tarafın hangi kipte olduğunu bilmesi gerekmez.
String? fullPhoneFromHint(String? hint) {
  final String value = (hint ?? '').trim();
  if (!value.startsWith('+') || value.contains('X') || value.contains('x')) {
    return null;
  }

  final String digits = value.substring(1).replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  final String e164 = '+$digits';
  return countryForE164(e164) == null ? null : e164;
}

/// Yazılan numara ipucuyla bağdaşıyor mu?
///
/// İpucu **tam numara** taşıyorsa birebir karşılaştırılır — maskenin
/// gizlediği ortadaki haneler de denetlenir. İpucu **maskeliyse** yalnızca
/// maskenin açık bıraktığı kadarı (arama kodu, hane sayısı, son haneler)
/// karşılaştırılabilir.
///
/// `null` dönerse **engelleme yok**: ya ipucu elde yok/tanınmıyor, ya da
/// numara ipucuyla çelişmiyor. Dolu dönerse numara o hesaba ait değildir.
///
/// [typedE164] yapısal olarak bozuksa da `null` döner; o hatayı
/// `phoneStructureError` zaten kendi mesajıyla veriyor, burada ikinci kez
/// rapor edilmez.
MaskedPhoneMismatch? matchHintPhone({
  required String? hint,
  required String? typedE164,
}) {
  final String typed = (typedE164 ?? '').trim();

  final String? full = fullPhoneFromHint(hint);
  if (full != null) {
    if (countryForE164(typed) == null) return null;
    final String typedDigits = typed.replaceAll(RegExp(r'\D'), '');
    return typedDigits == full.substring(1) ? null : MaskedPhoneMismatch.exact;
  }

  final MaskedPhoneHint? mask = parseMaskedPhone(hint);
  if (mask == null) return null;

  final CountryCode? country = countryForE164(typed);
  if (country == null) return null;

  final String nationalDigits = typed
      .substring(country.dial.length)
      .replaceAll(RegExp(r'\D'), '');
  if (nationalDigits.isEmpty) return null;

  final String dialDigits = country.dial.replaceAll(RegExp(r'\D'), '');
  final String allDigits = '$dialDigits$nationalDigits';

  if (mask.dial != null) {
    if (mask.dial != country.dial) return MaskedPhoneMismatch.country;
    if (mask.nationalDigitCount != nationalDigits.length) {
      return MaskedPhoneMismatch.length;
    }
  } else if (mask.totalDigitCount != allDigits.length) {
    // Arama kodu gizliyken hane sayısı tek elimizdeki uzunluk ölçütü.
    return MaskedPhoneMismatch.length;
  }

  if (mask.visibleSuffix.isNotEmpty &&
      !allDigits.endsWith(mask.visibleSuffix)) {
    return MaskedPhoneMismatch.suffix;
  }

  return null;
}
