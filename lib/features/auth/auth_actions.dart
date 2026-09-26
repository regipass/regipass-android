/// Giriş sonrası ortak işlemler ve hata çevirisi.
///
/// Daha önce `landing_screen.dart` içindeydi; giriş ekranı yeniden
/// tasarlanınca hem giriş hem kayıt ekranının kullandığı bu yardımcılar
/// bağımsız bir dosyaya alındı.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/staff_access.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../state/providers.dart';

/// login-modal.js#handlePostAuth portu.
///
/// Yönlendirmeyi router yapar. Firestore'da hesabı olmayan yeni kullanıcı için
/// burada hiçbir belge oluşturulmaz; tamamlanmış bir hesabın yalnız giriş
/// zamanı ve Auth e-postası tazelenir.
Future<void> completePostAuth(WidgetRef ref, User user) async {
  // İP-M1: yönetim hesabı rol etiketinden tanınır. Kodla açılmış oturum →
  // router /admin'e alır. Rolü olup doğrulayıcısı hiç kurulmamış hesap
  // mobilde kurulum yapamaz (QR + ilk kod webde): oturum kapatılır.
  final StaffAccess staff = await _staffAccessOf(user);
  if (staff.state == StaffAccessState.ready) return;
  if (staff.state == StaffAccessState.needsSetup) {
    await ref.read(authRepositoryProvider).signOut();
    throw FirebaseAuthException(code: kStaffSetupRequiredCode);
  }

  final profileRepository = ref.read(profileRepositoryProvider);
  final authRepository = ref.read(authRepositoryProvider);
  final AppUser? appUser = await profileRepository.fetchUser(user.uid);
  if (appUser == null) return;

  await authRepository.recordExistingUserLogin(user);
}

/// Yönetim hesabının doğrulayıcı kurulumu webde yapılmalı (İP-M1).
const String kStaffSetupRequiredCode = 'staff-setup-required';

Future<StaffAccess> _staffAccessOf(User user) async {
  try {
    final IdTokenResult token = await user.getIdTokenResult();
    return StaffAccess.fromClaims(token.claims);
  } catch (_) {
    return StaffAccess.none;
  }
}

/// login-modal.js#getFriendlyErrorMessage portu.
String friendlyAuthError(BuildContext context, Object error) {
  // Google'ın hesap seçicisinden vazgeçmek hata değildir. Eklentinin v7
  // sürümü bunu FirebaseAuthException yerine GoogleSignInException olarak
  // döndürdüğü için burada ayrıca ele alıyoruz; aksi hâlde ham, uzun hata
  // metni ekranda görünür.
  if (error is GoogleSignInException &&
      (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted)) {
    return '';
  }

  final String code = error is FirebaseAuthException ? error.code : '';

  return switch (code) {
    'invalid-email' => context.t('auth.error.invalidEmail'),
    'invalid-credential' ||
    'wrong-password' => context.t('auth.error.invalidCredentials'),
    'user-not-found' => context.t('auth.error.userNotFound'),
    // İP-M1: engellenen ya da silinmeyi bekleyen hesap (Auth hesabı kapalı).
    'user-disabled' => context.t('auth.error.userDisabled'),
    kStaffSetupRequiredCode => context.t('auth.error.staffSetupRequired'),
    'invalid-verification-code' ||
    'missing-code' => context.t('auth.totp.invalid'),
    'multi-factor-unsupported' => context.t('auth.totp.unsupported'),
    'email-already-in-use' => context.t('auth.error.emailInUse'),
    'weak-password' => context.t('auth.error.weakPassword'),
    'too-many-requests' => context.t('auth.error.tooManyRequests'),
    'operation-not-allowed' => context.t('auth.error.operationNotAllowed'),
    'network-request-failed' => context.t('auth.error.networkFailed'),
    // Kullanıcı Google/Apple penceresini kapattı — hata göstermeye gerek yok.
    'canceled' || 'web-context-canceled' => '',
    _ => context.t('auth.error.unknown'),
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
  final Session session = ref.read(sessionProvider);
  final accountCleanup = ref.read(accountCleanupRepositoryProvider);
  final roleSessionStore = ref.read(roleSessionStoreProvider);
  final authRepository = ref.read(authRepositoryProvider);
  final pendingRole = ref.read(pendingOnboardingRoleProvider.notifier);

  // Sosyal sağlayıcılar ve createUserWithEmailAndPassword, formdan önce bir
  // Auth kimliği üretir. Hiç tamamlanmış profili olmayan kullanıcı açıkça
  // vazgeçtiğinde eski sürümden kalmış yarım Firestore iskeletleri silinir.
  // Auth kimliği silinmez: iki ayrı Firebase ürünü arasında atomik silme
  // olmadığı için başka cihazdaki son kayıtla yarışmak güvenli değildir.
  if (!session.isLoading &&
      !session.isAdmin &&
      !session.hasAnyRole &&
      session.user != null) {
    try {
      await accountCleanup.discardIfUnfinished(session.user!.uid);
    } catch (_) {
      // En iyi çaba. Çevrimdışıyken kullanıcı yine güvenle oturumdan çıkarılır.
    }
  }

  await roleSessionStore.clear();
  await authRepository.signOut();
  pendingRole.clear();
}
