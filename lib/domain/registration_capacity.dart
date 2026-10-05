/// Kontenjan parçaları, ilk istek yayma ve yeniden deneme politikası.
/// Parça sayısı eşzamanlı öğrenci sınırı değildir. Yerel yük ölçümleri
/// üretim Firestore kapasitesi veya fiziksel cihaz performansı sayılmaz.
library;

import 'dart:math';

// ── Eski kapasite araçlarıyla uyumluluk ──────────────────────────────

/// Eski test varsayımı; güncel Firestore garantisi veya kullanılan hız limiti değil.
const int kSustainedWritesPerDocPerSecond = 1;

/// Eski indeks yükü varsayımı; etkinlik başına garanti edilmiş kayıt hızı değil.
///
/// `event_registrations` dokümanlarında `eventId` tek bir değer, `createdAt`
/// ise sürekli artan bir zaman damgasıdır. Firestore her alanı kendiliğinden
/// indekslediği ve `firestore.indexes.json` bu alanlar için indeksi
/// KAPATMADIĞI için yazımlar dar bir indeks anahtar aralığına düşer —
/// belgelenmiş sıcak nokta sınırı saniyede 500 yazmadır.
const int kMaxWritesPerSecondPerEvent = 500;

/// Yeni bir koleksiyona/indekse başlangıç trafiği (500/50/5 kuralı):
/// ilk 5 dakika 500 işlem/sn, sonra her 5 dakikada %50 artırılabilir.
const int kColdStartOpsPerSecond = 500;

// ── Parçalı sayaç ────────────────────────────────────────────────────

/// Bir etkinliğin kontenjanı kaç parçaya bölünsün.
///
/// Her parça `events/{id}/quota_shards/{n}` yolunda ayrı bir dokümandır.
/// Parçalar eşzamanlı yazma çekişmesini azaltır. Öğrenci kapasitesi sadece
/// bu sayıdan çıkarılamaz; ilk istek yayma ve yeniden deneme de sonucu etkiler.
///
/// Sayı neden bu: iki maliyet birbirine karşı çalışıyor.
///
///   • **Çekişme** parça sayısıyla azalır — aynı satır için yarışan az olur.
///   • **Yürüme** parça sayısıyla artar: parçalar dolmaya başlayınca kayıt
///     boş parça arayarak dolaşır, kontenjanın son kişileri pahalılaşır.
///     Ayrıca doluluk göstergesi ve "kontenjan doldu" kontrolü parçaların
///     tamamını okur.
///
/// Denge, parça başına ~12 kişilik kapasitede kuruluyor: yürüme nadir kalacak
/// kadar dolu, çekişme dağılacak kadar çok parça.
///
/// AYAR NOTU — bir denemeden sonra bu tablo ikiye katlanmıştı; geri alındı.
/// Gerekçe emulator ölçümleriydi ve **o ölçümler güvenilir değil**: aynı
/// kurulum (400 kişi, 32 parça) iki koşuda 95 ve 45 verdi. Yüksek
/// eşzamanlılıkta emulator kendi tavanına çarptığı için parça sayısı
/// ayarlanamıyor. Güvenilir olan tek karşılaştırma doygunluk ALTINDA
/// yapılanıydı ve tabloyu destekliyor: kontenjan 100, kabul denetimli,
/// 8 parça → **100/100**; 16 parça → 88/100.
int quotaShardCount(int quota) {
  if (quota <= 0) return 0; // kontenjansız etkinlik: sayaç yok

  final int fromTable = quota <= 50
      ? 4
      : quota <= 200
      ? 8
      : quota <= 1000
      ? 16
      : 32;

  // Kontenjandan çok parça olmasın: kapasitesi 0 olan parçalar yalnızca
  // taranıp geçilecek ölü dokümanlardır.
  return fromTable < quota ? fromTable : quota;
}

/// Kontenjanı parçalara böler; artan pay ilk parçalara verilir.
///
/// Toplamları **tam olarak** kontenjandır — kontenjan aşımının da eksik
/// kalmasının da imkânsız olmasının sebebi budur.
List<int> shardCapacities(int quota, int shards) {
  if (shards <= 0 || quota <= 0) return const <int>[];
  final int base = quota ~/ shards;
  final int extra = quota % shards;
  return List<int>.generate(shards, (int s) => base + (s < extra ? 1 : 0));
}

