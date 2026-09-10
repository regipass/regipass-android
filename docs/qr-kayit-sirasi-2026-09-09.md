# Eşzamanlı etkinlik kaydı — düzeltme ve doğrulama

Test tarihi: 9 Eylül 2026. Rapor tamamlanma tarihi: 10 Eylül 2026.

**İstenen 200–300 kişilik kayıt akışı yerel ortamda doğrulandı.** 300
eşzamanlı öğrenci için mobil algoritması, web fonksiyonları ve karma akışta
300/300 kayıt tamamlandı; kayıt/sayaç tutarsızlığı ve kontenjan aşımı yok.
Değişiklikler kaynak kodundadır; bu test çalışmasında web veya mobil dağıtımı yapılmadı.

## Davranış

Mobilde ilk kayıt denemesi artık yoğun etkinliklerde 0–8 saniyelik rastgele
bir bekleme penceresine yayılıyor. Bekleme başlar başlamaz mevcut sıra
göstergesi açılıyor. Webdeki mevcut istek yayma ve bekleme göstergesi korunuyor.
Öğrenciler tek anda aynı sayaca yüklenmek yerine farklı zamanlarda kayıt
deniyor; geçici yarışlar otomatik tekrar ediliyor.

Bu, istemcilerde çalışan dağıtık bekleme/yeniden denemedir. Merkezî bir FIFO
sunucu kuyruğu veya belirli sırayla kesin kabul garantisi değildir. Uygulama
kapatıldığında kalıcı sunucu kuyruğunda saklanan bir talep oluşturulmaz.

## Yapılan değişiklikler

- `lib/domain/registration_capacity.dart`: ilk istek yayma politikası ve
  tekrar denenebilir hata ayrımı eklendi. Sayaç parçası planı değiştirilmedi.
- `lib/services/registration_service.dart`: ilk bekleyişten sonra etkinlik
  tekrar doğrulanıyor. Sayaç ve kayıt aynı transaction içinde kalıyor.
  `permission-denied` oluşursa yalnızca denemede okunan sayacın sunucuda
  değiştiği doğrulanırsa sonuç `aborted` olarak tekrar deneniyor. Değişmeyen
  sayaçtaki gerçek yetki reddi korunuyor; hiçbir güvenlik kuralı gevşetilmedi.
  Geçici erişim kesintileri de mevcut sınırlı tekrar döngüsüne alındı.
- `lib/features/student/student_dashboard_screen.dart`: işlem sürerken
  ikinci kayıt çağrısı engellendi; hata dahil bütün çıkışlarda bekleme
  göstergesi temizleniyor.
- `C:/Users/5sana/Desktop/REGİPASS/js/modules/events/quota-shards.js`:
  aynı sayaç değişimi doğrulaması eklendi. Dolu parçaya her gelişte
  `consecutiveFull` değerini sıfırlayan hata kaldırıldı; son boş parçaları
  bulmak için gereken toplu okuma artık çalışıyor. Deneme sonunda doluluk
  yeniden kontrol edilerek gerçek doluluk ile çekişme ayrılıyor.
- `C:/Users/5sana/Desktop/REGİPASS/js/pages/dashboard.js`: uçuşta olan kayıt
  sırasında ikinci işlem başlatılması engellendi.

Gerçek kontenjan dolması, etkinliğin kapatılması, kapsam/yetki uyuşmazlığı
başarılı kayıt gibi gösterilmez. Geçici yoğunluğu bu sonuçlarla karıştıran
yollar düzeltildi. Kalıcı ağ veya sunucu arızasında sınırsız/hatasız kayıt
garantisi verilmez; tekrar sayısı sınırlıdır.

## Yük ölçümleri

| Aynı anda başvuran | Mobil algoritması | Web fonksiyonları | Karma |
|---:|---:|---:|---:|
| 100 | 100/100 | 100/100 | 100/100 |
| 200 | 200/200 | 200/200 | 200/200 |
| 300 | 300/300 | 300/300 | 300/300 |

300 kişilik son koşuda bütün isteklerin bitiş süresi:

| Akış | Toplam süre | p95 | Yazım hatası |
|---|---:|---:|---:|
| Mobil algoritması | 9,194 sn | 8,700 sn | 0 |
| Web fonksiyonları | 6,848 sn | 6,424 sn | 0 |
| Karma | 8,582 sn | 8,091 sn | 0 |

Karma: aynı etkinlikte öğrencilerin yarısı mobil algoritmasını, yarısı web
fonksiyonlarını çalıştırdı. Mobilin oluşturduğu sayaç planı kullanıldı.

**300 başvuru / 150 kontenjan** senaryosu üç akışta da aynı sonucu verdi:
150 başarılı kayıt, 150 doğru `quota-full` sonucu, 0 beklenmedik hata.
Hiçbir sayaç kapasitesini aşmadı; toplam sayaç her durumda kayıt sayısına eşit.

## Doğrulama

- Flutter tam test paketi: **377 geçti, 0 başarısız**.
- Web mevcut birim testleri: **133 geçti, 0 başarısız**.
- Gerçek web fonksiyonlarını bağımlılık enjeksiyonuyla çalıştıran 7 yeni
  test: **7 geçti**. Gerçek yetki reddinin korunması, değişen sayaçta yeniden
  deneme, çift çağrının birleştirilmesi, mevcut kaydın tekrar sayılmaması ve
  60 sayaç parçası içinde kalan son yerin bulunması denetlendi.
- Değiştirilen Dart alanları için analyzer ve JS sözdizimi kontrolleri
  başarılı; `git diff --check` temiz.

Yük koşulları önceki raporla aynıdır: localhost Firestore emulator 1.22.0,
Firebase JS SDK 12.18.0, sentetik authenticated istemciler, ücretsiz ve
herkese açık etkinlik. Mobil yük algoritması JS uyarlamasıdır; fiziksel
Android/iOS SDK yük/çökme testi değildir. Web fonksiyonları gerçek yerel
kaynaktan alınır, tarayıcı UI'sı yürütülmez. Auth/SMS, GPS, Hosting, Functions
ve canlı dinleyicilerin yükü kapsam dışındadır. Üretim kapasitesi veya
cihaz performansı için garanti sayılmaz.

Önceki başarısız ölçüm: [ilk inceleme](qr-yuk-testi-2026-09-09.md).
Yeni özet: [ölçüm verileri](qr-kayit-sirasi-2026-09-09.json).
Ham yük sonuçları:

- `tool/loadtest/logs/qr-1788970972499.json`: 100/200 kişilik ölçümler ve
  son boş parça hatasını ortaya çıkaran ara 300 kişilik web ölçümü.
- `tool/loadtest/logs/qr-1788971192492.json`: son boş parça düzeltmesinden
  sonraki 300 kişilik altı senaryo; tüm sonuçlar beklenen şekilde tamamlandı.

Komutlar (proje kökünde, 9091 portunda yerel emulator açıkken):

```powershell
$env:QR_COUNTS='100,200,300'
$env:QR_MODES='mobile,web,mixed'
node tool/loadtest/14-qr-concurrency.mjs
$env:QR_COUNTS='300'
$env:QR_MODES='mobile-overflow,web-overflow,mixed-overflow'
node tool/loadtest/14-qr-concurrency.mjs
node --test tool/loadtest/quota-retry.test.mjs
& C:/Users/5sana/Desktop/flutter/bin/flutter.bat test --no-pub
```
