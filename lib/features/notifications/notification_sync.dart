/// Uygulama ağacının tepesinde duran, görünmeyen köprü.
///
/// Üç işi yapar:
///   1. Kullanıcı bir panele girdiğinde bildirim iznini bir kez ister,
///   2. Etkinlik listesi değiştikçe hatırlatma alarmlarını günceller,
///   3. Yeni bir duyuru geldiğinde onu cihaz bildirimine çevirir.
///
/// Widget olması bilinçli: Riverpod dinleyicilerinin ömrü ağaca bağlı ve
/// bildirime dokununca sayfayı açmak yönlendiriciye erişim istiyor.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../domain/event_reminders.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/announcement.dart';
import '../../models/event.dart';
import '../../services/notification_service.dart';
import '../../state/providers.dart';
import 'notification_providers.dart';

class NotificationSync extends ConsumerStatefulWidget {
  const NotificationSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<NotificationSync> {
  /// İzin bu oturumda hangi kullanıcı için istendi. Kullanıcı reddederse
  /// aynı açılışta tekrar sorulmaz — sistem zaten ikinci kez göstermez.
  String? _permissionAskedFor;

  /// Son kurulan alarm kümesinin parmak izi. Aynı liste yeniden çizildiğinde
  /// (her `build`de olur) platform kanalına gereksiz çağrı gitmesin diye.
  String? _lastSyncSignature;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.tappedPayload.addListener(_onNotificationTap);
  }

  @override
  void dispose() {
    NotificationService.instance.tappedPayload.removeListener(
      _onNotificationTap,
    );
    super.dispose();
  }

  /// Bildirime dokunulunca kullanıcıyı bildirimler sayfasına götürür.
  void _onNotificationTap() {
    final String? payload = NotificationService.instance.tappedPayload.value;
    if (payload == null || !mounted) return;

    // Aynı yükün ikinci kez işlenmemesi için tüketiliyor.
    NotificationService.instance.tappedPayload.value = null;

    final ReminderAudience? audience = ref.read(notificationAudienceProvider);
    if (audience == null) return;

    ref
        .read(routerProvider)
        .push(
          audience == ReminderAudience.club
              ? Routes.clubNotifications
              : Routes.studentNotifications,
        );
  }

  /// İzin isteme: panele girmiş (rolü çözülmüş) her kullanıcı için bir kez.
  void _ensurePermission(String? uid, ReminderAudience? audience) {
    if (uid == null || audience == null || _permissionAskedFor == uid) return;
    _permissionAskedFor = uid;
    unawaited(NotificationService.instance.requestPermission());
  }

  /// Alarm kurulumunu tetikleyen veri değişti mi?
  ///
  /// Yalnızca hatırlatma anını etkileyen alanlara bakılır; başlık da metne
  /// girdiği için o da dahil.
  String _signatureOf(
    List<AppEvent> events,
    ReminderAudience audience,
    String language,
  ) => <String>[
    audience.name,
    language,
    for (final AppEvent e in events)
      '${e.id}|${e.eventDateAtMs}|${e.eventStartTime}|${e.deadlineAtMs}'
          '|${e.registrationClosed}|${e.title}',
  ].join(';');

  void _syncReminders(
    List<AppEvent> events,
    ReminderAudience? audience,
    String language,
  ) {
    if (audience == null) return;

    final String signature = _signatureOf(events, audience, language);
    if (signature == _lastSyncSignature) return;
    _lastSyncSignature = signature;

    unawaited(
      ref
          .read(eventReminderSchedulerProvider)
          .sync(events: events, audience: audience, language: language),
    );
  }

  /// Yeni duyuruyu cihaz bildirimine çevirir.
  ///
  /// "Yeni"nin ölçüsü cihazda saklanan son bildirim damgası: uygulama her
  /// açıldığında dinleyici tüm duyuruları baştan verir, damga olmasa
  /// kullanıcı eski duyuruları tekrar tekrar alırdı.
  Future<void> _pushNewAnnouncements(
    String uid,
    List<Announcement> announcements,
  ) async {
    if (announcements.isEmpty) return;

    final int lastNotified = ref
        .read(notificationReadStoreProvider)
        .lastNotifiedAtMs(uid);

    // Liste yeniden eskiye sıralı (bkz. AnnouncementRepository).
    final int newest = announcements.first.createdAtMs;

    // İlk kurulumda (damga yok) geçmiş duyuruların tamamı bildirime
    // dönüşmemeli; yalnızca damga yazılıp sessizce geçilir.
    if (lastNotified == 0) {
      await ref.read(notificationReadStoreProvider).markNotified(uid, newest);
      return;
    }

    final List<Announcement> fresh = announcements
        .where((Announcement a) => a.createdAtMs > lastNotified)
        .toList();
    if (fresh.isEmpty) return;

    for (final Announcement a in fresh) {
      await NotificationService.instance.show(
        // Belge kimliğinden türeyen sabit sayı: aynı duyuru iki kez
        // gösterilse bile bildirim çoğalmaz, üzerine yazar.
        id: a.id.hashCode & 0x7FFFFFFF,
        title: a.title,
        body: a.body,
        payload: '${NotificationPayloads.announcement}:${a.id}',
      );
    }

    await ref.read(notificationReadStoreProvider).markNotified(uid, newest);
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = ref.watch(currentUidProvider);
    final ReminderAudience? audience = ref.watch(notificationAudienceProvider);

    _ensurePermission(uid, audience);
    _syncReminders(
      ref.watch(reminderSourceEventsProvider),
      audience,
      ref.watch(languageProvider),
    );

    // ── Duyurular ───────────────────────────────────────────────────
    ref.listen<AsyncValue<List<Announcement>>>(myAnnouncementsProvider, (
      AsyncValue<List<Announcement>>? _,
      AsyncValue<List<Announcement>> next,
    ) {
      final List<Announcement>? list = next.value;
      final String? currentUid = ref.read(currentUidProvider);
      if (list == null || currentUid == null) return;
      unawaited(_pushNewAnnouncements(currentUid, list));
    });

    // ── Hesap değişimi ──────────────────────────────────────────────
    // Önceki kullanıcının etkinlikleri için kurulmuş alarmlar yenisine
    // gitmemeli.
    ref.listen<String?>(currentUidProvider, (String? previous, String? next) {
      if (previous == null || previous == next) return;
      _permissionAskedFor = null;
      _lastSyncSignature = null;
      unawaited(ref.read(eventReminderSchedulerProvider).clear());
    });

    return widget.child;
  }
}