/// Öğrencinin **başlangıç** parçası.
///
/// Kimlikten türetilir (rastgele değil): aynı öğrenci yeniden denediğinde
/// aynı parçadan başlar, böylece yeniden denemeler parçalar arasında
/// savrulup çekişmeyi çoğaltmaz. Farklı öğrenciler ise farklı parçalara
/// dağılır.
int startShardFor(String studentId, int shards) {
  if (shards <= 0) return 0;
  int hash = 0;
  for (int i = 0; i < studentId.length; i++) {
    hash = (hash * 31 + studentId.codeUnitAt(i)) & 0x7fffffff;
  }
  return hash % shards;
}

// ── Yeniden deneme ───────────────────────────────────────────────────

/// En fazla kaç tur denenecek.
///
/// Yük testinde 500 eşzamanlı istek en geç 4. turda yerleşti; 8 tur,
/// beklenmedik yavaşlıklara pay bırakır.
const int kRegistrationMaxRounds = 8;

/// Üstel bekleyişin taban süresi.
const Duration kRegistrationBaseDelay = Duration(milliseconds: 150);

/// Bekleyiş tavanı — bir tur bundan uzun sürmez.
const Duration kRegistrationMaxDelay = Duration(seconds: 6);

/// Web registration-queue.js ile aynı ilk istek yayma penceresi.
/// Bu, merkezî/FIFO sıra veya bir Firestore hız limiti değildir.
Duration registrationAdmissionWindow({
  required int quota,
  required int shards,
}) {
  if (quota < 40 || shards <= 0) return Duration.zero;
  final int seats = (quota / shards).ceil();
  return Duration(milliseconds: (seats * 1200).clamp(2000, 8000));
}

Duration registrationAdmissionDelay({
  required int quota,
  required int shards,
  Random? random,
}) {
  final int window = registrationAdmissionWindow(
    quota: quota,
    shards: shards,
  ).inMilliseconds;
  if (window == 0) return Duration.zero;
  return Duration(milliseconds: (random ?? _defaultRandom).nextInt(window));
}

/// Kural reddi kendi başına çekişme kanıtı değildir. Yalnızca denemede
/// okunan sayaç sonradan değişmişse işlem taze değerle tekrar denenebilir.
bool quotaChangedAfterDeniedWrite({
  required String code,
  required int? attemptedCount,
  required int? currentCount,
}) =>
    code == 'permission-denied' &&
    attemptedCount != null &&
    currentCount != null &&
    attemptedCount != currentCount;

bool isRegistrationRetryable(String code) => const <String>{
  'aborted',
  'failed-precondition',
  'unavailable',
  'deadline-exceeded',
  'resource-exhausted',
  'internal',
  'cancelled',
}.contains(code);

final Random _defaultRandom = Random();

/// [round] numaralı turdan sonra ne kadar beklenecek — **tam jitter**.
///
/// Pencere üstel büyür (150ms, 300ms, 600ms, …, tavan 6sn) ama bekleme
/// süresi bu pencereden RASTGELE seçilir: sabit bekleyişte çekişmeden düşen
/// herkes aynı anda uyanıp aynı anda tekrar çarpışır (sürü etkisi).
///
/// DÜRÜSTLÜK NOTU: jitter'ın sabit bekleyişe üstünlüğünü bu projenin yük
/// testleri **gösteremedi** — emulator tek süreçli olduğu için yüksek
/// eşzamanlılıkta kendi işlem tavanına çarpıyor ve iki kurulum da aynı
/// sonucu veriyor (`05-realistic` mod 2 ile `05b-jitter` karşılaştırması).
/// Jitter yine de tercih edildi: yerleşik bir dağıtık sistem uygulamasıdır
/// ve üretimde (arka uç doymadığında) sürü etkisini gerçekten kırar.
/// Ölçülemeyen bir fayda için ödenen bedel sıfıra yakın.
Duration registrationBackoff(int round, {Random? random}) {
  if (round < 0) return Duration.zero;

  final int baseMs = kRegistrationBaseDelay.inMilliseconds;
  final int capMs = kRegistrationMaxDelay.inMilliseconds;

  // `1 << round` büyük turlarda taşabilir; tavana çarpınca zaten sabitlenir.
  final int windowMs = round >= 31 ? capMs : min(capMs, baseMs << round);

  return Duration(
    milliseconds: (random ?? _defaultRandom).nextInt(windowMs + 1),
  );
}

