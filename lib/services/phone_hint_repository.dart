import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';

import '../core/app_log.dart';
import '../core/constants.dart';
import 'firebase_refs.dart';

class PasswordResetHint {
  const PasswordResetHint({
    required this.maskedPhone,
    required this.roles,
    this.resolved = true,
  });

  /// Hiçbir kaynağa ulaşılamadığında dönen sonuç. [resolved] `false` olduğu
  /// için "bu hesabın telefonu yok" diye yorumlanamaz.
  static const PasswordResetHint unavailable = PasswordResetHint(
    maskedPhone: '',
    roles: <String>[],
    resolved: false,
  );

  final String maskedPhone;
  final List<String> roles;

  /// Bir kaynak (Firestore ipucu ya da Auth'u okuyan Cloud Function)
  /// gerçekten yanıt verdi mi?
  ///
  /// Boş [maskedPhone] iki ayrı şey demek olabilir: "hesaba bağlı doğrulanmış
  /// telefon yok" ya da "okuyamadık". Birincisinde kullanıcıyı SMS
  /// beklemeden uyarmak gerekir, ikincisinde akışı durdurmak kullanıcıyı
  /// kurtarmadan tamamen koparır. [resolved] ikisini ayırır.
  final bool resolved;

  /// Karşılaştırılabilir bir maske elde var mı?
  bool get hasMask => maskedPhone.isNotEmpty;

  /// Kaynak yanıt verdi ve hesapta doğrulanmış telefon **yok**.
  bool get knownPhoneless => resolved && maskedPhone.isEmpty;
}

/// js/modules/auth/phone-hint.js karşılığı.
///
/// Şifresini unutmuş kullanıcı giriş YAPMAMIŞ durumdadır; profil
/// koleksiyonları yalnızca sahibine açık olduğu için oradan telefon
/// okunamaz. Bu koleksiyon sadece bu ekranın ihtiyacı kadar veri taşır.
///
/// **Saklanan:** önceden maskelenmiş metin ("+90 XXX XXX XX 67") ve bu
/// e-postada bulunan hesap türleri (`student`, `club`).
/// **Saklanmayan:** tam numara, e-posta (anahtar e-postanın SHA-256'sı), isim,
/// uid veya başka profil alanı.
///
/// Kayıt tamamen görseldir: doğrulama SMS'i her zaman Firebase Auth'a bağlı
/// gerçek numaraya gider, buradaki metin değiştirilse bile kodun gittiği
/// numara değişmez.
///
/// Anahtar ve alan adları web ile birebir aynı olmak zorunda — iki istemci
/// aynı belgeleri okuyup yazıyor.
class PhoneHintRepository {
  const PhoneHintRepository();

  /// Maske değil, sunucudaki güncel Firebase Auth numarası karşılaştırılır.
  /// Hata durumunda çağıran SMS göndermemelidir.
  Future<bool> matchesAccountPhone({
    required String email,
    required String phoneE164,
  }) async {
    final result = await fbFunctions
        .httpsCallable(
          'checkPasswordResetPhone',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
        )
        .call(<String, String>{
          'email': email.trim().toLowerCase(),
          'phoneE164': phoneE164,
        });
    return result.data is Map && result.data['match'] == true;
  }

  static const String _collection = 'phone_hints';

