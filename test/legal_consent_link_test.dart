import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/shared/legal_consent.dart';
import 'package:regipass/features/shared/legal_document_screen.dart';
import 'package:regipass/l10n/app_strings.dart';

/// Onay satırındaki belge adları, adın HANGİ kelimesine basılırsa basılsın
/// doğru belgeyi açmalı — ad satır sonuna taştığında ("… ve KVKK" /
/// "Aydınlatma Metni'ni okudum") ikinci satırdaki parça da tıklanabilir
/// kalmalı.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool terms = false;

  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 200, 20, 20),
          child: LegalConsentSection(
            termsAccepted: terms,
            marketingConsent: false,
            onTermsChanged: (bool value) => setState(() => terms = value),
            onMarketingChanged: (_) {},
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<void> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: LanguageScope(language: 'tr', child: _Host()),
      ),
    );
    await tester.pumpAndSettle();
  }

  RenderParagraph consentParagraph(WidgetTester tester) {
    return tester.renderObject<RenderParagraph>(
      find
          .byWidgetPredicate(
            (Widget w) => w is RichText && w.text.toPlainText().contains('KVKK'),
          )
          .first,
    );
  }

  /// Metnin içindeki [needle] parçasının tam ortasına denk gelen ekran noktası.
  Offset centerOf(WidgetTester tester, String needle) {
    final RenderParagraph para = consentParagraph(tester);
    final String plain = para.text.toPlainText();
    final int start = plain.indexOf(needle);
    expect(start, isNonNegative, reason: '"$needle" onay metninde yok');
    final TextBox box = para
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + needle.length),
        )
        .first;
    return para.localToGlobal(
      Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2),
    );
  }

  String? openDocumentTitle(WidgetTester tester) {
    final Finder screen = find.byType(LegalDocumentScreen);
    if (screen.evaluate().isEmpty) return null;
    return tester.widget<LegalDocumentScreen>(screen).document.title('tr');
  }

  testWidgets('belge adının her kelimesi doğru metni açar', (
    WidgetTester tester,
  ) async {
    const Map<String, String> expected = <String, String>{
      'Kullanıcı': 'Kullanıcı ve Kulüp Sözleşmesi',
      'Sözleşmesi': 'Kullanıcı ve Kulüp Sözleşmesi',
      'KVKK': 'KVKK Aydınlatma Metni',
      // Satır sonuna taşan parça — asıl bildirilen hata buydu.
      'Aydınlatma': 'KVKK Aydınlatma Metni',
      'Metni': 'KVKK Aydınlatma Metni',
    };

    await pumpHost(tester);
    for (final MapEntry<String, String> entry in expected.entries) {
      await tester.tapAt(centerOf(tester, entry.key));
      await tester.pumpAndSettle();
      expect(
        openDocumentTitle(tester),
        entry.value,
        reason: '"${entry.key}" kelimesine dokunuş yanlış belgeyi açtı',
      );

      // Bir sonraki dokunuş için onay ekranına geri dön.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(openDocumentTitle(tester), isNull);
    }
  });

  testWidgets('metin üzerindeyken gelen yeniden çizim dokunuşu yutmaz', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    final TestGesture gesture = await tester.startGesture(
      centerOf(tester, 'Aydınlatma'),
    );

    // Parmak metnin üzerindeyken ekranı besleyen bir kaynak yayın yapıyor.
    tester.state<_HostState>(find.byType(_Host)).rebuild();
    await tester.pump();

    await gesture.up();
    await tester.pumpAndSettle();

    expect(openDocumentTitle(tester), 'KVKK Aydınlatma Metni');
  });

  testWidgets('onay kutusu dokunuşları belge açmaz', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(openDocumentTitle(tester), isNull);
    expect(tester.state<_HostState>(find.byType(_Host)).terms, isTrue);
  });
}
