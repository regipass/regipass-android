import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/domain/registration_capacity.dart';

void main() {
  test('mobil ilk istek penceresi web ile aynı ve sınırlıdır', () {
    expect(
      registrationAdmissionWindow(quota: 100, shards: 20),
      const Duration(seconds: 6),
    );
    for (final int quota in <int>[100, 200, 300]) {
      expect(
        registrationAdmissionWindow(
          quota: quota,
          shards: quotaShardCount(quota),
        ),
        const Duration(seconds: 8),
      );
    }
    expect(registrationAdmissionWindow(quota: 25, shards: 4), Duration.zero);
    expect(registrationAdmissionWindow(quota: 300, shards: 0), Duration.zero);
  });

  test('300 öğrenci aynı anda yazmaya gönderilmez; bekleyişler yayılır', () {
    final Random random = Random(42);
    final List<int> delays = List<int>.generate(
      300,
      (_) => registrationAdmissionDelay(
        quota: 300,
        shards: 16,
        random: random,
      ).inMilliseconds,
    );
    expect(delays.every((int ms) => ms >= 0 && ms < 8000), isTrue);
    expect(delays.toSet().length, greaterThan(250));
    expect(delays.map((int ms) => ms ~/ 1000).toSet().length, 8);
  });

  test('yalnızca değiştiği doğrulanan sayaç kural reddini çekişme yapar', () {
    expect(
      quotaChangedAfterDeniedWrite(
        code: 'permission-denied',
        attemptedCount: 3,
        currentCount: 4,
      ),
      isTrue,
    );
    expect(
      quotaChangedAfterDeniedWrite(
        code: 'permission-denied',
        attemptedCount: 3,
        currentCount: 2,
      ),
      isTrue,
    );
    for (final int? current in <int?>[3, null]) {
      expect(
        quotaChangedAfterDeniedWrite(
          code: 'permission-denied',
          attemptedCount: 3,
          currentCount: current,
        ),
        isFalse,
      );
    }
    expect(
      quotaChangedAfterDeniedWrite(
        code: 'permission-denied',
        attemptedCount: null,
        currentCount: 4,
      ),
      isFalse,
    );
    expect(
      quotaChangedAfterDeniedWrite(
        code: 'unauthenticated',
        attemptedCount: 3,
        currentCount: 4,
      ),
      isFalse,
    );
  });

  test('kalıcı yetki hataları tekrar deneme döngüsüne alınmaz', () {
    for (final String code in <String>[
      'permission-denied',
      'unauthenticated',
      'invalid-argument',
      'not-found',
      'unknown',
    ]) {
      expect(isRegistrationRetryable(code), isFalse, reason: code);
    }
    for (final String code in <String>[
      'aborted',
      'unavailable',
      'resource-exhausted',
      'deadline-exceeded',
    ]) {
      expect(isRegistrationRetryable(code), isTrue, reason: code);
    }
  });
}
