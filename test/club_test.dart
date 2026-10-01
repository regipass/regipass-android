import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/features/club/club_account_screen.dart';
import 'package:regipass/features/club/club_create_event_screen.dart';
import 'package:regipass/domain/event_utils.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/features/club/club_providers.dart';
import 'package:regipass/features/club/club_shell.dart';
import 'package:regipass/features/shared/common_widgets.dart';
import 'package:regipass/features/shared/profile_photo.dart';
import 'package:regipass/features/club/location_picker_screen.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/models/profiles.dart';
import 'package:regipass/services/firebase_refs.dart';
import 'package:regipass/state/providers.dart';

/// Kulüp tarafının davranış testleri.
///
/// Ağ/Firebase gerektiren akışlar değil, saf mantık ve yerleşim doğrulanır:
/// çoklu alan keşif algoritmasını bozmuyor mu, gruplama web'deki üç grupla
/// aynı mı, alt çubuk taşmadan çiziliyor mu.
AppEvent event({
  String id = 'e1',
  int deadlineDaysFromNow = 7,
  int? eventDateDaysFromNow,
  DateTime? referenceNow,
  bool registrationClosed = false,
  bool entryOpen = false,
  int entryStartedAtMs = 0,
  int currentSession = 0,
  bool sessionsCompleted = false,
  bool hiddenFromClubList = false,
  List<String> clubFields = const <String>[],
  String clubField = '',
  String targetScope = 'public',
}) {
  final DateTime deadline = (referenceNow ?? DateTime.now()).add(
    Duration(days: deadlineDaysFromNow),
  );

  return AppEvent.fromMap(id, <String, dynamic>{
    'title': 'Etkinlik $id',
    'deadlineAtMs': DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
      23,
      59,
      59,
    ).millisecondsSinceEpoch,
    if (eventDateDaysFromNow != null)
      'eventDateAtMs': DateTime(deadline.year, deadline.month, deadline.day)
          .add(Duration(days: eventDateDaysFromNow - deadlineDaysFromNow))
          .millisecondsSinceEpoch,
    'registrationClosed': registrationClosed,
    'entryOpen': entryOpen,
    'entryStartedAtMs': entryStartedAtMs,
    'currentSession': currentSession,
    'sessionsCompleted': sessionsCompleted,
    'hiddenFromClubList': hiddenFromClubList,
    'clubFields': clubFields,
    'clubField': clubField,
    'targetScope': targetScope,
  });
}

StudentProfile student({String department = '', String university = ''}) =>
    StudentProfile.fromMap('s1', <String, dynamic>{
      'department': department,
      'university': university,
    });

