/// Öğrenci ekranlarına özgü türetilmiş sağlayıcılar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../domain/event_utils.dart';
import '../../models/event.dart';
import '../../models/profiles.dart';
import '../../services/event_repository.dart';
import '../../state/providers.dart';

/// Öğrencinin görebileceği, süresi dolmamış etkinlikler — keşif önceliğine
/// göre sıralanmış.
///
/// dashboard.js#loadStudentVisibleEvents ile aynı: tüm etkinlikler çekilir,
/// görünürlük ve tarih filtresi istemcide uygulanır. Kayıtların açılması ve
/// kapanması keşfete canlı yansır.
final StreamProvider<List<AppEvent>> studentVisibleEventsProvider =
    StreamProvider<List<AppEvent>>((Ref ref) {
      final StudentProfile? profile = ref.watch(studentProfileProvider).value;
      return ref.watch(eventRepositoryProvider).watchAllEvents().map((
        List<AppEvent> all,
      ) {
        // `isPastEvent` yalnızca son başvuru tarihine bakar; kulübün kaydı elle
        // kapattığı etkinlikler de kartta "Süresi Geçmiştir" göründüğü için
        // keşifte yer almamalı — bu yüzden kapalılığın tamamı kontrol edilir.
        final List<AppEvent> visible = all
            .where(
              (AppEvent event) =>
                  canStudentSeeEvent(event, profile) &&
                  isDiscoverableEvent(event),
            )
            .toList();

        return sortEventsForStudent(visible, profile);
      });
    });

/// Öğrencinin kayıtlı olduğu etkinlik kimlikleri (canlı).
final Provider<Set<String>> registeredEventIdsProvider = Provider<Set<String>>((
  Ref ref,
) {
  final List<EventRegistration> registrations =
      ref.watch(studentRegistrationsProvider).value ??
      const <EventRegistration>[];

  return registrations
      .map((EventRegistration r) => r.eventId)
      .where((String id) => id.isNotEmpty)
      .toSet();
});

/// İP-K: öğrencinin kayıtları etkinliğe göre (ödeme durumu için).
final Provider<Map<String, EventRegistration>> registrationByEventProvider =
    Provider<Map<String, EventRegistration>>((Ref ref) {
      final List<EventRegistration> registrations =
          ref.watch(studentRegistrationsProvider).value ??
          const <EventRegistration>[];
      return <String, EventRegistration>{
        for (final EventRegistration r in registrations)
          if (r.eventId.isNotEmpty) r.eventId: r,
      };
    });

/// İP-K: öğrencinin bekleme listesinde olduğu etkinlikler (canlı).
final StreamProvider<Set<String>> waitlistedEventIdsProvider =
    StreamProvider<Set<String>>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream<Set<String>>.value(const <String>{});
      return ref.watch(eventRepositoryProvider).watchStudentWaitlist(uid);
    });

/// Öğrencinin tüm kayıtları — canlı. Kulüp QR okuttuğunda oturum sayısı
/// sayfa yenilenmeden güncellenir (web'deki onSnapshot davranışı).
final StreamProvider<List<EventRegistration>> studentRegistrationsProvider =
    StreamProvider<List<EventRegistration>>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) {
        return Stream<List<EventRegistration>>.value(
          const <EventRegistration>[],
        );
      }

      return ref.watch(eventRepositoryProvider).watchStudentRegistrations(uid);
    });

/// Tek etkinliğin **canlı** hâli
/// (student-appointments.js#startModalEventListener karşılığı).
///
/// `appointmentsProvider` etkinlikleri tek seferlik okur; detay penceresi
/// açıkken kulüp yeni oturumu başlattığında "QR Okut" düğmesinin kendiliğinden
/// aktifleşmesi için etkinlik dokümanının canlı dinlenmesi gerekiyor.
// ignore: always_specify_types
final liveEventProvider = StreamProvider.family<AppEvent?, String>((
  Ref ref,
  String eventId,
) {
  if (eventId.isEmpty) return Stream<AppEvent?>.value(null);
  return ref.watch(eventRepositoryProvider).watchEvent(eventId);
});

/// Oturumlu etkinlikte "QR Okut" düğmesinin durumu.
///
/// Düğme hiçbir durumda gizlenmez — yalnızca [ready] iken basılabilir, diğer
/// durumlarda pasif kalır ve altında sebebi yazar. Kaybolan bir düğme
/// "etkinlikte QR yok" izlenimi veriyordu; oysa çoğu zaman kulüp henüz yeni
/// oturumu açmamış oluyor.
enum SessionScanState {
  /// Kulüp ilk oturumu henüz başlatmadı.
  notStarted,

  /// Aktif oturum var ve bu oturumun girişi yapılmadı.
  ready,

