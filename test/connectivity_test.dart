import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/shared/offline_banner.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/state/connectivity.dart';

/// Çevrimdışı uyarısı testleri.
///
/// Uyarı şeridi yalnızca bağlantı koptuğunda görünmeli; her açılışta kısa
/// süreliğine çakmamalı. Bu ayrım `onlineProvider`'ın geri düşme sırasında
/// gizli olduğu için elle doğrulanması zor.
void main() {
  test('akış henüz bir şey yayınlamadıysa açılış ölçümü kullanılır', () {
    final ProviderContainer container = ProviderContainer(
      // ignore: always_specify_types
      overrides: [
        isOnlineProvider.overrideWith((Ref ref) => const Stream<bool>.empty()),
        initialOnlineProvider.overrideWith((Ref ref) async => false),
      ],
    );
    addTearDown(container.dispose);

    // Açılış ölçümü de çözülmeden önce "bağlı" varsayılır: aksi hâlde her
    // açılışta uyarı bir kare boyunca görünürdü.
    expect(container.read(onlineProvider), isTrue);
  });

  testWidgets('bağlantı koptuğunda uyarı şeridi belirir, gelince kaybolur', (
    WidgetTester tester,
  ) async {
    final StreamController<bool> online = StreamController<bool>.broadcast();
    addTearDown(online.close);

    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types
        overrides: [
          isOnlineProvider.overrideWith((Ref ref) => online.stream),
          initialOnlineProvider.overrideWith((Ref ref) async => true),
        ],
        child: const LanguageScope(
          language: 'tr',
          child: MaterialApp(
            home: Scaffold(body: OfflineBanner(child: SizedBox.expand())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    // Bağlıyken şerit çizilir ama tamamen saydam ve ekranın dışındadır.
    expect(opacity(), 0);

    online.add(false);
    await tester.pumpAndSettle();
    expect(find.text('İnternet bağlantısı yok'), findsOneWidget);
    expect(opacity(), 1);

    online.add(true);
    await tester.pumpAndSettle();
    expect(opacity(), 0);
  });
}
