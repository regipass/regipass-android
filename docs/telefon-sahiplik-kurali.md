# Telefon sahiplik dizini için Firestore kuralı

Hesap ekranında numara değiştirirken, SMS gönderilmeden önce "bu numara başka
bir hesaba ait mi?" sorgusu yapılıyor (`lib/services/phone_directory_repository.dart`).
Bu sorgu **profil koleksiyonlarından yapılamaz**:

```javascript
// Desktop/REGİPASS/firestore.rules
match /student_profiles/{userId} {
  allow read: if isOwner(userId) || isAdmin();
```

Profiller yalnızca sahibine açık; `where("phone", "==", ...)` sorgusu her
zaman `permission-denied` alır. Bu yüzden yalnızca bu sorunun ihtiyacı kadar
veri taşıyan ayrı bir koleksiyon kullanılıyor: `phone_owners`.

- **Belge kimliği:** E.164 numaranın kendisi (`+905551234567`).
- **İçerik:** `uid`, `status`, `updatedAt` — başka hiçbir alan yok.

## Belge şeması (yayındaki kuralla birebir)

```json
{ "uid": "<sahibin uid'si>", "status": "verified | pending", "updatedAt": <serverTimestamp> }
```

| status | anlamı | ömrü |
| --- | --- | --- |
| `verified` | Numara Firebase Auth'ta gerçekten bu hesaba bağlı. Kanıtı ID token'daki `phone_number` iddiası — sahtelenemez. | kalıcı |
| `pending` | Numaraya SMS gönderildi, kod henüz onaylanmadı. Kanıt taşımaz. | 15 dakika |

`pending` kanıt taşımadığı için süreli: aksi hâlde biri istediği numarayı
rezerve edip o kişinin hiç kaydolamamasını sağlayabilirdi. Süre dolunca kural
başkasının aynı numarayı rezerve etmesine izin verir.

> **DİKKAT — sessiz arıza kaynağı.** İstemci `status` alanını yazmazsa kural
> yazımı REDDEDER (`isVerifiedClaim()` de `canReserve()` de önce `status`'e
> bakar). Depodaki yazımların hepsi "en iyi çaba" (hata yutuluyor), dolayısıyla
> eksik şema **hiçbir hata göstermeden** dizinin hiç dolmamasına ve
> "bu numara başkasına ait" uyarısının hiç çıkmamasına yol açar. Bir dönem tam
> olarak bu yaşandı. Alan adları değişecekse kural ve
> `lib/services/phone_directory_repository.dart` birlikte güncellenmeli.

Ayrıca `updatedAt` **mutlaka** `FieldValue.serverTimestamp()` olmalı: kural
`request.resource.data.updatedAt == request.time` şartını arar, aksi hâlde
istemci ileri tarihli bir damga yazıp rezervasyonunu sonsuza kadar taze
gösterebilirdi.

## Yayındaki kural

```javascript
    match /phone_owners/{phoneNumber} {
      function isVerifiedClaim() {
        return request.resource.data.status == "verified"
          && request.auth.token.phone_number is string
          && request.auth.token.phone_number == phoneNumber;
      }

      function pendingExpired() {
        return resource.data.status == "pending"
          && resource.data.updatedAt is timestamp
          && request.time > resource.data.updatedAt + duration.value(15, 'm');
      }

      function canReserve() {
        return request.resource.data.status == "pending"
          && (
            resource == null
            || resource.data.uid == request.auth.uid
            || pendingExpired()
          );
      }

      allow get: if isSignedIn();
      allow list: if false;

      allow create, update: if isSignedIn()
        && request.resource.data.keys().hasOnly(["uid", "status", "updatedAt"])
        && request.resource.data.uid == request.auth.uid
        && request.resource.data.updatedAt == request.time
        && (isVerifiedClaim() || canReserve());

      allow delete: if isSignedIn() && resource.data.uid == request.auth.uid;
    }
```

## Kural yayınlanmadan ne olur?

Uygulama **çalışmaya devam eder**, kontrol yalnızca bir adım geriye kayar:

- `lookup(...)` `permission-denied` alır ve `PhoneOwnership.unknown` döner;
  akış durmaz, kullanıcı doğrulama pop-up'ına geçer.
