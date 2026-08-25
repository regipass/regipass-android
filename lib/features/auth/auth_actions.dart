/// Giriş sonrası ortak işlemler ve hata çevirisi.
///
/// Daha önce `landing_screen.dart` içindeydi; giriş ekranı yeniden
/// tasarlanınca hem giriş hem kayıt ekranının kullandığı bu yardımcılar
/// bağımsız bir dosyaya alındı.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../state/providers.dart';

/// login-modal.js#handlePostAuth portu.
///
/// Yönlendirmeyi router yapar; burada yalnızca "hangi rol seçili olmalı"
/// kararı verilip `users` dokümanı tazelenir.
Future<void> completePostAuth(WidgetRef ref, User user) async {
  if (isAdminEmail(user.email)) return; // router /admin'e alır

  final AppUser? appUser =
      await ref.read(profileRepositoryProvider).fetchUser(user.uid);

  final bool hasStudent = appUser?.hasStudentRole ?? false;
  final bool hasClub = appUser?.hasClubRole ?? false;

  // İki rol de varsa ya da hiç yoksa: rol seçim ekranına düşülür
  // (aktif rol atanmaz, router yönlendirir).
  if (hasStudent == hasClub) return;

  final String role = hasStudent ? UserRole.student : UserRole.club;
  await ref.read(activeRoleProvider.notifier).select(role);
  await ref.read(authRepositoryProvider).upsertBaseUser(user, role);
}

/// login-modal.js#getFriendlyErrorMessage portu.
String friendlyAuthError(BuildContext context, Object error) {
  final String code = error is FirebaseAuthException ? error.code : '';

  return switch (code) {
    'invalid-email' => context.t('auth.error.invalidEmail'),
    'invalid-credential' ||
    'wrong-password' =>
      context.t('auth.error.invalidCredentials'),
    'user-not-found' => context.t('auth.error.userNotFound'),
    'email-already-in-use' => context.t('auth.error.emailInUse'),
    'weak-password' => context.t('auth.error.weakPassword'),
    'too-many-requests' => context.t('auth.error.tooManyRequests'),
    'operation-not-allowed' => context.t('auth.error.operationNotAllowed'),
    'network-request-failed' => context.t('auth.error.networkFailed'),
    // Kullanıcı Google/Apple penceresini kapattı — hata göstermeye gerek yok.
    'canceled' || 'web-context-canceled' => '',
    '' => context.t('auth.error.unknown', <String, Object?>{'code': '$error'}),
    _ => context.t('auth.error.unknown', <String, Object?>{'code': code}),
  };
}

/// Çıkış: cihazdaki rol seçimi silinir ve oturum kapatılır.
///
/// Sıra ve yöntem önemli. Önceden her ekran `activeRoleProvider.clear()`
/// çağırıyordu; bu, oturum HÂLÂ açıkken gözlemlenebilir durumu değiştiriyor
/// ve iki rolü olan hesaplarda router'ı "seçim yapılmamış" durumuna
/// düşürüyordu — kullanıcı bir an rol seçim ekranını görüp sonra giriş
/// ekranına iniyordu. Depo doğrudan temizlenirse durum değişmez; notifier
/// zaten uid null olunca kendini sıfırlar, router da doğrudan giriş
/// ekranına yönlendirir.
Future<void> logout(WidgetRef ref) async {
  await ref.read(roleSessionStoreProvider).clear();
  await ref.read(authRepositoryProvider).signOut();
}
