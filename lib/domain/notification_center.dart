/// Kulüp > Bildirimler ekranının saf yardımcıları (İP-KN).
///
/// js/modules/club/notification-center.js ile AYNI kurallar:
///   upcoming  henüz başlamamış
///   active    başladı / kapı açık / sürüyor
///   recent    son 7 günde bitti (ya da iptal edildi) — mesaj penceresi
///   old       gösterilmez
library;

import '../models/event.dart';
import 'reminder_schedule.dart';

const int _day = 24 * 60 * 60 * 1000;
const int kMessagingWindowMs = 7 * _day;

enum NotifyStage { upcoming, active, recent, old }

int _pos(int? v) => (v ?? 0) > 0 ? v! : 0;

int notifyEventEndMs(AppEvent e) {
  final int end = _pos(e.eventEndAtMs);
  if (end > 0) return end;
  final int start = _pos(e.eventStartAtMs);
  if (start > 0) return start + 2 * 60 * 60 * 1000;
  final int day = _pos(e.eventDateAtMs) > 0
      ? _pos(e.eventDateAtMs)
      : _pos(e.deadlineAtMs);
  return day > 0 ? day + _day : 0;
}

int notifyEventStartMs(AppEvent e) {
  if (_pos(e.eventStartAtMs) > 0) return e.eventStartAtMs!;
  if (_pos(e.eventDateAtMs) > 0) return e.eventDateAtMs!;
  return _pos(e.deadlineAtMs);
}

NotifyStage notifyStage(AppEvent e, int nowMs) {
  final int end = notifyEventEndMs(e);
  final int start = notifyEventStartMs(e);
  if (e.cancelled) {
    return end > 0 && nowMs - end <= kMessagingWindowMs
        ? NotifyStage.recent
        : NotifyStage.old;
  }
  if (end > 0 && nowMs > end) {
    return nowMs - end <= kMessagingWindowMs
        ? NotifyStage.recent
        : NotifyStage.old;
  }
  final bool open =
      e.entryOpen || e.currentSession > 0 || e.entryStartedAtMs > 0;
  if (open || (start > 0 && nowMs >= start)) return NotifyStage.active;
  return NotifyStage.upcoming;
}

class NotifyGroups {
  const NotifyGroups(this.upcoming, this.active, this.recent);
  final List<AppEvent> upcoming;
  final List<AppEvent> active;
  final List<AppEvent> recent;

  List<AppEvent> of(NotifyStage stage) => switch (stage) {
    NotifyStage.upcoming => upcoming,
    NotifyStage.active => active,
    _ => recent,
  };
}

NotifyGroups groupEventsForNotify(List<AppEvent> events, int nowMs) {
  final List<AppEvent> up = <AppEvent>[];
  final List<AppEvent> act = <AppEvent>[];
  final List<AppEvent> rec = <AppEvent>[];
  for (final AppEvent e in events) {
    switch (notifyStage(e, nowMs)) {
      case NotifyStage.upcoming:
        up.add(e);
      case NotifyStage.active:
        act.add(e);
      case NotifyStage.recent:
        rec.add(e);
      case NotifyStage.old:
        break;
    }
  }
  up.sort(
    (AppEvent a, AppEvent b) =>
        notifyEventStartMs(a).compareTo(notifyEventStartMs(b)),
  );
  act.sort(
    (AppEvent a, AppEvent b) =>
        notifyEventStartMs(a).compareTo(notifyEventStartMs(b)),
  );
  rec.sort(
    (AppEvent a, AppEvent b) =>
        notifyEventEndMs(b).compareTo(notifyEventEndMs(a)),
  );
  return NotifyGroups(up, act, rec);
}

/// Elle gönderilen mesaj kaydı (events/{id}/club_messages).
class ClubMessageRecord {
  const ClubMessageRecord({
    required this.eventId,
    required this.title,
    required this.message,
    required this.audience,
    required this.recipients,
    required this.sentAtMs,
  });
  final String eventId;
  final String title;
  final String message;
  final String audience;
  final int recipients;
  final int sentAtMs;
}

/// "Tüm gönderimler" satırı. [reminderKey] doluysa otomatik bildirimdir.
class SendHistoryItem {
  const SendHistoryItem({
    required this.atMs,
    required this.eventId,
    required this.eventTitle,
    this.reminderKey,
    this.message,
  });
  final int atMs;
  final String eventId;
  final String eventTitle;
  final String? reminderKey;
  final ClubMessageRecord? message;

  bool get isAuto => reminderKey != null;
}

/// type: '' (hepsi) | 'manual' | 'auto'
List<SendHistoryItem> mergeSendHistory(
  List<AppEvent> events,
  List<ClubMessageRecord> messages, {
  String type = '',
}) {
  final Map<String, String> titles = <String, String>{
    for (final AppEvent e in events)
      e.id: e.title.isEmpty ? 'Etkinlik' : e.title,
  };
  final List<SendHistoryItem> out = <SendHistoryItem>[];
  if (type != 'auto') {
    for (final ClubMessageRecord m in messages) {
      out.add(
        SendHistoryItem(
          atMs: m.sentAtMs,
          eventId: m.eventId,
          eventTitle: titles[m.eventId] ?? 'Etkinlik',
          message: m,
        ),
      );
    }
  }
  if (type != 'manual') {
    for (final AppEvent e in events) {
      for (final MapEntry<String, int> sent in e.notificationsSent.entries) {
        final bool known =
            kReminderKeys.contains(sent.key) ||
            sent.key == 'entryOpen' ||
            RegExp(r'^session_\d+$').hasMatch(sent.key);
        if (sent.value > 0 && known) {
          out.add(
            SendHistoryItem(
              atMs: sent.value,
              eventId: e.id,
              eventTitle: titles[e.id]!,
              reminderKey: sent.key,
            ),
          );
        }
      }
    }
  }
  out.sort((SendHistoryItem a, SendHistoryItem b) => b.atMs.compareTo(a.atMs));
  return out;
}
