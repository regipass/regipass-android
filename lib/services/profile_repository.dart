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

  /// Bekleme ekranındaki kullanıcı isteğiyle, yerel önbellek yerine doğrudan
  /// sunucudan güncel kulüp durumunu getirir. Dinleyen profil akışı da gelen
  /// yeni anlık görüntüyle güncellenir.
  Future<ClubProfile?> refreshClubProfile(String uid) async =>
      ClubProfile.fromDoc(
        await clubProfileDoc(uid).get(const GetOptions(source: Source.server)),
      );

  /// Kayıt ekranındaki onay kutucuklarının anlık kaydı.
  ///
  /// Hesap oluşturulur oluşturulmaz `users/{uid}` belgesine yazılır — profil
  /// belgesi (`student_profiles`/`club_profiles`) henüz yoktur, bilgi formu
  /// tamamlanana kadar oluşmaz. Onay bu yüzden iki yerde durur:
  ///   1. burada, tıklama anıyla birlikte (kullanıcı formu yarıda bıraksa
  ///      bile kayıt kaybolmaz),
  ///   2. bilgi formu kaydedilirken profil belgesine kopyalanır (kartlarda
  ///      ve yönetici ekranlarında oradan okunur).
  ///
  /// [acceptedAtMs] kullanıcının kaydol düğmesine bastığı andır; sunucu
  /// damgası değil, çünkü aranan bilgi yazımın değil ONAYIN zamanı.
  /// İP-HK: güncellenen metinlerin yeniden onayı. Web (`consent.tosAndKvkk`)
  /// ve mobil (`termsAccepted`/`termsVersion`) alanlarına birlikte yazılır;
  /// sunucu tetikleyicisi bunu değiştirilemez `consent_log` kaydına geçirir.
  Future<void> acceptLegalUpdate(String uid, String version) {
    return userDoc(uid).set(<String, dynamic>{
      'consent': <String, dynamic>{
        'tosAndKvkk': <String, dynamic>{
          'given': true,
          'version': version,
          'givenAt': FieldValue.serverTimestamp(),
        },
      },
      'termsAccepted': true,
      'termsVersion': version,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'consentHistory': FieldValue.arrayUnion(<Map<String, dynamic>>[
        <String, dynamic>{
          'version': version,
          'atMs': DateTime.now().millisecondsSinceEpoch,
          'source': 'mobile-reconsent',
        },
      ]),
    }, SetOptions(merge: true));
  }

  /// İP-PZ: açık rıza tercihi (Hesap ayarları). [key]: `commercialMessages`
  /// ya da `marketingThirdPartyShare`. Web ve mobil alanlarına birlikte
  /// yazılır; sunucu tetikleyicisi consent_log'a geçirir.
  Future<void> setConsentPreference(
    String uid,
    String key,
    bool on,
    String version,
  ) {
    return userDoc(uid).set(<String, dynamic>{
      'consent': <String, dynamic>{
        key: <String, dynamic>{
          'given': on,
          'version': version,
          'givenAt': FieldValue.serverTimestamp(),
        },
      },
      if (key == 'commercialMessages') 'commercialMessages': on,
      if (key == 'marketingThirdPartyShare') 'marketingConsent': on,
    }, SetOptions(merge: true));
  }

  Future<void> recordConsent({
    required String uid,
    required bool termsAccepted,
    required bool marketingConsent,
    required int acceptedAtMs,
    required String termsVersion,
  }) async {
    final Timestamp acceptedAt = Timestamp.fromMillisecondsSinceEpoch(
      acceptedAtMs,
    );
    await userDoc(uid).set(<String, dynamic>{
      'uid': uid,
      'termsAccepted': termsAccepted,
      'termsAcceptedAt': acceptedAt,
      'termsVersion': termsVersion,
      'marketingConsent': marketingConsent,
      // Reddedilen açık rızanın zamanı tutulmaz: KVKK'da saklanması gereken
      // şey verilen rızadır, verilmeyeni kayıt altına almak gereksiz veri.
      'marketingConsentAt': marketingConsent
          ? acceptedAt
          : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// İP-G4: kayıtta alınan "18 yaşından büyüğüm" beyanı
  /// (web: consent.ageOver18). En iyi çaba; kayıt akışını durdurmaz.
  Future<void> recordAgeConfirmation({
    required String uid,
    required int confirmedAtMs,
    required String termsVersion,
  }) async {
    await userDoc(uid).set(<String, dynamic>{
      'consent': <String, dynamic>{
        'ageOver18': <String, dynamic>{
          'given': true,
          'version': termsVersion,
          'givenAt': Timestamp.fromMillisecondsSinceEpoch(confirmedAtMs),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// info.js#saveStudentProfile — profil ve users dokümanı tek transaction'da
  /// yazılır.
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
    bool? termsAccepted,
    int? termsAcceptedAtMs,
    bool? marketingConsent,
    String? termsVersion,
  }) async {
    final Doc profileRef = studentProfileDoc(uid);
    final Doc userRef = userDoc(uid);
    final Doc otherProfileRef = clubProfileDoc(uid);

    await fbDb.runTransaction<void>((Transaction transaction) async {
      // Bütün okumalar transaction yazımlarından önce yapılmalı. users belgesi
      // de okunduğu için iki cihaz aynı anda farklı rol tamamlarsa Firestore
      // işlemlerden birini yeniden çalıştırır ve rol haritası kaybolmaz.
      final Snap existingProfile = await transaction.get(profileRef);
      final Snap existingUser = await transaction.get(userRef);
      final Snap existingOtherProfile = await transaction.get(otherProfileRef);
      final bool profileWasCompleted =
          existingProfile.data()?['onboardingCompleted'] == true;

      final Object? rawRoles = existingUser.data()?['roles'];
      final Map<String, dynamic> existingRoles = rawRoles is Map
          ? Map<String, dynamic>.from(rawRoles)
          : <String, dynamic>{};
      final bool keepClubRole =
          existingOtherProfile.data()?['onboardingCompleted'] == true;
      if (keepClubRole) {
        existingRoles[UserRole.club] = true;
      } else {
        existingRoles.remove(UserRole.club);
      }

      if (existingOtherProfile.exists && !keepClubRole) {
        transaction.delete(otherProfileRef);
      }

      transaction.set(profileRef, <String, dynamic>{
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
        // Onay yalnızca kayıt ekranında bir kez verilir; bu alanlar yoksa
        // (ör. hesap ekranındaki düzenleme akışı) mevcut değer korunur.
        'termsAccepted': ?termsAccepted,
        if (termsAcceptedAtMs != null) ...<String, dynamic>{
          'termsAcceptedAt': Timestamp.fromMillisecondsSinceEpoch(
            termsAcceptedAtMs,
          ),
          'termsVersion': termsVersion,
        },
        'marketingConsent': ?marketingConsent,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': profileWasCompleted
            ? (existingProfile.data()?['createdAt'] ??
                  FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(userRef, <String, dynamic>{
        'uid': uid,
        'role': UserRole.student,
        'lastRole': UserRole.student,
        'email': email,
        'displayName': '$firstName $lastName'.trim(),
        'photoURL': photoUrl,
        'roles': <String, dynamic>{...existingRoles, UserRole.student: true},
        'studentOnboardingCompleted': true,
        if (!keepClubRole) 'clubOnboardingCompleted': FieldValue.delete(),
        'onboardingCompleted': true,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': profileWasCompleted || keepClubRole
            ? (existingUser.data()?['createdAt'] ??
                  FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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
    required bool phoneVerified,
    required bool hasPassword,
    String? logoUrl,
    String? logoPath,
    bool? termsAccepted,
    int? termsAcceptedAtMs,
    bool? marketingConsent,
    String? termsVersion,
  }) async {
    final Doc profileRef = clubProfileDoc(uid);
    final Doc userRef = userDoc(uid);
    final Doc otherProfileRef = studentProfileDoc(uid);

    return fbDb.runTransaction<String>((Transaction transaction) async {
      final Snap existingProfile = await transaction.get(profileRef);
      final Snap existingUser = await transaction.get(userRef);
      final Snap existingOtherProfile = await transaction.get(otherProfileRef);
      final bool profileWasCompleted =
          existingProfile.data()?['onboardingCompleted'] == true;

      final Object? rawRoles = existingUser.data()?['roles'];
      final Map<String, dynamic> existingRoles = rawRoles is Map
          ? Map<String, dynamic>.from(rawRoles)
          : <String, dynamic>{};
      final bool keepStudentRole =
          existingOtherProfile.data()?['onboardingCompleted'] == true;
      if (keepStudentRole) {
        existingRoles[UserRole.student] = true;
      } else {
        existingRoles.remove(UserRole.student);
      }

      final String clubStatus =
          (existingProfile.data()?['clubStatus'] as String?) ??
          ClubStatus.documentsPending;

      if (existingOtherProfile.exists && !keepStudentRole) {
        transaction.delete(otherProfileRef);
      }

      transaction.set(profileRef, <String, dynamic>{
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
        if (logoUrl != null && logoPath != null) 'logoUrl': logoUrl,
        if (logoUrl != null && logoPath != null) 'logoPath': logoPath,
        'onboardingCompleted': true,
        'clubStatus': clubStatus,
        // Telefon, Firebase Auth hesabının ortak alanıdır. Aynı e-postayla
        // sonradan öğrenci rolü eklenirse bu bayrak, Auth'ta bağlı numarayla
        // birlikte ikinci profile de taşınır.
        'phoneVerified': phoneVerified,
        if (!phoneVerified) 'phoneVerifiedAt': FieldValue.delete(),
        'hasPassword': hasPassword,
        'termsAccepted': ?termsAccepted,
        if (termsAcceptedAtMs != null) ...<String, dynamic>{
          'termsAcceptedAt': Timestamp.fromMillisecondsSinceEpoch(
            termsAcceptedAtMs,
          ),
          'termsVersion': termsVersion,
        },
        'marketingConsent': ?marketingConsent,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': profileWasCompleted
            ? (existingProfile.data()?['createdAt'] ??
                  FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(userRef, <String, dynamic>{
        'uid': uid,
        'role': UserRole.club,
        'lastRole': UserRole.club,
        'email': email,
        'displayName': '$firstName $lastName'.trim(),
        'photoURL': asString(existingUser.data()?['photoURL']),
        'clubName': clubName,
        'roles': <String, dynamic>{...existingRoles, UserRole.club: true},
        'clubOnboardingCompleted': true,
        if (!keepStudentRole) 'studentOnboardingCompleted': FieldValue.delete(),
        'onboardingCompleted': true,
        'clubStatus': clubStatus,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': profileWasCompleted || keepStudentRole
            ? (existingUser.data()?['createdAt'] ??
                  FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return clubStatus;
    });
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
  /// İP-KP: onaylı kulübün onay gerektirmeyen alanları (temsilci adı).
  /// Ad, üniversite, metinler ve alanlar `clubRequestProfileChange` ile
  /// yöneticinin onayına gider; kurallar bunların doğrudan yazılmasını reddeder.
  Future<void> updateClubRepresentative({
    required String uid,
    required String firstName,
    required String lastName,
  }) async {
    await _refreshIdTokenBestEffort();
    await clubProfileDoc(uid).update(<String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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

  /// İP-B4b: üniversite/bölüme özel etkinliğe kaydolurken profilde boş olan
  /// alanı doldurur (yalnızca verilenler yazılır).
  Future<void> fillStudentScopeFields({
    required String uid,
    String? university,
    String? department,
  }) async {
    final Map<String, dynamic> patch = <String, dynamic>{
      if (university != null && university.isNotEmpty) 'university': university,
      if (department != null && department.isNotEmpty) 'department': department,
    };
    if (patch.isEmpty) return;
    await studentProfileDoc(uid).update(<String, dynamic>{
      ...patch,
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
  }) => _writeSharedPhone(
    uid: uid,
    fallbackRole: role,
    phoneE164: phoneE164,
    verified: true,
  );

  /// phone-change.js — numara değişince doğrulama sıfırlanır.
  Future<void> changePhone(String uid, String role, String newPhoneE164) =>
      _writeSharedPhone(
        uid: uid,
        fallbackRole: role,
        phoneE164: newPhoneE164,
        verified: false,
      );

  /// Öğrenci ve kulüp aynı Firebase Auth kimliğini kullandığı için giriş
  /// telefonu da ortaktır. Var olan iki profili tek batch içinde günceller;
  /// ikinci rol henüz oluşturulmamışsa yalnız mevcut profile yazar.
  ///
  /// NOT: yeni kayıtlarda bir e-postaya tek rol bağlanıyor, dolayısıyla ikinci
  /// profil oluşmuyor. Bu birleşik yazım, kural değişmeden önce açılmış çift
  /// rollü hesaplar için duruyor.
  Future<void> _writeSharedPhone({
    required String uid,
    required String fallbackRole,
    required String phoneE164,
    required bool verified,
  }) async {
    final Doc studentRef = studentProfileDoc(uid);
    final Doc clubRef = clubProfileDoc(uid);
    final List<Snap> snapshots = await Future.wait<Snap>(<Future<Snap>>[
      studentRef.get(),
      clubRef.get(),
    ]);

    final Map<String, dynamic> data = <String, dynamic>{
      'phone': phoneE164,
      'phoneVerified': verified,
      'phoneVerifiedAt': verified
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final WriteBatch batch = fbDb.batch();
    bool hasWrite = false;
    if (snapshots[0].exists) {
      batch.update(studentRef, data);
      hasWrite = true;
    }
    if (snapshots[1].exists) {
      batch.update(clubRef, data);
      hasWrite = true;
    }

    if (!hasWrite) {
      final Doc fallbackRef = fallbackRole == UserRole.club
          ? clubRef
          : studentRef;
      batch.update(fallbackRef, data);
    }
    await batch.commit();
  }

  /// Bir kulüp belgesini anında kaydeder. Dördüncü belge de kaydedildiğinde
  /// kulüp otomatik olarak inceleme kuyruğuna alınır.
  Future<void> saveClubDocuments(
    String uid,
    Map<String, dynamic> documents,
  ) async {
    final bool complete = kClubDocTypes.every(documents.containsKey);
    final WriteBatch batch = fbDb.batch();

    batch.update(clubProfileDoc(uid), <String, dynamic>{
      'documents': documents,
      'clubStatus': complete
          ? ClubStatus.pendingReview
          : ClubStatus.documentsPending,
      'documentsSubmittedAt': complete
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
      // Yönetici "belge eksik" notu, ancak tüm belgeler tamamlanıp başvuru
      // yeniden incelemeye gönderildiğinde kaldırılır.
      if (complete) 'documentIssue': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userDoc(uid), <String, dynamic>{
      'clubStatus': complete
          ? ClubStatus.pendingReview
          : ClubStatus.documentsPending,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Geriye dönük çağıranlar için eski ad korunur.
  Future<void> submitClubDocuments(
    String uid,
    Map<String, dynamic> documents,
  ) => saveClubDocuments(uid, documents);
}
