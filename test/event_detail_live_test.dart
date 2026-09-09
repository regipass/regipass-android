import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/shared/event_widgets.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/state/providers.dart';

AppEvent _event({required String clubName, required String title}) =>
    AppEvent.fromMap('event-1', <String, dynamic>{
      'title': title,
      'clubId': 'club-1',
      'clubName': clubName,
      'clubUniversity': 'İlk Üniversite',
      'clubFields': <String>['Teknoloji'],
      'hiddenGlobally': false,
    });

void main() {
  testWidgets('detay penceresi etkinlik ve kulüp bilgisini canlı yeniler', (
    WidgetTester tester,
  ) async {
    final StreamController<AppEvent?> events =
        StreamController<AppEvent?>.broadcast();
    addTearDown(events.close);

    final AppEvent initial = _event(
      clubName: 'Eski Kulüp Adı',
      title: 'Eski Etkinlik Adı',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventByIdProvider(
            initial.id,
          ).overrideWith((Ref ref) => events.stream),
        ],
        child: LanguageScope(
          language: 'tr',
          child: MaterialApp(
            home: Scaffold(body: EventDetailSheet(event: initial)),
          ),
        ),
      ),
    );

    expect(find.text('Eski Kulüp Adı'), findsOneWidget);
    expect(find.text('Eski Etkinlik Adı'), findsOneWidget);

    events.add(_event(clubName: 'Yeni Kulüp Adı', title: 'Yeni Etkinlik Adı'));
    await tester.pump();

    expect(find.text('Yeni Kulüp Adı'), findsOneWidget);
    expect(find.text('Yeni Etkinlik Adı'), findsOneWidget);
    expect(find.text('Eski Kulüp Adı'), findsNothing);
    expect(find.text('Eski Etkinlik Adı'), findsNothing);
  });
}