  /// Aktif oturumun QR'ı zaten okutuldu; yeni oturumu beklemek gerekiyor.
  alreadyScanned,

  /// Kulüp tüm oturumları kapattı.
  completed,

  /// Etkinlik silinmiş — okunacak bir oturum kalmadı.
  unavailable,
}

/// Kayıt + ilgili etkinlik verisi bir arada.
class RegistrationWithEvent {
  const RegistrationWithEvent({
    required this.registration,
    required this.event,
  });

  final EventRegistration registration;

  /// Etkinlik silinmiş olabilir; bu durumda kayıttaki kopya alanlar kullanılır.
  final AppEvent? event;

  /// Canlı etkinlik verisi geldiğinde aynı kaydın tazelenmiş kopyası.
  RegistrationWithEvent withLiveEvent(AppEvent? live) => live == null
      ? this
      : RegistrationWithEvent(registration: registration, event: live);

  /// student-appointments.js#resolveDisplayEvent — canlı etkinlik verisi
  /// yoksa kayıttaki denormalize alanlara düşülür.
  String get title => (event?.title.isNotEmpty ?? false)
      ? event!.title
      : registration.eventTitle;

  /// Kapak adresi. Kulüp etkinliğe görsel eklemediyse boş döner; `EventImage`
  /// o durumda gri marka perdesini çizer.
  String get imageUrl {
    final String live = event?.imageUrl ?? '';
    if (live.isNotEmpty) return isAutoCoverUrl(live) ? '' : live;

    final String copy = registration.eventImageUrl;
    return isAutoCoverUrl(copy) ? '' : copy;
  }

  String get clubName => (event?.clubName.isNotEmpty ?? false)
      ? event!.clubName
      : registration.clubName;

  /// Listelerde sıralama zamanı (bkz. event_utils.dart#compareByUpcomingEvent).
  int get sortTimeMs => eventSortTime(
    startAtMs: event?.eventStartAtMs,
    dateAtMs: event?.eventDateAtMs,
    deadlineAtMs: deadlineAtMs,
  );

  int get deadlineAtMs => (event?.deadlineAtMs ?? 0) > 0
      ? event!.deadlineAtMs
      : registration.deadlineAtMs;

  int get sessionCount => event?.sessionCount ?? 1;

  bool get isMultiSession => event?.isMultiSession ?? false;

  int? get certificateThresholdPercent => event?.certificateThresholdPercent;

  int get currentSession => event?.currentSession ?? 0;

  /// Etkinlik silinmişse ya da GERÇEKTEN bitmişse kayıt "kapalı" sayılır
  /// (bkz. [isEventOverForAttendee]).
  ///
  /// Bilerek [isRegistrationClosed] KULLANILMAZ: kulübün kayıtları elle
  /// durdurması, öğrenci zaten kayıtlıyken randevuyu "geçmiş" sekmesine
  /// düşürmemeli ve biletini/QR'ını üretmesini engellememeli — kulübün tek
  /// etkisi yeni kayıtların kapanmasıdır.
  bool get isClosed => isEventOverForAttendee(event) || isCancelled;

  /// İP-K: kulüp etkinliği iptal etti (kayıt korunur, bilet geçersiz).
  bool get isCancelled => event?.cancelled ?? false;

  /// İP-K: ücretli etkinlikte ödeme henüz onaylanmadı.
  bool get paymentPending => registration.paymentPendingFor(event);

  /// Karttaki/penceredeki durum rozeti: çeviri anahtarı + "kötü/uyarı/iyi".
  ///   iptal edildi > süresi doldu > ödeme bekleniyor > kayıtlı
  ({String key, int tone}) get statusBadge => isCancelled
      ? (key: 'registration.status.cancelled', tone: -1)
      : isEventOverForAttendee(event)
      ? (key: 'dashboard.status.expired', tone: -1)
      : paymentPending
      ? (key: 'registration.status.paymentPending', tone: 0)
      : (key: 'dashboard.status.registered', tone: 1);

  /// student-appointments.js#updateQrButtonVisibility:
  ///  • Tek oturumlu: giriş onaylandıysa QR üretilemez.
  ///  • Çok oturumlu: aktif oturumda giriş yapıldıysa üretilemez; kulüp yeni
  ///    oturum başlatınca tekrar üretilebilir.
  bool get canGenerateQr {
    if (isClosed) return false;

    if (isMultiSession) {
      final int lastAttended = registration.lastAttendedSession;
      return !(lastAttended > 0 && lastAttended >= currentSession);
    }

    return !registration.isCheckedIn;
  }

