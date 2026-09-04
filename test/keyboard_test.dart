import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/app/theme.dart';
import 'package:regipass/core/keyboard.dart';
import 'package:regipass/l10n/app_strings.dart';

/// Klavyeden çıkış yolları (bkz. lib/core/keyboard.dart).
///
/// Üçü de kullanıcının pencereyi kapatmadan yazdığını düzeltebilmesi için var:
/// boşluğa dokunma, listeyi sürükleme ve çok satırlı alanlarda "Bitti" çubuğu.
void main() {
  Widget wrap(Widget child) => LanguageScope(
    language: 'tr',
    child: MaterialApp(
      theme: buildRegipassTheme(),
      scrollBehavior: const RegipassScrollBehavior(),
      home: child,
    ),
  );

  group('boşluğa dokunma', () {
    testWidgets('klavyeyi kapatır', (WidgetTester tester) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        wrap(
          DismissKeyboardOnTap(
            child: Scaffold(
              body: Column(
                children: <Widget>[TextField(focusNode: focus)],
              ),
            ),
          ),
        ),
      );

      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      // Alanın çok altında, hiçbir widget'ın ilgilenmediği bir nokta.
      await tester.tapAt(const Offset(20, 500));
      await tester.pump();

      expect(focus.hasFocus, isFalse);
    });

    testWidgets('düğmeye dokunmayı yutmaz', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        wrap(
          DismissKeyboardOnTap(
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => pressed = true,
                  child: const Text('Kaydet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Kaydet'));
      await tester.pump();

      expect(pressed, isTrue);
    });
  });

  group('listeyi sürükleme', () {
    testWidgets('kaydırma başlayınca klavye kapanır', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: ListView(
              children: <Widget>[
                TextField(focusNode: focus),
                for (int i = 0; i < 40; i++) const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );

      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pump();

      expect(focus.hasFocus, isFalse);
    });

    testWidgets('davranış uygulama genelinde onDrag', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const Scaffold(body: SizedBox())));

      final BuildContext context = tester.element(find.byType(Scaffold));

      expect(
        ScrollConfiguration.of(context).getKeyboardDismissBehavior(context),
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });
  });

  group('"Bitti" çubuğu', () {
    /// Klavye açıkken oluşan alt boşluğu taklit eder: çubuk klavyenin üstüne
    /// oturduğu için bu değer olmadan hiç çizilmez.
    Widget withKeyboard(Widget field) => wrap(
      Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
          child: KeyboardDoneBar(child: Scaffold(body: field)),
        ),
      ),
    );

    testWidgets('çok satırlı alanda görünür', (WidgetTester tester) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        withKeyboard(TextField(focusNode: focus, maxLines: 4)),
      );

      expect(find.text('Bitti'), findsNothing);

      focus.requestFocus();
      await tester.pump();

      expect(find.text('Bitti'), findsOneWidget);

      await tester.tap(find.text('Bitti'));
      await tester.pump();

      expect(focus.hasFocus, isFalse);
      expect(find.text('Bitti'), findsNothing);
    });

    testWidgets('tek satırlık alanda görünmez', (WidgetTester tester) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(withKeyboard(TextField(focusNode: focus)));

      focus.requestFocus();
      await tester.pump();

      // Tek satırlıkta klavyenin kendi "Bitti" tuşu zaten var.
      expect(find.text('Bitti'), findsNothing);
    });

    testWidgets('çok satırlı alan "Bitti" tuşu istediyse görünmez', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        withKeyboard(
          TextField(
            focusNode: focus,
            maxLines: 4,
            textInputAction: TextInputAction.done,
          ),
        ),
      );

      focus.requestFocus();
      await tester.pump();

      expect(find.text('Bitti'), findsNothing);
    });
  });
}
