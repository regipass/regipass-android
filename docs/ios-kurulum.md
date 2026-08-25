# iOS kurulumu, izinler ve alınacak anahtarlar

Proje bugüne kadar yalnızca Windows'ta geliştirildi: iOS tarafı **hiç
derlenmedi**, `pod install` hiç çalışmadı. Bu belge, bir Mac'te ilk derlemeye
kadar gereken her şeyi ve Apple Developer / Google Cloud hesaplarından
alınacak anahtarları sırayla anlatır.

Paket adı her yerde aynı olmalı: **`app.regipass.mobile`**
(Android `applicationId`, iOS bundle ID, Firebase kayıtları, Apple App ID).

---

## 1. Kod tarafında hazır olanlar

Bunlar depoda mevcut, tekrar yapılması gerekmiyor:

| Dosya | Ne yapıyor |
|---|---|
| `ios/Runner/Info.plist` | İzin açıklamaları, OAuth geri dönüş şeması, Google istemci kimlikleri, arka plan bildirim modu |
| `ios/Runner/Runner.entitlements` | Push Notifications + Sign in with Apple yetkileri |
| `ios/Runner.xcodeproj` | `CODE_SIGN_ENTITLEMENTS`, dağıtım hedefi 15.0, bundle ID, iPhone+iPad |
| `ios/Podfile` | `platform :ios, '15.0'` ve file_picker alt seçici bayrakları |
| `ios/Runner/AppDelegate.swift` | Google Maps anahtarının verilmesi, bildirim merkezi delegesi |
| `ios/Flutter/Maps.xcconfig` | Google Maps iOS anahtarı (depo dışı, bkz. §6.1) |
| `ios/Runner/Assets.xcassets/AppIcon` | 1024×1024 marka ikonu, alfa kanalı yok (App Store şartı) |

---

## 2. Bağımlılıklar — iOS tarafında ne çekiliyor

Dağıtım hedefi **iOS 15.0**. Belirleyen Firebase: `firebase_core`,
`firebase_auth`, `cloud_firestore` ve `firebase_storage` podspec'lerinin
tamamı `ios.deployment_target = '15.0'` diyor. Diğer eklentilerin hiçbiri
bunun üstünü istemiyor, dolayısıyla 15.0 hem alt hem üst sınır.

| Paket | iOS min | Çektiği yerel SDK | Ek gereksinim |
|---|---|---|---|
| firebase_core / auth / firestore / storage | 15.0 | Firebase iOS SDK | — |
| google_sign_in_ios 6.3 | 13.0 | GoogleSignIn ~> 9.0 | URL şeması + `GIDClientID` |
| google_maps_flutter_ios 2.18 | 14.0 | GoogleMaps 8.4–10.x, Google-Maps-iOS-Utils | API anahtarı |
| mobile_scanner 7.4 | 12.0 | Apple Vision (ML Kit yok) | Kamera izni |
| image_picker_ios | 13.0 | PHPicker / UIImagePicker | Kamera + fotoğraf izni |
| geolocator_apple | 11.0 | CoreLocation | Konum izni |
| file_picker 10.3 | 12.0 | UIDocumentPicker (+DKImagePickerController) | bkz. §2.1 |
| flutter_local_notifications 22.3 | 13.0 | UserNotifications | Bildirim izni |
| share_plus 12 | 12.0 | UIActivityViewController | iPad'de konum dikdörtgeni |
| pdfx, url_launcher_ios, connectivity_plus, package_info_plus, flutter_timezone, shared_preferences_foundation | ≤13.0 | — | — |

**CocoaPods zorunlu.** Eklentilerin çoğu Swift Package Manager destekliyor
ama `google_maps_flutter_ios` ve `pdfx` desteklemiyor; bu ikisi yalnızca
Pod olarak geliyor. Mac'te CocoaPods kurulu olmalı:

```bash
brew install cocoapods
```

### 2.1 file_picker alt seçicileri

`file_picker` iOS'ta üç ayrı seçici derleyebiliyor: belge, medya ve ses.
Uygulama yalnızca `FileType.custom` (PDF/JPEG/PNG) kullanıyor, yani yalnızca
belge seçicisi gerekli. `ios/Podfile` diğer ikisini kapatıyor — ses seçicisi
derlemeye girseydi App Store, hiç çağrılmasa bile
`NSAppleMusicUsageDescription` açıklaması isteyecekti.

