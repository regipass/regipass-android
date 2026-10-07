/// Uygulama genelindeki Riverpod sağlayıcıları.
///
/// Web'deki `onAuthStateChanged` + `onSnapshot` zinciri burada birbirine
/// bağlı stream sağlayıcılarına dönüşür: oturum değişince profil akışları
/// kendiliğinden yeniden kurulur.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../domain/plans.dart';
import '../domain/routing.dart';
import '../domain/staff_access.dart';
import '../models/event.dart';
import '../models/profiles.dart';
import '../services/account_cleanup_repository.dart';
import '../services/admin_repository.dart';
import '../services/announcement_repository.dart';
import '../services/attendance_service.dart';
import '../services/auth_repository.dart';
import '../services/event_reminder_scheduler.dart';
import '../services/event_repository.dart';
import '../services/inbox_repository.dart';
import '../services/notification_read_store.dart';
import '../services/notification_service.dart';
import '../services/online_service.dart';
import '../services/phone_directory_repository.dart';
import '../services/phone_hint_repository.dart';
import '../services/plan_service.dart';
import '../services/password_reset_auth_session.dart';
import '../services/profile_repository.dart';
import '../services/registration_service.dart';
import '../services/role_session_store.dart';

// ── Altyapı ───────────────────────────────────────────────────────────

/// `main()` içinde gerçek örnekle override edilir.
final Provider<RoleSessionStore> roleSessionStoreProvider =
    Provider<RoleSessionStore>((Ref ref) {
      throw UnimplementedError(
        'roleSessionStoreProvider main() içinde override edilmeli',
      );
    });

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => const AuthRepository());

final Provider<PasswordResetAuthSession Function()>
passwordResetSessionFactoryProvider =
    Provider<PasswordResetAuthSession Function()>(
      (Ref ref) => PasswordResetAuthSession.new,
    );

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) => const ProfileRepository());

final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>((Ref ref) => const EventRepository());

/// Kimliği verilen etkinliğin canlı Firestore kopyası.
///
/// Liste ekranlarının bir kısmı maliyeti sınırlamak için etkinlikleri tek
/// seferlik okuyor. Detay penceresi bu sağlayıcıyı izlediğinde pencere açıkken
/// etkinlik ya da etkinliğe kopyalanan kulüp bilgileri değişirse eski liste
/// nesnesine takılı kalmadan kendiliğinden yenilenir.
// ignore: always_specify_types
final eventByIdProvider = StreamProvider.family<AppEvent?, String>((
  Ref ref,
  String eventId,
) {
  if (eventId.isEmpty) return Stream<AppEvent?>.value(null);
  return ref.watch(eventRepositoryProvider).watchEvent(eventId);
});

/// Kontenjanı koruyan kayıt akışı. Eşzamanlılık politikası
/// `lib/domain/registration_capacity.dart` içinde, Firebase'e dokunmadan
/// test edilebilir hâlde durur.
final Provider<RegistrationService> registrationServiceProvider =
    Provider<RegistrationService>((Ref ref) => const RegistrationService());

/// İP-ON (mobil): Yayına katıl + yoklama kodu.
final Provider<OnlineService> onlineServiceProvider =
    Provider<OnlineService>((Ref ref) => const OnlineService());

/// İP-P1 (mobil): paket bilgisi.
final Provider<PlanService> planServiceProvider =
    Provider<PlanService>((Ref ref) => const PlanService());

/// Organizatörün paket özeti (her açılışta tazelenir). Hata → sistem kapalı say.
final FutureProvider<PlanSummary> myPlanProvider =
    FutureProvider.autoDispose<PlanSummary>((Ref ref) async {
  try {
    return await ref.watch(planServiceProvider).getMyPlan();
  } catch (_) {
    return const PlanSummary(enabled: false);
  }
});

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>((Ref ref) => const AdminRepository());

final Provider<PhoneHintRepository> phoneHintRepositoryProvider =
    Provider<PhoneHintRepository>((Ref ref) => const PhoneHintRepository());

