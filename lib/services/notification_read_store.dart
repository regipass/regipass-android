/// Bildirimlerin "görüldü" durumu — cihazda tutulur.
///
/// Sunucuda tutulmamasının sebebi: duyuru dokümanları hedef kitledeki HERKESE
/// açık okunur belgelerdir; her kullanıcının okuma damgasını oraya yazması
/// için belgeye yazma izni gerekirdi. Okundu bilgisi kişisel ve önemsiz
/// olduğundan cihazda kalması yeterli.
library;

import 'package:shared_preferences/shared_preferences.dart';

class NotificationReadStore {
  NotificationReadStore(this._prefs);

  static Future<NotificationReadStore> create() async =>
      NotificationReadStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  /// Kullanıcının bildirimler sayfasını son açtığı an.
  static String _seenKey(String uid) => 'regipass_notif_seen_$uid';

  /// Cihaz bildirimine çevrilmiş en son duyurunun anı.
  ///
  /// [_seenKey]'den ayrı tutulur: kullanıcı sayfayı hiç açmasa da aynı duyuru
  /// için ikinci kez bildirim almamalı.
  static String _notifiedKey(String uid) => 'regipass_notif_pushed_$uid';

  /// Tek tek açılmış bildirimlerin kimlikleri.
  ///
  /// [_seenKey] "sayfayı şu ana kadar gördüm" der; bu ise "şu bildirime
  /// dokundum". İkisi ayrı: kullanıcı sayfayı açıp bir bildirime dokunmadan
  /// çıkabilir, o zaman dokunulmayanın işareti sönmemeli.
  static String _openedKey(String uid) => 'regipass_notif_opened_$uid';

  /// Listede saklanacak en fazla kimlik sayısı. Bildirimler zaten eskiyip
  /// akıştan düşüyor; sınırsız büyüyen bir liste tutmanın karşılığı yok.
  static const int _maxOpenedIds = 200;

  int lastSeenAtMs(String uid) => _prefs.getInt(_seenKey(uid)) ?? 0;

  Future<void> markSeen(String uid, int atMs) =>
      _prefs.setInt(_seenKey(uid), atMs);

  Set<String> openedIds(String uid) =>
      (_prefs.getStringList(_openedKey(uid)) ?? const <String>[]).toSet();

  /// [id]'yi açılmışlar listesine ekler ve güncel listeyi döndürür.
  Future<Set<String>> markOpened(String uid, String id) async {
    final List<String> current =
        List<String>.of(_prefs.getStringList(_openedKey(uid)) ?? const <String>[])
          ..remove(id)
          ..add(id);

    // En eskiler baştan düşer; sondaki (en yeni) kayıtlar korunur.
    final List<String> trimmed = current.length > _maxOpenedIds
        ? current.sublist(current.length - _maxOpenedIds)
        : current;

    await _prefs.setStringList(_openedKey(uid), trimmed);
    return trimmed.toSet();
  }

  int lastNotifiedAtMs(String uid) => _prefs.getInt(_notifiedKey(uid)) ?? 0;

  Future<void> markNotified(String uid, int atMs) =>
      _prefs.setInt(_notifiedKey(uid), atMs);

  /// Hesap değiştiğinde değil, çıkış yapıldığında da çağrılabilir; anahtarlar
  /// kullanıcıya özel olduğu için silmek zorunlu değil, yalnızca temizlik.
  Future<void> clear(String uid) async {
    await _prefs.remove(_seenKey(uid));
    await _prefs.remove(_notifiedKey(uid));
    await _prefs.remove(_openedKey(uid));
  }
}
