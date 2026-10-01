/// Firestore alan adları web istemcisiyle **birebir** aynıdır; iki istemci
/// aynı dokümanları okuyup yazdığı için burada yeniden adlandırma yapılamaz.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

/// Firestore'dan gelen değeri güvenli biçimde int'e çevirir.
/// (Firestore sayıları int veya double olarak dönebilir.)
int? asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Firestore'daki tarih alanını epoch milisaniyesine çevirir.
///
/// Etkinlikler ilk web sürümünden kalma olabileceği için tarih bazen Firestore
/// [Timestamp]'ı, bazen epoch saniyesi ya da ISO metni olarak bulunabiliyor.
/// Bunlardan biri düz `asInt` ile okunamadığında tarih `0` olur ve geçmiş bir
/// etkinlik yanlışlıkla süresiz/aktif kabul edilir. Tarih alanları bu yardımcı
/// ile tek bir birime normalleştirilir.
int? asEpochMilliseconds(Object? value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;

  final int? numeric = asInt(value);
  if (numeric != null) {
    // Güncel epoch saniyeleri 10 basamaklı, milisaniyeler 13 basamaklıdır.
    // Bu eşik yalnızca açıkça saniye olduğu anlaşılan değerleri dönüştürür.
    if (numeric >= 1000000000 && numeric < 100000000000) {
      return numeric * 1000;
    }
    return numeric;
  }

  if (value is String) {
    return DateTime.tryParse(value)?.millisecondsSinceEpoch;
  }
  return null;
}

double? asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String asString(Object? value) => value is String ? value : '';

/// Dizi alanını temiz bir `List<String>`e çevirir.
///
/// Çoklu alan desteği web'e sonradan eklendi: eski dokümanlarda dizi hiç yok,
/// yalnızca tekil alan var. [fallback] doluysa dizi boş kaldığında tek
/// elemanlı liste üretilir; böylece okuyan taraf iki durumu ayırt etmek
/// zorunda kalmaz.
List<String> asStringList(Object? value, [String fallback = '']) {
  if (value is List) {
    final List<String> items = value
        .map((Object? item) => asString(item).trim())
        .where((String item) => item.isNotEmpty)
        .toList();
    if (items.isNotEmpty) return items;
  }

  final String single = fallback.trim();
  return single.isEmpty ? const <String>[] : <String>[single];
}

/// `users/{uid}` — rol ve onboarding durumunun tutulduğu kök doküman.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.role,
    required this.lastRole,
    required this.roles,
    required this.onboardingCompleted,
    required this.clubStatus,
    required this.clubName,
    required this.termsAccepted,
    required this.termsAcceptedAtMs,
    required this.marketingConsent,
    required this.termsVersion,
    this.webTermsGiven = false,
    this.webTermsVersion = '',
    this.commercialMessages = false,
    this.thirdPartyShare = false,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final Object? rawRoles = data['roles'];
    return AppUser(
      uid: uid,
      email: asString(data['email']),
      displayName: asString(data['displayName']),
      photoUrl: asString(data['photoURL']),
      role: data['role'] as String?,
      lastRole: data['lastRole'] as String?,
      roles: rawRoles is Map
          ? rawRoles.map(
              (Object? k, Object? v) => MapEntry<String, bool>('$k', v == true),
            )
          : const <String, bool>{},
      onboardingCompleted: data['onboardingCompleted'] == true,
      clubStatus: data['clubStatus'] as String?,
      clubName: asString(data['clubName']),
      termsAccepted: data['termsAccepted'] == true,
      termsAcceptedAtMs: asEpochMilliseconds(data['termsAcceptedAt']),
      marketingConsent: data['marketingConsent'] == true,
      termsVersion: asString(data['termsVersion']),
      webTermsGiven: _webTerms(data)['given'] == true,
      webTermsVersion: asString(_webTerms(data)['version']),
      commercialMessages:
          data['commercialMessages'] == true ||
          _consentGiven(data, 'commercialMessages') == true,
      thirdPartyShare:
          _consentGiven(data, 'marketingThirdPartyShare') ??
          (data['marketingConsent'] == true),
    );
  }

  /// `consent.<key>.given` (yoksa null).
  static bool? _consentGiven(Map<String, dynamic> data, String key) {
    final Object? consent = data['consent'];
    if (consent is Map) {
      final Object? item = consent[key];
      if (item is Map && item['given'] is bool) return item['given'] as bool;
    }
    return null;
  }

  /// Web'in yazdığı `consent.tosAndKvkk` alanı (yoksa boş).
  static Map<Object?, Object?> _webTerms(Map<String, dynamic> data) {
    final Object? consent = data['consent'];
    if (consent is Map) {
      final Object? terms = consent['tosAndKvkk'];
      if (terms is Map) return terms;
    }
    return const <Object?, Object?>{};
  }

  static AppUser? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null;

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String? role;
  final String? lastRole;
  final Map<String, bool> roles;
  final bool onboardingCompleted;
  final String? clubStatus;
  final String clubName;

  /// Kayıt ekranındaki onayın kaydı. Profil belgesi henüz yokken (bilgi formu
  /// doldurulmadan) onayın tek kalıcı kopyası burasıdır: kullanıcı formu
  /// yarıda bırakıp uygulamayı kapatsa bile onay anı kaybolmaz.
  final bool termsAccepted;

  /// Onaya tıklanan an — saniye çözünürlüğünde (bkz. KVKK metni madde 7).
  final int? termsAcceptedAtMs;

  final bool marketingConsent;

  /// Onaylanan belge sürümü (bkz. [kLegalDocsVersion]).
  final String termsVersion;

  /// Web'den verilen onay (`consent.tosAndKvkk`): web ve mobil farklı alana
  /// yazıyordu; güncel sürüm kontrolü ikisine birden bakar.
  final bool webTermsGiven;
  final String webTermsVersion;

  /// İP-PZ: kampanya bildirimi (ticari ileti) izni — varsayılan kapalı.
  final bool commercialMessages;

  /// Verilerin üçüncü kurumlarla pazarlama amaçlı paylaşılması izni.
  final bool thirdPartyShare;

  bool get hasStudentRole => roles['student'] == true;
  bool get hasClubRole => roles['club'] == true;
}

