// department-field-map.js içindeki RAW_FIELD_KEYWORDS tablosunu Dart'a taşır.
// Tablo modülden dışa aktarılmadığı için kopyaya bir export satırı eklenir.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const SRC = "C:/Users/5sana/Desktop/REGİPASS/js/modules/events/department-field-map.js";
const OUT = "C:/Users/5sana/StudioProjects/Regipass/lib/data/department_field_map_data.dart";
const TMP = path.join(process.env.TMPDIR || ".", "regipass_fieldmap.mjs");

fs.writeFileSync(TMP, fs.readFileSync(SRC, "utf8") + "\nexport { RAW_FIELD_KEYWORDS };\n", "utf8");
const m = await import(pathToFileURL(TMP).href);

const q = (s) =>
  "'" +
  String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$") +
  "'";

const blocks = Object.entries(m.RAW_FIELD_KEYWORDS)
  .map(([field, entries]) => {
    const rows = entries
      .map(([kw, w]) => `    FieldKeyword(${q(kw)}, ${Number.isInteger(w) ? w.toFixed(1) : w}),`)
      .join("\n");
    return `  ${q(field)}: <FieldKeyword>[\n${rows}\n  ],`;
  })
  .join("\n");

const total = Object.values(m.RAW_FIELD_KEYWORDS).reduce((n, e) => n + e.length, 0);

fs.writeFileSync(
  OUT,
  `// GENERATED — düzenlemeyin.
// Kaynak: js/modules/events/department-field-map.js (RAW_FIELD_KEYWORDS)
// Yeniden üretmek için: node tool/convert_field_map.mjs

/// Bir kulüp alanına ait anahtar kelime ve ağırlığı (0..1).
class FieldKeyword {
  const FieldKeyword(this.keyword, this.weight);

  final String keyword;
  final double weight;
}

/// Kulüp alanı -> anahtar kelime listesi. Bir bölüm birden fazla alanın
/// kelimeleriyle eşleşebilir (ör. "Gıda Mühendisliği" hem mühendislik hem
/// gıda alanına düşer); en yüksek ağırlık kazanır.
const Map<String, List<FieldKeyword>> kRawFieldKeywords =
    <String, List<FieldKeyword>>{
${blocks}
};
`,
  "utf8"
);

console.log(
  `department_field_map_data.dart: ${Object.keys(m.RAW_FIELD_KEYWORDS).length} alan, ${total} anahtar kelime`
);
