# Ücretli etkinlik onay logu

## İhtiyaç

Ücretli etkinliklerde iki taraf da bir metni açıkça onaylıyor:

* **kulüp**, etkinliği oluştururken ödeme sorumluluğunun kendisinde olduğunu,
* **öğrenci**, kayıt olmadan hemen önce ödemenin Regipass dışında yapıldığını.

Onay pencereleri zaten vardı, ama mobilde kayda yalnızca **sürüm + sunucu
damgası** düşüyordu. Bir ihtilafta "hangi metin, tam olarak ne zaman kabul
edildi" sorusu veriye bakılarak yanıtlanamıyordu: metin uygulamanın o günkü
sözlüğünden okunuyordu ve sözlük değişebilir.

## Şema — web ile ORTAK

Onay penceresi artık `bool` değil, ekranda **gösterilen metnin kendisini**
taşıyan bir kayıt döndürüyor (`PaidEventConsentAcceptance`,
[lib/domain/paid_event_consent.dart](../lib/domain/paid_event_consent.dart)).
Yazan taraf metni yeniden çevirmez; kabul anındaki hâli olduğu gibi yazılır.

Her iki belgede de tek bir harita tutulur:

```
paidConsentLog: {
  approved:            true
  text:                kabul edilen metnin TAM hâli
  approvedAtMs:        epoch milisaniye (sorgulanabilir asıl değer)
  approvedAt:          serverTimestamp() — istemci saatinden bağımsız
  approvedAtFormatted: "03.09.2026 14:22:07"   // gün.ay.yıl saat:dk:sn
}
```

Alan adları web ile **birebir** aynıdır:
`js/pages/club-create-event.js#saveEvent` ve
`js/pages/dashboard.js#buildRegistrationPayload`. İki istemci aynı logu
okuyup yazar; değişecekse iki tarafta birden değişmeli.

### Nerede duruyor

| Onay | Belge |
| --- | --- |
| Kulüp (etkinlik oluşturma / düzenleme) | `events/{eventId}` |
| Öğrenci (kayıt) | `event_registrations/{eventId}_{studentId}` |

İkisi de **etkinlik verisidir**; öğrencinin profil belgesine
(`student_profiles/{uid}`) hiçbir şey yazılmaz. Öğrenci onayı, o etkinliğin
katılımcı kaydının içinde — yani kulübün ücretli etkinlik altında gördüğü
öğrenci bilgisinin yanında — durur.

**Neden etkinlik belgesinin kendisine değil:** öğrenci `events/{eventId}`
belgesini güncelleyemez (`allow update: ... resource.data.clubId ==
request.auth.uid`). Ayrıca her kaydın etkinlik belgesine yazması, kontenjan
sayacını parçalara bölerek kurtardığımız darboğazı geri getirirdi (tek
dokümana sürdürülebilir yazma ~1/sn, bkz.
[kayit-kapasitesi.md](kayit-kapasitesi.md)).

Log **yalnızca ücretli etkinlikte** yazılır; ücretsizde tek alan bile
eklenmez. Etkinlik ücretsize çevrildiğinde log silinir (web ve mobil aynı
davranır) — ücretsiz bir etkinlikte bayat bir ödeme onayı kalmaz.

`approvedAtMs` **onay anıdır**, yazma anı değil: kabul ile Firestore yazımı
arasında kapak görseli yüklemesi gibi saniyeler sürebilen adımlar var.

### Nerede görünüyor

Kulüp etkinlik detayında (ücretli etkinlikte) **Ücretli Etkinlik Onay Kaydı**
bölümü: kulübün kendi onayı ve onay veren öğrencilerin listesi — her satırda
damga ve dokununca açılan metnin tamamı. Katılımcı kartında da öğrencinin
onay damgası ayrı bir satır olarak yazılı.

## Kural zorunluluğu (firestore.rules)

Onay artık yalnızca istemcide değil, **kuralda** zorunlu:

