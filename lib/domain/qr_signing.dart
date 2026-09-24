/// Kapı/oturum QR imzası (İP-Y).
///
/// Sunucudaki functions/attendance.js ve web'deki
/// js/modules/events/attendance-api.js ile BİREBİR aynı olmalı:
///   mesaj = `tür|etkinlik|oturum (yoksa 0)|dilim`
///   imza  = `base64url(HMAC-SHA256(anahtar, mesaj))` ilk 22 karakter
///
/// Kulüp cihazı etkinliğin anahtarını bir kez alır (getCheckinQrKey) ve her
/// 20 saniyelik dilim için kodu kendisi üretir. Dilim sunucu saatine göre
/// hesaplanır ([QrSigner.offsetMs]); cihaz saati kaymış olsa da kod geçerli.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

const int kQrSigLength = 22;

String signedQrMessage({
  required String type,
  required String eventId,
  int session = 0,
  required int slot,
}) => '$type|$eventId|$session|$slot';

String _b64urlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _keyBytes(String key) => base64Url.decode(
  base64Url.normalize(key.replaceAll('+', '-').replaceAll('/', '_')),
);

String hmacQrSig(String key, String message) => _b64urlNoPad(
  Hmac(sha256, _keyBytes(key)).convert(utf8.encode(message)).bytes,
).substring(0, kQrSigLength);

class QrSigner {
  QrSigner({
    required this.key,
    required this.windowMs,
    required this.offsetMs,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final String key;
  final int windowMs;

  /// Sunucu saati − cihaz saati (ms).
  final int offsetMs;
  final int Function() _clock;

  int nowMs() => _clock() + offsetMs;

  int slot() => nowMs() ~/ windowMs;

  int msUntilNextSlot() => windowMs - (nowMs() % windowMs);

  /// Kapı (`event-entry`) ya da oturum (`session-checkin`) yükü, imzalı.
  Map<String, dynamic> sign({
    required String type,
    required String eventId,
    int session = 0,
    int? slotOverride,
  }) {
    final int s = slotOverride ?? slot();
    return <String, dynamic>{
      'v': 2,
      'type': type,
      'eventId': eventId,
      if (type == 'session-checkin') 'session': session,
      'slot': s,
      'sig': hmacQrSig(
        key,
        signedQrMessage(
          type: type,
          eventId: eventId,
          session: session,
          slot: s,
        ),
      ),
    };
  }
}

/// Kayıttaki şüphe işaretlerini okunur etiket anahtarlarına çevirir.
///
/// Dönen her öğe (aşama, çeviri anahtarı): aşama `0` kapı, `n` oturum.
/// Sunucudan geçmemiş (eski sürümden yazılmış) kendi kendine giriş/yoklama da
/// şüpheli sayılır. Kulübün kapıda okuttuğu giriş şüpheli değildir.
List<({int stage, String key})> attendanceSuspicions({
  required List<String> flags,
  required Map<String, int> verified,
  required String checkedInVia,
  required int lastAttendedSession,
}) {
  const Map<String, String> known = <String, String>{
    'edge': 'attendance.flag.edge',
    'low-accuracy': 'attendance.flag.lowAccuracy',
    'unsigned-qr': 'attendance.flag.unsignedQr',
    'delayed': 'attendance.flag.delayed',
  };
  final List<({int stage, String key})> out = <({int stage, String key})>[];
  final Set<String> seen = <String>{};
  void add(int stage, String key) {
    if (seen.add('$stage|$key')) out.add((stage: stage, key: key));
  }

  for (final String entry in flags) {
    final List<String> parts = entry.split(':');
    final String? key = known[parts.last];
    if (key == null) continue;
    final int stage = parts.first == 'session' && parts.length >= 3
        ? int.tryParse(parts[1]) ?? 0
        : 0;
    add(stage, key);
  }
  if (checkedInVia == 'self-qr' && !verified.containsKey('door')) {
    add(0, 'attendance.flag.unverified');
  }
  if (lastAttendedSession > 0 &&
      !verified.containsKey('s$lastAttendedSession')) {
    add(lastAttendedSession, 'attendance.flag.unverified');
  }
  return out;
}

/// Kulübün okuttuğu bilet kayıtla eşleşiyor mu?
/// (js/modules/events/student-ticket.js#verifyTicketCode ile aynı)
///
/// Aşama 1: eski sürümün kodsuz bileti uyarıyla kabul edilir ([acceptLegacy]).
({bool ok, bool legacy}) verifyTicketCode({
  required String? given,
  required String expected,
  bool acceptLegacy = kAcceptLegacyTickets,
}) {
  if (given != null && given.isNotEmpty) {
    return (ok: expected.isNotEmpty && given == expected, legacy: false);
  }
  return (ok: acceptLegacy, legacy: true);
}

/// İP-Y aşama 1: true. Yeni mobil sürüm yayındayken aşama 2'de false.
const bool kAcceptLegacyTickets = true;
