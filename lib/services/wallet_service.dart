/// Bileti cüzdana ekle (İP-W) — js/modules/wallet/wallet-buttons.js karşılığı.
/// Ayar kapalıyken (şu an) düğme görünmez; bkz. Regipass-Web/docs/ip-w-wallet-kurulum.md.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wallet.dart';
import 'firebase_refs.dart';

class WalletService {
  const WalletService();

  /// Sunucunun verdiği adres (Apple .pkpass ya da Google kaydetme bağlantısı).
  Future<String> passUrl(
    String registrationId,
    WalletPlatform platform, {
    String lang = 'tr',
  }) async {
    final HttpsCallableResult<Object?> result = await fbFunctions
        .httpsCallable('walletPass')
        .call(<String, Object>{
          'registrationId': registrationId,
          'platform': platform.name,
          'lang': lang,
        });
    final Object? data = result.data;
    final String url = data is Map && data['url'] is String
        ? data['url'] as String
        : '';
    if (!isSafeWalletUrl(url)) throw StateError('bad-wallet-url');
    return url;
  }
}

String walletErrorReason(Object error) {
  if (error is FirebaseFunctionsException) {
    final Object? details = error.details;
    if (details is Map && details['reason'] is String) {
      return details['reason'] as String;
    }
  }
  return '';
}

final Provider<WalletService> walletServiceProvider = Provider<WalletService>(
  (Ref ref) => const WalletService(),
);

/// Firestore app_config/wallet { apple, google } — okunamazsa kapalı.
final FutureProvider<Map<String, Object?>> walletConfigProvider =
    FutureProvider<Map<String, Object?>>((Ref ref) async {
      try {
        final DocumentSnapshot<Map<String, dynamic>> snap = await fbDb
            .collection('app_config')
            .doc('wallet')
            .get();
        return snap.data() ?? const <String, Object?>{};
      } catch (_) {
        return const <String, Object?>{};
      }
    });
