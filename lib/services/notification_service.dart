/// Cihaz bildirimleri — tek noktadan erişim.
///
/// Uygulamanın bir sunucu tarafı (Cloud Functions) yok; bu yüzden bildirimler
/// FCM ile değil, **cihaz üzerinde** üretilir:
///
///   • Etkinlik hatırlatmaları (`zonedSchedule`) uygulama kapalıyken de
///     çalışır — işletim sistemi alarmı tutar.
///   • Yönetici duyuruları Firestore'a yazılır; istemci dinleyicisi yeni
///     duyuruyu gördüğü anda [show] ile cihaz bildirimine çevirir.
///
/// Her iki yol da aynı kanalları kullanır: sesli + titreşimli ve
/// `Importance.max` (Android'de ekranın üstünde beliren "heads-up" uyarı).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Android bildirim kanalları.
///
/// Kanal ayarları (ses, titreşim, önem) Android'de **ilk oluşturulduğunda**
/// sabitlenir; sonradan koddan değiştirilemez. Ayar değiştirmek gerekirse
/// kanal kimliğinin sonundaki sürüm numarası artırılmalıdır — aksi hâlde
/// güncelleme yükleyen kullanıcıda eski ayar yaşamaya devam eder.
class NotificationChannels {
  static const String eventReminders = 'regipass_event_reminders_v1';
  static const String announcements = 'regipass_announcements_v1';
}

/// Bildirime dokunulduğunda taşınan yük türleri.
class NotificationPayloads {
  static const String announcement = 'announcement';
  static const String eventReminder = 'event';
}

