# Firebase projesinin regipass.product@gmail.com hesabına devri

Amaç: `eventapp-604a5` projesinin sahibi `eyyupahmet24@gmail.com` yerine
`regipass.product@gmail.com` olsun; proje adı `Regipass` görünsün.

## Önce bilinmesi gerekenler

**Proje ID'si değiştirilemez.** Firebase/GCP'de proje ID'si oluşturulurken
sabitlenir. `eventapp-604a5` kalıcıdır. Değiştirilebilen tek şey *görünen
addır* (`Eventapp` → `Regipass`).

Bunun kod tarafındaki sonucu: aşağıdaki adresler `eventapp-604a5` olarak
kalmaya devam eder ve **değiştirilmemelidir**.

| Yer | Değer |
| --- | --- |
| `lib/domain/checkin_qr.dart:32` | `https://eventapp-604a5.web.app/` — basılı QR kodları bu adrese bakar |
| `lib/firebase_options.dart` | `authDomain: eventapp-604a5.firebaseapp.com` |
| `lib/firebase_options.dart` | `storageBucket: eventapp-604a5.firebasestorage.app` |
| `lib/firebase_options.dart` | `databaseURL: eventapp-604a5-default-rtdb.firebaseio.com` |
| `android/app/google-services.json` | `project_id`, `firebase_url`, `storage_bucket` |
| `.firebaserc`, `firebase.json` | `eventapp-604a5` |

**"Devretme" = IAM'de Owner değiştirmek.** Firebase'de projeyi bir hesaptan
diğerine taşıyan ayrı bir işlem yoktur; yeni hesabı Owner olarak eklemek
devretmenin ta kendisidir. Proje, veriler, kullanıcılar, apiKey'ler, appId'ler,
OAuth istemcileri, SHA parmak izleri ve APNs anahtarı **hiç değişmez**.

**Kod tarafında değişecek hiçbir şey yok.** Depoda `eyyupahmet24@gmail.com`
geçen tek bir satır bile yok (`grep` ile doğrulandı); tüm config değerleri
hesaba değil projeye bağlıdır. Devirden sonra `flutterfire configure`
çalıştırmaya da gerek yoktur — çalıştırılırsa aynı değerleri üretir.

## Konsolda yapılacaklar

Bu adımlar Google hesabına giriş gerektirdiği için elle yapılmalıdır.

### 1. Yeni hesabı Owner olarak ekle

`eyyupahmet24@gmail.com` ile giriş yapılmış tarayıcıda:

<https://console.firebase.google.com/project/eventapp-604a5/settings/iam>

**Üye ekle** → `regipass.product@gmail.com` → rol **Owner (Sahip)** → Ekle.

### 2. Daveti kabul et

`regipass.product@gmail.com` gelen kutusuna bir davet e-postası düşer.
Owner rolü daima bu davet akışından geçer; davet kabul edilmeden devir
tamamlanmaz. (`firebase` CLI'ın IAM komutu yoktur; bu adım konsoldan veya
`gcloud projects add-iam-policy-binding` ile yapılır.)

### 3. Proje adını değiştir

<https://console.firebase.google.com/project/eventapp-604a5/settings/general>

**Proje adı** alanını `Regipass` yap. (Proje ID'si alanı gri ve
değiştirilemezdir — beklenen davranış.)

### 4. Web uygulamasının takma adını değiştir

Proje adından **ayrı** bir alandır; 3. adım bunu değiştirmez.

Aynı sayfa → **Uygulamalarınız** → web uygulaması → düzenle (kalem) →
takma ad `Eventapp` → `Regipass`.

`firebase apps:list` çıktısı bunu doğruluyor: Android ve iOS uygulamaları
zaten `regipass`, sadece web tarafı `Eventapp` kalmış. `firebase-tools`'ta
uygulama yeniden adlandırma komutu yoktur, tek yol konsoldur.

### 5. Faturalandırmayı kontrol et — atlanmamalı

Proje **Blaze planındadır** — doğrulandı:

```
$ firebase functions:list --project eventapp-604a5
checkPasswordResetPhone | v2 | callable | europe-west1 | 256 | nodejs22
```

Cloud Functions Gen2 yalnızca Blaze'de çalışır ve bu fonksiyon canlıdadır
(şifre sıfırlamadaki telefon doğrulaması buna bağlı).

Faturalandırma hesabı projeden **ayrı bir kaynaktır ve proje devriyle
taşınmaz.** `eyyupahmet24@gmail.com` faturalandırma hesabını kaparsa
`checkPasswordResetPhone` durur.

