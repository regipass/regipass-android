import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/domain/admin_stats.dart';
import 'package:regipass/domain/club_moderation.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/features/admin/admin_providers.dart';
import 'package:regipass/features/admin/admin_screens.dart';
import 'package:regipass/features/admin/admin_shell.dart';
import 'package:regipass/features/shared/admin_message_log.dart';
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
  String name = '',
  List<String> fields = const <String>['Teknoloji'],
  String status = ClubStatus.approved,
  bool onboardingCompleted = true,
}) => ClubProfile.fromMap(uid, <String, dynamic>{
  'city': city,
  'university': university,
  'clubName': name.isEmpty ? 'Kulüp $uid' : name,
  'clubFields': fields,
  'clubStatus': status,
  'onboardingCompleted': onboardingCompleted,
});

void main() {
  // Tarih biçimlendirme yerel verisi uygulamada main.dart'ta yükleniyor;
  // testte de yüklenmezse `DateFormat('tr_TR')` hata fırlatır.
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

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

      expect(tables.map((CityTable t) => t.cityKey), <String>[
        'Ankara',
        'İzmir',
      ]);

      final CityTable ankara = tables.first;
      expect(ankara.students, 2);
      expect(ankara.clubs, 1);
      expect(ankara.male, 1);
      expect(ankara.female, 1);
      expect(ankara.universities.single.university, 'Ankara Üniversitesi');
    });

    test('şehri veya üniversitesi boş profiller sayılmaz', () {
      // Hangi satıra gireceği belirsiz olan kayıt toplamları yanıltır.
      final List<CityTable> tables = buildCityTables(<StudentProfile>[
        student(uid: 'a', city: '', university: ''),
        student(uid: 'b', city: 'Ankara', university: ''),
        student(uid: 'c'),
      ], const <ClubProfile>[]);

      expect(tables.length, 1);
      expect(tables.single.students, 1);
    });
  });

  group('pasta dilimleri', () {
    test('ilk N azalan sırada, gerisi Diğer altında', () {
      final PieBuckets buckets = buildTopNBuckets(<String, int>{
        'A': 10,
        'B': 8,
        'C': 6,
        'D': 4,
        'E': 3,
        'F': 2,
        'G': 1,
      });

      expect(buckets.labels.take(5), <String>['A', 'B', 'C', 'D', 'E']);
      expect(buckets.labels.last, kOtherSliceLabel);
      expect(buckets.values.last, 3); // F + G
      expect(buckets.total, 34);
    });

    test('sıfır değerler dilim açmaz', () {
      final PieBuckets buckets = buildTopNBuckets(<String, int>{
        'A': 5,
        'B': 0,
      });

      expect(buckets.labels, <String>['A']);
    });

    test('boş girdi boş sonuç', () {
      expect(buildTopNBuckets(<String, int>{}).isEmpty, isTrue);
    });
  });

  group('engelleme listesi gruplama', () {
    test('şehir + üniversiteye göre gruplanır', () {
      final List<BanGroup> groups = groupBanEntries(
        studentBanEntries(<StudentProfile>[
          student(uid: 'a'),
          student(uid: 'b'),
          student(uid: 'c', city: 'İzmir', university: 'Ege Üniversitesi'),
        ]),
      );

      expect(groups.length, 2);
      expect(groups.first.title, 'Ankara · Ankara Üniversitesi');
      expect(groups.first.entries.length, 2);
    });

    test('bilgisi eksik öğrenciler kaybolmaz', () {
      final List<BanGroup> groups = groupBanEntries(
        studentBanEntries(<StudentProfile>[
          student(uid: 'a', city: '', university: ''),
        ]),
      );

      expect(groups.single.title, 'Bilgisi eksik');
    });

    test('arama ad, üniversite ve şehirde çalışır', () {
      final List<BanEntry> all = studentBanEntries(<StudentProfile>[
        student(uid: 'a', name: 'Ayşe Yılmaz'),
        student(uid: 'b', name: 'Mehmet Kaya', city: 'İzmir'),
      ]);

      expect(groupBanEntries(all, query: 'ayşe').single.entries.length, 1);
      expect(groupBanEntries(all, query: 'izmir').single.entries.length, 1);
      expect(groupBanEntries(all, query: 'bulunmayan'), isEmpty);
    });

    test('durum süzgeci aktif/engelli ayırır', () {
      final List<BanEntry> all = studentBanEntries(<StudentProfile>[
        student(uid: 'a', name: 'Ayşe Yılmaz'),
        student(uid: 'b', name: 'Mehmet Kaya', banned: true),
      ]);

      expect(groupBanEntries(all).single.entries.length, 2);
      expect(
        groupBanEntries(
          all,
          filter: BanStateFilter.active,
        ).single.entries.single.title,
        'Ayşe Yılmaz',
      );
      expect(
        groupBanEntries(
          all,
          filter: BanStateFilter.banned,
        ).single.entries.single.title,
        'Mehmet Kaya',
      );
    });

    test('kulüp listesinde bilgi formu yarım kalanlar yer almaz', () {
      final List<BanEntry> entries = clubBanEntries(<ClubProfile>[
        club(uid: 'a', name: 'Yazılım Kulübü'),
        club(uid: 'b', name: 'Yarım Kayıt', onboardingCompleted: false),
      ]);

      expect(entries.single.title, 'Yazılım Kulübü');
    });

    test('kulüp engeli iki alandan biriyle de görülür', () {
      // Web tarafı `clubStatus` ve `banned` alanlarının ikisini de yazıyor;
      // eski kayıtlarda yalnızca biri dolu olabiliyor.
      expect(
        clubBanEntry(club(uid: 'a', status: ClubStatus.banned)).banned,
        isTrue,
      );
      expect(
        clubBanEntry(
          ClubProfile.fromMap('b', <String, dynamic>{
            'clubName': 'Eski Kayıt',
            'clubStatus': ClubStatus.approved,
            'banned': true,
            'onboardingCompleted': true,
          }),
        ).banned,
        isTrue,
      );
    });
  });

  group('kulüp engeli kaldırma', () {
    test('belgeleri duran kulüp inceleme kuyruğuna döner', () {
      final ClubProfile withDocuments = ClubProfile.fromMap(
        'a',
        <String, dynamic>{
          'clubStatus': ClubStatus.banned,
          'onboardingCompleted': true,
          'documents': <String, dynamic>{
            'advisor': <String, dynamic>{'url': 'x', 'path': 'p'},
          },
        },
      );

      expect(clubStatusAfterUnban(withDocuments), ClubStatus.pendingReview);
    });

    test('belgesi silinmiş kulüp yükleme adımına döner', () {
      expect(
        clubStatusAfterUnban(club(uid: 'a', status: ClubStatus.banned)),
        ClubStatus.documentsPending,
      );
    });
  });

  group('yönetici mesajları', () {
    test('en yeni mesaj başta, boş metinler elenir', () {
      final ClubProfile profile = ClubProfile.fromMap('a', <String, dynamic>{
        'onboardingCompleted': true,
        'adminMessages': <dynamic>[
          <String, dynamic>{
            'id': 'eski',
            'message': 'Danışman onayı okunmuyor.',
            'createdAtMs': 1000,
          },
          <String, dynamic>{
            'id': 'yeni',
            'message': 'Yeni belgeyi aldık.',
            'createdAtMs': 2000,
          },
          <String, dynamic>{'id': 'bos', 'message': '   ', 'createdAtMs': 3000},
        ],
      });

      expect(profile.adminMessages.length, 2);
      expect(profile.adminMessages.first.id, 'yeni');
      expect(profile.adminMessages.last.message, 'Danışman onayı okunmuyor.');
    });

    test('kimliği olmayan kayıtta zaman damgası kimlik yerine geçer', () {
      final ClubProfile profile = ClubProfile.fromMap('a', <String, dynamic>{
        'adminMessages': <dynamic>[
          <String, dynamic>{'message': 'Not', 'createdAtMs': 1234},
        ],
      });

      expect(profile.adminMessages.single.id, '1234');
    });

    test('alan hiç yoksa liste boş kalır', () {
      expect(
        ClubProfile.fromMap('a', <String, dynamic>{}).adminMessages,
        isEmpty,
      );
    });
  });

  group('kulüp listesi gruplama', () {
    test('şehir → üniversite ağacı kurulur', () {
      final List<ClubCityGroup> groups = groupClubsByLocation(<ClubProfile>[
        club(uid: 'a'),
        club(uid: 'b', university: 'ODTÜ'),
        club(uid: 'c', city: 'İzmir', university: 'Ege Üniversitesi'),
      ]);

      expect(groups.length, 2);
      expect(groups.first.city, 'Ankara');
      expect(groups.first.universities.length, 2);
      expect(groups.first.clubCount, 2);
    });

    test('bilgi formu tamamlanmamış kayıtlar listeye girmez', () {
      final List<ClubCityGroup> groups = groupClubsByLocation(<ClubProfile>[
        club(uid: 'a', onboardingCompleted: false),
      ]);

      expect(groups, isEmpty);
    });

    test('şehri girilmemiş kulüp en sondaki başlıkta toplanır', () {
      final List<ClubCityGroup> groups = groupClubsByLocation(<ClubProfile>[
        club(uid: 'a', city: '', university: ''),
        club(uid: 'b'),
      ]);

      expect(groups.last.city, kMissingLocationLabel);
      expect(groups.last.universities.single.university, kMissingLocationLabel);
    });

    test('arama ad, şehir, üniversite ve alanda çalışır', () {
      final List<ClubProfile> all = <ClubProfile>[
        club(uid: 'a', name: 'Robotik Kulübü'),
        club(
          uid: 'b',
          name: 'Tiyatro Kulübü',
          city: 'İzmir',
          fields: <String>['Sanat'],
        ),
      ];

      expect(groupClubsByLocation(all, query: 'robotik').single.clubCount, 1);
      expect(groupClubsByLocation(all, query: 'izmir').single.clubCount, 1);
      expect(groupClubsByLocation(all, query: 'sanat').single.clubCount, 1);
      expect(groupClubsByLocation(all, query: 'yok'), isEmpty);
    });

    test('durum süzgeci yalnızca o durumdaki kulüpleri bırakır', () {
      final List<ClubProfile> all = <ClubProfile>[
        club(uid: 'a'),
        club(uid: 'b', status: ClubStatus.pendingReview),
      ];

      final List<ClubCityGroup> pending = groupClubsByLocation(
        all,
        status: ClubStatus.pendingReview,
      );

      expect(pending.single.clubCount, 1);
      expect(
        pending.single.universities.single.clubs.single.clubStatus,
        ClubStatus.pendingReview,
      );
    });
  });

  testWidgets('engelleme ekranı öğrenci ve kulüp sekmelerini taşır', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allStudentsProvider.overrideWith(
            (Ref ref) => Stream<List<StudentProfile>>.value(<StudentProfile>[
              student(uid: 'a', name: 'Ayşe Yılmaz'),
              student(uid: 'b', name: 'Mehmet Kaya', banned: true),
            ]),
          ),
          allClubsProvider.overrideWith(
            (Ref ref) async => <ClubProfile>[
              club(uid: 'c', name: 'Yazılım Kulübü'),
            ],
          ),
        ],
        child: const LanguageScope(
          language: 'tr',
          child: MaterialApp(home: AdminBanScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Süzgeç şeridi ve iki sekme yerinde.
    expect(find.text('Katılımcılar'), findsOneWidget);
    expect(find.text('Organizatörler'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Engelli'), findsWidgets);

    // Öğrenci listesi grubu açılınca engelli kayıt işaretli görünür.
    await tester.tap(find.text('Ankara · Ankara Üniversitesi'));
    await tester.pumpAndSettle();
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Engeli Kaldır'), findsOneWidget);

    // Kulüp sekmesine geçince liste kulüplerden gelir.
    await tester.tap(find.text('Organizatörler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ankara · Ankara Üniversitesi'));
    await tester.pumpAndSettle();
    expect(find.text('Yazılım Kulübü'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yönetici notları en yenisi başta çizilir', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final ClubProfile profile = ClubProfile.fromMap('a', <String, dynamic>{
      'onboardingCompleted': true,
      'adminMessages': <dynamic>[
        <String, dynamic>{
          'id': '1',
          'message': 'Danışman onayı okunmuyor.',
          'createdAtMs': 1000,
        },
        <String, dynamic>{
          'id': '2',
          'message': 'Yeni belgeyi aldık.',
          'createdAtMs': 2000,
        },
      ],
    });

    await tester.pumpWidget(
      ProviderScope(
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            home: Scaffold(
              body: AdminMessageLog(messages: profile.adminMessages),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gönderilen mesajlar'), findsOneWidget);
    expect(find.text('Yeni belgeyi aldık.'), findsOneWidget);
    expect(find.text('Danışman onayı okunmuyor.'), findsOneWidget);

    final double newer = tester.getTopLeft(find.text('Yeni belgeyi aldık.')).dy;
    final double older = tester
        .getTopLeft(find.text('Danışman onayı okunmuyor.'))
        .dy;
    expect(newer, lessThan(older));
    expect(tester.takeException(), isNull);
  });

  testWidgets('yönetici alt çubuğu beş sekme çizer', (
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
    expect(find.text('Organizatörler'), findsOneWidget);
    expect(find.text('Engelle'), findsOneWidget);
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
