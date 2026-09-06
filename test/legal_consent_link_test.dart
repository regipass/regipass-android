import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:regipass/features/shared/legal_consent.dart';
import 'package:regipass/features/shared/legal_document_screen.dart';
import 'package:regipass/l10n/app_strings.dart';

/// Belge adları artık ortak bir cümle içine gömülü linkler değil, onay
/// metninin altında duran, kendi başına geniş dokunma alanlı iki ayrı
/// buton (chip). Bu testler her çipin doğru belgeyi açtığını ve onay
/// kutusundan bağımsız çalıştığını doğrular.
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
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

  Future<void> pumpHost(WidgetTester tester, {String language = 'tr'}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LanguageScope(language: language, child: const _Host()),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? openDocumentTitle(WidgetTester tester, String language) {
    final Finder screen = find.byType(LegalDocumentScreen);
    if (screen.evaluate().isEmpty) return null;
    return tester.widget<LegalDocumentScreen>(screen).document.title(language);
  }

  Future<void> tapChipAndPop(
    WidgetTester tester,
    String label,
    String expectedTitle,
    String language,
  ) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(
      openDocumentTitle(tester, language),
      expectedTitle,
      reason: '"$label" çipine dokunuş yanlış belgeyi açtı',
    );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(openDocumentTitle(tester, language), isNull);
  }

  testWidgets('Türkçede her belge çipi kendi belgesini açar', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    await tapChipAndPop(
      tester,
      'Kullanıcı ve Kulüp Sözleşmesi',
      'Kullanıcı ve Kulüp Sözleşmesi',
      'tr',
    );
    await tapChipAndPop(
      tester,
      'KVKK Aydınlatma Metni',
      'KVKK Aydınlatma Metni',
      'tr',
    );
  });

  testWidgets('İngilizcede her belge çipi kendi belgesini açar', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester, language: 'en');
    await tapChipAndPop(
      tester,
      'User and Club Agreement',
      'User and Club Agreement',
      'en',
    );
    await tapChipAndPop(
      tester,
      'Data Protection Notice',
      'Data Protection Notice',
      'en',
    );
  });

  testWidgets('çip üzerindeyken gelen yeniden çizim dokunuşu yutmaz', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('KVKK Aydınlatma Metni')),
    );

    // Parmak çipin üzerindeyken ekranı besleyen bir kaynak yayın yapıyor.
    tester.state<_HostState>(find.byType(_Host)).rebuild();
    await tester.pump();

    await gesture.up();
    await tester.pumpAndSettle();

    expect(openDocumentTitle(tester, 'tr'), 'KVKK Aydınlatma Metni');
  });

  testWidgets('onay kutusu dokunuşları belge açmaz', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(openDocumentTitle(tester, 'tr'), isNull);
    expect(tester.state<_HostState>(find.byType(_Host)).terms, isTrue);
  });

  testWidgets('salt-okunur özet çipleri hâlâ dokunulabilir', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: LanguageScope(
          language: 'tr',
          child: Scaffold(
            body: SingleChildScrollView(
              child: ConsentSummary(
                termsAccepted: true,
                marketingConsent: false,
                acceptedAtMs: 1735689600000,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('KVKK Aydınlatma Metni'));
    await tester.pumpAndSettle();
    expect(openDocumentTitle(tester, 'tr'), 'KVKK Aydınlatma Metni');
  });
}
