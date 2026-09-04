/// Ülkelere göre **cep telefonu** operatör ön ekleri (ulusal numaranın ilk
/// haneleri; trunk ön eki — ör. baştaki 0 — hariç).
///
/// Neden var: hane sayısı doğru olan bir sabit hat ya da yanlış ülkeden
/// yazılmış bir numara da `min..max` denetiminden geçiyordu; SMS ancak
/// gönderildikten sonra ulaşmadığı anlaşılıyordu. Bu tablo, doğrulama kodu
/// istenmeden önce "bu numara gerçekten bu ülkenin cebi mi" sorusunu
/// yanıtlar (bkz. domain/phone_precheck.dart).
///
/// **Kapsam bilinçli olarak dar:** yalnızca ön ek listesinden emin olduğumuz
/// ülkeler burada. Listede olmayan ülke için ön ek denetimi hiç yapılmaz —
/// eksik/eskimiş bir listeyle gerçek bir numarayı bloklamak, denetimi
/// atlamaktan daha kötüdür. Yeni ülke eklerken kaynak numaralandırma
/// planını (ör. BTK, Ofcom) yorumda belirtin.
library;

/// Türkiye (BTK cep numaralandırma planı): 50x, 53x, 54x, 55x, 56x.
/// 51x/52x/57x/58x/59x cebe tahsis edilmemiştir; 2xx/3xx/4xx sabit hattır.
const List<String> _tr = <String>['50', '53', '54', '55', '56'];

/// ISO ülke kodu -> ulusal numaranın başlayabileceği ön ekler.
///
/// Ön ekler farklı uzunlukta olabilir; eşleştirme [String.startsWith] ile
/// yapılır (bkz. domain/phone_precheck.dart).
const Map<String, List<String>> kMobilePrefixes = <String, List<String>>{
  'TR': _tr,
};
