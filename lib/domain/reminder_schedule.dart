/// Otomatik etkinlik bildirimlerinin zamanı (İP-B) —
/// functions/eventReminders.js#reminderSchedule ve
/// js/modules/events/reminder-schedule.js ile AYNI hesap.
library;

const int _trOffsetMs = 3 * 60 * 60 * 1000;
const int _hour = 60 * 60 * 1000;
const int _day = 24 * _hour;

const List<String> kReminderKeys = <String>[
  'dayBefore',
  'hourBefore',
  'atStart',
  'afterEnd',
];

int _trDayIndex(int ms) => ((ms + _trOffsetMs) / _day).floor();
int _trMidnight(int day) => day * _day - _trOffsetMs;
int _trHour(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms + _trOffsetMs, isUtc: true).hour;

/// Her anın zamanı (kapalıysa ya da saat yoksa null).
Map<String, int?> reminderSchedule({
  required int? eventDateAtMs,
  required int? eventStartAtMs,
  required int? eventEndAtMs,
  Map<String, bool> flags = const <String, bool>{},
}) {
  final int start = eventStartAtMs ?? 0;
  final int endRaw = eventEndAtMs ?? 0;
  final int end = endRaw > start ? endRaw : 0;
  final int day = (eventDateAtMs ?? 0) > 0 ? eventDateAtMs! : start;
  bool on(String key) => flags[key] != false;
  final Map<String, int?> s = <String, int?>{
    'dayBefore': null,
    'hourBefore': null,
    'atStart': null,
    'afterEnd': null,
  };
  if (day > 0 && on('dayBefore')) {
    s['dayBefore'] = _trMidnight(_trDayIndex(day) - 1) + 19 * _hour;
  }
  if (start > 0 && on('hourBefore')) s['hourBefore'] = start - _hour;
  if (start > 0 && on('atStart')) s['atStart'] = start;
  if (end > 0 && on('afterEnd')) {
    int at = end + 30 * 60 * 1000;
    final int h = _trHour(at);
    if (h >= 23) {
      at = _trMidnight(_trDayIndex(at) + 1) + 9 * _hour;
    } else if (h < 8) {
      at = _trMidnight(_trDayIndex(at)) + 9 * _hour;
    }
    s['afterEnd'] = at;
  }
  final int? dayBefore = s['dayBefore'];
  if (dayBefore != null && start > 0 && dayBefore >= start - _hour) {
    s['dayBefore'] = null;
  }
  return s;
}

enum ReminderStatus { off, sent, pending, missed }

class ReminderState {
  const ReminderState(this.key, this.status, this.atMs, this.sentAtMs);

  final String key;
  final ReminderStatus status;
  final int? atMs;
  final int? sentAtMs;
}

List<ReminderState> reminderStates({
  required int? eventDateAtMs,
  required int? eventStartAtMs,
  required int? eventEndAtMs,
  required bool cancelled,
  Map<String, bool> flags = const <String, bool>{},
  Map<String, int> sent = const <String, int>{},
  required int nowMs,
}) {
  final Map<String, int?> s = reminderSchedule(
    eventDateAtMs: eventDateAtMs,
    eventStartAtMs: eventStartAtMs,
    eventEndAtMs: eventEndAtMs,
    flags: flags,
  );
  return kReminderKeys.map((String key) {
    final int? at = s[key];
    // Kulüp girişi / ilk oturumu açınca "Başladı" o an gider
    // (functions/eventReminders.js#progressNotices).
    int? sentAt = (sent[key] ?? 0) > 0 ? sent[key] : null;
    if (sentAt == null && key == 'atStart') {
      final int alt = (sent['entryOpen'] ?? 0) > 0
          ? sent['entryOpen']!
          : (sent['session_1'] ?? 0);
      if (alt > 0) sentAt = alt;
    }
    ReminderStatus status = ReminderStatus.off;
    if (sentAt != null) {
      status = ReminderStatus.sent;
    } else if (at != null && !cancelled) {
      status = at > nowMs ? ReminderStatus.pending : ReminderStatus.missed;
    }
    return ReminderState(key, status, at, sentAt);
  }).toList();
}
