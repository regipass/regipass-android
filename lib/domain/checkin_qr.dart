/// js/modules/events/checkin-qr.js portu.
///
/// QR yükü `EVAPPQR1:` ön eki + base64url(JSON) biçimindedir. Web ile mobil
/// birbirinin QR'ını okuyabilmek zorunda olduğu için bu format aynen korunur.
///
/// ## QR bir ADRES taşır
///
/// Kulübün ekrana bastığı kodların (kapı girişi ve oturum yoklaması) içeriği
/// ham token değil şu adrestir:
///
///     https://eventapp-604a5.web.app/qr.html?t=EVAPPQR1:...
///
/// Sebebi: öğrenci telefonunun **kendi kamera uygulaması** ham metni okuyunca
/// yapacak bir şey bulamaz, yalnızca düz yazı gösterir. Adres olduğunda ise
/// doğrudan açılır. Uygulama içi tarayıcılar (öğrenci ve kulüp ekranları) her
/// iki biçimi de okuyabilsin diye çözümleme [extractCheckinQrToken]'dan geçer.
///
/// Öğrencinin **bileti** (`event-checkin`) bu sarmalamanın dışındadır: onu
/// telefon kamerası değil, kapıdaki görevlinin uygulaması okur. Ham token en
/// küçük ve en hızlı okunan biçimdir.
library;

import 'dart:convert';

const String kCheckinQrPrefix = 'EVAPPQR1:';

/// Telefon kamerasının açacağı sayfanın yolu ve token parametresi.
const String kQrEntryPath = 'qr.html';
const String kQrTokenParam = 't';

/// Mobilde `window.location` yoktur; adres her zaman yayındaki siteye kurulur.
const String kQrPublicBaseUrl = 'https://eventapp-604a5.web.app/';

String _toBase64Url(String text) => base64Url
    .encode(utf8.encode(text))
    .replaceAll(RegExp(r'=+$'), ''); // dolgu atılır

String _fromBase64Url(String encoded) {
  // base64Url.decode dolgu bekler; eksikse tamamlanır.
  final String padded = encoded.padRight((encoded.length + 3) ~/ 4 * 4, '=');
  return utf8.decode(base64Url.decode(padded));
}

/// Yükü QR'a yazılacak token'a çevirir.
String createCheckinQrToken(Map<String, dynamic> payload) =>
    '$kCheckinQrPrefix${_toBase64Url(jsonEncode(payload))}';

/// QR'dan okunan **ham değeri** token'a çevirir. İki biçim de kabul edilir:
///
///   1. `EVAPPQR1:...`                        — doğrudan token
///   2. `https://site/qr.html?t=EVAPPQR1:...` — telefon kamerasının açtığı adres
///
/// Tanımadığı bir değer için `null` döner.
String? extractCheckinQrToken(String? rawValue) {
  if (rawValue == null) return null;

  final String value = rawValue.trim();
  if (value.isEmpty) return null;
  if (value.startsWith(kCheckinQrPrefix)) return value;

  final Uri? uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) return null;

  // Web `t`yi kullanıyor; `token` eski adreslerde kalmış olabilir.
  final String? fromUrl =
      uri.queryParameters[kQrTokenParam] ?? uri.queryParameters['token'];

  return fromUrl != null && fromUrl.startsWith(kCheckinQrPrefix)
      ? fromUrl
      : null;
}

/// Telefon kamerasının açabileceği adres. Kulübün ekrana bastığı QR'a yazılan
/// içerik budur.
String buildCheckinQrUrl(String token) => Uri.parse(kQrPublicBaseUrl)
    .resolve(kQrEntryPath)
    .replace(queryParameters: <String, String>{kQrTokenParam: token})
    .toString();

