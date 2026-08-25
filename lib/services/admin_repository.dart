import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
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
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            ClubProfile.fromMap(d.id, d.data()))
        .toList();

    list.sort((ClubProfile a, ClubProfile b) => a.clubName.compareTo(b.clubName));
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
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            StudentProfile.fromMap(d.id, d.data()))
        .toList();

    list.sort((StudentProfile a, StudentProfile b) =>
        a.fullName.compareTo(b.fullName));
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
