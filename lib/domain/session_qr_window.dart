/// js/modules/events/session-qr-window.js portu.
///
/// Salondaki ekrana yansıtılan oturum QR'ı sabit **değildir**: 20 saniyede bir
/// yenilenir. Amaç, ekranın fotoğrafını çekip dışarıdaki arkadaşına gönderen
/// öğrenciyi durdurmaktır — fotoğraf karşı tarafa ulaştığında kod çoktan
/// değişmiş olur.
///
/// Nasıl çalışır: QR'ın içine, üretildiği **anın** 20 saniyelik dilim numarası
/// (slot) yazılır. Okuyan taraf kendi saatindeki dilimle karşılaştırır:
///
///     slot = (nowMs / 20000).floor()
///
/// ## Neden sunucu doğrulaması yok
///
/// Tazelik kontrolü istemcidedir; `firestore.rules` bunu doğrulayamaz. Sunucuda
/// doğrulanabilmesi için kulübün her 20 saniyede bir etkinlik dokümanına bir
/// "nonce" yazması gerekirdi; ama o dokümanı etkinliğe kayıtlı **her** öğrenci
/// zaten okuyabildiği için nonce sır olmaktan çıkar ve kural hiçbir şey
/// eklemez. Bu yüzden 20 saniyelik pencere, tıpkı konum kontrolü gibi, bir
/// güvenlik sınırı **değil** caydırıcıdır. Gerçek sınırlar kurallarda duruyor:
/// öğrenci yalnızca kendi kaydını, yalnızca etkinliğin o anki `currentSession`ı
/// için ve yalnızca bir kez işaretleyebilir
/// (bkz. firestore.rules > studentCanMarkOwnSessionCheckIn).
///
/// ## Tolerans
///
/// Okuma anı ile QR'ın üretildiği an arasında kamera gecikmesi, ekran açılışı
/// ve cihaz saatlerindeki küçük kaymalar vardır. Bu yüzden bir önceki dilim de
/// kabul edilir; pratikte kabul penceresi 20-40 saniyedir.
library;

/// QR'ın ekranda kaldığı süre.
const int kSessionQrWindowMs = 20000;

/// Kabul edilen en eski dilim farkı (1 => bir önceki dilim de geçerli).
const int kSessionQrGraceSlots = 1;

/// Verilen anın 20 saniyelik dilim numarası.
int currentSessionQrSlot([int? nowMs]) =>
    (nowMs ?? DateTime.now().millisecondsSinceEpoch) ~/ kSessionQrWindowMs;

/// Ekrandaki QR'ın yenilenmesine kaç milisaniye kaldı?
int msUntilNextSessionQrSlot([int? nowMs]) {
  final int now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  return kSessionQrWindowMs - (now % kSessionQrWindowMs);
}

/// Okunan QR hâlâ geçerli mi?
///
/// Dilimi olmayan (bu alan eklenmeden önce üretilmiş) QR'lar geçerli sayılır —
/// yoksa yayındaki ekranlarda duran eski kodlar bir anda çalışmaz olurdu.
bool isSessionQrSlotFresh(Object? slot, [int? nowMs]) {
  if (slot == null) return true; // eski QR biçimi

  final int? value = slot is int ? slot : int.tryParse('$slot');
  if (value == null) return false;

  final int age = currentSessionQrSlot(nowMs) - value;

  // Geleceğe ait bir dilim ancak okuyan cihazın saati geriyse oluşur; bir
  // dilimlik ileri kaymaya izin verilir, daha fazlası kabul edilmez.
  return age >= -1 && age <= kSessionQrGraceSlots;
}
