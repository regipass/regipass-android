import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'firebase_refs.dart';

/// js/modules/auth/phone-hint.js karşılığı.
///
/// Şifresini unutmuş kullanıcı giriş YAPMAMIŞ durumdadır; profil
/// koleksiyonları yalnızca sahibine açık olduğu için oradan telefon
/// okunamaz. Bu koleksiyon sadece bu ekranın ihtiyacı kadar veri taşır.
///
/// **Saklanan:** yalnızca önceden maskelenmiş metin ("+90 XXX XXX XX 67").
/// **Saklanmayan:** tam numara, e-posta (anahtar e-postanın SHA-256'sı),
/// isim, uid veya başka profil alanı.
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
  Future<String> read(String email) async {
    final String key = hashEmail(email);
    if (key.isEmpty) return '';

    try {
      final Snap snap = await fbDb.collection(_collection).doc(key).get();
      if (!snap.exists) return '';

      final Object? value = snap.data()?['maskedPhone'];
      return value is String ? value : '';
    } catch (_) {
      // İpucu okunamazsa akış durmaz; ekran maskesiz devam eder.
      return '';
    }
  }

  /// Doğrulanmış numaranın maskeli ipucunu yazar.
  ///
  /// En iyi çaba: başarısız olursa çağıran akış (telefon doğrulama) bozulmaz.
  /// [phoneE164] yalnızca maskelemek için kullanılır, olduğu gibi yazılmaz.
  Future<bool> write({required String email, required String maskedPhone}) async {
    final String key = hashEmail(email);
    if (key.isEmpty || maskedPhone.isEmpty) return false;

    try {
      await fbDb.collection(_collection).doc(key).set(<String, dynamic>{
        'maskedPhone': maskedPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
