# Telefon doğrulamada reCAPTCHA ekranını kaldırmak

**Belirti:** SMS kodu isterken uygulama kullanıcıyı bir anlığına
`*.firebaseapp.com` adresindeki "robot değilim" sayfasına atıyor.

## Neden oluyor

Firebase, SMS göndermeden önce isteğin gerçek bir cihazdan geldiğini
doğrulamak zorunda. Android'de bunun iki yolu var:

1. **Play Integrity API** — sessiz. Kullanıcı hiçbir şey görmez.
2. **reCAPTCHA** — WebView/tarayıcı açar. Yalnızca 1. yol başarısız olursa
   devreye giren *son çare*.

Yani reCAPTCHA sayfasını görüyorsan Play Integrity doğrulaması başarısız
oluyor. Bunu istemci kodundan kapatmanın bir yolu yok: kapatılabilseydi
herkes SMS kotasını sömürebilirdi.

## Kodda yapılan

`lib/main.dart` içindeki `_initFirebase()`:

```dart
await FirebaseAuth.instance.setSettings(
  appVerificationDisabledForTesting: false,
  forceRecaptchaFlow: false,
);
```

`forceRecaptchaFlow: false`, "önce sessiz yolu dene, reCAPTCHA'yı zorlama"
demektir (Android'de bazı SDK sürümleri/hata ayıklama derlemeleri bu akışı
zorlayabiliyor). **Tek başına yetmez** — Play Integrity çalışmıyorsa Firebase
yine reCAPTCHA'ya düşer.

## Konsol tarafında yapılması gerekenler (asıl çözüm)

1. **Play Integrity API'yi etkinleştir.**
   Google Cloud Console > `eventapp-604a5` projesi > "APIs & Services" >
   "Play Integrity API" > Enable.
2. **SHA sertifika parmak izlerini ekle.**
   Firebase Console > Proje ayarları > `app.regipass.mobile` > "SHA sertifika
   parmak izleri". **Hem SHA-1 hem SHA-256** gerekir; SHA-256 yoksa Play
   Integrity çalışmaz.

   > `android/app/google-services.json` dosyasına bakarak SHA-256'nın kayıtlı
   > olup olmadığı **anlaşılamaz**: bu dosyadaki `certificate_hash` alanı
   > yalnızca OAuth istemcisinin SHA-1'ini taşır, SHA-256 parmak izleri
   > dosyaya hiç yazılmaz. Kontrol yalnızca konsoldaki listeden yapılır.

   ```bash
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
   ```

   Yayın imzası için (şu an `build.gradle.kts` release'i de debug anahtarıyla
   imzalıyor) gerçek keystore'un SHA-1/SHA-256'sı da eklenmeli.
3. Parmak izlerini ekledikten sonra **`google-services.json`'ı yeniden indir**
   ve `android/app/` altına koy, ardından uygulamayı temiz derle
   (`flutter clean && flutter run`).
4. Firebase Console > Authentication > Settings > "App verification" kısmında
   Play Integrity'nin etkin göründüğünü doğrula.

## Kalan durumlar

Bunlar tamamlandıktan sonra reCAPTCHA yalnızca şu hâllerde çıkar:

- Google Play Services'ı olmayan cihaz/emülatör (ör. saf AOSP imajı).
- Play Integrity kotası dolmuşsa (günlük ücretsiz kota aşımı).
- Yan yükleme yapılmış, imzası kayıtlı olmayan bir APK.

Emülatörde test ederken Play Store'lu (Google APIs) bir imaj seçmek ya da
Firebase Console > Authentication > Phone > "Test için telefon numaraları"
listesine sabit bir numara + kod eklemek reCAPTCHA'yı tamamen atlar.

## Geliştirirken tarayıcıyı hiç görmemek

Test numarası tanımladıktan sonra uygulamayı şu şekilde çalıştır:

```bash
flutter run --dart-define=PHONE_TEST_MODE=true
```

Bu bayrak `lib/main.dart` içinde `appVerificationDisabledForTesting: true`
yapar: cihaz doğrulaması tamamen atlanır, reCAPTCHA sayfası **hiç açılmaz** ve
gerçek SMS de gitmez — konsolda tanımlı sabit kod kullanılır. Bayrak
`kReleaseMode` ile ayrıca kısıtlıdır, yayın yapısında yanlışlıkla açık kalamaz.

## Tarayıcıya düşülürse ne oluyor

reCAPTCHA sayfası açıldığında kullanıcı geri tuşuna basar ya da sekmeyi
kapatırsa Firebase `web-context-canceled` döndürüyor; iki doğrulama üst üste
başlatılırsa `web-context-already-presented` geliyor. Bu iki kod eskiden
"Bir hata oluştu. Lütfen tekrar deneyin." diye gösteriliyordu — artık
`lib/features/auth/phone_auth_errors.dart` içinde ne olduğunu ve ne yapılması
gerektiğini söyleyen ayrı metinlere bağlı.