* **Ücretli etkinlik oluşturulamaz** — `events` create, `feeType == "paid"`
  ise geçerli bir `paidConsentLog` ister (`approved == true`, dolu `text`,
  pozitif `approvedAtMs`).
* **Ücretli etkinliğe kayıt yazılamaz** — `event_registrations` create,
  hedef etkinlik ücretliyse aynı logu ister.
* **Var olan log silinemez/bozulamaz** — ne etkinlikte ne kayıtta; tek
  istisna etkinliğin ücretsize çevrilmesi.
* **Ücretsizden ücretliye geçiş** onay ister.
* Ücretsiz etkinlikler ve **bu kural yayınlanmadan önce oluşmuş** ücretli
  etkinlikler etkilenmez: eski (logsuz) ücretli etkinlik hâlâ güncellenebilir,
  yoksa kulüp kendi etkinliğinin kaydını bile kapatamazdı.

İki uygulama notu:

* Kayıt **güncelleme** dalında etkinliği bir kez daha okumak (`get`) kural
  değerlendirmesinin **1000 ifade** bütçesini aşıyor ve meşru güncellemeler
  bile "evaluation error" ile reddediliyordu. Güncellemede belge okumayan
  ucuz bir koşul kullanılıyor: *var olan geçerli log zayıflatılamaz*. Zorunlu
  tutma asıl yerinde — create'te — yapılıyor.
* Kural, kaydın kontenjan parçasının sayacıyla **aynı commit'te** yazılmasını
  zaten şart koşuyor (`slotClaimedInSameCommit`); onay koşulu bu akışın
  üstüne biniyor, akışı değiştirmiyor.

> **Yayınlamadan önce:** kural, onay logu yazmayan HER istemciyi ücretli
> akışlardan dışarı atar. Web (bugünkü hâliyle) ve bu mobil sürüm logu
> yazıyor; **eski mobil sürümler yazmıyor**. Kuralı yayınlamak, yayınlanmış
> eski uygulama sürümlerinde ücretli etkinliğe kaydı kırar.
>
> ```bash
> firebase deploy --only firestore:rules
> ```

## Doğrulama (emulator)

Log gerçekten yazılıyor mu, kural gerçekten zorunlu tutuyor mu — Firestore
emulator'e karşı ölçülüyor. Yazılan alanlar elle değil **uygulamanın kendi
kodu** tarafından üretiliyor:

```bash
cd tool/loadtest/rules-env && firebase emulators:start --only firestore --project eventapp-604a5
```

```bash
dart run tool/consent_log_fields.dart > "$TEMP/consent_fields.json" && node tool/loadtest/12-ucretli-onay-logu.mjs "$TEMP/consent_fields.json"
```

Kurallar üretim dosyasından (`Desktop/REGİPASS/firestore.rules`) yükleniyor.
Son koşu: **21/21**. Kapsam:

* onay logu ile ücretli etkinlik oluşturuluyor; **logsuz, `approved:false`
  ve boş metinli** onay reddediliyor,
* onay logu ile kayıt yazılıyor; **logsuz ücretli kayıt reddediliyor**,
* alanlar iki belgede de aynen duruyor; kulüp öğrencinin metnini okuyabiliyor,
* `student_profiles/{uid}` belgesine hiçbir onay alanı sızmıyor,
* ücretsiz etkinlik ve kaydı kuraldan etkilenmiyor,
* log silinemiyor; ücretsize dönüşte silinebiliyor; ücretliye geçiş onay
  istiyor; eski logsuz ücretli etkinlik hâlâ güncellenebiliyor,
* mevcut akışlar bozulmuyor: öğrencinin kayıt kopyasını tazelemesi ve
  kontenjansız etkinlikte merge ile yeniden yazım çalışıyor.

## Eski kayıtlar

Mobil bir süre düz alanlar yazdı (`paidEventClubConsent*`,
`paidEventStudentConsent*`). Okuma tarafı bunları hâlâ tanıyor: log listesinde
görünürler, metin alanları boş kalır ve okunabilir damga epoch alanından
türetilir. Yeni yazımların hepsi `paidConsentLog` şemasıyla yapılır.
