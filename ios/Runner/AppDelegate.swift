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
    // koda yazılmaz (bkz. Maps.xcconfig.example). Tanımlı değilse harita boş
    // görünür ama uygulama açılmaya devam eder.
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.isEmpty {
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
