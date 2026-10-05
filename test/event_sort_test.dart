import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_utils.dart';
import 'package:regipass/domain/registration_capacity.dart';
import 'package:regipass/domain/session_names.dart';

/// İP-B2: bilet/etkinlik listeleri en yakın tarihe göre (web: event-sort.test.mjs).
void main() {
  final DateTime now = DateTime(2026, 10, 5, 12);
  int at(Duration d) => now.add(d).millisecondsSinceEpoch;

  test('eventSortTime: başlangıç > gün > son başvuru', () {
    expect(eventSortTime(startAtMs: 5, dateAtMs: 3, deadlineAtMs: 1), 5);
    expect(eventSortTime(dateAtMs: 3, deadlineAtMs: 1), 3);
    expect(eventSortTime(deadlineAtMs: 1), 1);
    expect(eventSortTime(), 0);
  });

  test('yaklaşanlar en yakın üstte, geçmiş en yeni önce, tarihsiz sonda', () {
    final Map<String, int> times = <String, int>{
      'gelecek-uzak': at(const Duration(days: 20)),
      'tarihsiz': 0,
      'gecmis-eski': at(const Duration(days: -30)),
      'bugun': at(const Duration(hours: -2)),
      'gecmis-yeni': at(const Duration(days: -3)),
      'yarin': at(const Duration(days: 1)),
    };
    final List<String> keys = times.keys.toList()
      ..sort(
        (String a, String b) => compareByUpcomingEvent(
          timeA: times[a]!,
          timeB: times[b]!,
          now: now,
        ),
      );
    expect(keys, <String>[
      'bugun',
      'yarin',
      'gelecek-uzak',
      'gecmis-yeni',
      'gecmis-eski',
      'tarihsiz',
    ]);
  });

  test('aynı zamanda iki etkinlik: son kaydolunan önce', () {
    final int t = at(const Duration(days: 1));
    expect(
      compareByUpcomingEvent(
        timeA: t,
        timeB: t,
        registeredA: 100,
        registeredB: 200,
        now: now,
      ),
      greaterThan(0),
    );
  });

  test('İP-B4: geç kayıt açıksa ilk oturumda kayıtlar kapanmaz', () {
    expect(
      sessionRegistrationGateAction(
        previousSession: 0,
        nextSession: 1,
        registrationClosed: false,
        closedReason: '',
      ),
      SessionRegistrationGateAction.close,
    );
    expect(
      sessionRegistrationGateAction(
        previousSession: 0,
        nextSession: 1,
        registrationClosed: false,
        closedReason: '',
        allowLateRegistration: true,
      ),
      SessionRegistrationGateAction.none,
    );
  });

  test('İP-B1: oturum saatleri çakışma / sıra / ters saat / aralık', () {
    List<SessionTime> l(List<List<String>> x) => <SessionTime>[
      for (final List<String> p in x) SessionTime(start: p[0], end: p[1]),
    ];
    expect(
      findSessionTimeProblem(l(<List<String>>[<String>['10:00', '11:00'], <String>['11:00', '12:00']])),
      isNull,
    );
    expect(
      findSessionTimeProblem(l(<List<String>>[<String>['10:00', '11:00'], <String>['10:30', '12:00']]))?.code,
      'overlap',
    );
    expect(
      findSessionTimeProblem(l(<List<String>>[<String>['10:00', '09:30']]))?.code,
      'end-before-start',
    );
    expect(
      findSessionTimeProblem(l(<List<String>>[<String>['10:00', ''], <String>['09:00', '']]))?.session,
      2,
    );
    expect(
      findSessionTimeProblem(
        l(<List<String>>[<String>['08:00', '09:00']]),
        eventStart: '09:00',
        eventEnd: '17:00',
      )?.code,
      'before-event',
    );
  });
}
