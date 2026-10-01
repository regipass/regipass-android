/// Web'de her sayfanın başındaki `onAuthStateChanged` bloğu kendi
/// yönlendirmesini yapıyordu (20+ dosyada tekrarlanan aynı mantık).
/// Burada tüm bu kararlar tek bir `redirect` fonksiyonunda toplanır —
/// davranış aynı, ama kural tek yerde.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../domain/legal_reconsent.dart';
import '../domain/routing.dart';
import '../features/admin/admin_clubs_screen.dart';
import '../features/admin/admin_notifications_screen.dart';
import '../features/admin/admin_screens.dart';
import '../features/admin/admin_shell.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/phone_change_screen.dart';
import '../features/auth/phone_verify_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_select_screen.dart';
import '../features/club/club_account_screen.dart';
import '../features/event_link/event_link_screen.dart';
import '../features/club/club_blocked_students_screen.dart';
import '../features/club/club_create_event_screen.dart';
import '../features/club/club_dashboard_screen.dart';
import '../features/club/club_documents_screen.dart';
import '../features/club/club_event_detail_screen.dart';
import '../features/club/club_event_notifications_screen.dart';
import '../features/club/club_events_screen.dart';
import '../features/club/club_notifications_screen.dart';
import '../features/club/club_pending_screen.dart';
import '../features/club/club_qr_checkin_screen.dart';
import '../features/club/club_session_qr_screen.dart';
import '../features/club/club_shell.dart';
import '../features/explore/explore_screen.dart';
import '../features/landing/login_screen.dart';
import '../features/onboarding/club_info_screen.dart';
import '../features/onboarding/student_info_screen.dart';
import '../features/student/student_account_screen.dart';
import '../features/student/student_appointments_screen.dart';
import '../features/student/student_certificates_screen.dart';
import '../features/student/student_dashboard_screen.dart';
import '../features/student/student_notifications_screen.dart';
import '../features/student/student_qr_checkin_screen.dart';
import '../features/student/student_qr_generate_screen.dart';
import '../features/student/student_shell.dart';
import '../features/legal/legal_update_screen.dart';
import '../services/event_link_service.dart';
import '../state/providers.dart';
import 'demo_mode.dart';

/// Oturum değiştiğinde router'ı yeniden değerlendirmek için köprü.
/// (go_router'ın `refreshListenable` beklentisi.)
class _SessionRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

