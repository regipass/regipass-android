/// Cihazın sistem çubuklarının (durum çubuğu + gezinme çubuğu) ne zaman
/// görüneceğini belirleyen kurallar.
///
/// Kural tek cümle: **oturum açılmadan önce her iki çubuk da görünür, oturum
/// açıldığı anda cihazın alt gezinme çubuğu (geri / ana ekran / son
/// kullanılanlar) gizlenir.** Giriş öncesi ekranlarda kullanıcının cihazın
/// kendi geri düğmesine ihtiyacı var; panelin içinde ise uygulamanın kendi
/// alt çubuğu bu işi devralıyor ve iki çubuğun üst üste gelmesi hem yer
/// harcıyor hem de görsel olarak karışıyor.
///
/// PLATFORM NOTU: Android, API 36'yı hedefleyen uygulamalarda çubuk gizleme
/// isteklerini yok sayar. Bu yüzden `android/app/build.gradle.kts` içinde
/// `targetSdk = 35` sabitlendi — aksi hâlde buradaki kod sessizce etkisiz
/// kalıyordu.
library;

import 'package:flutter/services.dart';

/// Gezinme çubuğu gizlensin mi?
///
/// Oturum çözülmeden (açılış perdesi sürerken) karar verilmez: o sırada
/// çubuğu gizleyip hemen geri getirmek titremeye yol açardı.
bool shouldHideSystemNavigationBar({
  required bool isSignedIn,
  required bool isLoading,
}) => true;

/// Gizleme kararının karşılığı olan sistem katmanı listesi.
///
/// `SystemUiOverlay.top` listede kaldığı için durum çubuğu (saat, pil,
/// bildirimler) her durumda görünür; yalnızca alttaki çubuk kaldırılır.
List<SystemUiOverlay> systemOverlaysFor({required bool hideNavigationBar}) =>
    hideNavigationBar ? const <SystemUiOverlay>[] : SystemUiOverlay.values;

/// Kararı cihaza uygular.
Future<void> applySystemNavigationBarVisibility({
  required bool hideNavigationBar,
}) => hideNavigationBar
    ? SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
    : SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

/// Platformun çubukları kendiliğinden geri getirdiği durumlarda (klavye
/// kapanması, uygulamaya geri dönüş, kenardan yukarı kaydırma) son ayarı
/// yeniden uygular.
Future<void> restoreSystemNavigationBarVisibility() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
