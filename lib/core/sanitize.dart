/// js/modules/utils/sanitize.js portu.
///
/// Mobilde HTML enjeksiyonu web'deki kadar doğrudan bir risk değil (Flutter
/// metni HTML olarak yorumlamaz), ancak bu değerler **aynı Firestore
/// koleksiyonlarına** yazılıyor ve web istemcisi tarafından okunuyor. Bu
/// yüzden temizleme kuralları birebir korunur — aksi hâlde mobilden yazılan
/// bir kayıt web tarafında XSS'e dönüşebilir.
library;

/// HTML etiketlerini, `javascript:` protokolünü ve satır içi olay
/// yakalayıcılarını söker. Tüm temizleme fonksiyonlarının tabanıdır.
String _stripHtml(String? str) {
  return (str ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '') // <herhangi etiket>
      .replaceAll(RegExp(r'\bon\w+\s*=', caseSensitive: false), '') // onclick= ...
      .replaceAll(RegExp(r'javascript\s*:', caseSensitive: false), '')
      .replaceAll(RegExp(r'data\s*:\s*text\s*/\s*html', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _clip(String value, int maxLength) =>
    value.length <= maxLength ? value : value.substring(0, maxLength);

/// Genel amaçlı düz metin.
String sanitizeText(String? str, {int maxLength = 500}) =>
    _clip(_stripHtml(str), maxLength);

/// Uzun serbest metin alanları (açıklama, amaç).
String sanitizeLongText(String? str, {int maxLength = 2000}) =>
    _clip(_stripHtml(str), maxLength);

/// Kişi/kurum adları: yalnızca Unicode harfler, boşluk, tire, kesme, nokta,
/// virgül. Tüm Türkçe karakterleri kapsar (İ, ı, Ğ, ğ, Ş, ş, Ü, ü, Ö, ö, Ç, ç).
String sanitizeName(String? str) {
  final String cleaned = _stripHtml(str)
      .replaceAll(RegExp(r"[^\p{L}\p{M}\s\-'.,]", unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return _clip(cleaned, 100);
}

/// E-posta: temel RFC-5322 biçim kontrolü. Geçerliyse küçük harfli değeri,
/// değilse `null` döner.
String? sanitizeEmail(String? str) {
  final String clean = _clip((str ?? '').trim().toLowerCase(), 254);
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(clean) ? clean : null;
}

/// URL alanları: `javascript:`, `data:`, `vbscript:` protokollerini engeller.
String sanitizeUrl(String? str) {
  final String clean = _clip((str ?? '').trim(), 500);
  return RegExp(r'^(javascript|data|vbscript)\s*:', caseSensitive: false)
          .hasMatch(clean)
      ? ''
      : clean;
}

/// Ham metin XSS/HTML enjeksiyon kalıbı içeriyorsa `true` döner.
/// Temizlemeden ÖNCE kullanılır — yakalanırsa işlem engellenip kullanıcı uyarılır.
bool detectHarmfulInput(String? str) {
  final String s = str ?? '';
  return RegExp(r'<[a-zA-Z/!]').hasMatch(s) ||
      RegExp(r'\bon\w+\s*=', caseSensitive: false).hasMatch(s) ||
      RegExp(r'javascript\s*:', caseSensitive: false).hasMatch(s) ||
      RegExp(r'vbscript\s*:', caseSensitive: false).hasMatch(s) ||
      RegExp(r'data\s*:\s*text\s*/\s*html', caseSensitive: false).hasMatch(s);
}
