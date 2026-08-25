/// js/modules/events/department-field-map.js portu (mantık kısmı).
/// Anahtar kelime tablosu `lib/data/department_field_map_data.dart` içinde üretilir.
library;

import '../core/text_utils.dart';
import '../data/department_field_map_data.dart';

/// Bir bölüm<->alan anahtar kelime eşleşmesinin "ilişkili" sayılması için
/// gereken en düşük ağırlık (bkz. event_utils.dart).
const double kFieldRelationThreshold = 0.5;

/// Anahtar kelimeler bir kez katlanıp önbelleğe alınır — her çağrıda
/// 239 kelimeyi yeniden normalize etmemek için.
final Map<String, List<MapEntry<String, double>>> _foldedRules =
    kRawFieldKeywords.map(
  (String field, List<FieldKeyword> entries) => MapEntry<String, List<MapEntry<String, double>>>(
    field,
    entries
        .map((FieldKeyword e) => MapEntry<String, double>(foldTr(e.keyword), e.weight))
        .toList(growable: false),
  ),
);

/// Öğrencinin bölümü ile kulübün alanı arasındaki ilişki ağırlığı (0..1).
///
/// Eşleşme kelime sınırına bakmadan, düz alt dize olarak yapılır: Türkçe
/// ekler kökle bitişik yazılır ("edebiyat" + "ı" -> "edebiyatı"), sınır
/// kontrolü gerçek bölüm adlarının çoğunu kaçırırdı.
double getFieldRelationWeight(String? departmentName, String? clubField) {
  final List<MapEntry<String, double>>? rules = _foldedRules[clubField];
  if (rules == null || rules.isEmpty) return 0;

  final String folded = foldTr(departmentName);
  if (folded.isEmpty) return 0;

  double best = 0;
  for (final MapEntry<String, double> rule in rules) {
    if (rule.key.isNotEmpty && folded.contains(rule.key) && rule.value > best) {
      best = rule.value;
    }
  }

  return best;
}
