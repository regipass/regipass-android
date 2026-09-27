/// Etkinlik değerlendirmesi (İP-D) — saf kurallar.
/// Web: js/modules/feedback/feedback-core.js; sunucu: functions/eventFeedback.js
/// (+ eventReminders.js#eventEndAnchor). Asıl denetim sunucuda.
library;

import '../models/event.dart';

const int _hour = 60 * 60 * 1000;
const int _day = 24 * _hour;
const int _trOffset = 3 * _hour;
const int feedbackWindowMs = 14 * _day;
const int maxFeedbackComment = 500;
const int feedbackMinForComments = 3;

int _ms(int? value) {
  final int n = value ?? 0;
  if (n <= 0) return 0;
  return n >= 1000000000 && n < 100000000000 ? n * 1000 : n;
}

/// Etkinliğin "bitti" sayıldığı an: bitiş → başlangıç + 3 saat → gün 20:00 (TR).
int eventEndAnchorMs({int? startMs, int? endMs, int? dayMs}) {
  final int start = _ms(startMs);
  final int endRaw = _ms(endMs);
  final int end = endRaw > start ? endRaw : 0;
  final int day = _ms(dayMs) != 0 ? _ms(dayMs) : start;
  if (end != 0) return end;
  if (start != 0) return start + 3 * _hour;
  if (day != 0) {
    final int dayIndex = ((day + _trOffset) / _day).floor();
    return dayIndex * _day - _trOffset + 20 * _hour;
  }
  return 0;
}

int eventEndAnchorOf(AppEvent event) => eventEndAnchorMs(
  startMs: event.eventStartAtMs,
  endMs: event.eventEndAtMs,
  dayMs: event.eventDateAtMs,
);

/// Etkinlik bitti mi (kulüp oturumları tamamladıysa da biter).
bool eventFeedbackEnded(AppEvent event, int nowMs) {
  final int anchor = eventEndAnchorOf(event);
  return event.sessionsCompleted || (anchor > 0 && nowMs >= anchor);
}

class FeedbackWindow {
  const FeedbackWindow({
    required this.ok,
    required this.reason,
    required this.opensAtMs,
    required this.closesAtMs,
  });

  final bool ok;
  final String reason;
  final int opensAtMs;
  final int closesAtMs;
}

/// Değerlendirme penceresi. [checkedIn]: kapıdan giriş ya da oturum yoklaması.
FeedbackWindow feedbackWindow({
  required int anchorMs,
  required bool sessionsCompleted,
  required bool cancelled,
  required bool registered,
  required bool checkedIn,
  required int nowMs,
  bool eventExists = true,
}) {
  final bool ended = sessionsCompleted || (anchorMs > 0 && nowMs >= anchorMs);
  final int closes = anchorMs > 0 ? anchorMs + feedbackWindowMs : 0;
  FeedbackWindow out(bool ok, [String reason = '']) => FeedbackWindow(
    ok: ok,
    reason: reason,
    opensAtMs: anchorMs,
    closesAtMs: closes,
  );
  if (!eventExists) return out(false, 'event-not-found');
  if (cancelled) return out(false, 'event-cancelled');
  if (!registered) return out(false, 'not-registered');
  if (!checkedIn) return out(false, 'not-checked-in');
  if (!ended) return out(false, 'event-not-finished');
  if (closes > 0 && nowMs > closes) return out(false, 'feedback-closed');
  return out(true);
}

bool registrationAttended(EventRegistration reg) =>
    reg.isCheckedIn || reg.sessionsAttended > 0 || reg.lastAttendedSession > 0;

FeedbackWindow feedbackWindowFor(
  AppEvent? event,
  EventRegistration? reg,
  int nowMs,
) => feedbackWindow(
  anchorMs: event == null ? 0 : eventEndAnchorOf(event),
  sessionsCompleted: event?.sessionsCompleted ?? false,
  cancelled: event?.cancelled ?? false,
  registered: reg != null,
  checkedIn: reg != null && registrationAttended(reg),
  nowMs: nowMs,
  eventExists: event != null,
);

