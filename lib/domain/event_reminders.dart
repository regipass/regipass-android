/// Etkinlikten hatırlatma anlarının türetilmesi.
///
/// Saf fonksiyonlar: burada ne Firestore ne de bildirim eklentisi vardır,
/// dolayısıyla kurallar doğrudan test edilebilir. Bildirimleri gerçekten
/// kuran taraf `lib/services/event_reminder_scheduler.dart`.
library;

import '../models/event.dart';

/// Etkinlik başlamadan ne kadar önce hatırlatılacak.
const Duration kEventUpcomingLead = Duration(minutes: 30);

/// Bir hatırlatmanın hangi olaya karşılık geldiği.
enum EventReminderKind {
  /// Başlangıçtan [kEventUpcomingLead] kadar önce — "etkinlik başlıyor".
  upcoming,

  /// Başlangıç anı — "etkinlik başladı".
  started,

  /// Son başvuru anı — "başvurular kapandı".
  deadline,
}

/// Hatırlatmayı kimin aldığı. Metin bu ayrıma göre değişir: öğrenciye
/// "katılmayı unutma", kulübe "girişleri açmaya hazır ol" denir.
enum ReminderAudience { student, club }

/// Tek bir hatırlatma anı.
class EventReminder {
  const EventReminder({
    required this.eventId,
    required this.eventTitle,
    required this.kind,
    required this.at,
  });

  final String eventId;
  final String eventTitle;
  final EventReminderKind kind;
  final DateTime at;

  /// İşletim sistemi alarmının kimliği.
  ///
  /// Aynı etkinlik + aynı tür her zaman aynı sayıyı üretmeli: liste her
  /// tazelendiğinde bildirimler yeniden kurulur ve eski kayıt bu kimlikle
  /// üzerine yazılır. Aksi hâlde kullanıcı aynı etkinlik için birikmiş
  /// kopyalar alırdı.
  ///
  /// `String.hashCode` bilerek kullanılmadı: değeri Dart sürümleri arasında
  /// değişebilir ve uygulama güncellendiğinde eski alarmlar iptal edilemez
  /// hâle gelirdi. Aşağıdaki FNV-1a ise sabittir.
  int get notificationId => _stableId('${kind.name}:$eventId');
}

/// 32 bitlik pozitif tamsayı üretir (Android bildirim kimliği int olmalı).
int _stableId(String value) {
  int hash = 0x811C9DC5;
  for (int i = 0; i < value.length; i++) {
    hash ^= value.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// Etkinliğin başlangıç anı — gün + saat.
///
/// Gün `eventDateAtMs`, saat `eventStartTime` ("HH:mm") alanında tutulur.
/// Saat girilmemiş etkinliklerde başlangıç anı bilinemez; bu durumda `null`
/// döner ve başlangıçla ilgili iki hatırlatma hiç kurulmaz (son başvuru
/// hatırlatması kurulmaya devam eder).
DateTime? eventStartMoment(AppEvent event) {
  final int? dayMs = event.eventDateAtMs;
  if (dayMs == null || dayMs <= 0) return null;

  final DateTime day = DateTime.fromMillisecondsSinceEpoch(dayMs);
  final List<String> parts = event.eventStartTime.split(':');
  if (parts.length < 2) return null;

  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// Etkinliğin son başvuru anı.
DateTime? eventDeadlineMoment(AppEvent event) => event.deadlineAtMs > 0
    ? DateTime.fromMillisecondsSinceEpoch(event.deadlineAtMs)
    : null;

/// Bir etkinliğin tüm hatırlatma anları — zaman filtresi uygulanmadan.
List<EventReminder> reminderMomentsOf(AppEvent event) {
  final List<EventReminder> reminders = <EventReminder>[];

  void add(EventReminderKind kind, DateTime? at) {
    if (at == null) return;
    reminders.add(
      EventReminder(
        eventId: event.id,
        eventTitle: event.title,
        kind: kind,
        at: at,
      ),
    );
  }

  final DateTime? start = eventStartMoment(event);
  if (start != null) {
    add(EventReminderKind.upcoming, start.subtract(kEventUpcomingLead));
    add(EventReminderKind.started, start);
  }

  // Kulüp kayıtları elle kapattıysa "başvurular kapandı" hatırlatmasının
  // konusu kalmaz; tarih geldiğinde kimse yeni başvuru bekliyor olmaz.
  if (!event.registrationClosed) {
    add(EventReminderKind.deadline, eventDeadlineMoment(event));
  }

  return reminders;
}

/// Bir etkinliğin **gelecekteki** hatırlatma anları.
///
/// Geçmişte kalan anlar elenir: alarm kurulamaz (kurulsa anında patlar) ve
/// biten bir etkinlik için "başlıyor" bildirimi göndermek yanlış olur.
List<EventReminder> remindersForEvent(AppEvent event, {DateTime? now}) {
  final DateTime current = now ?? DateTime.now();
  return reminderMomentsOf(
    event,
  ).where((EventReminder r) => r.at.isAfter(current)).toList();
}

/// Zamanı gelmiş — yani kullanıcıya çoktan gönderilmiş — hatırlatmalar.
///
/// Bildirimler sayfasındaki geçmiş bu listeden kurulur. [window] kadar
/// gerisi gösterilir; daha eskisi kullanıcı için değerini yitirmiştir.
List<EventReminder> firedRemindersForEvents(
  Iterable<AppEvent> events, {
  DateTime? now,
  Duration window = const Duration(days: 30),
}) {
  final DateTime current = now ?? DateTime.now();
  final DateTime floor = current.subtract(window);

  return <EventReminder>[
    for (final AppEvent event in events)
      ...reminderMomentsOf(event).where(
        (EventReminder r) => !r.at.isAfter(current) && r.at.isAfter(floor),
      ),
  ]..sort((EventReminder a, EventReminder b) => b.at.compareTo(a.at));
}

/// Birden fazla etkinliğin hatırlatmaları, zamana göre sıralı.
///
/// [limit], işletim sistemi başına kurulabilecek alarm sayısı sınırsız
/// olmadığı için var: iOS aynı anda en fazla 64 bekleyen bildirim tutar,
/// fazlası sessizce düşer. En yakın tarihliler önceliklidir.
List<EventReminder> remindersForEvents(
  Iterable<AppEvent> events, {
  DateTime? now,
  int limit = 48,
}) {
  final List<EventReminder> all = <EventReminder>[
    for (final AppEvent event in events) ...remindersForEvent(event, now: now),
  ]..sort((EventReminder a, EventReminder b) => a.at.compareTo(b.at));

  return all.length <= limit ? all : all.sublist(0, limit);
}

// ── Metinler ──────────────────────────────────────────────────────────
//
// Çeviri anahtarları burada değil, çağıran tarafta çözülür; bu dosya
// anahtarları üretmekle yetinir. Böylece hem bildirim metni hem de
// bildirimler sayfasındaki satır aynı kaynaktan beslenir.

/// `notification.event.<kitle>.<tür>.title`
String reminderTitleKey(EventReminderKind kind, ReminderAudience audience) =>
    'notification.event.${audience.name}.${kind.name}.title';

/// `notification.event.<kitle>.<tür>.body` — `{{title}}` yer tutucusu alır.
String reminderBodyKey(EventReminderKind kind, ReminderAudience audience) =>
    'notification.event.${audience.name}.${kind.name}.body';
