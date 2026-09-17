# Regipass — Mobil (Flutter)

Regipass web uygulamasının (`Desktop/REGİPASS`) Android + iOS portu.
**Aynı Firebase projesini** (`eventapp-604a5`) ve **aynı Firestore
koleksiyonlarını** kullanır; web ve mobil aynı veriyi okur/yazar.

## Kurulum

Paket adı her platformda **`app.regipass.mobile`**; Firebase kayıtları da bu
adla yapılmış ve `lib/firebase_options.dart` gerçek değerleri taşıyor.
Yeniden üretmek gerekirse:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=eventapp-604a5
```

**Android.** Firebase Console > Proje ayarları > Android uygulaması
bölümünden **hata ayıklama ve yayın SHA-1/SHA-256 parmak izlerini** ekleyin;
Google Sign-In ve telefon doğrulaması bunu şart koşar. Ayrıntı:
[docs/telefon-dogrulama-recaptcha.md](docs/telefon-dogrulama-recaptcha.md).
Harita anahtarı `android/local.properties` içindeki `MAPS_API_KEY`'den
okunur (depoya girmez).

**iOS.** Bağımlılıklar, izinler, Xcode yetenekleri ve Apple Developer /
Google Cloud hesaplarından alınacak anahtarların tamamı:
[docs/ios-kurulum.md](docs/ios-kurulum.md). Kısaca: dağıtım hedefi iOS 15.0,
CocoaPods zorunlu, telefon doğrulaması için Firebase'e bir **APNs anahtarı**
yüklenmiş olmalı ve harita anahtarı `ios/Flutter/Maps.xcconfig` içine elle
kopyalanmalı (o dosya da depoya girmez).

## Mimari

| Katman | Dizin | Web karşılığı |
|---|---|---|
| Sabitler, metin/şifre kuralları | `lib/core/` | `js/modules/utils/`, `js/core/admin-config.js` |
| Üretilen veri tabloları | `lib/data/` | `js/data/` |
| İş mantığı (saf, test edilir) | `lib/domain/` | `js/modules/events/`, `js/modules/auth/role-session.js` |
| Firestore modelleri | `lib/models/` | — (web düz nesne kullanıyordu) |
| Firebase erişimi | `lib/services/` | `js/core/firebase.js` + sayfa içi sorgular |
| Durum yönetimi | `lib/state/` | `onAuthStateChanged` + `onSnapshot` |
| Yönlendirme | `lib/app/router.dart` | 20+ sayfadaki `window.location.href` |
| Çeviriler | `lib/l10n/` | `js/modules/i18n/language.js` |
| Ekranlar | `lib/features/` | `*.html` + `js/pages/` |

### Yönlendirme

Web'de her sayfa kendi `onAuthStateChanged` bloğunda yönlendirme kararı
veriyordu (aynı mantık 20+ dosyada tekrarlanıyordu). Mobilde bu kararların
tamamı `lib/app/router.dart` içindeki tek bir `redirect` fonksiyonunda:

- oturum yok → tanıtım sayfası
- yönetici (`a@regipass.app`) → yönetici paneli
- rol yok / iki rol birden → rol seçimi
- öğrenci: onboarding → telefon doğrulama → panel
- kulüp: bilgi formu → belge yükleme → onay bekleme → panel
- engellenmiş kullanıcı → oturum kapatılır

### Üretilen dosyalar

`lib/data/*.dart` ve `lib/l10n/translations.dart` web kaynağından üretilir,
elle düzenlenmez. Web tarafı değişince yeniden üretin:

```bash
node tool/convert_data.mjs       # iller, üniversiteler, bölümler, ülke kodları
node tool/convert_field_map.mjs  # bölüm <-> kulüp alanı anahtar kelimeleri
node tool/convert_i18n.mjs       # tr/en çeviri sözlüğü
```

Mobile özgü metinler `lib/l10n/extra_translations.dart` içinde tutulur
(üretilen dosyaya dokunmadan); arama sırası: ek sözlük → üretilen sözlük →
Türkçe → anahtarın kendisi.

## Giriş ekranı ve misafir vitrini

Giriş ekranı (`lib/features/landing/`) web'deki kaydırmalı tanıtım
sayfasının yerini alır: tek ekranda sabit yerleşim, koyu zemin, buzlu cam
form kartı. Tasarım kararlarının gerekçeleri:

- **Koyu zemin.** Tek parlak nokta kırmızı "Giriş Yap" butonu olur; göz
  oraya kilitlenir. Açık zeminde aynı etki için butonu büyütmek gerekirdi,
  bu da arka plandaki hareketle yarışırdı.
- **Çapraz akan yazı katmanı** (`diagonal_marquee.dart`). Sol alttan sağ
  üste, %5-9 opaklıkta kulüp/etkinlik adları ve emojiler. Satırlar aynı
  yönde ama farklı hızlarda akar — zıt yönler ekranı "makaslar" ve göz
  sürekli yön değiştirmek zorunda kalırdı. En hızlı satır saniyede ~18
  piksel.
- **Hareket azaltma desteği.** Cihazda "hareketi azalt" açıksa animasyon
  hiç başlamaz. Vestibüler bozukluk, migren ve ADHD için gerekli; düşük
  pilde de işlemciyi meşgul etmez.
- **Buzlu cam kart.** Arka plandaki hareketin form alanına sızmasını
  engeller.

**Keşfet** (`lib/features/explore/`) giriş yapmadan etkinliklere göz atma
ekranı. Alt gezinme çubuğu yok; üstte solda "Giriş Yap", sağda dil. Tüm
etkinlikler (geçmiş olanlar dâhil) her açılışta **rastgele** sırada gelir.
Salt görüntüleme — kayıt, QR ve belge işlemleri giriş gerektirir.

> ⚠️ Keşfet'in gerçek veri gösterebilmesi için `firestore.rules` içindeki
> etkinlik okuma kuralının açılması gerekiyor. Kural açılana kadar ekran
> açıklayıcı bir mesaj gösterir, boş kalmaz veya çökmez.
> Ayrıntı ve önerilen kural: [docs/misafir-vitrini-firestore-kurali.md](docs/misafir-vitrini-firestore-kurali.md)

## Web'den bilinçli sapmalar

- **reCAPTCHA yok** — mobilde Firebase Auth cihaz doğrulamasını kendisi
  yapar; `RecaptchaVerifier` kodu kaldırıldı.
- **Yönetici şifresi gömülü değil** — web'deki eski sabit yönetici parolası
  sabiti hiçbir yerde kullanılmıyordu ve istemci paketinde şifre taşımak
  risk oluşturduğu için taşınmadı.
- **Alt gezinme çubuğu** — web'deki yan çekmecenin yerine; hesap bağlantısı
  üst çubuktaki profil menüsüne alındı (6 sekme dar ekranda okunmuyordu).
- **Tam ekran arama** — 612 bölüm / 200+ üniversite için açılır liste yerine
  aranabilir tam ekran seçici.

QR üretimi web ile **aynı** kalmıştır (`api.qrserver.com`), böylece iki
platformun ürettiği kodlar birebir aynıdır. Token formatı da aynı:
`EVAPPQR1:` + base64url(JSON).

## Check-in / Yoklama modları

Kulüp etkinliği oluştururken üç moddan birini seçer: **Check-in + Yoklama**,
**Sadece Yoklama**, **Sadece Check-in**. Mod `events.checkinMode` alanında
durur; alanı olmayan eski kayıtlarda oturum sayısından türetilir ve davranış
değişmez. Ayrıntı, QR türleri ve kural tarafı:
[docs/check-in-modlari.md](docs/check-in-modlari.md)

## Durum

| Bölüm | Durum |
|---|---|
| Çekirdek altyapı, modeller, servisler, yönlendirme | ✅ tamam |
| i18n (tr/en, 533 anahtar) | ✅ tamam |
| Öğrenci akışı (kayıt → onboarding → telefon → keşif → randevu → QR → belge → hesap) | ✅ tamam |
| Kulüp onboarding (bilgi formu) | ✅ tamam |
| Kulüp panel / etkinlik yönetimi / QR okutma / belge dağıtımı | ⏳ iskelet |
| Yönetici paneli (onay, istatistik, engelleme) | ⏳ iskelet |

## Komutlar

### GitHub'dan IPA alma

`main` dalina push edildiginde **Actions > iOS derleme** akisi macOS'ta
analiz, test ve iOS release derlemesini calistirir. Basarili calismanin
**Artifacts > Regipass-ipa-unsigned** dosyasini indirip ZIP'i acin;
icinde `Regipass-unsigned.ipa` bulunur.

Bu IPA **imzasizdir**: cihaza kurulumdan once Apple sertifikasi ve uygun
provisioning profiliyle imzalanmalidir. TestFlight / App Store icin Mac'te
imzalama ayarlari tamamlanip `flutter build ipa --release` calistirilir;
ayrintilar [iOS kurulum belgesinde](docs/ios-kurulum.md).
Haritanin calismasi icin depodaki Actions secrets alanina `MAPS_API_KEY`
eklenmelidir.

### Yerel gelistirme

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
