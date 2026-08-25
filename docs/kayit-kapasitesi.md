# Eşzamanlı kayıt ve giriş kapasitesi

Bu belge iki soruyu ölçümle yanıtlar:

1. Bir etkinliğe **aynı anda** kaç kişi kaydolabilir?
2. Uygulamaya **aynı anda** kaç kişi giriş yapabilir?

Ölçüm düzeneği: [`tool/loadtest/`](../tool/loadtest/README.md) — Firestore
emulator'e karşı çalışan yük testleri. Ham günlükler `tool/loadtest/logs/`
altında JSONL olarak duruyor.

---

## Kısa cevap

| Soru | Cevap |
|---|---|
| Kayıtta çökme sınırı nedir? | **Çökme yok** — kontenjan hiç kontrol edilmediği için 100 kişilik etkinliğe 2000 kişi hatasız kaydoldu. Sorun kapasite değil, **veri bütünlüğü**. |
| Kontenjan korunursa sınır ne olur? | Sayaç tek dokümandaysa **~10 eşzamanlı**. Parçalı sayaçla **parça sayısı kadar** (16 parça → 16 eşzamanlı yazma, %0 hata). |
| Sürdürülebilir kayıt hızı? | **Parça sayısı kadar kayıt/saniye.** Üretimde mutlak tavan aynı etkinlik için **~500 kayıt/sn** (indeks sıcak noktası). |
| Anlık patlama ne kadar emilir? | Bir turda **parça sayısı kadar** kayıt geçiyor (16 parça → tam 16). Tur sayısını artırmak kapasite **eklemiyor**, yalnızca gecikme ekliyor — kapasitenin kolu parça sayısıdır. |
| 100 kontenjanlı etkinliğe 100 kişi aynı anda basarsa? | **100/100, kimse kaçmıyor** (p50 29 ms). Emulator'ü doyuracak şekilde hepsi tek anda salındığında %80–87 — kayıp emulator'ün kendi tavanından. |
| Ya 400 kişi? | **Bu düzenek yanıt veremiyor.** Emulator 400 ölçeğinde doyuyor, aynı kurulum koşudan koşuya iki kat farklı sonuç veriyor. Üretimde ölçülmeli. |
| Kontenjan dolunca ne oluyor? | Etkinlik kulüp ekranında **kendiliğinden beklemeye alınıyor**, öğrencinin keşif listesinden düşüyor. Yer açılırsa geri açılıyor; kulübün elle durdurduğuna dokunulmuyor. |
| Girişte çökme sınırı nedir? | **Çökme yok** — 1000 eşzamanlı girişte %0 hata. Giriş salt okuma olduğu için çekişme yaşamıyor. |
| Girişin gerçek sınırı? | **Okuma sayısı.** Giriş başına `27 + katalog boyutu` okuma. 1000 etkinlikli katalogda 1000 giriş = **1.027.000 okuma** tek seferde. |

---

## Ölçüm aracının sınırları

Emulator **tek süreçli ve bellek içi**. Neyi ölçtüğünü bilmeden sayılara
bakmak yanıltır:

**Gerçek ölçer**

- transaction çekişmesi, ABORTED oranı, yeniden deneme davranışı
- kontenjan aşımı / eksiği — yani algoritmanın **doğruluğu**
- işlem başına okuma-yazma sayısı
- güvenlik kurallarının davranışı

**Ölçmez**

- Firestore'un paralelliği. Emulator saniyede ancak **6–16 transaction**
  işliyor ve eşzamanlılık arttıkça bu sayı **düşüyor** — yani parçalara
  bölmenin üretimdeki hız kazancını gösteremiyor.
- Belgelenmiş üretim tavanları: tek dokümana ~1 yazma/sn, dar indeks
  aralığında ~500 yazma/sn, 500/50/5 rampası.

Bu yüzden aşağıdaki tablolarda **mutlak işlem/sn değerleri değil, eşit yük
altında yapılan karşılaştırmalar** anlamlıdır.

