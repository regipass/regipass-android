/// Kayıt ve kontenjan sunucuda (İP-K) — Cloud Functions çağrıları.
///
/// Sunucu: Regipass-Web/functions/registrations.js. Kayıt, iptal, bekleme
/// listesi, kulübün kayıt silmesi, "Ödendi" işareti, kontenjan ve etkinlik
/// iptali artık yalnızca bu çağrılarla yapılır; uygulama kayıt belgesini ve
/// kontenjan parçalarını doğrudan yazmaz.
///
/// Eskiden (≤1.0.7) bu dosya kontenjan parçalarını istemcide kapıyordu. O yol
/// kurallarda aşama 1 boyunca açık kalır (eski sürümler için); aşama 2'de
/// kapanır (bkz. Regipass-Web/docs/ip-k-kayit-sunucuda.md).
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../core/app_log.dart';
import '../domain/paid_event_consent.dart';
import '../domain/registration_capacity.dart';
import '../models/event.dart';
import 'firebase_refs.dart';

/// Kayıt denemesinin sonucu.
class RegistrationResult {
  const RegistrationResult({
    required this.outcome,
    required this.elapsed,
    this.paymentPending = false,
    this.reason = '',
    this.attempts = 1,
  });

  final RegistrationOutcome outcome;
  final Duration elapsed;

  /// Ücretli etkinlik: kayıt "ödeme bekliyor" durumunda başladı.
  final bool paymentPending;

  /// Sunucunun ret nedeni (`details.reason`), varsa.
  final String reason;
  final int attempts;

  bool get isSuccess => outcome.isSuccess;

  Map<String, Object?> toFields() => <String, Object?>{
    'outcome': outcome.name,
    'ms': elapsed.inMilliseconds,
    'attempts': attempts,
    if (reason.isNotEmpty) 'reason': reason,
    if (paymentPending) 'paymentPending': true,
  };
}

/// Sunucunun reddettiği işlem.
class RegistrationFailure implements Exception {
  const RegistrationFailure(
    this.reason, {
    this.details = const <String, Object?>{},
  });

  /// `deadline-passed`, `below-registered`, `cancel-locked` ... ya da
  /// bağlantı sorununda `network`.
  final String reason;
  final Map<String, Object?> details;

  int? get registered => (details['registered'] as num?)?.toInt();

  bool get isNetwork => reason == 'network';

  @override
  String toString() => 'RegistrationFailure($reason)';
}

/// Sunucu hatasını [RegistrationFailure]'a çevirir (testlerde de kullanılır).
RegistrationFailure registrationFailureFrom(String code, Object? details) {
  final Map<String, Object?> map = details is Map
      ? Map<String, Object?>.from(details)
      : <String, Object?>{};
  final Object? reason = map['reason'];
  if (reason is String && reason.isNotEmpty) {
    return RegistrationFailure(reason, details: map);
  }
  return RegistrationFailure(
    const <String>{
          'unavailable',
          'deadline-exceeded',
          'internal',
          'aborted',
          'resource-exhausted',
        }.contains(code)
        ? 'network'
        : code,
    details: map,
  );
}

/// Sunucu ret nedeni → ekrandaki sonuç.
RegistrationOutcome outcomeForReason(String reason) => switch (reason) {
  'event-not-found' => RegistrationOutcome.notFound,
  'not-eligible' ||
  'club-banned' ||
  'banned' => RegistrationOutcome.notEligible,
  'registration-closed' ||
  'deadline-passed' ||
  'event-started' ||
  'event-past' ||
  'event-cancelled' ||
  'event-hidden' ||
  'quota-setup' => RegistrationOutcome.closed,
  'busy' => RegistrationOutcome.retryExhausted,
  _ => RegistrationOutcome.unavailable,
};

/// Bekleme listesi çağrılarının sonucu.
class WaitlistResult {
  const WaitlistResult({
    required this.status,
    this.position = 0,
    this.size = 0,
  });

  /// `waiting` | `seats-available` | `already-registered` | `not-waiting` | `left`
  final String status;
  final int position;
  final int size;

  bool get waiting => status == 'waiting';
}

/// Toplu işlem sonucu.
class BulkResult {
  const BulkResult({required this.count, this.notFound = const <String>[]});

  final int count;
  final List<String> notFound;
}

