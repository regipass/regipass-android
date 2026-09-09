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

Mobil proje Android paket adını `app.regipass.mobile` kullanır. Android App
Link doğrulaması için web sunucusunda şu dosya HTTPS ile, yönlendirme olmadan
yayınlanmalıdır:

```text
/.well-known/assetlinks.json
```

Dosyadaki `sha256_cert_fingerprints` değeri **Play Console > App integrity >
App signing key certificate** ekranındaki SHA-256 olmalıdır. Yerel debug veya
`google-services.json` içindeki SHA-1 bu değer değildir.

8 Eylül 2026'da canlı alan adı kontrol edildi: dosya `application/json` ile
200 dönüyor, paket adı doğru ve aşağıdaki iki yayın imzası yer alıyor. Yeni
Play imzasına geçilirse bu iki değer silinmeden yenisi eklenmelidir.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "app.regipass.mobile",
      "sha256_cert_fingerprints": [
        "7D:AC:A7:72:66:DA:72:DB:63:B0:2B:84:B4:18:CF:CF:0C:FC:77:1C:C3:7A:6B:30:D6:47:AB:08:E7:F8:3B:57",
        "3B:5C:16:48:4F:0C:85:28:E1:25:A7:F8:2C:4E:EC:B4:04:9A:39:48:B5:8F:6E:1C:1F:32:40:9B:6D:00:70:A8"
      ]
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
