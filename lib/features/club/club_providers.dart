/// Kulüp ekranlarına özgü türetilmiş sağlayıcılar.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/event_utils.dart';
import '../../domain/registration_capacity.dart';
import '../../models/club_block.dart';
import '../../models/event.dart';
import '../../models/profiles.dart';
import '../../services/door_gate.dart';
import '../../services/firebase_refs.dart';
import '../../state/connectivity.dart';
import '../../state/providers.dart';

/// Kulübün kendi etkinlikleri — canlı.
///
/// club-events.js `where("clubId", "==", uid)` sorgusunun karşılığı. Oturum
/// ilerletme / kayıt açma-kapama gibi işlemler sayfa yenilenmeden listeye
/// yansısın diye dinleyici (tek seferlik okuma değil) kullanılır.
final StreamProvider<List<AppEvent>> clubEventsProvider =
    StreamProvider<List<AppEvent>>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream<List<AppEvent>>.value(const <AppEvent>[]);

      return ref.watch(eventRepositoryProvider).watchClubEvents(uid);
    });

/// Kulüp listesindeki üç grup: gelecek, aktif ve geçmiş.
///
/// Ayrım, webdeki `club-events.js#renderEvents` ile aynı olarak etkinlik
/// gününe ve yoklamanın başlayıp başlamadığına göre yapılır. `registrationClosed`
/// tek başına bir grup değildir; yalnızca yeni kayıt alınıp alınmadığını söyler.
class ClubEventGroups {
  const ClubEventGroups({
    required this.active,
    required this.upcoming,
    required this.past,
  });

  final List<AppEvent> active;
  final List<AppEvent> upcoming;
  final List<AppEvent> past;

  bool get isEmpty => active.isEmpty && upcoming.isEmpty && past.isEmpty;
}

ClubEventGroups groupClubEvents(List<AppEvent> events, {DateTime? now}) {
  // Kulüp listesinden kaldırılmış geçmiş etkinlikler hiçbir grupta görünmez.
  final List<AppEvent> visible = events
      .where((AppEvent event) => !event.hiddenFromClubList)
      .toList();
  final DateTime current = now ?? DateTime.now();

  final List<AppEvent> active = <AppEvent>[];
  final List<AppEvent> upcoming = <AppEvent>[];
  final List<AppEvent> past = <AppEvent>[];

  for (final AppEvent event in visible) {
    switch (getClubEventStage(event, now: current)) {
      case ClubEventStage.active:
        active.add(event);
        break;
      case ClubEventStage.upcoming:
        upcoming.add(event);
        break;
      case ClubEventStage.past:
        past.add(event);
        break;
    }
  }

  // Web'de gelecek ve aktifler en yakın tarih önce, geçmişler en yeni önce
  // sıralanır.
  active.sort(
    (AppEvent a, AppEvent b) => a.deadlineAtMs.compareTo(b.deadlineAtMs),
  );
  upcoming.sort(
    (AppEvent a, AppEvent b) => a.deadlineAtMs.compareTo(b.deadlineAtMs),
  );
  past.sort(
    (AppEvent a, AppEvent b) => b.deadlineAtMs.compareTo(a.deadlineAtMs),
  );

  return ClubEventGroups(active: active, upcoming: upcoming, past: past);
}

final Provider<ClubEventGroups> clubEventGroupsProvider =
    Provider<ClubEventGroups>((Ref ref) {
      final List<AppEvent> events =
          ref.watch(clubEventsProvider).value ?? const <AppEvent>[];
      return groupClubEvents(events);
    });

/// Kulübün keşfet akışında SIRALAMA için kullanılan "sözde öğrenci" profili
/// (club-dashboard.js#loadClubEvents).
///
/// Kulübün alanı bölüm yerine geçer; birden fazla alan seçildiyse ilki
/// temsilci olarak kullanılır — ağırlık hesabı zaten tüm alanlara bakıyor.
///
/// Görünürlük kararında kullanılmaz; gerekçesi için
/// [clubDiscoverEventsProvider].
StudentProfile? pseudoStudentFromClub(ClubProfile? club) {
  if (club == null) return null;

  return StudentProfile.fromMap(club.uid, <String, dynamic>{
    'university': club.university,
    'department': club.clubFields.isEmpty
        ? club.clubField
        : club.clubFields.first,
    'city': club.city,
  });
}

