/// js/modules/auth/role-session.js içindeki yönlendirme mantığının portu.
///
/// Web'de her sayfa `window.location.href = "x.html"` ile karar veriyordu;
/// burada aynı kararlar tek bir router redirect'inde toplanır (bkz.
/// `lib/app/router.dart`).
library;

import '../core/constants.dart';
import 'checkin_qr.dart';
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

  /// Telefonun kendi kamerasının açtığı HTTPS QR adresinin uygulama içi
  /// karşılığı. Web tarafı bu yolu (`/qr.html?t=...`) uygulama yokken kendi
  /// QR giriş sayfasında işler; uygulama varsa Android App Link / iOS
  /// Universal Link doğrudan bu rotaya gelir.
  static const String qrEntry = '/qr.html';

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

  /// Kulüp listesi: hangi şehirde/üniversitede hangi kulüp açılmış.
  /// Web'de admin-clubs.html.
  static const String adminClubs = '/admin/clubs';
  static const String adminBan = '/admin/ban';
  static const String adminNotifications = '/admin/notifications';

  /// "banned" gerçek bir rota değil; çağıran taraf oturumu kapatıp
  /// kullanıcıyı uyarmalıdır (web ile aynı desen).
  static const String banned = '__banned__';
}

/// QR rotasını oturum açma ve onboarding boyunca kaybetmemek için kullanılan
/// sorgu parametresi. Yalnızca doğrulanmış bir [CheckinQrDeepLink] saklanır;
/// istemcinin rastgele bir iç rotaya yönlendirme yaptırmasına izin verilmez.
const String kExternalQrContinueParam = 'continue';

/// Telefon kamerasından gelen dış QR isteğinin doğrulanmış, küçük modeli.
///
/// Eski `EVAPPQR1` yükü ve mevcut uygulama-içi tarama aynen korunur. Bu model
/// yalnızca HTTPS sarmalayıcısından gelen kapı/oturum QR'larına yol verir;
/// görevlinin okuduğu kişisel `event-checkin` bileti hiçbir zaman dış rotaya
/// dönüşmez.
class CheckinQrDeepLink {
  const CheckinQrDeepLink._({
    required this.token,
    required this.eventId,
    required this.type,
  });

  final String token;
  final String eventId;
  final String type;

  /// `/qr.html?t=EVAPPQR1:...` biçimindeki bir URI'yi çözer.
  static CheckinQrDeepLink? parse(Uri uri) {
    if (uri.path != Routes.qrEntry) return null;

    final String? token =
        uri.queryParameters[kQrTokenParam] ?? uri.queryParameters['token'];
    final Map<String, dynamic>? payload = parseCheckinQrToken(token);
    if (payload == null) return null;

    final String type = '${payload['type'] ?? ''}';
    final String eventId = '${payload['eventId'] ?? ''}'.trim();
    if (eventId.isEmpty ||
        (type != 'event-entry' && type != 'session-checkin')) {
      return null;
    }

    // Oturum QR'ı için mevcut tarayıcıdaki zorunlu alanı burada da koru.
    final int? session = payload['session'] is int
        ? payload['session'] as int
        : int.tryParse('${payload['session'] ?? ''}');
    if (type == 'session-checkin' && session == null) return null;

    return CheckinQrDeepLink._(token: token!, eventId: eventId, type: type);
  }

  /// Oturumu tamamlaması gereken kullanıcı için uygulama içi hedef.
  ///
  /// `qr` ham URL değil mevcut token'dır; tarama ekranı ikisini de zaten
  /// destekler ve token'ı tekrar kamera önüne tutmayı gerektirmez.
  String studentDestination() => Uri(
    path: Routes.studentHome,
    queryParameters: <String, String>{'openEventId': eventId, 'qr': token},
  ).toString();

  String clubDestination() => Uri(
    path: Routes.clubEventDetail,
    queryParameters: <String, String>{'eventId': eventId},
  ).toString();
}