/// Öğrencinin kendi değerlendirmesi (listMyFeedback).
class MyFeedback {
  const MyFeedback({
    required this.eventId,
    required this.rating,
    required this.comment,
    required this.updatedAtMs,
  });

  factory MyFeedback.fromMap(Map<Object?, Object?> map) {
    final Object? r = map['rating'];
    final Object? at = map['updatedAtMs'];
    return MyFeedback(
      eventId: map['eventId'] is String ? map['eventId'] as String : '',
      rating: r is num ? r.toInt() : 0,
      comment: map['comment'] is String ? map['comment'] as String : '',
      updatedAtMs: at is num ? at.toInt() : 0,
    );
  }

  final String eventId;
  final int rating;
  final String comment;
  final int updatedAtMs;
}

enum FeedbackBadge { none, rate, rated }

FeedbackBadge feedbackBadge(FeedbackWindow window, MyFeedback? mine) {
  if (mine != null && mine.rating > 0) return FeedbackBadge.rated;
  return window.ok ? FeedbackBadge.rate : FeedbackBadge.none;
}

String starText(num rating) {
  final int n = rating.round().clamp(0, 5);
  return '${'★' * n}${'☆' * (5 - n)}';
}

/// Kulübe gelen kimliksiz özet (clubEventFeedback).
class FeedbackSummary {
  const FeedbackSummary({
    required this.count,
    required this.average,
    required this.distribution,
    required this.comments,
    required this.commentsHidden,
    required this.minForComments,
  });

  factory FeedbackSummary.fromMap(Map<Object?, Object?> map) {
    final Object? dist = map['distribution'];
    final Object? comments = map['comments'];
    final Object? avg = map['average'];
    final Object? count = map['count'];
    final Object? min = map['minForComments'];
    return FeedbackSummary(
      count: count is num ? count.toInt() : 0,
      average: avg is num ? avg.toDouble() : 0,
      distribution: dist is List
          ? <int>[
              for (int i = 0; i < 5; i++)
                i < dist.length && dist[i] is num
                    ? (dist[i] as num).toInt()
                    : 0,
            ]
          : const <int>[0, 0, 0, 0, 0],
      comments: comments is List
          ? comments
                .whereType<Map<Object?, Object?>>()
                .map(
                  (Map<Object?, Object?> c) => (
                    rating: c['rating'] is num
                        ? (c['rating'] as num).toInt()
                        : 0,
                    comment: c['comment'] is String
                        ? c['comment'] as String
                        : '',
                  ),
                )
                .toList(growable: false)
          : const <({int rating, String comment})>[],
      commentsHidden: map['commentsHidden'] == true,
      minForComments: min is num ? min.toInt() : feedbackMinForComments,
    );
  }

  final int count;
  final double average;
  final List<int> distribution;
  final List<({int rating, String comment})> comments;
  final bool commentsHidden;
  final int minForComments;

  /// 5 → 1 sırasıyla (yıldız, adet, yüzde).
  List<({int stars, int count, int percent})> get rows =>
      <({int stars, int count, int percent})>[
        for (final int stars in <int>[5, 4, 3, 2, 1])
          (
            stars: stars,
            count: distribution[stars - 1],
            percent: count == 0
                ? 0
                : (distribution[stars - 1] * 100 / count).round(),
          ),
      ];
}

String feedbackErrorKey(String reason) => switch (reason) {
  'not-checked-in' || 'not-registered' => 'feedback.error.notCheckedIn',
  'event-not-finished' => 'feedback.error.notFinished',
  'feedback-closed' => 'feedback.error.closed',
  'event-cancelled' => 'feedback.error.cancelled',
  'bad-rating' => 'feedback.error.badRating',
  'account-banned' => 'feedback.error.banned',
  'not-event-club' => 'feedback.error.notOwner',
  _ => 'feedback.error.generic',
};
