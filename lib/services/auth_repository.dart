import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app/demo_mode.dart';
import 'firebase_refs.dart';
import 'push_service.dart';

/// Kimlik doğrulama akışları — js/modules/auth/login-modal.js ve
/// js/pages/register.js karşılığı.
class AuthRepository {
  const AuthRepository();

  User? get currentUser => fbAuth.currentUser;

  Stream<User?> authStateChanges() => fbAuth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) =>
      fbAuth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> createWithEmail(String email, String password) =>
      fbAuth.createUserWithEmailAndPassword(email: email, password: password);

  /// google_sign_in 7.x, `authenticate()` çağrılmadan önce bir kez
  /// `initialize()` bekliyor. Uygulama ömrü boyunca tek sefer yapılmalı;
  /// bu Future onu tembel (lazy) ve tek seferlik tutar.
  static Future<void>? _googleInit;

  /// Google ile giriş. Web'de `signInWithPopup` idi; mobilde yerel hesap
  /// seçiciyi açar.
  ///
  /// [_kServerClientId]: Android'de Firebase'in kabul edeceği bir `idToken`
  /// üretebilmek için ZORUNLU. Verilmezse paket
  /// "serverClientId must be provided on Android" hatası atar ve
  /// `idToken` null döner.
  ///
  /// Değer `google-services.json` içindeki **web** OAuth istemcisidir
  /// (`client_type: 3`) — Android istemcisi (`client_type: 1`) değil.
  /// Kafa karıştırıcı ama doğrusu bu: Google, kimliği doğrulayan tarafın
  /// (Firebase) istemci kimliğini ister, uygulamanınkini değil.
  ///
  /// **iOS'ta bu sabit hiç kullanılmaz.** Eklenti, `clientId` verilmediğinde
  /// yapılandırmayı hiç kurmuyor ve GoogleSignIn SDK hem istemci hem sunucu
  /// kimliğini `Info.plist`'ten (`GIDClientID` / `GIDServerClientID`)
  /// okuyor. Yani buradaki değer değişirse iOS Info.plist'i de
  /// güncellenmeli — bkz. `docs/ios-kurulum.md` §6.3.
  static const String _kServerClientId =
      '738082064551-5h5e3jab4u4ndk580og5gkkfvj5p9m0f.apps.googleusercontent.com';

  Future<UserCredential> signInWithGoogle() async {
    _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: _kServerClientId,
    );
    await _googleInit;

    final GoogleSignInAccount account = await GoogleSignIn.instance
        .authenticate();
    final GoogleSignInAuthentication auth = account.authentication;

    final String? idToken = auth.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google kimlik doğrulaması jeton döndürmedi.',
      );
    }

    return fbAuth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// Apple ile giriş.
  ///
  /// Ek paket gerekmez: `signInWithProvider` iOS'ta yerel Apple akışını,
  /// Android'de Firebase'in barındırdığı web akışını çalıştırır. Web
  /// uygulamasındaki `new OAuthProvider("apple.com")` ile aynı sağlayıcı.
  ///
  /// Firebase Console > Authentication > Sign-in method altında Apple
  /// sağlayıcısı etkin değilse `operation-not-allowed` hatası döner.
  Future<UserCredential> signInWithApple() {
    final AppleAuthProvider provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');

    return fbAuth.signInWithProvider(provider);
  }

  // ── Şifremi unuttum ─────────────────────────────────────────────────

  /// Doğrulanan SMS koduyla hesaba girer.
  ///
  /// Telefon, öğrencinin Auth hesabına doğrulama sırasında bağlandığı için
  /// bu kimlik bilgisi aynı hesabı açar. Şifre değiştirmek oturum gerektirdiği
  /// için bu adım zorunlu.
  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) => fbAuth.signInWithCredential(credential);

  /// Oturum açmış kullanıcının şifresini değiştirir.
  Future<void> updatePassword(String newPassword) =>
      _requireUser().updatePassword(newPassword);

  // ── Hassas işlemler (şifre değiştirme, hesap silme) ─────────────────

  /// Oturumdaki hesabı **mevcut şifresiyle** yeniden doğrular.
  ///
  /// İki işi birden yapar. Biri güvenlik: istemci elindeki bir şifrenin doğru
  /// olup olmadığını başka türlü anlayamaz, "eski şifreyi bilme şartı"nın tek
  /// gerçek karşılığı budur. Diğeri teknik: `updatePassword` ve `delete`
  /// Firebase'de hassas işlemdir; son girişin üzerinden birkaç dakikadan
  /// fazla geçtiyse `requires-recent-login` ile düşerler.
  ///
  /// Yanlış şifrede `invalid-credential` (bazı sürümlerde `wrong-password`)
  /// atar — çağıran taraf bunu "mevcut şifren hatalı" diye çevirmeli.
  Future<void> reauthenticateWithPassword(String password) async {
    final User user = _requireUser();
    final String email = user.email ?? '';
    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Hesaba bağlı e-posta yok.',
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// Aynı doğrulamanın SMS'li yolu — eski şifresini hatırlamayan kullanıcı
  /// için. Numara doğrulama sırasında Auth hesabına bağlandığı için (bkz.
  /// `phone_verify_sheet.dart`) bu kimlik bilgisi aynı hesabı işaret eder;
  /// başka bir numaranın kodu `user-mismatch` ile reddedilir.
  Future<void> reauthenticateWithPhoneCredential(
    PhoneAuthCredential credential,
  ) => _requireUser().reauthenticateWithCredential(credential);

  User _requireUser() {
    final User? user = fbAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Oturum bulunamadı.',
      );
    }
    return user;
  }

  Future<void> signOut() async {
    // Bu cihaz çıkış yapan hesabın push bildirimlerini almaya devam etmesin
    // (İP-6). Oturum kapanmadan önce: kural silme için oturum istiyor.
    // Ağ yoksa çıkışı bekletmez; sunucu geçersiz jetonu zamanla temizler.
    try {
      await PushService.instance.unregister().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google oturumu yoksa yok say.
    }
    // İP-DM3: demoda hazır hesap bırakılır, sunucu yapılanları geri alır.
    if (kDemoMode) await releaseDemoSlot();
    await fbAuth.signOut();
  }

  /// Yalnızca mevcut `users/{uid}` belgesinin giriş bilgilerini tazeler.
  ///
  /// İlk hesap ve profil yazımı onboarding formunun nihai kaydında yapılır;
  /// belge henüz yoksa [DocumentReference.update] `not-found` ile başarısız
  /// olur ve burada yarım bir hesap iskeleti oluşturulmaz.
  Future<void> recordExistingUserLogin(User user) =>
      userDoc(user.uid).update(<String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Firestore kurallarındaki `isClubUser` kontrolü `users` dokümanına bakar.
  /// Rol değişiminde bu kaydı senkron tutmak gerekir
  /// (club-create-event.js#loadContext'teki yazma).
  Future<void> syncActiveRoleToUserDoc(String uid, String role) =>
      userDoc(uid).update(<String, dynamic>{
        'role': role,
        'lastRole': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Google/Apple ile gelen hesaba şifre bağlar (info.js#ensureManualPassword).
  Future<void> linkPassword(User user, String password) async {
    await user.linkWithCredential(
      EmailAuthProvider.credential(email: user.email ?? '', password: password),
    );
  }

  bool hasPasswordProvider(User user) =>
      user.providerData.any((UserInfo info) => info.providerId == 'password');
}
