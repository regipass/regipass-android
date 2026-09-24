/// Sunucudan gelen push bildirimleri (FCM) — İP-6.
///
/// Kişiye özel olaylar (belge geldi, kaydın iptal edildi ...) sunucuda
/// üretilir: kayıt `users/{uid}/inbox`'a yazılır ve bu cihazın jetonuna FCM
/// ile gönderilir. Uygulama kapalıyken bildirimi işletim sistemi gösterir;
/// açıkken:
///   • Android: FCM ön planda bildirim göstermez, [NotificationService.show]
///     ile yerel bildirime çevrilir.
///   • iOS: sistem banner'ı ön planda da gösterir (aşağıdaki sunum ayarı);
///     ikinci kez yerel bildirim üretilmez.
///
/// Dokunulduğunda yük [NotificationService.tappedPayload]'a
/// `personal:<rota>` olarak yazılır; `NotificationSync` rotayı açar.
///
/// Hata olursa uygulama çalışmaya devam eder: push, uygulamanın çalışması
/// için zorunlu değil — gelen kutusu zaten canlı dinleniyor.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/inbox_entry.dart';
import 'device_token_repository.dart';
import 'notification_service.dart';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  DeviceTokenRepository _devices = const DeviceTokenRepository();

  /// Testlerde sahte depo vermek için.
  @visibleForTesting
  set devices(DeviceTokenRepository value) => _devices = value;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  bool _listening = false;
  String? _uid;
  String _language = 'tr';
  StreamSubscription<String>? _tokenRefresh;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// Mesaj dinleyicilerini bir kez kurar.
  Future<void> _listen() async {
    if (_listening) return;
    _listening = true;

    try {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    try {
      final RemoteMessage? initial = await _fcm.getInitialMessage();
      if (initial != null) _onOpened(initial);
    } catch (_) {}
  }

  /// Oturum açmış kullanıcı için cihazı kaydeder (izin + jeton + belge).
  ///
  /// Aynı kullanıcı için tekrar çağrılırsa yalnızca dili günceller.
  Future<void> register({required String uid, required String language}) async {
    final bool sameUser = _uid == uid;
    _uid = uid;
    _language = language;

    try {
      await _listen();

      if (!sameUser) {
        final NotificationSettings settings = await _fcm.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      }

      // iOS'ta FCM jetonu APNs jetonu gelmeden üretilemez; ilk açılışta
      // birkaç saniye gecikebilir.
      if (_isIos && await _waitForApnsToken() == null) return;

      final String? token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;
      await _save(uid, token);

      await _tokenRefresh?.cancel();
      _tokenRefresh = _fcm.onTokenRefresh.listen((String fresh) {
        final String? current = _uid;
        if (current != null) unawaited(_save(current, fresh));
      });
    } catch (error) {
      debugPrint('PushService.register başarısız: $error');
    }
  }

  Future<String?> _waitForApnsToken() async {
    for (int i = 0; i < 5; i++) {
      final String? apns = await _fcm.getAPNSToken();
      if (apns != null) return apns;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<void> _save(String uid, String token) async {
    try {
      await _devices.save(
        uid: uid,
        installId: await DeviceTokenRepository.installId(),
        token: token,
        platform: _isIos ? 'ios' : 'android',
        language: _language,
      );
    } catch (error) {
      debugPrint('Cihaz jetonu kaydedilemedi: $error');
    }
  }

  /// Çıkıştan ÖNCE çağrılır (kural gereği silme için oturum gerekli):
  /// bu cihaz artık o kullanıcının bildirimlerini almasın.
  Future<void> unregister() async {
    final String? uid = _uid;
    _uid = null;
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    if (uid == null) return;

    try {
      await _devices.remove(
        uid: uid,
        installId: await DeviceTokenRepository.installId(),
      );
    } catch (error) {
      debugPrint('Cihaz kaydı silinemedi: $error');
    }
    try {
      await _fcm.deleteToken();
    } catch (_) {}
  }

  void _onForeground(RemoteMessage message) {
    if (_isIos) return; // Sistem zaten gösteriyor.
    final RemoteNotification? n = message.notification;
    if (n == null) return;
    unawaited(
      NotificationService.instance.show(
        id:
            (message.messageId ?? message.data['inboxId'] ?? '').hashCode &
            0x7FFFFFFF,
        title: n.title ?? '',
        body: n.body ?? '',
        channelId: NotificationChannels.personal,
        channelName: NotificationChannels.personalName,
        payload: personalPayload(message.data['route']),
      ),
    );
  }

  void _onOpened(RemoteMessage message) {
    NotificationService.instance.tappedPayload.value = personalPayload(
      message.data['route'],
    );
  }
}

/// `personal:<güvenli rota>` — rota geçersizse yalnızca `personal:`.
String personalPayload(Object? route) =>
    '${NotificationPayloads.personal}:${safeInboxRoute(route is String ? route : '')}';

/// Yükten rotayı çıkarır; kişisel bildirim değilse null.
String? routeFromPersonalPayload(String? payload) {
  const String prefix = '${NotificationPayloads.personal}:';
  if (payload == null || !payload.startsWith(prefix)) return null;
  return safeInboxRoute(payload.substring(prefix.length));
}
