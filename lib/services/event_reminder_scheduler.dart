/// Etkinlik listesini işletim sistemi alarmlarına çevirir.
///
/// [EventReminderScheduler.sync] her çağrıldığında istenen alarm kümesini
/// yeniden hesaplar: artık gerekmeyenler iptal edilir, değişenler yeniden
/// kurulur, aynı kalanlara dokunulmaz. Böylece etkinlik listesi her
/// tazelendiğinde (kayıt olma, kulübün tarihi güncellemesi, oturum açma)
/// bildirimler kendiliğinden doğru duruma gelir.
library;

import '../domain/event_reminders.dart';
import '../l10n/app_strings.dart';
import '../models/event.dart';
import 'notification_service.dart';

class EventReminderScheduler {
  EventReminderScheduler(this._notifications);

  final NotificationService _notifications;

  /// En son kurulan alarmlar: kimlik -> tetiklenme anı.
  ///
  /// Aynı içerik tekrar kurulmasın diye tutulur. Uygulama yeniden başladığında
  /// boştur; ilk `sync` her şeyi yeniden kurar — `zonedSchedule` aynı kimlikle
  /// çağrıldığında üzerine yazdığı için kopya oluşmaz.
  final Map<int, int> _scheduled = <int, int>{};

  /// Dil değişince metinler de değişmeli; son kullanılan dil takip edilir.
  String? _language;
  ReminderAudience? _audience;

  /// [events] için gereken tüm hatırlatmaları kurar.
  Future<void> sync({
    required List<AppEvent> events,
    required ReminderAudience audience,
    required String language,
  }) async {
    // Dil ya da rol değiştiyse metinler eskidi: hepsi yeniden kurulmalı.
    final bool rebuildAll = _language != language || _audience != audience;
    if (rebuildAll) {
      _language = language;
      _audience = audience;
      _scheduled.clear();
    }

    final List<EventReminder> wanted = remindersForEvents(events);
    final Map<int, EventReminder> byId = <int, EventReminder>{
      for (final EventReminder reminder in wanted)
        reminder.notificationId: reminder,
    };

    // Artık istenmeyen alarmları iptal et. Bekleyenlerin tamamı bu servise
    // aittir: duyurular `show` ile anlık gösterilir, zamanlanmış kuyruğa
    // hiç girmez.
    final Set<int> pending = await _notifications.pendingIds();
    for (final int id in pending) {
      if (byId.containsKey(id)) continue;
      await _notifications.cancel(id);
      _scheduled.remove(id);
    }

    for (final MapEntry<int, EventReminder> entry in byId.entries) {
      final EventReminder reminder = entry.value;
      final int atMs = reminder.at.millisecondsSinceEpoch;

      final bool unchanged =
          _scheduled[entry.key] == atMs && pending.contains(entry.key);
      if (unchanged) continue;

      await _notifications.scheduleAt(
        id: entry.key,
        when: reminder.at,
        title: translate(
          reminderTitleKey(reminder.kind, audience),
          language: language,
        ),
        body: translate(
          reminderBodyKey(reminder.kind, audience),
          params: <String, Object?>{'title': reminder.eventTitle},
          language: language,
        ),
        payload: '${NotificationPayloads.eventReminder}:${reminder.eventId}',
      );

      _scheduled[entry.key] = atMs;
    }
  }

  /// Çıkışta çağrılır: başka bir hesabın etkinlikleri için kurulmuş
  /// hatırlatmalar yeni kullanıcıya gitmemeli.
  Future<void> clear() async {
    _scheduled.clear();
    _language = null;
    _audience = null;
    await _notifications.cancelAll();
  }
}
