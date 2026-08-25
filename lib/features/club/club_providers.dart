/// Kulüp ekranlarına özgü türetilmiş sağlayıcılar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/event_utils.dart';
import '../../domain/registration_capacity.dart';
import '../../models/event.dart';
import '../../models/profiles.dart';
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

/// Kulüp listesindeki üç grup: aktif, beklemede (kayıtları durdurulmuş ama
/// süresi geçmemiş) ve geçmiş — club-events.js#renderEvents ile aynı ayrım.
class ClubEventGroups {
  const ClubEventGroups({
    required this.active,
    required this.pending,
    required this.past,
  });

  final List<AppEvent> active;
  final List<AppEvent> pending;
  final List<AppEvent> past;

  bool get isEmpty => active.isEmpty && pending.isEmpty && past.isEmpty;
}

ClubEventGroups groupClubEvents(List<AppEvent> events) {
  // Kulüp listesinden kaldırılmış geçmiş etkinlikler hiçbir grupta görünmez.
  final List<AppEvent> visible = events
      .where((AppEvent event) => !event.hiddenFromClubList)
      .toList();

  final List<AppEvent> past = visible.where(isPastEvent).toList()
    ..sort((AppEvent a, AppEvent b) =>
        b.deadlineAtMs.compareTo(a.deadlineAtMs));

  final List<AppEvent> pending = visible
      .where((AppEvent e) => !isPastEvent(e) && e.registrationClosed)
      .toList()
    ..sort((AppEvent a, AppEvent b) =>
        a.deadlineAtMs.compareTo(b.deadlineAtMs));

  final List<AppEvent> active = visible
      .where((AppEvent e) => !isPastEvent(e) && !e.registrationClosed)
      .toList()
    ..sort((AppEvent a, AppEvent b) =>
        a.deadlineAtMs.compareTo(b.deadlineAtMs));

  return ClubEventGroups(active: active, pending: pending, past: past);
}

final Provider<ClubEventGroups> clubEventGroupsProvider =
    Provider<ClubEventGroups>((Ref ref) {
  final List<AppEvent> events =
      ref.watch(clubEventsProvider).value ?? const <AppEvent>[];
  return groupClubEvents(events);
});

/// Kulübün keşfet akışı: kendi profilini "sözde öğrenci" gibi kullanarak
/// diğer kulüplerin etkinliklerini görür (club-dashboard.js#loadClubEvents).
///
/// Kulübün alanı bölüm yerine geçer; birden fazla alan seçildiyse ilki
/// temsilci olarak kullanılır — ağırlık hesabı zaten tüm alanlara bakıyor.
StudentProfile? pseudoStudentFromClub(ClubProfile? club) {
  if (club == null) return null;

  return StudentProfile.fromMap(club.uid, <String, dynamic>{
    'university': club.university,
    'department': club.clubFields.isEmpty ? club.clubField : club.clubFields.first,
    'city': club.city,
  });
}

final FutureProvider<List<AppEvent>> clubDiscoverEventsProvider =
    FutureProvider<List<AppEvent>>((Ref ref) async {
  final ClubProfile? club = ref.watch(clubProfileProvider).value;
  final StudentProfile? pseudo = pseudoStudentFromClub(club);

  final List<AppEvent> all =
      await ref.watch(eventRepositoryProvider).fetchAllEvents();

  final List<AppEvent> visible = all
      .where((AppEvent event) =>
          canStudentSeeEvent(event, pseudo) && !isRegistrationClosed(event))
      .toList();

  return sortEventsForStudent(visible, pseudo);
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
    return Stream<List<EventRegistration>>.value(const <EventRegistration>[]);
  }
  return ref.watch(eventRepositoryProvider).watchEventRegistrations(eventId);
});

/// Tek bir etkinliğin canlı hâli (oturum durumu modal açıkken değişebilir).
// ignore: always_specify_types
final clubEventProvider =
    StreamProvider.family<AppEvent?, String>((Ref ref, String eventId) {
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
final quotaStatusProvider =
    StreamProvider.family<QuotaStatus, String>((Ref ref, String eventId) {
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
  List<EventRegistration> registrations,
) {
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
/// etkinlik bittiği anda.
bool canDistributeCertificates(AppEvent event, {DateTime? now}) =>
    event.isMultiSession
        ? event.sessionsCompleted
        : isEventFinished(event, now: now);