---

## 1. Kayıt

### 1.1 Bugünkü durum: kontenjan hiç korunmuyor

`EventRepository.registerToEvent` kaydı doğrudan `set()` ile yazıyordu.
Kontenjan ne istemcide ne `firestore.rules` içinde kontrol ediliyordu.

500 kişilik değil, **100 kişilik** bir etkinliğe N kişi aynı anda bastı
(`01-baseline.mjs`):

| eşzamanlı | başarı | hata | veritabanındaki kayıt | kontenjan aşımı |
|---:|---:|---:|---:|---:|
| 100 | %100 | 0 | 100 | 0 |
| 250 | %100 | 0 | 250 | **+150** |
| 500 | %100 | 0 | 500 | **+400** |
| 1000 | %100 | 0 | 1000 | **+900** |
| 2000 | %100 | 0 | 2000 | **+1900** |

Tek bir hata bile yok. Uygulama çökmüyor — **sessizce yanlış çalışıyor.**
Kontenjanı 100 olan etkinliğe 2000 kişi giriyor ve kulüp bunu ancak
katılımcı listesini açınca fark ediyor.

### 1.2 Okuma çoğalması

Kayıt başarılı olunca ekran `ref.invalidate(studentVisibleEventsProvider)`
çağırıyor; o da `fetchAllEvents()` ile **bütün etkinlik koleksiyonunu**
yeniden okuyor. 300 etkinlikli bir katalogda:

| eşzamanlı kayıt | toplam okuma | p50 gecikme |
|---:|---:|---:|
| 10 | 3.020 | 154 ms |
| 100 | 30.200 | 1.013 ms |
| 250 | 75.500 | 2.516 ms |
| 500 | **151.000** | 6.187 ms |

Yani tek bir kayıt, 1 yazma + **301 okumaya** mal oluyor.

### 1.3 Kontenjanı korumanın bedeli: tek dokümanlı sayaç

En akla yatkın çözüm — etkinlik dokümanında `registeredCount` tutup kaydı
transaction'la yazmak — doğru sonuç verir ama tek doküman **serileştirme
noktasıdır** (`02-quota-contention.mjs`, kontenjan 500):

| eşzamanlı | başarı | p50 | yeniden deneme |
|---:|---:|---:|---:|
| 10 | %100 | 3.415 ms | 10 |
| 25 | %100 | 10.878 ms | 65 |
| 50 | **%62** | 15.343 ms | 99 |
| 100 | **%1** | 20.358 ms | 4 |
| 500 | **%0,2** | 76.972 ms | 4 |

100 kişi aynı anda bastığında **yalnızca 1 kişi** kaydolabildi.

Üretimde durum daha da kötü: Firestore'da tek dokümana sürdürülebilir yazma
hızı **saniyede ~1**. Emulator bu kotayı uygulamaz, yani yukarıdaki tablo
üretimin **iyimser** tarafı.

### 1.4 Çözüm: parçalı sayaç

Kontenjan tek satırda değil, `events/{eventId}/quota_shards/{0..S-1}`
altında S parçada tutulur. Her parça `{count, capacity}` taşır ve
**kapasitelerin toplamı tam olarak kontenjandır** — bu yüzden ne aşım ne
eksik olabilir.

Öğrenci kimliğinden türeyen bir parçadan başlar, parça doluysa sıradakine
yürür. Bütün parçalar doluysa kontenjan gerçekten bitmiştir.

500 kişi aynı anda, kabul denetimi olmadan (`03-sharded-queue.mjs` A):

| parça | kaydolabilen |
|---:|---:|
| 1 | 1 |
| 4 | 4 |
| 8 | 16 |
| 16 | 48 |
| 32 | 62 |
| 64 | 294 |

Parça sayısı tavanı yükseltiyor — ama tek başına yetmiyor.

