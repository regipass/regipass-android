# Şifre sıfırlama incelemesi — 7 Eylül 2026

İncelenen proje: `C:\Users\5sana\StudioProjects\Regipass`.
Firebase projesi: `eventapp-604a5`.
Kullanıcının bildirdiği sürüm: Android / Play Store. ADB paket sorgusu
`versionName=1.0.4`, `versionCode=6`, `installerPackageName=com.android.vending`
değerlerini doğruladı. Telefonda yüklü derlemenin kaynak koduyla birebir
eşleşmesi doğrulanamadı; aşağıdaki istemci bulguları incelenen çalışma ağacına aittir.

## Numaranın görünmemesi

Ekran telefon numarasını doğrudan kullanıcı profilinden okumuyordu.
E-posta normalize edilip SHA-256 anahtarıyla `phone_hints` belgesi okunuyor,
belge yoksa veya erişim başarısızsa boş ipucu dönüyordu. Ekran da boş ipucunu
gizliyordu. Bu nedenle telefonun Auth hesabında doğrulanmış olması, maskenin
ekranda görüneceğini garanti etmiyordu.

Canlı Firestore kuralı okunarak şu uyumsuzluk doğrulandı:

- Uygulamanın ilk yazması: `maskedPhone`, `roles`, `updatedAt`.
- Uygulamanın yedek yazması: `maskedPhone`, `updatedAt`.
- Canlı kural: `phoneHash` zorunlu; `roles` izin verilen alanlarda yok.

Dolayısıyla uygulamanın iki yazma biçimi de kurala aykırıydı. Eski canlı kural
kimliği: `c046f3b0-dbaf-4d99-86e7-8cb354d57cba`.

Kural düzeltmesi mobilin iki yazma biçimini kabul eder. Eski web istemcisinin
64 karakterlik `phoneHash` alanı uyumluluk için isteğe bağlı kabul edilmeye
devam eder. Oturumsuz yazma ve koleksiyon listeleme kapalıdır. Tam numara
alanı eklenmedi; mobil istemci tam numaranın hash'ini yayımlamaz.

Eksik eski belgeler için `getPasswordResetHint` callable fonksiyonu e-postanın
Firebase Auth hesabını sunucuda bulup sadece maskeli telefon döndürür.
Profildeki `phoneVerified` bayrağına dayanarak kurtarma izni verilmez.
Türkiye numaraları `+90 XXX XXX XX 67` biçimindedir. Gerçek numara, UID ve
e-posta yanıta eklenmez. İpucu sorguları ayrı hız sayacını kullanır.

İstemci önce Firestore'u en fazla 3 saniye, gerekirse Auth ipucu servisini en
fazla 8 saniye bekler. Telefon alanı bu sırada kullanılabilir. İpucunun geç
gelmesi devam eden SMS aşamasını yeniden telefon girişine döndürmez.

İlgili dosyalar: `lib/services/phone_hint_repository.dart`,
`lib/app/app.dart`, `functions/passwordResetHint.js`, `functions/index.js`,
`tool/loadtest/firestore.rules`, `tool/loadtest/rules-env/firestore.rules`.

## İlk hata ve ardından yüklenmenin takılması

Çalışma ağacında şu durumlar bulundu ve düzeltildi:

1. Önceki SMS isteğinin callback'i, yeni isteğin ortak zamanlayıcısını iptal
   edebiliyordu. Her denemeye ayrı kimlik verildi. İptal edilmiş veya süresi
   dolmuş bir isteğin yanıtı yeni denemeye dokunamıyor.
2. Otomatik doğrulama başladığında SMS zamanlayıcısı kapanıyordu; ardından
   yapılan giriş işleminin süre sınırı yoktu. Kod doğrulama artık ayrı bir
   aşama ve 30 saniye sınırıyla çalışıyor. SMS isteğinin sınırı 75 saniye.
