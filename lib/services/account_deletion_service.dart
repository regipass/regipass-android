/// İP-G2: kullanıcının kendi hesabını silme talebi (30 gün bekler).
///
/// Sunucu: functions/adminAccounts.js `requestMyDeletion` / `cancelMyDeletion`.
/// Talep sonrası kayıtlar hemen bırakılır, `users/{uid}.pendingDeletion`
/// işaretlenir; 30 gün içinde giriş yapan kullanıcı geri alabilir. Süre
/// dolunca sunucu (purgeScheduledDeletions) her şeyi siler.
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_refs.dart';

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.reason);

  /// Sunucunun `details.reason` değeri: `club-has-events`, `banned`,
  /// `recent-login-required`, `admin-scheduled` ya da boş.
  final String reason;

  @override
  String toString() => 'AccountDeletionException($reason)';
}

class AccountDeletionService {
  const AccountDeletionService();

  /// Silme talebini bırakır. Dönüş: kalıcı silme zamanı (ms).
  Future<int?> requestMyDeletion() async {
    // Sunucu son 15 dakikada kimlik doğrulaması ister; yeniden doğrulamadan
    // sonra jetonu tazele ki `auth_time` güncel gitsin.
    await fbAuth.currentUser?.getIdToken(true);
    final Map<String, dynamic> data = await _call('requestMyDeletion');
    final Object? ms = data['purgeAfterMs'];
    return ms is num ? ms.toInt() : null;
  }

  Future<void> cancelMyDeletion() async {
    await _call('cancelMyDeletion');
  }

  Future<Map<String, dynamic>> _call(String name) async {
    try {
      final HttpsCallableResult<dynamic> result = await fbFunctions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          )
          .call(<String, Object>{});
      final Object? data = result.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (error) {
      final Object? details = error.details;
      final String reason = details is Map && details['reason'] is String
          ? details['reason'] as String
          : '';
      throw AccountDeletionException(reason);
    }
  }
}
