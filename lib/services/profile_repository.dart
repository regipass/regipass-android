import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/profiles.dart';
import 'firebase_refs.dart';

/// Profil okuma/yazma — js/pages/info.js, club-info.js, phone-*.js karşılığı.
class ProfileRepository {
  const ProfileRepository();

  Stream<AppUser?> watchUser(String uid) =>
      userDoc(uid).snapshots().map(AppUser.fromDoc);

  Stream<StudentProfile?> watchStudentProfile(String uid) =>
      studentProfileDoc(uid).snapshots().map(StudentProfile.fromDoc);

  Stream<ClubProfile?> watchClubProfile(String uid) =>
      clubProfileDoc(uid).snapshots().map(ClubProfile.fromDoc);

  Future<AppUser?> fetchUser(String uid) async =>
      AppUser.fromDoc(await userDoc(uid).get());

  Future<StudentProfile?> fetchStudentProfile(String uid) async =>
      StudentProfile.fromDoc(await studentProfileDoc(uid).get());

  Future<ClubProfile?> fetchClubProfile(String uid) async =>
      ClubProfile.fromDoc(await clubProfileDoc(uid).get());

  /// info.js#saveStudentProfile — profil ve users dokümanı tek batch'te yazılır.
  ///
  /// [phoneVerified]: numara değişmediyse önceki doğrulama durumu korunur;
  /// Firebase Auth bu hesaba bu numarayı zaten bağlamışsa da korunur.
  Future<void> saveStudentProfile({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required String city,
    required String university,
    required String department,
    required String studentNumber,
    required String classYear,
    required String gender,
    required String photoUrl,
    required String photoPath,
    required bool phoneVerified,
    required bool hasPassword,
  }) async {
    final Doc profileRef = studentProfileDoc(uid);
    final Doc userRef = userDoc(uid);

    final List<Snap> snaps = await Future.wait<Snap>(<Future<Snap>>[
      profileRef.get(),
      userRef.get(),
    ]);
    final Snap existingProfile = snaps[0];
    final Snap existingUser = snaps[1];

    final Object? rawRoles = existingUser.data()?['roles'];
    final Map<String, dynamic> existingRoles = rawRoles is Map
        ? Map<String, dynamic>.from(rawRoles)
        : <String, dynamic>{};

    final WriteBatch batch = fbDb.batch();

    batch.set(profileRef, <String, dynamic>{
      'uid': uid,
      'email': email,
      'role': UserRole.student,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'city': city,
      'university': university,
      'department': department,
      'studentNumber': studentNumber,
      'classYear': classYear,
      // `male` | `female`. Yönetici istatistikleri bu iki değeri sayıyor.
      'gender': gender,
      'photoUrl': photoUrl,
      'photoPath': photoPath,
      'onboardingCompleted': true,
      'phoneVerified': phoneVerified,
      // Auth SDK'nın providerData'sı bazen önbellekten eski gelebildiği için
      // şifre sağlayıcısının varlığı Firestore'da da tutulur.
      'hasPassword': hasPassword,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt':
          existingProfile.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, <String, dynamic>{
      'role': UserRole.student,
      'lastRole': UserRole.student,
      'email': email,
      'roles': <String, dynamic>{...existingRoles, UserRole.student: true},
      'studentOnboardingCompleted': true,
      'onboardingCompleted': true,
      'profileCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// club-info.js#saveClubProfile.
  /// Mevcut onay durumu varsa korunur; yoksa belge yükleme aşamasına alınır.
  Future<String> saveClubProfile({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required String city,
    required String university,
    required String clubName,
    required List<String> clubFields,
    required String clubPurpose,
    required String clubContents,
    required bool hasPassword,
  }) async {
    final Doc profileRef = clubProfileDoc(uid);
    final Doc userRef = userDoc(uid);

    final List<Snap> snaps = await Future.wait<Snap>(<Future<Snap>>[
      profileRef.get(),
      userRef.get(),
    ]);
    final Snap existingProfile = snaps[0];
    final Snap existingUser = snaps[1];

    final Object? rawRoles = existingUser.data()?['roles'];
    final Map<String, dynamic> existingRoles = rawRoles is Map
        ? Map<String, dynamic>.from(rawRoles)
        : <String, dynamic>{};

    final String clubStatus =
        (existingProfile.data()?['clubStatus'] as String?) ??
        ClubStatus.documentsPending;

    final WriteBatch batch = fbDb.batch();

    batch.set(profileRef, <String, dynamic>{
      'uid': uid,
      'email': email,
      'role': UserRole.club,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'city': city,
      'university': university,
      'clubName': clubName,
      // Geriye dönük uyumluluk: `clubField` ilk alan, `clubFields` tümü.
      // Eski web sürümleri ve eski etkinlik kayıtları yalnızca tekil alanı
      // okuyor (club-account.js ile aynı desen).
      'clubField': clubFields.isEmpty ? '' : clubFields.first,
      'clubFields': clubFields,
      'clubPurpose': clubPurpose,
      'clubContents': clubContents,
      'onboardingCompleted': true,
      'clubStatus': clubStatus,
      'hasPassword': hasPassword,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt':
          existingProfile.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, <String, dynamic>{
      'role': UserRole.club,
      'lastRole': UserRole.club,
      'email': email,
      'clubName': clubName,
      'roles': <String, dynamic>{...existingRoles, UserRole.club: true},
      'clubOnboardingCompleted': true,
      'onboardingCompleted': true,
      'clubStatus': clubStatus,
      'profileCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    return clubStatus;
  }

  /// phone-verify.js#markPhoneVerified.
  ///
  /// Çağırmadan önce `user.getIdToken(true)` ile token tazelenmelidir:
  /// firestore.rules `request.auth.token.phone_number` iddiasını kontrol eder
  /// ve bu iddia yalnızca YENİ alınan bir token'da bulunur.
  Future<void> markPhoneVerified(String uid, String role) =>
      (role == UserRole.club ? clubProfileDoc(uid) : studentProfileDoc(uid))
          .update(<String, dynamic>{
            'phoneVerified': true,
            'phoneVerifiedAt': FieldValue.serverTimestamp(),
          });

  /// firestore.rules `student_profiles` üzerindeki HER create/update için
  /// `phoneVerified` alanı (bu yazımda dokunulmasa bile) true ise
  /// `request.auth.token.phone_number` iddiasının profildeki `phone` ile
  /// birebir eşleşmesini şart koşar. Bu iddia yalnızca YENİ alınan bir
  /// token'da güvenilir biçimde bulunur (bkz. phone-verify.js /
  /// PhoneVerifyScreen._markVerified) — telefonla ilgisi olmayan bir
  /// düzenleme bile bayat token yüzünden permission-denied ile reddedilebilir.
  /// Bu yüzden onboarding'in tam kaydı gibi, buradaki kısmi güncellemeler de
  /// yazmadan önce token'ı zorla tazeler.
  Future<void> _refreshIdTokenBestEffort() async {
    try {
      await fbAuth.currentUser?.getIdToken(true);
    } catch (_) {
      // En iyi çaba: tazelenemezse mevcut token ile denenir.
    }
  }

  /// Hesap sayfasındaki kalem düğmesi. Formun tamamını yeniden doğrulamadan
  /// yalnızca fotoğraf alanlarını günceller.
  Future<void> updateStudentPhoto({
    required String uid,
    required String photoUrl,
    required String photoPath,
  }) async {
    await _refreshIdTokenBestEffort();
    await studentProfileDoc(uid).update(<String, dynamic>{
      'photoUrl': photoUrl,
      'photoPath': photoPath,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Kulüp hesabındaki logo kalemi — öğrencinin fotoğraf kalemiyle aynı
  /// desen: formun tamamını yeniden doğrulamadan yalnızca logo alanlarını
  /// günceller.
  ///
  /// Yalnızca `club_profiles` yazılır. Etkinliklerdeki logo ayrı bir adımda
  /// tazelenir (`EventRepository.syncClubLogo`): kulübün etkinlikleri
  /// güncellenemese bile logo kaydedilmiş olsun.
  Future<void> updateClubLogo({
    required String uid,
    required String logoUrl,
    required String logoPath,
  }) async {
    await _refreshIdTokenBestEffort();
    await clubProfileDoc(uid).update(<String, dynamic>{
      'logoUrl': logoUrl,
      'logoPath': logoPath,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Hesabım ekranındaki hızlı düzenleme. Onboarding/parola akışını yeniden
  /// çalıştırmadan yalnızca öğrencinin düzenleyebileceği profil alanlarını
  /// günceller; telefon doğrulama durumu ve rol bilgileri korunur.
  Future<void> updateStudentProfileDetails({
    required String uid,
    required String firstName,
    required String lastName,
    required String city,
    required String university,
    required String department,
    required String studentNumber,
    required String classYear,
    required String gender,
  }) async {
    await _refreshIdTokenBestEffort();
    await studentProfileDoc(uid).update(<String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'city': city,
      'university': university,
      'department': department,
      'studentNumber': studentNumber,
      'classYear': classYear,
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Yeni numarayı ve doğrulanmış bayrağını TEK yazımda kaydeder.
  ///
  /// Hesap ekranındaki pop-up akışı bunu kullanır: numara Firestore'a ancak
  /// SMS kodu doğrulandıktan sonra yazılır. Böylece kullanıcı doğrulamadan
  /// vazgeçtiğinde profil hiç değişmemiş olur — eski akışta numara hemen
  /// yazılıp `phoneVerified` false'a düştüğü için router kullanıcıyı çıkışı
  /// olmayan tam ekran doğrulama kapısına kilitliyordu.
  ///
  /// firestore.rules bu yazımda `request.auth.token.phone_number` iddiasının
  /// yeni numarayla eşleşmesini şart koşar; çağıran taraf bu yüzden önce
  /// `user.updatePhoneNumber(...)`/`linkWithCredential(...)` çağırıp ardından
  /// `user.getIdToken(true)` ile token'ı tazelemek zorundadır.
  Future<void> setVerifiedPhone({
    required String uid,
    required String role,
    required String phoneE164,
  }) => (role == UserRole.club ? clubProfileDoc(uid) : studentProfileDoc(uid))
      .update(<String, dynamic>{
        'phone': phoneE164,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// phone-change.js — numara değişince doğrulama sıfırlanır.
  Future<void> changePhone(String uid, String role, String newPhoneE164) =>
      (role == UserRole.club ? clubProfileDoc(uid) : studentProfileDoc(uid))
          .update(<String, dynamic>{
            'phone': newPhoneE164,
            'phoneVerified': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

  /// club-documents.js — belgeler yüklendikten sonra inceleme kuyruğuna alır.
  Future<void> submitClubDocuments(
    String uid,
    Map<String, dynamic> documents,
  ) async {
    final WriteBatch batch = fbDb.batch();

    batch.update(clubProfileDoc(uid), <String, dynamic>{
      'documents': documents,
      'clubStatus': ClubStatus.pendingReview,
      'documentsSubmittedAt': FieldValue.serverTimestamp(),
      // Yönetici "belge eksik" notu bıraktıysa yeniden gönderimle birlikte
      // silinir; aksi hâlde kulüp eksiği tamamladıktan sonra da eski uyarıyı
      // görmeye devam ederdi.
      'documentIssue': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userDoc(uid), <String, dynamic>{
      'clubStatus': ClubStatus.pendingReview,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
