// İP-B: mobil zamanlama sunucuyla aynı (functions/eventReminders.test.js).
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/reminder_schedule.dart';

void main() {
  const int h = 3600000;
  final int start = DateTime.utc(2026, 9, 30, 11).millisecondsSinceEpoch;
  final int day = DateTime.utc(2026, 9, 29, 21).millisecondsSinceEpoch;

  test('1 gün önce 19:00, 1 saat önce, başlangıç, bitiş + 30 dk', () {
    final Map<String, int?> s = reminderSchedule(
      eventDateAtMs: day,
      eventStartAtMs: start,
      eventEndAtMs: start + 2 * h,
    );
    expect(
      s['dayBefore'],
      DateTime.utc(2026, 9, 29, 16).millisecondsSinceEpoch,
    );
    expect(s['hourBefore'], start - h);
    expect(s['atStart'], start);
    expect(s['afterEnd'], start + 2 * h + 30 * 60000);
  });

  test('gece biten etkinliğin teşekkürü ertesi sabah 09:00', () {
    final Map<String, int?> s = reminderSchedule(
      eventDateAtMs: day,
      eventStartAtMs: start,
      eventEndAtMs: DateTime.utc(2026, 9, 30, 20).millisecondsSinceEpoch,
    );
    expect(s['afterEnd'], DateTime.utc(2026, 10, 1, 6).millisecondsSinceEpoch);
  });

  test('saatsiz etkinlik ve kapatılan anlar', () {
    final Map<String, int?> s = reminderSchedule(
      eventDateAtMs: day,
      eventStartAtMs: null,
      eventEndAtMs: null,
    );
    expect(s['dayBefore'], isNotNull);
    expect(s['hourBefore'], isNull);
    final List<ReminderState> states = reminderStates(
      eventDateAtMs: day,
      eventStartAtMs: start,
      eventEndAtMs: start + 2 * h,
      cancelled: false,
      flags: const <String, bool>{'afterEnd': false},
      sent: const <String, int>{'dayBefore': 1},
      nowMs: start - 30 * 60000,
    );
    expect(states.map((ReminderState s) => s.status).toList(), <ReminderStatus>[
      ReminderStatus.sent,
      ReminderStatus.missed,
      ReminderStatus.pending,
      ReminderStatus.off,
    ]);
  });
}
