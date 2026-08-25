# Misafir vitrini için Firestore kuralı

Keşfet ekranı giriş yapmamış kullanıcıya etkinlikleri gösteriyor. Mevcut
kural bunu engelliyor:

```javascript
// Desktop/REGİPASS/firestore.rules — satır 87
match /events/{eventId} {
  allow read: if isSignedIn();
```

Kural açılmadan Keşfet ekranı `permission-denied` alır ve kullanıcıya
"Etkinlikler misafir kullanıcılara henüz açık değil" mesajını gösterir
(uygulama çökmez, boş ekran da kalmaz).

## Önerilen değişiklik

```javascript
match /events/{eventId} {
  allow read: if isSignedIn() || resource.data.hiddenGlobally == false;

  allow create: if isClubUser() && request.resource.data.clubId == request.auth.uid;
  allow update, delete: if isSignedIn() && resource.data.clubId == request.auth.uid;
}
```

Yalnızca `read` satırı değişiyor; yazma kuralları aynı kalıyor.
**Bu değişiklik `firestore.rules` dosyasına uygulandı, henüz yayınlanmadı.**

### Neden `isSignedIn() ||` kısmı duruyor?

Firestore'da sorgu (`list`) izni **dönen belgelere değil, sorgunun kendisine**
bakar. Kural `resource.data`'ya bağlıysa sorgunun da aynı alanı filtrelemesi
gerekir; aksi hâlde Firestore sorgunun tamamını reddeder.

- **Misafir tarafı** bu yüzden `where('hiddenGlobally', isEqualTo: false)` ile
  sorguluyor (`explore_providers.dart`). İstemcide filtrelemek yetmez.
- **Öğrenci paneli** filtresiz `eventsCol.get()` çağırıyor. `isSignedIn()`
  dalı belgeden bağımsız olduğu için bu sorgu çalışmaya devam eder.

`isSignedIn()` kaldırılsaydı öğrenci panelindeki etkinlik listesi çökerdi.

### Bilinen sınır

`hiddenGlobally` alanı hiç yazılmamış eski etkinlikler misafir listesinde
görünmez. Uygulama üzerinden oluşturulan her etkinlikte bu alan `false`
olarak yazılıyor (`club-create-event.js`), dolayısıyla normalde sorun
çıkarmaz. Keşfet'te eksik etkinlik görürsen sebebi budur — o belgelere
`hiddenGlobally: false` eklemek çözer.

## Bunu uygulamadan önce bil

**Bu kural etkinlik dokümanının tamamını herkese açar.** İçinde şunlar var:

| Alan | Açığa çıkan |
|---|---|
| `title`, `description`, `purpose` | Etkinlik içeriği — zaten kamuya yönelik |
| `clubName`, `clubUniversity` | Kulüp kimliği — zaten kamuya yönelik |
| `locationLat`, `locationLng`, `locationRadius` | **Etkinliğin tam GPS koordinatı** |
| `quota`, `feeAmount` | Kontenjan ve ücret |
| `targetUniversity`, `targetDepartment` | Hedef kitle |

Katılımcı listesi (`event_registrations`) ve profiller etkilenmez — onların
kuralları ayrı ve değişmiyor.

Değerlendirmen gereken tek şey konum: etkinlik koordinatları internete açık
olur. Herkese açık kampüs etkinlikleri için bu genelde sorun değil, ama
kapalı/özel bir etkinliğin yeri sızmasın istiyorsan alternatif olarak
konum alanlarını okuma dışında bırakan bir yapı gerekir (etkinlik belgesini
ikiye bölmek gibi) — o daha büyük bir değişiklik olur.

## Uygulama

Bu dosya yalnızca öneri. Değişikliği **sen** yapmalısın:

1. `C:\Users\5sana\Desktop\REGİPASS\firestore.rules` içindeki `read` satırını
   yukarıdaki gibi düzenle.
2. Deploy et:
   ```bash
   cd "C:\Users\5sana\Desktop\REGİPASS"
   firebase deploy --only firestore:rules
   ```
3. Keşfet ekranını tekrar aç — gerçek etkinlikler görünecek.

Bu kural web uygulamasını da etkiler (aynı backend). Web tarafında etkinlik
okuma zaten giriş yapmış kullanıcılarla sınırlıydı; kuralın gevşemesi web'de
bir davranış değişikliğine yol açmaz, yalnızca API üzerinden dışarıdan da
okunabilir hâle gelir.

## İlgili not

Aynı dosyada duran bu geçici kod hâlâ açık:

```javascript
// satır 39
function registrationDebugMode() {
  return true;   // "Sorun cozulunce mutlaka false yap"
}
```

`true` olduğu sürece `event_registrations` create/update işlemlerinde
etkinlik kontrolleri (gizli mi, kayıt kapalı mı) **atlanıyor** — yani
kapatılmış bir etkinliğe kayıt olunabiliyor. Bu kuralı deploy ederken
bunu da gözden geçirmek iyi olur.