/// En kötü hâlde toplam ne kadar beklenir (bütün turlar tavana çarparsa).
/// Kullanıcıya gösterilecek zaman aşımı metnini buna göre yazıyoruz.
Duration get maxRegistrationWait {
  int total = 0;
  for (int round = 0; round < kRegistrationMaxRounds - 1; round++) {
    total += registrationBackoffWindow(round).inMilliseconds;
  }
  return Duration(milliseconds: total);
}

/// [round] turunun jitter penceresi (rastgelelik öncesi üst sınır).
Duration registrationBackoffWindow(int round) {
  if (round < 0) return Duration.zero;
  final int baseMs = kRegistrationBaseDelay.inMilliseconds;
  final int capMs = kRegistrationMaxDelay.inMilliseconds;
  return Duration(
    milliseconds: round >= 31 ? capMs : min(capMs, baseMs << round),
  );
}

// ── Doluluk ──────────────────────────────────────────────────────────

/// Kayıtların neden kapatıldığı (`events.registrationClosedReason`).
///
/// Sebebi saklamak şart: kontenjan dolduğu için KENDİLİĞİNDEN kapanan bir
/// etkinlik, yer açılınca kendiliğinden geri açılmalı; kulübün ELİYLE
/// kapattığı etkinlik ise açılmamalı. İkisi de aynı `registrationClosed`
/// bayrağını kullandığı için ayrım ancak burada durabilir.
class ClosedReason {
  /// Kontenjan doldu — kayıtlar beklemede.
  static const String quotaFull = 'quota_full';

  /// Kulüp kayıtları elle durdurdu.
  static const String manual = 'manual';

  /// Etkinlik başladı (ilk oturum ilerletildi) — kayıtlar kendiliğinden
  /// durdu.
  static const String sessionsStarted = 'sessions_started';

  /// Kapı check-in'i açıldı (henüz hiçbir oturum ilerletilmeden) — kayıtlar
  /// kendiliğinden durdu. Bkz. `EventRepository.setEntryOpen`.
  static const String checkinStarted = 'checkin_started';
}

/// Bir etkinliğin kontenjan doluluk durumu — parça sayaçlarından türetilir.
///
/// Etkinlik dokümanında **saklanmaz**: tek bir sayı olarak saklamak, o sayıyı
/// yazan dokümanı yeniden darboğaz yapardı (bkz. §1.3). Kulüp ekranı
/// parçaları okuyup burada toplar; parça sayısı 32'yi geçmediği için bu
/// okuma ucuzdur.
class QuotaStatus {
  const QuotaStatus({
    required this.used,
    required this.capacity,
    required this.shardsFound,
  });

  /// Hiç parçası olmayan (eski ya da kontenjansız) etkinlik.
  static const QuotaStatus untracked = QuotaStatus(
    used: 0,
    capacity: 0,
    shardsFound: 0,
  );

  /// Dolu yer sayısı — parça sayaçlarının toplamı.
  final int used;

  /// Toplam kontenjan — parça kapasitelerinin toplamı.
  final int capacity;

  /// Kaç parça okundu.
  final int shardsFound;

  /// Kontenjan takibi bu etkinlikte çalışıyor mu?
  bool get isTracked => shardsFound > 0 && capacity > 0;

  bool get isFull => isTracked && used >= capacity;

  int get remaining {
    if (!isTracked) return 0;
    final int left = capacity - used;
    return left < 0 ? 0 : left;
  }

  /// 0–100 arası doluluk yüzdesi.
  int get percent {
    if (!isTracked) return 0;
    final int value = ((used / capacity) * 100).round();
    return value.clamp(0, 100);
  }

  @override
  String toString() => 'QuotaStatus($used/$capacity, $shardsFound parça)';
}

/// Kontenjan durumuna bakınca kayıt bayrağına ne yapılmalı.
enum QuotaGateAction {
  /// Dokunma.
  none,

  /// Kontenjan doldu → kayıtları beklemeye al.
  pause,

  /// Yer açıldı → kayıtları geri aç.
  resume,
}

