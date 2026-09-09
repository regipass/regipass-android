# QR ve eşzamanlı kayıt ölçümü — 9 Eylül 2026

**Sonuç: önceden etkinliğe kayıtlı 1.000 öğrencinin eşzamanlı QR giriş/yoklama
yazımları yerel testte eksiksiz tamamlandı. Kontenjanlı yeni kayıt, aynı
güvenilirliği sağlayamadı. Bu ölçümden canlı iOS/Android/web için garanti
edilmiş azami öğrenci sayısı çıkarılamaz.**

## Kapsam ve yöntem

- Flutter çalışma klasörü: `C:/Users/5sana/StudioProjects/Regipass`.
- Web kaynakları salt okunur incelendi: `C:/Users/5sana/Desktop/REGİPASS`.
- Firestore emulator 1.22.0, Java 24, Node 24.14.1, Firebase JS SDK 12.18.0.
- Makine: i5-12450H, 12 mantıksal çekirdek, yaklaşık 23,7 GiB RAM.
- Yalnız `demo-regipass-qr-load`, `127.0.0.1:9091`; canlı veritabanına yük
  gönderilmedi, uygulama kodu veya yayınlanan kurallar değiştirilmedi.
- Her öğrenci ayrı authenticated Firebase test context ve bağımsız web modül
  durumu kullandı. Aynı senaryodaki işlemler tek `Promise.all` ile başlatıldı.
  İstemciler aynı Node sürecindedir; bunlar 1.000 fiziksel telefon değildir.
- Bağlantılar ölçümden önce ısıtıldı. Süre, öğrenci başına etkinlik ve kendi
  kayıt belgesinin sunucudan okunmasını, yazımı, mevcut kayıt yönteminin
  beklemelerini kapsar. Hazırlık, veri ekimi ve son bütünlük okumaları hariçtir.
- Mobil kayıt işlemi `RegistrationService` algoritmasının JS uyarlamasıdır:
  aynı öğrenci hash'i, 4/8/16/32 sayaç parçası, 8 tur, SDK `maxAttempts: 1`,
  150 ms tabanlı rastgele geri çekilme ve son doluluk kontrolü.
  Dart kodu yük testinde gerçek Android/iOS SDK'sıyla yürütülmedi.
- Web `quota-shards.js`, `registration-queue.js`, `quota-plan.js` fonksiyonları
  yerel kaynaktan alındı; yalnız import/bağımlılık bağlama ve günlük altyapısı
  test ortamına uyarlandı. Webin sayaç planı farklıdır (100 kişide 20 parça;
  mobilde 8). Testte SDK 12.18.0 kullanıldı; web kaynağının CDN sürümü 10.12.2.
  Bu yüzden tablolar saf bir platform performansı karşılaştırması değildir.
- Test etkinlikleri ücretsiz, `targetScope: public`; öğrenci kimlikleri
  sentetiktir. Başarıdan sonra kayıt sayısı, giriş/yoklama sayısı ve sayaç
  toplamı yeniden okundu. QR görüntü tanıma, GPS, Auth/OTP/SMS, hesap oluşturma,
  profil yükleme, Hosting, Functions tetikleyicileri ve canlı liste dinleyicileri
  yük senaryosuna dahil değildir.

## Ortak QR yazımları ve kontenjansız kayıt

Ana koşu: `qr-1788952721975.json`. Aşağıdaki süreler öğrencilerin %95'inin
işleminin tamamlandığı süredir (p95); canlı ağ gecikmesini temsil etmez.

| Eşzamanlı öğrenci | Kapı girişi | Oturum yoklaması | Kontenjansız yeni kayıt |
|---:|---:|---:|---:|
| 100 | 100/100 | 100/100 | 100/100 |
| 250 | 250/250 | 250/250 | 250/250 |
| 500 | 500/500 | 500/500 | 500/500 |
| 1.000 | 1.000/1.000; p95 3,714 sn | 1.000/1.000; p95 2,779 sn | 1.000/1.000; p95 3,139 sn |

1.000 kişilik koşuların toplam bitiş süreleri sırasıyla 3,743 / 2,801 / 3,163
saniyedir. Yazım hatası veya eksik giriş/yoklama görülmedi. 1.000, bu koşuda
denenen en yüksek sayıdır; sistemin azami kapasitesi olduğu gösterilmemiştir.

## Kontenjanlı yeni kayıt

Ana koşu: `qr-1788952789428.json`, Flutter klasöründeki yerel kurallar.
Her satırda kontenjan başvuran sayısına eşittir. Mobil ve web satırları
kendi sayaç planlarıyla oluşturulmuş ayrı etkinliklerdir.

