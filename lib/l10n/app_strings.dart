/// js/modules/i18n/language.js çalışma zamanının portu.
///
/// Web'de `t()` global bir fonksiyondu ve dil değişimi bir CustomEvent ile
/// yayınlanıyordu. Burada dil bir Riverpod durumu; `context.t(...)` çağıran
/// her widget dil değiştiğinde kendiliğinden yeniden çizilir.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'extra_translations.dart';
import 'translations.dart';

const String kDefaultLanguage = 'tr';
const List<String> kSupportedLanguages = <String>['tr', 'en'];
const String _storageKey = 'eventapp_language_v1';

String normalizeLanguage(String? language) =>
    kSupportedLanguages.contains(language) ? language! : kDefaultLanguage;

final RegExp _placeholder = RegExp(r'\{\{(\w+)\}\}');

/// `{{ad}}` yer tutucularını doldurur. Karşılığı olmayan yer tutucu, web'deki
/// davranışla aynı şekilde boş dizeye çevrilir.
String _interpolate(String template, Map<String, Object?> params) =>
    template.replaceAllMapped(_placeholder, (Match match) {
      final String key = match.group(1)!;
      return params.containsKey(key) ? '${params[key]}' : '';
    });

/// Anahtarı çevirir.
///
/// Arama sırası: ek sözlük (seçili dil) -> üretilen sözlük (seçili dil) ->
/// ek sözlük (tr) -> üretilen sözlük (tr) -> anahtarın kendisi.
String translate(
  String key, {
  Map<String, Object?> params = const <String, Object?>{},
  String language = kDefaultLanguage,
}) {
  final String lang = normalizeLanguage(language);

  final String value = kExtraTranslations[lang]?[key] ??
      kTranslations[lang]?[key] ??
      kExtraTranslations[kDefaultLanguage]?[key] ??
      kTranslations[kDefaultLanguage]?[key] ??
      key;

  return _interpolate(value, params);
}

/// Seçili dil. Değer cihazda kalıcıdır (web'deki localStorage karşılığı).
class LanguageNotifier extends Notifier<String> {
  SharedPreferences? _prefs;

  @override
  String build() {
    // Depo hazır olana kadar varsayılan dil kullanılır; okuma tamamlanınca
    // state güncellenir ve dinleyen widget'lar yeniden çizilir.
    _load();
    return kDefaultLanguage;
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();

    // Depo okuması bir asenkron boşluk: sağlayıcı bu arada atılmış olabilir
    // (testlerde kısa ömürlü container, uygulamada hesap değişimi). Atılmış
    // bir sağlayıcının state'ine yazmak hata fırlatır.
    if (!ref.mounted) return;

    final String stored = normalizeLanguage(_prefs!.getString(_storageKey));
    if (stored != state) state = stored;
  }

  Future<void> setLanguage(String language) async {
    final String next = normalizeLanguage(language);
    state = next;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_storageKey, next);
  }
}

final NotifierProvider<LanguageNotifier, String> languageProvider =
    NotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);

/// Widget ağacına seçili dili taşır — `context.t(...)` bunu okur.
class LanguageScope extends InheritedWidget {
  const LanguageScope({
    required this.language,
    required super.child,
    super.key,
  });

  final String language;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.language ??
      kDefaultLanguage;

  @override
  bool updateShouldNotify(LanguageScope oldWidget) =>
      language != oldWidget.language;
}

extension TranslateX on BuildContext {
  /// Kısa çeviri erişimi: `context.t('dashboard.welcome', {'name': 'Ayşe'})`.
  String t(String key, [Map<String, Object?> params = const <String, Object?>{}]) =>
      translate(key, params: params, language: LanguageScope.of(this));

  /// Tarih biçimlendirme gibi yerlerde gereken ham dil kodu.
  String get lang => LanguageScope.of(this);
}
