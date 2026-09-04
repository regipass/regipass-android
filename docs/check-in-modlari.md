# Check-in / Yoklama modları

Kulüp, etkinliği oluştururken (veya düzenlerken) üç moddan birini seçer.
Mod `events/{eventId}.checkinMode` alanında saklanır ve **web ile mobil aynı
alanı okur**.

| Mod | `checkinMode` | Kapıda check-in | Oturum yoklaması |
|---|---|---|---|
| Check-in + Yoklama | `checkin_attendance` | ✅ konum doğrulamalı | ✅ kapıya bağlı |
| Sadece Yoklama | `attendance_only` | — | ✅ |
| Sadece Check-in | `checkin_only` | ✅ konum doğrulamalı | — |

**Check-in + Yoklama.** Öğrenci sabah kapıda, kulübün ekrana bastığı giriş
QR'ını kendi telefonuyla okutur; konumu doğrulanır ve `checkedInAtMs` yazılır.
Gün içindeki oturum yoklamalarına ancak bu girişi yapmışsa katılabilir.
Kapıdaki girişi kaçıranlar için kulüp, oturumları başlattıktan sonra
**"Check-in yapmayanlar da yoklamaya katılsın"** anahtarını açabilir
(`allowSessionWithoutCheckin`); o anda kapı şartı kalkar.

**Sadece Yoklama.** Klasik oturum içi yoklama. Kapı girişi diye bir şey
yoktur, oturum QR'ları doğrudan çalışır.

**Sadece Check-in.** Oturum yoklaması olmayan, tek seferlik girişli etkinlik.
Kapıda konum doğrulamalı QR okutulur ve süreç tamamlanır.

## Eski kayıtlar

Bu alan eklenmeden önce oluşturulmuş etkinliklerde `checkinMode` **yoktur**.
O kayıtlarda mod `sessionCount` üzerinden türetilir; davranış eskisiyle
birebir aynı kalır:

```
sessionCount > 1   ->  attendance_only   (oturum QR'ları, kapı şartı yok)
sessionCount <= 1  ->  checkin_only      (kulübün okuttuğu klasik giriş QR'ı)
```

Türetme tek yerde durur ve iki platformda da test edilir:

| | Kod | Test |
|---|---|---|
| Web | `js/modules/events/checkin-mode.js` | `tests/unit/checkin-mode.test.mjs` |
| Mobil | `lib/domain/checkin_mode.dart` | `test/domain_test.dart` |

## Oturum sayısıyla ilişkisi

Mod, "oturum var mı" sorusunun tek kaynağı **değildir**; onu hâlâ
`sessionCount > 1` söyler. İki alan bilerek tutarlı yazılır (`checkin_only`
→ 1 oturum, diğerleri → en az 2). Bu sayede `sessionCount`'a dayanan mevcut
kodun tamamı değişmeden çalışır; modun eklediği tek yeni boyut **kapı
girişidir**.

## QR türleri

QR yükünün `type` alanı hangi kapının çalındığını söyler. **İki platformda
da aynı adlar kullanılmak zorundadır** — web'in bastığı QR'ı mobil, mobilin
bastığını web okuyor:

| `type` | Kim gösterir | Kim okutur |
|---|---|---|
| `event-entry` | kulüp (kapıda) | öğrenci |
| `session-checkin` | kulüp (salonda) | öğrenci |
| `event-checkin` | öğrenci | kulüp görevlisi |

## QR'ın içeriği: ham token mi, adres mi?

Kulübün **ekrana bastığı** iki kod (`event-entry`, `session-checkin`) ham
token değil bir adres taşır:

```
https://eventapp-604a5.web.app/qr.html?t=EVAPPQR1:...
```

Sebep, öğrencinin telefonunun **kendi kamera uygulaması**: ham metni okuduğunda
yapacak bir şey bulamaz, yalnızca düz yazı gösterir. Adres olduğunda doğrudan
açılır. Uygulama içi tarayıcılar iki biçimi de okumak zorundadır — çözümleme
tek kapıdan geçer:

| | Kod |
|---|---|
| Web | `js/modules/events/checkin-qr.js` → `extractCheckinQrToken` |
| Mobil | `lib/domain/checkin_qr.dart` → `extractCheckinQrToken` |

Öğrencinin **bileti** (`event-checkin`) bu sarmalamanın dışındadır: onu telefon
kamerası değil, kapıdaki görevlinin uygulaması okur. Ham token en küçük ve en
hızlı okunan biçimdir.

## Oturum QR'ının 20 saniyelik penceresi

Salondaki ekranda duran oturum QR'ı sabit değildir: içine üretildiği anın 20
saniyelik dilim numarası (`slot`) yazılır ve kod her dilim sınırında yenilenir.
Okuyan taraf kendi dilimiyle karşılaştırır; bir önceki dilim de kabul edilir,
yani pratik pencere 20-40 saniyedir. Amaç, ekranın fotoğrafını çekip dışarıdaki
arkadaşına gönderen öğrenciyi durdurmaktır.

Bu bir **güvenlik sınırı değil caydırıcıdır**: `firestore.rules` dilimi
doğrulayamaz (gerekli nonce'u etkinliğe kayıtlı her öğrenci okuyabilirdi, yani
sır olmaktan çıkardı). Gerçek sınır kuralda duruyor — öğrenci yalnızca kendi
kaydını, yalnızca o anki `currentSession` için ve yalnızca bir kez işaretler.

| | Kod | Test |
|---|---|---|
| Web | `js/modules/events/session-qr-window.js` | `tests/unit/session-qr-window.test.mjs` |
| Mobil | `lib/domain/session_qr_window.dart` | `test/domain_test.dart` |

Web'de tazelik yalnızca QR'ın taze okunduğu turda (`qr.html?t=...` ile
gelindiğinde) bakılır; giriş/kayıt adımları dakikalar sürebildiği için sonradan
tekrar sorulmaz. Mobilde tarayıcı ekranına gelen her token doğrudan kameradan
okunur, yani o koşul her zaman sağlanır ve kontrol her okumada uygulanır.

## Konum hangi adımda sorulur?

Yalnızca **salondaki oturum yoklamasında**. Orada QR'ı öğrenci kendi
telefonuyla okuttuğu için gerçekten içeride olup olmadığı başka türlü
anlaşılamaz.

Kapı check-in'inde konum **hiç sorulmaz** — ne bilet yükünde koordinat taşınır
ne de okutma sırasında cihazın konumuna bakılır. Kapı zaten fiziksel bir
noktadır: öğrenci ya görevlinin okuttuğu bilettedir ya da görevlinin açtığı
kapı QR'ının önünde durmaktadır. Oradaki sınır konum değil, kulübün kapıyı açıp
kapatmasıdır (`events.entryOpen`).

| | Kod |
|---|---|
| Web | `js/modules/events/geo-fence.js` |
| Mobil | `lib/services/geo_fence_service.dart` (mesafe: `lib/core/geo.dart`) |

## Kapıda iki yön birden

Kapı check-in'i olan etkinlikte giriş iki şekilde alınabilir ve **ikisi de aynı
damgayı yazar**:

| Yön | Kim okutur | Yazan kural dalı | `checkedInVia` |
|---|---|---|---|
| Öğrenci biletini gösterir | görevli | `clubCanMarkCheckIn` | — (`checkedInByClubId` yazılır) |
| Öğrenci kapıdaki kodu okutur | öğrenci | `studentCanMarkOwnEventCheckIn` | `self-qr` |

Hangisinin kullanılacağını kulüp kapıda seçer; uygulama ikisini de sunar.
Görevlinin okuttuğu yol `entryOpen` aramaz (kural da aramıyor), böylece
check-in bitirildikten sonra gelen geç öğrenci yine alınabilir.

