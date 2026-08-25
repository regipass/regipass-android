import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/shared/common_widgets.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/core/constants.dart';
import 'package:regipass/models/event.dart';

/// 1x1 saydam PNG — gerçek bir görsel gerektiren testler için en küçük yük.
const String _kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Widget _wrap(Widget child) => LanguageScope(
      language: 'tr',
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('EventImage', () {
    // Web, yüklenen görseli Storage'a değil dokümana base64 `data:` adresi
    // olarak yazıyor. `Image.network` bu adresleri çözemiyor; bu yüzden
    // web'den yüklenen her etkinlik görseli mobilde kırık görünüyordu.
    testWidgets('base64 data: adresini çizer', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const EventImage(
            url: 'data:image/png;base64,$_kTinyPngBase64',
            height: 100,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      // Ağ görseli DEĞİL: bellek görseli olmalı.
      final Image image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('bozuk data: adresinde marka perdesi gösterir', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const EventImage(url: 'data:image/png;base64,@@bozuk@@')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EventCoverPlaceholder), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('base64 gövdesi doğru çözülür', () {
      final Uint8List bytes = base64Decode(_kTinyPngBase64);
      // PNG imzası: 89 50 4E 47
      expect(bytes.take(4), <int>[0x89, 0x50, 0x4E, 0x47]);
    });
  });

  // Kulüp etkinliğe görsel eklemediğinde kapakta rastgele bir doğa fotoğrafı
  // değil, gri Regipass perdesi görünmeli.
  group('kapaksız etkinlik', () {
    AppEvent event({String imageUrl = ''}) =>
        AppEvent.fromMap('e1', <String, dynamic>{
          'title': 'Etkinlik',
          'imageUrl': imageUrl,
        });

    test('kulübün kapağı varsa o kullanılır', () {
      expect(
        event(imageUrl: 'https://ornek/kapak.jpg').displayImageUrl,
        'https://ornek/kapak.jpg',
      );
    });

    test('kapak yoksa adres boş kalır', () {
      expect(event().displayImageUrl, isEmpty);
    });

    test('eski doğa fotoğrafı ve ağ yer tutucusu da kapaksız sayılır', () {
      expect(event(imageUrl: kNatureImagePool.first).displayImageUrl, isEmpty);
      expect(event(imageUrl: kEventPlaceholderImage).displayImageUrl, isEmpty);
    });

    testWidgets('boş adreste marka perdesi çizilir, ağ görseli çekilmez', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const EventImage(url: '', height: 120)));
      await tester.pumpAndSettle();

      expect(find.byType(EventCoverPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