void main() {
  group('çoklu kulüp alanı', () {
    test('dizi yoksa tekil alana düşer', () {
      final AppEvent e = event(clubField: 'Bilgisayar ve Yazılım');
      expect(eventClubFields(e), <String>['Bilgisayar ve Yazılım']);
    });

    test('dizi varsa tümü okunur', () {
      final AppEvent e = event(
        clubFields: <String>['Hukuk', 'İşletme'],
        clubField: 'Hukuk',
      );
      expect(eventClubFields(e), <String>['Hukuk', 'İşletme']);
    });

    test('tek alanlı kulüpte davranış eskisiyle aynı kalır', () {
      // Keşif kademesi, çoklu alan desteği eklenmeden önceki sonucu vermeli.
      final AppEvent e = event(clubField: 'Bilgisayar ve Yazılım');
      final StudentProfile s = student(department: 'Bilgisayar Mühendisliği');

      expect(getStudentEventPriority(e, s), 2); // ilgili bölüm, farklı üni.
    });

    test('ikinci alan sayesinde ilgisiz görünen etkinlik yakalanır', () {
      // Kulübün birinci alanı öğrenciyle ilgisiz; ikinci alan tam eşleşiyor.
      final AppEvent related = event(
        clubFields: <String>['Spor Bilimleri', 'Hukuk'],
        clubField: 'Spor Bilimleri',
      );
      final AppEvent unrelated = event(
        id: 'e2',
        clubFields: <String>['Spor Bilimleri'],
        clubField: 'Spor Bilimleri',
      );
      final StudentProfile s = student(department: 'Hukuk');

      expect(getStudentEventPriority(related, s), 2);
      expect(getStudentEventPriority(unrelated, s), 3);
    });

    test('ağırlık en güçlü alandan alınır', () {
      final AppEvent multi = event(
        clubFields: <String>['Spor Bilimleri', 'Bilgisayar ve Yazılım'],
      );
      final AppEvent single = event(
        id: 'e2',
        clubFields: <String>['Spor Bilimleri'],
      );
      final StudentProfile s = student(department: 'Bilgisayar Mühendisliği');

      expect(
        getDepartmentFieldWeight(multi, s),
        greaterThan(getDepartmentFieldWeight(single, s)),
      );
    });
  });

  group('kulüp etkinlik grupları', () {
    test('aktif / gelecek / geçmiş ayrımı webdeki etkinlik günü kuralıyla', () {
      final DateTime now = DateTime(2026, 9, 8, 12);
      final List<AppEvent> events = <AppEvent>[
        event(id: 'aktif', eventDateDaysFromNow: 0, referenceNow: now),
        // Kayıtların kapanması tek başına etkinliği aktife taşımaz.
        event(
          id: 'gelecek',
          eventDateDaysFromNow: 2,
          referenceNow: now,
          registrationClosed: true,
        ),
        event(id: 'gecmis', eventDateDaysFromNow: -1, referenceNow: now),
      ];

      final ClubEventGroups groups = groupClubEvents(events, now: now);

      expect(groups.active.map((AppEvent e) => e.id), <String>['aktif']);
      expect(groups.upcoming.map((AppEvent e) => e.id), <String>['gelecek']);
      expect(groups.past.map((AppEvent e) => e.id), <String>['gecmis']);
    });

    test('kulüp listesinden kaldırılan etkinlik hiçbir grupta görünmez', () {
      final ClubEventGroups groups = groupClubEvents(<AppEvent>[
        event(id: 'gizli', hiddenFromClubList: true),
      ]);

      expect(groups.isEmpty, isTrue);
    });

    test(
      'yoklama başlatılan gelecek etkinlik aktife, tamamlanan etkinlik geçmişe gider',
      () {
        final DateTime now = DateTime(2026, 9, 8, 12);
        final ClubEventGroups groups = groupClubEvents(<AppEvent>[
          event(
            id: 'basladi',
            eventDateDaysFromNow: 3,
            referenceNow: now,
            entryStartedAtMs: now.millisecondsSinceEpoch,
          ),
          event(
            id: 'tamamlandi',
            eventDateDaysFromNow: 3,
            referenceNow: now,
            sessionsCompleted: true,
          ),
        ], now: now);

        expect(groups.active.map((AppEvent e) => e.id), <String>['basladi']);
        expect(groups.past.map((AppEvent e) => e.id), <String>['tamamlandi']);
      },
    );
  });

  group('belge hakkı', () {
    EventRegistration reg(String id, int attended) => EventRegistration.fromMap(
      id,
      <String, dynamic>{'studentId': id, 'sessionsAttended': attended},
    );

    test('eşik yoksa en az bir oturuma katılan hak kazanır', () {
      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'sessionCount': 4,
      });

      final List<EventRegistration> eligible = certificateEligible(
        e,
        <EventRegistration>[reg('a', 0), reg('b', 1), reg('c', 4)],
      );

      expect(eligible.map((EventRegistration r) => r.id), <String>['b', 'c']);
    });

    test('eşik varsa yüzdeye göre süzülür', () {
      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'sessionCount': 4,
        'certificateThresholdPercent': 75,
      });

      final List<EventRegistration> eligible = certificateEligible(
        e,
        <EventRegistration>[reg('a', 2), reg('b', 3), reg('c', 4)],
      );

      expect(eligible.map((EventRegistration r) => r.id), <String>['b', 'c']);
    });

    // Tek oturumlu etkinlikte oturum sayacı hiç işlemiyor; hak sahibi
    // listesi eskiden HER ZAMAN boş çıkıyor, yüklenen belge kimseye
    // ulaşmıyordu.
    test('tek oturumluda girişi onaylanan hak kazanır', () {
      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'sessionCount': 1,
      });

      EventRegistration checkedIn(String id, {required bool checked}) =>
          EventRegistration.fromMap(id, <String, dynamic>{
            'studentId': id,
            'checkedInAtMs': checked ? 1700000000000 : null,
          });

      final List<EventRegistration> eligible = certificateEligible(
        e,
        <EventRegistration>[
          checkedIn('a', checked: false),
          checkedIn('b', checked: true),
        ],
      );

      expect(eligible.map((EventRegistration r) => r.id), <String>['b']);
    });

    test('tek oturumluda eski eşik değeri hak sahibini elemez', () {
      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'sessionCount': 1,
        'certificateThresholdPercent': 80,
      });

      final List<EventRegistration> eligible = certificateEligible(
        e,
        <EventRegistration>[
          EventRegistration.fromMap('a', <String, dynamic>{
            'studentId': 'a',
            'checkedInAtMs': 1700000000000,
          }),
        ],
      );

      expect(eligible.map((EventRegistration r) => r.id), <String>['a']);
    });
  });

  // Aynı etkinliğe yüklenen ikinci belge, birincinin öğrencideki kaydını ve
  // dosyasını eziyordu: kimlik yalnızca etkinlik+öğrenciydi. Anahtar artık
  // belgeye bağlı.
  group('belge anahtarı', () {
    EventDocument doc({
      String url = 'https://x/a.pdf',
      String path = '',
      int uploadedAtMs = 0,
    }) => EventDocument(
      url: url,
      name: 'a.pdf',
      path: path,
      contentType: 'application/pdf',
      uploadedAtMs: uploadedAtMs,
    );

    test('aynı etkinliğin iki belgesi ayrı anahtar alır', () {
      expect(
        doc(uploadedAtMs: 1700000000000).key,
        isNot(doc(uploadedAtMs: 1700000000001).key),
      );
    });

    test('aynı belge her okunduğunda aynı anahtarı verir', () {
      expect(doc(uploadedAtMs: 1700000000000).key, '1700000000000');
    });

    test('zaman damgası yoksa yol, o da yoksa adres ayırt eder', () {
      expect(doc(path: 'certificates/c/e/_belge-42.pdf').key, 'belge42pdf');
      expect(doc(url: 'https://x/a.pdf').key, isNotEmpty);
      expect(doc(url: 'https://x/a.pdf').key, doc(url: 'https://x/a.pdf').key);
      expect(
        doc(url: 'https://x/a.pdf').key,
        isNot(doc(url: 'https://x/b.pdf').key),
      );
    });

    test('kimlik belgeye göre ayrışır, aynı belgede sabit kalır', () {
      expect(certificateIdFor('e1', 's1', '1'), 'e1_s1_1');
      expect(
        certificateIdFor('e1', 's1', '1'),
        certificateIdFor('e1', 's1', '1'),
      );
      expect(
        certificateIdFor('e1', 's1', '1'),
        isNot(certificateIdFor('e1', 's1', '2')),
      );
    });
  });

  group('belge dağıtım kapısı', () {
    AppEvent withDate({
      required int sessionCount,
      required int endOffsetHours,
      bool sessionsCompleted = false,
    }) {
      final DateTime end = DateTime.now().add(Duration(hours: endOffsetHours));

      return AppEvent.fromMap('e', <String, dynamic>{
        'sessionCount': sessionCount,
        'sessionsCompleted': sessionsCompleted,
        'eventEndAtMs': end.millisecondsSinceEpoch,
        'deadlineAtMs': end.millisecondsSinceEpoch,
      });
    }

    test('tek oturumlu: etkinlik bitmeden kapalı, bitince açık', () {
      expect(
        canDistributeCertificates(withDate(sessionCount: 1, endOffsetHours: 2)),
        isFalse,
      );
      expect(
        canDistributeCertificates(
          withDate(sessionCount: 1, endOffsetHours: -2),
        ),
        isTrue,
      );
    });

    test('tek oturumlu: son başvurusu geçse de etkinlik bitmeden kapalı', () {
      final DateTime deadline = DateTime.now().subtract(
        const Duration(hours: 2),
      );
      final DateTime eventEnd = DateTime.now().add(const Duration(hours: 2));

      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'sessionCount': 1,
        'deadlineAtMs': deadline.millisecondsSinceEpoch,
        'eventEndAtMs': eventEnd.millisecondsSinceEpoch,
      });

      expect(isPastEvent(e), isTrue);
      expect(canDistributeCertificates(e), isFalse);
    });

    test('oturumlu: kapıyı takvim değil, oturumların bitmesi açar', () {
      expect(
        canDistributeCertificates(
          withDate(sessionCount: 3, endOffsetHours: -48),
        ),
        isFalse,
      );
      expect(
        canDistributeCertificates(
          withDate(
            sessionCount: 3,
            endOffsetHours: 48,
            sessionsCompleted: true,
          ),
        ),
        isTrue,
      );
    });

    test('bitiş anı yoksa etkinlik gününün sonuna bakılır', () {
      final DateTime yesterday = DateTime.now().subtract(
        const Duration(days: 1),
      );

      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'sessionCount': 1,
        'eventDateAtMs': DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
        ).millisecondsSinceEpoch,
      });

      expect(isEventFinished(e), isTrue);
    });

    test('bugün yapılan etkinlik gün bitmeden bitmiş sayılmaz', () {
      final DateTime today = DateTime.now();

      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'sessionCount': 1,
        'eventDateAtMs': DateTime(
          today.year,
          today.month,
          today.day,
        ).millisecondsSinceEpoch,
      });

      expect(
        isEventFinished(
          e,
          now: DateTime(today.year, today.month, today.day, 12),
        ),
        isFalse,
      );
    });
  });

  testWidgets('kulüp alt çubuğu dört sekme + ekleme düğmesi çizer', (
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
            home: ClubShell(
              location: Routes.clubHome,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keşfet'), findsOneWidget);
    expect(find.text('Etkinliklerim'), findsOneWidget);
    expect(find.text('Yeni Etkinlik'), findsOneWidget);
    expect(find.text('Hesabım'), findsOneWidget);
    expect(find.byKey(clubQrToggleKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kulüp QR düğmesi okut/oluştur eylemlerini açar', (
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
            home: ClubShell(
              location: Routes.clubHome,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Eylemler hep ağaçta durur; açık olup olmadıklarını IgnorePointer söyler.
    bool actionsHitTestable() =>
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.byKey(clubQrScanActionKey),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring ==
        false;

    expect(actionsHitTestable(), isFalse);

    await tester.tap(find.byKey(clubQrToggleKey));
    await tester.pumpAndSettle();

    expect(actionsHitTestable(), isTrue);
    expect(find.byKey(clubQrCreateActionKey), findsOneWidget);
    expect(find.text('QR Okut'), findsOneWidget);
    expect(find.text('QR Oluştur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('harita seçici hazır konumla açılır ve onay döndürür', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 820);
    addTearDown(tester.view.reset);

    PickedLocation? result;

    await tester.pumpWidget(
      LanguageScope(
        language: 'tr',
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<PickedLocation>(
                  MaterialPageRoute<PickedLocation>(
                    builder: (_) => const LocationPickerScreen(
                      initialLat: 41.0082,
                      initialLng: 28.9784,
                      initialRadius: 120,
                    ),
                  ),
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Döşemeler ağdan gelmiyor (testte HTTP kapalı) ama harita, iğne ve
    // alt panel çizilmeli — yerleşim hatası olsaydı burada patlardı.
    expect(find.text('Bu Konumu Kullan'), findsOneWidget);
    expect(find.text('120 m'), findsOneWidget);

    await tester.tap(find.text('Bu Konumu Kullan'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.lat, closeTo(41.0082, 0.0001));
    expect(result!.lng, closeTo(28.9784, 0.0001));
    expect(result!.radius, 120);
  });

  // Düzenleme kipindeki "İptal" düğmesi bir zamanlar `Row` içinde esnek
  // olmayan çocuktu; tema düğmelere sonsuz genişlik verdiği için düzen
  // çöküyor ve hesap ekranı gerçek cihazda donuyordu.
  testWidgets('kulüp hesabında düzenleme kipi düzeni bozmaz', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);

    const ClubProfile profile = ClubProfile(
      uid: 'u1',
      email: 'kulup@ornek.com',
      firstName: 'Ayşe',
      lastName: 'Yılmaz',
      phone: '+905551112233',
      city: 'İstanbul',
      university: 'Boğaziçi Üniversitesi',
      clubName: 'Test Kulübü',
      clubField: 'Teknoloji',
      clubFields: <String>['Teknoloji'],
      clubPurpose: 'Amaç',
      clubContents: 'İçerik',
      logoUrl: '',
      logoPath: '',
      documentIssue: '',
      adminMessages: <AdminMessage>[],
      onboardingCompleted: true,
      clubStatus: ClubStatus.approved,
      banned: false,
      phoneVerified: true,
      hasPassword: true,
      documents: <String, Map<String, dynamic>>{},
      termsAccepted: true,
      termsAcceptedAtMs: null,
      marketingConsent: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            const Session(
              isLoading: false,
              user: null,
              appUser: null,
              studentProfile: null,
              clubProfile: profile,
              activeRole: null,
            ),
          ),
        ],
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            theme: buildRegipassTheme(),
            home: const ClubAccountScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Logo kutusu formun üstünde, kalemiyle birlikte durur: kulüp fotoğrafı
    // nereden ekleyeceğini aramak zorunda kalmasın.
    expect(find.byType(EditableClubLogo), findsOneWidget);

    await tester.tap(find.text('Bilgileri Düzenle'));
    await tester.pumpAndSettle();

    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Yeni etkinlik formunun istenen düzeni: geri oku yok (alt çubukta kendi
  // sekmesi var), başlık alanı doğru yazılmış, konum adı yalnızca haritadan
  // seçim yapıldıktan sonra açılıyor.
  testWidgets('yeni etkinlik formu geri okusuz açılır', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 3600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            const Session(
              isLoading: false,
              user: null,
              appUser: null,
              studentProfile: null,
              clubProfile: null,
              activeRole: null,
            ),
          ),
        ],
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            theme: buildRegipassTheme(),
            home: const ClubCreateEventScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Etkinlik Adı'), findsOneWidget);
    expect(find.text('Haritadan Konum Seç'), findsOneWidget);
    // Konum seçilmeden ad alanı görünmez.
    expect(find.text('Konum Adı'), findsNothing);

    // Saat alanı Material'ın seçicisini açar: kulüp istediği saati yazabilir.
    await tester.tap(find.text('--:--').first);
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('görsel alanı boşken form fotoğraf göstermez', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 3600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            const Session(
              isLoading: false,
              user: null,
              appUser: null,
              studentProfile: null,
              clubProfile: null,
              activeRole: null,
            ),
          ),
        ],
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            theme: buildRegipassTheme(),
            home: const ClubCreateEventScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kapak seçilmediğinde ağdan bir fotoğraf çekilmez: "Cihazdan Seç"in
    // altında gri marka perdesinin küçük bir önizlemesi ve tek satırlık
    // açıklama durur.
    expect(find.byType(Image), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Cihazdan Seç'), findsOneWidget);
    expect(find.byType(EventCoverPlaceholder), findsOneWidget);
    expect(
      find.text('Görsel eklemezsen kapakta gri Regipass logosu görünür.'),
      findsOneWidget,
    );

    // Adres kutusu formdan kaldırıldı: kapak yalnızca cihazdan seçilir.
    expect(find.widgetWithText(TextField, 'Görsel Adresi'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  // Kulüp hesabı görüntüleme kipinde form alanları yerine simgeli bilgi
  // kartları çizer; düzenleme kipine geçmeden hiçbir alan yazılabilir olmamalı.
  testWidgets('kulüp hesabı görüntüleme kipinde bilgi kartları gösterir', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);

    const ClubProfile profile = ClubProfile(
      uid: 'u1',
      email: 'kulup@ornek.com',
      firstName: 'Ayşe',
      lastName: 'Yılmaz',
      phone: '+905551112233',
      city: 'İstanbul',
      university: 'Boğaziçi Üniversitesi',
      clubName: 'Test Kulübü',
      clubField: 'Teknoloji',
      clubFields: <String>['Teknoloji'],
      clubPurpose: 'Amaç',
      clubContents: 'İçerik',
      logoUrl: '',
      logoPath: '',
      documentIssue: '',
      adminMessages: <AdminMessage>[],
      onboardingCompleted: true,
      clubStatus: ClubStatus.approved,
      banned: false,
      phoneVerified: true,
      hasPassword: true,
      documents: <String, Map<String, dynamic>>{},
      termsAccepted: true,
      termsAcceptedAtMs: null,
      marketingConsent: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            const Session(
              isLoading: false,
              user: null,
              appUser: null,
              studentProfile: null,
              clubProfile: profile,
              activeRole: null,
            ),
          ),
        ],
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            theme: buildRegipassTheme(),
            home: const ClubAccountScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Görüntüleme kipi: metin kutusu yok, bölüm başlıkları ve değerler var.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Yetkili Bilgileri'), findsOneWidget);
    expect(find.text('Organizatör Bilgileri'), findsOneWidget);
    expect(find.text('Boğaziçi Üniversitesi'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_outlined), findsWidgets);

    // Düzenlemeye geçince alanlar simgeleriyle açılır.
    await tester.tap(find.text('Bilgileri Düzenle'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
    expect(find.byIcon(Icons.groups_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // Oturum ilerlemesi "2/4" metniyle değil, oturum sayısı kadar bölmesi olan
  // bir çubukla anlatılıyor.
  testWidgets('oturum çubuğu oturum sayısı kadar bölme çizer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRegipassTheme(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SessionProgressBar(total: 4, completed: 2),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Iterable<AnimatedContainer> slots = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(slots.length, 4);

    final List<Color?> colors = slots
        .map(
          (AnimatedContainer slot) => (slot.decoration! as BoxDecoration).color,
        )
        .toList();

    // İlk iki bölme dolu, kalan ikisi boş.
    expect(colors[0], BrandColors.red);
    expect(colors[1], BrandColors.red);
    expect(colors[2], isNot(BrandColors.red));
    expect(colors[3], isNot(BrandColors.red));
    expect(tester.takeException(), isNull);
  });

  // Tamamlanmış oturumda çubuğun tamamı dolu ve yeşile döner.
  testWidgets('oturumlar bitince çubuk tamamen dolu ve yeşil olur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRegipassTheme(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SessionProgressBar(total: 3, completed: 3, done: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Iterable<AnimatedContainer> slots = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(slots.length, 3);
    for (final AnimatedContainer slot in slots) {
      expect((slot.decoration! as BoxDecoration).color, BrandColors.success);
    }
  });

  // Çoklu belge: eski tek şablon alanları da listede tek eleman olarak okunur,
  // yeni dizi varsa tamamı okunur.
  test('etkinlik belgeleri hem dizi hem eski tek şablon biçiminde okunur', () {
    final AppEvent legacy = AppEvent.fromMap('e1', <String, dynamic>{
      'title': 'Eski',
      'certificateTemplateUrl': 'https://ornek.com/belge.pdf',
      'certificateTemplateName': 'belge.pdf',
      'certificateTemplateType': 'application/pdf',
    });

    expect(legacy.certificateDocuments.length, 1);
    expect(legacy.certificateDocuments.single.name, 'belge.pdf');
    expect(legacy.hasCertificateDocuments, isTrue);

    final AppEvent modern = AppEvent.fromMap('e2', <String, dynamic>{
      'title': 'Yeni',
      'certificateTemplateUrl': 'https://ornek.com/ikinci.pdf',
      'certificateDocuments': <Object>[
        <String, dynamic>{
          'url': 'https://ornek.com/birinci.pdf',
          'name': 'birinci.pdf',
          'path': 'certificates/c1/e2/_belge-1.pdf',
          'contentType': 'application/pdf',
          'uploadedAtMs': 1,
        },
        <String, dynamic>{
          'url': 'https://ornek.com/ikinci.pdf',
          'name': 'ikinci.pdf',
          'path': 'certificates/c1/e2/_belge-2.pdf',
          'contentType': 'application/pdf',
          'uploadedAtMs': 2,
        },
      ],
    });

    expect(modern.certificateDocuments.length, 2);
    expect(modern.certificateDocuments.last.path, endsWith('_belge-2.pdf'));

    final AppEvent none = AppEvent.fromMap('e3', <String, dynamic>{
      'title': 'Belgesiz',
    });
    expect(none.hasCertificateDocuments, isFalse);
  });

  group('isEventDayPast (kulüp listesi: iptal / düzenle / listeden kaldır)', () {
    test('son başvurusu geçmiş ama günü bugün olan etkinlik geçmiş sayılmaz', () {
      final DateTime now = DateTime(2026, 10, 1, 15);
      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'deadlineAtMs': DateTime(2026, 9, 30, 23, 59).millisecondsSinceEpoch,
        'eventDateAtMs': DateTime(2026, 10, 1).millisecondsSinceEpoch,
      });
      expect(isPastEvent(e, now: now), isTrue);
      expect(isEventDayPast(e, now: now), isFalse);
    });

    test('günü dün olan etkinlik geçmiştir', () {
      final AppEvent e = AppEvent.fromMap('e', <String, dynamic>{
        'eventDateAtMs': DateTime(2026, 9, 30).millisecondsSinceEpoch,
      });
      expect(isEventDayPast(e, now: DateTime(2026, 10, 1, 9)), isTrue);
    });
  });
}
