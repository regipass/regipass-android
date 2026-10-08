/// Uygulamanın kullanıcıdan açıkça istediği cihaz izinleri.
///
/// Bildirim izni, ses/uyarı/badge seçeneklerini platforma özgü olarak
/// ayarlayan [NotificationService] üzerinden istenir. Kamera için ise QR
/// eklentisinin ekran açılırken dolaylı izin istemesine güvenmek yerine doğrudan
/// sistem izin API'si kullanılır. Konum izni ise haritayı/etkinlik girişini
/// kullanan ekranlarla aynı API üzerinden (geolocator) istenir; böylece izin
/// durumu her yerde aynı kaynaktan okunur.
library;

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_service.dart';

class DevicePermissionService {
  DevicePermissionService._();

  /// Açılış perdesi kapandıktan sonra yalnız bildirim iznini ister. Kamera ve
  /// konum izinleri kullanıldıkları ekranda, bağlamı içinde istenir.
  ///
  /// Dönen kayıt, her iznin verilip verilmediğini söyler. Çağıran taraf
  /// isterse buna bakıp yönlendirme gösterebilir; hiçbiri uygulamanın
  /// açılışını engellemez.
  static Future<StartupPermissions> requestStartupPermissions() async {
    bool notifications = false;
    bool camera = false;
    bool location = false;

    try {
      notifications = await NotificationService.instance.requestPermission();
    } catch (_) {
      // Eklenti o an hazır değilse uygulamanın açılışı engellenmez. Bildirim
      // eşitleyicisi oturum çözülünce bir kez daha denemeye devam eder.
    }

    // Kamera ve konum açılışta İSTENMEZ (App Store 2.1(a) / 5.1.1):
    // kullanıcı bağlamı görmeden "İzin Verme" deyince QR ekranı kilitleniyordu.
    // Kamera QR ekranında (QrScannerView), konum etkinlik girişinde
    // (GeoFenceService) ve harita ekranında, ihtiyaç anında sorulur. Burada
    // yalnız mevcut durum okunur; sistem penceresi açılmaz.
    try {
      camera = (await Permission.camera.status).isGranted;
    } catch (_) {}
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      location =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {}

    return StartupPermissions(
      notifications: notifications,
      camera: camera,
      location: location,
    );
  }
}

/// [DevicePermissionService.requestStartupPermissions] sonucunda kullanıcının
/// hangi izinleri verdiği.
class StartupPermissions {
  const StartupPermissions({
    required this.notifications,
    required this.camera,
    required this.location,
  });

  final bool notifications;
  final bool camera;
  final bool location;

  bool get allGranted => notifications && camera && location;
}
