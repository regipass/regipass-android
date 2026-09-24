/// FCM cihaz jetonları: `users/{uid}/devices/{kurulumKimliği}` (İP-6).
///
/// Belge kimliği jeton değil, bu kuruluma özel rastgele kimlik: jeton
/// yenilendiğinde aynı belge güncellenir, eski jeton geride kalmaz.
/// Sunucu push gönderirken bu belgeleri okur, geçersiz jetonları siler.
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import 'firebase_refs.dart';

/// Kurallardaki `validDevice()` ile aynı alan listesi.
Map<String, Object> deviceDocData({
  required String token,
  required String platform,
  required String language,
  String appVersion = '',
  int? nowMs,
}) => <String, Object>{
  'token': token,
  'platform': platform == 'ios' ? 'ios' : 'android',
  'language': language == 'en' ? 'en' : 'tr',
  if (appVersion.isNotEmpty) 'appVersion': appVersion,
  'updatedAt': FieldValue.serverTimestamp(),
  'updatedAtMs': nowMs ?? DateTime.now().millisecondsSinceEpoch,
};

class DeviceTokenRepository {
  const DeviceTokenRepository({this.firestore});

  final FirebaseFirestore? firestore;

  static const String _installIdKey = 'regipass_install_id';

  Doc _device(String uid, String installId) => (firestore ?? fbDb)
      .collection(Collections.users)
      .doc(uid)
      .collection('devices')
      .doc(installId);

  /// Bu kurulumun kalıcı kimliği (ilk çağrıda üretilir).
  static Future<String> installId([SharedPreferences? prefs]) async {
    final SharedPreferences store =
        prefs ?? await SharedPreferences.getInstance();
    final String? existing = store.getString(_installIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    const String alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random.secure();
    final String id = List<String>.generate(
      24,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    await store.setString(_installIdKey, id);
    return id;
  }

  Future<void> save({
    required String uid,
    required String installId,
    required String token,
    required String platform,
    required String language,
    String appVersion = '',
  }) => _device(uid, installId).set(
    deviceDocData(
      token: token,
      platform: platform,
      language: language,
      appVersion: appVersion,
    ),
  );

  Future<void> remove({required String uid, required String installId}) =>
      _device(uid, installId).delete();
}
