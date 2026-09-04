import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/features/shared/support_contact.dart';
import 'package:regipass/l10n/app_strings.dart';

/// Hesap ekranındaki "İletişim" simgesinin açtığı alt sayfa.
///
/// Sayfanın tek işi var: aranacak numarayı okunur biçimde göstermek ve
/// kullanıcıdan açık onay almak. Numara koda gömülü olduğu için ekranda
/// göründüğü hâlin sabitle aynı kaldığını test doğruluyor — biri sabiti
/// değiştirirse ya da biçimlendirmeyi bozarsa burada yakalanır.
Widget _wrap(Widget child) => LanguageScope(
  language: 'tr',
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('destek sayfası numarayı ve onay sorusunu gösterir', (
    WidgetTester tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    unawaited(showSupportContactSheet(ctx));
    await tester.pumpAndSettle();

    expect(find.text(kSupportPhoneDisplay), findsOneWidget);
    expect(find.text('+90 (850) 888 35 58'), findsOneWidget);
    expect(
      find.text(translate('support.callPrompt', language: 'tr')),
      findsOneWidget,
    );
    expect(
      find.text(translate('support.call', language: 'tr')),
      findsOneWidget,
    );
  });

  testWidgets('vazgeç sayfayı arama başlatmadan kapatır', (
    WidgetTester tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    unawaited(showSupportContactSheet(ctx));
    await tester.pumpAndSettle();

    await tester.tap(find.text(translate('common.cancel', language: 'tr')));
    await tester.pumpAndSettle();

    expect(find.text(kSupportPhoneDisplay), findsNothing);
  });
}
