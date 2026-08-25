/// js/modules/admin/stats-engine.js portu.
///
/// Saf hesaplama: Firestore ya da widget bağımlılığı yok, bu yüzden doğrudan
/// test edilebilir. Girdi öğrenci/kulüp profilleri, çıktı yönetici ekranının
/// çizeceği hazır tablolar.
library;

import '../data/istanbul_university_side.dart';
import '../models/profiles.dart';

/// Pasta grafiğinde artakalanların toplandığı dilim.
const String kOtherSliceLabel = 'Diğer';

/// Sistem geneli sayılar.
class SystemTotals {
  const SystemTotals({
    required this.students,
    required this.clubs,
    required this.male,
    required this.female,
  });

  final int students;
  final int clubs;
  final int male;
  final int female;

  /// Cinsiyeti girilmemiş öğrenciler.
  int get unspecified => students - male - female;
}

/// Bir üniversitenin satırı.
class UniversityRow {
  const UniversityRow({
    required this.university,
    required this.students,
    required this.clubs,
    required this.male,
    required this.female,
  });

  final String university;
  final int students;
  final int clubs;
  final int male;
  final int female;
}

/// Bir şehrin (İstanbul'da bir yakanın) tablosu.
class CityTable {
  const CityTable({required this.cityKey, required this.universities});

  final String cityKey;
  final List<UniversityRow> universities;

  int get students =>
      universities.fold(0, (int sum, UniversityRow u) => sum + u.students);

  int get clubs =>
      universities.fold(0, (int sum, UniversityRow u) => sum + u.clubs);

  int get male =>
      universities.fold(0, (int sum, UniversityRow u) => sum + u.male);

  int get female =>
      universities.fold(0, (int sum, UniversityRow u) => sum + u.female);
}

/// Pasta dilimleri: ilk N azalan sırada, gerisi tek "Diğer" diliminde.
class PieBuckets {
  const PieBuckets({required this.labels, required this.values});

  final List<String> labels;
  final List<int> values;

  bool get isEmpty => values.isEmpty;

  int get total => values.fold(0, (int sum, int v) => sum + v);
}

/// Yönetici istatistik ekranının ihtiyaç duyduğu her şey.
class AdminStats {
  const AdminStats({
    required this.totals,
    required this.cityTables,
    required this.cityStudents,
    required this.cityClubs,
    required this.universityStudents,
    required this.universityClubs,
  });

  final SystemTotals totals;
  final List<CityTable> cityTables;

  final PieBuckets cityStudents;
  final PieBuckets cityClubs;
  final PieBuckets universityStudents;
  final PieBuckets universityClubs;
}

/// İstanbul üniversiteleri yakalarına ayrılır; diğer şehirler tek grup kalır.
///
/// Sebep: İstanbul tek satırda toplandığında tablo okunmaz hâle geliyor —
/// öğrencilerin yarısı orada.
String resolveCityKey(String city, String university) {
  if (city != 'İstanbul') return city;

  final String? side = kIstanbulUniversitySide[university];
  if (side == IstanbulSide.anadolu) return 'İstanbul (Anadolu Yakası)';
  if (side == IstanbulSide.avrupa) return 'İstanbul (Avrupa Yakası)';
  return 'İstanbul (Diğer)';
}

/// Pasta grafiklerde yakalar tekrar tek "İstanbul" altında birleşir:
/// "en çok öğrenci hangi ilde" sorusu yakayla değil illa cevaplanmalı.
String collapseCityKey(String cityKey) =>
    cityKey.startsWith('İstanbul (') ? 'İstanbul' : cityKey;

SystemTotals computeSystemTotals(
  List<StudentProfile> students,
  List<ClubProfile> clubs,
) {
  int male = 0;
  int female = 0;

  for (final StudentProfile student in students) {
    if (student.gender == 'male') {
      male += 1;
    } else if (student.gender == 'female') {
      female += 1;
    }
  }

  return SystemTotals(
    students: students.length,
    clubs: clubs.length,
    male: male,
    female: female,
  );
}

