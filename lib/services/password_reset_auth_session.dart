import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/app_log.dart';
import 'firebase_refs.dart';

/// SMS girişini ana oturumdan ayırır. İptal edilmiş/gecikmiş bir istek
/// uygulamaya giriş yaptıramaz; şifre kaydedilince ana oturum ayrıca açılır.
class PasswordResetAuthSession {
  Future<FirebaseApp>? _app;
  bool _closed = false;
  static int _nextId = 0;

  Future<FirebaseAuth> get _auth async {
    if (_closed) throw StateError('Password reset session closed');
    final FirebaseApp app = await (_app ??= Firebase.initializeApp(
      name:
          'password-reset-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
      options: fbAuth.app.options,
    ));
    if (_closed) throw StateError('Password reset session closed');
    return FirebaseAuth.instanceFor(app: app);
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    final FirebaseAuth auth = await _auth;
    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> signIn(PhoneAuthCredential credential) async =>
      (await _auth).signInWithCredential(credential);

  Future<void> updatePassword(String password) async {
    final User? user = (await _auth).currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await user.updatePassword(password);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final Future<FirebaseApp>? pending = _app;
    if (pending == null) return;
    try {
      final FirebaseApp app = await pending;
      try {
        await FirebaseAuth.instanceFor(
          app: app,
        ).signOut().timeout(const Duration(seconds: 5));
      } finally {
        await app.delete().timeout(const Duration(seconds: 5));
      }
    } catch (error) {
      AppLog.warn('passwordReset.sessionCleanupFailed', <String, Object?>{
        'type': error.runtimeType.toString(),
      });
    }
  }
}
