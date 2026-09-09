import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/club/club_events_screen.dart';
import 'package:regipass/features/club/club_providers.dart';
import 'package:regipass/features/shared/event_widgets.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/event.dart';
import 'package:regipass/state/providers.dart';

AppEvent _event() => AppEvent.fromMap('event-1', <String, dynamic>{
  'title': 'QR ile girilen etkinlik',
  'clubId': 'club-1',
  'clubName': 'Kulüp',
  'hiddenGlobally': false,
});

void main() {
  testWidgets(
    'QR dönüşündeki openEventId ilgili etkinlik penceresini otomatik açar',
    (WidgetTester tester) async {
      final AppEvent event = _event();
      final StreamController<AppEvent?> liveEvent =
          StreamController<AppEvent?>.broadcast();
      addTearDown(liveEvent.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clubEventsProvider.overrideWith(
              (Ref ref) => Stream<List<AppEvent>>.value(<AppEvent>[event]),
            ),
            eventByIdProvider(
              event.id,
            ).overrideWith((Ref ref) => liveEvent.stream),
          ],
          child: LanguageScope(
            language: 'tr',
            child: const MaterialApp(
              home: ClubEventsScreen(openEventId: 'event-1'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(EventDetailSheet), findsOneWidget);
      expect(find.text('QR ile girilen etkinlik'), findsOneWidget);
    },
  );
}
