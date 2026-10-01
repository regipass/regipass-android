/// Yönetici → Bildirimler → "Genel Duyuru" akışı.
///
/// Ekran, yönetici kabuğunun (`ShellRoute`) KENDİ Navigator'ının altında
/// çiziliyor; `showDialog` ise pencereyi kök Navigator'a itiyor. Testteki
/// iç içe Navigator bu düzeni birebir kuruyor — onay penceresinin ekranın
/// context'iyle kapatılmaya çalışıldığı hata ancak bu düzende görünüyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/features/admin/admin_notifications_screen.dart';
import 'package:regipass/l10n/app_strings.dart';
import 'package:regipass/models/announcement.dart';
import 'package:regipass/services/announcement_repository.dart';
import 'package:regipass/state/providers.dart';

/// Gönderilen duyuruyu Firestore yerine belleğe yazan sahte depo.
class _RecordingRepository extends AnnouncementRepository {
  final List<({String title, String body, String audience})> broadcasts =
      <({String title, String body, String audience})>[];
  final List<({String audience, String university})> singles =
      <({String audience, String university})>[];

  @override
  Future<void> sendBroadcast({
    required String title,
    required String body,
    required String audience,
    required String senderUid,
  }) async {
    broadcasts.add((title: title, body: body, audience: audience));
  }

  @override
  Future<void> send({
    required String title,
    required String body,
    required String audience,
    required String university,
    required String city,
    required String senderUid,
  }) async {
    singles.add((audience: audience, university: university));
  }
}

Widget _app(_RecordingRepository repository) => ProviderScope(
  overrides: [
    announcementRepositoryProvider.overrideWithValue(repository),
    currentUidProvider.overrideWithValue('admin-uid'),
  ],
  child: LanguageScope(
    language: 'tr',
    child: MaterialApp(
      // `ShellRoute` navigatorKey verilmediğinde kendi Navigator'ını kurar;
      // ekranın context'i o iç Navigator'ın altında kalır.
      home: Navigator(
        onGenerateRoute: (RouteSettings _) => MaterialPageRoute<void>(
          builder: (BuildContext _) => const AdminNotificationsScreen(),
        ),
      ),
    ),
  ),
);

/// Genel duyuru penceresini açar, hedef kitleyi seçer, metni yazar ve
/// onay penceresindeki "Gönder"e basar.
Future<void> _composeBroadcast(
  WidgetTester tester, {
  required String audienceLabel,
  String title = 'Kayıt haftası',
  String body = 'Tanıtım günleri 12 Eylül’de başlıyor.',
}) async {
  await tester.tap(find.text('Genel Duyuru'));
  await tester.pumpAndSettle();

  await tester.tap(find.text(audienceLabel));
  await tester.enterText(
    find.widgetWithText(TextField, 'Bildirim başlığı'),
    title,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Bildirim metni'),
    body,
  );
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(FilledButton, 'Gönder'));
  await tester.pumpAndSettle();

  // Onay penceresi.
  await tester.tap(find.widgetWithText(FilledButton, 'Gönder'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('genel duyuru penceresinde başlık ve metin alanı var', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_RecordingRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Genel Duyuru'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Bildirim başlığı'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Bildirim metni'), findsOneWidget);
    expect(find.text('Katılımcılar'), findsOneWidget);
    expect(find.text('Organizatörler'), findsOneWidget);
    expect(find.text('Her ikisi'), findsOneWidget);
  });

  testWidgets('onay penceresindeki İptal yalnızca pencereyi kapatır', (
    WidgetTester tester,
  ) async {
    final _RecordingRepository repository = _RecordingRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Genel Duyuru'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Bildirim başlığı'),
      'Başlık',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Bildirim metni'),
      'Metin',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Gönder'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'İptal'));
    await tester.pumpAndSettle();

    expect(find.text('Genel duyuru gönderilsin mi?'), findsNothing);
    expect(find.byType(AdminNotificationsScreen), findsOneWidget);
    expect(repository.broadcasts, isEmpty);
  });

  testWidgets('onay penceresi gönderilecek duyuruyu gösterir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_RecordingRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Genel Duyuru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organizatörler'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Bildirim başlığı'),
      'Kayıt haftası',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Bildirim metni'),
      'Tanıtım günleri başlıyor.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Gönder'));
    await tester.pumpAndSettle();

    expect(find.text('Genel duyuru gönderilsin mi?'), findsOneWidget);
    expect(find.text('Kayıt haftası'), findsOneWidget);
    expect(find.text('Tanıtım günleri başlıyor.'), findsOneWidget);
    expect(find.text('Organizatörler'), findsOneWidget);
  });

  group('genel duyuru üç hedef kitlenin her biri için gönderilir', () {
    for (final ({String label, String value}) target
        in <({String label, String value})>[
          (label: 'Öğrenciler', value: AnnouncementAudience.students),
          (label: 'Kulüpler', value: AnnouncementAudience.clubs),
          (label: 'Her ikisi', value: AnnouncementAudience.all),
        ]) {
      testWidgets(target.label, (WidgetTester tester) async {
        final _RecordingRepository repository = _RecordingRepository();
        await tester.pumpWidget(_app(repository));
        await tester.pumpAndSettle();

        await _composeBroadcast(tester, audienceLabel: target.label);

        expect(repository.broadcasts, hasLength(1));
        expect(repository.broadcasts.single.audience, target.value);
        expect(repository.broadcasts.single.title, 'Kayıt haftası');
        expect(
          repository.broadcasts.single.body,
          'Tanıtım günleri 12 Eylül’de başlıyor.',
        );

        // Pencere kapanmış, ekran yerinde durmalı.
        expect(find.text('Genel duyuru gönderilsin mi?'), findsNothing);
        expect(find.byType(AdminNotificationsScreen), findsOneWidget);
        expect(
          find.text('Genel duyuru tüm üniversitelere gönderildi.'),
          findsOneWidget,
        );
      });
    }
  });
}
