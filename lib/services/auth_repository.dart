import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants.dart';
import 'firebase_refs.dart';

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

    final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();
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
  ) =>
      fbAuth.signInWithCredential(credential);

  /// Oturum açmış kullanıcının şifresini değiştirir.
  Future<void> updatePassword(String newPassword) async {
    final User? user = fbAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Oturum bulunamadı.',
      );
    }
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google oturumu yoksa yok say.
    }
    await fbAuth.signOut();
  }

  /// `users/{uid}` ve ilgili profil dokümanını oluşturur/günceller.
  /// (login-modal.js#upsertBaseUser ile birebir aynı yük.)
  Future<void> upsertBaseUser(User user, String role) async {
    final Doc ref = userDoc(user.uid);
    final Snap snap = await ref.get();

    final Map<String, dynamic> existing = snap.data() ?? <String, dynamic>{};
    final Object? rawRoles = existing['roles'];
    final Map<String, dynamic> existingRoles =
        rawRoles is Map ? Map<String, dynamic>.from(rawRoles) : <String, dynamic>{};

    final Map<String, dynamic> payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'photoURL': user.photoURL ?? '',
      'role': role,
      'lastRole': role,
      'roles': <String, dynamic>{...existingRoles, role: true},
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      payload['onboardingCompleted'] = false;
    }

    await ref.set(payload, SetOptions(merge: true));

    // Profil dokümanı yoksa iskeletini oluştur.
    final Doc profileRef =
        role == UserRole.student ? studentProfileDoc(user.uid) : clubProfileDoc(user.uid);

    if (!(await profileRef.get()).exists) {
      await profileRef.set(<String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'role': role,
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Firestore kurallarındaki `isClubUser` kontrolü `users` dokümanına bakar.
  /// Rol değişiminde bu kaydı senkron tutmak gerekir
  /// (club-create-event.js#loadContext'teki yazma).
  Future<void> syncActiveRoleToUserDoc(String uid, String role) =>
      userDoc(uid).set(<String, dynamic>{
        'role': role,
        'lastRole': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Google/Apple ile gelen hesaba şifre bağlar (info.js#ensureManualPassword).
  Future<void> linkPassword(User user, String password) async {
    await user.linkWithCredential(
      EmailAuthProvider.credential(email: user.email ?? '', password: password),
    );
  }

  bool hasPasswordProvider(User user) =>
      user.providerData.any((UserInfo info) => info.providerId == 'password');
}
