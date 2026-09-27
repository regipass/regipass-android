// İP-KN: kulüp Bildirimler ekranı — web (notification-center.js) ile aynı kurallar.
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/notification_center.dart';
import 'package:regipass/models/event.dart';

const int h = 3600000;
const int d = 24 * h;
final int now = DateTime.utc(2026, 9, 27, 9).millisecondsSinceEpoch;

AppEvent ev(String id, Map<String, dynamic> data) =>
    AppEvent.fromMap(id, <String, dynamic>{'title': id, ...data});

void main() {
  test('sekme: yaklaşan, süren, son 7 gün biten, eski', () {
    expect(
      notifyStage(ev('a', <String, dynamic>{'eventStartAtMs': now + h}), now),
      NotifyStage.upcoming,
    );
    expect(
      notifyStage(
        ev('b', <String, dynamic>{
          'eventStartAtMs': now - h,
          'eventEndAtMs': now + h,
        }),
        now,
      ),
      NotifyStage.active,
    );
    expect(
      notifyStage(
        ev('c', <String, dynamic>{'eventDateAtMs': now + d, 'entryOpen': true}),
        now,
      ),
      NotifyStage.active,
    );
    expect(
      notifyStage(
        ev('d', <String, dynamic>{
          'eventStartAtMs': now - 3 * d,
          'eventEndAtMs': now - 3 * d + h,
        }),
        now,
      ),
      NotifyStage.recent,
    );
    expect(
      notifyStage(
        ev('e', <String, dynamic>{'eventDateAtMs': now - 20 * d}),
        now,
      ),
      NotifyStage.old,
    );
    expect(
      notifyStage(
        ev('f', <String, dynamic>{
          'eventStartAtMs': now + d,
          'cancelled': true,
        }),
        now,
      ),
      NotifyStage.recent,
    );
    expect(
      notifyStage(ev('g', <String, dynamic>{'eventDateAtMs': now - h}), now),
      NotifyStage.active,
    );
  });

  test('gruplama ve sıralama', () {
    final NotifyGroups g = groupEventsForNotify(<AppEvent>[
      ev('b', <String, dynamic>{'eventStartAtMs': now + 5 * d}),
      ev('a', <String, dynamic>{'eventStartAtMs': now + d}),
      ev('old', <String, dynamic>{'eventDateAtMs': now - 30 * d}),
      ev('r1', <String, dynamic>{
        'eventStartAtMs': now - 5 * d,
        'eventEndAtMs': now - 5 * d + h,
      }),
      ev('r2', <String, dynamic>{
        'eventStartAtMs': now - 2 * d,
        'eventEndAtMs': now - 2 * d + h,
      }),
    ], now);
    expect(g.upcoming.map((AppEvent e) => e.id), <String>['a', 'b']);
    expect(g.recent.map((AppEvent e) => e.id), <String>['r2', 'r1']);
    expect(g.active, isEmpty);
  });

  test('tüm gönderimler: elle + otomatik, en yeni önce, tür süzgeci', () {
    final List<AppEvent> events = <AppEvent>[
      ev('e1', <String, dynamic>{
        'title': 'Panel',
        'notificationsSent': <String, dynamic>{
          'dayBefore': now - 2 * d,
          'atStart': now - d,
        },
      }),
    ];
    final List<ClubMessageRecord> msgs = <ClubMessageRecord>[
      ClubMessageRecord(
        eventId: 'e1',
        title: 'Salon',
        message: 'B',
        audience: 'registered',
        recipients: 3,
        sentAtMs: now - (1.5 * d).round(),
      ),
    ];
    final List<SendHistoryItem> all = mergeSendHistory(events, msgs);
    expect(all.map((SendHistoryItem i) => i.isAuto), <bool>[true, false, true]);
    expect(all[1].eventTitle, 'Panel');
    expect(mergeSendHistory(events, msgs, type: 'manual'), hasLength(1));
    expect(mergeSendHistory(events, msgs, type: 'auto'), hasLength(2));
  });
}
