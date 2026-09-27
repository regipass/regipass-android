/// Bileti cüzdana ekle (İP-W) — saf kurallar. Web: js/modules/wallet/wallet-core.js.
library;

enum WalletPlatform { apple, google }

/// Ayar (Firestore app_config/wallet) + cihaz → görünen düğmeler.
List<WalletPlatform> walletButtonsFor(
  Map<String, Object?>? config, {
  required bool isIos,
  required bool isAndroid,
}) {
  final List<WalletPlatform> out = <WalletPlatform>[];
  if (config?['apple'] == true && (isIos || !isAndroid)) {
    out.add(WalletPlatform.apple);
  }
  if (config?['google'] == true && (isAndroid || !isIos)) {
    out.add(WalletPlatform.google);
  }
  return out;
}

bool walletAllowed({required bool cancelled, required bool paymentPending}) =>
    !cancelled && !paymentPending;

/// Sunucunun döndürdüğü adres yalnızca beklenen iki yerden olabilir.
bool isSafeWalletUrl(String url) => RegExp(
  r'^https://(pay\.google\.com|firebasestorage\.googleapis\.com)/',
).hasMatch(url);

String walletErrorKey(String reason) => switch (reason) {
  'wallet-disabled' || 'wallet-not-configured' => 'wallet.error.disabled',
  'payment-pending' => 'wallet.error.paymentPending',
  'event-cancelled' => 'wallet.error.cancelled',
  'event-past' => 'wallet.error.past',
  _ => 'wallet.error.generic',
};