/// Sunucu yanıtı → [BulkResult] (testlerde de kullanılır).
BulkResult bulkResultFrom(
  Map<String, dynamic> out, {
  required String countKey,
}) {
  final Object? missing = out['notFound'];
  return BulkResult(
    count: (out[countKey] as num?)?.toInt() ?? 0,
    notFound: missing is List
        ? missing.map((Object? e) => '$e').toList(growable: false)
        : const <String>[],
  );
}

class RegistrationService {
  const RegistrationService({this.functions});

  final FirebaseFunctions? functions;

  /// Sunucu "şu an yoğun" derse (ya da bağlantı kısa süre koparsa) bu kadar
  /// deneme yapılır.
  static const int _maxAttempts = 4;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data, {
    Duration timeout = const Duration(seconds: 30),
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
      throw registrationFailureFrom(error.code, error.details);
    }
  }

  /// Etkinliğe kayıt. Kontenjan, son başvuru, engel, hedef kitle ve ücretli
  /// etkinlik onayı sunucuda denetlenir.
  ///
  /// [onWaiting]: sunucu yoğun olduğu için yeniden denenirken çağrılır.
  Future<RegistrationResult> register({
    required AppEvent event,
    required PaidEventConsentAcceptance? paidEventConsent,
    void Function(int round)? onWaiting,
  }) async {
    // Ekrandaki zorunlu pop-up atlatılsa bile ücretli kayıt onaysız gitmez
    // (sunucu da `paid-consent-required` ile reddeder).
    if (event.isPaid && paidEventConsent == null) {
      throw ArgumentError('Paid event registration requires student consent.');
    }

    final Stopwatch watch = Stopwatch()..start();
    AppLog.info('registration.start', <String, Object?>{
      'eventId': event.id,
      'quota': event.quota,
    });

    for (int attempt = 1; ; attempt += 1) {
      try {
        final Map<String, dynamic> out =
            await _call('registerForEvent', <String, Object?>{
              'eventId': event.id,
              'paidConsent': paidEventConsent != null,
              'consentText': paidEventConsent?.text ?? '',
            });
        final String status = '${out['status'] ?? ''}';
        final RegistrationResult result = RegistrationResult(
          outcome: switch (status) {
            'registered' => RegistrationOutcome.registered,
            'already-registered' => RegistrationOutcome.alreadyRegistered,
            'full' => RegistrationOutcome.quotaFull,
            _ => RegistrationOutcome.unavailable,
          },
          paymentPending: '${out['paymentStatus'] ?? ''}' == 'pending',
          elapsed: watch.elapsed,
          attempts: attempt,
        );
        AppLog.info('registration.done', result.toFields());
        return result;
      } on RegistrationFailure catch (failure) {
        final bool retry =
            (failure.reason == 'busy' || failure.isNetwork) &&
            attempt < _maxAttempts;
        if (retry) {
          onWaiting?.call(attempt);
          await Future<void>.delayed(
            Duration(milliseconds: 400 * attempt * attempt),
          );
          continue;
        }
        final RegistrationResult result = RegistrationResult(
          outcome: outcomeForReason(failure.reason),
          reason: failure.reason,
          elapsed: watch.elapsed,
          attempts: attempt,
        );
        AppLog.warn('registration.rejected', result.toFields());
        return result;
      }
    }
  }

  /// Öğrenci kaydını iptal eder; kontenjan yeri aynı işlemde geri verilir ve
  /// bekleme listesindekilere haber gider. Hata olursa [RegistrationFailure].
  Future<void> unregister({required String eventId}) async {
    await _call('cancelRegistration', <String, Object?>{'eventId': eventId});
    AppLog.info('registration.cancelled', <String, Object?>{
      'eventId': eventId,
    });
  }

  /// Hesap silme: bütün kayıtlar yer geri verilerek silinir, bekleme listesi
  /// girişleri temizlenir.
  Future<void> cancelAllMine() async {
    await _call(
      'cancelAllMyRegistrations',
      const <String, Object?>{},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<WaitlistResult> joinWaitlist(String eventId) async => _waitlistResult(
    await _call('joinWaitlist', <String, Object?>{'eventId': eventId}),
  );

  Future<void> leaveWaitlist(String eventId) async {
    await _call('leaveWaitlist', <String, Object?>{'eventId': eventId});
  }

  Future<WaitlistResult> waitlistPosition(String eventId) async =>
      _waitlistResult(
        await _call('getWaitlistPosition', <String, Object?>{
          'eventId': eventId,
        }, timeout: const Duration(seconds: 15)),
      );

  WaitlistResult _waitlistResult(Map<String, dynamic> out) => WaitlistResult(
    status: '${out['status'] ?? ''}',
    position: (out['position'] as num?)?.toInt() ?? 0,
    size: (out['size'] as num?)?.toInt() ?? 0,
  );

  // ── Kulüp ────────────────────────────────────────────────────────────────
  Future<void> clubRemoveRegistration({
    required String eventId,
    required String studentId,
    String reason = '',
  }) async {
    await _call('clubRemoveRegistration', <String, Object?>{
      'eventId': eventId,
      'studentId': studentId,
      'reason': reason,
    });
  }

  Future<void> setPaymentStatus({
    required String eventId,
    required String studentId,
    required bool paid,
  }) async {
    await _call('setPaymentStatus', <String, Object?>{
      'eventId': eventId,
      'studentId': studentId,
      'paid': paid,
    });
  }

  /// Toplu (çoklu seçim) "Ödendi": en fazla [maxBulk] öğrenci. Dönüş:
  /// durumu değişen kayıt sayısı ve bulunamayan (bu arada silinmiş) kayıtlar.
  Future<BulkResult> setPaymentStatusBulk({
    required String eventId,
    required List<String> studentIds,
    required bool paid,
  }) async => bulkResultFrom(
    await _call('setPaymentStatus', <String, Object?>{
      'eventId': eventId,
      'studentIds': studentIds,
      'paid': paid,
    }, timeout: const Duration(seconds: 120)),
    countKey: 'changedCount',
  );

  /// Toplu kayıt silme (gerekçe hepsine aynı gider).
  Future<BulkResult> clubRemoveRegistrations({
    required String eventId,
    required List<String> studentIds,
    String reason = '',
  }) async => bulkResultFrom(
    await _call('clubRemoveRegistration', <String, Object?>{
      'eventId': eventId,
      'studentIds': studentIds,
      'reason': reason,
    }, timeout: const Duration(seconds: 120)),
    countKey: 'removed',
  );

  // ── İP-KB: kulübün öğrenci engeli ────────────────────────────────────────
  /// Kulüp, etkinliğine kaydolmuş bir öğrenciyi kendi etkinliklerinden
  /// engeller. Dönüş: silinen gelecek etkinlik kaydı sayısı.
  Future<int> clubBlockStudent({
    required String studentId,
    required String reason,
    bool removeFutureRegistrations = false,
  }) async {
    final Map<String, dynamic> out =
        await _call('clubBlockStudent', <String, Object?>{
          'studentId': studentId,
          'reason': reason,
          'removeFutureRegistrations': removeFutureRegistrations,
        }, timeout: const Duration(seconds: 120));
    return (out['removedEvents'] as num?)?.toInt() ?? 0;
  }

  Future<void> clubUnblockStudent(String studentId) async {
    await _call('clubUnblockStudent', <String, Object?>{
      'studentId': studentId,
    });
  }

  /// Sunucunun tek çağrıda kabul ettiği en fazla öğrenci (functions MAX_BULK).
  static const int maxBulk = 200;

  /// Kontenjanı kurar/değiştirir (parça silinmez, sayımlar kayıtlardan yeniden
  /// hesaplanır). Kayıtlı sayısının altına inilirse `below-registered`.
  Future<int> setEventQuota({
    required String eventId,
    required int quota,
  }) async {
    final Map<String, dynamic> out = await _call(
      'setEventQuota',
      <String, Object?>{'eventId': eventId, 'quota': quota},
      timeout: const Duration(seconds: 60),
    );
    return (out['quota'] as num?)?.toInt() ?? quota;
  }

  /// Etkinliği iptal eder. Hiç kaydı olmayan etkinlik tamamen silinir.
  /// Dönüş: `cancelled` | `deleted` | `already-cancelled`.
  Future<({String status, int notified})> cancelEvent({
    required String eventId,
    String reason = '',
  }) async {
    final Map<String, dynamic> out = await _call(
      'cancelEvent',
      <String, Object?>{'eventId': eventId, 'reason': reason},
      timeout: const Duration(seconds: 120),
    );
    return (
      status: '${out['status'] ?? ''}',
      notified: (out['notified'] as num?)?.toInt() ?? 0,
    );
  }
}
