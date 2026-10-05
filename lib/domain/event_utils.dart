/// js/modules/events/event-utils.js portu.
library;

import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/text_utils.dart';
import '../models/event.dart';
import '../models/profiles.dart';
import 'department_field_map.dart';

// ── Tarih ─────────────────────────────────────────────────────────────

/// Son başvuru tarihi girişi (yyyy-MM-dd) -> gün sonu epoch ms.
/// Web'de `new Date("${input}T23:59:59")` ile aynı: yerel saat dilimi.
int? parseDeadlineFromInput(DateTime? day) {
  if (day == null) return null;
  return DateTime(
    day.year,
    day.month,
    day.day,
    23,
    59,
    59,
  ).millisecondsSinceEpoch;
}

/// Kullanıcıya gösterilecek tarih. Web `Intl.DateTimeFormat("tr-TR")`
/// kullanıyordu; dil değişiminde İngilizce'ye geçebilmesi için locale
/// parametreleştirildi.
String formatDeadline(int? deadlineAtMs, {String locale = 'tr'}) {
  if (deadlineAtMs == null || deadlineAtMs <= 0) {
    return locale == 'en' ? 'Date not set' : 'Tarih belirtilmedi';
  }
  return DateFormat(
    'dd MMMM yyyy',
    locale == 'en' ? 'en_US' : 'tr_TR',
  ).format(DateTime.fromMillisecondsSinceEpoch(deadlineAtMs));
}

String formatDateTime(int? valueMs, {String locale = 'tr'}) {
  if (valueMs == null || valueMs <= 0) return '-';
  return DateFormat(
    'dd MMMM yyyy HH:mm',
    locale == 'en' ? 'en_US' : 'tr_TR',
  ).format(DateTime.fromMillisecondsSinceEpoch(valueMs));
}

/// Saniyeli tam zaman damgası — gün, saat, dakika, saniye.
///
/// KVKK Aydınlatma Metni (madde 7), onay kayıtlarının "onay zamanı" ile
/// birlikte saklanmasını şart koşuyor; olası bir uyuşmazlıkta onayın tam
/// olarak ne zaman verildiği ispatlanabilmeli. Bu yüzden onay satırlarında
/// dakika değil saniye çözünürlüğü gösterilir.
String formatDateTimeWithSeconds(int? valueMs, {String locale = 'tr'}) {
  if (valueMs == null || valueMs <= 0) return '-';
  return DateFormat(
    'dd MMMM yyyy HH:mm:ss',
    locale == 'en' ? 'en_US' : 'tr_TR',
  ).format(DateTime.fromMillisecondsSinceEpoch(valueMs));
}

/// Etkinliğin süresi doldu mu?
///
/// Karşılaştırma yerel saatle, son başvuru anına kadar yapılır.
///
/// Tarih seçicisi son başvuru gününü `23:59:59` olarak kaydeder. Bu nedenle
/// etkinlik o gün boyunca açık kalır; bu an geçer geçmez keşfetten çıkar.
bool isPastEvent(AppEvent event, {DateTime? now}) {
  if (event.deadlineAtMs <= 0) return false;

  final DateTime deadline = DateTime.fromMillisecondsSinceEpoch(
    event.deadlineAtMs,
  );
  final DateTime current = now ?? DateTime.now();
  return !deadline.isAfter(current);
}

/// Kulübün "Etkinliklerim" ekranındaki üç durum.
///
/// Bu sınıflandırma, keşfet/kayıt kapanışından farklı olarak etkinliğin
/// **yapılacağı güne** bakar. Web'deki `getClubEventStage` ile aynı kuralı
/// kullanır: kayıt süresi etkinlik gününden önce kapansa bile etkinlik, o gün
/// gelene kadar "Gelecek"te kalır.
enum ClubEventStage { upcoming, active, past }

