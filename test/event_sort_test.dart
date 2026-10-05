import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/event_utils.dart';

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
}
