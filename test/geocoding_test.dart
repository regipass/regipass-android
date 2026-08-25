import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/services/geocoding_service.dart';

/// Adres arama testleri.
///
/// Bu testler somut bir hatadan doğdu: istek `lang=tr` ile gönderiliyordu,
/// Photon bu dili kabul etmediği için her isteğe HTTP 400 dönüyor ve öneri
/// listesi **sessizce** boş kalıyordu. Hata, hem mobilde hem web'de aynı
/// parametre kullanıldığı için iki tarafta birden vardı ve kimse fark
/// etmiyordu — çünkü boş liste "sonuç yok" gibi görünüyor.
void main() {
  group('Photon istek adresi', () {
    test('lang parametresi göndermez', () {
      final Uri uri = photonSuggestUri('boğaziçi üniversitesi');

      expect(
        uri.queryParameters.containsKey('lang'),
        isFalse,
        reason: 'Photon yalnızca default/de/en/fr kabul ediyor; lang=tr '
            'gönderilirse tüm istek 400 döner.',
      );
    });

    test('sorguyu ve Türkiye merkezli yanlılığı taşır', () {
      final Uri uri = photonSuggestUri('kadıköy');

      expect(uri.host, 'photon.komoot.io');
      expect(uri.queryParameters['q'], 'kadıköy');
      expect(uri.queryParameters['lat'], '39');
      expect(uri.queryParameters['lon'], '35');
    });
  });

  group('Photon yanıtı ayrıştırma', () {
    // Gerçek yanıttan kısaltılmış örnek.
    const String sample = '''
{"features":[
  {"geometry":{"coordinates":[29.0505009,41.0832734],"type":"Point"},
   "properties":{"name":"Boğaziçi Üniversitesi Güney Yerleşkesi",
                 "city":"Beşiktaş","country":"Türkiye"}},
  {"geometry":{"coordinates":[29.0535915,41.0844751],"type":"Point"},
   "properties":{"name":"Boğaziçi Üniversitesi","city":"Sarıyer",
                 "country":"Türkiye"}}
],"type":"FeatureCollection"}''';

    test('ad, bölge ve koordinatları çıkarır', () {
      final List<GeoPlace> places = parsePhotonResponse(sample);

      expect(places.length, 2);
      expect(places.first.name, 'Boğaziçi Üniversitesi Güney Yerleşkesi');
      expect(places.first.subtitle, contains('Beşiktaş'));
      // Photon [lng, lat] sırasıyla döner — ters okunursa iğne Afrika'ya düşer.
      expect(places.first.lat, closeTo(41.0832734, 0.000001));
      expect(places.first.lng, closeTo(29.0505009, 0.000001));
    });

    test('etiket ad + bölgeyi birleştirir', () {
      final GeoPlace place = parsePhotonResponse(sample).last;
      expect(place.label, 'Boğaziçi Üniversitesi, Sarıyer, Türkiye');
    });

    test('bozuk ya da eksik kayıtlar listeyi düşürmez', () {
      const String broken = '''
{"features":[
  {"properties":{"name":"Koordinatsız"}},
  {"geometry":{"coordinates":[1]},"properties":{"name":"Yarım koordinat"}},
  {"geometry":{"coordinates":[32.85,39.92]},"properties":{"name":"Ankara"}}
]}''';

      final List<GeoPlace> places = parsePhotonResponse(broken);

      expect(places.length, 1);
      expect(places.single.name, 'Ankara');
    });

    test('geçersiz JSON boş liste döner, patlamaz', () {
      expect(parsePhotonResponse('bu json degil'), isEmpty);
      // Photon hata gövdesi de bir Map ama features taşımıyor.
      expect(
        parsePhotonResponse('{"lang":[{"message":"not supported"}]}'),
        isEmpty,
      );
    });
  });
}
