// İP-P (mobil 1.0.13): web language.js'teki paket hattı anahtarlarını
// (plan / online / staff / approval / voucher / passport / hall / photos / inst / offline)
// lib/l10n/feature_translations.dart'a taşır. translations.dart'a dokunmaz.
//   node tool/convert_feature_i18n.mjs <web language.js yolu>
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const SRC = process.argv[2] || "../Regipass-Web/js/modules/i18n/language.js";
const OUT = path.join(path.dirname(new URL(import.meta.url).pathname), "../lib/l10n/feature_translations.dart");
const PREFIXES = ["plan.", "online.", "staff.", "approval.", "voucher.", "passport.", "hall.", "photos.", "inst.", "offline."];
const TMP = path.join(process.env.TMPDIR || "/tmp", `regipass_feature_i18n_${process.pid}.mjs`);
fs.writeFileSync(TMP, fs.readFileSync(SRC, "utf8") + "\nexport { TRANSLATIONS };\n", "utf8");
const m = await import(pathToFileURL(TMP).href);
fs.unlinkSync(TMP);

const q = (s) => "'" + String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$").replace(/\r/g, "\\r").replace(/\n/g, "\\n") + "'";
function block(lang) {
  const entries = Object.entries(m.TRANSLATIONS[lang] ?? {}).filter(([k]) => PREFIXES.some((p) => k.startsWith(p))).sort(([a], [b]) => a.localeCompare(b));
  return { rows: entries.map(([k, v]) => `  ${q(k)}:\n      ${q(v)},`).join("\n"), count: entries.length };
}
const tr = block("tr");
const en = block("en");
fs.writeFileSync(OUT, `// GENERATED — düzenlemeyin.
// Kaynak: Regipass-Web js/modules/i18n/language.js (paket hattı anahtarları)
// Yeniden üretmek için: node tool/convert_feature_i18n.mjs <language.js>
// ignore_for_file: lines_longer_than_80_chars

/// Paket hattı (İP-P1 … İP-FT) çevirileri — Türkçe.
const Map<String, String> kFeatureTranslationsTr = <String, String>{
${tr.rows}
};

/// Paket hattı çevirileri — İngilizce.
const Map<String, String> kFeatureTranslationsEn = <String, String>{
${en.rows}
};

const Map<String, Map<String, String>> kFeatureTranslations = <String, Map<String, String>>{
  'tr': kFeatureTranslationsTr,
  'en': kFeatureTranslationsEn,
};
`, "utf8");
console.log(`feature_translations.dart: tr=${tr.count}, en=${en.count}`);
