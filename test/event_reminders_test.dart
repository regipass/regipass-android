import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_reminders.dart';
import 'package:regipass/models/announcement.dart';
import 'package:regipass/models/event.dart';

AppEvent event({
  String id = 'event-1',
  String title = 'Kariyer Günleri',
  DateTime? day,
  String startTime = '14:00',
  DateTime? deadline,
  bool registrationClosed = false,
}) => AppEvent.fromMap(id, <String, dynamic>{
  'title': title,
  'eventDateAtMs': (day ?? DateTime(2026, 9, 10)).millisecondsSinceEpoch,
  'eventStartTime': startTime,
  'deadlineAtMs': (deadline ?? DateTime(2026, 9, 5, 23, 59, 59))
      .millisecondsSinceEpoch,
  'registrationClosed': registrationClosed,
});

void main() {
  group('hatırlatma anları', () {
    test('başlangıçtan yarım saat önce ve başlangıç anı üretilir', () {
      final List<EventReminder> moments = reminderMomentsOf(event());

      final EventReminder upcoming = moments.firstWhere(
        (EventReminder r) => r.kind == EventReminderKind.upcoming,
      );
      final EventReminder started = moments.firstWhere(
        (EventReminder r) => r.kind == EventReminderKind.started,
      );

      expect(started.at, DateTime(2026, 9, 10, 14, 0));
      expect(upcoming.at, DateTime(2026, 9, 10, 13, 30));
      expect(started.at.difference(upcoming.at), kEventUpcomingLead);
    });

    test('son başvuru anı için hatırlatma kurulur', () {
      final EventReminder deadline = reminderMomentsOf(event()).firstWhere(
        (EventReminder r) => r.kind == EventReminderKind.deadline,
      );

      expect(deadline.at, DateTime(2026, 9, 5, 23, 59, 59));
    });

    test('kayıtlar elle kapatıldıysa son başvuru hatırlatması kurulmaz', () {
      final List<EventReminder> moments = reminderMomentsOf(
        event(registrationClosed: true),
      );

      expect(
        moments.any((EventReminder r) => r.kind == EventReminderKind.deadline),
        isFalse,
      );
    });

    test('başlangıç saati yoksa yalnızca son başvuru hatırlatılır', () {
      final List<EventReminder> moments = reminderMomentsOf(
        event(startTime: ''),
      );

      expect(moments, hasLength(1));
      expect(moments.single.kind, EventReminderKind.deadline);
    });

    test('geçersiz saat metni başlangıç hatırlatması üretmez', () {
      final List<EventReminder> moments = reminderMomentsOf(
        event(startTime: '25:99'),
      );

      expect(
        moments.every((EventReminder r) => r.kind == EventReminderKind.deadline),
        isTrue,
      );
    });
  });

  group('zaman süzgeci', () {
    test('geçmiş anlar zamanlamaya girmez', () {
      final List<EventReminder> future = remindersForEvent(
        event(),
        now: DateTime(2026, 9, 10, 13, 45),
      );

      // 13:30 geçti, 14:00 ve son başvuru (5 Eylül) geçti -> yalnızca başlangıç.
      expect(future, hasLength(1));
      expect(future.single.kind, EventReminderKind.started);
    });

    test('zamanı gelmiş hatırlatmalar geçmiş listesine düşer', () {
      final List<EventReminder> fired = firedRemindersForEvents(
        <AppEvent>[event()],
        now: DateTime(2026, 9, 10, 15, 0),
      );

      // Yeniden eskiye: başladı (14:00), yaklaşıyor (13:30), son başvuru (5 Eylül).
      expect(
        fired.map((EventReminder r) => r.kind).toList(),
        <EventReminderKind>[
          EventReminderKind.started,
          EventReminderKind.upcoming,
          EventReminderKind.deadline,
        ],
      );
    });

    test('pencereden eski hatırlatmalar listelenmez', () {
      final List<EventReminder> fired = firedRemindersForEvents(
        <AppEvent>[event()],
        now: DateTime(2026, 11, 1),
      );

      expect(fired, isEmpty);
    });

    test('zamanlama listesi verilen sınırı aşmaz', () {
      final List<AppEvent> many = <AppEvent>[
        for (int i = 0; i < 30; i++)
          event(
            id: 'event-$i',
            day: DateTime(2026, 9, 10 + i),
            deadline: DateTime(2026, 9, 2 + i, 23, 59, 59),
          ),
      ];

      final List<EventReminder> planned = remindersForEvents(
        many,
        now: DateTime(2026, 9, 1),
        limit: 10,
      );

      expect(planned, hasLength(10));
      // En yakın tarihliler önce kurulur.
      expect(planned.first.at.isBefore(planned.last.at), isTrue);
    });
  });

  group('bildirim kimliği', () {
    test('aynı etkinlik + tür her zaman aynı kimliği üretir', () {
      final EventReminder a = reminderMomentsOf(event()).first;
      final EventReminder b = reminderMomentsOf(event()).first;

      expect(a.notificationId, b.notificationId);
      expect(a.notificationId, greaterThanOrEqualTo(0));
    });

    test('farklı türler çakışmaz', () {
      final List<EventReminder> moments = reminderMomentsOf(event());
      final Set<int> ids = moments
          .map((EventReminder r) => r.notificationId)
          .toSet();

      expect(ids, hasLength(moments.length));
    });
  });

  group('duyuru hedef kitlesi', () {
    test('öğrenci duyurusu kulübe gitmez', () {
      expect(
        AnnouncementAudience.reaches(
          AnnouncementAudience.students,
          asClub: true,
        ),
        isFalse,
      );
      expect(
        AnnouncementAudience.reaches(
          AnnouncementAudience.students,
          asClub: false,
        ),
        isTrue,
      );
    });

    test('her ikisi seçilirse iki tarafa da gider', () {
      expect(
        AnnouncementAudience.reaches(AnnouncementAudience.all, asClub: true),
        isTrue,
      );
      expect(
        AnnouncementAudience.reaches(AnnouncementAudience.all, asClub: false),
        isTrue,
      );
    });

    test('tanınmayan kitle değeri "herkes" olarak okunur', () {
      final Announcement parsed = Announcement.fromMap('a1', <String, dynamic>{
        'title': 'Duyuru',
        'body': 'Metin',
        'audience': 'bozuk-deger',
      });

      expect(parsed.audience, AnnouncementAudience.all);
    });
  });
}
