import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../core/constants.dart';
import '../core/input_guard.dart';
import '../domain/club_moderation.dart';
import '../models/profiles.dart';
import 'firebase_refs.dart';

/// Yönetici işlemleri — js/pages/admin-*.js karşılığı.
///
/// Bu sınıfın tüm çağrıları yalnızca yönetim hesabı için firestore.rules
/// tarafından yetkilendirilmiştir (`isAdmin()` / `isStaff()`: rol etiketi +
/// doğrulayıcı kodla açılmış oturum); başka bir hesapta `permission-denied`
/// döner.
///
/// İP-M1: engelleme artık SUNUCUDA (functions/adminAccounts.js#adminSetBan):
/// gerekçe zorunlu ve işlem kaydına yazılır, engellenen hesap giriş yapamaz,
/// kulüpte gelecek etkinlikler iptal edilip kayıtlılara bildirim gider.
class AdminRepository {
  const AdminRepository();

  // ── Onay bekleyen kulüpler (admin-dashboard.js) ─────────────────────

  Stream<List<ClubProfile>> watchPendingClubs() => clubProfilesCol
      .where('clubStatus', isEqualTo: ClubStatus.pendingReview)
      .snapshots()
      .map(_mapClubs);

  Future<List<ClubProfile>> fetchAllClubs() async =>
      _mapClubs(await clubProfilesCol.get());

  List<ClubProfile> _mapClubs(QSnap snap) {
    final List<ClubProfile> list = snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              ClubProfile.fromMap(d.id, d.data()),
        )
        .toList();

