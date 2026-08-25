import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/system_ui.dart';

/// Sistem çubuğu kuralları.
///
/// Karar (ne zaman gizlenir) ve uygulama (platforma ne gönderilir) ayrı ayrı
/// doğrulanır; ikincisi için gerçek platform kanalı dinlenir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('gezinme çubuğu kararı', () {
    test('oturum açıkken ve yükleme bittiğinde gizlenir', () {
      expect(
        shouldHideSystemNavigationBar(isSignedIn: true, isLoading: false),
        isTrue,
      );
    });

    test('giriş yapılmadıysa görünür kalır', () {
      expect(
        shouldHideSystemNavigationBar(isSignedIn: false, isLoading: false),
        isTrue,
      );
    });

    test('açılış perdesi sürerken karar verilmez, çubuk görünür kalır', () {
      // Oturum çözülmeden gizlemek, hemen ardından geri getirmek anlamına
      // gelir; bu da açılışta göze çarpan bir titreme yaratırdı.
      expect(
        shouldHideSystemNavigationBar(isSignedIn: true, isLoading: true),
        isTrue,
      );
    });
  });

  group('katman listesi', () {
    test('gizliyken yalnızca durum çubuğu kalır', () {
      final List<SystemUiOverlay> overlays = systemOverlaysFor(
        hideNavigationBar: true,
      );

      expect(overlays, isEmpty);
      expect(overlays.contains(SystemUiOverlay.bottom), isFalse);
    });

    test('görünürken her iki çubuk da açık', () {
      expect(
        systemOverlaysFor(hideNavigationBar: false),
        containsAll(<SystemUiOverlay>[
          SystemUiOverlay.top,
          SystemUiOverlay.bottom,
        ]),
      );
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

    // `SystemUiMode.manual` platforma yalnızca katman listesini gönderir
    // (framework `setEnabledSystemUIMode` çağrısını bu modda kullanmaz).
    test('gizleme isteği yalnızca üst katmanı bildirir', () async {
      await applySystemNavigationBarVisibility(hideNavigationBar: true);

      final MethodCall overlays = calls.singleWhere(
        (MethodCall c) => c.method == 'SystemChrome.setEnabledSystemUIMode',
      );
      expect(overlays.arguments, 'SystemUiMode.immersiveSticky');
    });

    test('gösterme isteği alt katmanı da bildirir', () async {
      await applySystemNavigationBarVisibility(hideNavigationBar: false);

      final MethodCall overlays = calls.singleWhere(
        (MethodCall c) => c.method == 'SystemChrome.setEnabledSystemUIMode',
      );
      expect(overlays.arguments, 'SystemUiMode.edgeToEdge');
    });

    test('geri yükleme, son ayarı yeniden uygular', () async {
      await restoreSystemNavigationBarVisibility();

      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIMode');
      expect(calls.single.arguments, 'SystemUiMode.immersiveSticky');
    });
  });
}