/// `student_profiles/{uid}`
class StudentProfile {
  const StudentProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.city,
    required this.university,
    required this.department,
    required this.studentNumber,
    required this.classYear,
    required this.gender,
    required this.photoUrl,
    required this.photoPath,
    required this.onboardingCompleted,
    required this.phoneVerified,
    required this.banned,
    required this.hasPassword,
    required this.createdAtMs,
    required this.termsAccepted,
    required this.termsAcceptedAtMs,
    required this.marketingConsent,
  });

  factory StudentProfile.fromMap(String uid, Map<String, dynamic> data) {
    return StudentProfile(
      uid: uid,
      email: asString(data['email']),
      firstName: asString(data['firstName']),
      lastName: asString(data['lastName']),
      phone: asString(data['phone']),
      city: asString(data['city']),
      university: asString(data['university']),
      department: asString(data['department']),
      studentNumber: asString(data['studentNumber']),
      classYear: asString(data['classYear']),
      gender: asString(data['gender']).trim().toLowerCase(),
      photoUrl: asString(data['photoUrl']),
      photoPath: asString(data['photoPath']),
      onboardingCompleted: data['onboardingCompleted'] == true,
      phoneVerified: data['phoneVerified'] == true,
      banned: data['banned'] == true,
      hasPassword: data['hasPassword'] == true,
      createdAtMs: asEpochMilliseconds(data['createdAt']),
      termsAccepted: data['termsAccepted'] == true,
      termsAcceptedAtMs: asEpochMilliseconds(data['termsAcceptedAt']),
      marketingConsent: data['marketingConsent'] == true,
    );
  }

  static StudentProfile? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      doc.exists ? StudentProfile.fromMap(doc.id, doc.data()!) : null;

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String city;
  final String university;
  final String department;
  final String studentNumber;
  final String classYear;

  /// `male` | `female` | boş. Yönetici istatistiklerindeki cinsiyet dağılımı
  /// bu alandan hesaplanır; web de aynı iki değeri yazıyor.
  final String gender;

  final String photoUrl;
  final String photoPath;
  final bool onboardingCompleted;
  final bool phoneVerified;
  final bool banned;
  final bool hasPassword;

  /// Hesabın açıldığı an. Telefon doğrulama süresi buradan sayılır
  /// (bkz. lib/domain/account_expiry.dart).
  ///
  /// Sunucu damgası olarak yazıldığı için sunucu onaylayana kadar yerel
  /// anlık görüntüde `null` görünür — okuyan taraf bunu hesaba katmalı.
  final int? createdAtMs;

  /// Kayıt ekranındaki zorunlu onay (Kullanıcı ve Organizatör Sözleşmesi + KVKK
  /// Aydınlatma Metni). Bilgi formu bu onay olmadan kaydedilemez, bu yüzden
  /// tamamlanmış her profilde true olması beklenir.
  final bool termsAccepted;
  final int? termsAcceptedAtMs;

  /// KVKK Açık Rıza Metni'ndeki isteğe bağlı pazarlama paylaşımı onayı.
  final bool marketingConsent;

  /// dashboard.js#getStudentDisplayName ile aynı sıra.
  String get fullName => '$firstName $lastName'.trim();
}