    list.sort(
      (ClubProfile a, ClubProfile b) => a.clubName.compareTo(b.clubName),
    );
    return list;
  }

  /// Kulübü onaylar: hem profil hem `users` dokümanı güncellenir, çünkü
  /// yönlendirme kararı `users.clubStatus` üzerinden de okunabiliyor.
  Future<void> approveClub(String uid) async {
    final WriteBatch batch = fbDb.batch();

    batch.update(clubProfileDoc(uid), <String, dynamic>{
      'clubStatus': ClubStatus.approved,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userDoc(uid), <String, dynamic>{
      'clubStatus': ClubStatus.approved,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Başvuru incelemesinde kulübü reddeder (engeller).
  ///
  /// Belgeler sunucuda Storage'dan silinir (`deleteDocuments`): engellenen
  /// bir kulübün kimlik belgelerini saklamanın bir gerekçesi yok.
  Future<void> blockClub(ClubProfile club, {required String reason}) async {
    await _setBan(club.uid, true, reason: reason, deleteDocuments: true);
  }

  /// Belgeleri eksik/hatalı bulup kulübü yükleme aşamasına geri gönderir.
  ///
  /// Engellemekten farkı: belgeler silinmez ve kulüp reddedilmiş sayılmaz —
  /// yalnızca neyin eksik olduğu yazılıp yeniden yükleme kapısı açılır.
  Future<void> requestDocumentFix(String uid, String reason) async {
    final WriteBatch batch = fbDb.batch();

    batch.update(clubProfileDoc(uid), <String, dynamic>{
      'clubStatus': ClubStatus.documentsPending,
      'documentIssue': reason,
      'documentIssueAt': FieldValue.serverTimestamp(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userDoc(uid), <String, dynamic>{
      'clubStatus': ClubStatus.documentsPending,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Kulübe mesaj (js/modules/admin/club-messages.js) ────────────────

  /// Tek bir kulübe yönetici notu gönderir.
  ///
  /// Kayıt kulüp profilinin içindeki `adminMessages` dizisine eklenir; ayrı
  /// koleksiyon açılmadı çünkü kulüp kendi `club_profiles` belgesini zaten
  /// okuyabiliyor (bkz. firestore.rules) ve projede Cloud Functions yok.
  ///
  /// Zaman damgası istemciden yazılır: `serverTimestamp()` [FieldValue.arrayUnion]
  /// içinde çalışmaz. Belge düzeyindeki `lastAdminMessageAt` sunucu saatiyle
  /// tutulur, böylece sıralamada güvenilecek bir alan yine de var.
  ///
  /// Yazılan kaydı döndürür: çağıran ekran listeyi sunucuyu beklemeden
  /// tazeleyebilir.
  Future<AdminMessage> sendClubMessage({
    required String clubUid,
    required String message,
    required String adminUid,
  }) async {
    final String uid = clubUid.trim();
    final String text = message.trim().length > InputLimits.adminMessage
        ? message.trim().substring(0, InputLimits.adminMessage)
        : message.trim();

    if (uid.isEmpty) throw ArgumentError('missing-club');
    if (text.isEmpty) throw ArgumentError('empty-message');

    final AdminMessage entry = AdminMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}-${_randomSuffix()}',
      message: text,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      createdBy: adminUid.trim(),
    );

    await clubProfileDoc(uid).update(<String, dynamic>{
      'adminMessages': FieldValue.arrayUnion(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': entry.id,
          'message': entry.message,
          'createdAtMs': entry.createdAtMs,
          'createdBy': entry.createdBy.isEmpty ? null : entry.createdBy,
        },
      ]),
      'lastAdminMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return entry;
  }

  static String _randomSuffix() {
    const String alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    return List<String>.generate(
      6,
      (int _) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  // ── Kulüp engelle / engeli kaldır (ban-actions.js) ──────────────────

  /// Kulübü engeller ya da engelini kaldırır; işlemden sonraki `clubStatus`
  /// değerini döndürür.
  ///
  /// [blockClub]'dan farkı: belgelere dokunmaz. Engeli kaldırınca kulüp
  /// kaldığı yerden devam eder (belgeleri duruyorsa incelemeye döner).
  /// İptal edilen etkinlikler engel kalkınca geri gelmez.
  Future<String> setClubBanned(
    ClubProfile club,
    bool banned, {
    String reason = '',
  }) async {
    final Map<String, dynamic> result = await _setBan(
      club.uid,
      banned,
      reason: reason,
    );
    final Object? status = result['clubStatus'];
    return status is String && status.isNotEmpty
        ? status
        : (banned ? ClubStatus.banned : clubStatusAfterUnban(club));
  }

  /// Engelleme öncesi etkisi: kaç gelecek etkinlik iptal edilecek, kaç kişi.
  Future<BanPreview> previewBan(String uid) async {
    final Map<String, dynamic> data = await _call(
      'adminPreviewBan',
      <String, dynamic>{'uid': uid},
    );
    return BanPreview.fromMap(data);
  }

  Future<Map<String, dynamic>> _setBan(
    String uid,
    bool banned, {
    String reason = '',
    bool deleteDocuments = false,
  }) => _call('adminSetBan', <String, dynamic>{
    'uid': uid,
    'banned': banned,
    'reason': reason,
    'deleteDocuments': deleteDocuments,
  }, timeout: const Duration(minutes: 5));

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final HttpsCallableResult<dynamic> result = await fbFunctions
        .httpsCallable(name, options: HttpsCallableOptions(timeout: timeout))
        .call<dynamic>(data);
    final Object? value = result.data;
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  // ── Öğrenciler (admin-ban.js, admin-stats.js) ───────────────────────

  Stream<List<StudentProfile>> watchStudents() =>
      studentProfilesCol.snapshots().map(_mapStudents);

  Future<List<StudentProfile>> fetchStudents() async =>
      _mapStudents(await studentProfilesCol.get());

  List<StudentProfile> _mapStudents(QSnap snap) {
    final List<StudentProfile> list = snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              StudentProfile.fromMap(d.id, d.data()),
        )
        .toList();

    list.sort(
      (StudentProfile a, StudentProfile b) => a.fullName.compareTo(b.fullName),
    );
    return list;
  }

  /// Öğrenciyi engeller / engelini kaldırır. Engellenen hesap giriş
  /// yapamaz (sunucu Auth hesabını kapatır, oturumu düşürür).
  Future<void> setStudentBanned(
    String uid,
    bool banned, {
    String reason = '',
  }) async {
    await _setBan(uid, banned, reason: reason);
  }
}

/// Engelleme önizlemesi (functions/adminAccounts.js#adminPreviewBan).
class BanPreview {
  const BanPreview({required this.futureEvents, required this.registrations});

  factory BanPreview.fromMap(Map<String, dynamic> map) => BanPreview(
    futureEvents: (map['futureEvents'] as num?)?.toInt() ?? 0,
    registrations: (map['registrations'] as num?)?.toInt() ?? 0,
  );

  final int futureEvents;
  final int registrations;
}
