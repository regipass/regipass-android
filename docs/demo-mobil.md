# Demo mobil — "Regipass Demo" (ayrı uygulama)

demo.regipass.com'un mobil karşılığı. Gerçek uygulamadan ayrı kurulur (paket
kimliği `com.regipassbeta.mobile`, ad "Regipass Demo", ikon "DEMO" şeritli) ve
**regipass-demos** Firebase projesine bağlanır; canlı veriye dokunmaz.

## Nasıl açılır
- Kod: `lib/app/demo_mode.dart`. Yalnız `--dart-define=REGIPASS_DEMO=true` ile
  derlenince açılır; mağaza sürümü bu ayar olmadan derlenir → demo kapalı.
- Giriş ekranında "Öğrenci olarak dene / Kulüp olarak dene" (sunucudaki
  `demoSignIn` hazır hesaba jeton verir). Kayıt, Google/Apple, şifremi unuttum gizli.
- `--dart-define=REGIPASS_SHOTS=true` (yalnız debug): ekran görüntüsü kipi —
  tüm QR'lar https://regipass.com, kapı ekranı örnek başarılı okutma sahnesi
  (simülatörde kamera yok). Hiçbir şey yazılmaz.

## Komutlar (Mac, Regipass-iOS kökünde)
    bash scripts/demo-ios.sh sim       # simülatör + ekran görüntüsü kipi
    bash scripts/demo-ios.sh iphone    # kabloyla bağlı iPhone'a kalıcı kurulum

Betik geçici bir kopya (`../_regipass-demo-build`, git worktree) açar; paket
kimliği/ad/ikon yalnız orada değişir. İkon: `scripts/demo-ios/AppIcon.appiconset`.
İmza: ekip 64G83H5LB2, otomatik imzalama (Xcode'da Apple hesabı açık olmalı).
iPhone'da ilk kurulumda: Ayarlar > Gizlilik ve Güvenlik > Geliştirici Modu açık.

## Firebase
regipass-demos → iOS uygulaması "Regipass Demo" (com.regipassbeta.mobile,
1:216973453535:ios:e7c8cc14a1b44ab1d5216a). Android demo kayıtlı değil.
Push bildirimleri demoda yapılandırılmadı (APNs anahtarı yok) — beklenen.
