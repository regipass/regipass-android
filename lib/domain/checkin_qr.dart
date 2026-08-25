/// js/modules/events/checkin-qr.js portu.
///
/// QR yükü `EVAPPQR1:` ön eki + base64url(JSON) biçimindedir. Web ile mobil
/// birbirinin QR'ını okuyabilmek zorunda olduğu için bu format aynen korunur.
library;

import 'dart:convert';

const String kCheckinQrPrefix = 'EVAPPQR1:';

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

/// Token'ı çözer. Regipass token'ı değilse veya bozuksa `null` döner.
Map<String, dynamic>? parseCheckinQrToken(String? token) {
  if (token == null || !token.startsWith(kCheckinQrPrefix)) return null;

  try {
    final String json = _fromBase64Url(token.substring(kCheckinQrPrefix.length));
    final Object? decoded = jsonDecode(json);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// QR görselinin URL'i. Web ile aynı servis kullanılır ki üretilen kod
/// iki platformda birebir aynı olsun.
String buildCheckinQrImageUrl(String token, {int size = 280}) {
  final int sanitized = size.clamp(180, 600);
  return 'https://api.qrserver.com/v1/create-qr-code/'
      '?size=${sanitized}x$sanitized&data=${Uri.encodeComponent(token)}';
}

/// Öğrencinin kendi kaydı için ürettiği, kulübün okuttuğu QR yükü.
/// (student-qr-generate.js#buildStudentCheckinPayload)
Map<String, dynamic> buildStudentCheckinPayload({
  required String registrationId,
  required String eventId,
  required String studentId,
  double? lat,
  double? lng,
}) {
  // Yük küçük tutulur -> kompakt QR -> güvenilir okuma.
  final Map<String, dynamic> payload = <String, dynamic>{
    'v': 1,
    'type': 'event-checkin',
    'registrationId': registrationId,
    'eventId': eventId,
    'studentId': studentId,
  };

  // Konum varsa eklenir (5 ondalık ≈ ±1 m hassasiyet).
  if (lat != null && lng != null) {
    payload['lat'] = (lat * 1e5).round() / 1e5;
    payload['lng'] = (lng * 1e5).round() / 1e5;
  }

  return payload;
}

/// Kulübün ekrana bastığı, öğrencilerin okuttuğu paylaşılan oturum QR yükü.
/// (club-events.js#showSessionQr)
Map<String, dynamic> buildSessionCheckinPayload({
  required String eventId,
  required int session,
}) =>
    <String, dynamic>{
      'v': 1,
      'type': 'session-checkin',
      'eventId': eventId,
      'session': session,
    };