final Provider<PhoneDirectoryRepository> phoneDirectoryRepositoryProvider =
    Provider<PhoneDirectoryRepository>(
      (Ref ref) => const PhoneDirectoryRepository(),
    );

final Provider<AnnouncementRepository> announcementRepositoryProvider =
    Provider<AnnouncementRepository>(
      (Ref ref) => const AnnouncementRepository(),
    );

/// Yoklama ve giriş sunucuda (İP-Y).
final Provider<AttendanceService> attendanceServiceProvider =
    Provider<AttendanceService>((Ref ref) => const AttendanceService());

/// Kişiye özel gelen kutusu (İP-6).
final Provider<InboxRepository> inboxRepositoryProvider =
    Provider<InboxRepository>((Ref ref) => const InboxRepository());

final Provider<AccountCleanupRepository> accountCleanupRepositoryProvider =
    Provider<AccountCleanupRepository>(
      (Ref ref) => const AccountCleanupRepository(),
    );

/// Oturum kendiliğinden kapatıldığında giriş ekranında gösterilecek çeviri
/// anahtarı.
///
/// Telefonunu doğrulamayan öğrencinin kaydı açılışta silinip oturumu
/// kapatılıyor (bkz. lib/domain/account_expiry.dart). Bu değer olmadan
/// kullanıcı kendini hiçbir açıklama olmadan giriş ekranında bulur ve
/// hesabının neden kaybolduğunu öğrenemezdi. Çeviri anahtarı saklanır,
/// çevrilmiş metin değil: dil değişince metin de değişsin.
class SignOutNoticeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String translationKey) => state = translationKey;

  void clear() => state = null;
}

final NotifierProvider<SignOutNoticeNotifier, String?> signOutNoticeProvider =
    NotifierProvider<SignOutNoticeNotifier, String?>(SignOutNoticeNotifier.new);

// ── Bildirim ──────────────────────────────────────────────────────────

/// Cihaz bildirimleri. Eklenti tek örnekli olduğu için servis de tekil;
/// sağlayıcı yalnızca erişimi test edilebilir kılar.
final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => NotificationService.instance);

/// Etkinlik hatırlatmalarının kurulumu. Durum (hangi alarm kuruldu)
/// nesnenin içinde tutulduğu için ömrü uygulama ömrüyle aynı olmalı —
/// `autoDispose` yok.
final Provider<EventReminderScheduler> eventReminderSchedulerProvider =
    Provider<EventReminderScheduler>(
      (Ref ref) =>
          EventReminderScheduler(ref.watch(notificationServiceProvider)),
    );

/// `main()` içinde gerçek örnekle override edilir.
final Provider<NotificationReadStore> notificationReadStoreProvider =
    Provider<NotificationReadStore>((Ref ref) {
      throw UnimplementedError(
        'notificationReadStoreProvider main() içinde override edilmeli',
      );
    });

// ── Oturum ────────────────────────────────────────────────────────────

final StreamProvider<User?> authStateProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// İP-M1: oturumun yönetim yetkisi (rol etiketi + doğrulayıcı kodu).
/// ID token'dan okunur; token okunamazsa yönetim yetkisi YOK sayılır.
final FutureProvider<StaffAccess> staffAccessProvider =
    FutureProvider<StaffAccess>((Ref ref) async {
      final User? user = ref.watch(authStateProvider).value;
      if (user == null) return StaffAccess.none;
      try {
        final IdTokenResult token = await user.getIdTokenResult();
        return StaffAccess.fromClaims(token.claims);
      } catch (_) {
        return StaffAccess.none;
      }
    });

/// Giriş yapmış kullanıcının uid'i (yoksa null).
final Provider<String?> currentUidProvider = Provider<String?>(
  (Ref ref) => ref.watch(authStateProvider).value?.uid,
);

final StreamProvider<AppUser?> appUserProvider = StreamProvider<AppUser?>((
  Ref ref,
) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<AppUser?>.value(null);
  return ref.watch(profileRepositoryProvider).watchUser(uid);
});

