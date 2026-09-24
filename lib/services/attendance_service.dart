/// Yoklama ve giriş sunucuda (İP-Y) — Cloud Functions çağrıları.
///
/// Sunucu: Regipass-Web/functions/attendance.js.
///   • getCheckinQrKey  → kulübün kapı/oturum QR'ını imzalaması için anahtar
///   • checkInWithQr    → öğrencinin kapı girişi / oturum yoklaması
///   • ensureTicketCode → öğrencinin bilet kodu
///
/// Öğrencinin yoklamayı Firestore'a doğrudan yazdığı eski yol aşama 2'de
/// kurallarda kapanacak; bu sürüm yalnızca sunucu yolunu kullanır.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../domain/qr_signing.dart';
import 'firebase_refs.dart';

/// Sunucunun ret nedeni (`details.reason`) ve ek bilgisi.
class AttendanceFailure implements Exception {
  const AttendanceFailure(
    this.reason, {
    this.details = const <String, Object?>{},
  });

  /// `expired`, `too-far`, `entry-closed` ... ya da bağlantı sorununda `network`.
  final String reason;
  final Map<String, Object?> details;

  int? get distanceM => (details['distanceM'] as num?)?.toInt();
  int? get radiusM => (details['radiusM'] as num?)?.toInt();
  int? get session => (details['session'] as num?)?.toInt();

  @override
  String toString() => 'AttendanceFailure($reason)';
}

class CheckInResult {
  const CheckInResult({
    required this.session,
    required this.sessionsAttended,
    required this.flags,
  });

  final int session;
  final int sessionsAttended;
  final List<String> flags;
}

class AttendanceService {
  const AttendanceService({this.functions});

  final FirebaseFunctions? functions;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final HttpsCallableResult<Object?> result =
          await (functions ?? fbFunctions)
              .httpsCallable(
                name,
                options: HttpsCallableOptions(timeout: timeout),
              )
              .call(data);
      final Object? raw = result.data;
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (error) {
      throw failureFromException(error.code, error.details);
    }
  }

  /// Kulüp: etkinliğin QR imzalayıcısı. Sunucu saati farkını da hesaplar.
  Future<QrSigner> fetchQrSigner(String eventId) async {
    final int startedAt = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> out = await _call(
      'getCheckinQrKey',
      <String, Object?>{'eventId': eventId},
    );
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int serverNow = (out['serverNowMs'] as num?)?.toInt() ?? now;
    final int offset = serverNow + (now - startedAt) ~/ 2 - now;
    return QrSigner(
      key: '${out['key'] ?? ''}',
      windowMs: (out['windowMs'] as num?)?.toInt() ?? 20000,
      offsetMs: offset,
    );
  }

  /// Öğrenci: okutulan kod + (gerekiyorsa) cihaz konumu.
  Future<CheckInResult> checkInWithQr({
    required String token,
    ({double lat, double lng, double? accuracyM})? location,
  }) async {
    final Map<String, dynamic> out = await _call(
      'checkInWithQr',
      <String, Object?>{
        'token': token,
        'receipt': '',
        'location': location == null
            ? null
            : <String, Object?>{
                'lat': location.lat,
                'lng': location.lng,
                'accuracyM': location.accuracyM,
              },
      },
      timeout: const Duration(seconds: 15),
    );
    return CheckInResult(
      session: (out['session'] as num?)?.toInt() ?? 0,
      sessionsAttended: (out['sessionsAttended'] as num?)?.toInt() ?? 0,
      flags: (out['flags'] is List)
          ? (out['flags'] as List<dynamic>).whereType<String>().toList()
          : const <String>[],
    );
  }

  /// Öğrenci: kendi biletinin kodu (yoksa sunucu üretir).
  Future<String> ensureTicketCode(String registrationId) async {
    final Map<String, dynamic> out = await _call(
      'ensureTicketCode',
      <String, Object?>{'registrationId': registrationId},
      timeout: const Duration(seconds: 8),
    );
    return '${out['ticketCode'] ?? ''}';
  }
}

/// Sunucu hatasını [AttendanceFailure]'a çevirir (testlerde de kullanılır).
AttendanceFailure failureFromException(String code, Object? details) {
  final Map<String, Object?> map = details is Map
      ? Map<String, Object?>.from(details)
      : <String, Object?>{};
  final Object? reason = map['reason'];
  if (reason is String && reason.isNotEmpty) {
    return AttendanceFailure(reason, details: map);
  }
  return AttendanceFailure(
    const <String>{
          'unavailable',
          'deadline-exceeded',
          'internal',
        }.contains(code)
        ? 'network'
        : code,
    details: map,
  );
}
