import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/admin_stats.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/features/admin/admin_providers.dart';
import 'package:regipass/features/admin/admin_shell.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/profiles.dart';

StudentProfile student({
  String uid = 's1',
  String city = 'Ankara',
  String university = 'Ankara Üniversitesi',
  String gender = '',
  String name = 'Ali Veli',
  bool banned = false,
}) {
  final List<String> parts = name.split(' ');
  return StudentProfile.fromMap(uid, <String, dynamic>{
    'firstName': parts.first,
    'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
    'city': city,
    'university': university,
    'gender': gender,
    'banned': banned,
  });
}

ClubProfile club({
  String uid = 'c1',
  String city = 'Ankara',
  String university = 'Ankara Üniversitesi',
}) =>
    ClubProfile.fromMap(uid, <String, dynamic>{
      'city': city,
      'university': university,
      'clubName': 'Kulüp $uid',
    });

void main() {
  group('sistem toplamları', () {
    test('öğrenci, kulüp ve cinsiyet sayıları', () {
      final SystemTotals totals = computeSystemTotals(
        <StudentProfile>[
          student(uid: 'a', gender: 'male'),
          student(uid: 'b', gender: 'female'),
          student(uid: 'c', gender: 'female'),
          student(uid: 'd'), // cinsiyet girilmemiş
        ],
        <ClubProfile>[club()],
      );

      expect(totals.students, 4);
      expect(totals.clubs, 1);
      expect(totals.male, 1);
      expect(totals.female, 2);
      expect(totals.unspecified, 1);
    });
  });

  group('İstanbul yaka ayrımı', () {
    test('İstanbul üniversiteleri yakalara bölünür', () {
      // Boğaziçi Avrupa, Marmara (Göztepe) Anadolu yakasında.
      expect(
        resolveCityKey('İstanbul', 'Boğaziçi Üniversitesi'),
        'İstanbul (Avrupa Yakası)',
      );
      expect(
        resolveCityKey('İstanbul', 'Bilinmeyen Üniversite'),
        'İstanbul (Diğer)',
      );
    });

    test('diğer şehirler bölünmez', () {
      expect(resolveCityKey('Ankara', 'Ankara Üniversitesi'), 'Ankara');
    });

    test('pasta dilimlerinde yakalar tek İstanbul olur', () {
      // "En çok öğrenci hangi ilde" sorusu yakayla değil ille cevaplanmalı.
      expect(collapseCityKey('İstanbul (Avrupa Yakası)'), 'İstanbul');
      expect(collapseCityKey('Ankara'), 'Ankara');
    });
  });

  group('şehir tabloları', () {
    test('şehir → üniversite kırılımı ve cinsiyet sayıları', () {
      final List<CityTable> tables = buildCityTables(
        <StudentProfile>[
          student(uid: 'a', gender: 'male'),
          student(uid: 'b', gender: 'female'),
          student(
            uid: 'c',
            city: 'İzmir',
            university: 'Ege Üniversitesi',
            gender: 'male',
          ),
        ],
        <ClubProfile>[club()],
      );

      expect(tables.map((CityTable t) => t.cityKey), <String>['Ankara', 'İzmir']);

      final CityTable ankara = tables.first;
      expect(ankara.students, 2);
      expect(ankara.clubs, 1);
      expect(ankara.male, 1);
      expect(ankara.female, 1);
      expect(ankara.universities.single.university, 'Ankara Üniversitesi');
    });

    test('şehri veya üniversitesi boş profiller sayılmaz', () {
      // Hangi satıra gireceği belirsiz olan kayıt toplamları yanıltır.
      final List<CityTable> tables = buildCityTables(
        <StudentProfile>[
          student(uid: 'a', city: '', university: ''),
          student(uid: 'b', city: 'Ankara', university: ''),
          student(uid: 'c'),
        ],
        const <ClubProfile>[],
      );

      expect(tables.length, 1);
      expect(tables.single.students, 1);
    });
  });

  group('pasta dilimleri', () {
    test('ilk N azalan sırada, gerisi Diğer altında', () {
      final PieBuckets buckets = buildTopNBuckets(
        <String, int>{'A': 10, 'B': 8, 'C': 6, 'D': 4, 'E': 3, 'F': 2, 'G': 1},
      );

      expect(buckets.labels.take(5), <String>['A', 'B', 'C', 'D', 'E']);
      expect(buckets.labels.last, kOtherSliceLabel);
      expect(buckets.values.last, 3); // F + G
      expect(buckets.total, 34);
    });

    test('sıfır değerler dilim açmaz', () {
      final PieBuckets buckets =
          buildTopNBuckets(<String, int>{'A': 5, 'B': 0});

      expect(buckets.labels, <String>['A']);
    });

    test('boş girdi boş sonuç', () {
      expect(buildTopNBuckets(<String, int>{}).isEmpty, isTrue);
    });
  });

  group('öğrenci gruplama', () {
    test('şehir + üniversiteye göre gruplanır', () {
      final List<StudentGroup> groups = groupStudents(
        <StudentProfile>[
          student(uid: 'a'),
          student(uid: 'b'),
          student(uid: 'c', city: 'İzmir', university: 'Ege Üniversitesi'),
        ],
        '',
      );

      expect(groups.length, 2);
      expect(groups.first.title, 'Ankara · Ankara Üniversitesi');
      expect(groups.first.students.length, 2);
    });

    test('bilgisi eksik öğrenciler kaybolmaz', () {
      final List<StudentGroup> groups = groupStudents(
        <StudentProfile>[student(uid: 'a', city: '', university: '')],
        '',
      );

      expect(groups.single.title, 'Bilgisi eksik');
    });

    test('arama ad, üniversite ve şehirde çalışır', () {
      final List<StudentProfile> all = <StudentProfile>[
        student(uid: 'a', name: 'Ayşe Yılmaz'),
        student(uid: 'b', name: 'Mehmet Kaya', city: 'İzmir'),
      ];

      expect(groupStudents(all, 'ayşe').single.students.length, 1);
      expect(groupStudents(all, 'izmir').single.students.length, 1);
      expect(groupStudents(all, 'bulunmayan'), isEmpty);
    });
  });

  testWidgets('yönetici alt çubuğu dört sekme çizer', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            home: AdminShell(
              location: Routes.adminHome,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Onaylar'), findsOneWidget);
    expect(find.text('İstatistik'), findsOneWidget);
    expect(find.text('Engelle'), findsOneWidget);
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
