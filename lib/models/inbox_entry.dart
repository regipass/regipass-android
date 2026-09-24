/// Kişiye özel gelen kutusu kaydı — `users/{uid}/inbox/{id}` (İP-6).
///
/// Kayıtları yalnızca sunucu yazar (Regipass-Web/functions/
/// userNotifications.js). Başlık ve metin iki dilde gelir (`{tr, en}`);
/// uygulama arayüz diline göre seçer, şablonlar burada tekrar edilmez.
/// Kullanıcı yalnızca `readAtMs` alanını işaretleyebilir.
library;

class InboxEntry {
  const InboxEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAtMs,
    this.route = '',
    this.readAtMs = 0,
  });

  factory InboxEntry.fromMap(String id, Map<String, dynamic> data) =>
      InboxEntry(
        id: id,
        kind: _string(data['kind']),
        title: _localized(data['title']),
        body: _localized(data['body']),
        createdAtMs: _int(data['createdAtMs']),
        route: safeInboxRoute(_string(data['route'])),
        readAtMs: _int(data['readAtMs']),
      );

  final String id;
  final String kind;

  /// Dil → metin (`tr`, `en`).
  final Map<String, String> title;
  final Map<String, String> body;
  final int createdAtMs;

  /// Dokununca gidilecek uygulama içi rota ('' ise yok).
  final String route;

  /// 0: okunmamış. Web'de ya da başka cihazda okunduysa dolu gelir.
  final int readAtMs;

  bool get isRead => readAtMs > 0;

  String titleIn(String language) => pickLanguage(title, language);
  String bodyIn(String language) => pickLanguage(body, language);
}

/// İstenen dil yoksa diğerine düşer; ikisi de yoksa boş.
String pickLanguage(Map<String, String> value, String language) {
  final String primary = language == 'en' ? 'en' : 'tr';
  final String fallback = primary == 'en' ? 'tr' : 'en';
  final String first = value[primary] ?? '';
  return first.isNotEmpty ? first : (value[fallback] ?? '');
}

/// Sunucudan gelen rota yalnızca öğrenci/kulüp sayfalarından biri olabilir.
/// Başka bir şey (tam adres, yönetici sayfası) yok sayılır.
String safeInboxRoute(String route) {
  final String text = route.trim();
  return RegExp(
        r'^/(student|club)(/[a-z0-9-]+)*(\?[\w=&%.-]*)?$',
      ).hasMatch(text)
      ? text
      : '';
}

String _string(Object? value) => value is String ? value : '';

int _int(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  _ => 0,
};

Map<String, String> _localized(Object? value) {
  if (value is String) return <String, String>{'tr': value, 'en': value};
  if (value is! Map) return const <String, String>{};
  return <String, String>{
    for (final MapEntry<Object?, Object?> e in value.entries)
      if (e.key is String && e.value is String)
        e.key! as String: e.value! as String,
  };
}