  /// E-posta düz metin yazılmasın diye SHA-256 (küçük harf hex).
  /// phone-hint.js#hashEmail ile aynı: trim + toLowerCase + sha256 + hex.
  static String hashEmail(String email) {
    final String normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  /// Maskeli ipucunu okur. Bulunamazsa boş dize döner.
  ///
  /// Kurallarda `get` açık, `list` kapalı — yani yalnızca tam anahtarı
  /// (e-postanın hash'i) üretebilen tek tek okuyabilir, koleksiyon
  /// listelenip toplu tarama yapılamaz.
  Future<PasswordResetHint> readHint(String email) async {
    final String key = hashEmail(email);
    // Boş e-posta sorulmadı bile; "telefonu yok" diye yorumlanmamalı.
    if (key.isEmpty) return PasswordResetHint.unavailable;

    try {
      final PasswordResetHint stored = await readStoredHint(
        key,
      ).timeout(const Duration(seconds: 3));
      // Maskesiz kip açıkken elde kalmış ESKİ maskeli belge işe yaramaz:
      // birebir karşılaştırma yapılamaz, kullanıcı yine yalnızca son iki
      // hanesi tutan bir numarayla geçebilirdi. Böyle bir belge yok sayılıp
      // Auth'u okuyan Cloud Function'a düşülür; o tam numarayı döndürür.
      if (stored.maskedPhone.isNotEmpty && !_isStaleMask(stored.maskedPhone)) {
        return stored;
      }
    } catch (error) {
      _logReadFailure('firestore', error);
    }
    // Eski kurallar yazmayı reddetmişse kullanıcı tekrar giriş yapamadan da
    // kurtarma ipucunu görebilmeli. Sunucu yalnızca Auth numarasını maskeler.
    try {
      return await readAuthHint(
        email.trim().toLowerCase(),
      ).timeout(const Duration(seconds: 8));
    } catch (error) {
      _logReadFailure('authHint', error);
      return PasswordResetHint.unavailable;
    }
  }

  /// Maskesiz kip açıkken hâlâ maske taşıyan belge.
  static bool _isStaleMask(String value) =>
      kRevealPasswordResetPhone && (value.contains('X') || value.contains('x'));

  Future<PasswordResetHint> readStoredHint(String key) async {
    final Snap snap = await fbDb
        .collection(_collection)
        .doc(key)
        .get(const GetOptions(source: Source.server));
    return _parseHint(snap.data() ?? <String, dynamic>{});
  }

  Future<PasswordResetHint> readAuthHint(String email) async {
    final HttpsCallableResult<dynamic> result = await fbFunctions
        .httpsCallable(
          'getPasswordResetHint',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
        )
        .call(<String, String>{'email': email});
    return _parseHint(
      result.data is Map ? result.data as Map : <String, dynamic>{},
    );
  }

  static PasswordResetHint _parseHint(Map<dynamic, dynamic> data) {
    final Object? rawRoles = data['roles'];
    final List<String> roles = rawRoles is List
        ? rawRoles.whereType<String>().where(UserRole.isValid).toSet().toList()
        : const <String>[];
    return PasswordResetHint(
      maskedPhone: data['maskedPhone'] is String
          ? data['maskedPhone'] as String
          : '',
      roles: roles,
    );
  }

  static void _logReadFailure(String source, Object error) {
    AppLog.warn('phoneHint.readFailed', <String, Object?>{
      'source': source,
      'code': error is FirebaseException
          ? error.code
          : error.runtimeType.toString(),
    });
  }

  Future<String> read(String email) async =>
      (await readHint(email)).maskedPhone;

  /// Hesap silinirken ipucunu da kaldırır.
  ///
  /// En iyi çaba ve gerçekten öyle: kurallarda bu koleksiyonda silme kapalı
  /// olabilir (`allow delete: if false`). Kalan ipucu bir sızıntı değil —
  /// içinde yalnızca maske var ve zaten herkese açık okunuyor — ama aynı
  /// e-postayla açılan yeni bir hesap ilk telefon doğrulamasına kadar eski
  /// maskeyi gösterirdi.
  Future<void> delete(String email) async {
    final String key = hashEmail(email);
    if (key.isEmpty) return;

    try {
      await fbDb.collection(_collection).doc(key).delete();
    } catch (_) {
      // Yok say.
    }
  }

  /// Doğrulanmış numaranın maskeli ipucunu yazar.
  ///
  /// En iyi çaba: başarısız olursa çağıran akış (telefon doğrulama) bozulmaz.
  Future<bool> write({
    required String email,
    required String maskedPhone,
    required Iterable<String> roles,
  }) async {
    final String key = hashEmail(email);
    if (key.isEmpty || maskedPhone.isEmpty) return false;

    final List<String> validRoles = roles
        .where(UserRole.isValid)
        .toSet()
        .toList();
    if (validRoles.isEmpty) return false;

    try {
      await fbDb
          .collection(_collection)
          .doc(key)
          .set(<String, dynamic>{
            'maskedPhone': maskedPhone,
            'roles': validRoles,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      // Yayındaki eski kural henüz `roles` alanını kabul etmiyorsa maskeli
      // telefon ipucunu kaybetme. Kural güncellendiğinde bir sonraki oturum
      // senkronu yeni biçimi kendiliğinden tekrar dener.
      try {
        await fbDb
            .collection(_collection)
            .doc(key)
            .set(<String, dynamic>{
              'maskedPhone': maskedPhone,
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 5));
        return true;
      } catch (error) {
        // Burası sessiz kalırsa hata çok sonra, "şifremi unuttum" ekranında
        // ortaya çıkıyor: maske hiç yazılmadığı için ekran hesabın telefonu
        // yokmuş gibi davranıyor. En sık nedeni yayındaki firestore.rules
        // dosyasında `phone_hints` bloğunun bulunmaması (permission-denied).
        AppLog.error(
          'phoneHint.writeFailed',
          error: error,
          fields: <String, Object?>{
            'code': error is FirebaseException ? error.code : null,
            'roles': validRoles.join(','),
          },
        );
        return false;
      }
    }
  }
}