### 1.5 Asıl kol: kabul denetimi ("bölük bölük")

Aynı anda uçan istek sayısı parça sayısını **aşmadığı** sürece hata sıfır
(`03-sharded-queue.mjs` B, 16 parça sabit, 500 kayıt):

| aynı anda uçan | başarı | p50 | kayıt |
|---:|---:|---:|---:|
| 8 | **%100** | 13 ms | 500/500 |
| 16 | **%100** | 16 ms | 500/500 |
| 32 | %87 | 12 ms | 437 |
| 64 | %76 | 29 ms | 379 |
| 128 | %66 | 44 ms | 332 |
| 500 | %10 | 23.539 ms | 52 |

**Kural: kabul edilen eşzamanlılık ≤ parça sayısı.**

Ama merkezî bir kuyruk kuramayız: 500 öğrencinin 500 ayrı telefonu var ve
hiçbiri diğerini beklemiyor. Kuyruğu **zaman** kurar — çekişmeye takılan
istek, üstel büyüyen ve rastgeleleştirilmiş (jitter) bir bekleyişten sonra
yeniden dener. Her turda parça sayısı kadar kayıt geçer, gerisi sonraki
turu bekler. "Bölük bölük" olan budur.

Tur başına kaç kişi geçtiği doğrudan ölçüldü (`07-capacity.mjs` B): 500 kişi
aynı anda bastı, 16 parça, **yeniden deneme kapalı** — tam **16 kişi**
kaydoldu. Yani:

> **Bir turda parça sayısı kadar kayıt geçer.**

#### Yeniden deneme bütçesi kapasite SATIN ALMIYOR

Sezgisel beklenti "tur sayısını artırırsak daha çok kişi geçer" idi. Ölçüm
bunu **çürüttü** (500 kişi aynı anda, 16 parça sabit):

| tur | kaydolan | p50 gecikme |
|---:|---:|---:|
| 1 | 16 | 2,8 sn |
| 4 | 36 | 5,5 sn |
| 8 | 23 | 41,2 sn |
| 12 | 49 | 60,7 sn |
| 16 | 48 | **132,6 sn** |
| 20 | 37 | **186,4 sn** |

Başarı 16–49 arasında sallanıyor, tur sayısıyla **büyümüyor**; buna karşılık
gecikme 2,8 saniyeden 186 saniyeye çıkıyor. Arka uç doymuşken yeniden deneme
yalnızca **kullanıcıyı bekletiyor**, kapasite eklemiyor.

İki sonuç:

1. **Kapasitenin kolu `quotaShardCount`'tur, `kRegistrationMaxRounds` değil.**
   Daha çok kişiyi aynı anda almak için parça sayısı artırılmalı.
2. **8 turdan fazlası zarar.** Varsayılan bilerek 8'de bırakıldı; ötesi
   kullanıcıya dakikalarca dönen bir çember göstermek demek.

Not: bu tablo emulator doymuşken alındı. Üretimde her deneme milisaniyeler
sürer, o yüzden turlar burada göründüğü kadar pahalı değildir; ama "tur
ekleyerek kapasite alınmaz" sonucu ölçüm aracından bağımsızdır.

### 1.6 "Kontenjan 100, aynı anda 100 kişi — kaldırır mı?"

En somut soru bu: tam dolduracak kadar talep geldiğinde herkes içeri
girebiliyor mu. Boş kalan her yer, kulübün kaybettiği katılımcıdır
(`09-exact-quota.mjs`).

**Kontenjan 100, aynı anda 100 kişi:**

| kurulum | kaydolan | dolum | kaçan |
|---|---:|---:|---:|
| hepsi birden, 8 parça | 87 | %87 | 13 |
| hepsi birden, 16 parça | 82 | %82 | 18 |
| hepsi birden, 32 parça | 84 | %84 | 16 |
| **kabul denetimli (K=8)** | **100** | **%100** | **0** |

