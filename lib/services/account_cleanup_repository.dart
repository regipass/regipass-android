/// Telefonu doğrulanmamış öğrenci kaydının silinmesi.
///
/// Kural sunucu tarafında değil **istemcide** işletilir: proje Cloud Functions
/// içermiyor. Süresi dolmuş hesap zaten telefon doğrulama kapısının arkasında
/// kilitli olduğu için (bkz. `getStudentRouteByStatus`) uygulamayı açmadan
/// hiçbir şey yapamaz; kayıt, sahibi uygulamayı bir daha açtığında silinir.
/// Uygulamayı hiç açmayan hesabın kaydı Firestore'da kalır — bunu temizlemek
/// için zamanlanmış bir Cloud Function gerekir.
///
/// Yayındaki firestore.rules bu silmelere zaten izin veriyor
/// (`student_profiles`: `allow delete: if isOwner(userId)`, `users`:
/// `allow read, write: if isOwner(userId)`), ek kural yayınlamak gerekmez.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_log.dart';
import '../core/constants.dart';
import '../domain/event_utils.dart';
import '../models/event.dart';
import '../models/profiles.dart';
import 'firebase_refs.dart';
import 'phone_directory_repository.dart';
import 'phone_hint_repository.dart';
import 'registration_service.dart';

class AccountCleanupRepository {
  const AccountCleanupRepository({
    this.phoneDirectory = const PhoneDirectoryRepository(),
    this.phoneHints = const PhoneHintRepository(),
    this.registrations = const RegistrationService(),
  });

  final PhoneDirectoryRepository phoneDirectory;
  final PhoneHintRepository phoneHints;
  final RegistrationService registrations;

  /// Hiç tamamlanmış rolü olmayan eski Firestore taslaklarını temizler.
  ///
  /// Google/Apple ve e-posta kaydı Firebase Auth kimliğini formdan önce
  /// oluşturmak zorundadır; Auth ve Firestore arasında atomik işlem yoktur.
  /// Bu yüzden çıkış sırasında Auth kullanıcısını silmek, başka bir cihazın
  /// aynı anda tamamladığı profili yetim bırakabilir. Yalnız eski sürümlerin
  /// yarım Firestore iskeletleri transaction içinde temizlenir. Tamamlanmış
  /// öğrenci veya kulüp profili varsa hiçbir belgeye dokunulmaz.
  Future<bool> discardIfUnfinished(String uid) =>
      fbDb.runTransaction<bool>((Transaction transaction) async {
        final Doc userRef = userDoc(uid);
        final Doc studentRef = studentProfileDoc(uid);
        final Doc clubRef = clubProfileDoc(uid);

        final Snap userSnap = await transaction.get(userRef);
        final Snap studentSnap = await transaction.get(studentRef);
        final Snap clubSnap = await transaction.get(clubRef);
        final bool hasCompletedStudent =
            studentSnap.data()?['onboardingCompleted'] == true;
        final bool hasCompletedClub =
            clubSnap.data()?['onboardingCompleted'] == true;

        if (hasCompletedStudent || hasCompletedClub) return false;

        final bool hasFirestoreDraft =
            studentSnap.exists || clubSnap.exists || userSnap.exists;
        if (studentSnap.exists) transaction.delete(studentRef);
        if (clubSnap.exists) transaction.delete(clubRef);
        if (userSnap.exists) transaction.delete(userRef);
        return hasFirestoreDraft;
      });

