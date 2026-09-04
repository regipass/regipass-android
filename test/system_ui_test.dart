import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/system_ui.dart';
import 'package:regipass/app/theme.dart';

/// Sistem çubuğu kuralları.
///
/// Karar (buzlu cam ne zaman devreye girer), stil (platforma hangi renkler
/// bildirilir) ve uygulama (gerçek platform kanalına ne gönderilir) ayrı ayrı
/// doğrulanır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buzlu cam kararı', () {
    test('oturum açıkken ve yükleme bittiğinde çizilir', () {
      expect(shouldFrostSystemBars(isSignedIn: true, isLoading: false), isTrue);
    });

    test('giriş yapılmadıysa çubuklar sade kalır', () {
      expect(
        shouldFrostSystemBars(isSignedIn: false, isLoading: false),
        isFalse,
      );
    });

    test('açılış perdesi sürerken karar verilmez', () {
      // Perde kapanır kapanmaz efektin belirmesi açılışta renk sıçraması
      // yaratırdı; oturum çözülene kadar sade hâl korunur.
      expect(shouldFrostSystemBars(isSignedIn: true, isLoading: true), isFalse);
    });
  });

  group('katman listesi', () {
    test('her iki çubuk da her koşulda açık', () {
      expect(
        visibleSystemOverlays,
        containsAll(<SystemUiOverlay>[
          SystemUiOverlay.top,
          SystemUiOverlay.bottom,
        ]),
      );
    });
  });

  group('çubuk stili', () {
    test('durum çubuğu her zaman saydam, simgeler temanın tersi', () {
      final SystemUiOverlayStyle light = systemBarsStyle(
        brightness: Brightness.light,
      );
      final SystemUiOverlayStyle dark = systemBarsStyle(
        brightness: Brightness.dark,
      );

      expect(light.statusBarColor, Colors.transparent);
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(dark.statusBarColor, Colors.transparent);
      expect(dark.statusBarIconBrightness, Brightness.light);
    });

    test('AppBar da aynı stili taşır', () {
      // Flutter her karede AppBar'ın AnnotatedRegion'ına bakıp çubuk stilini
      // kendisi bildiriyor; AppBar kendi varsayılanını taşısaydı uygulamanın
      // bildirdiği saydamlık eziliyor ve alt çubuk siyah kalıyordu.
      for (final Brightness brightness in Brightness.values) {
        expect(
          buildRegipassTheme(
            brightness: brightness,
          ).appBarTheme.systemOverlayStyle,
          systemBarsStyle(brightness: brightness),
        );
      }
    });

    test('gezinme çubuğu her iki görünümde de saydam', () {
      // Çubuğun rengini altındaki tema zemini veriyor; sistemin kendi
      // dolgusu araya girerse saydamlığın üstüne gri bir bant çizerdi.
      for (final Brightness brightness in Brightness.values) {
        final SystemUiOverlayStyle style = systemBarsStyle(
          brightness: brightness,
        );

        expect(style.systemNavigationBarColor, Colors.transparent);
        expect(style.systemNavigationBarDividerColor, Colors.transparent);
        expect(style.systemNavigationBarContrastEnforced, isFalse);
      }
    });
  });

  group('platforma gönderilen çağrı', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('çubuklar görünür kalır, içerik altlarına uzatılır', () async {
      await applyVisibleSystemBars();

      final MethodCall mode = calls.singleWhere(
        (MethodCall c) => c.method == 'SystemChrome.setEnabledSystemUIMode',
      );
      expect(mode.arguments, 'SystemUiMode.edgeToEdge');
    });
  });

  group('buzlu cam katmanı', () {
    /// Şeritlerin gerçekten güvenli alan yüksekliğinde çizildiğini doğrular.
    Future<void> pump(
      WidgetTester tester, {
      required bool enabled,
      EdgeInsets padding = const EdgeInsets.only(top: 40, bottom: 24),
    }) => tester.pumpWidget(
      MaterialApp(
        // MediaQuery MaterialApp'in İÇİNDE: dışında kalırsa MaterialApp
        // kendi MediaQuery'sini pencereden türetip padding'i eziyor.
        home: MediaQuery(
          data: MediaQueryData(padding: padding),
          child: SystemBarsFrost(
            enabled: enabled,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    testWidgets('kapalıyken hiçbir katman eklenmez', (
      WidgetTester tester,
    ) async {
      await pump(tester, enabled: false);

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('açıkken üst ve alt şerit çizilir', (
      WidgetTester tester,
    ) async {
      await pump(tester, enabled: true);

      expect(find.byType(BackdropFilter), findsNWidgets(2));
    });

    testWidgets('klavye açıkken alt şerit çizilmez', (
      WidgetTester tester,
    ) async {
      // Klavye açılınca alt güvenli alan sıfırlanır; şerit çizilmeye devam
      // etseydi klavyenin üstünde asılı bir bant kalırdı.
      await pump(
        tester,
        enabled: true,
        padding: const EdgeInsets.only(top: 40),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('alt gezinme çubuğunun kendiliğinden gizlenmesi', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    /// Çubukların gizlenmesi Android'e özgü; her test platformu sabitler.
    final TargetPlatformVariant android = TargetPlatformVariant.only(
      TargetPlatform.android,
    );

    /// Yalnızca alt çubuğu gizleyen çağrılar.
    Iterable<MethodCall> hideCalls() => calls.where(
      (MethodCall c) => c.method == 'SystemChrome.setEnabledSystemUIOverlays',
    );

    /// Çubukları geri getiren (edge-to-edge) çağrılar.
    Iterable<MethodCall> showCalls() => calls.where(
      (MethodCall c) =>
          c.method == 'SystemChrome.setEnabledSystemUIMode' &&
          c.arguments == 'SystemUiMode.edgeToEdge',
    );

    /// Test yüzeyi; şerit [kNavigationBarTouchStrip] kadar, yani en alttaki
    /// 12 piksel.
    const Size testSurface = Size(800, 600);
    const Offset onNavigationBar = Offset(400, 590);

    Future<void> pump(
      WidgetTester tester, {
      EdgeInsets viewInsets = EdgeInsets.zero,
    }) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // Ölçü şart: dokunma şeridi ekranın altından hesaplanıyor.
          data: MediaQueryData(size: testSurface, viewInsets: viewInsets),
          child: const AutoHideNavigationBar(child: SizedBox.expand()),
        ),
      ),
    );

    /// Bekleyen sayaç kalmasın diye ağaç sökülür.
    Future<void> unmount(WidgetTester tester) =>
        tester.pumpWidget(const SizedBox.shrink());

    testWidgets(
      'çubuğa üç saniye dokunulmazsa yalnızca alt çubuk gizlenir',
      (WidgetTester tester) async {
        await pump(tester);
        expect(hideCalls(), isEmpty);

        await tester.pump(kNavigationBarIdleDelay);

        // Durum çubuğu listede kalır: gizlenen yalnızca alttaki çubuktur.
        expect(hideCalls().single.arguments, <String>['SystemUiOverlay.top']);

        await unmount(tester);
      },
      variant: android,
    );

    testWidgets('çubuğa dokunulunca geri gelir ve sayaç yeniden başlar', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await tester.pump(kNavigationBarIdleDelay);
      calls.clear();

      await tester.tapAt(onNavigationBar);
      expect(showCalls(), isNotEmpty);

      // Sayaç sıfırdan işler: dokunuştan üç saniye sonra yeniden gizlenir.
      calls.clear();
      await tester.pump(kNavigationBarIdleDelay);
      expect(hideCalls(), hasLength(1));

      await unmount(tester);
    }, variant: android);

    testWidgets('çubuk dışına dokunmak onu geri getirmez', (
      WidgetTester tester,
    ) async {
      // İstenen kural bu: uygulamayı kullanmak çubuğu geri çağırmamalı.
      await pump(tester);
      await tester.pump(kNavigationBarIdleDelay);
      calls.clear();

      await tester.tapAt(const Offset(400, 300));

      expect(showCalls(), isEmpty);
      // Sistem gizli çubuğu kendiliğinden geri göstermiş olabilir; karar
      // aynı dokunuşta yeniden bildirilir.
      expect(hideCalls(), hasLength(1));

      await unmount(tester);
    }, variant: android);

    testWidgets('çubuk dışına dokunmak gizlenmeyi de ertelemez', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      // Sayaç dolmadan hemen önce ekranın ortasına dokunmak süreyi uzatmaz.
      await tester.pump(kNavigationBarIdleDelay - const Duration(seconds: 1));
      await tester.tapAt(const Offset(400, 300));
      expect(hideCalls(), isEmpty);

      await tester.pump(const Duration(seconds: 1));
      expect(hideCalls(), hasLength(1));

      await unmount(tester);
    }, variant: android);

    testWidgets('klavye açıkken gizlenmez', (WidgetTester tester) async {
      // Yazarken çubuğun kalkması yerleşimi sıçratır, klavyenin üstündeki
      // "Bitti" çubuğuyla da çakışırdı.
      await pump(tester, viewInsets: const EdgeInsets.only(bottom: 320));

      await tester.pump(kNavigationBarIdleDelay);

      expect(hideCalls(), isEmpty);

      await unmount(tester);
    }, variant: android);

    testWidgets(
      'Android dışında hiçbir şey yapmaz',
      (WidgetTester tester) async {
        await pump(tester);
        await tester.pump(kNavigationBarIdleDelay);

        expect(hideCalls(), isEmpty);

        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });
}
