import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// js/modules/auth/role-session.js içindeki depolama kısmının portu.
///
/// Web'de aynı değer hem `sessionStorage`'a hem `localStorage`'a yazılıyordu
/// (sekme ömrü + kalıcılık). Mobilde uygulama zaten tek bir oturum olduğu için
/// tek bir kalıcı depo (SharedPreferences) yeterli.
class RoleSessionStore {
  RoleSessionStore(this._prefs);

  static const String _key = 'eventapp_active_role_v1';

  final SharedPreferences _prefs;

  static Future<RoleSessionStore> create() async =>
      RoleSessionStore(await SharedPreferences.getInstance());

  /// Kullanıcının bu cihazda seçtiği aktif rolü yazar.
  Future<void> setActiveRole(String uid, String role) async {
    if (uid.isEmpty || !UserRole.isValid(role)) return;

    await _prefs.setString(
      _key,
      jsonEncode(<String, dynamic>{
        'uid': uid,
        'role': role,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Saklanan rol yalnızca **aynı kullanıcı** için geçerlidir; farklı bir
  /// hesap giriş yaptıysa yok sayılır.
  String? getActiveRole(String? uid) {
    if (uid == null || uid.isEmpty) return null;

    final String? raw = _prefs.getString(_key);
    if (raw == null) return null;

    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is! Map) return null;
      if (parsed['uid'] != uid) return null;

      final Object? role = parsed['role'];
      return role is String && UserRole.isValid(role) ? role : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => _prefs.remove(_key);
}
