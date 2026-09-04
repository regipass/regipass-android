/// js/modules/events/geo-fence.js portu.
///
/// **Salondaki** oturum QR'ını okutan öğrencinin gerçekten etkinlik alanında
/// olup olmadığını kontrol eder. Evden, arkadaşının gönderdiği ekran
/// görüntüsünü okutan öğrenci bu adımda reddedilir.
///
/// ## Kapı check-in'inde kullanılmaz
///
/// Kapıda iki yön de fizikseldir: ya QR'ı görevli okutur (öğrencinin bileti),
/// ya da öğrenci görevlinin ekrandaki kodunu okutur. Her iki durumda da öğrenci
/// zaten kapıda durmaktadır; konum sormak gereksiz bir izin isteği ve her
/// öğrenci için saniyeler süren bir gecikmedir. Kapıdaki sınır konum değil,
/// kulübün kapıyı açık tutmasıdır (`events.entryOpen`).
///
/// Bu kontrol de istemcidedir ve tek başına bir güvenlik sınırı değildir
/// (bkz. `session_qr_window.dart`). Gerçek sınırlar `firestore.rules` içinde.
library;

import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../models/event.dart';

/// Doğrulamanın nasıl sonuçlandığı. Metinler burada üretilmez; çağıran ekran
/// kendi sözlüğünden çevirir (web'de sabit Türkçe cümleler gömülüydü).
enum GeoFenceOutcome {
  /// Etkinliğin tanımlı konumu yok — adım tamamen atlandı, izin bile istenmedi.
  skipped,

  /// Cihaz etkinlik alanının içinde.
  inside,

  /// Konum alındı ama yarıçapın dışında.
  tooFar,

  /// Konum servisi kapalı ya da izin verilmedi.
  unavailable,
}

class GeoFenceResult {
  const GeoFenceResult(this.outcome, {this.distanceM});

  final GeoFenceOutcome outcome;

  /// Yalnızca [GeoFenceOutcome.inside] ve [GeoFenceOutcome.tooFar] için dolu.
  final double? distanceM;

  bool get ok =>
      outcome == GeoFenceOutcome.inside || outcome == GeoFenceOutcome.skipped;
}

class GeoFenceService {
  const GeoFenceService();

  /// Web'deki `POSITION_OPTIONS` karşılığı: yüksek doğruluk, 12 sn üst sınır.
  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 12),
  );

  /// Cihazın konumu; servis kapalıysa ya da izin yoksa `null`.
  Future<Position?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(locationSettings: _settings);
    } catch (_) {
      // Zaman aşımı / platform hatası: konum alınamadı sayılır.
      return null;
    }
  }

  /// Etkinliğin konumu ile cihazın konumunu karşılaştırır.
  Future<GeoFenceResult> verify(AppEvent event) async {
    if (!event.hasLocationCheck) {
      return const GeoFenceResult(GeoFenceOutcome.skipped);
    }

    final Position? position = await currentPosition();
    if (position == null) {
      return const GeoFenceResult(GeoFenceOutcome.unavailable);
    }

    final double distanceM = haversineDistanceM(
      position.latitude,
      position.longitude,
      event.locationLat!,
      event.locationLng!,
    );

    return GeoFenceResult(
      distanceM > event.effectiveRadius
          ? GeoFenceOutcome.tooFar
          : GeoFenceOutcome.inside,
      distanceM: distanceM,
    );
  }
}