  /// Kapıda görevliye gösterilen **bilet** üretilebilir mi?
  /// (js/modules/events/student-ticket.js#canShowStudentTicket)
  ///
  /// Ölçüt oturum sayısı DEĞİL etkinliğin modudur: "Sadece Yoklama" modunda
  /// kapı girişi yoktur, dolayısıyla bilet de yoktur — o etkinlikte tek QR
  /// salondaki oturum kodudur ve onu öğrenci "QR Okut" ile okutur.
  ///
  /// Giriş bir kez alındıktan sonra bilet gizlenir; aynı bilet ikinci kez işe
  /// yaramaz (kapıda "zaten giriş yapmış" uyarısı çıkar).
  bool get canShowTicket =>
      event != null &&
      !event!.cancelled &&
      event!.hasDoorCheckin &&
      !registration.isCheckedIn;

  /// Oturumlu etkinlikte QR okutma düğmesinin durumu.
  ///
  /// Bilerek [isClosed] KULLANILMAZ: o tek bir "bitti mi" bilgisi verir,
  /// oysa düğme "henüz başlamadı" / "sırası geldi" / "bu oturum zaten
  /// okutuldu" durumlarını AYRI AYRI göstermek zorunda — kaynak burada
  /// oturum durumudur; firestore.rules'un öğrenci girişi için baktığı şart
  /// da aynı
  /// (`sessionsCompleted` + `currentSession`).
  SessionScanState get sessionScanState {
    if (event == null) return SessionScanState.unavailable;
    if (event!.sessionsCompleted) return SessionScanState.completed;

    // Kulüp henüz ilk oturumu başlatmadı: ortada okutulacak bir QR yok.
    if (currentSession < 1) return SessionScanState.notStarted;
    if (!event!.hasActiveSessionQr) return SessionScanState.unavailable;

    // Bu oturumun QR'ı okutulmuş; kulüp yeni oturum açınca tekrar açılır.
    return registration.lastAttendedSession >= currentSession
        ? SessionScanState.alreadyScanned
        : SessionScanState.ready;
  }

  /// Katılım yüzdesi (çok oturumlu etkinlikler için).
  int get attendancePercent => isMultiSession
      ? ((registration.sessionsAttended / sessionCount) * 100).round().clamp(
          0,
          100,
        )
      : (registration.isCheckedIn ? 100 : 0);

  bool get hasEarnedCertificate {
    final int? threshold = certificateThresholdPercent;
    return threshold != null && attendancePercent >= threshold;
  }
}

/// Kayıtları ilgili etkinlik verisiyle zenginleştirir ve son başvuru
/// tarihine göre sıralar (student-appointments.js#handleRegistrationsSnapshot).
final FutureProvider<List<RegistrationWithEvent>> appointmentsProvider =
    FutureProvider<List<RegistrationWithEvent>>((Ref ref) async {
      final List<EventRegistration> registrations =
          ref.watch(studentRegistrationsProvider).value ??
          const <EventRegistration>[];

      if (registrations.isEmpty) return const <RegistrationWithEvent>[];

      final EventRepository repo = ref.watch(eventRepositoryProvider);

      // Aynı etkinliğe birden fazla kayıt olamaz, yine de tekilleştiriyoruz.
      final Set<String> eventIds = registrations
          .map((EventRegistration r) => r.eventId)
          .where((String id) => id.isNotEmpty)
          .toSet();

      final List<AppEvent?> fetched = await Future.wait<AppEvent?>(
        eventIds.map((String id) => repo.fetchEvent(id)),
      );

      final Map<String, AppEvent?> byId = <String, AppEvent?>{
        for (int i = 0; i < eventIds.length; i++)
          eventIds.elementAt(i): fetched[i],
      };

      final List<RegistrationWithEvent> items = registrations
          .map(
            (EventRegistration r) =>
                RegistrationWithEvent(registration: r, event: byId[r.eventId]),
          )
          .toList();

      // İP-B2: en yakın tarihli etkinlik en üstte (eskiden son başvuruya
      // göre sıralanıyordu).
      final DateTime now = DateTime.now();
      items.sort(
        (RegistrationWithEvent a, RegistrationWithEvent b) =>
            compareByUpcomingEvent(
              timeA: a.sortTimeMs,
              timeB: b.sortTimeMs,
              registeredA: a.registration.registeredAtMs,
              registeredB: b.registration.registeredAtMs,
              now: now,
            ),
      );

      return items;
    });

/// Öğrencinin belgeleri (canlı) — kulüp yeni belge dağıtınca liste güncellenir.
final StreamProvider<List<StudentCertificate>> studentCertificatesProvider =
    StreamProvider<List<StudentCertificate>>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) {
        return Stream<List<StudentCertificate>>.value(
          const <StudentCertificate>[],
        );
      }

      return ref.watch(eventRepositoryProvider).watchStudentCertificates(uid);
    });