Bu bayraklar yalnızca CocoaPods yolunda geçerli. Mac'te Swift Package
Manager açıksa `file_picker` SPM üzerinden gelir ve üç seçici de derlenir.
O durumda ya bu proje için SPM kapatılmalı:

```bash
flutter config --no-enable-swift-package-manager
```

…ya da `Info.plist`'e `NSAppleMusicUsageDescription` eklenmeli.

---

## 3. İzinler

Hepsi `ios/Runner/Info.plist` içinde tanımlı. iOS'ta bu açıklamalar
Android'deki `<uses-permission>` gibi *bildirim* değil: eksikse izin
istenmez, **uygulama o anda çöker**.

| Anahtar | Hangi özellik | Kodda |
|---|---|---|
| `NSCameraUsageDescription` | QR okutma, profil fotoğrafı çekme | `club_qr_checkin_screen.dart`, `student_qr_checkin_screen.dart`, `profile_photo.dart` |
| `NSPhotoLibraryUsageDescription` | Profil fotoğrafı / etkinlik görseli seçme | `profile_photo.dart`, `club_create_event_screen.dart` |
| `NSLocationWhenInUseUsageDescription` | Etkinlik konumu seçme, giriş QR'ına konum damgası | `location_picker_screen.dart`, `appointment_detail_sheet.dart` |
| `UIBackgroundModes: remote-notification` | Telefon doğrulamasının sessiz APNs kontrolü | Firebase Auth, dolaylı |
| `CFBundleURLTypes` | Google girişi ve reCAPTCHA yedeğinin geri dönüşü | `auth_repository.dart`, `phone_verify_*.dart` |
| `aps-environment` (entitlements) | Aynı sessiz APNs kontrolü | Firebase Auth, dolaylı |
| `com.apple.developer.applesignin` (entitlements) | Apple ile giriş | `auth_repository.dart#signInWithApple` |

**Gerekmeyenler** — bilerek eklenmedi, gereksiz açıklama App Review'da soru
doğurur:

- `NSMicrophoneUsageDescription` — `mobile_scanner` yalnızca video akışı
  açıyor, ses kaydı yok.
- `NSAppleMusicUsageDescription` — ses seçici derlemeye girmiyor (§2.1).
- `NSPhotoLibraryAddUsageDescription` — uygulama galeriye hiçbir şey
  kaydetmiyor.
- `NSLocationAlwaysAndWhenInUseUsageDescription` — konum yalnızca ekran
  açıkken bir kez okunuyor, arka planda takip yok.
- `LSApplicationQueriesSchemes` — dışarı açılan tüm adresler `https://`
  (`maps.apple.com`); özel şema sorgulanmıyor.

Bildirim izni ayrı bir Info.plist anahtarı istemiyor; çalışma zamanında
`NotificationService.requestPermission()` ile isteniyor ve iOS izin kutusunu
o an gösteriyor.

---

## 4. Xcode'da yapılacaklar

`ios/Runner.xcworkspace` ile açın (`.xcodeproj` **değil**).

1. **Runner → Signing & Capabilities → Team**: yeni açılan geliştirici
   hesabını seçin. "Automatically manage signing" açık kalsın.
2. Bundle Identifier'ın `app.regipass.mobile` olduğunu doğrulayın.
3. Aşağıdaki üç yeteneğin listede göründüğünü doğrulayın. `Runner.entitlements`
   zaten bağlı olduğu için Xcode bunları genelde kendiliğinden gösterir;
   göstermiyorsa **+ Capability** ile ekleyin (dosyaya ikinci kez yazmaz):
   - **Push Notifications**
   - **Sign in with Apple**
   - **Background Modes** → yalnızca *Remote notifications* işaretli
4. Xcode "Automatically manage signing" ile App ID'yi Apple portalında
   günceller. Portalda `app.regipass.mobile` Identifier'ının **Push
   Notifications** ve **Sign in with Apple** kutuları işaretli olmalı;
   değilse elle işaretleyip profilleri yenileyin.

---

## 5. Apple Developer hesabından alınacak anahtarlar

Hepsi <https://developer.apple.com/account> → **Certificates, Identifiers &
Profiles** altında. Tarayıcıda yapılır, Mac gerekmez.

