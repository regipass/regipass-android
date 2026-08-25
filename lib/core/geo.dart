import 'dart:math' as math;

/// İki GPS koordinatı arasındaki mesafe (metre) — Haversine.
///
/// Web tarafında aynı fonksiyon üç dosyada kopyalanmıştı
/// (club-events.js, club-qr-checkin.js, club-create-event.js);
/// burada tek yerde toplandı.
double haversineDistanceM(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const double earthRadiusM = 6371000;
  double toRad(double deg) => deg * math.pi / 180;

  final double dLat = toRad(lat2 - lat1);
  final double dLng = toRad(lng2 - lng1);

  final double a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);

  return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Mesafeyi kullanıcıya gösterilecek biçime çevirir (1 km altı metre).
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';