final StreamProvider<StudentProfile?> studentProfileProvider =
    StreamProvider<StudentProfile?>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream<StudentProfile?>.value(null);
      return ref.watch(profileRepositoryProvider).watchStudentProfile(uid);
    });

final StreamProvider<ClubProfile?> clubProfileProvider =
    StreamProvider<ClubProfile?>((Ref ref) {
      final String? uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream<ClubProfile?>.value(null);
      return ref.watch(profileRepositoryProvider).watchClubProfile(uid);
    });

/// Kullanıcının bu cihazda seçtiği aktif rol.
///
/// Web'de rol seçimi localStorage'a yazılıyor ve her sayfa açılışında
/// okunuyordu; burada tek bir gözlemlenebilir durum olarak tutulur.
class ActiveRoleNotifier extends Notifier<String?> {
  @override
  String? build() {
    final String? uid = ref.watch(currentUidProvider);
    return ref.read(roleSessionStoreProvider).getActiveRole(uid);
  }

  Future<void> select(String role) async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await selectForUser(uid, role);
  }

  /// Telefonla giriş sonucu `authStateProvider`a ulaşmadan hemen önce de rol
  /// seçilebilsin diye uid'i çağırandan alan sürüm.
  Future<void> selectForUser(String uid, String role) async {
    if (uid.isEmpty || !UserRole.isValid(role)) return;

    state = role;
    await ref.read(roleSessionStoreProvider).setActiveRole(uid, role);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(roleSessionStoreProvider).clear();
  }
}

final NotifierProvider<ActiveRoleNotifier, String?> activeRoleProvider =
    NotifierProvider<ActiveRoleNotifier, String?>(ActiveRoleNotifier.new);

/// Bilgi formu henüz kaydedilmemişken seçilen rol.
///
/// Bu değer bilerek yalnız bellekte tutulur. Uygulama kapanırsa veya kullanıcı
/// çıkış yaparsa seçim unutulur; Firestore'a ya da SharedPreferences'a hiçbir
/// yarım hesap bilgisi yazılmaz.
class PendingOnboardingRoleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String role) {
    if (UserRole.isValid(role)) state = role;
  }

  void clear() => state = null;
}

final NotifierProvider<PendingOnboardingRoleNotifier, String?>
pendingOnboardingRoleProvider =
    NotifierProvider<PendingOnboardingRoleNotifier, String?>(
      PendingOnboardingRoleNotifier.new,
    );

/// Kayıt ekranında verilen onay — bilgi formu kaydedilene kadar bellekte
/// tutulur, sonra profil belgesine yazılıp temizlenir (bkz.
/// [PendingOnboardingRoleNotifier] ile aynı gerekçe: kalıcı depoya hiçbir
/// yarım hesap bilgisi yazılmaz).
class PendingConsent {
  const PendingConsent({
    required this.termsAccepted,
    required this.marketingConsent,
    required this.acceptedAtMs,
    this.ageConfirmed = false,
  });

  final bool termsAccepted;
  final bool marketingConsent;
  final int acceptedAtMs;

  /// İP-G4: "18 yaşından büyüğüm" beyanı (zorunlu).
  final bool ageConfirmed;
}

class PendingConsentNotifier extends Notifier<PendingConsent?> {
  @override
  PendingConsent? build() => null;

  void set({
    required bool termsAccepted,
    required bool marketingConsent,
    bool? ageConfirmed,
  }) {
    state = PendingConsent(
      termsAccepted: termsAccepted,
      marketingConsent: marketingConsent,
      acceptedAtMs: DateTime.now().millisecondsSinceEpoch,
      // Verilmezse önceki beyan korunur (kutular ayrı ayrı değişir).
      ageConfirmed: ageConfirmed ?? state?.ageConfirmed ?? false,
    );
  }

  void setAge(bool value) => set(
    termsAccepted: state?.termsAccepted ?? false,
    marketingConsent: state?.marketingConsent ?? false,
    ageConfirmed: value,
  );

