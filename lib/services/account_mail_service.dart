/// İP-E1: şifre değişince hesabın kendi adresine "şifren değişti" e-postası.
/// js/modules/auth/account-mail.js karşılığı. Firebase'de şifre değişimi için
/// sunucu tetikleyicisi yok; istemci haber verir. En iyi çaba: hata akışı
/// asla bozmaz, beklenmez (unawaited).
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../core/app_log.dart';
import 'firebase_refs.dart';

/// [via]: 'change' (hesap ayarları) ya da 'reset' (şifremi unuttum).
Future<void> notifyPasswordChanged(String via) async {
  try {
    await fbFunctions
        .httpsCallable(
          'notifyPasswordChanged',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
        )
        .call(<String, Object>{'via': via});
  } catch (error) {
    AppLog.warn('password-changed-mail', <String, Object?>{'error': error.toString()});
  }
}
