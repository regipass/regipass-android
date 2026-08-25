// js/modules/i18n/language.js içindeki TRANSLATIONS sözlüğünü Dart'a taşır.
// Sözlük dışa aktarılmadığı için kopyaya bir export satırı eklenir.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const SRC = "C:/Users/5sana/Desktop/REGİPASS/js/modules/i18n/language.js";
const OUT = "C:/Users/5sana/StudioProjects/Regipass/lib/l10n/translations.dart";
const TMP = path.join(process.env.TMPDIR || ".", "regipass_i18n.mjs");

// language.js tarayıcı API'lerine (window/document) modül gövdesinde
// dokunmuyor, yalnızca fonksiyon içinde; bu yüzden doğrudan import edilebilir.
fs.writeFileSync(TMP, fs.readFileSync(SRC, "utf8") + "\nexport { TRANSLATIONS };\n", "utf8");
const m = await import(pathToFileURL(TMP).href);

const q = (s) =>
  "'" +
  String(s)
    .replace(/\\/g, "\\\\")
    .replace(/'/g, "\\'")
    .replace(/\$/g, "\\$")
    .replace(/\r/g, "\\r")
    .replace(/\n/g, "\\n") +
  "'";

function block(lang) {
  const entries = Object.entries(m.TRANSLATIONS[lang] ?? {});
  const rows = entries.map(([k, v]) => `  ${q(k)}: ${q(v)},`).join("\n");
  return { rows, count: entries.length };
}

const tr = block("tr");
const en = block("en");

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(
  OUT,
  `// GENERATED — düzenlemeyin.
// Kaynak: js/modules/i18n/language.js (TRANSLATIONS)
// Yeniden üretmek için: node tool/convert_i18n.mjs

/// Türkçe çeviriler (varsayılan dil — eksik anahtarlarda geri düşülür).
const Map<String, String> kTranslationsTr = <String, String>{
${tr.rows}
};

/// İngilizce çeviriler.
const Map<String, String> kTranslationsEn = <String, String>{
${en.rows}
};

const Map<String, Map<String, String>> kTranslations = <String, Map<String, String>>{
  'tr': kTranslationsTr,
  'en': kTranslationsEn,
};
`,
  "utf8"
);

console.log(`translations.dart: tr=${tr.count}, en=${en.count} anahtar`);
