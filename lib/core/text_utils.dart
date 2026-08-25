/// Türkçe metin normalizasyonu.
///
/// Web tarafında `event-utils.js#normalizeText` ve
/// `department-field-map.js#foldTr` birbirinin aynısı olan iki kopyaydı;
/// burada tek fonksiyonda birleştirildi.
///
/// JS zinciri:
///   I -> i, ı -> i, toLocaleLowerCase("tr"), NFD, birleşen işaretleri at,
///   [^a-z0-9\s] at, boşlukları tekille, kırp.
///
/// Dart'ta `String.normalize()` bulunmadığı için aksan ayrıştırma yerine
/// doğrudan karakter eşlemesi kullanılır; Türkçe ve yaygın Latin aksanları
/// için sonuç aynıdır.
library;

const Map<String, String> _diacriticFolding = <String, String>{
  'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
  'â': 'a', 'ä': 'a', 'à': 'a', 'á': 'a', 'å': 'a', 'ã': 'a',
  'ê': 'e', 'ë': 'e', 'è': 'e', 'é': 'e',
  'î': 'i', 'ï': 'i', 'ì': 'i', 'í': 'i',
  'ô': 'o', 'ò': 'o', 'ó': 'o', 'õ': 'o', 'ø': 'o',
  'û': 'u', 'ù': 'u', 'ú': 'u',
  'ñ': 'n', 'ý': 'y', 'ÿ': 'y', 'ß': 's',
};

/// Türkçe duyarlı katlama. Karşılaştırma ve anahtar kelime araması için
/// kullanılır — görüntülenecek metinlerde kullanılmaz.
String foldTr(String? value) {
  if (value == null || value.isEmpty) return '';

  // 'I' ve 'ı' -> 'i' (Dart'ın toLowerCase'i locale duyarlı değil, JS'teki
  // ön değiştirmeyle aynı sonucu elde etmek için önce elle yapıyoruz).
  final String pre = value.replaceAll('I', 'i').replaceAll('ı', 'i');

  final StringBuffer out = StringBuffer();
  for (final int rune in pre.toLowerCase().runes) {
    final String ch = String.fromCharCode(rune);

    // Birleşen aksan işaretleri (U+0300–U+036F) atılır. Dart'ta 'İ'
    // küçültüldüğünde 'i' + U+0307 üretir; bu adım onu 'i'ye indirir.
    if (rune >= 0x0300 && rune <= 0x036F) continue;

    final String folded = _diacriticFolding[ch] ?? ch;

    final bool isAllowed = (folded.codeUnitAt(0) >= 0x61 && folded.codeUnitAt(0) <= 0x7A) ||
        (folded.codeUnitAt(0) >= 0x30 && folded.codeUnitAt(0) <= 0x39) ||
        folded == ' ' ||
        folded == '\t' ||
        folded == '\n';

    if (isAllowed) out.write(folded == '\t' || folded == '\n' ? ' ' : folded);
  }

  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Türkçe alfabetik sıralama için karşılaştırıcı (`localeCompare(a, b, "tr")`).
int compareTr(String a, String b) => foldTr(a).compareTo(foldTr(b));