/// Token'ı çözer. Ham token da adres biçimi de kabul edilir; Regipass kodu
/// değilse veya bozuksa `null` döner.
Map<String, dynamic>? parseCheckinQrToken(String? rawValue) {
  final String? token = extractCheckinQrToken(rawValue);
  if (token == null) return null;

  try {
    final String json = _fromBase64Url(
      token.substring(kCheckinQrPrefix.length),
    );
    final Object? decoded = jsonDecode(json);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// QR görselinin URL'i. Web ile aynı servis kullanılır ki üretilen kod
/// iki platformda birebir aynı olsun.
String buildCheckinQrImageUrl(String data, {int size = 280}) {
  final int sanitized = size.clamp(180, 600);
  // The four-module white quiet zone must survive resizing and saving the
  // image. QRServer otherwise supplies no quiet zone, just a one-pixel margin.
  // Only rendering changes: the encoded URL/token remains byte-for-byte intact.
  return 'https://api.qrserver.com/v1/create-qr-code/'
      '?size=${sanitized}x$sanitized&qzone=4&margin=0'
      '&data=${Uri.encodeComponent(data)}';
}

/// Öğrencinin kapıda görevliye **gösterdiği** statik bilet
/// (js/modules/events/student-ticket.js#buildStudentTicketPayload).
///
/// Kodun küçük kalması taramayı hızlandırır: yalnızca eşleştirme alanları
/// taşınır. Konum **taşınmaz** — QR'ı okutan taraf görevlidir, öğrenci zaten
/// karşısında durmaktadır. Konum yalnızca salondaki oturum QR'ında anlamlıdır,
/// çünkü onu öğrenci kendi telefonuyla okutur.
Map<String, dynamic> buildStudentCheckinPayload({
  required String registrationId,
  required String eventId,
  required String studentId,
}) => <String, dynamic>{
  'v': 1,
  'type': 'event-checkin',
  'registrationId': registrationId,
  'eventId': eventId,
  'studentId': studentId,
};

/// Kulübün ekrana bastığı, öğrencilerin okuttuğu paylaşılan oturum QR yükü.
/// (club-events.js#paintSessionQr)
///
/// [slot] üretim anının 20 saniyelik dilimidir; okuyan taraf buna bakarak eski
/// bir ekran görüntüsünü reddeder (bkz. `session_qr_window.dart`).
///
/// Konum alanları isteğe bağlıdır. Konumsuz etkinlikte alanlar hiç yazılmaz;
/// token türü, sürümü, oturum dilimi ve onu URL'ye saran algoritma aynen
/// kalır. Konumlu QR'ların yükü ise değişmeden korunur.
Map<String, dynamic> buildSessionCheckinPayload({
  required String eventId,
  required int session,
  required int slot,
  double? locationLat,
  double? locationLng,
  int? locationRadius,
}) => <String, dynamic>{
  'v': 1,
  'type': 'session-checkin',
  'eventId': eventId,
  'session': session,
  'slot': slot,
  ...?_qrLocationPayload(locationLat, locationLng, locationRadius),
};

/// Kapıda gösterilen ortak giriş QR'ı. Öğrenci kendi telefonuyla okutur;
/// kimlik QR'ın içinde değil, oturumdaki kayıt belgesinden alınır.
///
/// Dilim taşımaz: kapı kodunun sınırı tazelik değil, kulübün kapıyı açık
/// tutmasıdır (`events.entryOpen`).
Map<String, dynamic> buildEventEntryPayload({
  required String eventId,
  double? locationLat,
  double? locationLng,
  int? locationRadius,
}) => <String, dynamic>{
  'v': 1,
  'type': 'event-entry',
  'eventId': eventId,
  ...?_qrLocationPayload(locationLat, locationLng, locationRadius),
};

/// Konum tamamen yoksa alanları hiç ekleme. Böylece konumsuz QR'lar eski
/// payload/URL biçimini korur; konumlu QR'ların alan sırası da değişmez.
Map<String, dynamic>? _qrLocationPayload(
  double? locationLat,
  double? locationLng,
  int? locationRadius,
) {
  if (locationLat == null || locationLng == null) return null;
  return <String, dynamic>{
    'locationLat': locationLat,
    'locationLng': locationLng,
    'locationRadius': ?locationRadius,
  };
}