Page<void> _instantPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _SessionRefresh refresh = _SessionRefresh();
  ref.onDispose(refresh.dispose);

  // Oturumun herhangi bir parçası değişince yönlendirme yeniden çalışır.
  ref.listen<Session>(
    sessionProvider,
    (Session? _, Session _) => refresh.ping(),
  );

  return GoRouter(
    initialLocation: Routes.landing,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) =>
        _resolveRedirect(ref.read(sessionProvider), state.uri),
    routes: <RouteBase>[
      GoRoute(
        path: Routes.landing,
        pageBuilder: (_, state) => _instantPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: Routes.explore,
        pageBuilder: (_, state) => _instantPage(state, const ExploreScreen()),
      ),
      // Telefon kamerasının okuduğu HTTPS QR linki. Uygulama kurulu değilse
      // aynı adres webdeki `qr.html` tarafından karşılanır; kuruluysa App
      // Link/Universal Link bu rotayı doğrudan Flutter'a verir.
      GoRoute(
        path: Routes.qrEntry,
        pageBuilder: (_, state) => _instantPage(
          state,
          ExploreScreen(
            initialEventId: CheckinQrDeepLink.parse(state.uri)?.eventId ?? '',
            externalQrUri: state.uri,
          ),
        ),
      ),
      GoRoute(
        path: Routes.eventLink,
        pageBuilder: (_, GoRouterState state) => _instantPage(
          state,
          EventLinkScreen(code: state.pathParameters['code'] ?? ''),
        ),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _instantPage(
              state,
              ForgotPasswordScreen(
                email: state.uri.queryParameters['email'] ?? '',
              ),
            ),
      ),
      GoRoute(
        path: Routes.register,
        pageBuilder: (_, state) => _instantPage(state, const RegisterScreen()),
      ),
      GoRoute(
        path: Routes.roleSelect,
        pageBuilder: (_, state) =>
            _instantPage(state, const RoleSelectScreen()),
      ),

      // ── Onboarding ────────────────────────────────────────────────
      GoRoute(
        path: Routes.studentOnboarding,
        pageBuilder: (_, state) =>
            _instantPage(state, const StudentInfoScreen()),
      ),
      GoRoute(
        path: Routes.clubOnboarding,
        pageBuilder: (_, state) => _instantPage(state, const ClubInfoScreen()),
      ),
      GoRoute(
        path: Routes.phoneVerify,
        pageBuilder: (_, state) =>
            _instantPage(state, const PhoneVerifyScreen()),
      ),
      GoRoute(
        path: Routes.legalUpdate,
        pageBuilder: (_, state) =>
            _instantPage(state, const LegalUpdateScreen()),
      ),
      GoRoute(
        path: Routes.phoneChange,
        pageBuilder: (_, state) =>
            _instantPage(state, const PhoneChangeScreen()),
      ),

      // ── Öğrenci ───────────────────────────────────────────────────
      // Alt gezinme çubuğu kalıcıdır; web'deki yan çekmecenin karşılığı.
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            StudentShell(location: state.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.studentHome,
            builder: (BuildContext context, GoRouterState state) =>
                StudentDashboardScreen(
                  openEventId: state.uri.queryParameters['openEventId'],
                  externalQrToken: state.uri.queryParameters['qr'],
                ),
          ),
          GoRoute(
            path: Routes.studentAppointments,
            // `open`: QR okutma ekranı, giriş onaylandıktan sonra öğrenciyi
            // ilgili etkinliğin detay penceresi açık olarak buraya döndürür.
            builder: (BuildContext context, GoRouterState state) =>
                StudentAppointmentsScreen(
                  openRegistrationId: state.uri.queryParameters['open'],
                  feedbackEventId: state.uri.queryParameters['feedbackEventId'],
                ),
          ),
          GoRoute(
            path: Routes.studentQrGenerate,
            builder: (_, _) => const StudentQrGenerateScreen(),
          ),
          GoRoute(
            path: Routes.studentQrCheckin,
            // `eventId`: etkinlik penceresinden gelindiyse yalnızca o
            // etkinliğin oturum QR'ı kabul edilir.
            builder: (BuildContext context, GoRouterState state) =>
                StudentQrCheckinScreen(
                  expectedEventId: state.uri.queryParameters['eventId'],
                  initialQrValue: state.uri.queryParameters['payload'],
                ),
          ),
          GoRoute(
            path: Routes.studentCertificates,
            builder: (_, _) => const StudentCertificatesScreen(),
          ),
          GoRoute(
            path: Routes.studentAccount,
            builder: (_, _) => const StudentAccountScreen(),
          ),
          GoRoute(
            path: Routes.studentNotifications,
            builder: (_, _) => const StudentNotificationsScreen(),
          ),
        ],
      ),

      // ── Kulüp ─────────────────────────────────────────────────────
      // Alt gezinme çubuğu öğrenci tarafındaki gibi kalıcıdır; belge yükleme
      // ve onay bekleme ekranları kapının dışında kaldığı için kabuğun
      // dışındadır (o aşamada gezinecek bir panel yok).
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            ClubShell(location: state.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.clubHome,
            builder: (BuildContext context, GoRouterState state) =>
                ClubDashboardScreen(
                  openEventId: state.uri.queryParameters['openEventId'],
                ),
          ),
          GoRoute(
            path: Routes.clubEvents,
            // QR ile başarılı girişten dönüldüğünde, ilgili etkinliğin
            // penceresi liste yüklenir yüklenmez otomatik açılır.
            builder: (BuildContext context, GoRouterState state) =>
                ClubEventsScreen(
                  openEventId: state.uri.queryParameters['openEventId'],
                ),
          ),
          GoRoute(
            path: Routes.clubEventDetail,
            builder: (BuildContext context, GoRouterState state) =>
                ClubEventDetailScreen(
                  eventId: state.uri.queryParameters['eventId'] ?? '',
                ),
          ),
          GoRoute(
            path: Routes.clubCreateEvent,
            builder: (BuildContext context, GoRouterState state) =>
                ClubCreateEventScreen(
                  eventId: state.uri.queryParameters['eventId'],
                ),
          ),
          GoRoute(
            path: Routes.clubQrCheckin,
            builder: (BuildContext context, GoRouterState state) =>
                ClubQrCheckinScreen(
                  eventId: state.uri.queryParameters['eventId'],
                ),
          ),
          GoRoute(
            path: Routes.clubSessionQr,
            builder: (_, _) => const ClubSessionQrScreen(),
          ),
          GoRoute(
            path: Routes.clubAccount,
            builder: (_, _) => const ClubAccountScreen(),
          ),
          GoRoute(
            path: Routes.clubNotifications,
            builder: (_, _) => const ClubNotificationsScreen(),
          ),
          GoRoute(
            path: Routes.clubEventNotifications,
            builder: (BuildContext context, GoRouterState state) =>
                ClubEventNotificationsScreen(
                  eventId: state.uri.queryParameters['eventId'],
                ),
          ),
          GoRoute(
            path: Routes.clubBlockedStudents,
            builder: (_, _) => const ClubBlockedStudentsScreen(),
          ),
        ],
      ),

      GoRoute(
        path: Routes.clubDocuments,
        builder: (_, _) => const ClubDocumentsScreen(),
      ),
      GoRoute(
        path: Routes.clubPending,
        builder: (_, _) => const ClubPendingScreen(),
      ),

      // ── Yönetici ──────────────────────────────────────────────────
      // admin-nav.js'teki çekmecenin karşılığı: kalıcı alt sekme çubuğu.
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AdminShell(location: state.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.adminHome,
            builder: (_, _) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: Routes.adminStats,
            builder: (_, _) => const AdminStatsScreen(),
          ),
          GoRoute(
            path: Routes.adminClubs,
            builder: (_, _) => const AdminClubsScreen(),
          ),
          GoRoute(
            path: Routes.adminBan,
            builder: (_, _) => const AdminBanScreen(),
          ),
          GoRoute(
            path: Routes.adminNotifications,
            builder: (_, _) => const AdminNotificationsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Tek yönlendirme kuralı. Saf fonksiyon — yan etkisi yok, test edilebilir.
///
/// Ban tespitinde oturum kapatma yan etkisi burada değil, `RegipassApp`
/// içindeki dinleyicide yapılır (bkz. lib/app/app.dart).
@visibleForTesting
String? resolveRedirectForTest(Session session, String location) =>
    _resolveRedirect(session, Uri.parse(location));

@visibleForTesting
String? resolveRedirectUriForTest(Session session, Uri uri) =>
    _resolveRedirect(session, uri);

String? _resolveRedirect(Session session, Uri uri) {
  final String location = uri.path;
  // Kayıt ekranı "bu e-postaya ait hesapta bu rol zaten var mı" diye
  // bakıyor. Soruyu sorabilmek için oturum bir an açılır; bu oturum bir
  // GİRİŞ değildir ve rol zaten varsa hemen kapatılır. Bu aralıkta
  // yönlendirme yapılırsa kullanıcı uyarıyı hiç görmeden panele düşer.
  if (session.isProbingAccount) return null;

  // Profil dokümanları henüz yüklenmediyse karar verilemez; mevcut ekran
  // (açılışta LoginScreen) yükleniyor göstergesini çizer.
  if (session.isLoading) return null;

  // ── Şifre sıfırlama ─────────────────────────────────────────────
  // SMS kodu Firebase Auth oturumu açar; şifre ve hedef hesap seçimi
  // tamamlanana kadar rol seçimi/panel ekranı bu akışı kesmemeli.
  if (session.isResettingPassword) {
    return location == Routes.forgotPassword ? null : Routes.forgotPassword;
  }

  // Bu rota hem oturumsuz hem oturumlu erişime açık olmalı: SMS kodu
  // doğrulandığı anda kullanıcı Auth'a giriş yapmış olur (şifre değiştirmek
  // oturum gerektiriyor). Aksi hâlde router onu tam o anda panele fırlatır
  // ve kullanıcı yeni şifresini hiç giremez.
  if (location == Routes.forgotPassword) return null;

  // ── Oturum yok ──────────────────────────────────────────────────
  // Keşfet giriş gerektirmez: misafir vitrini bilerek herkese açık.
  if (!session.isSignedIn) {
    const Set<String> publicRoutes = <String>{
      Routes.landing,
      Routes.register,
      Routes.explore,
      Routes.qrEntry,
    };
    if (location.startsWith(Routes.eventLinkPrefix)) return null;
    return publicRoutes.contains(location) ? null : Routes.landing;
  }

  // İP-EL: link oturum açıkken ama hesap henüz tamamlanmamışken geldiyse,
  // kurulum bitince o etkinliğe dönülsün diye kod saklanır.
  final bool isEventLink = location.startsWith(Routes.eventLinkPrefix);
  if (isEventLink) {
    final String key = eventLinkKeyFromPath(location);
    if (key.isNotEmpty) pendingEventLinkCode = key;
  }

  // ── Yönetici ────────────────────────────────────────────────────
  if (session.isAdmin) {
    return isAdminRoute(location) ? null : Routes.adminHome;
  }
  if (isAdminRoute(location)) return Routes.landing;

  // ── Henüz kaydedilmemiş rol ─────────────────────────────────────
  // Yeni hesapta (veya mevcut hesaba ikinci rol eklerken) rol seçimi yalnız
  // bellekte tutulur. Bu aşamada kullanıcı sadece ilgili bilgi formuna
  // girebilir; form başarıyla kaydedilince pendingRole temizlenir.
  final String? pendingTarget = onboardingRouteForPendingRole(
    session.pendingRole,
  );
  if (pendingTarget != null) {
    return location == pendingTarget
        ? null
        : routeWithExternalQrContinuation(pendingTarget, uri);
  }

  // ── Rol seçimi ──────────────────────────────────────────────────
  // TEK durumda gösterilir: hesapta hiç TAMAMLANMIŞ rol yok (ilk
  // Google/Apple/e-posta kaydı ya da eski yarım iskelet). Kullanıcı burada
  // hesabının TÜRÜNÜ seçer.
  //
  // Eskiden ikinci bir dal daha vardı: her iki rolü de olan hesaba "hangisiyle
  // devam edeceksin" diye soruluyordu. Bir e-postaya artık tek rol
  // bağlanabildiği için (bkz. RegisterScreen ve docs/telefon-sahiplik-kurali.md)
  // o soru kalktı. Kural gelmeden önce açılmış çift rollü hesaplar soru
  // sorulmadan `resolvedRole`a — yani `lastRole`a — düşer; hiçbir belge
  // silinmediği için ikinci rolün verisi Firestore'da durur.
  final String? role = session.resolvedRole;
  if (role == null) {
    return location == Routes.roleSelect
        ? null
        : routeWithExternalQrContinuation(Routes.roleSelect, uri);
  }
  if (location == Routes.roleSelect) {
    // Seçim yapıldı; role göre hedefe düş.
    return routeWithExternalQrContinuation(_homeFor(role, session), uri);
  }

  // ── Rol içi durum kapıları ──────────────────────────────────────
  final String target = role == UserRole.club
      ? getClubRouteByStatus(session.clubProfile)
      : getStudentRouteByStatus(session.studentProfile);

  if (target == Routes.banned) return Routes.landing;

  final bool isFullyOnboarded =
      target == Routes.studentHome || target == Routes.clubHome;

  if (!isFullyOnboarded) {
    // Telefon doğrulama ekranından numara değiştirmeye geçişe izin verilir
    // (phone-verify.html üzerindeki "Numarayı Değiştir" bağlantısı).
    if (target == Routes.phoneVerify && location == Routes.phoneChange) {
      return null;
    }

    // Onay beklerken yanlış belge yüklendiği fark edilirse kulüp belge
    // ekranına geri dönebilmeli (club-pending üzerindeki "Belgeleri Düzenle").
    // Bu istisna olmasa kapı kullanıcıyı tam o anda bekleme ekranına geri
    // fırlatır ve hatalı belge düzeltilemez.
    if (target == Routes.clubPending && location == Routes.clubDocuments) {
      return null;
    }

    return location == target
        ? null
        : routeWithExternalQrContinuation(target, uri);
  }

  // ── İP-HK: güncellenen sözleşmelerin yeniden onayı ──────────────
  // Daha önce onay vermiş ama güncel sürümü onaylamamış kullanıcı panele
  // geçmeden önce bir kez onay ekranını görür (demo uygulamasında yok).
  if (!kDemoMode && needsLegalReconsent(session.appUser)) {
    return location == Routes.legalUpdate ? null : Routes.legalUpdate;
  }

  // Giriş, rol seçimi, profil formu ve SMS doğrulaması bitince kullanıcıyı
  // başlangıç paneline değil QR'ın işaret ettiği etkinliğe döndür. Böylece
  // dış kamera ile okutulan kod için ikinci bir uygulama içi tarama gerekmez.
  final CheckinQrDeepLink? externalQr = externalQrLinkForUri(uri);
  if (externalQr != null) {
    return role == UserRole.student
        ? externalQr.studentDestination()
        : externalQr.clubDestination();
  }

  // ── Tam yetkili: kendi rol alanının dışına çıkamaz ───────────────
  // Tek istisna hesap yönetimi ekranları: bilgi formu (düzenleme modu) ve
  // numara değiştirme, panelin dışında yaşayan ama panele ait sayfalardır.
  // Bunlar dışlanırsa "Bilgileri Düzenle" / "Numaramı Değiştir" düğmeleri
  // kullanıcıyı anında panele geri fırlatır.
  if (location == Routes.phoneChange) return null;

  // İP-EL: link ekranı etkinliği çözüp kullanıcıyı kendi paneline götürür.
  if (isEventLink) {
    pendingEventLinkCode = null;
    return null;
  }
  final String? pendingLink = pendingEventLinkCode;
  if (pendingLink != null) {
    pendingEventLinkCode = null;
    return '${Routes.eventLinkPrefix}$pendingLink';
  }

  if (role == UserRole.student) {
    if (location == Routes.studentOnboarding) return null;
    return location.startsWith(Routes.studentHome) ? null : Routes.studentHome;
  }
  if (location == Routes.clubOnboarding) return null;
  return location.startsWith(Routes.clubHome) ? null : Routes.clubHome;
}

String _homeFor(String role, Session session) {
  final String target = role == UserRole.club
      ? getClubRouteByStatus(session.clubProfile)
      : getStudentRouteByStatus(session.studentProfile);

  // Engellenmiş kullanıcı hiçbir iç sayfaya gidemez.
  return target == Routes.banned ? Routes.landing : target;
}
