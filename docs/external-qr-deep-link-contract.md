# Dış kamera QR: web–Android–iOS ortak sözleşmesi

Bu belge, web ve mobil tarafının aynı dış QR bağlantısını işlemesi için
uygulanan sözleşmedir. Mevcut `EVAPPQR1:` QR algoritması değiştirilmez.

## Tek QR içeriği

Kulübün ürettiği kapı ve oturum QR'ı şu HTTPS adresini içerir:

```text
https://eventapp-604a5.web.app/qr.html?t=EVAPPQR1:<base64url-json>
```

`t` içindeki payload mevcut sözleşmedeki `event-entry` veya
`session-checkin` değeridir. `eventId` zorunludur; `session-checkin` için
`session` da zorunludur. Görevlinin taradığı kişisel `event-checkin` bileti
ham token olarak kalır; kişisel öğrenci kimliği dış QR URL'sine taşınmaz.

## Beklenen davranış

1. Telefonun kamerası bağlantıyı açar.
2. Android/iOS'ta Regipass kurulu ve alan adı doğrulanmışsa uygulama
   `/qr.html?t=...` rotasına açılır; değilse webdeki aynı `qr.html` çalışır.
3. Oturum yoksa web/mobil etkinlik detay penceresini gösterir. Kullanıcı giriş
   veya kayıt akışını bitirdiğinde `continue` ile aynı QR niyetine döner.
4. Öğrenci zaten etkinliğe kayıtlıysa etkinlik penceresi açılır ve mevcut
   kapı/oturum kontrolü token üzerinden otomatik yürür. Kamera tekrar QR
   okumaz; konum, kapı açıklığı, oturum dilimi ve Firestore kuralları korunur.
5. Öğrenci kayıtlı değilse detay penceresindeki normal kayıt akışı kullanılır;
   kayıt başarılı olunca aynı dış QR işlemi otomatik sürer.

Webdeki `qr.html`, token'ı bu kurallarla doğrulamalı, geçersiz QR'ı işleme
almamalı ve uygulama yokken doğrudan aynı etkinlik detay/popup akışını
göstermelidir.

## Web yayını için ilişki dosyaları

Mobil proje Android paket adını `app.regipassapp.mobile` kullanır (Google Play'deki uygulama). Android App
Link doğrulaması için web sunucusunda şu dosya HTTPS ile, yönlendirme olmadan
yayınlanmalıdır:

```text
/.well-known/assetlinks.json
```

Dosyadaki `sha256_cert_fingerprints` değeri **Play Console > App integrity >
App signing key certificate** ekranındaki SHA-256 olmalıdır. Yerel debug veya
`google-services.json` içindeki SHA-1 bu değer değildir.

23 Eylül 2026 (İP-0b): Play'deki paket `app.regipassapp.mobile` olduğu için
dosyaya bu paket için yeni bir kayıt eklendi. Kayıtta Play Console'daki imzalar
(uygulama imzalama anahtarı, upload anahtarı) ve yerel release/debug imzaları
var. Eski `app.regipass.mobile` kaydı zarar vermediği için ikinci sırada
duruyor. Dosya web reposunda `scripts/generate-app-link-associations.mjs` ile
üretilir; yeni imza eklenirse eskiler silinmeden eklenmelidir.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "app.regipassapp.mobile",
      "sha256_cert_fingerprints": ["<Play uygulama imzalama SHA-256>", "<upload SHA-256>", "..."]
    }
  }
]
```

iOS Universal Link için aynı alan adında aşağıdaki dosya HTTPS ile,
yönlendirme olmadan yayınlanmalıdır:

```text
/.well-known/apple-app-site-association
```

8 Eylül 2026'da canlı dosyada Apple Team ID `64G83H5LB2`, bundle id ise
`app.regipass.mobile` olarak doğrulandı. Mevcut yayın, Firebase Auth yollarını
hariç tutup geri kalan yolları kabul ediyor; mobil uygulama yalnız `/qr.html`
rotasını işler.

```json
{
  "applinks": {
    "details": [
      {
        "appID": "64G83H5LB2.app.regipass.mobile",
        "paths": ["NOT /__/auth/action/", "NOT /__/auth/handler/", "NOT /_/*", "/*"]
      }
    ]
  }
}
```

Her iki dosya `application/json` ile sunulmalı ve Firebase Hosting/web
rewrite kuralı bu dosyaları Flutter/SPA giriş sayfasına yönlendirmemelidir.

## Cihaz doğrulama

Yayın sonrası, gerçek Play imzalı Android yapısında ve TestFlight iOS
yapısında aynı QR ile aşağıdakiler denenmelidir:

- oturumu açık ve kaydı mevcut öğrenci;
- oturumu kapalı mevcut hesap;
- yeni hesap: kayıt, profil, telefon doğrulaması sonrası dönüş;
- kaydı olmayan öğrenci;
- kapısı kapalı / eski oturum token'ı / konum dışında olan öğrenci;
- uygulamanın hiç kurulu olmadığı cihazda web yedeği.

Android doğrulaması için `adb shell am start -W -a android.intent.action.VIEW
-c android.intent.category.BROWSABLE -d '<QR_URL>'`, iOS Simulator için
`xcrun simctl openurl booted '<QR_URL>'` kullanılabilir. Fiziksel iOS
Universal Link testi için bağlantıyı Notlar veya Mesajlar içinden açmak
gerekir; Apple ilişki dosyasını önbelleğe alabileceğinden yayından sonra kısa
bir gecikme yaşanabilir.