/// Yöneticinin tek bir kulübe yazdığı not.
///
/// Web karşılığı: `js/modules/admin/club-messages.js`. Kayıtlar ayrı bir
/// koleksiyonda değil, kulüp profilinin içindeki `adminMessages` dizisinde
/// durur — kulüp kendi `club_profiles` belgesini zaten okuyabiliyor ve
/// projede Cloud Functions yok.
///
/// Zaman damgası istemciden gelir: `serverTimestamp()` bir dizi elemanının
/// içinde çalışmaz (`arrayUnion`). Belge düzeyindeki `lastAdminMessageAt`
/// alanı sunucu saatiyle tutulur.
class AdminMessage {
  const AdminMessage({
    required this.id,
    required this.message,
    required this.createdAtMs,
    required this.createdBy,
  });

  factory AdminMessage.fromMap(Map<String, dynamic> data) {
    final int createdAtMs = asInt(data['createdAtMs']) ?? 0;
    final String id = asString(data['id']).trim();

    return AdminMessage(
      // Eski/eksik kayıtlarda kimlik yoksa zaman damgası kimlik yerine geçer;
      // liste anahtarı olarak kullanılabilsin diye boş bırakılmıyor.
      id: id.isNotEmpty ? id : '$createdAtMs',
      message: asString(data['message']).trim(),
      createdAtMs: createdAtMs,
      createdBy: asString(data['createdBy']).trim(),
    );
  }

  final String id;
  final String message;
  final int createdAtMs;
  final String createdBy;
}

/// Ham diziyi **en yenisi başta** olacak şekilde sıralanmış listeye çevirir.
/// Boş metinli kayıtlar elenir (web'deki `readAdminMessages` ile aynı).
List<AdminMessage> asAdminMessages(Object? value) {
  if (value is! List) return const <AdminMessage>[];

  final List<AdminMessage> list = value
      .whereType<Map<Object?, Object?>>()
      .map(
        (Map<Object?, Object?> raw) =>
            AdminMessage.fromMap(Map<String, dynamic>.from(raw)),
      )
      .where((AdminMessage entry) => entry.message.isNotEmpty)
      .toList();

  list.sort(
    (AdminMessage a, AdminMessage b) => b.createdAtMs.compareTo(a.createdAtMs),
  );
  return list;
}