| Eşzamanlı başvuru | Mobil algoritması: başarı / ret | Web fonksiyonları: başarı / ret |
|---:|---:|---:|
| 1 | 1 / 0 | 1 / 0 |
| 25 | 8 / 17 | 12 / 13 |
| 100 | 23 / 77 | 99 / 1 |
| 250 | 33 / 217 | 247 / 3 |

Bu tabloda retlerin tamamı `permission-denied`. Kontenjan boşken de kayıt
reddediliyor. İlk 25 kişilik ayrı koşuda mobil 9/25, web 14/25 tamamlandı;
dolayısıyla sorunun varlığı tekrarlandı, tam başarı sayısı sabit değil.
Bu sonuçlardan “mobil en fazla 23 kişiyi alır” gibi bir üretim limiti çıkarılmaz.

Karma koşu `qr-1788952914272.json`: aynı etkinlikte yarı mobil algoritması,
yarı web fonksiyonları; mobilin oluşturduğu sayaç planı kullanıldı.

| Eşzamanlı başvuru | Başarı | permission-denied | p95 |
|---:|---:|---:|---:|
| 100 | 70 | 30 | 6,951 sn |
| 250 | 145 | 105 | 8,071 sn |

Kontenjanın başvuranların yarısı olduğu testlerde kontenjan aşılmadı ve
sayaç toplamı kayıt sayısıyla eşleşti. Ancak öğrencilerin hepsi doğru sonuca
ulaşmadı: mobilde 100 başvuru/50 kontenjan koşusunda 9 kayıt ve 91 ret;
webde aynı büyüklükte 50 kayıt, 46 `quota-full`, 4 ret görüldü. Webin
250 başvuru/125 kontenjan koşusunda 125 kayıt, 123 `aborted`, 2 ret görüldü.
Kontenjan bütünlüğünün korunması, herkese başarılı veya doğru açıklanmış
bir sonuç verildiği anlamına gelmiyor.

## Kural farkları ve QR'dan ilk kayıt

İki yerel kural dosyası aynı değil:

| Dosya | SHA-256 |
|---|---|
| `tool/loadtest/firestore.rules` | `995e38b5b21326ab4f6f35bf1f715a395e9e499d422d7d36a88cd482ac5d1106` |
| `C:/Users/5sana/Desktop/REGİPASS/firestore.rules` | `2d0135ab59de1d26288b2dba2260ff2e8a632d9b148951e0de88706f24fbccb3` |

Web kural dosyasıyla tekrar ölçüldü (`qr-1788952853924.json`): 100 kişide
mobil algoritması 15 kayıt/85 ret, web fonksiyonları 97 kayıt/3 ret verdi.
Kontenjanlı retler yalnızca Flutter kural kopyasına özgü değil.

`registrationClosed: true` olduğunda her iki kural dosyası da yeni kayıtları
reddetti. Kapı/oturum açılırken uygulama kayıtları kapatıyor. Dolayısıyla
**etkinliğe önceden kaydolmamış herkesin aktif kapı QR'ını okutup ilk kez
etkinliğe kaydolması, mevcut akışta garanti edilen bir kullanım değil.**
Bu, kullanıcı hesabı açılmasıyla etkinliğe kayıt işleminin de ayrı olduğunu
gösterir; yeni hesap oluşturma kapasitesi bu testte ölçülmedi.

Eski/tutarsız belgede `entryOpen: true`, `registrationClosed: false` olursa
Flutter kural kopyası 25/25 isteği reddetti; web kopyası 25/25 ve 100/100
isteği kabul etti. Bu test doğrudan güvenlik kurallarını sınar; normal ekran
ön kontrollerinin atlandığı bir durumdur. Canlıya hangi sürümün dağıtıldığı
bu çalışmada doğrulanmadı.

## Çift okutma ve diğer kontroller

- 25 öğrenci, öğrenci başına aynı anda iki kapı yazımı: her öğrencide biri
  kabul, biri ret; sonuçta 25 giriş.
- Aynı deneme oturum yoklamasında: her öğrencide biri kabul, biri ret;
  sonuçta 25 öğrencinin her birinde `sessionsAttended: 1`.
- Bütün kontenjan koşularında kayıt sayısı sayaç toplamıyla eşleşti;
  hiçbir sayaç parçası kapasitesini aşmadı.
- Seçili 70 QR/kontenjan/yönlendirme testi geçti. Ardından tam Flutter
  test paketi ayrı çalıştırıldı: **373 geçti, 0 başarısız**. Bu iki sayı
  toplanmaz; seçili testler tam paketin içindedir.
- Android cihaz listelendi; fiziksel Android üzerinde yeni yük testi veya
  uygulama kurulum/çökme testi yapılmadı. iOS cihaz/simülatörü yoktu.
  Üç platformda kamera, bellek, kare hızı ve uygulama kapanması doğrulanmadı.

## Hatanın değerlendirilmesi