3. `codeAutoRetrievalTimeout` yalnızca doğrulama ID'sini saklıyordu. Geçerli
   ID varsa ve pencere açılmamışsa artık kullanıcı kodu elle girebiliyor.
   Bu olay SMS'in otomatik okunamadığını bildirir; SMS isteğinin kesin
   başarısızlık kanıtı değildir. [Firebase Flutter telefon doğrulama belgesi](https://firebase.google.com/docs/auth/flutter/phone-auth).
4. Kod penceresi ve gönder düğmesi için yinelenen işlem korumaları eklendi.
   Kod otomatik doğrulanırken aynı kod elle tekrar uygulanamıyor. Pencere
   iptal edilince geç gelen otomatik doğrulama yok sayılıyor.
5. İptal edilen veya zaman aşımına uğrayan SMS girişinin ana uygulama
   oturumunu değiştirmemesi için her deneme ayrı bir Firebase Auth uygulama
   örneğinde yürütülüyor. Aynı Firebase projesi ve aynı kullanıcı hesabı
   kullanılır. Doğrulanan hesabın e-postası girilen e-postayla eşleşmeden yeni
   şifre alanları açılmaz. Ana oturum sadece şifre kaydedildikten sonra açılır.
6. Şifre kaydetme ve sonrasındaki girişin her birine 30 saniye sınırı eklendi.
   Şifre kaydolup otomatik giriş başarısız olursa kullanıcıya şifrenin
   kaydedildiği açıkça bildirilir.

Adım, deneme kimliği ve hata türü/kodu yapılandırılmış günlüğe yazılır.
E-posta, telefon, SMS kodu, şifre ve bunları içerebilecek ham SDK mesajı bu
yeni olaylara yazılmaz.

İlgili dosyalar: `lib/features/auth/forgot_password_screen.dart`,
`lib/services/password_reset_auth_session.dart`, `lib/state/providers.dart`,
`lib/l10n/extra_translations.dart`.

## Cihaz bulgusunun sınırı

Telefon kaydında 16:38:30'da Play Integrity isteği, 16:38:31'de yanıt ve
16:39:31'de `[SmsRetrieverHelper] Timed out waiting for SMS` görüldü.
Bu kayıt gerçek SMS'in operatöre teslim edilip edilmediğini veya
`codeSent` callback'inin uygulamada işlenip işlenmediğini göstermiyor.
Öncesindeki reCAPTCHA yapılandırma mesajı da tek başına kesin hata nedeni
olarak değerlendirilmedi.

Firebase Android uygulamasında beş SHA-1 ve beş SHA-256 kaydı canlı olarak
görüldü. Telefon bağlantısı kesildiğinden Play Store APK'sının imzasıyla
birebir karşılaştırma tamamlanamadı. Eksik SHA veya operatör engeli kesin
teşhis olarak sunulmuyor. İlgili resmi davranış:
[Firebase Android telefon doğrulaması](https://firebase.google.com/docs/auth/android/phone-auth).

## Doğrulama ve yayın

- Değiştirilen Dart dosyaları ve yeni testler: analiz temiz, `No issues found!`.
- Flutter: 44 test başarılı. Kapsam: ilk hata/ikinci deneme, geciken callback,
  eksik/geciken ipucu, otomatik ve manuel kod, yanlış e-posta, iptal/dispose,
  doğrulama/kaydetme zaman aşımı, klavye düzeni, telefon biçimi ve yönlendirme.
- Cloud Functions: 6 test başarılı. Kapsam: maskeleme, e-posta normalizasyonu,
  numarasız/devre dışı/olmayan hesap, servis hatası, hız sınırı ve geçersiz giriş.
- Yerel Firestore emülatörü: 10 kontrol başarılı. Mobil, yedek ve eski web
  yazmaları; tekil okuma; yasak listeleme/yazmalar.
- `git diff --check`: başarılı.
- Firestore kuralı canlıya alındı; canlı içerik test edilen dosyayla birebir
  karşılaştırıldı. Yeni kural kimliği: `02cd17d2-9245-46d1-86b2-d3da98498709`.
- `getPasswordResetHint` fonksiyonu `europe-west1` bölgesinde başarıyla
  oluşturuldu. Canlı HTTP kontrolünde geçersiz girdi `400 / INVALID_ARGUMENT`,
  olmayan hesap `200 / {maskedPhone: '', roles: []}` döndürdü. Kontrol
  sırasında SMS gönderilmedi ve Auth hesabı oluşturulmadı.
- Mobil değişiklikler çalışma ağacındadır. Play Store'a yeni sürüm yayımlanmadı.
- Gerçek telefonla SMS alma ve yeni şifreyle girişin uçtan uca doğrulaması
  henüz yapılmadı. Kullanıcının e-posta adresi olmadan o hesaba ait eksik
  ipucu belgesi ayrıca incelenmedi veya değiştirilmedi.

Fonksiyonun ilk yayın denemesi kaynak keşfinin 10 saniyelik sınırında kaldı.
Başlangıçta PDF motorunun da yüklenmesi kaldırıldı; sertifika kütüphaneleri
yalnızca sertifika fonksiyonu çağrılınca yüklenir. Mevcut sertifika fonksiyonu
bu işlem kapsamında yeniden yayımlanmadı.

Testleri yeniden çalıştırmak için:

```powershell
& C:\Users\5sana\Desktop\flutter\bin\flutter.bat test --no-pub test/forgot_password_flow_test.dart test/phone_hint_repository_test.dart test/forgot_password_layout_test.dart test/forgot_password_redirect_test.dart test/phone_field_test.dart test/phone_precheck_test.dart
node --test functions/passwordResetHint.test.js
firebase emulators:exec --config tool/loadtest/phone-hint.firebase.json --project demo-regipass-phone-reset --only firestore "node tool/loadtest/phone-hint-rules.test.cjs"
```

Emülatör komutu için Java'nın PATH'te olması gerekir. Yayın sırasında kökteki
`firebase.json` içinde Firestore yapılandırması bulunmadığı için canlı kuralın
anlık kopyası alındı, yalnızca `phone_hints` bloğu değiştirildi ve ayrı geçici
yapılandırmayla yayımlandı. Başka kural değişiklikleri taşınmadı.
