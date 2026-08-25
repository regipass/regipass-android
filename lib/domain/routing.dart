/// js/modules/auth/role-session.js içindeki yönlendirme mantığının portu.
///
/// Web'de her sayfa `window.location.href = "x.html"` ile karar veriyordu;
/// burada aynı kararlar tek bir router redirect'inde toplanır (bkz.
/// `lib/app/router.dart`).
library;

import '../core/constants.dart';
import '../models/profiles.dart';

/// Uygulama rotaları. Karşılık gelen web sayfası yorum satırında belirtildi.
class Routes {
  static const String landing = '/'; // index.html
  static const String register = '/register'; // register.html

  /// Web'de giriş penceresinin ikinci adımıydı (login-modal.js#showRoleStep):
  /// hesabın hem öğrenci hem kulüp rolü varsa ya da hiç rolü yoksa gösterilir.
  static const String roleSelect = '/role-select';

  /// Misafir vitrini: giriş yapmadan etkinliklere göz atma.
  /// Web'de karşılığı yoktu; index.html'deki tanıtım bölümlerinin yerini alır.
  static const String explore = '/explore';

  /// Şifremi unuttum. Girişten önce açılır ama SMS doğrulaması sırasında
  /// kullanıcı Auth'a giriş yapmış olur — bu yüzden router'da hem oturumsuz
  /// hem oturumlu erişime izin verilir (bkz. lib/app/router.dart).
  static const String forgotPassword = '/forgot-password';

  static const String studentOnboarding = '/onboarding/student'; // info.html
  static const String clubOnboarding = '/onboarding/club'; // club-info.html

  static const String phoneVerify = '/phone-verify'; // phone-verify.html
  static const String phoneChange = '/phone-change'; // phone-change.html

  static const String studentHome = '/student'; // dashboard.html
  static const String studentAppointments = '/student/appointments';
  static const String studentQrGenerate = '/student/qr';
  static const String studentQrCheckin = '/student/scan';
  static const String studentCertificates = '/student/certificates';
  static const String studentAccount = '/student/account';

  /// Üst çubuktaki zil düğmesinin hedefi. İçeriği sonraki aşamada dolacak.
  static const String studentNotifications = '/student/notifications';

  static const String clubHome = '/club'; // club-dashboard.html
  static const String clubEvents = '/club/events';
  static const String clubCreateEvent = '/club/events/new';

  /// Tek etkinliğin yönetimi: oturumlar, katılımcılar, belge dağıtımı.
  /// Web'de bu bir modaldı; mobilde içerik bir alt sayfaya sığmıyor.
  static const String clubEventDetail = '/club/events/detail';
  static const String clubDocuments = '/club/documents';
  static const String clubPending = '/club/pending';
  static const String clubQrCheckin = '/club/scan';

  /// Oturum QR'ı üretme. Web'de bu, etkinlik modalindeki "Oturum QR'ını Göster"
  /// düğmesiydi ve YALNIZCA çok oturumlu etkinliklerde görünüyordu.
  static const String clubSessionQr = '/club/qr';

  static const String clubAccount = '/club/account';
  static const String clubNotifications = '/club/notifications';

  static const String adminHome = '/admin'; // admin-dashboard.html
  static const String adminStats = '/admin/stats';
  static const String adminBan = '/admin/ban';
  static const String adminNotifications = '/admin/notifications';

  /// "banned" gerçek bir rota değil; çağıran taraf oturumu kapatıp
  /// kullanıcıyı uyarmalıdır (web ile aynı desen).
  static const String banned = '__banned__';
}

/// Onaylanmış kulüp durumuna göre hedef rota.
///
/// NOT: Kulüp hesapları için telefon SMS doğrulaması ARANMAZ (telefon bilgisi
/// yine toplanır, sadece zorunlu SMS onayı istenmez) — bu yüzden burada
/// telefon kontrolü yok, yalnızca öğrenci tarafında var.
String getClubRouteByStatus(ClubProfile? profile) {
  if (profile == null || !profile.onboardingCompleted) {
    return Routes.clubOnboarding;
  }

  switch (profile.clubStatus) {
    case ClubStatus.approved:
      return Routes.clubHome;
    case ClubStatus.pendingReview:
      return Routes.clubPending;
    case ClubStatus.banned:
      return Routes.banned;
    default:
      return Routes.clubDocuments;
  }
}

/// Öğrenci onboarding + telefon doğrulama + ban durumuna göre hedef rota.
String getStudentRouteByStatus(StudentProfile? profile) {
  if (profile == null || !profile.onboardingCompleted) {
    return Routes.studentOnboarding;
  }

  if (profile.banned) return Routes.banned;

  if (!profile.phoneVerified) return Routes.phoneVerify;

  return Routes.studentHome;
}

/// Sadece onboarding durumunu bilen çağrılar için kısa yol
/// (role-session.js#getRouteByRoleAndStatus).
String getRouteByRoleAndStatus(String? role, bool onboardingCompleted) {
  if (role == UserRole.student) {
    return onboardingCompleted ? Routes.studentHome : Routes.studentOnboarding;
  }
  if (role == UserRole.club) {
    return onboardingCompleted ? Routes.clubHome : Routes.clubOnboarding;
  }
  return Routes.landing;
}

/// Aktif rol çözümü: önce cihazda saklanan seçim, sonra `lastRole`, sonra `role`.
String? resolvePreferredRole(String? storedRole, AppUser? user) {
  if (UserRole.isValid(storedRole)) return storedRole;
  if (UserRole.isValid(user?.lastRole)) return user!.lastRole;
  if (UserRole.isValid(user?.role)) return user!.role;
  return null;
}

/// Bir rotanın öğrenci alanına ait olup olmadığı (guard'da kullanılır).
bool isStudentRoute(String location) =>
    location.startsWith(Routes.studentHome) ||
    location == Routes.studentOnboarding;

bool isClubRoute(String location) =>
    location.startsWith(Routes.clubHome) || location == Routes.clubOnboarding;

bool isAdminRoute(String location) => location.startsWith(Routes.adminHome);
