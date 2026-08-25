import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/routing.dart';
import 'package:regipass/features/student/student_shell.dart';
import 'package:regipass/l10n/app_strings.dart';

/// Alt çubuk testleri.
///
/// `flutter analyze` yerleşim hatalarını (taşma, sıfır boyut, Path.combine'ın
/// çalışmaması) göremez — oyuklu çubuk elle çizilen bir yüzey olduğu için bu
/// testler onu gerçekten çizip hata çıkmadığını doğrular.
Widget _wrap(Widget child) => ProviderScope(
  child: LanguageScope(
    language: 'tr',
    child: MaterialApp(home: child),
  ),
);

Future<void> _setPhone(WidgetTester tester, Size logical) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logical;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('alt çubuk dört sekme ve ortadaki QR düğmesini çizer', (
    WidgetTester tester,
  ) async {
    await _setPhone(tester, const Size(360, 780));

    await tester.pumpWidget(
      _wrap(
        const StudentShell(
          location: Routes.studentHome,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keşfet'), findsOneWidget);
    expect(find.text('Etkinliklerim'), findsOneWidget);
    expect(find.text('Belgelerim'), findsOneWidget);
    expect(find.text('Hesabım'), findsOneWidget);

    // Oyuğun içindeki düğme.
    expect(find.byKey(qrToggleKey), findsOneWidget);
    expect(tester.getSize(find.byKey(qrToggleKey)), const Size(66, 66));

    // Taşma/boyama hatası olsaydı burada birikirdi.
    expect(tester.takeException(), isNull);
  });

  testWidgets('dar ekranda da sekme etiketleri taşmaz', (
    WidgetTester tester,
  ) async {
    await _setPhone(tester, const Size(320, 640));

    await tester.pumpWidget(
      _wrap(
        const StudentShell(
          location: Routes.studentAccount,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('QR düğmesi iki eylemi açıp kapatır', (
    WidgetTester tester,
  ) async {
    await _setPhone(tester, const Size(360, 780));

    await tester.pumpWidget(
      _wrap(
        const StudentShell(
          location: Routes.studentHome,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Eylemler her zaman ağaçta durur (giriş/çıkış animasyonu için); açık
    // olup olmadıklarını üzerlerindeki IgnorePointer söyler.
    bool actionsHitTestable() =>
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.byKey(qrScanActionKey),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring ==
        false;

    expect(actionsHitTestable(), isFalse);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.tap(find.byKey(qrToggleKey));
    await tester.pumpAndSettle();

    // Açıkken orta düğme kapatma simgesine döner ve iki eylem tıklanabilir.
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(actionsHitTestable(), isTrue);
    expect(find.byKey(qrGenerateActionKey), findsOneWidget);
    expect(find.text('QR Okut'), findsOneWidget);
    expect(find.text('QR Oluştur'), findsOneWidget);

    // QR eylemleri açıldığında beyaz bir plaka/çubuk oluşmaz.
    final Material actionSurface = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(qrScanActionKey),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(actionSurface.color, Colors.transparent);
    expect(actionSurface.elevation, 0);

    await tester.tap(find.byKey(qrToggleKey));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
    expect(actionsHitTestable(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('üst çubuk marka işareti + bildirim düğmesi taşır', (
    WidgetTester tester,
  ) async {
    await _setPhone(tester, const Size(360, 780));

    await tester.pumpWidget(
      _wrap(
        const Scaffold(
          appBar: StudentAppBar(title: 'Başlık', subtitle: 'Alt başlık'),
          body: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başlık'), findsOneWidget);
    expect(find.text('Alt başlık'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('üst çubuk verilen eylemleri bildirim yerine gösterir', (
    WidgetTester tester,
  ) async {
    await _setPhone(tester, const Size(360, 780));

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          appBar: StudentAppBar(
            title: 'Hesabım',
            actions: <Widget>[
              IconButton(onPressed: () {}, icon: const Icon(Icons.logout)),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
