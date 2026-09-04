/// Doğrulama SMS'i gönderilmeden **önce** çalışan tek kapı.
///
/// Kod istemenin bedeli var (SMS kotası, kötüye kullanım sınırı, kullanıcının
/// bekleyip "kod gelmedi" demesi). Bu yüzden `verifyPhoneNumber` çağrılmadan
/// önce sırayla üç soru sorulur:
///
/// 1. **Hane sayısı** ülkeye uyuyor mu?           (yerel, ağsız)
/// 2. **Operatör ön eki** ülkeye uyuyor mu?       (yerel, ağsız)
/// 3. **Numara başka bir hesaba mı ait?**         (Firestore sahiplik dizini)
///
/// Ucuz olan önce: ağa çıkmadan elenebilecek numara için sorgu yapılmaz.
/// Üçü de geçerse çağıran taraf Firebase'e gider ve kodu Firebase gönderir.
///
/// Sahiplik sorgusu yapılamazsa (kural yayınlanmamış, çevrimdışı) akış
/// durmaz: `PhoneOwnership.unknown` "temiz" sayılır, Firebase Auth telefonu
/// hesaba bağlarken aynı çakışmayı ikinci kez zaten yakalar.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/phone_precheck.dart';
import '../../l10n/app_strings.dart';
import '../../services/phone_directory_repository.dart';
import '../../state/providers.dart';
import 'live_phone_field.dart' show phoneOwnershipError;

/// Yerel yapı denetimi (1. ve 2. adım). Numara SMS'e uygunsa `null`, değilse
/// kullanıcıya gösterilecek metin döner.
///
/// Alanın kendi anlık uyarısıyla (bkz. `PhoneField`) aynı kaynağı kullanır;
/// biri geçerken diğerinin takılması mümkün değildir.
String? phoneStructureError(BuildContext context, String? phoneE164) {
  final PhoneNumberCheck check = checkPhoneNumber(phoneE164);
  final PhoneNumberIssue? issue = check.issue;
  if (issue == null) return null;

  return switch (issue) {
    // Ülke kodu çözülemedi: kayıtlı numara bozuk, kullanıcı güncellemeli.
    PhoneNumberIssue.unknownCountry => context.t(
      'phoneVerify.error.invalidPhone',
    ),
    PhoneNumberIssue.digitCount => context.t(
      'form.phoneCountryDigits',
      <String, Object?>{
        'country': check.country!.name,
        'digits': check.expectedDigits,
      },
    ),
    PhoneNumberIssue.operatorPrefix => context.t(
      'form.phoneOperatorPrefix',
      <String, Object?>{
        'country': check.country!.name,
        'prefixes': describeMobilePrefixes(check.country!.code),
      },
    ),
  };
}

/// Üç adımın tamamı. `null` dönerse SMS gönderilebilir; dolu dönerse dönen
/// metin doğrudan kullanıcıya gösterilir ve kod **istenmez**.
///
/// [uid] `null` ise (henüz oturum açılmamış — ör. şifre sıfırlama akışı)
/// sahiplik sorgusu atlanır, yerel denetimler yine çalışır.
Future<String?> phoneSendPrecheck(
  BuildContext context,
  WidgetRef ref, {
  required String phoneE164,
  String? uid,
}) async {
  final String? structure = phoneStructureError(context, phoneE164);
  if (structure != null) return structure;

  if (uid == null) return null;

  final PhoneOwnership ownership = await ref
      .read(phoneDirectoryRepositoryProvider)
      .lookup(phoneE164: phoneE164, uid: uid);

  // Sorgu sürerken ekran kapanmış olabilir; çağıran taraf kendi `mounted`
  // denetimiyle zaten duracak, burada çeviri aramayız.
  if (!context.mounted) return null;

  return phoneOwnershipError(context, ownership);
}
