/// Görünüm (açık / koyu) tercihi.
///
/// Dil tercihiyle aynı desen: değer cihazda kalıcıdır ve Riverpod üzerinden
/// okunur, böylece seçim anında tüm ağaca yayılır.
///
/// Fark şu: görünüm cihazı da izler. Telefon koyu moda geçtiğinde uygulama
/// kullanıcı hiçbir şey yapmadan koyu moda döner (açıkken de tersi). Kullanıcı
/// bundan sonra ayarlardan açık/koyu seçerse o seçim geçerli olur ve cihaz
/// teması bir daha değişene kadar korunur — uygulamada "sistem" diye üçüncü
/// bir mod yoktur, state her zaman açık ya da koyudur.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _storageKey = 'regipass_theme_mode_v1';

/// Tercihle birlikte, o tercih kaydedilirken cihazın hangi görünümde olduğu da
/// saklanır. Uygulama kapalıyken yapılan cihaz değişikliği ancak böyle
/// anlaşılır: kayıtlı değer ile açılıştaki cihaz görünümü farklıysa cihaz
/// kazanır.
const String _deviceBrightnessKey = 'regipass_theme_device_brightness_v1';

/// Depo okunana kadar geçerli olan geçici değer; cihaz görünümü zaten
/// [ThemeModeNotifier.build] içinde ilk karede uygulanır.
const ThemeMode kDefaultThemeMode = ThemeMode.light;

/// Cihaz görünümünün uygulama karşılığı.
ThemeMode themeModeForBrightness(Brightness brightness) =>
    brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

String encodeThemeMode(ThemeMode mode) => switch (mode) {
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
  ThemeMode.light => 'light',
};

ThemeMode decodeThemeMode(String? raw) => switch (raw) {
  'dark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  'light' => ThemeMode.light,
  _ => kDefaultThemeMode,
};

String encodeBrightness(Brightness brightness) =>
    brightness == Brightness.dark ? 'dark' : 'light';

Brightness? decodeBrightness(String? raw) => switch (raw) {
  'dark' => Brightness.dark,
  'light' => Brightness.light,
  _ => null,
};

/// Kayıtlı tercih ile cihazın görünümünden hangisinin uygulanacağını seçer.
///
/// [seenDeviceBrightness] tercihin kaydedildiği andaki cihaz görünümüdür.
/// Cihaz o günden bu yana değiştiyse (ya da hiç tercih yoksa) cihaz kazanır.
ThemeMode resolveThemeMode({
  required ThemeMode? storedMode,
  required Brightness? seenDeviceBrightness,
  required Brightness deviceBrightness,
}) {
  if (storedMode == null || seenDeviceBrightness != deviceBrightness) {
    return themeModeForBrightness(deviceBrightness);
  }
  return storedMode;
}

class ThemeModeNotifier extends Notifier<ThemeMode> {
  SharedPreferences? _prefs;

  @override
  ThemeMode build() {
    // İlk kare cihaz görünümüyle çizilir; depo okunduktan sonra kullanıcının
    // kaydedilmiş seçimi (hâlâ geçerliyse) devreye girer.
    _load();
    return themeModeForBrightness(_deviceBrightness);
  }

  Brightness get _deviceBrightness =>
      PlatformDispatcher.instance.platformBrightness;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();

    final String? rawMode = _prefs!.getString(_storageKey);
    final Brightness device = _deviceBrightness;
    final ThemeMode resolved = resolveThemeMode(
      storedMode: rawMode == null ? null : decodeThemeMode(rawMode),
      seenDeviceBrightness: decodeBrightness(
        _prefs!.getString(_deviceBrightnessKey),
      ),
      deviceBrightness: device,
    );

    if (resolved != state) state = resolved;
    await _persist(resolved, device);
  }

  /// Cihazın açık/koyu ayarı değiştiğinde çağrılır (bkz. `lib/app/app.dart`).
  /// Kullanıcının önceki elle seçimi ne olursa olsun uygulama cihaza uyar.
  Future<void> syncWithDeviceBrightness(Brightness device) async {
    final ThemeMode next = themeModeForBrightness(device);
    if (next != state) state = next;
    await _persist(next, device);
  }

  /// Ayarlardan yapılan elle seçim. Cihazın o anki görünümü de yazılır; aksi
  /// halde uygulama bir sonraki açılışta seçimi "cihaz değişmiş" sanıp ezerdi.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _persist(mode, _deviceBrightness);
  }

  Future<void> _persist(ThemeMode mode, Brightness device) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_storageKey, encodeThemeMode(mode));
    await _prefs!.setString(_deviceBrightnessKey, encodeBrightness(device));
  }
}

final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
