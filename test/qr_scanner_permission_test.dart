// App Store 2.1(a): QR ekranında kamera izni akışı.
// İzin kapalıyken ekran kilitlenmemeli; "İzin ver" ya da "Ayarları Aç"
// düğmesi görünmeli, izin açılınca kamera gelmeli.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:regipass/features/shared/qr_scanner_view.dart';
import 'package:regipass/features/shared/share_origin.dart';
import 'package:regipass/l10n/app_strings.dart';

const MethodChannel _perm = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

// permission_handler durum kodları.
const int _denied = 0;
const int _granted = 1;
const int _permanentlyDenied = 4;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int status;
  late int requestResult;
  int requests = 0;
  int settingsOpened = 0;

  setUp(() {
    requests = 0;
    settingsOpened = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_perm, (MethodCall call) async {
          switch (call.method) {
            case 'checkPermissionStatus':
              return status;
            case 'requestPermissions':
              requests++;
              status = requestResult;
              return <int, int>{1: requestResult}; // 1 = camera
            case 'openAppSettings':
              settingsOpened++;
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_perm, null);
  });

  Future<MobileScannerController> pump(WidgetTester tester) async {
    final MobileScannerController controller = MobileScannerController(
      autoStart: false,
    );
    await tester.pumpWidget(
      LanguageScope(
        language: 'tr',
        child: MaterialApp(
          home: Scaffold(
            body: QrScannerView(
              controller: controller,
              onDetect: (_) {},
              overlay: const SizedBox(key: Key('frame')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return controller;
  }

  testWidgets('izin verilmişse kamera açılır, sistem penceresi açılmaz', (
    WidgetTester tester,
  ) async {
    status = _granted;
    requestResult = _granted;
    await pump(tester);
    expect(find.byType(MobileScanner), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('ilk açılışta izin ekranda sorulur; verilince kamera gelir', (
    WidgetTester tester,
  ) async {
    status = _denied; // iOS: henüz sorulmadı
    requestResult = _granted;
    await pump(tester);
    expect(requests, 1);
    expect(find.byType(MobileScanner), findsOneWidget);
  });

  testWidgets('kalıcı retten sonra "Ayarları Aç" görünür ve çalışır; '
      'Ayarlar\'dan izinle dönünce kamera açılır', (WidgetTester tester) async {
    status = _denied;
    requestResult = _permanentlyDenied; // iOS: "İzin Verme"
    await pump(tester);
    expect(find.byKey(const Key('qrScanner.settings')), findsOneWidget);
    expect(find.text('Ayarları Aç'), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.byKey(const Key('frame')), findsNothing);

    await tester.tap(find.text('Ayarları Aç'));
    await tester.pump();
    expect(settingsOpened, 1);

    // Kullanıcı Ayarlar'da izni açıp geri döner.
    status = _granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byType(MobileScanner), findsOneWidget);
  });

  testWidgets('Android ilk ret: "Kameraya izin ver" yeniden sorar', (
    WidgetTester tester,
  ) async {
    status = _denied;
    requestResult = _denied;
    await pump(tester);
    expect(find.byKey(const Key('qrScanner.permission')), findsOneWidget);

    requestResult = _granted;
    await tester.tap(find.text('Kameraya izin ver'));
    await tester.pump();
    await tester.pump();
    expect(requests, 2);
    expect(find.byType(MobileScanner), findsOneWidget);
  });

  testWidgets('izin penceresi kapanırken gelen "resumed" sonucu ezmez', (
    WidgetTester tester,
  ) async {
    status = _denied;
    final Completer<void> dialog = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_perm, (MethodCall call) async {
          switch (call.method) {
            case 'checkPermissionStatus':
              return status;
            case 'requestPermissions':
              await dialog.future; // sistem penceresi açık
              status = _granted;
              return <int, int>{1: _granted};
          }
          return null;
        });
    final MobileScannerController controller = MobileScannerController(
      autoStart: false,
    );
    await tester.pumpWidget(
      LanguageScope(
        language: 'tr',
        child: MaterialApp(
          home: Scaffold(
            body: QrScannerView(controller: controller, onDetect: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    // Pencere açıkken uygulama inactive → resumed olur (iOS davranışı).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    dialog.complete(); // kullanıcı "İzin Ver" dedi
    await tester.pump();
    await tester.pump();
    expect(find.byType(MobileScanner), findsOneWidget);
    expect(find.byKey(const Key('qrScanner.permission')), findsNothing);
  });

  test('iPad paylaşım kaynağı her zaman ekran içinde ve boş değil', () {
    final Rect a = safeShareOrigin(null);
    expect(a.isEmpty, isFalse);
    final Rect b = safeShareOrigin(Rect.zero);
    expect(b.isEmpty, isFalse);
    final Rect c = safeShareOrigin(const Rect.fromLTWH(-50, -50, 100, 100));
    expect(c.left, greaterThanOrEqualTo(0));
    expect(c.top, greaterThanOrEqualTo(0));
    expect(c.isEmpty, isFalse);
  });
}