  /// Öğrenci kaydını veritabanından siler.
  ///
  /// [keepAccount] hesapta AYRICA kulüp rolü varsa true olmalıdır: o durumda
  /// yalnızca öğrenci tarafı silinir, `users` dokümanı ve Firebase Auth hesabı
  /// kulüp için ayakta kalır.
  ///
  /// Sıra önemli: Firestore yazımları Auth hesabı silinmeden ÖNCE yapılır,
  /// aksi hâlde kurallar sahipliği doğrulayamaz ve silmeler reddedilir.
  ///
  /// Auth hesabının silinmesi "en iyi çaba"dır: `user.delete()` son girişin
  /// üzerinden uzun süre geçmişse `requires-recent-login` atar. O durumda
  /// veritabanı kaydı yine de silinmiş olur — kullanıcı aynı e-postayla
  /// tekrar giriş yaparsa sistem onu sıfırdan kaydolan biri gibi karşılar.
  Future<void> deleteUnverifiedStudent({
    required User user,
    required StudentProfile profile,
    required bool keepAccount,
  }) async {
    final String uid = user.uid;

    // Onboarding sırasında yüklenmiş profil fotoğrafı. En iyi çaba: dosya
    // yoksa ya da silinemezse kaydın silinmesi engellenmemeli.
    if (profile.photoPath.isNotEmpty) {
      try {
        await fbStorage.ref(profile.photoPath).delete();
      } catch (_) {
        // Yok say.
      }
    }

    // Numara doğrulanmadığı için dizinde olsa olsa bekleyen bir rezervasyon
    // vardır; onu bırak ki numara 15 dakika beklemeden serbest kalsın.
    if (profile.phone.isNotEmpty) {
      await phoneDirectory.release(phoneE164: profile.phone, uid: uid);
    }

    await studentProfileDoc(uid).delete();

    if (keepAccount) {
      await userDoc(uid).update(<String, dynamic>{
        'roles.student': FieldValue.delete(),
        'studentOnboardingCompleted': FieldValue.delete(),
        'role': UserRole.club,
        'lastRole': UserRole.club,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await userDoc(uid).delete();

    try {
      await user.delete();
    } catch (_) {
      // Bkz. yukarıdaki `requires-recent-login` notu.
    }
  }

  // ── Kullanıcının kendi isteğiyle hesabını silmesi ────────────────────

  /// Hesabı ve ona bağlı bütün kayıtları kalıcı olarak siler.
  ///
  /// Çağıran taraf kullanıcıyı işlemden hemen ÖNCE yeniden kimlik doğrulamış
  /// olmalıdır (`AuthRepository.reauthenticateWithPassword` ya da SMS'li
  /// eşi). Bu hem `user.delete()`in şartı hem de silmenin tek koruması:
  /// açık kalmış bir telefonu eline geçiren biri şifreyi bilmeden hesabı yok
  /// edememeli.
  ///
  /// **Sıra bilinçli.** Firestore ve Storage silmeleri Auth hesabı silinmeden
  /// önce yapılır; ters sırada `request.auth` boşalır, kurallar sahipliği
  /// doğrulayamaz ve geride kimsenin erişemeyeceği belgeler kalırdı. Proje
  /// Cloud Functions içermediği için temizliğin tamamı istemcidedir.
  ///
  /// Yan kayıtların temizliği (etkinlik kayıtları, sertifikalar, dosyalar,
  /// telefon dizini, şifre ipucu) **en iyi çabadır**: biri başarısız olursa
  /// hesabın silinmesi engellenmez, yoksa kullanıcı temizlenemeyen tek bir
  /// belge yüzünden hesabından hiç çıkamazdı. Profil belgeleri, `users`
  /// belgesi ve Auth hesabı ise zorunludur — silinemezlerse hata yukarı
  /// taşınır ve kullanıcı hesabının hâlâ durduğunu görür.
  Future<void> deleteAccount({
    required User user,
    StudentProfile? studentProfile,
    ClubProfile? clubProfile,
  }) async {
    final String uid = user.uid;

    if (studentProfile != null) {
      await _bestEffort(() => _cancelStudentRegistrations(uid));
      await _bestEffort(() => _deleteQuery(certificatesCol, 'studentId', uid));
      await _bestEffort(() => _deleteStorageObject(studentProfile.photoPath));
    }

    if (clubProfile != null) {
      await _bestEffort(() => _deleteClubEvents(uid));
      await _bestEffort(() => _deleteStorageObject(clubProfile.logoPath));
    }

    // Numara sahiplik dizininden düşürülmezse artık var olmayan bir uid'ye
    // ait görünür ve aynı kişi bile aynı numarayla yeniden kaydolamaz.
    final String phone = _accountPhone(
      user: user,
      studentProfile: studentProfile,
      clubProfile: clubProfile,
    );
    if (phone.isNotEmpty) {
      await _bestEffort(
        () => phoneDirectory.releaseOwned(phoneE164: phone, uid: uid),
      );
    }

    // "Şifremi unuttum" ekranının okuduğu maskeli ipucu. Yayındaki kural bu
    // koleksiyonda silmeye izin vermiyor olabilir; kalması zararsız (maske
    // zaten herkese açık okunabilir bir ipucu) ama denemeye değer.
    await _bestEffort(() => phoneHints.delete(user.email ?? ''));

    if (studentProfile != null) await studentProfileDoc(uid).delete();
    if (clubProfile != null) await clubProfileDoc(uid).delete();
    await userDoc(uid).delete();

    // En son: bu satırdan sonra hiçbir kural sahipliği doğrulayamaz.
    await user.delete();
  }

  /// Öğrencinin etkinlik kayıtları.
  ///
  /// İP-K (L4): kayıtlar sunucuda, kontenjan yeri aynı işlemde geri verilerek
  /// silinir; bekleme listesi girişleri de temizlenir. Çağrı başarısız olursa
  /// hesap silme durmaz: Auth hesabı silinince sunucudaki
  /// `releaseRegistrationsOnAccountDelete` aynı işi yeniden yapar. Geriye
  /// kalan belge (aşama 1) doğrudan silinir.
  Future<void> _cancelStudentRegistrations(String uid) async {
    try {
      await registrations.cancelAllMine();
    } catch (error) {
      AppLog.warn('account.cleanup.registrations', <String, Object?>{
        'error': '$error',
      });
    }

    final QSnap snap = await registrationsCol
        .where('studentId', isEqualTo: uid)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      await _bestEffort(() => doc.reference.delete());
    }
  }

  /// Kulübün etkinlikleri ve onlara bağlı her şey.
  ///
  /// Etkinlikleri bırakmak, sahibi olmayan ve kimsenin düzenleyemeyeceği
  /// ilanların Keşfet'te durmaya devam etmesi demekti.
  ///
  /// İP-K (L5): günü geçmemiş etkinlik istemciden silinemez; sunucu İPTAL
  /// eder (kayıtlılara bildirim gider) ya da hiç kaydı yoksa tamamen siler.
  /// Günü geçmiş etkinlikte eski yol sürer: kayıtlar ve kontenjan parçaları
  /// etkinlikten önce silinir; ters sırada etkinlik belgesi gidince kurallar
  /// "etkinliğin sahibi miyim" sorusunu yanıtlayamaz ve alt belgeler
  /// erişilemez hâlde kalırdı.
  Future<void> _deleteClubEvents(String uid) async {
    final QSnap events = await eventsCol.where('clubId', isEqualTo: uid).get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> event
        in events.docs) {
      final AppEvent parsed = AppEvent.fromMap(event.id, event.data());
      if (!isPastEvent(parsed)) {
        await _bestEffort(
          () => registrations.cancelEvent(
            eventId: event.id,
            reason: 'Organizatör hesabı kapatıldı.',
          ),
        );
        continue;
      }
      await _bestEffort(
        () => _deleteQuery(registrationsCol, 'eventId', event.id),
      );
      await _bestEffort(() => _deleteCollection(quotaShardsCol(event.id)));
      await _bestEffort(() => event.reference.delete());
    }
  }

  Future<void> _deleteQuery(Col collection, String field, String value) async {
    final QSnap snap = await collection.where(field, isEqualTo: value).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _deleteCollection(Col collection) async {
    final QSnap snap = await collection.get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _deleteStorageObject(String path) async {
    if (path.isEmpty) return;
    await fbStorage.ref(path).delete();
  }

  /// Auth'a bağlı numara doğruyu söyler (dizindeki kayıt ona göre yazıldı);
  /// eski hesaplarda boş olabildiği için profildeki numaraya düşülür.
  String _accountPhone({
    required User user,
    StudentProfile? studentProfile,
    ClubProfile? clubProfile,
  }) {
    final String linked = (user.phoneNumber ?? '').trim();
    if (linked.isNotEmpty) return linked;

    final String student = studentProfile?.phone.trim() ?? '';
    if (student.isNotEmpty) return student;

    return clubProfile?.phone.trim() ?? '';
  }

  /// Hesabın silinmesini durdurmaması gereken temizlik adımları için.
  Future<void> _bestEffort(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      // Yok say — hesabın kendisi yine de silinmeli.
    }
  }
}
