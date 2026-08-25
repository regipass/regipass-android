/// Uygulama genelindeki Riverpod sağlayıcıları.
///
/// Web'deki `onAuthStateChanged` + `onSnapshot` zinciri burada birbirine
/// bağlı stream sağlayıcılarına dönüşür: oturum değişince profil akışları
/// kendiliğinden yeniden kurulur.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../domain/routing.dart';
import '../models/profiles.dart';
import '../services/account_cleanup_repository.dart';
import '../services/admin_repository.dart';
import '../services/announcement_repository.dart';
import '../services/auth_repository.dart';
import '../services/event_reminder_scheduler.dart';
import '../services/event_repository.dart';
import '../services/notification_read_store.dart';
import '../services/notification_service.dart';
import '../services/phone_directory_repository.dart';
import '../services/phone_hint_repository.dart';
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

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) => const ProfileRepository());

final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>((Ref ref) => const EventRepository());

/// Kontenjanı koruyan kayıt akışı. Eşzamanlılık politikası
/// `lib/domain/registration_capacity.dart` içinde, Firebase'e dokunmadan
/// test edilebilir hâlde durur.
final Provider<RegistrationService> registrationServiceProvider =
    Provider<RegistrationService>((Ref ref) => const RegistrationService());

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
      (Ref ref) => EventReminderScheduler(ref.watch(notificationServiceProvider)),
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
    if (uid == null || !UserRole.isValid(role)) return;

    await ref.read(roleSessionStoreProvider).setActiveRole(uid, role);
    state = role;
  }

  Future<void> clear() async {
    await ref.read(roleSessionStoreProvider).clear();
    state = null;
  }
}

final NotifierProvider<ActiveRoleNotifier, String?> activeRoleProvider =
    NotifierProvider<ActiveRoleNotifier, String?>(ActiveRoleNotifier.new);

/// Router ve ekranların okuduğu birleşik oturum görüntüsü.
class Session {
  const Session({
    required this.isLoading,
    required this.user,
    required this.appUser,
    required this.studentProfile,
    required this.clubProfile,
    required this.activeRole,
  });

  final bool isLoading;
  final User? user;
  final AppUser? appUser;
  final StudentProfile? studentProfile;
  final ClubProfile? clubProfile;

  /// Cihazda saklanan seçim; `resolvedRole` bunu `lastRole`/`role` ile tamamlar.
  final String? activeRole;

  bool get isSignedIn => user != null;

  bool get isAdmin => isAdminEmail(user?.email);

  /// role-session.js#resolvePreferredRole sırası.
  String? get resolvedRole => resolvePreferredRole(activeRole, appUser);

  /// Kullanıcının her iki rolü de varsa giriş sonrası rol seçimi gerekir.
  bool get hasBothRoles =>
      (appUser?.hasStudentRole ?? false) && (appUser?.hasClubRole ?? false);
}

final Provider<Session> sessionProvider = Provider<Session>((Ref ref) {
  final AsyncValue<User?> auth = ref.watch(authStateProvider);
  final User? user = auth.value;

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
    );
  }

  final AsyncValue<AppUser?> appUser = ref.watch(appUserProvider);
  final AppUser? userProfile = appUser.value;
  final String? activeRole = ref.watch(activeRoleProvider);

  // Tek rollü kullanıcıların açılışında diğer role ait boş profil belgesini
  // beklemiyoruz. İki rol varsa cihazdaki seçim hangi profilin gerekli
  // olduğunu belirler; henüz seçim yoksa router doğrudan rol seçimine geçer.
  final bool hasStudentRole = userProfile?.hasStudentRole ?? false;
  final bool hasClubRole = userProfile?.hasClubRole ?? false;
  final bool loadStudent =
      hasStudentRole && (!hasClubRole || activeRole == UserRole.student);
  final bool loadClub =
      hasClubRole && (!hasStudentRole || activeRole == UserRole.club);

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
    isLoading: appUser.isLoading || student.isLoading || club.isLoading,
    user: user,
    appUser: safeAppUser,
    studentProfile: safeStudent,
    clubProfile: safeClub,
    activeRole: activeRole,
  );
});