Görevlinin bilet okutması bir **yoklama saymaz**: yalnızca kapı damgası yazılır.
"Check-in + Yoklama" modunda gün içindeki yoklamalar ayrı adımdır ve öğrencinin
salondaki oturum QR'ını kendi telefonuyla okutmasıyla işler — yoksa aynı öğrenci
hem kapıda hem salonda sayılırdı.

## Kapı check-in'inin üç adımı

`entryStartedAtMs` (bir kez yazılır, silinmez) ve `entryOpen` ikilisinden
türetilen aşama, kulübün gördüğü kontrol çubuğunu belirler:

| Aşama | Koşul | Çubuk |
|---|---|---|
| `not_started` | damga yok | "Check-in'i Başlat" |
| `running` | damga var, `entryOpen` | "Giriş QR'ını Göster" + "Check-in'i Bitir" |
| `finished` | damga var, kapalı | "Check-in'i Yeniden Başlat" |

Sıra zorunludur: "Check-in + Yoklama" modunda **ilk** oturum ancak `finished`
aşamasından sonra başlatılabilir. Kapı bitmeden oturum başlatılırsa daha içeri
girmemiş öğrenciler yoklamada reddedilir ve kulüp bunu ancak öğrenciler şikâyet
edince fark eder. Başlamış bir etkinliğin oturumlarını **ilerletmek** hiçbir
zaman kilitlenmez; aksi hâlde bu alanlar eklenmeden önce yarıda kalmış
etkinlikler kilitlenip kalırdı.

"Yeniden Başlat" veriyi sıfırlamaz: okunan girişler kayıtlarda durur
(`checkedInAtMs` bir kez yazılır), yeni okutulanlar üzerine eklenir.

Türetme ve kilit tek yerdedir: `lib/domain/checkin_mode.dart`
(`resolveCheckinStage`, `doorCheckinBlocksSessionsFor`), web'de
`js/modules/events/checkin-mode.js`.

## Henüz yapılmadı: uygulamaya devretme

Telefonun kendi kamerasıyla okunan QR bir adres açtığı için, cihazda mobil
uygulama kurulu olsa bile **tarayıcıda** açılır. Uygulamaya devretmek için:

* `/.well-known/assetlinks.json` ve `/.well-known/apple-app-site-association`
  gerçek paket adı / Team ID ile yayınlanmalı (Android App Links + iOS
  Universal Links), `firebase.json > hosting.rewrites` bunlara yönlendirmeli,
* mobil tarafta gelen `qr.html?t=...` bağlantısı karşılanıp token doğrudan
  tarama akışına verilmeli,
* web'de `js/modules/events/app-handoff.js` içindeki `NATIVE_APP.enabled`
  bugün `false`; özel şema (`regipass://qr?t=...`) yedek yol olarak açılabilir.

Uygulama **içindeki** tarayıcılar bundan etkilenmez: her iki QR biçimini de
okurlar. Eksik olan yalnızca telefonun kendi kamerasından gelen kısayoldur.

## Kural tarafı

Kapı şartı yalnızca istemcide değil `firestore.rules` içinde de duruyor
(`studentCanMarkOwnSessionCheckIn`). İki yeni alan da `.get(alan, varsayılan)`
ile okunur; eski kayıtlarda alanlar bulunmadığı için koşul, bugünkü davranışı
aynen koruyarak geçer.

Öğrencinin kapı girişini kendi kaydına yazması `studentCanMarkOwnEventCheckIn`
dalından geçer. O dal `checkedInVia == "self-qr"` yazılmasını **zorunlu**
kılar ve yalnızca `events.entryOpen == true` iken çalışır: QR'ın kendisi bir
sır değildir (ekran görüntüsü paylaşılabilir), asıl sınır kulübün kapıyı
açıp kapatmasıdır.
