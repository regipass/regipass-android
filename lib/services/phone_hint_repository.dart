import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';

import '../core/app_log.dart';
import '../core/constants.dart';
import 'firebase_refs.dart';

class PasswordResetHint {
  const PasswordResetHint({required this.maskedPhone, required this.roles});

  final String maskedPhone;
  final List<String> roles;
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
    if (key.isEmpty) {
      return const PasswordResetHint(maskedPhone: '', roles: <String>[]);
    }

    try {
      final PasswordResetHint stored = await readStoredHint(
        key,
      ).timeout(const Duration(seconds: 3));
      if (stored.maskedPhone.isNotEmpty) return stored;
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
      return const PasswordResetHint(maskedPhone: '', roles: <String>[]);
    }
  }

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
