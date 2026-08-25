# Öğrenci profili değişince kayıtların tazelenmesi

## Sorun

`event_registrations/{eventId}_{studentId}` dokümanı, kayıt anında öğrencinin
profilinden **kopyalanan** alanları taşır:

```
studentName, studentFirstName, studentLastName, studentEmail,
studentPhone, studentCity, studentUniversity, studentDepartment,
studentClassYear
```

Bu kopya bilinçli (denormalizasyon): kulüp, öğrencinin profilini **okuyamaz**.

```javascript
// Desktop/REGİPASS/firestore.rules
match /student_profiles/{userId} {
  allow read: if isOwner(userId) || isAdmin();
```

Kulübün gördüğü her yerde kaynak bu kopyadır:

| Yer | Okuduğu alan |
| --- | --- |
| Katılımcı listesi (mobil + web) | `studentName` |
| Excel çıktısı (`club-events.js#buildRegistrationsExcelXml`) | `studentName` |
| Belgeye işlenen isim (`club-events.js` → `personalizePdfWithName`) | `studentName` |

Kopya kayıt anında bir kez yazılıp bir daha güncellenmiyordu. Öğrenci adını
(ya da bölümünü, telefonunu) değiştirdiğinde — etkinlik başlamadan önce,
devam ederken ya da bittikten sonra, fark etmeksizin — kulüp **eski** bilgiyi
görmeye devam ediyordu; Excel'e ve belgeye de eski isim işleniyordu.

## Çözüm (istemci tarafı)

`EventRepository.syncStudentInfoOnRegistrations` öğrencinin bütün kayıtlarındaki
kopya alanları tazeler. Çağrıldığı yerler:

- `lib/features/student/student_account_screen.dart` — profil kaydedildiğinde
  ve yeni telefon numarası doğrulandığında,
- `lib/features/onboarding/student_info_screen.dart` — onboarding formu
  (düzenleme modunda da) kaydedildiğinde.

Yazım **en iyi çaba** ve kayıt kayıt yapılır (`WriteBatch` değil): tek bir
kaydın reddedilmesi diğerlerini geri almasın, profil kaydetme akışı hiçbir
durumda hata vermesin.

> **Zaten dağıtılmış belgeler değişmez.** Belge, dağıtım anında üretilip
> Storage'a yazılır. İsim değişikliğinden sonra o belgede eski isim kalır;
> kulübün belgeyi yeniden dağıtması gerekir. Yeniden dağıtım artık güncel ismi
> kullanır.

## Gereken Firestore kuralı

Kaydı öğrencinin güncellemesine izin veren mevcut dal, etkinliğin **hâlâ kayıt
alıyor** olmasını şart koşuyor:

```javascript
allow update: if (
    isSignedIn()
    && registrationPayloadValid()
    && studentEligibleForTargetEvent()
    && (
      registrationDebugMode()      // şu an true — bu şartı BYPASS ediyor
      || targetEventAllowsRegistration()
    )
  )
  || clubCanMarkCheckIn()
  || studentCanMarkOwnSessionCheckIn();
```

Yani senkron bugün yalnızca `registrationDebugMode()` açık olduğu için her
durumda çalışıyor. Bu bayrak kapatıldığı anda:

- son başvurusu geçmiş / kaydı kapatılmış etkinliklerde senkron reddedilir —
  **tam olarak sorunun en sık yaşandığı durum** (etkinlik bitmiş, öğrenci
  adını düzeltiyor),
- öğrenci üniversitesini/bölümünü değiştirip etkinliğin hedef kitlesinin
  dışına çıktıysa `studentEligibleForTargetEvent()` de düşer.

`event_registrations` bloğuna aşağıdaki dal eklenmeli:

```javascript
// Ogrenci, KENDI kaydindaki profil kopyasi alanlarini tazeler.
// Etkinligin durumuna bakilmaz: isim degisikliginin katilimci listesine,
// Excel'e ve belgeye yansimasi etkinlik bittikten sonra da gerekli.
// Katilim/giris alanlarina bu daldan DOKUNULAMAZ (hasOnly listesi).
function studentCanRefreshOwnProfileMirror() {
  return isSignedIn()
    && resource.data.studentId == request.auth.uid
    && request.resource.data.eventId == resource.data.eventId
    && request.resource.data.studentId == resource.data.studentId
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly([
      "studentFirstName",
      "studentLastName",
      "studentName",
      "studentEmail",
      "studentPhone",
      "studentCity",
      "studentUniversity",
      "studentDepartment",
      "studentClassYear",
      "updatedAt"
    ]);
}
```

ve `allow update` zincirine eklenmeli:

```javascript
  || clubCanMarkCheckIn()
  || studentCanMarkOwnSessionCheckIn()
  || studentCanRefreshOwnProfileMirror();
```

`affectedKeys()` yalnızca **değeri değişen** alanları sayar; istemci
`eventId`/`studentId` alanlarını aynı değerle yeniden yazsa bile bu liste
bozulmaz.

## Doğrulama

1. Öğrenci bir etkinliğe kaydolur, kulüp katılımcı listesinde adını görür.
2. Öğrenci Hesabım ekranından adını değiştirip kaydeder.
3. Kulüp etkinlik ekranını yeniler → katılımcı listesinde **yeni** ad görünür.
4. Web'de Excel indirilir → yeni ad yazar.
5. Etkinlik bitirilip belge dağıtılır → belgeye yeni ad işlenir.

3. adımda ad değişmiyorsa kural yayınlanmamış demektir; Firestore konsolunda
yazımın `permission-denied` aldığı görülür (istemci hatayı yutar).