Geçerli açık etkinliklerde tek başvuru başarılıyken kontenjan yarışında
`PERMISSION_DENIED` ve kural değerlendirme hataları kaydedildi.
Örnek hata yolları `create @ L946` ve sayaç `update @ L557`.
`RegistrationService` bu hata kodunu `closed` sonucuna çeviriyor;
web kuyruğu da kalıcı hata sayarak yeniden denemiyor. Bu, yer boşken
öğrencinin akışının neden tamamlanmadığını açıklayan somut davranıştır.
İncelenecek yerler:

- `lib/services/registration_service.dart`: `_claimShard`, `register` içindeki
  `permission-denied` işleme ve tekrar deneme kararı.
- `tool/loadtest/firestore.rules`: `slotClaimedInSameCommit`, sayaç güncelleme
  koşulları, create/update dalları.
- Web `quota-shards.js` ve `registration-queue.js`: çekişme, doluluk ve kalıcı
  hata ayrımı; farklı parça planı ve 8 saniyeye kadar ilk istek yayma penceresi.

Emulator, üretimdeki tüm transaction davranışlarını uygulamaz. Bu nedenle
bu bulgu canlı sunucudaki kesin hata oranı veya doğrulanmış kök neden diye
sunulmamalıdır. Aynı yarış, üretimden ayrı bir staging Firebase projesinde
gerçek mobil/web SDK'larıyla yeniden üretilmelidir.
[Firebase emulator sınırlamaları](https://firebase.google.com/docs/emulator-suite/connect_firestore#how_the_cloud_firestore_emulator_differs_from_production).

Eski kapasite notlarındaki “tek belge kesin 1 yazma/sn” veya “parça sayısı
kesin eşzamanlı kişi kapasitesidir” ifadeleri bu raporda limit olarak
kullanılmadı. Firebase, tek belge güncelleme kapasitesinin iş yüküne bağlı
olduğunu ve yük testiyle belirlenmesi gerektiğini söylüyor. 500/50/5 de
doğrudan öğrenci sayısı limiti değildir.
[Firebase ölçekleme önerileri](https://firebase.google.com/docs/firestore/best-practices#updates_to_a_single_document).

## Yeniden çalıştırma ve kanıtlar

Yük aracı: `tool/loadtest/14-qr-concurrency.mjs`.
Özet veriler: `docs/qr-yuk-testi-2026-09-09.json`.
Ham kayıtlar: özet JSON'un `runs[].rawPath` alanındaki 6 dosya.
Her ham dosyada öğrenci bazında sonuç/süre, kullanılan kuralların hash'i,
web kaynak hash'leri ve tamamlanma zamanı bulunur. Ham loglar `.gitignore`
nedeniyle Git'e dahil değildir; özet JSON kalıcı rapor içindir.

Geçersiz ilk denemeler (test verisinde `targetScope: all` ve Java'nın
`tr_TR` kaynak paketi hatası) sonuç tablolarından çıkarıldı. Veri `public`
olarak düzeltildi ve emulator İngilizce locale ile yeniden başlatıldı.
Geçerli koşulardaki uygulama kuralları değiştirilmedi.

PowerShell, Flutter proje kökünden, ayrı terminalde:

```powershell
java '-Duser.language=en' '-Duser.country=US' -Xmx3g -jar "$env:USERPROFILE/.cache/firebase/emulators/cloud-firestore-emulator-v1.22.0.jar" --host 127.0.0.1 --port 9091 --project_id demo-regipass-qr-load --rules tool/loadtest/firestore.rules
```

```powershell
$env:QR_COUNTS='25,100,250,500,1000'
$env:QR_MODES='door,session,unbounded'
node tool/loadtest/14-qr-concurrency.mjs
$env:QR_COUNTS='1,25,100,250'
$env:QR_MODES='mobile,web,mobile-overflow,web-overflow'
node tool/loadtest/14-qr-concurrency.mjs
$env:QR_COUNTS='100,250'
$env:QR_MODES='mixed'
node tool/loadtest/14-qr-concurrency.mjs
```

Aynı emulator üzerinde koşular sırayla çalıştırılmalıdır: araç seçilen
kuralları yükler. `LOADTEST_RULES` alternatif dosya yolunu seçer. Çıkış kodu
0 ölçümün tamamlandığını gösterir; tüm öğrencilerin başarılı olduğunu
göstermez. Bunun için `statuses` ve `integrity` alanlarına bakılmalıdır.
15 dakikalık koruma süresi aşılırsa araç sonuçları yazıp 2 koduyla çıkar.

Canlı etkinlik için tüm öğrencileri kabul edeceğine dair onay vermeden önce
kontenjan yarışındaki retlerin giderilmesi/doğrulanması, tek kural sürümünün
seçilmesi ve Auth, GPS, gerçek cihazlar, canlı dinleyiciler dahil uçtan uca
staging testi gerekir. Bu çalışmada dağıtım yapılmadı.
