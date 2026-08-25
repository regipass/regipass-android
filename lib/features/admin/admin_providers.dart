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
  final AsyncValue<List<StudentProfile>> students =
      ref.watch(allStudentsProvider);
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

/// Engelleme ekranında şehir → üniversite → öğrenci ağacı.
class StudentGroup {
  const StudentGroup({required this.title, required this.students});

  final String title;
  final List<StudentProfile> students;
}

/// Öğrencileri şehir + üniversiteye göre gruplar ve arama metniyle süzer.
List<StudentGroup> groupStudents(
  List<StudentProfile> students,
  String query,
) {
  final String needle = query.trim().toLowerCase();

  final List<StudentProfile> filtered = needle.isEmpty
      ? students
      : students.where((StudentProfile s) {
          return <String>[
            s.fullName,
            s.email,
            s.studentNumber,
            s.university,
            s.city,
            s.department,
          ].any((String field) => field.toLowerCase().contains(needle));
        }).toList();

  final Map<String, List<StudentProfile>> groups =
      <String, List<StudentProfile>>{};

  for (final StudentProfile student in filtered) {
    final String city = student.city.trim();
    final String university = student.university.trim();

    // Şehri/üniversitesi girilmemiş öğrenciler kaybolmasın: ayrı bir
    // başlık altında toplanırlar.
    final String key = city.isEmpty && university.isEmpty
        ? 'Bilgisi eksik'
        : <String>[
            if (city.isNotEmpty) city,
            if (university.isNotEmpty) university,
          ].join(' · ');

    groups.putIfAbsent(key, () => <StudentProfile>[]).add(student);
  }

  final List<String> keys = groups.keys.toList()
    ..sort((String a, String b) => a.compareTo(b));

  return keys
      .map((String key) => StudentGroup(title: key, students: groups[key]!))
      .toList();
}