**Kontenjan 400, aynı anda 400 kişi:**

| kurulum | kaydolan | dolum | kaçan |
|---|---:|---:|---:|
| hepsi birden, 16 parça | 23 | %6 | 377 |
| hepsi birden, 32 parça | 95 | %24 | 305 |
| hepsi birden, 64 parça | 192 | %48 | 208 |
| kabul denetimli (K=16) | 335 | %84 | 65 |

İki sonuç:

1. **100 kişilik etkinlik sorunsuz.** Kabul denetimli kurulumda kimse
   kaçmıyor, üstelik hızlı: p50 29 ms, tamamı 12 saniyede bitiyor.

2. **"Hepsi birden" satırları emulator'ün kendi tavanını da içerir.**
   Emulator saniyede 6–16 transaction işliyor; 400 kayıt için tek başına en
   az 25–65 saniye gerekiyor, yeniden deneme bütçesi ise ~27 saniye. Yani
   400'lük satırlarda ölçtüğümüz şey algoritma değil, **ölçüm aracının
   tavanı**.

#### Parça sayısı bu düzenekle ayarlanamıyor

Bir ara bu ölçümlere bakıp `quotaShardCount` tablosunu iki katına
çıkarmıştım (400 → 32 parça). **Geri alındı**: tekrar koşusu gerekçenin
gürültü olduğunu gösterdi.

| kurulum | 1. koşu | 2. koşu |
|---|---:|---:|
| kontenjan 400, 32 parça | 95 | 45 |
| kontenjan 100, 32 parça | 84 | 53 |

Aynı kurulum iki kat farklı sonuç veriyor. Doygunluk altında yapılan tek
güvenilir karşılaştırma ise **eski tabloyu destekliyor**:

| kontenjan 100, kabul denetimli | kaydolan |
|---|---:|
| 8 parça (tablo değeri) | **100 / 100** |
| 16 parça (iki katı) | 88 / 100 |

Tablo bu yüzden ilkeye bırakıldı: **parça başına ~12 kişilik kapasite.**
Çekişme parça sayısıyla azalır, yürüme maliyeti (dolan parçaları atlama)
artar; denge oradadır. Gerçek ayar üretim verisiyle yapılmalı.
2. **"Hepsi birden" satırları emulator'ün kendi tavanını da içerir.**
   Emulator saniyede 6–16 transaction işliyor; 400 kayıt için tek başına en
   az 25–65 saniye gerekiyor. Üretimde beklenen tablo "kabul denetimli"
   satırına daha yakındır.

Dürüst özet: **100 kişilik etkinliğe 100 kişinin aynı anda başvurması
sorunsuz — kimse kaçmıyor.** 400 için bu düzenek yanıt veremiyor; emulator
o ölçekte kendi tavanına çarpıyor ve sonuçlar koşudan koşuya iki kat
değişiyor. **400 rakamı üretimde ölçülmeli.**

### 1.7 Kontenjan dolunca etkinlik kendiliğinden beklemeye alınır

Kontenjan dolduğunda kulübün elle bir şey yapması gerekmiyor: etkinlik
kulüp ekranında **"beklemede"** durumuna geçiyor, öğrencinin keşif
listesinden düşüyor.

Nasıl çalışıyor:

- Doluluk, parça sayaçlarından canlı okunuyor (`quotaStatusProvider`).
  Etkinlik dokümanında tek sayı olarak **tutulmuyor** — o sayıyı yazan
  doküman kontenjanın darboğazı hâline gelirdi (bkz. §1.3).
- Dolduğu görüldüğünde `registrationClosed = true` ve
  `registrationClosedReason = 'quota_full'` yazılıyor.
- Biri kaydını iptal ederse ya da kulüp kontenjanı artırırsa kayıtlar
  **kendiliğinden geri açılıyor**.
