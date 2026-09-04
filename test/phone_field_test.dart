import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/features/shared/phone_field.dart';
import 'package:regipass/l10n/app_strings.dart';

/// Telefon alanının uyarı zamanlaması.
///
/// Uyarı yazarken değil, alandan çıkıldıktan sonra çıkmalı: aksi hâlde
/// kullanıcı ilk haneyi yazdığı anda "10 haneli olmalı" görüyordu.
void main() {
  Future<PhoneFieldController> pumpField(
    WidgetTester tester, {
    String? errorText,
    FocusNode? focusNode,
  }) async {
    final PhoneFieldController controller = PhoneFieldController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      LanguageScope(
        language: 'tr',
        child: MaterialApp(
          theme: buildRegipassTheme(),
          home: Scaffold(
            body: Column(
              children: <Widget>[
                PhoneField(
                  controller: controller,
                  errorText: errorText,
                  focusNode: focusNode,
                ),
                // Odağı almak için alan dışında bir hedef.
                const TextField(key: Key('other')),
              ],
            ),
          ),
        ),
      ),
    );

    return controller;
  }

  testWidgets('eksik numara yazılırken uyarı göstermez', (
    WidgetTester tester,
  ) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField).first, '555');
    await tester.pump();

    expect(find.text('10 haneli olmalı'), findsNothing);
  });

  testWidgets('eksik numarada alandan çıkınca uyarır', (
    WidgetTester tester,
  ) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField).first, '555');
    await tester.pump();
    // Başka alana geç: doğrulama şimdi gösterilmeli.
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();

    expect(find.text('10 haneli olmalı'), findsOneWidget);
  });

  testWidgets('hatalı operatör ön eki anında uyarır', (
    WidgetTester tester,
  ) async {
    await pumpField(tester);

    // "212" Türkiye'de sabit hattır; cep ön eklerinin hiçbiriyle bağdaşmaz.
    await tester.enterText(find.byType(TextField).first, '212');
    await tester.pump();

    expect(
      find.text('Türkiye cep numaraları 50, 53, 54, 55, 56 ile başlamalı.'),
      findsOneWidget,
    );
  });

  testWidgets('eksik ön ekte (yalnız "5") uyarı yok', (
    WidgetTester tester,
  ) async {
    await pumpField(tester);

    // "5" henüz 50/53/54/55/56 ön eklerinin hepsiyle bağdaşıyor: kullanıcı
    // ikinci haneyi yazmadan operatör uyarısı çıkmamalı.
    await tester.enterText(find.byType(TextField).first, '5');
    await tester.pump();

    expect(
      find.textContaining('cep numaraları'),
      findsNothing,
    );
  });

  testWidgets('tahsis edilmemiş ön ek geçersiz sayılır', (
    WidgetTester tester,
  ) async {
    final PhoneFieldController controller = await pumpField(tester);

    // 51x Türkiye'de cebe tahsis edilmiş değil: hane sayısı doğru olsa da
    // numara geçerli sayılmaz, SMS gönderilmez.
    await tester.enterText(find.byType(TextField).first, '5121234567');
    await tester.pump();

    expect(controller.isValid, isFalse);
    expect(
      find.text('Türkiye cep numaraları 50, 53, 54, 55, 56 ile başlamalı.'),
      findsOneWidget,
    );
  });

  testWidgets('tam numarada uyarı yok', (WidgetTester tester) async {
    final PhoneFieldController controller = await pumpField(tester);

    await tester.enterText(find.byType(TextField).first, '5551234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();

    expect(controller.isValid, isTrue);
    expect(controller.e164, '+905551234567');
    expect(find.text('10 haneli olmalı'), findsNothing);
  });

  testWidgets('dışarıdan gelen hata alanın altında görünür', (
    WidgetTester tester,
  ) async {
    await pumpField(tester, errorText: 'Bu numara başka bir hesaba ait.');

    expect(find.text('Bu numara başka bir hesaba ait.'), findsOneWidget);
  });

  testWidgets('dışarıdan verilen odak düğümü kullanılır', (
    WidgetTester tester,
  ) async {
    final FocusNode phoneFocus = FocusNode();
    addTearDown(phoneFocus.dispose);

    await pumpField(tester, focusNode: phoneFocus);

    // Soyad alanının "ileri" tuşunun yaptığı şey: odağı telefona taşımak.
    phoneFocus.requestFocus();
    await tester.pump();

    expect(phoneFocus.hasFocus, isTrue);
  });

  testWidgets('numara klavyesinin "bitti" tuşu klavyeyi kapatır', (
    WidgetTester tester,
  ) async {
    final FocusNode phoneFocus = FocusNode();
    addTearDown(phoneFocus.dispose);

    await pumpField(tester, focusNode: phoneFocus);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(phoneFocus.hasFocus, isTrue);

    // Alan `TextInputAction.done` bildirir; eylem tetiklendiğinde odak
    // başka alana geçmez, tamamen bırakılır (klavye kapanır).
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(phoneFocus.hasFocus, isFalse);
  });
}
