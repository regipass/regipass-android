/// js/modules/events/geo-fence.js portu.
///
/// **Salondaki** oturum QR'ını okutan öğrencinin gerçekten etkinlik alanında
/// olup olmadığını kontrol eder. Evden, arkadaşının gönderdiği ekran
/// görüntüsünü okutan öğrenci bu adımda reddedilir.
///
/// Öğrencinin okuttuğu kapı ve oturum QR'larında aynı kontrol uygulanır.
/// Bu cihaz kontrolü istemcidedir; sunucuda GPS doğrulaması sağlamaz.
library;

import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../models/event.dart';

/// Doğrulamanın nasıl sonuçlandığı. Metinler burada üretilmez; çağıran ekran
/// kendi sözlüğünden çevirir (web'de sabit Türkçe cümleler gömülüydü).
enum GeoFenceOutcome {
  /// Cihaz etkinlik alanının içinde.
  inside,

  /// Etkinlikte koordinat tanımlı değil; bu nedenle cihazdan konum istenmedi.
  skipped,

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
    // Konumu olmayan etkinlikte izin istemek hem gereksiz hem de QR akışını
    // engeller. Bu durumda check-in, QR'ın diğer canlılık/kayıt kurallarıyla
    // devam eder. Eksik veya bozuk koordinatlar ise bu istisna değildir.
    if (event.hasNoLocationCheck) {
      return const GeoFenceResult(GeoFenceOutcome.skipped);
    }
    if (!event.hasLocationCheck) {
      return const GeoFenceResult(GeoFenceOutcome.unavailable);
    }

    final Position? position = await currentPosition();
    if (position == null ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
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
