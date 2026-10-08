// İP-O: kapı ekranı — kamera kapanmadan arka arkaya okutma, kart ve sayaç.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:regipass/domain/checkin_qr.dart';
import 'package:regipass/domain/door_gate.dart';
import 'package:regipass/features/club/club_providers.dart';
import 'package:regipass/features/club/club_qr_checkin_screen.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/services/door_gate.dart';
import 'package:regipass/state/connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _ticket(String s, [String? code]) =>
    createCheckinQrToken(<String, dynamic>{
      'v': 1,
      'type': 'event-checkin',
      'registrationId': 'e1_$s',
      'eventId': 'e1',
      'studentId': s,
      'c': code ?? 'CODE_$s',
    });

void main() {
  testWidgets('kamera açık kalır; her okutmada kart yenilenir, sayaç artar', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DateTime now = DateTime.now();
    DateTime clock = now;
    final Map<String, Map<String, dynamic>> regs =
        <String, Map<String, dynamic>>{
          for (final String s in <String>['s1', 's2', 's3'])
            'e1_$s': <String, dynamic>{
              'eventId': 'e1',
              'studentId': s,
              'studentName': 'Öğrenci $s',
              'studentDepartment': 'Eczacılık',
              'ticketCode': 'CODE_$s',
            },
        };
    final List<String> writes = <String>[];
    final DoorGate gate = DoorGate(
      clubId: 'clubA',
      prefs: prefs,
      isOnline: () => true,
      now: () => clock,
      backend: GateBackend(
        fetchEvent: (String id) async =>
            GateEvent.fromMap(id, <String, dynamic>{
              'title': 'Bahar Şenliği',
              'clubId': 'clubA',
              'checkinMode': 'checkin_only',
              'eventDateAtMs': now.millisecondsSinceEpoch,
            }),
        fetchRegistrations: (String id) async => <GateRegistration>[
          for (final MapEntry<String, Map<String, dynamic>> e in regs.entries)
            GateRegistration.fromMap(e.key, e.value),
        ],
        fetchRegistration: (String id) async =>
            GateRegistration.fromMap(id, regs[id]!),
        writeCheckIn: (String id, int ms) async {
          writes.add(id);
          if (id == 'e1_s3') {
            throw FirebaseException(plugin: 'x', code: 'unavailable');
          }
        },
      ),
    );

    // Kamera izni verilmiş (QrScannerView izin akışı).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (MethodCall call) async =>
              call.method == 'checkPermissionStatus' ? 1 : null,
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          doorGateProvider.overrideWith((Ref ref) async => gate),
          onlineProvider.overrideWithValue(true),
        ],
        child: const LanguageScope(
          language: 'tr',
          child: MaterialApp(home: ClubQrCheckinScreen(eventId: 'e1')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final MobileScanner scanner = tester.widget(find.byType(MobileScanner));
    Future<void> scan(String raw) async {
      scanner.onDetect!(
        BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: raw)]),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Bahar Şenliği'), findsWidgets);

    await scan(_ticket('s1'));
    expect(find.textContaining('GİRİŞ TAMAM'), findsOneWidget);
    expect(find.text('Öğrenci s1'), findsOneWidget);
    expect(find.text('✓ 1 giriş'), findsOneWidget);

    // Kart kapanmadan sıradaki öğrenci: kamera ekranı yerinde.
    await scan(_ticket('s2'));
    expect(find.text('Öğrenci s2'), findsOneWidget);
    expect(find.text('✓ 2 giriş'), findsOneWidget);
    expect(find.byType(MobileScanner), findsOneWidget);

    await scan(_ticket('s1', 'SAHTE'));
    // Aynı bilet 10 sn içinde: sessizce yok sayılır, kart değişmez.
    expect(find.text('Öğrenci s2'), findsOneWidget);

    await scan('https://example.com');
    expect(find.textContaining('REGIPASS BİLETİ DEĞİL'), findsWidgets);

    // 4 sn sonra kart şeride küçülür.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Katılımcıdan Regipass biletini'), findsNothing);

    // Sabitle: kart yeni okutmalarla değişmez.
    await scan(_ticket('s3'));
    await tester.tap(find.textContaining('Sabitle'));
    await tester.pump();
    expect(find.text('Kaldır'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    clock = clock.add(const Duration(seconds: 11));
    await scan(_ticket('s1'));
    expect(find.textContaining('ZATEN GİRDİ'), findsOneWidget);
    expect(find.text('Öğrenci s3'), findsWidgets);

    // Son okutulanlar
    await tester.tap(find.text('✓ 3 giriş'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Son okutulanlar'), findsOneWidget);
    expect(writes, containsAll(<String>['e1_s1', 'e1_s2']));

    await tester.pumpWidget(const SizedBox());
    await gate.dispose();
  });
}
