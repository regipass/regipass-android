/// Ağ bağlantısı durumu.
///
/// Firebase çevrimdışıyken sessizce önbellekten okuyor ve yazmaları kuyruğa
/// alıyor: kullanıcı bir şeyin ters gittiğini ancak işlem "asılı kaldığında"
/// fark ediyordu. Bu sağlayıcı bağlantıyı açıkça izleyip arayüzde uyarı
/// gösterilmesini sağlar.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cihazın herhangi bir ağa bağlı olup olmadığı.
///
/// `connectivity_plus` yalnızca **arayüz** durumunu bildirir: Wi-Fi'a bağlı
/// ama internete çıkamayan bir cihaz burada "bağlı" görünür. Yine de
/// kullanıcının uçak modunu açtığı ya da şebekeyi kaybettiği durumları —
/// yani vakaların çoğunu — anında yakalar.
final StreamProvider<bool> isOnlineProvider = StreamProvider<bool>((Ref ref) {
  final Connectivity connectivity = Connectivity();

  return connectivity.onConnectivityChanged.map(_hasNetwork);
});

/// Açılışta bir kez okunan durum: akış ilk olayı yayınlayana kadar arayüz
/// "bağlı" varsayar, aksi hâlde her açılışta kısa bir uyarı çakardı.
final FutureProvider<bool> initialOnlineProvider = FutureProvider<bool>(
  (Ref ref) async => _hasNetwork(await Connectivity().checkConnectivity()),
);

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.any((ConnectivityResult r) => r != ConnectivityResult.none);

/// Arayüzün okuduğu birleşik durum.
///
/// Akış henüz bir şey yayınlamadıysa açılıştaki tek seferlik ölçüme,
/// o da yoksa "bağlı" varsayımına düşer.
final Provider<bool> onlineProvider = Provider<bool>((Ref ref) {
  final AsyncValue<bool> live = ref.watch(isOnlineProvider);
  if (live.hasValue) return live.value!;

  return ref.watch(initialOnlineProvider).value ?? true;
});
