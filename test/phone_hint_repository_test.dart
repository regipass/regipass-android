import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/services/phone_hint_repository.dart';

class _Hints extends PhoneHintRepository {
  Future<PasswordResetHint> Function() stored = () async =>
      const PasswordResetHint(maskedPhone: '', roles: []);
  Future<PasswordResetHint> Function() auth = () async =>
      const PasswordResetHint(maskedPhone: '+90 XXX XXX XX 67', roles: []);
  String? queriedEmail;
  @override
  Future<PasswordResetHint> readStoredHint(String key) => stored();
  @override
  Future<PasswordResetHint> readAuthHint(String email) {
    queriedEmail = email;
    return auth();
  }
}

void main() {
  test('eksik ve izni reddedilen belge icin Auth ipucu okunur', () async {
    final hints = _Hints();
    expect(
      (await hints.readHint(' Test@Example.com ')).maskedPhone,
      '+90 XXX XXX XX 67',
    );
    expect(hints.queriedEmail, 'test@example.com');
    hints.stored = () async => throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    expect(
      (await hints.readHint('test@example.com')).maskedPhone,
      '+90 XXX XXX XX 67',
    );
  });
  test('mevcut ipucu ikinci ag istegine gerek duymadan gosterilir', () async {
    final hints = _Hints();
    hints.stored = () async =>
        const PasswordResetHint(maskedPhone: 'saved-mask', roles: ['student']);
    expect(
      (await hints.readHint('test@example.com')).maskedPhone,
      'saved-mask',
    );
    expect(hints.queriedEmail, isNull);
  });
  testWidgets('iki servis de takilsa okuma belirli surede tamamlanir', (
    tester,
  ) async {
    final hints = _Hints();
    hints.stored = () => Completer<PasswordResetHint>().future;
    hints.auth = () => Completer<PasswordResetHint>().future;
    PasswordResetHint? result;
    unawaited(hints.readHint('test@example.com').then((hint) => result = hint));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 9));
    expect(result?.maskedPhone, '');
  });
}
