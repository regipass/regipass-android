/// Telefon doğrulama hatalarının kullanıcıya gösterilecek karşılıkları.
///
/// phone-verify.js#describePhoneError portu. Hem tam ekran doğrulama kapısı
/// (`phone_verify_screen.dart`) hem de hesap ekranındaki pop-up
/// (`phone_verify_sheet.dart`) aynı metinleri kullanır.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

/// Kaç yanlış koddan sonra kullanıcıya "yeni kod iste" denir.
const int kMaxWrongCodeAttempts = 3;

/// Girilen kodun kabul edilmediği hatalar.
///
/// Firebase art arda yanlış kod girildiğinde bir noktada oturumu düşürüp
/// `session-expired` döndürüyor; kullanıcı açısından bu da "yanlış kod"
/// denemesidir, o yüzden aynı sayaca girer.
bool isWrongCodeError(Object error) {
  final String code = _errorCode(error);
  return code == 'invalid-verification-code' ||
      code == 'session-expired' ||
      code == 'code-expired';
}

String _errorCode(Object error) => switch (error) {
  FirebaseAuthException(:final String code) => code,
  FirebaseException(:final String code) => code,
  _ => '',
};

/// [wrongCodeAttempts]: bu doğrulama oturumunda şimdiye kadarki yanlış kod
/// sayısı (bu hata dahil). Sınıra ulaşıldığında "kodun süresi doldu" demek
/// yanıltıcı olur — kullanıcı kodu yanlış girdiği için yeni kod istemeli.
String describePhoneAuthError(
  BuildContext context,
  Object error, {
  int wrongCodeAttempts = 0,
}) {
  final String code = _errorCode(error);

  if (wrongCodeAttempts >= kMaxWrongCodeAttempts && isWrongCodeError(error)) {
    return context.t('phoneVerify.error.tooManyWrongCodes');
  }

  return switch (code) {
    'invalid-phone-number' => context.t('phoneVerify.error.invalidPhone'),
    'too-many-requests' => context.t('phoneVerify.error.tooManyRequests'),
    'quota-exceeded' => context.t('phoneVerify.error.quotaExceeded'),
    'captcha-check-failed' => context.t('phoneVerify.error.captchaFailed'),
    'invalid-verification-code' => context.t('phoneVerify.error.invalidCode'),
    // Cihaz doğrulaması reCAPTCHA'ya düştüğünde Firebase kullanıcıyı tarayıcıya
    // götürür; kullanıcı oradan geri gelirse (ya da sekme kapanırsa) akış bu
    // kodla biter. Eskiden "bir hata oluştu" deyip bırakıyordu.
    'web-context-canceled' => context.t('phoneVerify.error.browserCanceled'),
    'web-context-already-presented' => context.t(
      'phoneVerify.error.browserAlreadyOpen',
    ),
    'network-request-failed' => context.t('phoneVerify.error.network'),
    // Cihaz doğrulaması (Play Integrity/reCAPTCHA) tamamlanamadı: imza
    // parmak izi eksik, Play Services yok ya da uygulama kaydı eşleşmiyor.
    // Bkz. docs/telefon-dogrulama-recaptcha.md.
    'app-not-authorized' ||
    'missing-client-identifier' ||
    'invalid-app-credential' => context.t(
      'phoneVerify.error.deviceCheckFailed',
    ),
    'session-expired' ||
    'code-expired' => context.t('phoneVerify.error.codeExpired'),
    'credential-already-in-use' ||
    'account-exists-with-different-credential' => context.t(
      'phoneVerify.error.numberInUse',
    ),
    'requires-recent-login' => context.t(
      'phoneChange.error.requiresRecentLogin',
    ),
    'permission-denied' => context.t('phoneVerify.error.mismatch'),
    // "error-code:-39" gibi belgelenmemiş sayısal kodlar, Firebase'in düzgün
    // bir "too-many-requests" yerine belirsiz kodla döndürdüğü kötüye
    // kullanım sınırıdır (sınır numaranın kendisine uygulanır).
    _ when code.startsWith('error-code:') => context.t(
      'phoneVerify.error.unknownRateLimit',
    ),
    _ => context.t('phoneVerify.error.generic'),
  };
}
