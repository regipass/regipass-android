// İP-ŞK: etkinlik şikâyeti + organizatör engelleme — saf kurallar, etkinlik
// penceresindeki satır, şikâyet penceresi, Hesabım'daki engel listesi.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_complaint.dart';
import 'package:regipass/features/shared/event_complaint_section.dart';
import 'package:regipass/features/student/blocked_organizers_section.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/l10n/extra_translations.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/services/event_complaint_service.dart';
import 'package:regipass/state/providers.dart';

class _FakeComplaintService extends EventComplaintService {
  _FakeComplaintService({this.blocked = const <BlockedOrganizer>[]});

  final List<String> calls = <String>[];
  final List<BlockedOrganizer> blocked;

  @override
  Future<void> reportEvent({
    required String eventId,
    required ComplaintReason reason,
    String note = '',
  }) async {
    calls.add('report:$eventId:${reason.wire}:${note.trim()}');
  }

  @override
  Future<void> setBlocked(String clubId, {required bool block}) async {
    calls.add('block:$clubId:$block');
  }

  @override
  Future<List<BlockedOrganizer>> listBlocked() async => blocked;
}

AppEvent _event({String clubId = 'clubA'}) => AppEvent.fromMap('ev1', <String, dynamic>{
  'clubId': clubId,
  'clubName': 'A Kulübü',
  'title': 'Kariyer Günü',
});

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: LanguageScope(
    language: 'tr',
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  test('şikâyet hazır mı: sebep şart, "diğer"de açıklama şart, not ≤ 500', () {
    expect(complaintReady(null, 'not'), isFalse);
    expect(complaintReady(ComplaintReason.fake, ''), isTrue);
    expect(complaintReady(ComplaintReason.other, ' a '), isFalse);
    expect(complaintReady(ComplaintReason.other, 'para istiyor'), isTrue);
    expect(complaintReady(ComplaintReason.spam, 'a' * 501), isFalse);
    expect(
      ComplaintReason.values.map((ComplaintReason r) => r.wire),
      <String>['inappropriate', 'fake', 'fraud', 'spam', 'other'],
    );
  });

  test('engellenen organizatörün etkinlikleri listeden çıkar', () {
    final List<String> events = <String>['clubA:e1', 'clubB:e2', ':e3'];
    String clubOf(String e) => e.split(':').first;
    expect(hideBlockedOrganizers(events, <String>{}, clubOf), events);
    expect(
      hideBlockedOrganizers(events, <String>{'clubA'}, clubOf),
      <String>['clubB:e2', ':e3'],
    );
  });

  test('sunucu hata nedeni çeviri anahtarına gider; tüm metinler iki dilde var', () {
    expect(complaintErrorKey('own-event'), 'complaint.error.ownEvent');
    expect(complaintErrorKey('bilinmeyen'), 'complaint.error.generic');
    final List<String> keys = <String>[
      'complaint.report',
      'complaint.title',
      'complaint.help',
      'complaint.send',
      'complaint.sent',
      'complaint.block.button',
      'complaint.block.confirm',
      'complaint.blocked.title',
      for (final ComplaintReason r in ComplaintReason.values) r.labelKey,
      for (final String reason in <String>[
        'sign-in-required',
        'student-only',
        'own-event',
        'event-not-found',
        'note-required',
        'too-many-blocks',
        'x',
      ])
        complaintErrorKey(reason),
    ];
    for (final String lang in <String>['tr', 'en']) {
      for (final String key in keys) {
        expect(kExtraTranslations[lang]![key], isNotNull, reason: '$lang · $key');
      }
    }
  });

  testWidgets('girişsiz kullanıcıya ve etkinliğin sahibine satır görünmez', (
    WidgetTester tester,
  ) async {
    final _FakeComplaintService service = _FakeComplaintService();
    await tester.pumpWidget(
      _wrap(EventComplaintSection(event: _event()), <Override>[
        currentUidProvider.overrideWithValue(null),
        eventComplaintServiceProvider.overrideWithValue(service),
      ]),
    );
    expect(find.byKey(const ValueKey<String>('complaint-report-button')), findsNothing);

    await tester.pumpWidget(
      _wrap(EventComplaintSection(event: _event()), <Override>[
        currentUidProvider.overrideWithValue('clubA'),
        eventComplaintServiceProvider.overrideWithValue(service),
      ]),
    );
    expect(find.byKey(const ValueKey<String>('complaint-report-button')), findsNothing);
  });

  testWidgets('şikâyet: sebep seçilmeden gönderilmez; gönderince sunucuya gider', (
    WidgetTester tester,
  ) async {
    final _FakeComplaintService service = _FakeComplaintService();
    await tester.pumpWidget(
      _wrap(EventComplaintSection(event: _event()), <Override>[
        currentUidProvider.overrideWithValue('stu1'),
        eventComplaintServiceProvider.overrideWithValue(service),
      ]),
    );
    await tester.tap(find.byKey(const ValueKey<String>('complaint-report-button')));
    await tester.pumpAndSettle();
    expect(find.text('Etkinliği şikâyet et'), findsOneWidget);

    final Finder send = find.byKey(const ValueKey<String>('complaint-send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('complaint-reason-fraud')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('complaint-note')),
      ' Para istiyor ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(service.calls, <String>['report:ev1:fraud:Para istiyor']);
    expect(find.text('Şikâyetin bize ulaştı. Teşekkürler.'), findsOneWidget);
  });

  testWidgets('engelle: onay ister, sonra sunucuya gider ve pencere kapatılır', (
    WidgetTester tester,
  ) async {
    final _FakeComplaintService service = _FakeComplaintService();
    int closed = 0;
    await tester.pumpWidget(
      _wrap(
        EventComplaintSection(event: _event(), onBlocked: () => closed += 1),
        <Override>[
          currentUidProvider.overrideWithValue('stu1'),
          eventComplaintServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('complaint-block-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('A Kulübü engellensin mi?'), findsOneWidget);
    await tester.tap(find.text('İptal').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('complaint-block-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('complaint-block-confirm')));
    await tester.pumpAndSettle();
    expect(service.calls, <String>['block:clubA:true']);
    expect(closed, 1);
  });

  testWidgets('Hesabım: engel listesi boşsa görünmez; "Engeli kaldır" çalışır', (
    WidgetTester tester,
  ) async {
    final _FakeComplaintService empty = _FakeComplaintService();
    await tester.pumpWidget(
      _wrap(const BlockedOrganizersSection(), <Override>[
        currentUidProvider.overrideWithValue('stu1'),
        blockedOrganizerIdsProvider.overrideWith(
          (Ref ref) => Stream<Set<String>>.value(const <String>{}),
        ),
        eventComplaintServiceProvider.overrideWithValue(empty),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('blocked-organizers-section')), findsNothing);

    final _FakeComplaintService service = _FakeComplaintService(
      blocked: const <BlockedOrganizer>[
        BlockedOrganizer(clubId: 'clubA', clubName: 'A Kulübü', logoUrl: ''),
      ],
    );
    await tester.pumpWidget(
      _wrap(const BlockedOrganizersSection(), <Override>[
        currentUidProvider.overrideWithValue('stu1'),
        blockedOrganizerIdsProvider.overrideWith(
          (Ref ref) => Stream<Set<String>>.value(const <String>{'clubA'}),
        ),
        eventComplaintServiceProvider.overrideWithValue(service),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('A Kulübü'), findsOneWidget);
    await tester.tap(find.text('Engeli kaldır'));
    await tester.pumpAndSettle();
    expect(service.calls, <String>['block:clubA:false']);
  });
}
