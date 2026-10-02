// İP-T2: kayıttan sonra takvim / bilet penceresi ve bilet resmi.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:regipass/features/shared/ticket_image.dart';
import 'package:regipass/features/student/post_registration_sheet.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

final int start = DateTime.parse(
  '2026-09-30T11:00:00Z',
).millisecondsSinceEpoch; // 14:00 TR

AppEvent ev(Map<String, dynamic> extra) =>
    AppEvent.fromMap('e1', <String, dynamic>{
      'title': 'Klinik Eczacılık Paneli',
      'clubName': 'Ege Farma',
      'locationName': 'B-204',
      'eventDateAtMs': DateTime.parse(
        '2026-09-29T21:00:00Z',
      ).millisecondsSinceEpoch,
      'eventStartAtMs': start,
      'eventEndAtMs': start + 2 * 3600000,
      ...extra,
    });

Widget app(AppEvent event) => ProviderScope(
  overrides: [currentUidProvider.overrideWithValue('u1')],
  child: LanguageScope(
    language: 'tr',
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showPostRegistrationSheet(
              context,
              event: event,
              message: 'Etkinliğe kaydın alındı.',
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

  test('bilet dosya adı ve tarih metni', () {
    expect(
      ticketFileName('Işık & Gölge: Söyleşi'),
      'regipass-bilet-isik-golge-soylesi.png',
    );
    expect(ticketFileName(''), 'regipass-bilet-bilet.png');
    final String text = ticketDateText(ev(<String, dynamic>{}));
    expect(text, contains('30 Eylül 2026'));
    expect(text, contains('14:00–16:00'));
    expect(
      ticketDateText(
        ev(<String, dynamic>{'eventStartAtMs': null, 'eventEndAtMs': null}),
      ),
      contains('30 Eylül 2026'),
    );
  });

  testWidgets('bilet kartı PNG olarak çizilir', (WidgetTester tester) async {
    final Uint8List? png = await tester.runAsync(
      () => renderTicketPng(
        title: 'Klinik Eczacılık Paneli',
        dateText: '30 Eylül 2026 · 14:00–16:00',
        place: 'B-204',
        clubLine: 'Düzenleyen: Ege Farma',
        studentName: 'Ayşe Yılmaz',
        qrData: 'RP1.test',
        note: 'Kapıda bu kodu göster.',
      ),
    );
    expect(png, isNotNull);
    expect(png!.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('pencere sorar; kapı girişi olan etkinlikte bilet düğmesi var', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      app(ev(<String, dynamic>{'checkinMode': 'checkin_only'})),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('Kaydın tamam'), findsOneWidget);
    expect(find.byKey(const Key('postRegGoogle')), findsOneWidget);
    expect(find.byKey(const Key('postRegCalendar')), findsOneWidget);
    expect(find.byKey(const Key('postRegTicket')), findsOneWidget);
    expect(await postRegistrationSkipped(), isFalse);

    await tester.tap(find.byKey(const Key('postRegSkip')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('postRegClose')));
    await tester.pumpAndSettle();
    expect(find.text('Kaydın tamam'), findsNothing);
    expect(await postRegistrationSkipped(), isTrue);
  });

  testWidgets('yalnızca yoklamalı etkinlikte bilet düğmesi yok', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      app(
        ev(<String, dynamic>{
          'checkinMode': 'attendance_only',
          'sessionCount': 2,
        }),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('postRegTicket')), findsNothing);
    expect(find.byKey(const Key('postRegGoogle')), findsOneWidget);
  });
}