- Kulübün **eliyle** durdurduğu etkinliğe dokunulmuyor: sebep `'manual'`
  yazıldığı için otomatik açma onu atlıyor. Bu ayrım olmasaydı kulüp
  kayıtları durdurur, uygulama hemen geri açardı.

Yazmayı neden kulüp tarafı yapıyor: `firestore.rules` etkinlik dokümanını
yalnızca sahibi kulübe açıyor. Öğrenciye izin vermek için kuralın "bütün
parçalar dolu mu" diye bakması gerekirdi; kurallarda tek istekte en çok
**10 doküman** okunabildiği için 16–32 parçada bu mümkün değil.

Bunun bir sınırı var: bayrak, kulüp uygulaması etkinliği görüntülediğinde
yazılıyor. Kimse bakmıyorsa etiket gecikir — **ama kontenjan yine korunur**,
çünkü koruma parça sayaçlarında, bayrakta değil. Dolu bir etkinliğe
kaydolmaya çalışan öğrenci her hâlükârda "kontenjan doldu" cevabı alır.

Karar mantığı saf bir fonksiyonda (`quotaGateAction`) ve testli.

### 1.8 Kontenjan bütünlüğü

Parçalı kurulumun **hiçbir koşusunda kontenjan aşılmadı.** 200 kişilik
etkinliğe 1000 başvuru geldiğinde veritabanında 193 kayıt oluştu ve parça
sayaçlarının toplamı da tam 193 idi — **sayaç ile gerçek kayıt sayısı
birebir tutuyor** (`07-capacity.mjs` C).

Ters yönde küçük bir kayıp var: doygunluk altında son birkaç yer boş
kalabiliyor (193/200). Sebep, kontenjanın son kişilerinin boş parçayı
bulmak için bütün parçaları taraması ve bu sırada çekişmeye takılması.
Kontenjanı **aşmaktansa** birkaç yeri boş bırakmak tercih edilir; boş kalan
yerler kayıtlar kapanmadan önce doldurulabilir.

### 1.9 Ölçümün yakaladığı hata: yanlış "tekrar dene" cevabı

`07-capacity.mjs` C beklenmedik bir şey gösterdi: kontenjanı dolmuş
etkinlikte **hiç kimse "kontenjan doldu" cevabı almadı**; 807 kişi
"çok yoğun, tekrar dene" gördü.

Sebep, tur içindeki "bütün parçalar dolu" kontrolünün çekişme varken bilerek
atlanması (dolu görünen parça eski bir okuma olabilir). Ama yoğunlukta
neredeyse her turda bir çekişme oluyor, dolayısıyla kontrol hiç
çalışmıyordu. Sonuç kullanıcı açısından yanlış: kontenjanı bitmiş bir
etkinliği tekrar tekrar denemesi söyleniyor.

Düzeltme: turlar bitince pes etmeden önce parçalara bir kez temiz bakılıyor
(`RegistrationService._isQuotaFull`) — S okuma, yalnızca başarısız yolda.
Şüphede kalınırsa `false` döner: yanlış "doldu" demek, yanlış "tekrar dene"
demekten daha zararlı.

Doğrulama `08-quota-full-signal.mjs`, aynı yükün düzeltme öncesi ve
sonrasını karşılaştırıyor.

### 1.10 Üretimdeki mutlak tavan

Emulator'ün ölçemediği, belgelenmiş Firestore sınırları:

| Sınır | Değer | Neden bizi ilgilendiriyor |
|---|---|---|
| Tek dokümana sürdürülebilir yazma | ~1/sn | Sayaç asla tek dokümanda tutulmamalı |
| Dar indeks anahtar aralığına yazma | ~500/sn | `event_registrations.eventId` aynı etkinlikte tek değer, `createdAt` sürekli artıyor; ikisi de kendiliğinden indeksleniyor (`firestore.indexes.json` bu alanların indeksini kapatmıyor) |
| Yeni koleksiyon rampası | 500 işlem/sn, 5 dakikada bir %50 artış | İlk büyük etkinlikte tavan budur |

