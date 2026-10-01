/// İP-EL: etkinlik linki (regipass.com/e/<kod>) — functions/eventLinks.js karşılığı.
///
/// - Katılımcı: "Paylaş" düğmesi etkinliğin kısa linkini alır (getShareLink).
/// - Organizatör: link, özel ad ve ziyaret/kayıt sayıları (getEventLink).
/// - Uygulama linkle açıldığında kod etkinliğe çözülür (getPublicEvent).
/// Hesapsız (misafir) kayıt formu webde kalır: uygulama o sayfayı
/// `regipass.com/kayit/<kod>?app=1` adresiyle uygulama içi tarayıcıda açar
/// (bu yol uygulama linklerine dahil değildir, uygulamaya geri sıçramaz).
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../app/demo_mode.dart';
import 'firebase_refs.dart';

const String kEventLinkSite =
    kDemoMode ? 'https://demo.regipass.com' : 'https://regipass.com';

/// Oturum açılmadan önce açılan link: giriş bitince bu etkinliğe dönülür.
/// Yalnızca bellekte tutulur; router bir kez tüketir.
String? pendingEventLinkCode;

final RegExp _keyRe = RegExp(r'^[A-Za-z0-9-]{3,60}$');

/// `/e/<kod>` yolundan kodu çıkarır; geçersizse boş.
String eventLinkKeyFromPath(String path) {
  final List<String> parts = path
      .split('/')
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.length < 2 || parts.first != 'e') return '';
  String key;
  try {
    key = Uri.decodeComponent(parts[1]);
  } catch (_) {
    return '';
  }
  return _keyRe.hasMatch(key) ? key : '';
}

String eventLinkUrl(String key) => '$kEventLinkSite/e/$key';

/// Uygulama içi tarayıcıda açılacak misafir kayıt formu.
String eventLinkWebFormUrl(String key) =>
    '$kEventLinkSite/kayit/${Uri.encodeComponent(key)}?app=1';

/// QR afişi (webde yazdırılır).
String eventPosterUrl(String key) =>
    '$kEventLinkSite/afis.html?c=${Uri.encodeComponent(key)}';

/// Linkin herkese açık özeti (kişisel veri içermez).
class PublicLinkEvent {
  const PublicLinkEvent({
    required this.key,
    required this.id,
    required this.title,
    required this.clubId,
    required this.clubName,
    required this.clubLogoUrl,
    required this.imageUrl,
    required this.locationName,
    required this.eventStartAtMs,
    required this.eventDate,
    required this.eventStartTime,
    required this.feeType,
    required this.feeAmount,
    required this.status,
  });

  factory PublicLinkEvent.fromMap(String key, Map<Object?, Object?> m) {
    String s(String k) => m[k] is String ? m[k] as String : '';
    int n(String k) => m[k] is num ? (m[k] as num).toInt() : 0;
    return PublicLinkEvent(
      key: key,
      id: s('id'),
      title: s('title'),
      clubId: s('clubId'),
      clubName: s('clubName'),
      clubLogoUrl: s('clubLogoUrl'),
      imageUrl: s('imageUrl'),
      locationName: s('locationName'),
      eventStartAtMs: n('eventStartAtMs'),
      eventDate: s('eventDate'),
      eventStartTime: s('eventStartTime'),
      feeType: s('feeType'),
      feeAmount: n('feeAmount'),
      status: s('status').isEmpty ? 'open' : s('status'),
    );
  }

  final String key;
  final String id;
  final String title;
  final String clubId;
  final String clubName;
  final String clubLogoUrl;
  final String imageUrl;
  final String locationName;
  final int eventStartAtMs;
  final String eventDate;
  final String eventStartTime;
  final String feeType;
  final int feeAmount;

  /// open | full | closed | started | past | cancelled
  final String status;
}

/// Organizatörün link bilgisi.
class ClubEventLink {
  const ClubEventLink({
    required this.code,
    required this.slug,
    required this.url,
    required this.views,
    required this.registrations,
  });

  factory ClubEventLink.fromMap(Map<Object?, Object?> m) => ClubEventLink(
    code: m['code'] is String ? m['code'] as String : '',
    slug: m['slug'] is String ? m['slug'] as String : '',
    url: m['url'] is String ? m['url'] as String : '',
    views: m['views'] is num ? (m['views'] as num).toInt() : 0,
    registrations: m['registrations'] is num
        ? (m['registrations'] as num).toInt()
        : 0,
  );

  final String code;
  final String slug;
  final String url;
  final int views;
  final int registrations;

  String get key => slug.isNotEmpty ? slug : code;
}

class EventLinkService {
  const EventLinkService();

  Map<Object?, Object?> _map(HttpsCallableResult<Object?> r) =>
      r.data is Map ? r.data! as Map<Object?, Object?> : <Object?, Object?>{};

  Future<PublicLinkEvent> resolve(String key) async {
    final Map<Object?, Object?> data = _map(
      await fbFunctions.httpsCallable('getPublicEvent').call(<String, Object>{
        'code': key,
        'countView': true,
      }),
    );
    final Object? ev = data['event'];
    if (ev is! Map) throw StateError('link-not-found');
    final String resolvedKey = data['key'] is String
        ? data['key'] as String
        : key;
    return PublicLinkEvent.fromMap(resolvedKey, ev.cast<Object?, Object?>());
  }

  Future<String> shareUrl(String eventId) async {
    final Map<Object?, Object?> data = _map(
      await fbFunctions.httpsCallable('getShareLink').call(<String, Object>{
        'eventId': eventId,
      }),
    );
    final String url = data['url'] is String ? data['url'] as String : '';
    if (!url.startsWith('https://')) throw StateError('bad-link');
    return url;
  }

  Future<ClubEventLink> clubLink(String eventId) async => ClubEventLink.fromMap(
    _map(
      await fbFunctions.httpsCallable('getEventLink').call(<String, Object>{
        'eventId': eventId,
      }),
    ),
  );

  Future<String> setSlug(String eventId, String slug) async {
    final Map<Object?, Object?> data = _map(
      await fbFunctions.httpsCallable('setEventLinkSlug').call(
        <String, Object>{'eventId': eventId, 'slug': slug},
      ),
    );
    return data['slug'] is String ? data['slug'] as String : '';
  }
}

/// Sunucunun `details.reason` değeri (yoksa genel hata).
String eventLinkErrorReason(Object error) {
  if (error is FirebaseFunctionsException) {
    final Object? details = error.details;
    if (details is Map && details['reason'] is String) {
      return details['reason'] as String;
    }
  }
  if (error is StateError) return error.message;
  return 'unknown';
}