/// Doğrudan QR rotası ya da onboarding'e taşınmış `continue` değeri içinden
/// güvenli QR hedefini döndürür.
CheckinQrDeepLink? externalQrLinkForUri(Uri uri) {
  final CheckinQrDeepLink? direct = CheckinQrDeepLink.parse(uri);
  if (direct != null) return direct;

  final String? raw = uri.queryParameters[kExternalQrContinueParam];
  if (raw == null || raw.isEmpty) return null;
  return CheckinQrDeepLink.parse(Uri.tryParse(raw) ?? Uri());
}

/// Router'ın geçici onboarding hedeflerine mevcut QR isteğini güvenli biçimde
/// ekler. Geçersiz/değiştirilmiş istekler bilinçli olarak taşınmaz.
String routeWithExternalQrContinuation(String target, Uri currentUri) {
  final CheckinQrDeepLink? link = externalQrLinkForUri(currentUri);
  if (link == null) return target;

  final Uri targetUri = Uri.parse(target);
  return targetUri
      .replace(
        queryParameters: <String, String>{
          ...targetUri.queryParameters,
          kExternalQrContinueParam: Uri(
            path: Routes.qrEntry,
            queryParameters: <String, String>{kQrTokenParam: link.token},
          ).toString(),
        },
      )
      .toString();
}

/// Onaylanmış kulüp durumuna göre hedef rota.
///
/// Kulüp hesabı da öğrencideki gibi, bilgi formu tamamlandıktan sonra SMS ile
/// telefonunu doğrulamak zorundadır. Aynı Firebase Auth kimliği altında ikinci
/// rol sonradan açılırsa doğrulama ortak olduğundan tekrar SMS istenmez.
String getClubRouteByStatus(ClubProfile? profile) {
  if (profile == null || !profile.onboardingCompleted) {
    return Routes.clubOnboarding;
  }

  // Engellenen kulüp, eski bir kayıttan telefon bayrağı eksik olsa bile
  // doğrulama ekranına değil doğrudan yasaklı duruma gider.
  if (profile.clubStatus == ClubStatus.banned) return Routes.banned;

  if (!profile.phoneVerified) return Routes.phoneVerify;

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

/// Aktif rol çözümü: önce cihazda saklanan seçim, sonra `lastRole`, sonra
/// `role`.
///
/// Yalnızca bilgi formu başarıyla kaydedilmiş roller kabul edilir. Eski
/// sürümlerin rol seçildiği anda oluşturduğu `onboardingCompleted: false`
/// iskeletleri böylece gerçek hesap gibi davranıp kullanıcıyı aynı forma
/// kilitlemez.
String? resolveCompletedRole({
  required String? storedRole,
  required AppUser? user,
  required bool hasCompletedStudentRole,
  required bool hasCompletedClubRole,
}) {
  bool isCompleted(String? role) => switch (role) {
    UserRole.student => hasCompletedStudentRole,
    UserRole.club => hasCompletedClubRole,
    _ => false,
  };

  if (isCompleted(storedRole)) return storedRole;
  if (isCompleted(user?.lastRole)) return user!.lastRole;
  if (isCompleted(user?.role)) return user!.role;

  // Eski/kısmi bir users belgesinde role veya lastRole bozuk olsa bile tek
  // tamamlanmış profil varsa kullanıcı o hesaba güvenle alınabilir.
  if (hasCompletedStudentRole != hasCompletedClubRole) {
    return hasCompletedStudentRole ? UserRole.student : UserRole.club;
  }
  return null;
}

/// Henüz kaydedilmemiş rol yalnızca kendi bilgi formuna erişim verir.
String? onboardingRouteForPendingRole(String? role) => switch (role) {
  UserRole.student => Routes.studentOnboarding,
  UserRole.club => Routes.clubOnboarding,
  _ => null,
};

/// Bir rotanın öğrenci alanına ait olup olmadığı (guard'da kullanılır).
bool isStudentRoute(String location) =>
    location.startsWith(Routes.studentHome) ||
    location == Routes.studentOnboarding;

bool isClubRoute(String location) =>
    location.startsWith(Routes.clubHome) || location == Routes.clubOnboarding;

bool isAdminRoute(String location) => location.startsWith(Routes.adminHome);