Yani **aynı etkinliğe üretimde sürdürülebilir üst sınır ~500 kayıt/saniye.**

### 1.11 Güvenlik

Parçalı sayaç, kurallar onu korumazsa işe yaramaz: istemciye "sayacı artır"
izni verilirken kayıt yazmadan yer kapmak, kaydı silmeden yer açmak veya
kapasiteyi kendi belirlemek mümkün olurdu.

`firestore.rules` bunları `getAfter`/`existsAfter` ile kapatıyor — sayaç
değişimi ancak **işlem bittiğinde** kaydın beklenen hâlde olmasıyla geçerli.
`06-rules.mjs` 15 senaryonun hepsini doğruluyor:

- öğrenci parça kuramaz / kapasiteyi değiştiremez
- kayıt yazmadan sayaç artırılamaz, kaydı silmeden azaltılamaz
- bir parça artırılıp kayıt başka parçaya yazılamaz
- başkasının kaydı yazılarak yer kapılamaz
- sayaç kapasiteyi aşamaz, 0'ın altına inemez

---

## 2. Giriş

### 2.1 Bir giriş kaç okuma yapıyor

Öğrenci giriş yaptığında açılanlar (`lib/state/providers.dart`,
`student_providers.dart`, `notification_providers.dart`):

| # | Kaynak | Okuma |
|---|---|---|
| 1 | `users/{uid}` — canlı dinleyici | 1 |
| 2 | `student_profiles/{uid}` — canlı dinleyici | 1 |
| 3 | `event_registrations where studentId == uid` | kayıt sayısı |
| 4 | `student_certificates where studentId == uid` | belge sayısı |
| 5 | `announcements` (üniversiteye göre) | duyuru sayısı |
| 6 | **`events` koleksiyonunun TAMAMI** | katalog boyutu |
| 7 | `appointmentsProvider` — kayıtlı her etkinlik ayrı ayrı | kayıt sayısı |

6. madde belirleyici: öğrencinin göreceği etkinlikler sunucuda değil
**istemcide** süzülüyor (`fetchAllEvents()` + `canStudentSeeEvent`), bu
yüzden her giriş bütün katalogu indiriyor.

### 2.2 Ölçüm

`04-login.mjs`, öğrenci başına 6 kayıt ve 3 belge ile:

| katalog | okuma / giriş |
|---:|---:|
| 100 etkinlik | 127 |
| 300 etkinlik | 327 |
| 1000 etkinlik | 1.027 |

Eşzamanlı giriş (1000 etkinlikli katalog):

| eşzamanlı | hata | p50 | p95 | toplam okuma |
|---:|---:|---:|---:|---:|
| 10 | %0 | 1.227 ms | 1.261 ms | 10.270 |
| 100 | %0 | 6.450 ms | 6.625 ms | 102.700 |
| 250 | %0 | 17.849 ms | 18.147 ms | 256.750 |
| 500 | %0 | 41.768 ms | 43.343 ms | 513.500 |
| 1000 | %0 | 97.373 ms | 99.233 ms | **1.027.000** |

**Hiçbir seviyede hata yok.** Giriş salt okuma olduğu için çekişme
yaşamıyor; Firestore okuma tarafında çok geniş ölçekli. Yani "kaç kişi giriş
yaparsa uygulama çöker" sorusunun teknik cevabı: **çökmez.**

Gerçek sınır ikisi:

1. **Gecikme.** Eşzamanlılık arttıkça giriş süresi doğrusal büyüyor.
   Emulator'deki mutlak değerler üretimi temsil etmez, ama eğrinin şekli
   eder: yük arttıkça kullanıcı bekler.
2. **Maliyet.** Okuma başına ücretlendiriliyor. 1000 kişilik bir giriş
   dalgası, 1000 etkinlikli katalogda tek seferde bir milyondan fazla okuma
   demek — ve bu her giriş dalgasında tekrarlanıyor.

