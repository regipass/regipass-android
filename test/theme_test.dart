import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/features/student/student_shell.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/state/theme_mode.dart';

/// Koyu mod testleri.
///
/// `flutter analyze` bir yüzeyin koyu modda hâlâ beyaz kaldığını göremez;
/// bu testler hem tema token'larını hem de gerçek çizimi doğrular.
void main() {
  group('tema', () {
    test('açık tema açık yüzeyler üretir', () {
      final ThemeData theme = buildRegipassTheme();

      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, BrandColors.grayLighter);
      expect(theme.appBarTheme.backgroundColor, BrandColors.white);
      expect(theme.cardTheme.color, BrandColors.white);
    });

    test('koyu tema koyu yüzeyler üretir', () {
      final ThemeData theme = buildRegipassTheme(brightness: Brightness.dark);

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, BrandColors.darkBase);
      expect(theme.appBarTheme.backgroundColor, BrandColors.darkSurface);
      expect(theme.cardTheme.color, BrandColors.darkSurface);
      // Alt çubuk ve giriş alanları da koyu yüzeye oturmalı.
      expect(theme.navigationBarTheme.backgroundColor, BrandColors.darkSurface);
      expect(theme.inputDecorationTheme.fillColor, BrandColors.darkSurface);
    });

    test('tercih yokken cihaz görünümü uygulanır', () {
      expect(
        resolveThemeMode(
          storedMode: null,
          seenDeviceBrightness: null,
          deviceBrightness: Brightness.dark,
        ),
        ThemeMode.dark,
      );
    });

    test('cihaz teması değiştiyse elle seçimi ezer', () {
      // Kullanıcı açık modu seçmişti, sonra telefon koyu moda alındı:
      // uygulama elle bir şey yapılmadan koyu moda geçmeli.
      expect(
        resolveThemeMode(
          storedMode: ThemeMode.light,
          seenDeviceBrightness: Brightness.light,
          deviceBrightness: Brightness.dark,
        ),
        ThemeMode.dark,
      );
    });

    test('cihaz teması aynıysa elle seçim korunur', () {
      // Telefon koyu, kullanıcı uygulamayı bilerek açık moda almış: cihaz bir
      // daha değişene kadar bu seçim geçerli kalır.
      expect(
        resolveThemeMode(
          storedMode: ThemeMode.light,
          seenDeviceBrightness: Brightness.dark,
          deviceBrightness: Brightness.dark,
        ),
        ThemeMode.light,
      );
    });

    test('görünüm tercihi kodlanıp geri çözülür', () {
      for (final ThemeMode mode in ThemeMode.values) {
        expect(decodeThemeMode(encodeThemeMode(mode)), mode);
      }
      // Bilinmeyen/eksik değer varsayılana düşer.
      expect(decodeThemeMode(null), kDefaultThemeMode);
      expect(decodeThemeMode('mavi'), kDefaultThemeMode);
    });
  });

  group('BrandSurfaces', () {
    Future<void> pumpProbe(WidgetTester tester, Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRegipassTheme(brightness: brightness),
          home: Builder(
            builder: (BuildContext context) => ColoredBox(
              key: const Key('probe'),
              color: context.surface,
              child: Text(
                'x',
                style: TextStyle(color: context.ink),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('açık modda beyaz yüzey verir', (WidgetTester tester) async {
      await pumpProbe(tester, Brightness.light);

      final ColoredBox box =
          tester.widget<ColoredBox>(find.byKey(const Key('probe')));
      expect(box.color, BrandColors.white);
    });

    testWidgets('koyu modda koyu yüzey verir', (WidgetTester tester) async {
      await pumpProbe(tester, Brightness.dark);

      final ColoredBox box =
          tester.widget<ColoredBox>(find.byKey(const Key('probe')));
      expect(box.color, BrandColors.darkSurface);
    });
  });

  testWidgets('alt çubuk koyu modda da hatasız çizilir',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            theme: buildRegipassTheme(brightness: Brightness.dark),
            home: const StudentShell(
              location: Routes.studentHome,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(qrToggleKey), findsOneWidget);
    expect(find.text('Hesabım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
