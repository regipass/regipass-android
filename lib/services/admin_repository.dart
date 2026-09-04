import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/input_guard.dart';
import '../domain/club_moderation.dart';
import '../models/profiles.dart';
import 'firebase_refs.dart';

/// Yönetici işlemleri — js/pages/admin-*.js karşılığı.
///
/// Bu sınıfın tüm çağrıları yalnızca yönetici hesabı için firestore.rules
/// tarafından yetkilendirilmiştir (`isAdmin()`); başka bir hesapta
/// `permission-denied` döner.
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

  /// Kulübü engeller.
  ///
  /// Belgeler önce Storage'dan silinir: engellenen bir kulübün kimlik
  /// belgelerini saklamanın bir gerekçesi yok. Silme başarısız olsa da
  /// engelleme sürer — aksi hâlde kulüp açıkta kalırdı.
  Future<void> blockClub(ClubProfile club) async {
    await _deleteClubDocuments(club);

    final WriteBatch batch = fbDb.batch();

    batch.update(clubProfileDoc(club.uid), <String, dynamic>{
      'clubStatus': ClubStatus.banned,
      'documents': FieldValue.delete(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userDoc(club.uid), <String, dynamic>{
      'clubStatus': ClubStatus.banned,
      'banned': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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
  /// [blockClub]'dan farkı: belgelere dokunmaz. Onay kuyruğundaki bir kulübü
  /// reddetmek belgeleri silmeyi gerektiriyor, listeden engellemek ise geri
  /// alınabilir bir işlem — engeli kaldırınca kulüp kaldığı yerden devam eder.
  Future<String> setClubBanned(ClubProfile club, bool banned) async {
    final String nextStatus = banned
        ? ClubStatus.banned
        : clubStatusAfterUnban(club);

    final WriteBatch batch = fbDb.batch();

    batch.update(clubProfileDoc(club.uid), <String, dynamic>{
      'clubStatus': nextStatus,
      'banned': banned,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userDoc(club.uid), <String, dynamic>{
      'clubStatus': nextStatus,
      'banned': banned,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return nextStatus;
  }

  Future<void> _deleteClubDocuments(ClubProfile club) async {
    await Future.wait(
      club.documents.values.map((Map<String, dynamic> info) async {
        final String path = '${info['path'] ?? ''}';
        if (path.isEmpty) return;
        try {
          await fbStorage.ref(path).delete();
        } catch (_) {
          // Dosya zaten yoksa ya da silinemiyorsa engelleme devam etmeli.
        }
      }),
    );
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

  /// Öğrenciyi engeller. Router `banned` görünce oturumu kapatır.
  Future<void> setStudentBanned(String uid, bool banned) async {
    final WriteBatch batch = fbDb.batch();

    batch.update(studentProfileDoc(uid), <String, dynamic>{
      'banned': banned,
      'bannedAt': banned ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userDoc(uid), <String, dynamic>{
      'banned': banned,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