> **Rolünüz belirleyici.** Keys ve Identifiers bölümleri yalnızca **Account
> Holder** ve **Admin** rollerine açık. App Manager ve Developer rolündeki
> ekip üyeleri bu sayfaları hiç göremez — daveti kabul etmiş olsalar bile.
> Rolünüzü App Store Connect → *Users and Access* → kendi adınız altından
> görürsünüz.
>
> Birden fazla ekipteyseniz (kişisel takım + kuruluş takımı)
> developer.apple.com sağ üstteki **takım seçicisinden** doğru ekibi seçin;
> yanlış ekipteyken sayfalar boş görünür ve üyelik yokmuş gibi durur.
> `Team ID` de seçili ekibin kimliğidir — Firebase'e o girilecek.

> **Sıralama önemli.** Sign in with Apple anahtarı ve Services ID "Primary
> App ID" seçtirdiği için `app.regipass.mobile` Identifier'ının portalda
> **var olmasını** şart koşar. İki yol:
>
> - **Admin/Account Holder iseniz:** Identifier'ı elle oluşturun (§5.0) ve
>   Apple tarafının tamamını tek oturumda, Mac'e hiç dokunmadan bitirin.
> - **Değilseniz:** Identifier, Mac'te ilk derlemede otomatik imzayla
>   oluşur; §5.2 ancak ondan sonra yapılabilir. (APNs anahtarı her hâlükârda
>   Identifier'dan bağımsızdır, §5.1 önce yapılabilir.)

### 5.0 App ID (Identifier) — Admin iseniz ilk adım

<https://developer.apple.com/account/resources/identifiers/add/bundleId>

1. **App IDs** → Continue → tür: **App** → Continue
2. **Description**: `Regipass`
   (Apple yalnızca harf, rakam ve boşluk kabul ediyor — Türkçe karakter,
   kısa çizgi ve noktalama reddedilir)
3. **Bundle ID**: **Explicit** → `app.regipass.mobile`
   ⚠️ **Wildcard seçmeyin** — joker App ID'ler Push Notifications ve Sign in
   with Apple yeteneklerini alamaz. Bundle ID sonradan değiştirilemez, tam
   olarak bu şekilde yazın.
4. **Capabilities** sekmesinde işaretleyin:
   - **Push Notifications**
   - **Sign In with Apple** → yanındaki *Edit* → *Enable as a primary App ID*
5. Continue → Register

Bu kayıt oluştuktan sonra Xcode otomatik imzada App ID'yi yeniden
oluşturmaya çalışmaz, mevcudu kullanır.

### 5.1 APNs Authentication Key — ZORUNLU

Uygulama FCM kullanmıyor; bu anahtar **telefon (SMS) doğrulaması** için
gerekli. Firebase, SMS göndermeden önce cihaza görünmez bir push yollayıp
cevabını bekler — Android'deki Play Integrity kontrolünün iOS karşılığı.
Anahtar yoksa doğrulama her seferinde reCAPTCHA web sayfasına düşer.

1. <https://developer.apple.com/account/resources/authkeys/add>
2. **Key Name**: `Regipass APNs`
3. **Apple Push Notifications service (APNs)** kutusunu işaretleyin. Yanında
   **Configure** çıkarsa: Environment = **Sandbox & Production**, topic
   kısıtlaması boş. Firebase her iki ortamı da kullanıyor.
4. Continue → Register
5. `AuthKey_XXXXXXXXXX.p8` dosyasını indirin.
   ⚠️ **Yalnızca bir kez indirilebilir.** Kaybolursa anahtarı iptal edip
   yenisini üretmek gerekir (hesap başına en fazla 2 APNs anahtarı olur).
   Firebase'e yükledikten sonra da yedeğini saklayın — Firebase geri
   indirtmiyor.
6. Not alın: **Key ID** (10 karakter, dosya adında da var — `AuthKey_ABCD123456.p8`
   → `ABCD123456`) ve **Team ID** (<https://developer.apple.com/account> →
   Membership details, 10 karakter).

**Nereye gidiyor:**
<https://console.firebase.google.com/project/eventapp-604a5/settings/cloudmessaging>
→ "Apple app configuration" → `app.regipass.mobile` → **APNs Authentication
Key** → Upload. Üç alan istenir: `.p8` dosyası, Key ID, Team ID.

Doğrulama gerçek cihazda yapılmalı — simülatörde APNs yok, oradaki test her
zaman reCAPTCHA'ya düşer ve yanlış alarm verir.

> Cloud Messaging sekmesinde iOS uygulaması görünmüyorsa Firebase'de iOS
> uygulaması kaydı eksik demektir — `flutterfire configure` çalıştırılmış
> olduğu için kayıt var (`lib/firebase_options.dart` içindeki `ios.appId`),
> sayfayı yenilemek yeterli olur.

### 5.2 Sign in with Apple anahtarı + Services ID — Android için zorunlu

iOS'ta Apple ile giriş **yerel** akışla çalışıyor (firebase_auth,
`apple.com` sağlayıcısını `ASAuthorizationAppleIDProvider`'a yönlendiriyor),
yani iOS için §4'teki yetenek yeterli — ek anahtar gerekmez.

Ama aynı `signInWithApple()` **Android'de** Firebase'in barındırdığı web
akışını çalıştırıyor ve o akış Apple tarafında bir Services ID + imza
anahtarı istiyor. Android'de Apple girişinin çalışması için:

1. **Identifiers** → sağ üstteki türü **Services IDs** yapın → **+**
   - Description: `Regipass Web`
   - Identifier: `app.regipass.web` (bundle ID'den farklı olmalı)
2. Oluşan kaydı açın → **Sign in with Apple** → Configure
   - Primary App ID: `app.regipass.mobile`
   - Domains and Subdomains: `eventapp-604a5.firebaseapp.com`
   - Return URLs: `https://eventapp-604a5.firebaseapp.com/__/auth/handler`
3. **Keys** → **+** → Ad: `Regipass Apple Sign-In` → **Sign in with Apple**
   kutusunu işaretleyin → Configure → Primary App ID: `app.regipass.mobile`
   → Continue → Register → `.p8` dosyasını indirin (**bu da tek sefer**),
   Key ID'yi not alın.

**Nereye gidiyor:** Firebase Console → Authentication → Sign-in method →
**Apple** → etkinleştirin ve "OAuth code flow configuration" bölümünü
doldurun: Services ID, Apple Team ID, Key ID, Private key (`.p8` içeriği).

Apple, gizli e-posta yönlendirmesi (`@privaterelay.appleid.com`) kullanan
hesaplara e-posta gönderilebilmesi için ayrıca alan adı doğrulaması ister:
**Services** → *Sign in with Apple for Email Communication* → gönderen alan
adını ekleyip SPF kaydını yayınlayın. Uygulama şu an kullanıcıya doğrudan
e-posta göndermiyor (şifre sıfırlama e-postasını Firebase gönderiyor),
dolayısıyla bu adım şimdilik ertelenebilir.

### 5.3 App Store Connect API Key — isteğe bağlı

Yüklemeyi Xcode yerine komut satırından (fastlane, `xcrun altool`, CI) yapmak
isterseniz: **Keys** → **App Store Connect API** → **+** → rol *App Manager*.
İndirilen `.p8` ile birlikte **Issuer ID** ve **Key ID** gerekir. Xcode'dan
elle yükleyecekseniz gerekmez.

### 5.4 Sertifikalar ve profiller

Elle üretmeyin. Xcode'da "Automatically manage signing" açıkken Apple
Distribution sertifikasını ve provisioning profillerini Xcode kendisi
oluşturur. Elle üretilen profiller entitlements ile uyumsuz kalıp
"Provisioning profile doesn't include the aps-environment entitlement"
hatasına yol açıyor.

---

## 6. Google Cloud / Firebase tarafındaki anahtarlar

Bunların hepsi **zaten üretilmiş durumda**; yapılacak iş yenisini almak
değil, doğru API'nin açık ve kısıtlamaların yerinde olduğunu doğrulamak.

Cloud projesi `eventapp-604a5` (proje numarası `738082064551`) altında beş
API anahtarı var. Konsol listesinde hangisinin hangisi olduğunu karıştırmak
kolay, çünkü Firebase onları "iOS key (auto created by Firebase)" gibi
adlarla üretiyor:

| Anahtarın başı | Ne için | Nerede duruyor |
|---|---|---|
| `AIzaSyD1jl9…` | **Maps SDK for iOS** | `ios/Flutter/Maps.xcconfig` |
| `AIzaSyCC3Of…` | Maps SDK for Android | `android/local.properties` |
| `AIzaSyBL70q…` | Firebase iOS (Auth/Firestore/Storage) | `lib/firebase_options.dart` |
| `AIzaSyD3ql3…` | Firebase Android | `lib/firebase_options.dart` |
| `AIzaSyAtuvg…` | Firebase Web | `lib/firebase_options.dart` |

Çalışma sayfaları:
- Etkin API'ler: <https://console.cloud.google.com/apis/dashboard?project=eventapp-604a5>
- Anahtarlar: <https://console.cloud.google.com/apis/credentials?project=eventapp-604a5>
- Faturalandırma: <https://console.cloud.google.com/billing/linkedaccount?project=eventapp-604a5>

> **Firebase anahtarlarını fazla kısıtlamayın.** Firebase istemci
> anahtarları sır değildir — güvenlik Firestore/Storage kurallarından gelir,
> anahtarın gizliliğinden değil. Asıl risk, **faturalandırılan** Maps
> API'lerinin başkası tarafından çağrılması. Dolayısıyla öncelik sırası:
> önce Maps anahtarlarını kendi platformlarına kilitleyin, sonra Firebase
> anahtarlarının Maps API'lerini çağıramadığından emin olun. Firebase
> anahtarına uygulama kısıtlaması eklerseniz **ekledikten sonra telefon
> doğrulamasını gerçek cihazda test edin**: reCAPTCHA yedeği web
> görünümünden çağrı yaptığı için iOS uygulama kısıtlamasına takılabiliyor.

### 6.1 Maps SDK for iOS anahtarı

`ios/Flutter/Maps.xcconfig` içinde duruyor ve Android anahtarından farklı
(ayrı anahtar kullanmak doğrusu: her biri kendi platformuna kilitlenebiliyor).

⚠️ Bu dosya `ios/.gitignore` içinde. Mac'e depo üzerinden geçerken dosya
gelmez; `Maps.xcconfig.example` kopyalanıp anahtar elle yapıştırılmalı.
Anahtar yoksa derleme yine başarılı olur, harita boş gri kalır.

Doğrulanacaklar:

1. **Maps SDK for iOS etkin mi** —
   <https://console.cloud.google.com/apis/library/maps-ios-backend.googleapis.com?project=eventapp-604a5>
   Sayfada "Manage" yazıyorsa açık, "Enable" yazıyorsa kapalı ve açılmalı.
   Android SDK'sı (`maps-android-backend`) **ayrı bir API**'dir; birinin
   açık olması diğerini açmaz. iOS haritasının boş gri çıkmasının en sık
   sebebi budur.
2. **Anahtar kısıtlaması** — Credentials → `AIzaSyD1jl9…`
   - *Application restrictions* → **iOS apps** → bundle ID
     `app.regipass.mobile`
   - *API restrictions* → **Restrict key** → yalnızca *Maps SDK for iOS*
3. **Faturalandırma** hesabı projeye bağlı. Bağlı değilse Maps SDK isteklerine
   `REQUEST_DENIED` döner ve harita boş kalır.
4. Harita SKU'sunun güncel ücretsiz kotasını teyit edin. `pubspec.yaml`'daki
   "mobilde ücretsiz ve sınırsız" notu Google'ın 2025 fiyatlandırma
   değişikliğinden önce yazıldı; güncel durumu
   <https://mapsplatform.google.com/pricing/> üzerinden doğrulayın.

### 6.2 Firebase iOS API anahtarı

`lib/firebase_options.dart` → `ios.apiKey` (`AIzaSyBL70q…`). `flutterfire
configure` üretti. İstemci paketinde açıkta durması normaldir — güvenliği
Firestore/Storage kurallarından ve anahtar kısıtlamasından gelir.

Cloud Console → Credentials → bu anahtar → *Application restrictions* →
**iOS apps** → `app.regipass.mobile`. *API restrictions* açılırsa şunlar
seçili kalmalı: Identity Toolkit, Token Service, Cloud Firestore, Cloud
Storage, Firebase Installations, Firebase Remote Config, FCM.

### 6.3 iOS OAuth istemcisi

`lib/firebase_options.dart` → `ios.iosClientId`. Aynı değer iki yerde daha
kullanılıyor ve **üçü de birbirini tutmak zorunda**:

- `Info.plist` → `GIDClientID`
- `Info.plist` → `CFBundleURLTypes` → şema, kimliğin ters çevrilmiş hâli:
  `com.googleusercontent.apps.738082064551-8ar660fj2b8j8sukqbhhkvfn3hhv62ts`

iOS istemci kimliği değişirse üçü birden güncellenmeli.

`GIDServerClientID` ise **web** istemcisidir (`…-5h5e3jab…`), Android
tarafındaki `AuthRepository._kServerClientId` ile aynı değer. Kafa
karıştırıcı ama doğrusu bu: Firebase'in kabul edeceği `idToken`, kimliği
doğrulayan tarafın (Firebase'in) istemcisi için üretilir.

### 6.4 GoogleService-Info.plist — isteğe bağlı

Projede yok ve **gerekmiyor**: Firebase `lib/firebase_options.dart` ile
başlatılıyor, Google girişi de istemci kimliğini `Info.plist`'ten okuyor.

Yine de eklemek isterseniz (Firebase Console → Proje ayarları → iOS
uygulaması → indir) `ios/Runner/` altına koyup Xcode'da Runner hedefine
ekleyin. Bu durumda içindeki `CLIENT_ID`, `Info.plist`'teki `GIDClientID`
ile **aynı olmalı** — farklı olurlarsa eklenti plist'i tercih eder ve giriş
sessizce Firebase'in tanımadığı bir jeton üretir.

---

## 7. Mac'te ilk derleme

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --debug
```

Sonra Xcode'da `ios/Runner.xcworkspace` açıp gerçek bir cihaza gönderin.
Simülatörde şunlar çalışmaz, cihaz şart: kamera (QR okutma), konum,
push tabanlı telefon doğrulaması, Apple ile giriş.

Beklenen ilk hata ve çözümü:

| Hata | Sebep |
|---|---|
| `The platform of the target 'Runner' (iOS 12.0) is not compatible with firebase_core` | `Podfile`'daki `platform :ios, '15.0'` satırı yorumlanmış |
| `Provisioning profile doesn't include the aps-environment entitlement` | App ID'de Push Notifications kapalı; §4.4 |
| `AuthorizationError error 1000` (Apple girişi) | Sign in with Apple yeteneği yok ya da profil eski |
| Google girişi seçiciyi açıyor ama geri dönmüyor | `CFBundleURLTypes` şeması yanlış/eksik |
| SMS isterken reCAPTCHA sayfası açılıyor | APNs anahtarı Firebase'e yüklenmemiş; §5.1 |
| `GMSServices.provideAPIKey` uyarısı, harita gri | `Maps.xcconfig` kopyalanmamış; §6.1 |

---

## 8. Yayın öncesi kontrol listesi

- [ ] `ios/Runner.xcodeproj` release yapılandırmasında Team ve otomatik imza
      seçili
- [ ] APNs anahtarı Firebase'e yüklendi ve gerçek cihazda SMS akışı
      reCAPTCHA'sız çalışıyor
- [ ] Apple ile giriş gerçek cihazda çalışıyor
- [ ] Google ile giriş gerçek cihazda çalışıyor
- [ ] Harita ve konum seçici çalışıyor
- [ ] **iPad'de** katılımcı listesi dışa aktarma çalışıyor (paylaşım balonu;
      `share_plus` konum dikdörtgeni olmadan iPad'de çökerdi)
- [ ] App Store Connect'te uygulama kaydı açıldı, App Privacy (veri toplama)
      formu dolduruldu: ad, e-posta, telefon, fotoğraf, konum, kullanıcı kimliği
- [ ] App Review'a demo hesap bilgisi verildi — uygulama tamamen giriş
      arkasında, hesapsız inceleme mümkün değil. Öğrenci **ve** kulüp için
      ayrı hesap verin, telefon doğrulaması için Firebase Console'da bir test
      numarası tanımlayın
- [ ] `ITSAppUsesNonExemptEncryption` sayesinde her yüklemede ihracat sorusu
      çıkmıyor (doğrulandı)
- [ ] **Uygulama içinden hesap silme** eklendi — aşağıya bakın

> ### ⚠️ Açık engel: uygulama içinden hesap silme
>
> App Store Review Guideline **5.1.1(v)**: hesap oluşturmaya izin veren
> uygulama, hesabın **uygulama içinden silinmesine** de izin vermek zorunda.
> Şu an böyle bir ekran yok — `AccountCleanupRepository` yalnızca telefonu
> doğrulanmamış kayıtları temizliyor, kullanıcıya açık bir "hesabımı sil"
> yolu sunmuyor. Bu madde eksikken uygulama **reddedilir**.
>
> Gereken: `student_account_screen.dart` ve `club_account_screen.dart`
> içinde onay isteyen bir silme akışı; Auth hesabı + Firestore dokümanları +
> Storage dosyaları + `phone_directory` kaydı birlikte temizlenmeli.
> Silme işlemi son girişten uzun süre geçmişse Firebase
> `requires-recent-login` döndürür, akışın yeniden giriş adımı içermesi
> gerekir.