### 2.3 Öneri (henüz uygulanmadı)

`fetchAllEvents()` sunucu tarafı filtreye çevrilirse giriş başına okuma
katalog boyutundan bağımsız, sabit bir sayıya iner:

```dart
eventsCol
    .where('hiddenGlobally', isEqualTo: false)
    .where('deadlineAtMs', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
    .orderBy('deadlineAtMs')
    .limit(50)
```

Gereken bileşik indeks (`firestore.indexes.json`):
`hiddenGlobally` (ASC) + `deadlineAtMs` (ASC).

Bu, giriş başına okumayı 1.027'den ~60'a düşürür — **17 kat**. Ama keşif
sıralaması şu anda **bütün** etkinlikler üzerinde istemcide yapılıyor
(`sortEventsForStudent`: öncelik → alan ağırlığı → son başvuru); sayfalamaya
geçmek sıralamanın davranışını değiştirir. Bu yüzden bilerek ayrı bir iş
olarak bırakıldı.

---

## 3. Uygulanan değişiklikler

| Ne | Nerede |
|---|---|
| Eşzamanlılık politikası (parça sayısı, backoff, sınırlar) — saf, test edilebilir | `lib/domain/registration_capacity.dart` |
| Kontenjanı koruyan kayıt/iptal akışı | `lib/services/registration_service.dart` |
| Parçaların etkinlikle atomik kurulması, kontenjan değişiminde dengelenmesi, eski etkinliklere geri dolum | `lib/services/event_repository.dart` |
| Parça referansları | `lib/services/firebase_refs.dart` |
| `quotaShardCount` alanı | `lib/models/event.dart` |
| Yapılandırılmış günlük (halka tampon + JSONL) | `lib/core/app_log.dart` |
| Sonuç ayrımı ve "sıradasın" göstergesi | `lib/features/student/student_dashboard_screen.dart` |
| Doluluk göstergesi, otomatik beklemeye alma, geri dolum kancası | `lib/features/club/club_event_detail_screen.dart` |
| Doluluk sağlayıcısı (`quotaStatusProvider`) | `lib/features/club/club_providers.dart` |
| `registrationClosedReason` alanı | `lib/models/event.dart` |
| `quota_shards` güvenlik kuralları | `Desktop/REGİPASS/firestore.rules` |
| Politika testleri (27) | `test/registration_capacity_test.dart` |
| Yük ve kural testleri | `tool/loadtest/` |

### Eski etkinlikler

`quotaShardCount` alanı olmayan (bu değişiklikten önce oluşturulmuş)
etkinliklerde parça yok. O etkinliklerde kayıt **eski kontenjansız yoldan**
geçmeye devam eder — davranış bilerek bozulmadı, aksi hâlde eski
etkinliklere kimse kaydolamazdı. Parçalar, kulüp kendi etkinliğinin detay
ekranını açtığında kendiliğinden kurulur ve o ana kadarki kayıtlar sayaca
işlenir.

---

## 4. Yapılması gerekenler

1. **Kuralları yayınla.** `firestore.rules` değişti ama **deploy edilmedi**.
   Yayınlanana kadar parçalı sayaç üretimde çalışmaz (`quota_shards`
   yazımları reddedilir).

   ```bash
   firebase deploy --only firestore:rules
   ```

2. **`registrationDebugMode()` hâlâ `true`.** Kuralların içindeki bu geçici
   tanılama anahtarı, `event_registrations` create/update için
   `registrationClosed` ve `hiddenGlobally` kontrollerini **atlıyor** — yani
   kulüp kayıtları kapatsa bile sunucu tarafında engellenmiyor, yalnızca
   istemci engelliyor. Kontenjan koruması bundan bağımsız çalışır, ama bu
   kapı ayrıca kapatılmalı.

3. **Giriş okumalarını sunucuya taşı** (bkz. 2.3).