final StreamProvider<List<AppEvent>>
clubDiscoverEventsProvider = StreamProvider<List<AppEvent>>((Ref ref) {
  final ClubProfile? club = ref.watch(clubProfileProvider).value;
  final StudentProfile? pseudo = pseudoStudentFromClub(club);

  return ref.watch(eventRepositoryProvider).watchDiscoverableEvents().map((
    List<AppEvent> all,
  ) {
    // Hedef kitle filtresi (`canStudentSeeEvent`) BİLEREK uygulanmaz.
    // `targetScope` kulübün kime KAYIT açtığını söyler, etkinliği kimin
    // görebileceğini değil; kulüp keşfette kaydolacak bir aday değil, "başka
    // kulüpler ne yapıyor" diye bakan bir izleyicidir. Sözde öğrenci profilinin
    // "bölümü" kulübün alanı olduğu için, bölüme/üniversiteye kısıtlı aktif
    // etkinliklerin çoğu bu filtreye takılıp keşiften düşüyordu; kulüp profili
    // henüz yüklenmemişken de (pseudo == null) liste yalnızca herkese açık
    // etkinliklere iniyordu.
    //
    // Tek ölçüt etkinliğin AKTİF olmasıdır: kulübün herkesten kaldırdığı
    // (`hiddenGlobally`), süresi geçmiş, kaydı kapatılmış ya da fiilen başlamış
    // etkinlikler yine dışarıda kalır (bkz. [isDiscoverableEvent]).
    final List<AppEvent> visible = all.where(isDiscoverableEvent).toList();

    // Sözde öğrenci profili filtre olarak değil, yalnızca SIRALAMA ölçütü
    // olarak kullanılmaya devam eder: kulübün üniversitesine/alanına yakın
    // etkinlikler listenin başında görünür, gerisi arkasından gelir.
    return sortEventsForStudent(visible, pseudo);
  });
});

/// Seçili etkinliğin kayıtları — canlı.
///
/// Kulüp QR okuturken ya da öğrenci kendi telefonundan oturum QR'ını
/// okuttuğunda liste kendiliğinden güncellenir.
// Aile (family) sağlayıcılarının tipi flutter_riverpod barrel'ında dışa
// aktarılmıyor; tür çıkarımına bırakılıyor.
// ignore: always_specify_types
final eventRegistrationsProvider =
    StreamProvider.family<List<EventRegistration>, String>((
      Ref ref,
      String eventId,
    ) {
      if (eventId.isEmpty) {
        return Stream<List<EventRegistration>>.value(
          const <EventRegistration>[],
        );
      }
      return ref
          .watch(eventRepositoryProvider)
          .watchEventRegistrations(eventId);
    });

/// Tek bir etkinliğin canlı hâli (oturum durumu modal açıkken değişebilir).
// ignore: always_specify_types
final clubEventProvider = StreamProvider.family<AppEvent?, String>((
  Ref ref,
  String eventId,
) {
  if (eventId.isEmpty) return Stream<AppEvent?>.value(null);
  return ref.watch(eventRepositoryProvider).watchEvent(eventId);
});

/// Etkinliğin kontenjan doluluğu — canlı.
///
/// Kontenjan parça sayaçlarında tutuluyor (tek sayı olarak saklamak o
/// dokümanı darboğaz yapardı, bkz. `docs/kayit-kapasitesi.md` §1.3), bu
/// yüzden doluluk okurken toplanır. Parça sayısı en çok 32 olduğundan
/// dinleyici ucuz.
// ignore: always_specify_types
final quotaStatusProvider = StreamProvider.family<QuotaStatus, String>((
  Ref ref,
  String eventId,
) {
  if (eventId.isEmpty) {
    return Stream<QuotaStatus>.value(QuotaStatus.untracked);
  }
  return ref.watch(eventRepositoryProvider).watchQuotaStatus(eventId);
});