  void clear() => state = null;
}

final NotifierProvider<PendingConsentNotifier, PendingConsent?>
pendingConsentProvider =
    NotifierProvider<PendingConsentNotifier, PendingConsent?>(
      PendingConsentNotifier.new,
    );

/// Kayıt ekranının "bu hesapta bu rol zaten var mı" yoklaması sürüyor.
///
/// Rol bilgisi Firestore'da ve o belgeleri yalnız hesabın SAHİBİ okuyabiliyor
/// (bkz. firestore.rules). Yani soruyu sorabilmek için bir an oturum açmak
/// zorunlu. Bayrak açıkken router hiçbir yönlendirme yapmaz; aksi hâlde
/// yoklama için açılan oturum kullanıcıyı doğrudan panele fırlatıyor,
/// "bu hesap zaten var" uyarısı hiç görünmeden kayıt ekranı kapanıyordu.
class AuthProbeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void begin() => state = true;

  void end() => state = false;
}

final NotifierProvider<AuthProbeNotifier, bool> authProbeProvider =
    NotifierProvider<AuthProbeNotifier, bool>(AuthProbeNotifier.new);

/// Şifre sıfırlamada SMS kodu doğrulanınca Firebase Auth geçici olarak oturum
/// açar. Bu bayrak, kullanıcı yeni şifresini girmeden router'ın rol/panel
/// ekranına yönlendirmesini önler.
class PasswordResetInProgressNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void begin() => state = true;

  void end() => state = false;
}

final NotifierProvider<PasswordResetInProgressNotifier, bool>
passwordResetInProgressProvider =
    NotifierProvider<PasswordResetInProgressNotifier, bool>(
      PasswordResetInProgressNotifier.new,
    );

/// Router ve ekranların okuduğu birleşik oturum görüntüsü.
class Session {
  const Session({
    required this.isLoading,
    required this.user,
    required this.appUser,
    required this.studentProfile,
    required this.clubProfile,
    required this.activeRole,
    this.pendingRole,
    this.isProbingAccount = false,
    this.isResettingPassword = false,
    this.staff = StaffAccess.none,
  });

  final bool isLoading;
  final User? user;
  final AppUser? appUser;
  final StudentProfile? studentProfile;
  final ClubProfile? clubProfile;

  /// Cihazda saklanan seçim; `resolvedRole` bunu `lastRole`/`role` ile tamamlar.
  final String? activeRole;

  /// Kayıt formu tamamlanana kadar yalnız bellekte yaşayan rol seçimi.
  final String? pendingRole;

  /// Kayıt ekranı var olan bir hesabı yokluyor (bkz. [authProbeProvider]).
  /// Router bu sırada hiçbir yönlendirme yapmaz.
  final bool isProbingAccount;

  /// Şifre yenileme, SMS doğrulamasının açtığı geçici oturumda sürüyor.
  final bool isResettingPassword;

  /// İP-M1: rol etiketi + doğrulayıcı kodu (bkz. [StaffAccess]).
  final StaffAccess staff;

  bool get isSignedIn => user != null;

  /// Yönetim paneli (yönetici ya da destek; kodla açılmış oturum).
  /// Eskiden e-postaya bakıyordu (a@regipass.app); artık rol etiketine.
  bool get isAdmin => staff.isStaff;

  /// Engelleme/onay/duyuru gibi yazma işlemleri yalnızca yönetici rolünde.
  bool get canAdminWrite => staff.canWrite;

  bool get hasStudentRole => studentProfile?.onboardingCompleted ?? false;

  bool get hasClubRole => clubProfile?.onboardingCompleted ?? false;

  bool hasCompletedRole(String? role) => switch (role) {
    UserRole.student => hasStudentRole,
    UserRole.club => hasClubRole,
    _ => false,
  };

  bool get hasAnyRole => hasStudentRole || hasClubRole;

