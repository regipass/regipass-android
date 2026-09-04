import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Anahtar Info.plist üzerinden Flutter/Maps.xcconfig'ten gelir; kaynak
    // koda yazılmaz (bkz. Maps.xcconfig.example).
    //
    // DİKKAT: provideAPIKey HİÇ çağrılmazsa Maps SDK ilk GMSMapView
    // kurulduğu anda NSException atar ve uygulama ÇÖKER — harita boş
    // görünmez, ekran hiç açılmaz. Maps.xcconfig .gitignore'da olduğu için
    // anahtarın bulunmadığı bir makinede (başka bir Mac, CI) üretilen IPA
    // tam olarak bu davranışı gösterir. Anahtar yoksa bilinçli olarak
    // geçersiz bir yer tutucu veriyoruz: SDK yetkilendirme hatasını
    // günlüğe yazar, harita gri kalır, ama uygulama ayakta durur.
    let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    if key.isEmpty || key.hasPrefix("$(") {
      NSLog(
        "[Regipass] MAPS_API_KEY tanımsız — ios/Flutter/Maps.xcconfig eksik. "
          + "Harita ekranı açılır ama boş görünür."
      )
      GMSServices.provideAPIKey("MISSING_MAPS_API_KEY")
    } else {
      GMSServices.provideAPIKey(key)
    }

    // flutter_local_notifications'ın bildirim merkezine bağlanması. Bu satır
    // olmadan uygulama ÖN PLANDAYKEN gelen bildirim iOS tarafından yutulur
    // (banner da ses de çıkmaz) ve bildirime dokunma geri çağrısı hiç
    // tetiklenmez. FlutterAppDelegate bu protokolü zaten uyguluyor.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