/// Titreşim deseni: bekle-titre-bekle-titre (ms).
final Int64List _vibrationPattern = Int64List.fromList(<int>[0, 400, 250, 400]);

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Bildirime dokunulduğunda dolar. `RegipassApp` bunu dinleyip kullanıcıyı
  /// bildirimler sayfasına götürür.
  final ValueNotifier<String?> tappedPayload = ValueNotifier<String?>(null);

  bool _initialized = false;

  /// Android 14+ üzerinde kullanıcı "tam zamanlı alarm" iznini vermediyse
  /// dakika hassasiyetli zamanlama yapılamaz; bu durumda yaklaşık zamanlamaya
  /// düşülür (bildirim birkaç dakika gecikebilir ama kaybolmaz).
  bool _exactAlarmsAllowed = true;

  bool get isInitialized => _initialized;

  // ── Kurulum ───────────────────────────────────────────────────────────

  /// Eklentiyi, saat dilimi veritabanını ve kanalları hazırlar.
  ///
  /// Açılışta çağrılır; ikinci çağrılar sessizce yok sayılır. Hata durumunda
  /// uygulama açılmaya devam eder — bildirim, uygulamanın çalışması için
  /// zorunlu bir yetenek değil.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await _initTimeZone();

      await _plugin.initialize(
        settings: const InitializationSettings(
          // Uygulama simgesi DEĞİL: Android 5'ten beri bildirim simgesinin
          // yalnızca alfa kanalı kullanılıyor, renk atılıyor. Kenardan
          // kenara opak olan `ic_launcher` bu işlemden dolu beyaz bir kare
          // olarak çıkıyordu. `ic_notification` aynı işaretin şeffaf zeminli,
          // ortalanmış karşılığı (bkz. drawable/ic_notification.xml).
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          // İzin açılışta DEĞİL, kullanıcı panele girdiğinde isteniyor
          // (bkz. [requestPermission]) — ilk karede çıkan izin kutusu
          // bağlamsız kalıyor ve daha sık reddediliyor.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );

      await _createAndroidChannels();
      _initialized = true;
    } catch (error, stack) {
      debugPrint('NotificationService.init başarısız: $error\n$stack');
    }
  }

  /// `zonedSchedule` yerel saat dilimini bilmek zorunda: cihaz İstanbul'da,
  /// veritabanı UTC'de tutuyor. Cihazın saat dilimi okunamazsa Türkiye'ye
  /// düşülür — kullanıcı kitlesinin tamamı orada.
  Future<void> _initTimeZone() async {
    tzdata.initializeTimeZones();

    String name = 'Europe/Istanbul';
    try {
      name = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      // Varsayılanla devam.
    }

    try {
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }
  }

  Future<void> _createAndroidChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        NotificationChannels.eventReminders,
        'Etkinlik hatırlatmaları',
        description:
            'Etkinlik başlamadan önce, başladığında ve başvurular '
            'kapandığında gönderilen hatırlatmalar.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
      ),
    );

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        NotificationChannels.announcements,
        'Duyurular',
        description: 'Regipass yönetiminden gelen duyurular.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
      ),
    );
  }

  // ── İzinler ───────────────────────────────────────────────────────────

  /// Bildirim iznini ister ve sonucu döndürür.
  ///
  /// Android 13+ ve iOS'ta izin kutusu çıkar; daha eski Android'de izin
  /// zaten kurulumla verilmiş sayılır. Ayrıca Android 14+ üzerinde tam
  /// zamanlı alarm izni de burada istenir: bu izin olmadan "yarım saat önce"
  /// hatırlatması dakika hassasiyetini kaybeder.
  Future<bool> requestPermission() async {
    if (!_initialized) await init();

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final bool granted = await android.requestNotificationsPermission() ?? false;

      // Reddedilse bile alarm iznini sormaya çalışmıyoruz; bildirim
      // gösterilemeyecekse zamanlamanın da anlamı yok.
      if (granted) await _ensureExactAlarms(android);
      return granted;
    }

    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return false;
  }

  Future<void> _ensureExactAlarms(
    AndroidFlutterLocalNotificationsPlugin android,
  ) async {
    _exactAlarmsAllowed = await android.canScheduleExactNotifications() ?? true;
    if (_exactAlarmsAllowed) return;

    // Kullanıcıyı sistem ayarına götürür. Dönen değer "ayar ekranı açıldı mı"
    // bilgisidir, izin verilip verilmediği bir sonraki kontrolde anlaşılır.
    await android.requestExactAlarmsPermission();
    _exactAlarmsAllowed = await android.canScheduleExactNotifications() ?? false;
  }

  /// Kullanıcı bildirimleri sistem ayarlarından kapatmış olabilir.
  Future<bool> areEnabled() async {
    if (!_initialized) await init();

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) return await android.areNotificationsEnabled() ?? false;
    return true;
  }

  /// Uygulamanın sistem bildirim ayarları ekranını açar.
  Future<void> openSystemSettings() => _plugin.openAppNotificationSettings();

  // ── Gösterim ──────────────────────────────────────────────────────────

  NotificationDetails _details(String channelId, String channelName) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          // `Importance.max` + `Priority.high`: bildirim ekranın üstünde
          // kısa süreliğine belirir (heads-up). Yalnızca biri verilirse
          // Android sürümlerinin bir kısmında yalnızca çubuğa düşer.
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _vibrationPattern,
          category: AndroidNotificationCategory.event,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // Uygulama ön plandayken de banner çıksın.
          presentBanner: true,
          // `active`: bildirim anında gösterilir, ekran yanar, ses çalar.
          // Bir üst seviye olan `timeSensitive` bilerek kullanılmadı —
          // Xcode'da "Time Sensitive Notifications" yetkisi tanımlanmadan
          // iOS onu sessizce `active` gibi işler.
          interruptionLevel: InterruptionLevel.active,
        ),
      );

  /// Bildirimi hemen gösterir (yönetici duyuruları bu yolu kullanır).
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String channelId = NotificationChannels.announcements,
    String channelName = 'Duyurular',
    String? payload,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(channelId, channelName),
        payload: payload,
      );
    } catch (error) {
      debugPrint('NotificationService.show başarısız: $error');
    }
  }

  /// Bildirimi ileri bir tarihe kurar.
  ///
  /// Geçmiş bir tarih verilirse hiçbir şey yapmaz — `zonedSchedule` geçmiş
  /// tarihte bildirimi anında patlatır ve kullanıcı, biten bir etkinlik için
  /// "başlıyor" uyarısı alırdı.
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String channelId = NotificationChannels.eventReminders,
    String channelName = 'Etkinlik hatırlatmaları',
    String? payload,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    final tz.TZDateTime target = tz.TZDateTime.from(when, tz.local);
    if (!target.isAfter(tz.TZDateTime.now(tz.local))) return;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: target,
        notificationDetails: _details(channelId, channelName),
        androidScheduleMode: _exactAlarmsAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (error) {
      debugPrint('NotificationService.scheduleAt başarısız ($id): $error');
    }
  }

  /// Kurulu ama henüz patlamamış bildirimlerin kimlikleri.
  Future<Set<int>> pendingIds() async {
    if (!_initialized) return <int>{};
    try {
      final List<PendingNotificationRequest> pending = await _plugin
          .pendingNotificationRequests();
      return pending.map((PendingNotificationRequest r) => r.id).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<void> cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Zaten yoksa sorun değil.
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Yok sayılır.
    }
  }

  void _onTap(NotificationResponse response) {
    tappedPayload.value = response.payload;
  }
}