/// Şehir → üniversite kırılımı.
///
/// Şehri ya da üniversitesi boş olan profiller sayılmaz: hangi satıra
/// gireceği belirsiz olduğu için toplamları yanıltırdı.
List<CityTable> buildCityTables(
  List<StudentProfile> students,
  List<ClubProfile> clubs,
) {
  final Map<String, Map<String, List<int>>> cityMap =
      <String, Map<String, List<int>>>{};

  // [öğrenci, kulüp, erkek, kız]
  List<int>? bucketFor(String city, String university) {
    final String trimmedCity = city.trim();
    final String trimmedUniversity = university.trim();
    if (trimmedCity.isEmpty || trimmedUniversity.isEmpty) return null;

    final String cityKey = resolveCityKey(trimmedCity, trimmedUniversity);
    final Map<String, List<int>> universities =
        cityMap.putIfAbsent(cityKey, () => <String, List<int>>{});

    return universities.putIfAbsent(
      trimmedUniversity,
      () => <int>[0, 0, 0, 0],
    );
  }

  for (final StudentProfile student in students) {
    final List<int>? bucket = bucketFor(student.city, student.university);
    if (bucket == null) continue;

    bucket[0] += 1;
    if (student.gender == 'male') {
      bucket[2] += 1;
    } else if (student.gender == 'female') {
      bucket[3] += 1;
    }
  }

  for (final ClubProfile club in clubs) {
    bucketFor(club.city, club.university)?[1] += 1;
  }

  final List<String> cityKeys = cityMap.keys.toList()
    ..sort((String a, String b) => a.compareTo(b));

  return cityKeys.map((String cityKey) {
    final Map<String, List<int>> universities = cityMap[cityKey]!;

    final List<String> names = universities.keys.toList()
      ..sort((String a, String b) => a.compareTo(b));

    return CityTable(
      cityKey: cityKey,
      universities: names.map((String name) {
        final List<int> counts = universities[name]!;
        return UniversityRow(
          university: name,
          students: counts[0],
          clubs: counts[1],
          male: counts[2],
          female: counts[3],
        );
      }).toList(),
    );
  }).toList();
}

/// Şehir toplamları (İstanbul yakaları birleştirilmiş).
Map<String, int> cityTotals(
  List<CityTable> tables,
  int Function(CityTable) pick,
) {
  final Map<String, int> totals = <String, int>{};
  for (final CityTable table in tables) {
    final String city = collapseCityKey(table.cityKey);
    totals[city] = (totals[city] ?? 0) + pick(table);
  }
  return totals;
}

Map<String, int> universityTotals(
  List<CityTable> tables,
  int Function(UniversityRow) pick,
) {
  final Map<String, int> totals = <String, int>{};
  for (final CityTable table in tables) {
    for (final UniversityRow row in table.universities) {
      totals[row.university] = (totals[row.university] ?? 0) + pick(row);
    }
  }
  return totals;
}

/// İlk [topN] azalan sırada; gerisi tek "Diğer" diliminde toplanır.
PieBuckets buildTopNBuckets(Map<String, int> counts, {int topN = 5}) {
  final List<MapEntry<String, int>> entries = counts.entries
      .where((MapEntry<String, int> e) => e.value > 0)
      .toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
        b.value.compareTo(a.value));

  final List<String> labels = <String>[];
  final List<int> values = <int>[];

  for (final MapEntry<String, int> entry in entries.take(topN)) {
    labels.add(entry.key);
    values.add(entry.value);
  }

  final int rest = entries
      .skip(topN)
      .fold(0, (int sum, MapEntry<String, int> e) => sum + e.value);

  if (rest > 0) {
    labels.add(kOtherSliceLabel);
    values.add(rest);
  }

  return PieBuckets(labels: labels, values: values);
}

/// Tüm istatistikleri tek çağrıda üretir.
AdminStats computeAdminStats(
  List<StudentProfile> students,
  List<ClubProfile> clubs,
) {
  final List<CityTable> tables = buildCityTables(students, clubs);

  return AdminStats(
    totals: computeSystemTotals(students, clubs),
    cityTables: tables,
    cityStudents: buildTopNBuckets(
      cityTotals(tables, (CityTable t) => t.students),
    ),
    cityClubs: buildTopNBuckets(cityTotals(tables, (CityTable t) => t.clubs)),
    universityStudents: buildTopNBuckets(
      universityTotals(tables, (UniversityRow u) => u.students),
    ),
    universityClubs: buildTopNBuckets(
      universityTotals(tables, (UniversityRow u) => u.clubs),
    ),
  );
}
