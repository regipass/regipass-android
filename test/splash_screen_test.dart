import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/features/landing/splash_screen.dart';
import 'package:regipass/features/shared/common_widgets.dart';

Future<void> _pumpSplash(WidgetTester tester, Brightness brightness) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRegipassTheme(brightness: brightness),
      home: const SplashScreen(),
    ),
  );
  await tester.pump();
}

Color? _splashBackground(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;

void main() {
  testWidgets('açılış ekranı açık temada beyaz zemine çizilir', (
    WidgetTester tester,
  ) async {
    await _pumpSplash(tester, Brightness.light);

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(_splashBackground(tester), BrandColors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('açılış ekranı koyu temada koyu zemine çizilir', (
    WidgetTester tester,
  ) async {
    await _pumpSplash(tester, Brightness.dark);

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(_splashBackground(tester), BrandColors.darkBase);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yükleme çubuğu kare atlamadan akmayı sürdürür', (
    WidgetTester tester,
  ) async {
    await _pumpSplash(tester, Brightness.light);

    // Akan parça `Transform` ile ötelenir; birkaç kare sonra konumu değişmiş
    // olmalı (animasyon donmuş olsaydı aynı kalırdı).
    Matrix4 runnerTransform() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(Transform),
          ),
        )
        .transform;

    final Matrix4 first = runnerTransform().clone();
    await tester.pump(const Duration(milliseconds: 200));

    expect(runnerTransform(), isNot(first));
    expect(tester.takeException(), isNull);
  });
}
