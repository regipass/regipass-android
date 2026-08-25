/// Uygulama genelindeki sabitler.
///
/// js/core/admin-config.js ve js/modules/auth/role-session.js karşılığı.
library;

/// Yönetici girişi. Kullanıcı giriş ekranına "a" yazar; sistem bunu gerçek
/// Firebase Auth hesabı olan [kAdminEmail] adresine eşler.
///
/// NOT: Web'deki `admin-config.js` ayrıca sabit bir yönetici parolası
/// sabitini içeriyordu. Bu sabit hiçbir yerde kullanılmıyordu (giriş akışı
/// kullanıcının yazdığı şifreyi kullanır) ve istemci paketine gömülü bir
/// yönetici şifresi ciddi bir risk oluşturduğu için buraya taşınmadı.
const String kAdminLoginAlias = 'a';
const String kAdminEmail = 'a@regipass.app';

/// Hem kısa "a" takma adını hem de tam yönetici e-postasını kabul eder.
bool isAdminLogin(String? rawInput) {
  final String value = (rawInput ?? '').trim().toLowerCase();
  return value == kAdminLoginAlias || value == kAdminEmail;
}

bool isAdminEmail(String? email) =>
    (email ?? '').trim().toLowerCase() == kAdminEmail;

/// Kulüp onay sürecindeki durumlar (`club_profiles.clubStatus`).
///
///   (yok)             -> bilgi formu henüz tamamlanmamış
///   documentsPending  -> belgeler henüz yüklenmemiş
///   pendingReview     -> belgeler yüklendi, yönetici onayı bekleniyor
///   approved          -> onaylandı, panele erişebilir
///   banned            -> engellendi, girişe izin yok
class ClubStatus {
  static const String documentsPending = 'documents_pending';
  static const String pendingReview = 'pending_review';
  static const String approved = 'approved';
  static const String banned = 'banned';
}

/// Kullanıcı rolleri (`users.role` / `users.lastRole`).
class UserRole {
  static const String student = 'student';
  static const String club = 'club';

  static bool isValid(String? role) => role == student || role == club;
}

/// Firestore koleksiyon adları — firestore.rules ile birebir eşleşmelidir.
class Collections {
  static const String users = 'users';
  static const String studentProfiles = 'student_profiles';
  static const String clubProfiles = 'club_profiles';
  static const String events = 'events';
  static const String eventRegistrations = 'event_registrations';
  static const String studentCertificates = 'student_certificates';

  /// Yönetici duyuruları (bkz. lib/models/announcement.dart). Belgeler
  /// yalnızca yönetici tarafından yazılır, hedef kitledeki herkes okur.
  ///
  /// DİKKAT: koleksiyon adı `notifications`. Mobil taraf bir süre
  /// `announcements` adına yazıyordu; firestore.rules'ta o adla bir blok
  /// olmadığı için her gönderim `permission-denied` ile düşüyor, yönetici
  /// "duyuru gönderilemedi" uyarısı alıyordu. Web yöneticisi de aynı
  /// koleksiyonu kullanıyor — iki taraf artık aynı duyuruları görüyor.
  static const String announcements = 'notifications';

  /// Doğrulanmış numaraların sahiplik dizini (bkz.
  /// `lib/services/phone_directory_repository.dart`). Belge kimliği E.164
  /// numaranın kendisidir; profil koleksiyonları yalnızca sahibine açık
  /// olduğu için "bu numara başkasına mı ait" sorusu ancak bu dizinden
  /// yanıtlanabilir.
  static const String phoneOwners = 'phone_owners';
}

/// Etkinlik hedef kitlesi (`events.targetScope`).
///
/// [department] artık YALNIZCA bölüm kısıtı demektir (üniversite fark
/// etmez); üniversite ve bölümün birlikte kısıtlandığı durum
/// [universityDepartment] ile ayrı bir kapsamdır. Eski kayıtlarda
/// "bölüme özel" aynı zamanda üniversite kısıtı taşıyordu; o kayıtlarda
/// `targetUniversity` dolu olduğu için görünürlük kontrolü üniversiteyi de
/// arar (bkz. event_utils.dart#canStudentSeeEvent).
class TargetScope {
  static const String public = 'public';
  static const String university = 'university';
  static const String department = 'department';
  static const String universityDepartment = 'university_department';

  /// Kapsam üniversite seçimi gerektiriyor mu?
  static bool needsUniversity(String scope) =>
      scope == university || scope == universityDepartment;

  /// Kapsam bölüm seçimi gerektiriyor mu?
  static bool needsDepartment(String scope) =>
      scope == department || scope == universityDepartment;
}

/// Kulüp kayıt belgeleri (club-documents.js#DOC_TYPES).
const List<String> kClubDocTypes = <String>[
  'establishment',
  'advisor',
  'studentCerts',
  'boardList',
];

/// Eski kayıtlarda kapak alanına yazılmış ağ yer tutucusu.
///
/// Artık yazılmıyor: kapağı olmayan etkinliklerde yer tutucu uygulamanın
/// kendi çizdiği gri marka perdesi (bkz. `EventImage`). Sabit yalnızca eski
/// kayıtları tanımak için duruyor.
const String kEventPlaceholderImage =
    'https://placehold.co/1200x675?text=Regipass';

/// Web'in görsel seçilmeyen etkinliklere atadığı doğa fotoğrafları.
///
/// club-create-event.js#NATURE_IMAGE_POOL ile **birebir aynı** liste. Mobil
/// artık bu havuzdan kapak atamıyor (kapaksız etkinlikte gri marka perdesi
/// çizilir), ama web'in atadığı ya da eskiden mobilde atanmış kapaklar
/// dokümanlarda duruyor: liste onları tanıyıp aynı perdeye düşürmek için
/// korunuyor.
const List<String> kNatureImagePool = <String>[
  'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1470770903676-69b98201ea1c?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1426604966848-d7adac402bff?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1418065460487-3e41a6c84dc5?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1431794062232-2a99a5431c6c?auto=format&fit=crop&w=1600&q=80',
];

/// Kulübün kendi seçmediği kapak adresleri.
///
/// Boş alan, eski ağ yer tutucusu ve havuzdan atanmış doğa fotoğrafları aynı
/// anlama gelir: bu etkinliğe görsel eklenmemiş. Hepsinde kapak yerine gri
/// marka perdesi çizilir — rastgele bir doğa fotoğrafı etkinlikle ilgisiz
/// duruyordu.
bool isAutoCoverUrl(String url) =>
    url.isEmpty ||
    url == kEventPlaceholderImage ||
    kNatureImagePool.contains(url);
