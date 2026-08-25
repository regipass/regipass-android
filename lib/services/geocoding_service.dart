/// Adresten koordinat (ve tersi) çözümleme.
///
/// club-create-event.js#fetchGeocodeSuggestions / reverseGeocode portu.
/// Harita ekranı (location_picker_screen.dart) bu iki servisi kullanır:
///   • Photon (komoot)   — yazarken öneri listesi
///   • Nominatim (OSM)   — iğnenin durduğu noktanın adresi
///
/// İkisi de anahtarsızdır ve web tarafıyla aynı sonuçları verir; böylece iki
/// istemcide seçilen konumlar birbirini tutar.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Nominatim kullanım koşulları tanımlayıcı bir User-Agent istiyor.
const String _kUserAgent = 'Regipass/1.0 (mobile)';

/// Öneri istemek için gereken en az karakter. Daha kısa metinlerde sonuçlar
/// anlamsız oluyor ve servise gereksiz yük biniyor.
const int kMinSuggestLength = 2;

/// Photon öneri adresi.
///
/// **`lang` parametresi bilerek yok.** Photon yalnızca `default, de, en, fr`
/// kabul ediyor; `lang=tr` gönderildiğinde tüm isteği HTTP 400 ile reddediyor
/// ve öneri listesi sessizce boş kalıyor (bu hata bir süre fark edilmedi).
/// Varsayılan dil OSM'deki yerel adı döndürdüğü için sonuçlar zaten Türkçe.
///
/// `lat`/`lon` Türkiye merkezine sabit: yakın sonuçlar öne çıksın.
Uri photonSuggestUri(String query) => Uri.parse(
      'https://photon.komoot.io/api/'
      '?q=${Uri.encodeQueryComponent(query)}&limit=8&lat=39&lon=35',
    );

/// Photon yanıtını [GeoPlace] listesine çevirir.
///
/// Ayrı bir fonksiyon: ağ olmadan test edilebilsin diye.
List<GeoPlace> parsePhotonResponse(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return const <GeoPlace>[];
  }

  if (decoded is! Map<String, dynamic>) return const <GeoPlace>[];

  final Object? features = decoded['features'];
  if (features is! List) return const <GeoPlace>[];

  final List<GeoPlace> places = <GeoPlace>[];

  for (final Object? feature in features) {
    if (feature is! Map<String, dynamic>) continue;

    final Object? properties = feature['properties'];
    final Object? geometry = feature['geometry'];
    if (properties is! Map<String, dynamic> ||
        geometry is! Map<String, dynamic>) {
      continue;
    }

    final Object? coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) continue;

    final double? lng = (coordinates[0] as num?)?.toDouble();
    final double? lat = (coordinates[1] as num?)?.toDouble();
    if (lat == null || lng == null) continue;

    final String name = '${properties['name'] ?? ''}'.trim();
    final String street = '${properties['street'] ?? ''}'.trim();

    // İlçe/şehir/ülke: en fazla iki parça, tekrarsız.
    final List<String> area = <String>{
      '${properties['district'] ?? properties['city'] ?? properties['county'] ?? properties['state'] ?? ''}'
          .trim(),
      '${properties['city'] ?? properties['state'] ?? ''}'.trim(),
      '${properties['country'] ?? ''}'.trim(),
    }.where((String part) => part.isNotEmpty).take(2).toList();

    final String title = <String>[
      if (name.isNotEmpty) name,
      if (street.isNotEmpty && street != name) street,
    ].join(', ');

    if (title.isEmpty) continue;

    places.add(
      GeoPlace(name: title, subtitle: area.join(', '), lat: lat, lng: lng),
    );
  }

  return places;
}

/// Arama sonucu tek bir yer.
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String subtitle;
  final double lat;
  final double lng;

  /// Konum adı alanına yazılacak tam etiket.
  String get label =>
      subtitle.isEmpty ? name : '$name, $subtitle';
}

class GeocodingService {
  const GeocodingService();

  /// Yazarken gösterilen öneriler.
  ///
  /// lat/lon Türkiye merkezine sabitlenir ki Türkiye'ye yakın sonuçlar öne
  /// çıksın.
  ///
  /// `lang` parametresi BİLEREK gönderilmiyor: Photon yalnızca
  /// `default, de, en, fr` kabul ediyor, `lang=tr` gönderildiğinde tüm isteği
  /// HTTP 400 ile reddediyor (öneri listesi bu yüzden hep boş kalıyordu).
  /// Varsayılan dil zaten OSM'deki yerel adı döndürüyor, yani sonuçlar Türkçe.
  Future<List<GeoPlace>> suggest(String query) async {
    final String trimmed = query.trim();
    if (trimmed.length < kMinSuggestLength) return const <GeoPlace>[];

    try {
      final http.Response response = await http
          .get(photonSuggestUri(trimmed), headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': _kUserAgent,
          })
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return const <GeoPlace>[];

      return parsePhotonResponse(utf8.decode(response.bodyBytes));
    } catch (_) {
      // Ağ hatası önerileri sessizce boşaltır; kullanıcı haritayı elle
      // kaydırmaya ya da GPS'e devam edebilir.
      return const <GeoPlace>[];
    }
  }

  /// Koordinattan okunabilir adres. Çözülemezse koordinatın kendisi döner.
  Future<String> reverse(double lat, double lng) async {
    final Uri uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lng&format=json&accept-language=tr',
    );

    try {
      final http.Response response = await http
          .get(uri, headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': _kUserAgent,
          })
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return _fallbackLabel(lat, lng);

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return _fallbackLabel(lat, lng);

      final String display = '${decoded['display_name'] ?? ''}'.trim();
      return display.isEmpty ? _fallbackLabel(lat, lng) : display;
    } catch (_) {
      return _fallbackLabel(lat, lng);
    }
  }

  static String _fallbackLabel(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}
