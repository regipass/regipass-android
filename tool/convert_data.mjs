// js/data/*.js -> lib/data/*.dart dönüştürücü.
// ES modülleri olduğu gibi import edilir; böylece Object.freeze/sort gibi
// çalışma anı dönüşümleri de aynen uygulanmış hâliyle Dart'a taşınır.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const SRC = "C:/Users/5sana/Desktop/REGİPASS/js/data";
const OUT = "C:/Users/5sana/StudioProjects/Regipass/lib/data";
const TMP = path.join(process.env.TMPDIR || ".", "regipass_data_mjs");

fs.mkdirSync(TMP, { recursive: true });
fs.mkdirSync(OUT, { recursive: true });

// .js dosyaları CommonJS olarak yorumlanmasın diye .mjs kopyası alınır.
function loadModule(name) {
  const src = fs.readFileSync(path.join(SRC, `${name}.js`), "utf8");
  const dst = path.join(TMP, `${name}.mjs`);
  fs.writeFileSync(dst, src, "utf8");
  return import(pathToFileURL(dst).href);
}

const q = (s) => "'" + String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$") + "'";

const header = (srcFile) => `// GENERATED — düzenlemeyin.
// Kaynak: js/data/${srcFile}
// Yeniden üretmek için: node tool/convert_data.mjs

`;

// ── location-data.js ────────────────────────────────────────────────
{
  const m = await loadModule("location-data");
  const cities = m.TURKEY_CITIES;
  const map = m.CITY_UNIVERSITIES;

  const entries = cities
    .map((c) => `  ${q(c)}: <String>[\n${map[c].map((u) => `    ${q(u)},`).join("\n")}\n  ],`)
    .join("\n");

  fs.writeFileSync(
    path.join(OUT, "location_data.dart"),
    header("location-data.js") +
      `/// Şehir -> o şehirdeki üniversiteler. Türkçe alfabetik sıralı.\n` +
      `const Map<String, List<String>> kCityUniversities = <String, List<String>>{\n${entries}\n};\n\n` +
      `/// Tüm iller (kCityUniversities anahtarları, Türkçe sıralı).\n` +
      `const List<String> kTurkeyCities = <String>[\n${cities.map((c) => `  ${q(c)},`).join("\n")}\n];\n\n` +
      `/// Tüm üniversiteler, tekilleştirilmiş ve sıralı (club-create-event.js'teki\n` +
      `/// allUniversities türetmesinin karşılığı).\n` +
      `final List<String> kAllUniversities = (kCityUniversities.values\n` +
      `        .expand((List<String> list) => list)\n` +
      `        .toSet()\n` +
      `        .toList()\n` +
      `      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase())));\n`,
    "utf8"
  );
  console.log(`location_data.dart: ${cities.length} il`);
}

// ── department-data.js ──────────────────────────────────────────────
{
  const m = await loadModule("department-data");
  const list = m.COMMON_DEPARTMENTS;
  fs.writeFileSync(
    path.join(OUT, "department_data.dart"),
    header("department-data.js") +
      `/// Öğrenci bölüm listesi (searchable input seçenekleri).\n` +
      `const List<String> kCommonDepartments = <String>[\n${list.map((d) => `  ${q(d)},`).join("\n")}\n];\n`,
    "utf8"
  );
  console.log(`department_data.dart: ${list.length} bölüm`);
}

// ── club-fields.js ──────────────────────────────────────────────────
{
  const m = await loadModule("club-fields");
  const list = m.CLUB_FIELDS;
  fs.writeFileSync(
    path.join(OUT, "club_fields.dart"),
    header("club-fields.js") +
      `/// Kulüp faaliyet alanları. department_field_map.dart'taki anahtarlarla\n` +
      `/// birebir eşleşmelidir.\n` +
      `const List<String> kClubFields = <String>[\n${list.map((f) => `  ${q(f)},`).join("\n")}\n];\n`,
    "utf8"
  );
  console.log(`club_fields.dart: ${list.length} alan`);
}

// ── country-codes.js ────────────────────────────────────────────────
{
  const m = await loadModule("country-codes");
  const list = m.COUNTRY_CODES;
  const rows = list
    .map(
      (c) =>
        `  CountryCode(code: ${q(c.code)}, dial: ${q(c.dial)}, name: ${q(c.name)}, min: ${c.min}, max: ${c.max}, trunk: ${q(c.trunk)}),`
    )
    .join("\n");

  fs.writeFileSync(
    path.join(OUT, "country_codes.dart"),
    header("country-codes.js") +
      `/// Ülke arama kodu + ulusal numara uzunluk aralığı.\n` +
      `/// [min]/[max]: trunk ön eki hariç ulusal anlamlı hane sayısı.\n` +
      `/// [trunk]: ulusal aramada başa eklenen, E.164'te atılan ön ek ('' = yok).\n` +
      `class CountryCode {\n` +
      `  const CountryCode({\n` +
      `    required this.code,\n    required this.dial,\n    required this.name,\n` +
      `    required this.min,\n    required this.max,\n    required this.trunk,\n  });\n\n` +
      `  final String code;\n  final String dial;\n  final String name;\n` +
      `  final int min;\n  final int max;\n  final String trunk;\n\n` +
      `  /// ISO ülke kodundan bayrak emojisi (phone-input.js ile aynı yöntem).\n` +
      `  String get flag => code\n` +
      `      .toUpperCase()\n` +
      `      .codeUnits\n` +
      `      .map((int c) => String.fromCharCode(0x1F1E6 + c - 0x41))\n` +
      `      .join();\n}\n\n` +
      `const List<CountryCode> kCountryCodes = <CountryCode>[\n${rows}\n];\n\n` +
      `const String kDefaultCountry = ${q(m.DEFAULT_COUNTRY)};\n`,
    "utf8"
  );
  console.log(`country_codes.dart: ${list.length} ülke`);
}

// ── istanbul-university-side.js ─────────────────────────────────────
{
  const m = await loadModule("istanbul-university-side");
  const map = m.ISTANBUL_UNIVERSITY_SIDE;
  const rows = Object.entries(map)
    .map(([uni, side]) => `  ${q(uni)}: ${q(side)},`)
    .join("\n");

  fs.writeFileSync(
    path.join(OUT, "istanbul_university_side.dart"),
    header("istanbul-university-side.js") +
      `/// İstanbul üniversitelerinin yaka bilgisi (admin istatistiklerinde kullanılır).\n` +
      `class IstanbulSide {\n  static const String anadolu = 'anadolu';\n  static const String avrupa = 'avrupa';\n}\n\n` +
      `const Map<String, String> kIstanbulUniversitySide = <String, String>{\n${rows}\n};\n\n` +
      `/// Eşlemede olmayan üniversite için null döner — çağıran taraf bunu\n` +
      `/// "İstanbul (Diğer)" kovasına koymalı, sessizce atmamalı.\n` +
      `String? istanbulSideOf(String universityName) =>\n` +
      `    kIstanbulUniversitySide[universityName];\n`,
    "utf8"
  );
  console.log(`istanbul_university_side.dart: ${Object.keys(map).length} üniversite`);
}

console.log("Tamamlandı.");