  /// Yalnız tamamlanmış profiller arasından aktif rolü çözer. Geçici
  /// onboarding rolü burada özellikle hesaba katılmaz; uygulamanın geri kalanı
  /// onu yetkili bir hesap sanmamalıdır.
  String? get resolvedRole => resolveCompletedRole(
    storedRole: activeRole,
    user: appUser,
    hasCompletedStudentRole: hasStudentRole,
    hasCompletedClubRole: hasClubRole,
  );
}

final Provider<Session> sessionProvider = Provider<Session>((Ref ref) {
  final AsyncValue<User?> auth = ref.watch(authStateProvider);
  final User? user = auth.value;
  final bool probing = ref.watch(authProbeProvider);
  final bool resettingPassword = ref.watch(passwordResetInProgressProvider);

  // Oturum yokken profil akışları beklenmez; aksi hâlde açılışta gereksiz
  // bir "yükleniyor" durumunda takılırdı.
  if (user == null) {
    return Session(
      isLoading: auth.isLoading,
      user: null,
      appUser: null,
      studentProfile: null,
      clubProfile: null,
      activeRole: null,
      pendingRole: null,
      isProbingAccount: probing,
      isResettingPassword: resettingPassword,
    );
  }

  final AsyncValue<StaffAccess> staff = ref.watch(staffAccessProvider);
  final AsyncValue<AppUser?> appUser = ref.watch(appUserProvider);
  final AppUser? userProfile = appUser.value;
  final String? activeRole = ref.watch(activeRoleProvider);
  final String? pendingRole = ref.watch(pendingOnboardingRoleProvider);

  // `roles` alanı eski sürümlerin yarım profil iskeletlerini de içeriyor
  // olabilir. Tamamlanıp tamamlanmadığını anlayabilmek için işaretli iki profil
  // de yüklenir; yalnız `onboardingCompleted: true` olanlar gerçek rol sayılır.
  final bool hasStudentRole = userProfile?.hasStudentRole ?? false;
  final bool hasClubRole = userProfile?.hasClubRole ?? false;
  // Pending/aktif rolün profili de dinlenir. Böylece final batch döndüğünde
  // profil snapshot'ı hemen tamamlanmış sayılır; users ve profil stream'lerinin
  // geliş sırası kısa süreli yanlış panele yönlendirme yaratmaz.
  final bool loadStudent =
      hasStudentRole ||
      pendingRole == UserRole.student ||
      activeRole == UserRole.student;
  final bool loadClub =
      hasClubRole ||
      pendingRole == UserRole.club ||
      activeRole == UserRole.club;

  final AsyncValue<StudentProfile?> student = loadStudent
      ? ref.watch(studentProfileProvider)
      : const AsyncData<StudentProfile?>(null);
  final AsyncValue<ClubProfile?> club = loadClub
      ? ref.watch(clubProfileProvider)
      : const AsyncData<ClubProfile?>(null);

  // Riverpod, akış yeniden kurulurken ÖNCEKİ değeri elinde tutar. Hesap
  // değiştiğinde bu, bir önceki kullanıcının profilini kısa bir süre yeni
  // kullanıcınınmış gibi gösteriyordu — yeni kayıtta bilgi formu eski
  // hesabın adı/telefonu/üniversitesiyle doluyordu. Bu yüzden uid'i
  // eşleşmeyen her profil yok sayılır.
  final AppUser? safeAppUser =
      userProfile != null && userProfile.uid == user.uid ? userProfile : null;

  final StudentProfile? safeStudent = student.value?.uid == user.uid
      ? student.value
      : null;

  final ClubProfile? safeClub = club.value?.uid == user.uid ? club.value : null;

  return Session(
    isLoading:
        staff.isLoading ||
        appUser.isLoading ||
        student.isLoading ||
        club.isLoading,
    user: user,
    appUser: safeAppUser,
    studentProfile: safeStudent,
    clubProfile: safeClub,
    activeRole: activeRole,
    pendingRole: pendingRole,
    isProbingAccount: probing,
    isResettingPassword: resettingPassword,
    staff: staff.value ?? StaffAccess.none,
  );
});
