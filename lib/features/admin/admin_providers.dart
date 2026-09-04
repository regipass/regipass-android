/// Yönetici ekranlarına özgü sağlayıcılar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/admin_stats.dart';
import '../../models/profiles.dart';
import '../../state/providers.dart';

/// Onay bekleyen kulüpler — canlı.
final StreamProvider<List<ClubProfile>> pendingClubsProvider =
    StreamProvider<List<ClubProfile>>(
      (Ref ref) => ref.watch(adminRepositoryProvider).watchPendingClubs(),
    );

/// Tüm öğrenciler — canlı (engelleme ekranı ve istatistikler kullanır).
final StreamProvider<List<StudentProfile>> allStudentsProvider =
    StreamProvider<List<StudentProfile>>(
      (Ref ref) => ref.watch(adminRepositoryProvider).watchStudents(),
    );

/// Tüm kulüpler — istatistiklerde şehir/üniversite dağılımı için.
final FutureProvider<List<ClubProfile>> allClubsProvider =
    FutureProvider<List<ClubProfile>>(
      (Ref ref) => ref.watch(adminRepositoryProvider).fetchAllClubs(),
    );

/// İstatistik ekranının okuduğu hazır veri.
final Provider<AsyncValue<AdminStats>> adminStatsProvider =
    Provider<AsyncValue<AdminStats>>((Ref ref) {
      final AsyncValue<List<StudentProfile>> students = ref.watch(
        allStudentsProvider,
      );
      final AsyncValue<List<ClubProfile>> clubs = ref.watch(allClubsProvider);

      // İki kaynaktan biri hâlâ yükleniyorsa ekran yükleniyor kalır; biri
      // hata verdiyse hatayı olduğu gibi taşırız.
      if (students.isLoading || clubs.isLoading) {
        return const AsyncValue<AdminStats>.loading();
      }
      if (students.hasError) {
        return AsyncValue<AdminStats>.error(
          students.error!,
          students.stackTrace ?? StackTrace.current,
        );
      }
      if (clubs.hasError) {
        return AsyncValue<AdminStats>.error(
          clubs.error!,
          clubs.stackTrace ?? StackTrace.current,
        );
      }

      return AsyncValue<AdminStats>.data(
        computeAdminStats(
          students.value ?? const <StudentProfile>[],
          clubs.value ?? const <ClubProfile>[],
        ),
      );
    });

// ── Engelleme ekranı (admin-ban.js) ───────────────────────────────────
//
// Ekran iki listeyi birden taşır: ÖĞRENCİLER ve KULÜPLER. İkisi de aynı
// şehir + üniversite ağacında gösterilir; tek fark kartın içeriği ve engelin
// hangi koleksiyona yazıldığıdır. Bu yüzden iki kayıt türü önce ortak bir
// [BanEntry] şekline indirgenir — ağacı çizen kod tek.

/// Engelleme listesinde tek bir satır: öğrenci ya da kulüp.
class BanEntry {
  const BanEntry({
    required this.uid,
    required this.title,
    required this.meta,
    required this.city,
    required this.university,
    required this.banned,
    required this.searchText,
    this.club,
  });

  final String uid;
  final String title;

  /// Başlığın altındaki tanıtıcı satır (öğrenci numarası/bölüm ya da
  /// e-posta/kulüp alanları).
  final String meta;

  final String city;
  final String university;
  final bool banned;

  /// Aramanın taradığı tüm alanlar, küçük harfe indirgenmiş hâlde.
  final String searchText;

  /// Kulüp satırlarında dolu: engeli kaldırırken kulübün belgelerine bakmak
  /// gerekiyor (bkz. `domain/club_moderation.dart`).
  final ClubProfile? club;
}

/// Engel durumu süzgeci.
enum BanStateFilter { all, active, banned }

/// Hangi liste açık?
enum BanScope { students, clubs }

BanEntry studentBanEntry(StudentProfile student) => BanEntry(
  uid: student.uid,
  title: student.fullName.trim().isNotEmpty
      ? student.fullName.trim()
      : student.email,
  meta: <String>[
    if (student.department.isNotEmpty) student.department,
    if (student.studentNumber.isNotEmpty) student.studentNumber,
  ].join(' · '),
  city: student.city.trim(),
  university: student.university.trim(),
  banned: student.banned,
  searchText: <String>[
    student.fullName,
    student.email,
    student.studentNumber,
    student.university,
    student.city,
    student.department,
  ].join(' ').toLowerCase(),
);

BanEntry clubBanEntry(ClubProfile club) => BanEntry(
  uid: club.uid,
  title: club.clubName.trim().isNotEmpty ? club.clubName.trim() : club.email,
  meta: <String>[
    if (club.email.isNotEmpty) club.email,
    if (club.clubFields.isNotEmpty) club.clubFields.join(', '),
  ].join(' · '),
  city: club.city.trim(),
  university: club.university.trim(),
  banned: club.isBanned,
  searchText: <String>[
    club.clubName,
    club.email,
    club.university,
    club.city,
    ...club.clubFields,
  ].join(' ').toLowerCase(),
  club: club,
);

/// Kulüp listesi — bilgi formunu tamamlamamış kayıtlar henüz açılmış bir
/// kulüp değil, yarım kalmış bir kayıt iskeleti; engellenecek bir şey yok.
List<BanEntry> clubBanEntries(List<ClubProfile> clubs) => clubs
    .where((ClubProfile c) => c.onboardingCompleted)
    .map(clubBanEntry)
    .toList();