**Bu artık şifre sıfırlamayı etkilemiyor.** Fonksiyon canlıda duruyor ama
mobil uygulama onu artık çağırmıyor: SMS öncesi sunucu kontrolü kaldırıldı,
çünkü tek başına akışın önünü tıkayabiliyordu (hesabın numarası Firebase
Auth'a bağlı değilse "eşleşmiyor" diyor, çağrı hata verirse SMS aşamasına
hiç geçilmiyordu). Numaranın hesaba ait olduğu artık yalnızca kod
doğrulandıktan sonra, `forgot_password_screen.dart#_applyCredential` içinde
e-posta karşılaştırmasıyla denetleniyor — asıl güvenlik sınırı da oydu. Web
tarafı bu fonksiyonu zaten hiç çağırmıyordu (`js/pages/password-reset.js`
doğrudan `signInWithPhoneNumber` kullanıyor).

Yani her iki istemcinin şifre sıfırlaması da faturalandırmadan bağımsız.
Fonksiyon şu an hiçbir yerden çağrılmıyor; silinebilir (`firebase functions:delete
checkPasswordResetPhone --region europe-west1`) ya da olduğu yerde
bırakılabilir — çağrılmadığı sürece maliyeti yok.

<https://console.cloud.google.com/billing/linkedaccount?project=eventapp-604a5>

İki seçenekten biri yapılmalı:

- `regipass.product@gmail.com` kendi faturalandırma hesabını oluşturup
  projeyi ona bağlar (temiz çözüm), **veya**
- mevcut faturalandırma hesabında `regipass.product@gmail.com`
  *Billing Account Administrator* yapılır.

### 6. OAuth izin ekranı

<https://console.cloud.google.com/apis/credentials/consent?project=eventapp-604a5>

Uygulama adı `Regipass`, **User support email** ve **Developer contact
information** `regipass.product@gmail.com` yapılmalı. Yapılmazsa Google ile
Giriş ekranında kullanıcılara hâlâ eski adres gösterilir.

### 7. Google Analytics erişimi — Firebase IAM'den bağımsız

`measurementId: G-KDR4SDH4W2` bir GA4 mülküdür ve GA erişim yönetimi
Firebase IAM'den ayrıdır. Proje devrolsa bile bu adım yapılmazsa yeni
hesap analytics verisini göremez.

<https://analytics.google.com> → Yönetici → Mülk erişim yönetimi →
`regipass.product@gmail.com` ekle.

### 8. Eski hesap: DOKUNULMAYACAK

Kullanıcının kararı: `eyyupahmet24@gmail.com` **Owner olarak kalacak.**
Yedek erişim olarak duruyor, IAM'den kaldırılmıyor.

İleride kaldırılmak istenirse: yalnızca 1-2. adımlar doğrulandıktan sonra,
yani yeni hesap gerçekten Owner olduktan sonra yapılmalı. Önce kaldırılırsa
projeye erişim tamamen kaybedilir ve geri dönüşü yoktur.

## Devirden sonra: CLI hesabını değiştir

```
firebase login:add regipass.product@gmail.com
firebase login:use regipass.product@gmail.com
firebase projects:list
```

Son komut `Regipass / eventapp-604a5` satırını göstermelidir. Göstermiyorsa
davet kabul edilmemiş veya rol Owner değil demektir.

## Devir kapsamı dışındakiler

Bunlar Firebase projesine ait değildir, proje devriyle taşınmazlar:

- **Faturalandırma hesabı** (5. adım — atlanırsa Functions durur)
- **Google Analytics mülkü** (7. adım)
- Google Play Console geliştirici hesabı
- App Store Connect / Apple Developer hesabı
- Alan adı kaydı (varsa)

## Devir sonrası doğrulama (mobil)

Devir metadata değişikliği olduğu için aşağıdakilerin bozulmaması
beklenir; yine de kontrol edilmeli:

- Google ile Giriş `DEVELOPER_ERROR` vermiyor (verirse SHA parmak izleri
  veya Android OAuth istemcisi `client_type: 1` etkilenmiş demektir —
  `google-services.json` içindeki hash `b45d37bb…6cd8`)
- Telefon (SMS) doğrulaması ve reCAPTCHA çalışıyor
  (bkz. `docs/telefon-dogrulama-recaptcha.md`)
- Şifre sıfırlamada doğrulama SMS'i geliyor (bu akış artık Cloud Functions'a
  bağlı değil, doğrudan Firebase Phone Auth kullanıyor)
- iOS push / APNs anahtarı (bkz. `docs/ios-kurulum.md`)

`flutterfire configure` **yeniden çalıştırılmamalı** — gereksizdir ve
`lib/firebase_options.dart`'ı ezer.

## Neden sıfırdan yeni proje kurulmadı

Devir mümkün olduğu için gerekmedi. Yeni proje kurulsaydı Firestore
export/import, Auth kullanıcılarının taşınması, Storage kopyalanması,
Functions'ın yeniden deploy'u, yeni OAuth istemcileri, yeni SHA parmak
izleri, yeni APNs anahtarı ve hem web hem mobil taraftaki tüm config
dosyalarının değişmesi gerekirdi — ayrıca basılı QR kodlarındaki
`eventapp-604a5.web.app` adresi geçersiz olurdu.
