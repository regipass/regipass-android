import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_reminders.dart';
import 'package:regipass/features/notifications/notification_providers.dart';
import 'package:regipass/features/student/student_providers.dart';
import 'package:regipass/models/announcement.dart';
import 'package:regipass/models/event.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bildirim akışının yönlendirme tarafı.
///
/// Firestore'a hiç dokunulmaz: kitle, duyuru akışı ve kayıt listesi doğrudan
/// override edilir. Doğrulanan tek şey, bildirime dokununca nereye
/// gidileceğinin doğru çözülmesi.

/// Başlangıcı geçmişte kalan (yani hatırlatması "gönderilmiş") etkinlik.
AppEvent firedEvent({String id = 'evt-1', String title = 'Kariyer Günleri'}) {
  final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));

  return AppEvent.fromMap(id, <String, dynamic>{
    'title': title,
    'eventDateAtMs': DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
    ).millisecondsSinceEpoch,
    'eventStartTime': '10:00',
    'deadlineAtMs': yesterday
        .subtract(const Duration(days: 2))
        .millisecondsSinceEpoch,
  });
}

RegistrationWithEvent registrationFor(AppEvent event, String studentId) =>
    RegistrationWithEvent(
      registration: EventRegistration.fromMap(
        '${event.id}_$studentId',
        <String, dynamic>{
          'eventId': event.id,
          'eventTitle': event.title,
          'studentId': studentId,
        },
      ),
      event: event,
    );

ProviderContainer containerFor({
  required ReminderAudience audience,
  List<AppEvent> events = const <AppEvent>[],
  List<RegistrationWithEvent> appointments = const <RegistrationWithEvent>[],
  List<Announcement> announcements = const <Announcement>[],
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      notificationAudienceProvider.overrideWithValue(audience),
      reminderSourceEventsProvider.overrideWithValue(events),
      appointmentsProvider.overrideWith(
        (Ref ref) async => appointments,
      ),
      myAnnouncementsProvider.overrideWith(
        (Ref ref) => Stream<List<Announcement>>.value(announcements),
      ),
    ],
  );
  // Dinleyicisi olmayan sağlayıcı hemen atılıyor: akış zincirini (duyurular,
  // kayıtlar, dil) bir dinleyici canlı tutmazsa asenkron kaynaklar hiç
  // çözülmeden düşer.
  container.listen(notificationFeedProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

/// Asenkron kaynakların (duyuru akışı, kayıt listesi) çözülmesini bekler.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  // Akış, metinleri çözmek için dil tercihini okuyor; o da SharedPreferences
  // üzerinden geliyor. Sahte depo olmadan sağlayıcı daha kurulurken patlıyor.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('kulüp bildirimi etkinliğin yönetim sayfasına gider', () {
    final AppEvent event = firedEvent();
    final ProviderContainer container = containerFor(
      audience: ReminderAudience.club,
      events: <AppEvent>[event],
    );

    final List<NotificationItem> feed = container.read(
      notificationFeedProvider,
    );

    expect(feed, isNotEmpty);
    for (final NotificationItem item in feed) {
      expect(item.hasRoute, isTrue);
      expect(item.route, startsWith('/club/events/detail?eventId='));
      expect(item.route, contains(event.id));
    }
  });

  test('öğrenci bildirimi kendi kaydının detay penceresini açar', () async {
    final AppEvent event = firedEvent();
    final ProviderContainer container = containerFor(
      audience: ReminderAudience.student,
      events: <AppEvent>[event],
      appointments: <RegistrationWithEvent>[registrationFor(event, 'stu-9')],
    );

    // appointmentsProvider asenkron; kayıt eşlemesi ancak çözüldükten sonra
    // kurulabilir.
    await settle();

    final List<NotificationItem> feed = container.read(
      notificationFeedProvider,
    );

    expect(feed, isNotEmpty);
    for (final NotificationItem item in feed) {
      expect(item.route, '/student/appointments?open=${event.id}_stu-9');
    }
  });

  test('kaydı bulunmayan öğrenci bildiriminde yönlendirme olmaz', () {
    final ProviderContainer container = containerFor(
      audience: ReminderAudience.student,
      events: <AppEvent>[firedEvent()],
    );

    final List<NotificationItem> feed = container.read(
      notificationFeedProvider,
    );

    expect(feed, isNotEmpty);
    for (final NotificationItem item in feed) {
      expect(item.hasRoute, isFalse);
    }
  });

  test('duyuruda gidilecek bir sayfa yoktur', () async {
    final ProviderContainer container = containerFor(
      audience: ReminderAudience.student,
      announcements: <Announcement>[
        Announcement.fromMap('a1', <String, dynamic>{
          'title': 'Duyuru',
          'body': 'Metin',
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        }),
      ],
    );

    await settle();

    final List<NotificationItem> feed = container.read(
      notificationFeedProvider,
    );

    expect(feed.length, 1);
    expect(feed.single.isAnnouncement, isTrue);
    expect(feed.single.hasRoute, isFalse);
  });
}
