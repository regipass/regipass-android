/// Telefonu doğrulanmamış kayıtların ömrü.
///
/// Kural: hesap açıldıktan (e-posta + şifre) sonra bu süre içinde SMS
/// doğrulaması tamamlanmazsa kayıt veritabanında tutulmaz, silinir. Silme
/// işini `AccountCleanupRepository` yapar; tetikleyen taraf `RegipassApp`
/// içindeki oturum dinleyicisidir (bkz. lib/app/app.dart).
///
/// **Yalnızca öğrenci hesapları için geçerlidir.** Kulüplerde SMS doğrulaması
/// hiç istenmiyor (bkz. [getClubRouteByStatus]); doğrulanmamış bir kulüp
/// kaydı bu yüzden silinmez.
library;

/// Doğrulama için tanınan süre.
/// İP-0b: 3 dakikadan 15 dakikaya çıkarıldı — form + SMS 3 dakikaya sığmıyor,
/// SMS gecikince hesap formun ortasında siliniyordu.
const Duration kPhoneVerifyGrace = Duration(minutes: 15);

/// Doğrulanmamış kaydın silinme zamanı geldi mi?
///
/// [createdAtMs] okunamıyorsa `false` döner — zamanı bilinmeyen kayıt
/// silinmez. Bu yalnızca teorik bir savunma değil: `createdAt` alanı
/// `FieldValue.serverTimestamp()` ile yazılır ve sunucu damgayı onaylayana
/// kadar yerel anlık görüntüde `null` görünür. O anda silmeye kalkmak, yeni
/// açılmış hesabı anında yok ederdi.
bool isPhoneVerifyGraceExpired({
  required bool phoneVerified,
  required int? createdAtMs,
  required DateTime now,
}) {
  if (phoneVerified) return false;
  if (createdAtMs == null || createdAtMs <= 0) return false;

  final DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  return now.difference(createdAt) > kPhoneVerifyGrace;
}
