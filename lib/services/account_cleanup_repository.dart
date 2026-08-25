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

import '../core/constants.dart';
import '../models/profiles.dart';
import 'firebase_refs.dart';
import 'phone_directory_repository.dart';

class AccountCleanupRepository {
  const AccountCleanupRepository({
    this.phoneDirectory = const PhoneDirectoryRepository(),
  });

  final PhoneDirectoryRepository phoneDirectory;

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
}
