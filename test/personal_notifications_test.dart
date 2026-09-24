import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_reminders.dart';
import 'package:regipass/features/student/student_providers.dart';
import 'package:regipass/models/announcement.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regipass/features/notifications/notification_providers.dart';
import 'package:regipass/models/inbox_entry.dart';
import 'package:regipass/services/device_token_repository.dart';
import 'package:regipass/services/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'kişisel bildirimler duyurularla aynı akışta, tarihe göre sıralanır',
    () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          notificationAudienceProvider.overrideWithValue(
            ReminderAudience.student,
          ),
          reminderSourceEventsProvider.overrideWithValue(const []),
          appointmentsProvider.overrideWith((Ref ref) async => const []),
          myAnnouncementsProvider.overrideWith(
            (Ref ref) =>
                Stream<List<Announcement>>.value(const <Announcement>[]),
          ),
          myInboxProvider.overrideWith(
            (Ref ref) => Stream<List<InboxEntry>>.value(<InboxEntry>[
              InboxEntry.fromMap('eski', <String, dynamic>{
                'title': <String, dynamic>{'tr': 'Eski'},
                'createdAtMs': 1,
                'readAtMs': 3,
              }),
              InboxEntry.fromMap('yeni', <String, dynamic>{
                'title': <String, dynamic>{'tr': 'Belgen geldi', 'en': 'Ready'},
                'createdAtMs': 2,
                'route': '/student/certificates',
              }),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notificationFeedProvider, (_, _) {});
      container.listen(unreadNotificationCountProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final List<NotificationItem> feed = container.read(
        notificationFeedProvider,
      );
      expect(feed.map((NotificationItem i) => i.id), <String>[
        'inbox:yeni',
        'inbox:eski',
      ]);
      expect(feed.first.title, 'Belgen geldi');
      expect(feed.first.route, '/student/certificates');
      expect(feed.first.isPersonal, isTrue);
      expect(
        container.read(unreadNotificationCountProvider),
        1,
      ); // eski okunmuş
    },
  );

  group('InboxEntry (users/{uid}/inbox, İP-6)', () {
    test('sunucu kaydı iki dilli okunur, arayüz diline göre seçilir', () {
      final InboxEntry e = InboxEntry.fromMap('n1', <String, dynamic>{
        'kind': 'certificate_ready',
        'title': <String, dynamic>{'tr': 'Belgen geldi', 'en': 'Ready'},
        'body': <String, dynamic>{'tr': 'Metin'},
        'createdAtMs': 1700,
        'route': '/student/certificates',
        'readAtMs': null,
      });
      expect(e.titleIn('tr'), 'Belgen geldi');
      expect(e.titleIn('en'), 'Ready');
      expect(e.bodyIn('en'), 'Metin'); // eksik dil diğerine düşer
      expect(e.createdAtMs, 1700);
      expect(e.route, '/student/certificates');
      expect(e.isRead, isFalse);
    });

    test('okundu bilgisi ve bozuk alanlar', () {
      final InboxEntry e = InboxEntry.fromMap('n2', <String, dynamic>{
        'title': 42,
        'createdAtMs': 5.0,
        'readAtMs': 99,
      });
      expect(e.isRead, isTrue);
      expect(e.titleIn('tr'), '');
      expect(e.createdAtMs, 5);
    });

    test('yalnızca öğrenci/kulüp rotaları kabul edilir', () {
      expect(safeInboxRoute('/student/certificates'), '/student/certificates');
      expect(
        safeInboxRoute('/club/events/detail?eventId=e1'),
        '/club/events/detail?eventId=e1',
      );
      for (final String bad in <String>[
        '/admin/ban',
        'https://kotu.site',
        '//x',
        'student',
        '',
      ]) {
        expect(safeInboxRoute(bad), '', reason: bad);
      }
    });
  });

  group('push yükü', () {
    test('rota yüke yazılır ve geri okunur; geçersiz rota boş kalır', () {
      expect(
        personalPayload('/student/certificates'),
        'personal:/student/certificates',
      );
      expect(
        routeFromPersonalPayload('personal:/student/certificates'),
        '/student/certificates',
      );
      expect(personalPayload('/admin'), 'personal:');
      expect(routeFromPersonalPayload('personal:'), '');
      expect(routeFromPersonalPayload('announcement:a1'), isNull);
      expect(routeFromPersonalPayload(null), isNull);
    });
  });

  group('okunmamış hesabı', () {
    NotificationItem item({
      NotificationItemKind kind = NotificationItemKind.personal,
      int atMs = 10,
      bool readElsewhere = false,
    }) => NotificationItem(
      id: 'inbox:n1',
      kind: kind,
      title: 't',
      body: 'b',
      atMs: atMs,
      readElsewhere: readElsewhere,
    );

    test('web zilinde okunmuş kişisel bildirim telefonda yeni görünmez', () {
      expect(
        isUnreadNotification(item(), seenAtMs: 0, opened: <String>{}),
        isTrue,
      );
      expect(
        isUnreadNotification(
          item(readElsewhere: true),
          seenAtMs: 0,
          opened: <String>{},
        ),
        isFalse,
      );
    });

    test('dokunulan ya da sayfa damgasından eski bildirim okunmuş sayılır', () {
      expect(
        isUnreadNotification(item(), seenAtMs: 0, opened: <String>{'inbox:n1'}),
        isFalse,
      );
      expect(
        isUnreadNotification(item(atMs: 5), seenAtMs: 9, opened: <String>{}),
        isFalse,
      );
      expect(
        isUnreadNotification(
          item(kind: NotificationItemKind.announcement, readElsewhere: true),
          seenAtMs: 0,
          opened: <String>{},
        ),
        isTrue, // duyurularda sunucu okundu bilgisi yok
      );
    });

    test('inboxId yalnızca kişisel bildirimde dolu', () {
      expect(item().inboxId, 'n1');
      expect(item(kind: NotificationItemKind.upcoming).inboxId, '');
    });
  });

  group('cihaz kaydı', () {
    test('kurallardaki alan listesine uyar', () {
      final Map<String, Object> data = deviceDocData(
        token: 'fcm',
        platform: 'ios',
        language: 'de',
        nowMs: 7,
      );
      expect(
        data.keys.toSet().difference(<String>{
          'token',
          'platform',
          'language',
          'appVersion',
          'updatedAt',
          'updatedAtMs',
        }),
        isEmpty,
      );
      expect(data['platform'], 'ios');
      expect(data['language'], 'tr'); // desteklenmeyen dil → tr
      expect(data['updatedAtMs'], 7);
      expect(data.containsKey('appVersion'), isFalse);
      expect(
        deviceDocData(token: 't', platform: 'x', language: 'en')['platform'],
        'android',
      );
    });
  });
}
