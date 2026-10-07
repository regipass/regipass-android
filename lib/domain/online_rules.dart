/// İP-ON (mobil 1.0.13): online etkinlik — saf kurallar.
/// Web: js/modules/events/online-rules.js, sunucu: functions/onlineEvents.js.
library;

import '../models/event.dart';

const int kJoinEarlyMs = 15 * 60 * 1000;
const int kJoinLateMs = 60 * 60 * 1000;
const int _day = 86400000;
const int _trOffsetMs = 3 * 60 * 60 * 1000;

int _dayStartMs(int ms) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms + _trOffsetMs, isUtc: true);
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch - _trOffsetMs;
}

/// "Yayına katıl" penceresi: başlangıçtan 15 dk önce → bitişten 60 dk sonra
/// (bitiş yoksa başlangıç + 3 saat). Saat yoksa etkinlik günü boyunca.
({int opensAtMs, int closesAtMs}) joinWindowOf({int? startMs, int? endMs, int? dayMs}) {
  final int start = startMs ?? 0;
  final int end = endMs ?? 0;
  final int day = dayMs ?? 0;
  if (start > 0) {
    final int close = (end > start ? end : start + 3 * 60 * 60 * 1000) + kJoinLateMs;
    return (opensAtMs: start - kJoinEarlyMs, closesAtMs: close);
  }
  if (day > 0) {
    final int s = _dayStartMs(day);
    return (opensAtMs: s, closesAtMs: s + _day);
  }
  return (opensAtMs: 0, closesAtMs: 1 << 62);
}

({int opensAtMs, int closesAtMs}) eventJoinWindow(AppEvent e) =>
    joinWindowOf(startMs: e.eventStartAtMs, endMs: e.eventEndAtMs, dayMs: e.eventDateAtMs);

/// Açık anlık yoklamanın sırası (yoksa 0).
int onlineCheckpointOpen(AppEvent e, int nowMs) =>
    e.onlineCheckpointOpenIndex >= 1 && e.onlineCheckpointOpenUntilMs > nowMs ? e.onlineCheckpointOpenIndex : 0;

/// Yazılan kod: yalnız rakamlar, tam 6 hane.
String? cleanOnlineCode(String raw) {
  final String digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length == 6 ? digits : null;
}

/// Sunucu nedeni → metin anahtarı.
String onlineJoinErrorKey(String reason) => switch (reason) {
  'join-not-open' => 'online.join.notOpen',
  'join-closed' => 'online.join.closed',
  'not-registered' => 'online.join.notRegistered',
  'link-missing' => 'online.join.linkMissing',
  'payment-pending' => 'registration.status.paymentPendingLong',
  _ => 'online.join.error',
};

String onlineCodeErrorKey(String reason) => switch (reason) {
  'wrong-code' || 'invalid-code' => 'online.code.wrong',
  'checkpoint-closed' || 'plan-feature' => 'online.code.closed',
  'too-many-attempts' => 'online.code.tooMany',
  'not-registered' => 'online.join.notRegistered',
  _ => 'online.join.error',
};
