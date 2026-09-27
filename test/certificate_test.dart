// İP-8 / İP-9: yeni sertifika sistemi — kurallar (web certificate-rules.js
// ile aynı sonuçlar) ve mobil kulüp paneli.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/certificate_rules.dart';
import 'package:regipass/features/club/certificate_panel_card.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/services/certificate_service.dart';

AppEvent ev(Map<String, dynamic> extra) =>
    AppEvent.fromMap('e1', <String, dynamic>{'clubId': 'clubA', 'title': 'Zirve', ...extra});

EventRegistration reg(String id, Map<String, dynamic> extra) =>
    EventRegistration.fromMap('e1_$id', <String, dynamic>{'eventId': 'e1', 'studentId': id, ...extra});

class _FakeCerts extends CertificateService {
  final List<String> calls = <String>[];
  @override
  Future<Map<String, Object?>> send(String eventId, {bool outdated = false}) async {
    calls.add('send:$eventId:$outdated');
    return <String, Object?>{'sent': 2, 'failed': 0};
  }
}

void main() {
  group('Gönder kapısı', () {
    test('Sadece Check-in: kapı bitirilince açılır', () {
      expect(certificateSendGate(ev(<String, dynamic>{'checkinMode': 'checkin_only'})).reason, 'checkin-not-started');
      expect(certificateSendGate(ev(<String, dynamic>{'checkinMode': 'checkin_only', 'entryStartedAtMs': 5, 'entryOpen': true})).reason, 'checkin-open');
      expect(certificateSendGate(ev(<String, dynamic>{'checkinMode': 'checkin_only', 'entryStartedAtMs': 5, 'entryOpen': false})).open, isTrue);
    });
    test('yoklamalı: Oturumları Bitir; iptal edilen kapalı', () {
      expect(certificateSendGate(ev(<String, dynamic>{'checkinMode': 'attendance_only', 'sessionCount': 5})).reason, 'sessions-not-finished');
      expect(certificateSendGate(ev(<String, dynamic>{'checkinMode': 'attendance_only', 'sessionCount': 5, 'sessionsCompleted': true})).open, isTrue);
      expect(certificateSendGate(ev(<String, dynamic>{'checkinMode': 'attendance_only', 'sessionCount': 5, 'sessionsCompleted': true, 'cancelled': true})).reason, 'event-cancelled');
    });
  });

  group('hak sahipliği (web ile aynı)', () {
    final AppEvent e = ev(<String, dynamic>{'checkinMode': 'attendance_only', 'sessionCount': 5});
    test('eşik', () {
      expect(evaluateCertificate(e, reg('a', <String, dynamic>{'sessionsAttended': 4}), 80).eligible, isTrue);
      expect(evaluateCertificate(e, reg('a', <String, dynamic>{'sessionsAttended': 3}), 80).reason, 'below-threshold');
      expect(evaluateCertificate(e, reg('a', <String, dynamic>{'sessionsAttended': 1}), null).eligible, isTrue);
      expect(evaluateCertificate(e, reg('a', <String, dynamic>{'sessionsAttended': 0}), null).reason, 'no-session');
      final AppEvent three = ev(<String, dynamic>{'checkinMode': 'attendance_only', 'sessionCount': 3});
      expect(evaluateCertificate(three, reg('a', <String, dynamic>{'sessionsAttended': 2}), 67).eligible, isFalse);
      expect(evaluateCertificate(three, reg('a', <String, dynamic>{'sessionsAttended': 2}), 66).eligible, isTrue);
    });
    test('ücretli: ödeme bekleyen almaz', () {
      final AppEvent paid = ev(<String, dynamic>{'checkinMode': 'attendance_only', 'sessionCount': 5, 'feeType': 'paid'});
      expect(evaluateCertificate(paid, reg('a', <String, dynamic>{'sessionsAttended': 5, 'paymentStatus': 'pending'}), null).reason, 'payment-pending');
      expect(evaluateCertificate(paid, reg('a', <String, dynamic>{'sessionsAttended': 5, 'paymentStatus': 'paid'}), null).eligible, isTrue);
    });
    test('Sadece Check-in: kapıdan giren', () {
      final AppEvent c = ev(<String, dynamic>{'checkinMode': 'checkin_only'});
      expect(evaluateCertificate(c, reg('a', <String, dynamic>{'checkedInAtMs': 9}), 80).eligible, isTrue);
      expect(evaluateCertificate(c, reg('a', <String, dynamic>{}), null).reason, 'not-checked-in');
    });
    test('özet: gönderilen, bekleyen, eski sürüm', () {
      final CertSummary s = summarizeCertificates(
        e,
        <EventRegistration>[
          reg('a', <String, dynamic>{'sessionsAttended': 5}),
          reg('b', <String, dynamic>{'sessionsAttended': 4}),
          reg('c', <String, dynamic>{'sessionsAttended': 2}),
        ],
        80,
        <String, Map<String, Object?>>{
          'a': <String, Object?>{'status': 'issued', 'configVersion': 1},
          'c': <String, Object?>{'status': 'issued', 'configVersion': 2},
        },
        configVersion: 2,
      );
      expect(s.eligible, 2);
      expect(s.sent, 2);
      expect(s.pending, 1);
      expect(s.belowThreshold, 1);
      expect(s.outdated, 1);
      expect(s.distribution, <String, int>{'5/5': 1, '4/5': 1, '2/5': 1});
      expect(resolveCertificateThreshold(null, ev(<String, dynamic>{'certificateThresholdPercent': 70})), 70);
      expect(resolveCertificateThreshold(0, ev(<String, dynamic>{})), isNull);
    });
  });

  test('LinkedIn bağlantısı: Regipass şirket sayfası', () {
    final Uri u = linkedInAddUri(code: 'RP-7K4M-Q9XD', issuedAtMs: DateTime(2026, 9, 24).millisecondsSinceEpoch, clubName: 'Ege Eczacılık Kulübü', eventTitle: 'Zirve');
    expect(u.host, 'www.linkedin.com');
    expect(u.queryParameters['name'], 'Ege Eczacılık Kulübü — Zirve Katılım Belgesi');
    expect(u.queryParameters['organizationId'], kLinkedInOrgId);
    expect(u.queryParameters['certUrl'], 'https://regipass.com/dogrula/RP-7K4M-Q9XD');
    expect(u.queryParameters['issueMonth'], '9');
  });

  Widget host(Widget child, List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: LanguageScope(
      language: 'tr',
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    ),
  );

  testWidgets('belge ayarlanmamış: yalnızca bilgi yazısı, web bağlantısı yok, Gönder kapalı', (WidgetTester tester) async {
    final AppEvent e = ev(<String, dynamic>{'checkinMode': 'attendance_only', 'sessionCount': 5, 'sessionsCompleted': true});
    await tester.pumpWidget(host(
      CertificatePanelCard(event: e, registrations: <EventRegistration>[reg('a', <String, dynamic>{'sessionsAttended': 5})]),
      <Override>[
        certificateConfigProvider('e1').overrideWith((Ref ref) => Stream<Map<String, Object?>?>.value(null)),
        certificateIssuesProvider('e1').overrideWith((Ref ref) => Stream<List<Map<String, Object?>>>.value(const <Map<String, Object?>>[])),
        clubEventCertificatesProvider('clubA|e1').overrideWith((Ref ref) => Stream<Map<String, Map<String, Object?>>>.value(const <String, Map<String, Object?>>{})),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('cert-web-only')), findsOneWidget);
    expect(find.textContaining('regipass.com web sitesini kullanın'), findsOneWidget);
    // Tıklanabilir bağlantı YOK (Apple): hiçbir InkWell / TextButton web'e gitmiyor.
    expect(find.byType(TextButton), findsNothing);
    final FilledButton send = tester.widget(find.byType(FilledButton));
    expect(send.onPressed, isNull);
  });

  testWidgets('kaydedilmiş belge: Gönder sunucuyu çağırır; eşik canlı sayı', (WidgetTester tester) async {
    final _FakeCerts fake = _FakeCerts();
    final AppEvent e = ev(<String, dynamic>{'checkinMode': 'attendance_only', 'sessionCount': 5, 'sessionsCompleted': true});
    await tester.pumpWidget(host(
      CertificatePanelCard(event: e, registrations: <EventRegistration>[
        reg('a', <String, dynamic>{'sessionsAttended': 5, 'studentFirstName': 'Ada'}),
        reg('b', <String, dynamic>{'sessionsAttended': 4}),
        reg('c', <String, dynamic>{'sessionsAttended': 2}),
      ]),
      <Override>[
        certificateServiceProvider.overrideWithValue(fake),
        certificateConfigProvider('e1').overrideWith((Ref ref) => Stream<Map<String, Object?>?>.value(<String, Object?>{'status': 'saved', 'version': 1, 'thresholdPercent': 80})),
        certificateIssuesProvider('e1').overrideWith((Ref ref) => Stream<List<Map<String, Object?>>>.value(const <Map<String, Object?>>[])),
        clubEventCertificatesProvider('clubA|e1').overrideWith((Ref ref) => Stream<Map<String, Map<String, Object?>>>.value(const <String, Map<String, Object?>>{})),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('%80 → 2 kişi alacak'), findsOneWidget);
    expect(find.text('2 kişiye gönder'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('cert-send')));
    await tester.pumpAndSettle();
    expect(fake.calls, <String>['send:e1:false']);
    expect(find.text('2 belge gönderildi.'), findsOneWidget);
  });
}