/// `club_profiles/{uid}`
class ClubProfile {
  const ClubProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.city,
    required this.university,
    required this.clubName,
    required this.clubField,
    required this.clubFields,
    required this.clubPurpose,
    required this.clubContents,
    required this.logoUrl,
    required this.logoPath,
    required this.documentIssue,
    required this.adminMessages,
    required this.onboardingCompleted,
    required this.clubStatus,
    required this.banned,
    required this.phoneVerified,
    required this.hasPassword,
    required this.documents,
    required this.termsAccepted,
    required this.termsAcceptedAtMs,
    required this.marketingConsent,
  });

  factory ClubProfile.fromMap(String uid, Map<String, dynamic> data) {
    final Object? rawDocs = data['documents'];
    return ClubProfile(
      uid: uid,
      email: asString(data['email']),
      firstName: asString(data['firstName']),
      lastName: asString(data['lastName']),
      phone: asString(data['phone']),
      city: asString(data['city']),
      university: asString(data['university']),
      clubName: asString(data['clubName']),
      clubField: asString(data['clubField']),
      clubFields: asStringList(data['clubFields'], asString(data['clubField'])),
      clubPurpose: asString(data['clubPurpose']),
      clubContents: asString(data['clubContents']),
      logoUrl: asString(data['logoUrl']),
      logoPath: asString(data['logoPath']),
      documentIssue: asString(data['documentIssue']),
      adminMessages: asAdminMessages(data['adminMessages']),
      onboardingCompleted: data['onboardingCompleted'] == true,
      // Alan yoksa web ile aynı varsayılan: belge bekleniyor.
      clubStatus:
          (data['clubStatus'] as String?) ?? ClubStatus.documentsPending,
      banned: data['banned'] == true,
      phoneVerified: data['phoneVerified'] == true,
      hasPassword: data['hasPassword'] == true,
      documents: rawDocs is Map
          ? rawDocs.map(
              (Object? k, Object? v) => MapEntry<String, Map<String, dynamic>>(
                '$k',
                v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
              ),
            )
          : const <String, Map<String, dynamic>>{},
      termsAccepted: data['termsAccepted'] == true,
      termsAcceptedAtMs: asEpochMilliseconds(data['termsAcceptedAt']),
      marketingConsent: data['marketingConsent'] == true,
    );
  }

  static ClubProfile? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      doc.exists ? ClubProfile.fromMap(doc.id, doc.data()!) : null;

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String city;
  final String university;
  final String clubName;

  /// Geriye dönük uyumluluk için tutulan tekil alan (dizinin ilk elemanı).
  final String clubField;

  /// Kulübün seçtiği tüm alanlar — keşif algoritması hepsine bakar.
  final List<String> clubFields;

  final String clubPurpose;
  final String clubContents;

  /// Kulübün yüklediği logo (Storage indirme adresi) ve Storage yolu.
  ///
  /// Logo yalnızca hesap ekranındaki süs değil: etkinliklerde kulübün kimlik
  /// kartında görünür ve kulüp bir etkinliğe kapak görseli koymadığında o
  /// etkinliğin kapağı olarak kullanılır (bkz. `AppEvent.displayImageUrl`).
  final String logoUrl;
  final String logoPath;

  /// Yöneticinin "belge eksik" derken yazdığı açıklama. Doluysa kulüp, belge
  /// yükleme ekranında bu metni görür ve eksiği tamamlar.
  final String documentIssue;

  /// Yöneticinin bu kulübe yazdığı notlar — en yenisi başta.
  /// Kulüp bunları onay bekleme ekranında görür.
  final List<AdminMessage> adminMessages;

  final bool onboardingCompleted;
  final String clubStatus;

  /// Ayrı `banned` bayrağı: engel `clubStatus` ile birlikte yazılır ama
  /// eski kayıtlarda yalnızca biri dolu olabilir (bkz. [isBanned]).
  final bool banned;

  final bool phoneVerified;
  final bool hasPassword;
  final Map<String, Map<String, dynamic>> documents;

  /// Kayıt ekranındaki zorunlu onay (Kullanıcı ve Organizatör Sözleşmesi + KVKK
  /// Aydınlatma Metni). Bilgi formu bu onay olmadan kaydedilemez.
  final bool termsAccepted;
  final int? termsAcceptedAtMs;

  /// KVKK Açık Rıza Metni'ndeki isteğe bağlı pazarlama paylaşımı onayı.
  final bool marketingConsent;

  /// Web'deki `clubIsBanned` ile aynı: iki alandan biri yeterli.
  bool get isBanned => clubStatus == ClubStatus.banned || banned;

  /// Yalnızca engel alanlarını değiştiren kopya.
  ///
  /// Yönetici ekranı, yazma bittikten sonra sunucudan yeni anlık görüntü
  /// gelmeden rozeti ve düğmeyi tazeleyebilsin diye var; başka bir alanı
  /// kopyalamak gerekmediği için tam bir `copyWith` yazılmadı.
  ClubProfile withBanState({
    required String clubStatus,
    required bool banned,
  }) => ClubProfile(
    uid: uid,
    email: email,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    city: city,
    university: university,
    clubName: clubName,
    clubField: clubField,
    clubFields: clubFields,
    clubPurpose: clubPurpose,
    clubContents: clubContents,
    logoUrl: logoUrl,
    logoPath: logoPath,
    documentIssue: documentIssue,
    adminMessages: adminMessages,
    onboardingCompleted: onboardingCompleted,
    clubStatus: clubStatus,
    banned: banned,
    phoneVerified: phoneVerified,
    hasPassword: hasPassword,
    documents: documents,
    termsAccepted: termsAccepted,
    termsAcceptedAtMs: termsAcceptedAtMs,
    marketingConsent: marketingConsent,
  );
}