List<BanEntry> studentBanEntries(List<StudentProfile> students) =>
    students.map(studentBanEntry).toList();

/// Şehir + üniversite başlığı altında toplanmış kayıtlar.
class BanGroup {
  const BanGroup({required this.title, required this.entries});

  final String title;
  final List<BanEntry> entries;
}

/// Kayıtları şehir + üniversiteye göre gruplar; arama metni ve engel
/// durumuyla süzer.
List<BanGroup> groupBanEntries(
  List<BanEntry> entries, {
  String query = '',
  BanStateFilter filter = BanStateFilter.all,
}) {
  final String needle = query.trim().toLowerCase();

  final List<BanEntry> filtered = entries.where((BanEntry entry) {
    switch (filter) {
      case BanStateFilter.active:
        if (entry.banned) return false;
      case BanStateFilter.banned:
        if (!entry.banned) return false;
      case BanStateFilter.all:
        break;
    }
    return needle.isEmpty || entry.searchText.contains(needle);
  }).toList();

  final Map<String, List<BanEntry>> groups = <String, List<BanEntry>>{};

  for (final BanEntry entry in filtered) {
    // Şehri/üniversitesi girilmemiş kayıtlar kaybolmasın: ayrı bir başlık
    // altında toplanırlar.
    final String key = entry.city.isEmpty && entry.university.isEmpty
        ? kMissingLocationLabel
        : <String>[
            if (entry.city.isNotEmpty) entry.city,
            if (entry.university.isNotEmpty) entry.university,
          ].join(' · ');

    groups.putIfAbsent(key, () => <BanEntry>[]).add(entry);
  }

  final List<String> keys = groups.keys.toList()
    ..sort((String a, String b) => a.compareTo(b));

  return keys
      .map((String key) => BanGroup(title: key, entries: groups[key]!))
      .toList();
}

// ── Kulüp listesi (admin-clubs.js) ────────────────────────────────────

/// Şehri/üniversitesi girilmemiş kulüplerin toplandığı başlık.
/// [groupBanEntries] ile aynı metin — iki listede aynı kavram.
const String kMissingLocationLabel = 'Bilgisi eksik';

/// Bir üniversitedeki kulüpler.
class ClubUniversityGroup {
  const ClubUniversityGroup({required this.university, required this.clubs});

  final String university;
  final List<ClubProfile> clubs;
}

/// Bir şehirdeki üniversiteler.
class ClubCityGroup {
  const ClubCityGroup({required this.city, required this.universities});

  final String city;
  final List<ClubUniversityGroup> universities;

  int get clubCount => universities.fold<int>(
    0,
    (int sum, ClubUniversityGroup g) => sum + g.clubs.length,
  );
}

/// Kulüpleri şehir → üniversite ağacına dizer.
///
/// Bilgi formunu tamamlamamış kayıtlar listeye girmez: onlar henüz "açılmış
/// bir kulüp" değil, yarım kalmış bir kayıt iskeleti (bkz. domain/routing.dart).
/// İstatistik ekranı ham sayıları gösterirken bu liste gerçek kulüpleri
/// gösterir; iki ekranın kulüp sayısı bu yüzden farklı olabilir.
List<ClubCityGroup> groupClubsByLocation(
  List<ClubProfile> clubs, {
  String query = '',
  String? status,
}) {
  final String needle = query.trim().toLowerCase();

  final List<ClubProfile> filtered = clubs.where((ClubProfile c) {
    if (!c.onboardingCompleted) return false;
    if (status != null && c.clubStatus != status) return false;
    if (needle.isEmpty) return true;

    return <String>[
      c.clubName,
      c.city,
      c.university,
      c.email,
      ...c.clubFields,
    ].any((String field) => field.toLowerCase().contains(needle));
  }).toList();

  // şehir -> üniversite -> kulüpler
  final Map<String, Map<String, List<ClubProfile>>> tree =
      <String, Map<String, List<ClubProfile>>>{};

  for (final ClubProfile club in filtered) {
    final String city = club.city.trim().isEmpty
        ? kMissingLocationLabel
        : club.city.trim();
    final String university = club.university.trim().isEmpty
        ? kMissingLocationLabel
        : club.university.trim();

    tree
        .putIfAbsent(city, () => <String, List<ClubProfile>>{})
        .putIfAbsent(university, () => <ClubProfile>[])
        .add(club);
  }

  final List<String> cities = tree.keys.toList()..sort(_compareLabels);

  return cities.map((String city) {
    final Map<String, List<ClubProfile>> byUniversity = tree[city]!;
    final List<String> universities = byUniversity.keys.toList()
      ..sort(_compareLabels);

    return ClubCityGroup(
      city: city,
      universities: universities
          .map(
            (String university) => ClubUniversityGroup(
              university: university,
              clubs: byUniversity[university]!
                ..sort(
                  (ClubProfile a, ClubProfile b) => a.clubName
                      .toLowerCase()
                      .compareTo(b.clubName.toLowerCase()),
                ),
            ),
          )
          .toList(),
    );
  }).toList();
}

/// "Bilgisi eksik" başlığı her zaman en sona; gerisi alfabetik.
int _compareLabels(String a, String b) {
  if (a == kMissingLocationLabel) return b == kMissingLocationLabel ? 0 : 1;
  if (b == kMissingLocationLabel) return -1;
  return a.compareTo(b);
}