/// Belge hakkı kazanan kayıtlar.
///
/// Oturumlu etkinlikte: eşik girildiyse yüzdeye göre, girilmediyse en az bir
/// oturuma katılanlar (club-events.js#distributeCertificates ile aynı kural).
///
/// Tek oturumlu etkinlikte: girişi onaylanan herkes. Oturum sayacı
/// (`sessionsAttended`) yalnızca çok oturumlu etkinliklerde işletiliyor
/// (bkz. `EventRepository.markCheckInByClub`); tek oturumluda yoklamanın tek
/// kaydı `checkedInAtMs`. Sayaç kuralı burada da uygulandığı için tek
/// oturumlu etkinlikte hak sahibi listesi HER ZAMAN boş çıkıyor, yüklenen
/// belge hiçbir öğrenciye ulaşmıyordu. Eşik alanı bu etkinliklerde forma
/// hiç çıkmaz; eski kayıtlarda dolu kalmışsa da dikkate alınmaz — tek
/// oturumda katılım ya %0'dır ya %100.
List<EventRegistration> certificateEligible(
  AppEvent event,
  List<EventRegistration> allRegistrations,
) {
  // İP-K: ücretli etkinlikte ödemesi onaylanmamış kayıt belge hakkı kazanmaz.
  final List<EventRegistration> registrations = allRegistrations
      .where((EventRegistration reg) => !reg.paymentPendingFor(event))
      .toList();
  if (!event.isMultiSession) {
    return registrations
        .where(
          (EventRegistration reg) =>
              reg.isCheckedIn || reg.sessionsAttended >= 1,
        )
        .toList();
  }

  final int sessionCount = event.sessionCount;
  final int? threshold = event.certificateThresholdPercent;

  return registrations.where((EventRegistration reg) {
    if (reg.sessionsAttended < 1) return false;
    if (threshold == null) return true;
    return (reg.sessionsAttended / sessionCount) * 100 >= threshold;
  }).toList();
}

/// Belge yükleme/dağıtma kapısı açık mı?
///
/// Oturumlu etkinlikte kapıyı kulüp açar ("oturumları bitir"): oturumlar
/// sürerken yüklenen belge, yoklaması tamamlanmamış katılımcılara ulaşmıyordu.
/// Tek oturumlu etkinlikte bitirilecek bir oturum yok; kapıyı takvim açar —
/// etkinlik BİTTİĞİ anda. Son başvuru tarihi artık kapıyı açmaz: son başvurusu
/// geçmiş ama henüz yapılmamış etkinlikte belge dağıtılamaz.
///
/// Etkinlik/bitiş günü olmayan eski kayıtlarda [isEventFinished] zaten son
/// başvuru tarihine geri döner. Bu belge dağıtım kuralı, Etkinliklerim
/// listesinin [getClubEventStage] ile belirlenen görünüm aşamasından ayrıdır.
bool canDistributeCertificates(AppEvent event, {DateTime? now}) =>
    event.isMultiSession
    ? event.sessionsCompleted
    : isEventFinished(event, now: now);

/// Kapı denetleyicisi (İP-O): cihazdaki bilet listesi + bekleyen okumalar.
///
/// Kulüp oturumu başına tek örnek: etkinlik ekranı listeyi buraya yazar
/// (internetsiz kapı için), okutma ekranı da aynı örneği kullanır.
final FutureProvider<DoorGate?> doorGateProvider = FutureProvider<DoorGate?>((
  Ref ref,
) async {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final DoorGate gate = DoorGate(
    clubId: uid,
    prefs: prefs,
    backend: GateBackend.firestore(uid),
    isOnline: () => ref.read(onlineProvider),
  );
  ref.onDispose(gate.dispose);
  return gate;
});

/// İP-K: kulübün etkinliğinin bekleme listesi uzunluğu (toplama sorgusu).
/// İşlemlerden sonra `ref.invalidate` ile tazelenir.
// ignore: always_specify_types
final eventWaitlistCountProvider = FutureProvider.family<int, String>(
  (Ref ref, String eventId) =>
      ref.watch(eventRepositoryProvider).countEventWaitlist(eventId),
);

/// İP-KB: kulübün engellediği öğrenciler (en yeni önce), canlı.
final StreamProvider<List<ClubBlock>> clubBlocksProvider =
    StreamProvider<List<ClubBlock>>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) {
        return Stream<List<ClubBlock>>.value(const <ClubBlock>[]);
      }
      return fbDb
          .collection('club_student_blocks')
          .where('clubId', isEqualTo: uid)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snap) {
            final List<ClubBlock> list = snap.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      ClubBlock.fromMap(d.data()),
                )
                .toList();
            list.sort(
              (ClubBlock a, ClubBlock b) =>
                  b.createdAtMs.compareTo(a.createdAtMs),
            );
            return list;
          });
    });
