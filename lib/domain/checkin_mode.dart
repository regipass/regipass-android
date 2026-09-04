/// Etkinlikte kapı girişi ve oturum yoklamasının nasıl çalıştığı.
///
/// Alan eklenmeden önce oluşturulmuş etkinliklerde [checkinMode] boş olur.
/// Bu kayıtlarda eski davranışı korumak için mod, `sessionCount` değerinden
/// türetilir: çok oturum = yalnızca yoklama, tek oturum = kulübün okuttuğu
/// klasik giriş QR'ı.
library;

abstract final class CheckinMode {
  static const String checkinAttendance = 'checkin_attendance';
  static const String attendanceOnly = 'attendance_only';
  static const String checkinOnly = 'checkin_only';

  static const List<String> values = <String>[
    checkinAttendance,
    attendanceOnly,
    checkinOnly,
  ];

  static bool isValid(String value) => values.contains(value);

  static String resolve(String? stored, int sessionCount) {
    if (stored != null && isValid(stored)) return stored;
    return sessionCount > 1 ? attendanceOnly : checkinOnly;
  }

  static bool hasDoorCheckin(String mode) => mode != attendanceOnly;

  static bool hasSessions(String mode) => mode != checkinOnly;

  static bool requiresDoorCheckinForSession({
    required String mode,
    required bool allowSessionWithoutCheckin,
  }) => mode == checkinAttendance && !allowSessionWithoutCheckin;
}

/// Kapı check-in'inin aşaması (checkin-mode.js > CHECKIN_STAGES).
///
/// "Check-in + Yoklama" modunda iş **sırayla** yürür:
///
///   * [notStarted] — kulüp henüz kapıyı açmadı. Oturumlar başlatılamaz.
///   * [running]    — kapı açık, öğrenciler giriyor.
///   * [finished]   — kulüp check-in'i bitirdi. Kimin girdiği artık bellidir ve
///                    oturumlar bu andan itibaren başlatılabilir.
///
/// Sıra zorunluluğunun sebebi: oturum yoklaması kapı girişine bağlıdır
/// ([CheckinMode.requiresDoorCheckinForSession]). Kapı bitmeden oturum
/// başlatılırsa daha içeri girmemiş öğrenciler yoklamada reddedilir ve kulüp
/// bunu ancak öğrenciler şikâyet edince fark eder.
enum CheckinStage { notStarted, running, finished }

/// Aşamayı iki kalıcı alandan türetir:
///
///   * `entryStartedAtMs` — kapı **bir kez** açıldığında yazılır, silinmez
///   * `entryOpen`        — kapı şu anda açık mı (kulüp açar/kapatır)
///
/// Böylece "bitir" sonrası "yeniden başlat" veriyi sıfırlamadan çalışır:
/// okunan girişler kayıtlarda durur, yeni okutulanlar üzerine eklenir.
///
/// Kapı check-in'i olmayan etkinlikte `null` döner.
CheckinStage? resolveCheckinStage({
  required String mode,
  required int entryStartedAtMs,
  required bool entryOpen,
}) {
  if (!CheckinMode.hasDoorCheckin(mode)) return null;
  if (entryStartedAtMs <= 0) return CheckinStage.notStarted;
  return entryOpen ? CheckinStage.running : CheckinStage.finished;
}

/// Kapı check-in'i, **ilk** oturumun başlatılmasını engelliyor mu?
///
/// Yalnızca "Check-in + Yoklama" modunda ve yalnızca henüz hiç oturum
/// başlatılmamışken geçerlidir. Başlamış bir etkinliğin oturumlarını ilerletmek
/// hiçbir zaman kilitlenmez — aksi hâlde bu alanlar eklenmeden önce
/// oluşturulmuş, yarıda kalmış etkinlikler kilitlenip kalırdı.
/// (Model üzerindeki `AppEvent.doorCheckinBlocksSessions` getter'ıyla ad
/// çakışmasın diye `...For` ekiyle.)
bool doorCheckinBlocksSessionsFor({
  required String mode,
  required int currentSession,
  required int entryStartedAtMs,
  required bool entryOpen,
}) {
  if (mode != CheckinMode.checkinAttendance) return false;
  if (currentSession > 0) return false;
  return resolveCheckinStage(
        mode: mode,
        entryStartedAtMs: entryStartedAtMs,
        entryOpen: entryOpen,
      ) !=
      CheckinStage.finished;
}
