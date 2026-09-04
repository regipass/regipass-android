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

  /// Açılış perdesi kapandıktan sonra kullanıcıya üç ayrı sistem istemi
  /// gösterir (bildirim → kamera → konum). İstemler art arda gelir; böylece
  /// iOS ve Android aynı anda iki iletişim kutusu göstermeye çalışmaz.
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

    try {
      camera = (await Permission.camera.request()).isGranted;
    } catch (_) {
      // Masaüstü/test ortamında platform izin kanalı bulunmayabilir. Mobilde
      // bu çağrı Android/iOS'un kendi kamera izin iletişim kutusunu açar.
    }

    try {
      // iOS izin listesinde bir satırın görünmesi için o iznin EN AZ BİR KEZ
      // istenmiş olması gerekir. Konum daha önce yalnızca harita/giriş
      // ekranlarının içinde isteniyordu; o ekranlara hiç girilmediğinde (ya
      // da harita açılışta çöktüğünde) Ayarlar'da konum satırı hiç
      // görünmüyordu. Açılışta bir kez istemek bunu çözer.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      location =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      // Konum servisi kapalıysa ya da platform kanalı yoksa sessiz geçilir;
      // ilgili ekranlar kendi akışlarında yeniden soruyor.
    }

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
