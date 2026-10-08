// Tasarım ekran görüntüsü düzeneği.
//
// Normal `flutter test` koşusunda ATLANIR (bkz. dart_test.yaml, `design`
// etiketi). Ekran görüntülerini üretmek için:
//
//   SHOTS_DIR=/tmp/shots flutter test --run-skipped -t design test/design
//
// Anahtar ekranlar sahte (Türkçe demo) veriyle, gerçek fontlarla, 390x844
// mantıksal pikselde açık ve koyu temada çizilip PNG olarak yazılır.
@Tags(<String>['design'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/features/admin/admin_providers.dart';
import 'package:regipass/features/admin/admin_screens.dart';
import 'package:regipass/features/admin/admin_shell.dart';
import 'package:regipass/features/auth/register_screen.dart';
import 'package:regipass/features/club/club_create_event_screen.dart';
import 'package:regipass/features/club/club_account_screen.dart';
import 'package:regipass/features/club/club_dashboard_screen.dart';
import 'package:regipass/features/club/club_events_screen.dart';
import 'package:regipass/features/club/club_event_detail_screen.dart';
import 'package:regipass/features/club/club_providers.dart';
import 'package:regipass/features/club/club_shell.dart';
import 'package:regipass/features/landing/login_screen.dart';
import 'package:regipass/features/explore/explore_providers.dart';
import 'package:regipass/features/explore/explore_screen.dart';
import 'package:regipass/features/onboarding/student_info_screen.dart';
import 'package:regipass/features/shared/event_widgets.dart';
import 'package:regipass/features/student/student_account_screen.dart';
import 'package:regipass/features/student/student_appointments_screen.dart';
import 'package:regipass/features/student/student_certificates_screen.dart';
import 'package:regipass/features/student/student_qr_checkin_screen.dart';
import 'package:regipass/features/club/club_qr_checkin_screen.dart';
import 'package:regipass/features/student/student_dashboard_screen.dart';
import 'package:regipass/features/student/student_providers.dart';
import 'package:regipass/features/student/student_shell.dart';
import 'package:regipass/features/notifications/notification_providers.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/services/certificate_service.dart';
import 'package:regipass/services/club_follow_service.dart';
import 'package:regipass/state/connectivity.dart';
import 'package:regipass/state/providers.dart';

final String _outDir =
    Platform.environment['SHOTS_DIR'] ?? '/tmp/claude-0/shots/mobile-after';

// İP-T2: tablet çekimi için ekran boyutu (ör. iPad: SHOTS_W=820 SHOTS_H=1180).
final double _shotW =
    double.tryParse(Platform.environment['SHOTS_W'] ?? '') ?? 390;
final double? _shotH = double.tryParse(Platform.environment['SHOTS_H'] ?? '');
final bool _tablet = _shotW >= 600;
final bool _lightOnly = Platform.environment['SHOTS_LIGHT_ONLY'] == '1';

// ── Fontlar ────────────────────────────────────────────────────────────

Future<void> _loadFonts() async {
  final String flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final String material = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File(f);
      if (!file.existsSync()) continue;
      final Uint8List bytes = file.readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family('Roboto', <String>[
    for (final String w in <String>[
      'Regular',
      'Medium',
      'Bold',
      'Light',
      'Black',
    ])
      '$material/Roboto-$w.ttf',
  ]);
  await family('MaterialIcons', <String>[
    '$material/MaterialIcons-Regular.otf',
  ]);

  // Uygulamaya gömülü fontlar (varsa).
  final Directory fonts = Directory('assets/fonts');
  if (fonts.existsSync()) {
    final Map<String, List<String>> byFamily = <String, List<String>>{};
    for (final FileSystemEntity e in fonts.listSync()) {
      if (!e.path.endsWith('.ttf')) continue;
      final String base = e.uri.pathSegments.last;
      final String fam = base.split('-').first;
      byFamily.putIfAbsent(fam, () => <String>[]).add(e.path);
    }
    for (final MapEntry<String, List<String>> entry in byFamily.entries) {
      await family(entry.key, entry.value);
    }
  }
}

// ── Demo veri ──────────────────────────────────────────────────────────

String _pic(String name) {
  final List<int> bytes = File(
    'test/design/fixtures/$name.jpg',
  ).readAsBytesSync();
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

class _FakeUser implements User {
  _FakeUser(this.uid, this.email);

  @override
  final String uid;

  @override
  final String? email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

int _at(int month, int day, [int hour = 18]) =>
    DateTime(2026, month, day, hour).millisecondsSinceEpoch;

final StudentProfile _student = StudentProfile.fromMap('s1', <String, dynamic>{
  'email': 'zeynep.kaya@std.bogazici.edu.tr',
  'firstName': 'Zeynep',
  'lastName': 'Kaya',
  'phone': '+905321234567',
  'city': 'İstanbul',
  'university': 'Boğaziçi Üniversitesi',
  'department': 'Bilgisayar Mühendisliği',
  'studentNumber': '2023400123',
  'classYear': '3',
  'gender': 'female',
  'onboardingCompleted': true,
  'phoneVerified': true,
  'hasPassword': true,
  'termsAccepted': true,
});

final ClubProfile _club = ClubProfile.fromMap('c1', <String, dynamic>{
  'email': 'bilisim@kulup.bogazici.edu.tr',
  'firstName': 'Mert',
  'lastName': 'Demir',
  'phone': '+905301112233',
  'city': 'İstanbul',
  'university': 'Boğaziçi Üniversitesi',
  'clubName': 'Boğaziçi Bilişim Kulübü',
  'clubField': 'Teknoloji',
  'clubFields': <String>['Teknoloji', 'Yazılım'],
  'clubPurpose': 'Öğrencileri yazılım ve teknolojiyle buluşturmak.',
  'clubContents': 'Atölyeler, hackathonlar, kariyer günleri.',
  'onboardingCompleted': true,
  'clubStatus': ClubStatus.approved,
  'phoneVerified': true,
  'hasPassword': true,
  'termsAccepted': true,
});

Session _studentSession() => Session(
  isLoading: false,
  user: _FakeUser('s1', _student.email),
  appUser: AppUser.fromMap('s1', <String, dynamic>{
    'role': UserRole.student,
    'lastRole': UserRole.student,
    'roles': <String, bool>{UserRole.student: true},
    'displayName': 'Zeynep Kaya',
  }),
  studentProfile: _student,
  clubProfile: null,
  activeRole: UserRole.student,
);

Session _clubSession() => Session(
  isLoading: false,
  user: _FakeUser('c1', _club.email),
  appUser: AppUser.fromMap('c1', <String, dynamic>{
    'role': UserRole.club,
    'lastRole': UserRole.club,
    'roles': <String, bool>{UserRole.club: true},
  }),
  studentProfile: null,
  clubProfile: _club,
  activeRole: UserRole.club,
);

const Session _guestSession = Session(
  isLoading: false,
  user: null,
  appUser: null,
  studentProfile: null,
  clubProfile: null,
  activeRole: null,
);

List<AppEvent> _events() => <AppEvent>[
  AppEvent.fromMap('e1', <String, dynamic>{
    'title': 'Yapay Zekâ ile Web Geliştirme Atölyesi',
    'description':
        'Üç saatlik uygulamalı atölyede yapay zekâ destekli araçlarla '
        'baştan sona bir web uygulaması geliştireceğiz. Dizüstü '
        'bilgisayarını getirmeyi unutma.',
    'purpose': 'Katılımcıların modern web araçlarını pratikte denemesi.',
    'feeType': 'free',
    'feeInfo': 'Ucretsiz',
    'targetScope': 'public',
    'imageUrl': _pic('ai'),
    'quota': 60,
    'deadlineAtMs': _at(10, 3, 23),
    'eventDateAtMs': _at(10, 4, 14),
    'eventStartTime': '14:00',
    'eventEndTime': '17:30',
    'locationName': 'Kuzey Kampüs, Bilgisayar Müh. Binası',
    'clubId': 'c1',
    'clubName': 'Boğaziçi Bilişim Kulübü',
    'clubUniversity': 'Boğaziçi Üniversitesi',
    'clubFields': <String>['Teknoloji', 'Yazılım'],
    'clubPhone': '+905301112233',
    'clubEmail': 'bilisim@kulup.bogazici.edu.tr',
    'contactMode': 'club',
    'sessionCount': 1,
    'checkinMode': 'entry',
  }),
  AppEvent.fromMap('e2', <String, dynamic>{
    'title': 'Bilişim Kariyer Günleri',
    'description': 'Sektörden 12 şirketle tanışma ve CV atölyesi.',
    'feeType': 'paid',
    'feeAmount': 150,
    'feeInfo': '150 TL',
    'targetScope': 'university',
    'targetUniversities': <String>['Boğaziçi Üniversitesi'],
    'imageUrl': _pic('career'),
    'quota': 300,
    'deadlineAtMs': _at(10, 18, 23),
    'eventDateAtMs': _at(10, 19, 10),
    'eventStartTime': '10:00',
    'eventEndTime': '17:00',
    'locationName': 'Albert Long Hall',
    'clubId': 'c1',
    'clubName': 'Boğaziçi Bilişim Kulübü',
    'clubUniversity': 'Boğaziçi Üniversitesi',
    'clubFields': <String>['Teknoloji'],
    'sessionCount': 1,
  }),
  AppEvent.fromMap('e3', <String, dynamic>{
    'title': 'Startup Okulu: 6 Haftalık Program',
    'description': 'Fikirden yatırıma altı haftalık girişimcilik programı.',
    'feeType': 'free',
    'targetScope': 'public',
    'imageUrl': _pic('startup'),
    'quota': 40,
    'deadlineAtMs': _at(10, 1, 23),
    'eventDateAtMs': _at(10, 2, 18),
    'eventStartTime': '18:00',
    'eventEndTime': '20:00',
    'locationName': 'İTÜ Çekirdek, Ayazağa',
    'clubId': 'c2',
    'clubName': 'İTÜ Girişimcilik Kulübü',
    'clubUniversity': 'İstanbul Teknik Üniversitesi',
    'clubFields': <String>['Girişimcilik'],
    'sessionCount': 6,
    'checkinMode': 'entry_sessions',
  }),
  AppEvent.fromMap('e4', <String, dynamic>{
    'title': 'Siber Güvenlik CTF Gecesi',
    'description': 'Takımlar hâlinde 6 saatlik yakala-bayrağı yarışması.',
    'feeType': 'free',
    'targetScope': 'public',
    'imageUrl': _pic('ctf'),
    'quota': 80,
    'seatsFull': true,
    'deadlineAtMs': _at(10, 5, 23),
    'eventDateAtMs': _at(10, 6, 20),
    'eventStartTime': '20:00',
    'eventEndTime': '02:00',
    'locationName': 'Güney Kampüs, Kare Blok',
    'clubId': 'c1',
    'clubName': 'Boğaziçi Bilişim Kulübü',
    'clubUniversity': 'Boğaziçi Üniversitesi',
    'clubFields': <String>['Teknoloji'],
    'sessionCount': 1,
  }),
];

List<EventRegistration> _registrations() => <EventRegistration>[
  for (final AppEvent e in _events().take(3))
    EventRegistration.fromMap('r-${e.id}', <String, dynamic>{
      'eventId': e.id,
      'eventTitle': e.title,
      'eventImageUrl': e.imageUrl,
      'deadlineAtMs': e.deadlineAtMs,
      'clubId': e.clubId,
      'clubName': e.clubName,
      'studentId': 's1',
      'studentFirstName': 'Zeynep',
      'studentLastName': 'Kaya',
      'studentName': 'Zeynep Kaya',
      'studentEmail': _student.email,
      'studentPhone': '+905321234567',
      'studentUniversity': 'Boğaziçi Üniversitesi',
      'studentDepartment': 'Bilgisayar Mühendisliği',
      'studentClassYear': '3',
      'studentCity': 'İstanbul',
      'registeredAtMs': _at(9, 17, 16),
      'ticketCode': 'RP-4X5J-${e.id.toUpperCase()}Q3',
      'paymentStatus': e.isPaid ? 'pending' : '',
    }),
];

List<EventRegistration> _clubRegistrations() {
  const List<List<String>> people = <List<String>>[
    <String>['Ahmet', 'Yıldız', 'Elektrik-Elektronik Mühendisliği'],
    <String>['Elif', 'Şahin', 'Bilgisayar Mühendisliği'],
    <String>['Can', 'Öztürk', 'İşletme'],
    <String>['Ayşe', 'Çelik', 'Matematik'],
  ];
  return <EventRegistration>[
    for (int i = 0; i < people.length; i++)
      EventRegistration.fromMap('cr$i', <String, dynamic>{
        'eventId': 'e1',
        'eventTitle': 'Yapay Zekâ ile Web Geliştirme Atölyesi',
        'clubId': 'c1',
        'studentId': 'st$i',
        'studentFirstName': people[i][0],
        'studentLastName': people[i][1],
        'studentName': '${people[i][0]} ${people[i][1]}',
        'studentEmail': '${people[i][0].toLowerCase()}@std.edu.tr',
        'studentPhone': '+90532000000$i',
        'studentUniversity': 'Boğaziçi Üniversitesi',
        'studentDepartment': people[i][2],
        'studentClassYear': '${i + 1}',
        'studentCity': 'İstanbul',
        'registeredAtMs': _at(9, 20 + i, 12),
        'checkedInAtMs': i < 2 ? _at(10, 4, 14) : null,
        'ticketCode': 'RP-AB${i}C-D${i}EF',
      }),
  ];
}

List<StudentCertificate> _certificates() => <StudentCertificate>[
  StudentCertificate.fromMap('cert1', <String, dynamic>{
    'studentId': 's1',
    'eventId': 'old1',
    'eventTitle': 'Networking Kahvaltısı',
    'clubId': 'c2',
    'clubName': 'İTÜ Girişimcilik Kulübü',
    'fileUrl': 'https://example.com/a.pdf',
    'fileName': 'katilim-belgesi.pdf',
    'contentType': 'application/pdf',
    'issuedAtMs': _at(9, 29, 12),
  }),
  StudentCertificate.fromMap('cert2', <String, dynamic>{
    'studentId': 's1',
    'eventId': 'old2',
    'eventTitle': 'Python ile Veri Bilimi Bootcamp',
    'clubId': 'c1',
    'clubName': 'Boğaziçi Bilişim Kulübü',
    'fileUrl': 'https://example.com/b.pdf',
    'fileName': 'katilim-belgesi.pdf',
    'contentType': 'application/pdf',
    'issuedAtMs': _at(9, 29, 12),
  }),
];

List<ClubProfile> _pendingClubs() => <ClubProfile>[
  ClubProfile.fromMap('pc1', <String, dynamic>{
    'email': 'muzik@kulup.odtu.edu.tr',
    'firstName': 'Deniz',
    'lastName': 'Aksoy',
    'phone': '+905551234567',
    'city': 'Ankara',
    'university': 'Orta Doğu Teknik Üniversitesi',
    'clubName': 'ODTÜ Müzik Topluluğu',
    'clubFields': <String>['Sanat', 'Müzik'],
    'clubPurpose': 'Kampüste canlı müzik kültürünü yaşatmak.',
    'clubContents': 'Konserler, jam gecesi, enstrüman atölyeleri.',
    'onboardingCompleted': true,
    'clubStatus': ClubStatus.pendingReview,
    'phoneVerified': true,
  }),
];

// ── Ortak sağlayıcı geçersiz kılmaları ─────────────────────────────────

List<Override> _baseOverrides(Session session) => <Override>[
  sessionProvider.overrideWithValue(session),
  currentUidProvider.overrideWithValue(session.user?.uid),
  onlineProvider.overrideWithValue(true),
  unreadNotificationCountProvider.overrideWithValue(2),
  studentProfileProvider.overrideWith(
    (Ref ref) => Stream<StudentProfile?>.value(session.studentProfile),
  ),
  clubProfileProvider.overrideWith(
    (Ref ref) => Stream<ClubProfile?>.value(session.clubProfile),
  ),
  followedClubIdsProvider.overrideWith(
    (Ref ref) => Stream<Set<String>>.value(const <String>{'c1'}),
  ),
  clubFollowerCountProvider.overrideWith((Ref ref) => Stream<int>.value(7)),
  waitlistedEventIdsProvider.overrideWith(
    (Ref ref) => Stream<Set<String>>.value(const <String>{}),
  ),
  eventByIdProvider.overrideWith(
    (Ref ref, String id) => Stream<AppEvent?>.value(
      _events().where((AppEvent e) => e.id == id).firstOrNull,
    ),
  ),
];

// ── Çekim ──────────────────────────────────────────────────────────────

final GlobalKey _boundaryKey = GlobalKey();

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required Widget home,
  required List<Override> overrides,
  double height = 844,
  double textScale = 1,
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  // Gölgeler testte varsayılan olarak keskin bloklar hâlinde çizilir;
  // cihazdaki yumuşak görünüm için çekim süresince açılır.
  debugDisableShadows = false;
  for (final Brightness brightness
      in _lightOnly ? <Brightness>[Brightness.light] : Brightness.values) {
    final double h = _shotH ?? height;
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(_shotW * 2, h * 2);
    final FakeViewPadding pad = _tablet
        ? const FakeViewPadding(top: 48, bottom: 40)
        : const FakeViewPadding(top: 88, bottom: 68);
    tester.view.padding = pad;
    tester.view.viewPadding = pad;

    final ThemeData theme = buildRegipassTheme(brightness: brightness);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: overrides,
          child: LanguageScope(
            language: 'tr',
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              darkTheme: theme,
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: home,
              builder: textScale == 1
                  ? null
                  : (BuildContext context, Widget? child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(textScale)),
                      child: child!,
                    ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    if (interact != null) {
      await interact(tester);
      await _settle(tester);
    }
    await _precacheImages(tester);
    await _settle(tester);

    final String suffix = brightness == Brightness.dark ? '-dark' : '';
    await _write(tester, '$name$suffix.png');
    // Hataları yut ama kaydet: düzenek bir ekranın patlamasıyla durmasın.
    final Object? error = tester.takeException();
    if (error != null) {
      // ignore: avoid_print
      print('!! $name$suffix: $error');
    }
  }
  tester.view.reset();
  debugDisableShadows = true;
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final Element element in find.byType(Image).evaluate()) {
      final Image image = element.widget as Image;
      try {
        await precacheImage(image.image, element);
      } catch (_) {}
    }
  });
}

Future<void> _write(WidgetTester tester, String file) async {
  final RenderRepaintBoundary boundary =
      _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$file').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _studentShell(String location, Widget child) =>
    StudentShell(location: location, child: child);

Widget _clubShell(String location, Widget child) =>
    ClubShell(location: location, child: child);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
    await _loadFonts();
  });

  List<Override> student() => <Override>[
    ..._baseOverrides(_studentSession()),
    studentVisibleEventsProvider.overrideWith(
      (Ref ref) => Stream<List<AppEvent>>.value(_events()),
    ),
    studentRegistrationsProvider.overrideWith(
      (Ref ref) => Stream<List<EventRegistration>>.value(_registrations()),
    ),
    appointmentsProvider.overrideWith((Ref ref) async {
      final Map<String, AppEvent> byId = <String, AppEvent>{
        for (final AppEvent e in _events()) e.id: e,
      };
      return <RegistrationWithEvent>[
        for (final EventRegistration r in _registrations())
          RegistrationWithEvent(registration: r, event: byId[r.eventId]),
      ];
    }),
    liveEventProvider.overrideWith(
      (Ref ref, String id) => Stream<AppEvent?>.value(
        _events().where((AppEvent e) => e.id == id).firstOrNull,
      ),
    ),
    studentCertificatesProvider.overrideWith(
      (Ref ref) => Stream<List<StudentCertificate>>.value(_certificates()),
    ),
    studentNewCertificatesProvider.overrideWith(
      (Ref ref, String uid) => Stream<List<Map<String, Object?>>>.value(
        const <Map<String, Object?>>[],
      ),
    ),
  ];

  List<Override> club() => <Override>[
    ..._baseOverrides(_clubSession()),
    clubDiscoverEventsProvider.overrideWith(
      (Ref ref) => Stream<List<AppEvent>>.value(_events()),
    ),
    clubEventsProvider.overrideWith(
      (Ref ref) => Stream<List<AppEvent>>.value(
        _events().where((AppEvent e) => e.clubId == 'c1').toList(),
      ),
    ),
    clubEventProvider.overrideWith(
      (Ref ref, String id) => Stream<AppEvent?>.value(
        _events().where((AppEvent e) => e.id == id).firstOrNull,
      ),
    ),
    eventRegistrationsProvider.overrideWith(
      (Ref ref, String id) =>
          Stream<List<EventRegistration>>.value(_clubRegistrations()),
    ),
    eventWaitlistCountProvider.overrideWith((Ref ref, String id) async => 0),
    doorGateProvider.overrideWith((Ref ref) async => null),
  ];

  // App Store 2.1(a): kamera izni kapalıyken QR ekranları.
  void mockCameraPermission(int status) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (MethodCall call) async => switch (call.method) {
            'checkPermissionStatus' => status,
            'requestPermissions' => <int, int>{1: status},
            _ => null,
          },
        );
  }

  testWidgets('qr scan camera blocked (student)', (WidgetTester tester) async {
    mockCameraPermission(4);
    await _shoot(
      tester,
      name: '40-qr-scan-camera-blocked',
      home: _studentShell(
        Routes.studentQrCheckin,
        const StudentQrCheckinScreen(),
      ),
      overrides: student(),
    );
  });

  testWidgets('qr scan camera ask again (student)', (
    WidgetTester tester,
  ) async {
    mockCameraPermission(0);
    await _shoot(
      tester,
      name: '41-qr-scan-camera-ask',
      home: _studentShell(
        Routes.studentQrCheckin,
        const StudentQrCheckinScreen(),
      ),
      overrides: student(),
    );
  });

  testWidgets('gate camera blocked (club)', (WidgetTester tester) async {
    mockCameraPermission(4);
    await _shoot(
      tester,
      name: '42-gate-camera-blocked',
      home: _clubShell(Routes.clubQrCheckin, const ClubQrCheckinScreen()),
      overrides: club(),
    );
  });

  testWidgets('login', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '01-login',
      home: const LoginScreen(),
      overrides: _baseOverrides(_guestSession),
    );
  });

  testWidgets('register', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '02-register',
      home: const RegisterScreen(),
      overrides: _baseOverrides(_guestSession),
      height: 1100,
    );
  });

  testWidgets('explore (misafir)', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '04-explore',
      home: const ExploreScreen(),
      overrides: <Override>[
        ..._baseOverrides(_guestSession),
        exploreEventsProvider.overrideWith(
          (Ref ref) async => ExploreEvents(_events()),
        ),
      ],
      height: 1100,
    );
  });

  testWidgets('onboarding', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '03-onboarding-student',
      home: const StudentInfoScreen(),
      overrides: _baseOverrides(_guestSession),
      height: 1300,
    );
  });

  testWidgets('student dashboard', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '10-student-dashboard',
      home: _studentShell(Routes.studentHome, const StudentDashboardScreen()),
      overrides: student(),
      height: 1400,
    );
  });

  testWidgets('student event detail', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '11-student-event-detail',
      home: _studentShell(Routes.studentHome, const StudentDashboardScreen()),
      overrides: student(),
      interact: (WidgetTester tester) async {
        // Keşfet puanlı sıralamada kart listenin aşağısında kalabilir; liste
        // tembel çizildiği için önce kaydırılarak bulunur.
        final Finder title = find.text('Bilişim Kariyer Günleri');
        await tester.scrollUntilVisible(
          title,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        final Finder card = title.first;
        await tester.ensureVisible(card);
        await tester.pump();
        await tester.tap(card, warnIfMissed: false);
      },
    );
  });

  testWidgets('shared event detail sheet', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '12-event-detail-sheet',
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) =>
              EventDetailSheet(event: _events()[1], forClub: true),
        ),
      ),
      overrides: club(),
      height: 1300,
    );
  });

  // İP-P1: etkinlik detayında Program — katılımcı (✓ / Şu an) ve
  // organizatör (oturum başına kişi) görünümleri.
  testWidgets('program', (WidgetTester tester) async {
    final Map<String, dynamic> base = <String, dynamic>{
      'title': 'Startup Okulu: 6 Haftalık Program',
      'clubId': 'c2',
      'clubName': 'İTÜ Girişimcilik Kulübü',
      'sessionCount': 4,
      'checkinMode': 'attendance_only',
      'currentSession': 2,
      'certificateThresholdPercent': 75,
      'eventDateAtMs': _at(10, 2, 18),
      'deadlineAtMs': _at(10, 1, 23),
      'sessionNames': <String>[
        'Açılış ve tanışma',
        "Fikirden ürüne",
        'Yatırımcı sunumu',
        'Demo günü',
      ],
      'sessionTimes': <Map<String, String>>[
        <String, String>{'start': '10:00', 'end': '10:45'},
        <String, String>{'start': '11:00', 'end': '12:30'},
        <String, String>{'start': '13:30', 'end': '15:00'},
        <String, String>{'start': '', 'end': ''},
      ],
    };
    final AppEvent ev = AppEvent.fromMap('p1', base);
    final EventRegistration mine = EventRegistration.fromMap(
      'p1_s1',
      <String, dynamic>{
        'eventId': 'p1',
        'studentId': 's1',
        'attendanceVerified': <String, dynamic>{'s1': 1},
        'sessionsAttended': 1,
        'lastAttendedSession': 1,
      },
    );
    final List<EventRegistration> all = <EventRegistration>[
      mine,
      EventRegistration.fromMap('p1_s2', <String, dynamic>{
        'eventId': 'p1',
        'studentId': 's2',
        'attendanceVerified': <String, dynamic>{'s1': 1, 's2': 2},
        'sessionsAttended': 2,
        'lastAttendedSession': 2,
      }),
      EventRegistration.fromMap('p1_s3', <String, dynamic>{
        'eventId': 'p1',
        'studentId': 's3',
        'manualAttendance': <String, dynamic>{
          's1': <String, dynamic>{'atMs': 1},
        },
        'sessionsAttended': 1,
        'lastAttendedSession': 1,
      }),
    ];
    await _shoot(
      tester,
      name: '17-program',
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'Katılımcı görünümü',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              EventProgramSection(event: ev, registration: mine),
              const SizedBox(height: 28),
              const Text(
                'Organizatör görünümü',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              EventProgramSection(event: ev, registrations: all),
            ],
          ),
        ),
      ),
      overrides: student(),
      height: 1100,
    );
  });

  testWidgets('student appointments', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '13-student-appointments',
      home: _studentShell(
        Routes.studentAppointments,
        const StudentAppointmentsScreen(),
      ),
      overrides: student(),
      height: 1300,
    );
  });

  testWidgets('student ticket', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '14-student-ticket',
      home: _studentShell(
        Routes.studentAppointments,
        const StudentAppointmentsScreen(),
      ),
      overrides: student(),
      interact: (WidgetTester tester) async {
        await tester.tap(
          find.text('Yapay Zekâ ile Web Geliştirme Atölyesi').first,
        );
      },
    );
  });

  testWidgets('student certificates', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '15-student-certificates',
      home: _studentShell(
        Routes.studentCertificates,
        const StudentCertificatesScreen(),
      ),
      overrides: student(),
    );
  });

  testWidgets('student account', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '16-student-account',
      home: _studentShell(Routes.studentAccount, const StudentAccountScreen()),
      overrides: student(),
      height: 1500,
    );
  });

  testWidgets('club dashboard', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '20-club-dashboard',
      home: _clubShell(Routes.clubHome, const ClubDashboardScreen()),
      overrides: club(),
      height: 1300,
    );
  });

  testWidgets('club events', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '23-club-events',
      home: _clubShell(Routes.clubEvents, const ClubEventsScreen()),
      overrides: club(),
      height: 1300,
    );
  });

  testWidgets('club account', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '24-club-account',
      home: _clubShell(Routes.clubAccount, const ClubAccountScreen()),
      overrides: club(),
      height: 1500,
    );
  });

  testWidgets('club event detail', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '21-club-event-detail',
      home: const ClubEventDetailScreen(eventId: 'e1'),
      overrides: club(),
      height: 3000,
    );
  });

  testWidgets('club create event', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '22-club-create-event',
      home: _clubShell(Routes.clubCreateEvent, const ClubCreateEventScreen()),
      overrides: club(),
      height: 3200,
    );
  });

  testWidgets('club create event — oturum adları', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '22b-club-create-event-session-names',
      home: _clubShell(Routes.clubCreateEvent, const ClubCreateEventScreen()),
      overrides: club(),
      height: 3400,
      interact: (WidgetTester tester) async {
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sadece Yoklama').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Oturum Sayısı'),
          '4',
        );
        await tester.pumpAndSettle();
        const List<String> names = <String>[
          'Açılış ve tanışma',
          'Makine Öğrenmesine Giriş',
          'Uygulamalı atölye',
        ];
        for (int i = 0; i < names.length; i++) {
          await tester.enterText(
            find.byKey(Key('session-name-${i + 1}')),
            names[i],
          );
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('club create event — iOS tarih tekerleği', (
    WidgetTester tester,
  ) async {
    await _shoot(
      tester,
      name: '22c-club-create-event-ios-date',
      home: _clubShell(Routes.clubCreateEvent, const ClubCreateEventScreen()),
      overrides: club(),
      height: 3200,
      interact: (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await tester.tap(find.text('Seçiniz').first);
        await tester.pumpAndSettle();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  });

  testWidgets('admin dashboard', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '30-admin-pending',
      home: const AdminShell(
        location: Routes.adminHome,
        child: AdminDashboardScreen(),
      ),
      overrides: <Override>[
        ..._baseOverrides(_guestSession),
        pendingClubsProvider.overrideWith(
          (Ref ref) => Stream<List<ClubProfile>>.value(_pendingClubs()),
        ),
      ],
      height: 1100,
    );
  });

  testWidgets('büyük yazı (1.3x)', (WidgetTester tester) async {
    await _shoot(
      tester,
      name: '90-textscale-login',
      home: const LoginScreen(),
      overrides: _baseOverrides(_guestSession),
      textScale: 1.3,
    );
    await _shoot(
      tester,
      name: '91-textscale-dashboard',
      home: _studentShell(Routes.studentHome, const StudentDashboardScreen()),
      overrides: student(),
      textScale: 1.3,
      height: 1400,
    );
    await _shoot(
      tester,
      name: '92-textscale-appointments',
      home: _studentShell(
        Routes.studentAppointments,
        const StudentAppointmentsScreen(),
      ),
      overrides: student(),
      textScale: 1.3,
    );
    await _shoot(
      tester,
      name: '93-textscale-club-event',
      home: const ClubEventDetailScreen(eventId: 'e1'),
      overrides: club(),
      textScale: 1.3,
      height: 3200,
    );
  });
}