- Numara gerçekten başkasına aitse Firebase Auth telefon bağlama adımında
  `credential-already-in-use` ile reddeder ve pop-up
  "Bu telefon numarası zaten başka bir hesaba bağlı" mesajını gösterir.

Yani kural, hatayı **SMS gönderilmeden önce** yakalamak için var; güvenlik
sınırını Firebase Auth'un kendi tekillik kontrolü zaten koruyor.

## Dizin nerede dolar

1. **Doğrulama bittiğinde** — `claim(...)`, numarayı doğrulayan hesaba yazar,
   varsa eski numarayı düşürür.
2. **Uygulama her açıldığında** — `ensureSelfClaim(...)` (bkz. `lib/app/app.dart`),
   Auth hesabında bağlı numarası olan kullanıcının kaydı dizinde yoksa onu
   yazar.

(2) olmasa dizin yalnızca kural yayınlandıktan **sonra** doğrulanan numaralarla
dolardı; daha eski hesapların numaraları "serbest" görünür ve uyarı ancak SMS
gönderilip kod girildikten sonra, Firebase Auth telefon bağlama adımında
çıkardı. Bu yüzden dizin, kullanıcılar uygulamayı açtıkça kendiliğinden dolar.

Kural yazma iznini `request.auth.token.phone_number == phoneE164` şartına
bağladığı için bu geriye dönük yazım da güvenli: kimse sahibi olmadığı bir
numarayı işgal edemez.

## Web ile ortak koleksiyon

`phone_owners` koleksiyonunu **hem web hem mobil** kullanır; kural da ikisi
için ortaktır. Referans uygulama web tarafındaki
`js/modules/auth/phone-registry.js`; mobil taraf ona birebir denk olmalı:

| Web (`phone-registry.js`) | Mobil (`phone_directory_repository.dart`) |
| --- | --- |
| `findPhoneOwner` / `getPhoneAvailability` | `lookup()` |
| `reservePhone` | `reserve()` |
| `releasePhone` | `release()` |
| `claimPhone` | `claim()` |
| `ensurePhoneClaim` | `ensureSelfClaim()` |
| `PENDING_TTL_MS = 15 dk` | `kPendingTtl = 15 dk` |
| `keyFor` → `/^\+\d{6,20}$/` | `_isUsableKey` → aynı desen |

Bu tablo bozulursa hata **sessiz** olur: bir platformun yazdığı kaydı diğeri
bulamaz ya da yazımı kural reddeder (yazımların hepsi en iyi çaba, hata
yutulur). Bir tarafta alan adı/TTL/anahtar deseni değişiyorsa diğeri ve kural
aynı commit'te güncellenmeli.

Tek bilinçli fark: mobildeki `release()` yalnızca **kendi bekleyen**
rezervasyonunu siler, doğrulanmış kaydına dokunmaz (web'de `releasePhone`
koşulsuz siler). Eski numarayı düşürme işini mobilde `claim()` kendi içinde
yapar, dolayısıyla davranış aynı kalır.

## Numara sorgusu nerede yapılıyor

İki katman var:

1. **Yazarken (canlı).** `LivePhoneField`
   (`lib/features/shared/live_phone_field.dart`), kullanıcı yazmayı bıraktıktan
   450 ms sonra `lookup(...)` çağırır ve uyarıyı doğrudan alanın altında
   gösterir — hiçbir düğmeye basmadan, sayfa yenilenmeden. Telefon alanı olan
   tüm ekranlar (öğrenci/kulüp bilgi formu, numara değiştir, öğrenci/kulüp
   hesap ekranı) bu alanı kullanır.
2. **Kaydederken / SMS'ten hemen önce.** Aynı sorgu bir kez daha yapılır:
   kullanıcı numarayı yazıp hemen kaydete basarsa canlı sorgu daha bitmemiş
   olabilir. `phone_verify_screen.dart` ayrıca sorgu geçtikten sonra
   `reserve(...)` ile numarayı `pending` olarak rezerve eder ve pop-up
   kapatılırsa `release(...)` ile bırakır.

## Gizlilik notu

Kural, giriş yapmış bir kullanıcının **bildiği** bir numarayı tek tek
yoklayıp kayıtlı olup olmadığını (ve kayıtlıysa uid'sini) görmesine izin
verir. `list` kapalı olduğu için toplu tarama yapılamaz. Numaradan isim,
e-posta ya da başka profil alanına ulaşılamaz.