/// Etkinliğin kayıt bayrağı kontenjan durumuyla uyumlu mu?
///
/// Saf karar: Firebase'e dokunmaz, böylece "kulüp elle kapattıysa
/// dokunma" gibi ince kurallar emulator gerektirmeden test edilebilir.
///
/// [closedReason] kritik: kontenjan dolduğu için KENDİLİĞİNDEN kapanan bir
/// etkinlik yer açılınca geri açılmalı, kulübün ELİYLE durdurduğu etkinlik
/// açılmamalı. Sebep yazılmamış eski kayıtlara da dokunulmaz — kulübün
/// kararı olabilir.
QuotaGateAction quotaGateAction({
  required QuotaStatus status,
  required bool registrationClosed,
  required String closedReason,
}) {
  if (!status.isTracked) return QuotaGateAction.none;

  // İP-K: kontenjan dolunca kayıtlar artık DURDURULMAZ; öğrenci bekleme
  // listesine girer (sunucu "dolu" bilgisini `seatsFull` ile yazar). Eski
  // sürümün otomatik kapattığı etkinlik dolu olsa bile geri açılır.
  if (registrationClosed && closedReason == ClosedReason.quotaFull) {
    return QuotaGateAction.resume;
  }

  return QuotaGateAction.none;
}

/// Oturum ilerletme/geri alma bakınca kayıt bayrağına ne yapılmalı.
enum SessionRegistrationGateAction {
  /// Dokunma.
  none,

  /// Etkinlik başlıyor (0 -> 1) → kayıtları durdur.
  close,

  /// En başa geri alındı (-> 0) → kendiliğinden kapanmışsa geri aç.
  reopen,
}

/// Etkinliği "başlat"mak (ilk oturumu ilerletmek) kayıtları kendiliğinden
/// durdurmalı; bu adımı geri alıp en başa dönmek de — yalnızca BU YÜZDEN
/// kapalıysa — kendiliğinden geri açmalı.
///
/// [quotaGateAction] ile aynı gerekçeyle [closedReason] ayrımı şart: kulübün
/// ELİYLE ya da kontenjan dolduğu için kapattığı bir etkinliği, oturumu geri
/// almak açmamalı — yalnızca etkinlik başladığı için kendiliğinden kapanan
/// etkinlik, en başa dönülünce kendiliğinden açılır.
///
/// Reopen ayrımı hem [ClosedReason.sessionsStarted] hem
/// [ClosedReason.checkinStarted] için geçerlidir: kapı check-in'i, ilk
/// oturum hiç ilerletilmeden önce açılıp kayıtları kendiliğinden
/// kapatabilir (bkz. `EventRepository.setEntryOpen`); en başa dönüş bu
/// durumda da kendiliğinden kapanmış kaydı açar (bkz.
/// `EventRepository.advanceSession` > kapı sıfırlaması).
SessionRegistrationGateAction sessionRegistrationGateAction({
  required int previousSession,
  required int nextSession,
  required bool registrationClosed,
  required String closedReason,
  bool allowLateRegistration = false,
}) {
  // İP-B4: organizatör geç kayda izin verdiyse başlarken kayıtlar kapanmaz.
  if (previousSession <= 0 &&
      nextSession >= 1 &&
      !registrationClosed &&
      !allowLateRegistration) {
    return SessionRegistrationGateAction.close;
  }

  if (nextSession <= 0 &&
      registrationClosed &&
      (closedReason == ClosedReason.sessionsStarted ||
          closedReason == ClosedReason.checkinStarted)) {
    return SessionRegistrationGateAction.reopen;
  }

  return SessionRegistrationGateAction.none;
}

// ── Sonuç ────────────────────────────────────────────────────────────

/// Bir kayıt denemesinin bitiş hâli.
enum RegistrationOutcome {
  /// Kayıt oluştu.
  registered,

  /// Öğrenci zaten kayıtlıydı; yeni kontenjan harcanmadı.
  alreadyRegistered,

  /// Kontenjan gerçekten doldu. **Hata değildir**, doğru cevaptır.
  quotaFull,

  /// Kulüp kayıtları durdurmuş ya da son başvuru geçmiş.
  closed,

  /// Etkinlik silinmiş / bulunamadı.
  notFound,

  /// Öğrenci etkinliğin hedef kitlesinde değil.
  notEligible,

  /// Bütün turlar çekişmeye takıldı. Tekrar denenebilir.
  retryExhausted,

  /// Ağ yok / Firestore ulaşılamadı.
  unavailable,
}

extension RegistrationOutcomeX on RegistrationOutcome {
  /// Kullanıcıya "tekrar dene" düğmesi gösterilmeli mi?
  bool get isRetryable =>
      this == RegistrationOutcome.retryExhausted ||
      this == RegistrationOutcome.unavailable;

  /// Kaydın gerçekten oluştuğu hâller.
  bool get isSuccess =>
      this == RegistrationOutcome.registered ||
      this == RegistrationOutcome.alreadyRegistered;
}
