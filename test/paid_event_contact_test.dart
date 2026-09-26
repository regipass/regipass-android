import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/shared/event_widgets.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';

/// Ücretli etkinlikte kayıt sonrası açılan iletişim penceresi.
///
/// Ücret uygulama içinde tahsil edilmiyor; kayıt alındıktan sonra öğrencinin
/// kulübe ulaşabilmesi gerekiyor. Ücretsiz etkinlikte aynı pencere kulübün
/// numarasını gereksiz yere yaymamalı.
AppEvent _event({
  required String feeType,
  String phone = '05551112233',
  String email = 'kulup@example.com',
}) =>
    AppEvent.fromMap('e1', <String, dynamic>{
      'title': 'Kariyer Günleri',
      'feeType': feeType,
      'clubPhone': phone,
      'clubEmail': email,
      if (feeType == 'paid') 'feeAmount': 150,
      if (feeType == 'paid') 'feeInfo': '150 TL',
    });

String _feeNote() => translate(
      'eventModal.feeContactNoteWithFee',
      params: <String, Object?>{'fee': '150 TL'},
      language: 'tr',
    );

Widget _wrap(Widget child) => LanguageScope(
      language: 'tr',
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('showPaidEventContactDialog', () {
    testWidgets('ücretli etkinlikte not ve iletişim bilgilerini gösterir', (
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

      unawaited(showPaidEventContactDialog(ctx, _event(feeType: 'paid')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(_feeNote()), findsOneWidget);
      expect(find.text('05551112233'), findsOneWidget);
      expect(find.text('kulup@example.com'), findsOneWidget);
    });

    testWidgets('ücretsiz etkinlikte pencere açılmaz', (
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

      unawaited(showPaidEventContactDialog(ctx, _event(feeType: 'free')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('iletişim bilgisi yoksa yalnızca not gösterilir', (
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

      unawaited(
        showPaidEventContactDialog(
          ctx,
          _event(feeType: 'paid', phone: '', email: ''),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_feeNote()), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);
      expect(find.byIcon(Icons.mail_outline), findsNothing);
    });

    // Satırlar eskiden `tel:`/`mailto:` açıyordu. Arama/e-posta uygulaması
    // olmayan cihazda dokunuş sessizce yutuluyordu; kopyalama her yerde
    // çalışır ve ödeme yazışmasına taşımak isteyen öğrencinin asıl yaptığı iş
    // de bu.
    testWidgets('numaraya ve e-postaya dokunmak panoya kopyalar', (
      WidgetTester tester,
    ) async {
      final List<String> copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add('${(call.arguments as Map<Object?, Object?>)['text']}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

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

      unawaited(showPaidEventContactDialog(ctx, _event(feeType: 'paid')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('05551112233'));
      await tester.pump();
      expect(copied, <String>['05551112233']);
      expect(
        find.text(translate('eventModal.phoneCopied', language: 'tr')),
        findsOneWidget,
      );

      await tester.tap(find.text('kulup@example.com'));
      await tester.pump();
      expect(copied, <String>['05551112233', 'kulup@example.com']);
      expect(
        find.text(translate('eventModal.emailCopied', language: 'tr')),
        findsOneWidget,
      );

      // Bildirim kök katmanda yaşıyor; testin sonunda zamanlayıcısı
      // beklemede kalmasın.
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('EventPaidContactBlock', () {
    Future<void> pump(WidgetTester tester, AppEvent event) =>
        tester.pumpWidget(_wrap(EventPaidContactBlock(event: event)));

    testWidgets('ücretsiz: "İletişim Bilgileri" başlığı, ücret notu yok', (
      WidgetTester tester,
    ) async {
      await pump(tester, _event(feeType: 'free'));
      expect(find.text(translate('eventModal.contactTitle', language: 'tr')), findsOneWidget);
      expect(find.text('05551112233'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('ücretli: "Ücret İçin İletişim Bilgileri" + ücret notu', (
      WidgetTester tester,
    ) async {
      await pump(tester, _event(feeType: 'paid'));
      expect(find.text(translate('eventModal.feeContactTitle', language: 'tr')), findsOneWidget);
      expect(find.text(_feeNote()), findsOneWidget);
    });

    testWidgets('ücretsiz + gizle: hiçbir şey gösterilmez', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        AppEvent.fromMap('e2', <String, dynamic>{
          'title': 'X',
          'clubPhone': '05551112233',
          'contactMode': 'hidden',
        }),
      );
      expect(find.byType(EventSectionTitle), findsNothing);
    });
  });

  testWidgets('kulüp ekranında not kulübe göre yazılır', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(EventPaidContactBlock(event: _event(feeType: 'paid'), forClub: true)),
    );
    expect(find.text(_feeNote()), findsNothing);
    expect(
      find.text(
        translate(
          'eventModal.feeContactNoteClub',
          params: <String, Object?>{'fee': '150 TL'},
          language: 'tr',
        ),
      ),
      findsOneWidget,
    );
  });
}