/// [timestampMs]'in takvim günü bugünden önce mi?
///
/// Son başvuru anını kullanan [isPastEvent]'ten ayrıdır: kulüp panelindeki
/// aşamalar "bugün"ü aktif kabul eder ve mümkünse `eventDateAtMs`e bakar.
bool _isDayBeforeToday(int timestampMs, DateTime now) {
  if (timestampMs <= 0) return false;

  final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final DateTime day = DateTime(date.year, date.month, date.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  return day.isBefore(today);
}

/// Etkinliğin GÜNÜ geçti mi? Web'deki `event-utils.js#isPastEvent` ve
/// sunucudaki `registrations.js#isPastEvent` ile aynı kural: etkinlik günü
/// (yoksa son başvuru günü) bugünden önceyse geçmiştir.
///
/// [isPastEvent] son başvuru ANINA bakar (keşfet/kayıt kapanışı); kulübün
/// etkinlik listesi (iptal / düzenle / listeden kaldır) bunu kullanmamalı:
/// son başvurusu geçmiş ama günü gelmemiş etkinlik hâlâ iptal edilebilir.
bool isEventDayPast(AppEvent event, {DateTime? now}) {
  final int eventDay = event.eventDateAtMs ?? 0;
  final int reference = eventDay > 0 ? eventDay : event.deadlineAtMs;
  return _isDayBeforeToday(reference, now ?? DateTime.now());
}

/// Etkinliğin günü geldi mi? Eski kayıtlarda etkinlik günü yoksa son başvuru
/// günü geri dönüş değeridir; webdeki geriye uyumlulukla aynıdır.
bool _hasClubEventDayArrived(AppEvent event, DateTime now) {
  final int eventDay = event.eventDateAtMs ?? 0;
  final int reference = eventDay > 0 ? eventDay : event.deadlineAtMs;
  if (reference <= 0) return false;

  final DateTime date = DateTime.fromMillisecondsSinceEpoch(reference);
  final DateTime day = DateTime(date.year, date.month, date.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  return !day.isAfter(today);
}

/// Kulübün kendi etkinliğinin listede gösterileceği aşama.
///
/// - Gelecek: etkinlik günü henüz gelmemiş ve yoklama başlatılmamış.
/// - Aktif: etkinlik günü gelmiş ya da kulüp kapı/oturum yoklamasını başlatmış.
/// - Geçmiş: etkinlik günü geçmiş ya da oturumlar tamamlanmış.
///
/// `entryStartedAtMs` bilerek ölçüte dahildir. Kapı yoklaması sonradan
/// kapatılsa bile bu damga etkinliğin bir kez başlatıldığını korur; aksi hâlde
/// etkinlik yanlışlıkla yeniden "Gelecek"e dönerdi.
ClubEventStage getClubEventStage(AppEvent event, {DateTime? now}) {
  final DateTime current = now ?? DateTime.now();
  final int eventDay = event.eventDateAtMs ?? 0;
  final int reference = eventDay > 0 ? eventDay : event.deadlineAtMs;

  if (event.sessionsCompleted || _isDayBeforeToday(reference, current)) {
    return ClubEventStage.past;
  }

  final bool checkinStarted =
      event.entryStartedAtMs > 0 || event.currentSession > 0 || event.entryOpen;
  if (checkinStarted || _hasClubEventDayArrived(event, current)) {
    return ClubEventStage.active;
  }

  return ClubEventStage.upcoming;
}

/// Etkinliğin kendisi (son başvuru değil) bitti mi?
///
/// Belge dağıtımının tek oturumlu etkinliklerdeki kapısı budur: oturumlu
/// etkinlikte kapıyı kulüp "oturumları bitir" diyerek açar, tek oturumluda
/// bitirilecek bir oturum yok — takvim karar verir.
///
/// Sırayla bakılır: bitiş anı (gün + bitiş saati), yoksa etkinlik gününün
/// sonu, o da yoksa son başvuru tarihi. Saat girilmemiş etkinliklerde gün
/// sonuna kadar beklenir; aksi hâlde sabah 09:00'da yapılan bir etkinlik gece
/// yarısına kadar "sürüyor" ya da tam tersi, gün başında "bitmiş" sayılırdı.
bool isEventFinished(AppEvent event, {DateTime? now}) {
  final DateTime current = now ?? DateTime.now();

  final int? endAtMs = event.eventEndAtMs;
  if (endAtMs != null && endAtMs > 0) {
    return !DateTime.fromMillisecondsSinceEpoch(endAtMs).isAfter(current);
  }

  final int? dayAtMs = event.eventDateAtMs;
  if (dayAtMs != null && dayAtMs > 0) {
    final DateTime day = DateTime.fromMillisecondsSinceEpoch(dayAtMs);
    return !DateTime(day.year, day.month, day.day, 23, 59, 59).isAfter(current);
  }

  return isPastEvent(event, now: now);
}

/// Etkinlik ŞU AN yürüyor mu: kapı check-in'i açık ya da bir oturum
/// ilerletilmiş durumda.
///
/// `registrationClosed` bayrağı etkinlik başlarken kendiliğinden kapanır
/// (bkz. `EventRepository.setEntryOpen` ve `advanceSession`) ama kulüp bunu
/// sonradan ELLE geri açabilir (`_toggleRegistrations`). Yürüyen bir
/// etkinlikte bu, keşfe geri dönmeye yetmemeli — kayıt kapısı bu yüzden
/// yalnızca bayrağa değil, etkinliğin o anki durumuna da bakar. Kulüp
/// yürüyen etkinlikte kaydı zaten AÇAMAZ; ekran onu uyarıp geri çevirir
/// (bkz. `_toggleRegistrations`), burası da okuma tarafındaki karşılığıdır.
///
/// Ölçüt bilerek `entryStartedAtMs` (kapı hiç açıldı mı) DEĞİL, `entryOpen`
/// (kapı şu anda açık mı): damga "Bitir" → "Yeniden Başlat" döngüsünde
/// korunduğu için, ölçüt o olsaydı kapısı bir kez açılmış etkinlik bir daha
/// asla keşfe dönemezdi. Oturumu olmayan (`checkin_only`) etkinliklerde geri
/// alınacak bir oturum da olmadığı için bu kalıcı bir çıkmaz olurdu.
///
/// Böylece "başa dönüş" iki adımla tamamlanır ve ikisi de geri alınabilir:
/// kapıyı bitirmek (`entryOpen = false`) ve oturumları en başa (0) almak.
/// Kulüp bu durumda kayıtları yeniden açabilir; oturumlar tek tek 0'a
/// alındığında `advanceSession` zaten kendiliğinden açar.
bool eventHasStarted(AppEvent event) =>
    event.currentSession > 0 || event.entryOpen;

/// İP-B4: başlamış etkinliğe yeni kayıt kapalı mı? Organizatör "başladıktan
/// sonra da kayıt al" dediyse yalnız oturumlar tamamen bitince kapanır.
/// Web: event-utils.js#isRegistrationsReopenBlocked; sunucu:
/// registrations.js#lateRegistrationBlocked.
bool lateRegistrationBlocked(AppEvent event) => event.allowLateRegistration
    ? event.sessionsCompleted
    : eventHasStarted(event);

/// Yeni bir öğrenci bu etkinliğe kaydolabilir mi (tersi: kapalı)?
///
/// Süresi geçmiş VEYA kulübün elle/otomatik kapattığı VEYA fiilen başlamış
/// (bkz. [eventHasStarted]) bir etkinlikte kayıt kapısı kapalı sayılır —
/// üçü de birbirinden bağımsız, herhangi biri yeter.
bool isRegistrationClosed(AppEvent? event, {DateTime? now}) {
  if (event == null) return true;
  return event.registrationClosed ||
      isPastEvent(event, now: now) ||
      lateRegistrationBlocked(event);
}

/// Zaten KAYITLI bir öğrenci için etkinlik gerçekten bitti mi?
///
/// Bilerek [isRegistrationClosed] KULLANILMAZ: o yalnızca YENİ kayıt açılıp
/// açılmadığını söyler. Kulüp kayıtları elle durdurduğunda (kontenjan
/// dolduğunda ya da elle) zaten kayıtlı öğrencinin randevusu hemen "geçmiş"
/// sekmesine düşmemeli, bileti/QR'ı da üretilemez hâle gelmemeli — kulübün
/// tek yaptığı yeni kayıt almayı durdurmaktır. Etkinlik, oturumları bitene VE
/// süresi tam olarak dolana kadar öğrenci için hâlâ "devam eden" sayılır.
bool isEventOverForAttendee(AppEvent? event, {DateTime? now}) {
  if (event == null) return true;
  final bool sessionsDone = !event.isMultiSession || event.sessionsCompleted;
  return sessionsDone && isEventFinished(event, now: now);
}

/// Keşfet/öğrenci listesinde gösterilebilecek aktif etkinlik.
///
/// Görünürlük ve son başvuru kurallarını tek bir noktada tutmak, iki ekranda
/// aynı geçmiş etkinliğin farklı davranmasını engeller.
bool isDiscoverableEvent(AppEvent event, {DateTime? now}) =>
    !event.hiddenGlobally &&
    !event.isLinkOnly &&
    !isRegistrationClosed(event, now: now);

// ── Görünürlük ────────────────────────────────────────────────────────

/// Öğrencinin üniversitesi etkinliğin hedef üniversitelerinden biri mi?
///
/// Kulüp birden fazla üniversite hedefleyebilir; biri tutuyorsa yeter.
bool matchesTargetUniversity(AppEvent event, StudentProfile? profile) {
  final String studentUniversity = foldTr(profile?.university);
  if (studentUniversity.isEmpty) return false;

  return event.targetUniversities.any(
    (String university) => foldTr(university) == studentUniversity,
  );
}

/// Öğrencinin bölümü etkinliğin hedef bölümlerinden biri mi?
///
/// Hedef listesinde gerçek bir bölüm adı ("Bilgisayar Mühendisliği") de,
/// kulübün faaliyet alanı ("Bilgisayar ve Yazılım") da bulunabilir: kulüp
/// bölüm seçmediğinde varsayılan olarak kendi alanı hedeflenir. Bu yüzden
/// tam eşleşme tutmazsa alan<->bölüm anahtar kelime ağırlığına bakılır;
/// aksi hâlde alanla hedeflenen etkinliği hiçbir öğrenci göremezdi.
bool matchesTargetDepartment(AppEvent event, StudentProfile? profile) {
  final String rawDepartment = profile?.department ?? '';
  final String studentDepartment = foldTr(rawDepartment);
  if (studentDepartment.isEmpty) return false;

  return event.targetDepartments.any(
    (String target) =>
        foldTr(target) == studentDepartment ||
        getFieldRelationWeight(rawDepartment, target) >=
            kFieldRelationThreshold,
  );
}

/// Öğrenci bu etkinliği görebilir mi? (hedef kitle filtresi)
bool canStudentSeeEvent(AppEvent event, StudentProfile? profile) {
  if (event.hiddenGlobally) return false;

  switch (event.targetScope) {
    case TargetScope.public:
      return true;
    case TargetScope.university:
      return matchesTargetUniversity(event, profile);
    case TargetScope.department:
      // Yalnızca bölüm kısıtı. Eski kayıtlarda "bölüme özel" aynı zamanda
      // üniversiteyi de kısıtlıyordu; o kayıtlarda hedef üniversite dolu
      // olduğu için burada ek koşul olarak aranır.
      if (!matchesTargetDepartment(event, profile)) return false;
      return event.targetUniversities.isEmpty ||
          matchesTargetUniversity(event, profile);
    case TargetScope.universityDepartment:
      return matchesTargetUniversity(event, profile) &&
          matchesTargetDepartment(event, profile);
    default:
      return false;
  }
}

/// Etkinliği düzenleyen kulübün alanları.
///
/// Kulüpler birden fazla alan seçebilir. Eski kayıtlarda dizi yok; model
/// katmanı bu durumda tekil `clubField`i tek elemanlı listeye indirdiği için
/// burada ayrıca kontrol gerekmez.
List<String> eventClubFields(AppEvent event) =>
    (event.clubFields.isNotEmpty ? event.clubFields : <String>[event.clubField])
        .where((String field) => field.isNotEmpty)
        .toList();

/// Hedef kitle satırında gösterilecek alanlar.
///
/// Etkinlik bir bölüm hedeflemiyorsa (herkese açık ya da yalnızca üniversite
/// kısıtlı) öğrenci en azından kulübün hangi alanda çalıştığını görsün diye
/// kulübün kendi alanları yazılır.
List<String> eventAudienceFields(AppEvent event) =>
    event.targetDepartments.isNotEmpty
    ? event.targetDepartments
    : eventClubFields(event);

/// Öğrencinin bölümü etkinlikle ilişkili mi?
/// Önce tam eşleşme (bölüm == hedef bölüm / sektör / kulübün ALANLARINDAN
/// biri), olmazsa ağırlıklı anahtar kelime eşleşmesi.
///
/// Çoklu alan desteği keşif algoritmasını bozmaz, yalnızca genişletir: tek
/// alanlı bir kulüpte liste tek elemanlı olduğu için sonuç eskisiyle birebir
/// aynı kalır.
bool _isDepartmentRelated(AppEvent event, StudentProfile? profile) {
  final String studentDepartment = foldTr(profile?.department);
  if (studentDepartment.isEmpty) return false;

  final bool exactMatch =
      event.targetDepartments.any(
        (String target) => studentDepartment == foldTr(target),
      ) ||
      studentDepartment == foldTr(event.targetSector) ||
      eventClubFields(
        event,
      ).any((String field) => studentDepartment == foldTr(field));

  if (exactMatch) return true;

  return getDepartmentFieldWeight(event, profile) >= kFieldRelationThreshold;
}

/// Bölüm<->kulüp alanı ilişki gücü. Aynı öncelik kademesindeki etkinlikler
/// arasında sıralama eşitliğini bozmak için kullanılır; kademeleri değiştirmez.
///
/// Kulübün birden fazla alanı varsa **en güçlü** eşleşme geçerlidir: bir
/// etkinliğin, kulübün ikinci alanı öğrenciyle ilgisiz diye sıralamada
/// gerilemesi yanlış olurdu.
double getDepartmentFieldWeight(AppEvent event, StudentProfile? profile) {
  final String department = profile?.department ?? '';
  if (department.isEmpty) return 0;

  double best = 0;
  for (final String field in eventClubFields(event)) {
    final double weight = getFieldRelationWeight(department, field);
    if (weight > best) best = weight;
  }
  return best;
}

/// Keşif önceliği — küçük olan önce gösterilir.
///   0: aynı üniversite + ilgili bölüm
///   1: aynı üniversite
///   2: ilgili bölüm
///   3: genel
int getStudentEventPriority(AppEvent event, StudentProfile? profile) {
  final String studentUniversity = foldTr(profile?.university);

  // Hedef üniversite seçilmediyse ölçüt kulübün kendi üniversitesidir.
  final List<String> eventUniversities = event.targetUniversities.isNotEmpty
      ? event.targetUniversities
      : <String>[event.clubUniversity];

  final bool sameUniversity =
      studentUniversity.isNotEmpty &&
      eventUniversities.any(
        (String university) => foldTr(university) == studentUniversity,
      );
  final bool departmentRelated = _isDepartmentRelated(event, profile);

  if (departmentRelated && sameUniversity) return 0;
  if (sameUniversity) return 1;
  if (departmentRelated) return 2;
  return 3;
}

/// Keşif puan ağırlıkları — web ile aynı (js/modules/events/event-utils.js
/// DISCOVERY_WEIGHTS). Büyük puan önce gösterilir.
abstract final class DiscoveryWeights {
  static const int university = 100;
  static const int departmentExact = 50;
  static const int fieldRelation = 40;

  /// Öğrencinin takip ettiği kulübün etkinliği (ilgiyi kendisi gösterdi).
  static const int followedClub = 60;
}

bool _isSameUniversity(AppEvent event, StudentProfile? profile) {
  final String studentUniversity = foldTr(profile?.university);
  if (studentUniversity.isEmpty) return false;
  final List<String> eventUniversities = event.targetUniversities.isNotEmpty
      ? event.targetUniversities
      : <String>[event.clubUniversity];
  return eventUniversities.any(
    (String university) => foldTr(university) == studentUniversity,
  );
}

bool _isDepartmentExact(AppEvent event, StudentProfile? profile) {
  final String studentDepartment = foldTr(profile?.department);
  if (studentDepartment.isEmpty) return false;
  return event.targetDepartments.any(
        (String target) => studentDepartment == foldTr(target),
      ) ||
      studentDepartment == foldTr(event.targetSector) ||
      eventClubFields(
        event,
      ).any((String field) => studentDepartment == foldTr(field));
}

/// Web ile aynı keşif puanı: üniversite +100, bölüm tam eşleşme +50,
/// kulüp alanı yakınlığı 0–40, takip edilen kulüp +60.
int getStudentEventScore(
  AppEvent event,
  StudentProfile? profile, {
  Set<String> followedClubIds = const <String>{},
}) {
  int score = 0;
  if (event.clubId.isNotEmpty && followedClubIds.contains(event.clubId)) {
    score += DiscoveryWeights.followedClub;
  }
  if (_isSameUniversity(event, profile)) score += DiscoveryWeights.university;
  if (_isDepartmentExact(event, profile)) {
    score += DiscoveryWeights.departmentExact;
  }
  score += (getDepartmentFieldWeight(event, profile) *
          DiscoveryWeights.fieldRelation)
      .round();
  return score;
}

/// dashboard.js#renderEvents sıralaması: puan (büyükten küçüğe) ->
/// geçmiş olanlar sona -> son kayda en yakın olan önce.
List<AppEvent> sortEventsForStudent(
  List<AppEvent> events,
  StudentProfile? profile, {
  Set<String> followedClubIds = const <String>{},
}) {
  final List<AppEvent> sorted = List<AppEvent>.of(events);
  final Map<String, int> scores = <String, int>{
    for (final AppEvent e in sorted)
      e.id: getStudentEventScore(e, profile, followedClubIds: followedClubIds),
  };

  sorted.sort((AppEvent a, AppEvent b) {
    final int scoreA = scores[a.id] ?? 0;
    final int scoreB = scores[b.id] ?? 0;
    if (scoreA != scoreB) return scoreB.compareTo(scoreA);

    final bool pastA = isPastEvent(a);
    final bool pastB = isPastEvent(b);
    if (pastA != pastB) return pastA ? 1 : -1;

    // Geçmiş etkinliklerde en yeni önce, aktiflerde en yakın son kayıt önce.
    return pastA
        ? b.deadlineAtMs.compareTo(a.deadlineAtMs)
        : a.deadlineAtMs.compareTo(b.deadlineAtMs);
  });

  return sorted;
}

/// Sıralama için etkinliğin zamanı (başlangıç saati > gün > son başvuru).
/// Web: event-utils.js#eventSortTime.
int eventSortTime({int? startAtMs, int? dateAtMs, int deadlineAtMs = 0}) {
  if ((startAtMs ?? 0) > 0) return startAtMs!;
  if ((dateAtMs ?? 0) > 0) return dateAtMs!;
  return deadlineAtMs > 0 ? deadlineAtMs : 0;
}

/// Bilet/etkinlik listeleri (İP-B2): günü gelmemiş (bugün dahil) etkinlikler
/// EN YAKIN tarih en üstte; günü geçmişler onlardan sonra, en yeni önce;
/// tarihsizler en sonda. Aynı zamanda olanlarda son kaydolunan önce.
/// Web: event-utils.js#compareByUpcomingEvent.
int compareByUpcomingEvent({
  required int timeA,
  required int timeB,
  int registeredA = 0,
  int registeredB = 0,
  DateTime? now,
}) {
  final int byRegistration = registeredB.compareTo(registeredA);
  if (timeA <= 0 || timeB <= 0) {
    final int missing = (timeA > 0 ? 0 : 1) - (timeB > 0 ? 0 : 1);
    return missing != 0 ? missing : byRegistration;
  }
  final DateTime current = now ?? DateTime.now();
  final bool pastA = _isDayBeforeToday(timeA, current);
  final bool pastB = _isDayBeforeToday(timeB, current);
  if (pastA != pastB) return pastA ? 1 : -1;
  if (timeA != timeB) {
    return pastA ? timeB.compareTo(timeA) : timeA.compareTo(timeB);
  }
  return byRegistration;
}
