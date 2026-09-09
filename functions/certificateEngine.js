/**
 * certificateEngine.js (Cloud Functions / Node portu)
 *
 * REGİPASS web istemcisindeki js/modules/certificates/certificate-engine.js
 * dosyasinin BİREBİR portu. Analiz ve tarama mantığının tamamı (5 katmanlı
 * alan bulma + font eşleştirme) o dosyayla satır satır aynıdır; tek fark
 * kütüphane/font yükleme şeklidir:
 *
 *   - Web: pdf.js / pdf-lib / fontkit CDN'den <script> ile, fontlar fetch()
 *     ile indirilir.
 *   - Burada: aynı paketler npm bağımlılığı olarak require() edilir, DejaVu
 *     fontları "dejavu-fonts-ttf" paketinden yerel dosya olarak okunur.
 *
 * Web tarafında bu dosyada yapılan her algoritma değişikliği bu porta da
 * elle taşınmalıdır — ikisi de aynı sertifika şablonlarını aynı şekilde
 * okuyabilmelidir (bkz. Flutter tarafındaki kullanım: club_event_detail_screen
 * dağıtım akışı artık kendi Dart koduyla değil, bu modülü saran
 * `personalizeCertificates` callable fonksiyonuyla isim basıyor).
 */

const fs = require("fs");
const path = require("path");
const pdfjsLib = require("pdfjs-dist/legacy/build/pdf.js");
const PDFLib = require("pdf-lib");
const fontkit = require("@pdf-lib/fontkit");

const DEJAVU_DIR = path.join(
  path.dirname(require.resolve("dejavu-fonts-ttf/package.json")),
  "ttf"
);
const FONT_REGULAR_PATH = path.join(DEJAVU_DIR, "DejaVuSans.ttf");
const FONT_BOLD_PATH = path.join(DEJAVU_DIR, "DejaVuSans-Bold.ttf");
// Belgenin yazi tipi serif (Times/Georgia vb.) tespit edilirse ve orijinal
// font gomulu/okunur degilse, en yakin uslupla eslesen yedek fontlar.
const FONT_SERIF_REGULAR_PATH = path.join(DEJAVU_DIR, "DejaVuSerif.ttf");
const FONT_SERIF_BOLD_PATH = path.join(DEJAVU_DIR, "DejaVuSerif-Bold.ttf");

// PDF FontDescriptor /Flags bit degerleri (PDF 32000-1:2008, Tablo 123).
const FONT_FLAG_SERIF = 1 << 1;
const FONT_FLAG_ITALIC = 1 << 6;
const FONT_FLAG_FORCE_BOLD = 1 << 18;

// BaseFont adindan (orn. "ABCDEF+TimesNewRomanPSMT-Bold") uslup ipucu cikarir.
function classifyBaseFontName(name) {
  const n = String(name || "").toLowerCase();
  return {
    serif: /times|georgia|garamond|serif|minion|palatino|cambria|book\s*antiqua|caslon|baskerville|didot|constantia|cardo|pt\s*serif/.test(n),
    bold: /bold|black|heavy|semibold/.test(n),
    italic: /italic|oblique/.test(n)
  };
}

// Noktali / cizgili / etiketli yer tutucular.
const PLACEHOLDER_RE = /(\.{3,}|…{1,}|_{3,}|\{\s*(?:ad\s*soyad|isim|name)\s*\}|\[\s*(?:ad\s*soyad|isim|name)\s*\])/i;

// Kilit kelimeler — Turkce karakterlerden arindirilmis kucuk harfli metinde aranir.
// "Belge Sahibi", "belge sahibi", "BELGE SAHIBI" gibi tum varyantlari yakalar.
const KEYWORD_RE = /(belge\s*sahibi|sertifika\s*sahibi|ad[i]?\s*[-/]?\s*soyad[i]?|isim\s*soyisim|kat[i]l[i]mc[i]|full\s*name|name\s*surname)/;
const KEYWORD_COMPACT_RE = /(belgesahibi|sertifikasahibi|adsoyad|adisoyad|adisoyadi|isimsoyisim|katilimci|fullname|namesurname)/;

// Isim alanini tanitan cumle kaliplari (Canva vb. sablonlarda kilit kelime
// yerine tam cumle kullanilir: "... adli kisiye sunulur", "proudly presented to").
const PRESENT_PHRASE_RE = /(sunulur|verilir|takdim\s*edilir|bu\s*belge|bu\s*sertifika|present(?:ed)?\s*to|awarded\s*to|is\s*hereby|in\s*recognition\s*of)/;

// Vektor cizgi/dikdortgen (kesikli/duz alt cizgi) tespiti icin ayristirici.
// PDF icerik akisindaki path/paint operatorlerini islerken kalan sayisal
// islenenleri tutar; her operatorden sonra temizlenir (bkz. GRAPHICS_TOKEN_RE).
const GRAPHICS_TOKEN_RE = /\[[^\]]*\]|-?\d*\.\d+(?:[eE][-+]?\d+)?|-?\d+(?:[eE][-+]?\d+)?|\/[^\s\/\[\]()<>]+|[A-Za-z]+\*?/g;
const PAINT_OPS = new Set(["S", "s", "f", "F", "f*", "B", "B*", "b", "b*"]);
const MIN_VECTOR_LINE_LENGTH = 24; // pt

const fontCache = new Map();

function simplifyChar(char) {
  return String(char || "")
    .replace(/İ/g, "I")
    .replace(/ı/g, "i")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase();
}

function loadPdfJs() {
  return pdfjsLib;
}

function loadPdfLib() {
  return PDFLib;
}

function getFontBytes(bold, serif = false) {
  const filePath = serif
    ? (bold ? FONT_SERIF_BOLD_PATH : FONT_SERIF_REGULAR_PATH)
    : (bold ? FONT_BOLD_PATH : FONT_REGULAR_PATH);

  if (!fontCache.has(filePath)) {
    fontCache.set(filePath, fs.readFileSync(filePath));
  }
  return fontCache.get(filePath);
}

// pdf.js metin ogelerini konum/boyut/kalinlik bilgisiyle sadelestirir.
function extractItems(content, pageIndex) {
  const items = [];

  for (const item of content.items) {
    if (!Array.isArray(item.transform)) continue;

    const [, b, , d, x, y] = item.transform;
    const height = Math.hypot(b, d) || Math.abs(d) || 12;
    const fontFamily = content.styles?.[item.fontName]?.fontFamily || "";
    const bold = /bold|black|heavy/i.test(fontFamily) || /bold|black|heavy/i.test(item.fontName || "");

    items.push({
      text: item.str || "",
      x,
      y,
      width: Number(item.width) || 0,
      height,
      bold,
      pageIndex
    });
  }

  return items;
}

// Ayni yatay hizadaki ogeleri satirlara gruplar (y toleransi: yukseklik * 0.6).
function groupIntoLines(items) {
  const lines = [];
  const sorted = [...items].sort((a, b) => b.y - a.y || a.x - b.x);

  for (const item of sorted) {
    const line = lines.find((candidate) =>
      Math.abs(candidate[0].y - item.y) <= Math.max(candidate[0].height, item.height) * 0.6
    );
    if (line) line.push(item);
    else lines.push([item]);
  }

  lines.forEach((line) => line.sort((a, b) => a.x - b.x));
  return lines;
}

function buildLineTextMap(line) {
  const refs = [];
  let plain = "";

  line.forEach((item, itemIndex) => {
    if (itemIndex > 0) {
      plain += " ";
      refs.push(null);
    }

    const chars = Array.from(item.text || "");
    const charCount = Math.max(chars.length, 1);

    chars.forEach((char, charIndex) => {
      const simplified = simplifyChar(char);
      for (const plainChar of Array.from(simplified)) {
        plain += plainChar;
        refs.push({ item, charIndex, charCount });
      }
    });
  });

  return { plain, refs };
}

function getRangeBounds(refs, start, end) {
  const mapped = refs.slice(start, end).filter(Boolean);
  if (mapped.length === 0) return null;

  let x1 = Infinity;
  let x2 = -Infinity;
  let height = 0;
  let bold = false;
  const firstItem = mapped[0].item;

  for (const ref of mapped) {
    const item = ref.item;
    const itemWidth = Number(item.width) || item.height * ref.charCount * 0.5;
    const left = item.x + (itemWidth * ref.charIndex) / ref.charCount;
    const right = item.x + (itemWidth * (ref.charIndex + 1)) / ref.charCount;

    x1 = Math.min(x1, left);
    x2 = Math.max(x2, right);
    height = Math.max(height, item.height);
    bold = bold || item.bold;
  }

  return {
    pageIndex: firstItem.pageIndex,
    x: x1,
    y: firstItem.y,
    width: Math.max(x2 - x1, height * 2),
    height,
    bold
  };
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function identityMatrix() {
  return { a: 1, b: 0, c: 0, d: 1, e: 0, f: 0 };
}

// PDF 'cm' semantigi: once A (islenen matris) uygulanir, sonra B (mevcut CTM).
function composeMatrix(A, B) {
  return {
    a: A.a * B.a + A.b * B.c,
    b: A.a * B.b + A.b * B.d,
    c: A.c * B.a + A.d * B.c,
    d: A.c * B.b + A.d * B.d,
    e: A.e * B.a + A.f * B.c + B.e,
    f: A.e * B.b + A.f * B.d + B.f
  };
}

function applyMatrix(m, x, y) {
  return [m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f];
}

// PDF sayfa icerik akisindaki path/paint operatorlerini tarayarak yatay
// cizgi/ince-dikdortgen (Canva vb. sablonlarda cok yaygin "alt cizgi" ismi
// yer tutuculari) adaylarini cikarir. Metin bloklari (BT..ET) ve gomulu
// resimler (BI..EI) atlanir -- yalnizca vektor cizimle ilgileniyoruz.
function extractHorizontalLineCandidates(rawContent, pageIndex) {
  const candidates = [];
  if (!rawContent) return candidates;

  const cleaned = rawContent
    .replace(/BT[\s\S]*?ET/g, " ")
    .replace(/BI[\s\S]*?EI/g, " ");

  let ctm = identityMatrix();
  const ctmStack = [];
  const operands = [];
  let subpaths = [];

  const finalizePaint = () => {
    for (const sub of subpaths) {
      if (sub.curved || sub.points.length < 2) continue;

      if (sub.rectWH) {
        const [w, h] = sub.rectWH;
        if (w <= 0 || h <= 0) continue;
        if (h <= Math.max(6, w * 0.15) && w >= MIN_VECTOR_LINE_LENGTH) {
          const xs = sub.points.map((p) => p[0]);
          const ys = sub.points.map((p) => p[1]);
          candidates.push({
            pageIndex,
            x1: Math.min(...xs),
            x2: Math.max(...xs),
            y: (Math.min(...ys) + Math.max(...ys)) / 2
          });
        }
        continue;
      }

      if (sub.points.length === 2) {
        const [[x1, y1], [x2, y2]] = sub.points;
        const dx = x2 - x1;
        const dy = y2 - y1;
        if (Math.abs(dx) >= MIN_VECTOR_LINE_LENGTH && Math.abs(dy) <= Math.abs(dx) * 0.15) {
          candidates.push({
            pageIndex,
            x1: Math.min(x1, x2),
            x2: Math.max(x1, x2),
            y: (y1 + y2) / 2
          });
        }
      }
    }

    subpaths = [];
  };

  let match;
  GRAPHICS_TOKEN_RE.lastIndex = 0;
  while ((match = GRAPHICS_TOKEN_RE.exec(cleaned))) {
    const token = match[0];

    if (token[0] === "[" || token[0] === "/") continue; // dash dizisi/isim -- degeri onemsiz.
    if (/^-?[\d.]/.test(token)) {
      operands.push(parseFloat(token));
      continue;
    }

    switch (token) {
      case "q":
        ctmStack.push(ctm);
        break;
      case "Q":
        ctm = ctmStack.pop() || identityMatrix();
        break;
      case "cm": {
        const [a, b, c, d, e, f] = operands.slice(-6);
        if ([a, b, c, d, e, f].every(Number.isFinite)) {
          ctm = composeMatrix({ a, b, c, d, e, f }, ctm);
        }
        break;
      }
      case "m": {
        const [x, y] = operands.slice(-2);
        subpaths.push({ points: [applyMatrix(ctm, x, y)], curved: false });
        break;
      }
      case "l": {
        const [x, y] = operands.slice(-2);
        if (subpaths.length) subpaths[subpaths.length - 1].points.push(applyMatrix(ctm, x, y));
        break;
      }
      case "c": case "v": case "y": {
        const nums = operands.slice(-(token === "c" ? 6 : 4));
        const x = nums[nums.length - 2];
        const y = nums[nums.length - 1];
        if (subpaths.length) {
          subpaths[subpaths.length - 1].curved = true;
          subpaths[subpaths.length - 1].points.push(applyMatrix(ctm, x, y));
        }
        break;
      }
      case "re": {
        const [x, y, w, h] = operands.slice(-4);
        if ([x, y, w, h].every(Number.isFinite)) {
          const p1 = applyMatrix(ctm, x, y);
          const p2 = applyMatrix(ctm, x + w, y);
          const p3 = applyMatrix(ctm, x + w, y + h);
          const p4 = applyMatrix(ctm, x, y + h);
          const devW = Math.hypot(p2[0] - p1[0], p2[1] - p1[1]);
          const devH = Math.hypot(p4[0] - p1[0], p4[1] - p1[1]);
          subpaths.push({ points: [p1, p2, p3, p4], curved: false, rectWH: [devW, devH] });
        }
        break;
      }
      case "n":
        subpaths = [];
        break;
      default:
        if (PAINT_OPS.has(token)) finalizePaint();
        break;
    }

    operands.length = 0;
  }

  return candidates;
}

// Sayfanin ham icerik akisini (Contents dizi ise birlestirerek) metne cevirir.
function getPageContentString(PDFLibRef, pdfDocLib, pageIndex) {
  const { PDFArray, PDFRawStream } = PDFLibRef;
  const page = pdfDocLib.getPages()[pageIndex];
  if (!page) return "";

  const contents = page.node?.Contents?.();
  if (!contents) return "";

  const context = pdfDocLib.context;
  const readStream = (entry) => {
    let stream = null;
    try {
      stream = context.lookupMaybe(entry, PDFRawStream);
    } catch (_) {
      if (entry instanceof PDFRawStream) stream = entry;
    }
    if (!stream) return "";
    try {
      return decodeRawStreamToString(PDFLibRef, stream);
    } catch (_) {
      return "";
    }
  };

  if (contents instanceof PDFArray) {
    let out = "";
    for (let i = 0; i < contents.size(); i += 1) {
      out += `${readStream(contents.get(i))}\n`;
    }
    return out;
  }

  return readStream(contents);
}

function bytesToBinaryString(bytes) {
  let out = "";
  for (let i = 0; i < bytes.length; i += 1) {
    out += String.fromCharCode(bytes[i]);
  }
  return out;
}

function decodeRawStreamToString(PDFLibRef, stream) {
  if (!PDFLibRef.decodePDFRawStream) throw new Error("PDF stream decoder yok");
  return bytesToBinaryString(PDFLibRef.decodePDFRawStream(stream).decode());
}

function hexToBytes(hex) {
  const clean = String(hex || "").replace(/\s+/g, "");
  const bytes = [];

  for (let i = 0; i < clean.length; i += 2) {
    bytes.push(parseInt(clean.slice(i, i + 2).padEnd(2, "0"), 16));
  }

  return bytes;
}

function parsePdfLiteralBytes(value) {
  const bytes = [];
  const text = String(value || "");

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (char !== "\\") {
      bytes.push(text.charCodeAt(i) & 255);
      continue;
    }

    i += 1;
    const escaped = text[i];
    if (escaped === "n") bytes.push(10);
    else if (escaped === "r") bytes.push(13);
    else if (escaped === "t") bytes.push(9);
    else if (escaped === "b") bytes.push(8);
    else if (escaped === "f") bytes.push(12);
    else if (escaped === "(" || escaped === ")" || escaped === "\\") {
      bytes.push(escaped.charCodeAt(0));
    } else if (/[0-7]/.test(escaped || "")) {
      let octal = escaped;
      for (let j = 0; j < 2 && /[0-7]/.test(text[i + 1] || ""); j += 1) {
        octal += text[++i];
      }
      bytes.push(parseInt(octal, 8) & 255);
    } else if (escaped) {
      bytes.push(escaped.charCodeAt(0) & 255);
    }
  }

  return bytes;
}

function parseHexNumber(hex) {
  return parseInt(String(hex || "").replace(/\s+/g, ""), 16);
}

function hexToUnicode(hex) {
  const bytes = hexToBytes(hex);
  let out = "";

  for (let i = 0; i + 1 < bytes.length; i += 2) {
    out += String.fromCodePoint((bytes[i] << 8) | bytes[i + 1]);
  }

  return out;
}

function parseToUnicodeCMap(text) {
  const map = new Map();
  const bfcharRe = /beginbfchar([\s\S]*?)endbfchar/g;
  const bfrangeRe = /beginbfrange([\s\S]*?)endbfrange/g;
  let match;

  while ((match = bfcharRe.exec(text))) {
    const pairRe = /<([0-9A-Fa-f\s]+)>\s*<([0-9A-Fa-f\s]+)>/g;
    let pair;
    while ((pair = pairRe.exec(match[1]))) {
      map.set(parseHexNumber(pair[1]), hexToUnicode(pair[2]));
    }
  }

  while ((match = bfrangeRe.exec(text))) {
    const rangeRe = /<([0-9A-Fa-f\s]+)>\s*<([0-9A-Fa-f\s]+)>\s*<([0-9A-Fa-f\s]+)>/g;
    let range;
    while ((range = rangeRe.exec(match[1]))) {
      const start = parseHexNumber(range[1]);
      const end = parseHexNumber(range[2]);
      let dest = parseHexNumber(range[3]);
      for (let code = start; code <= end; code += 1) {
        map.set(code, String.fromCodePoint(dest++));
      }
    }
  }

  return map;
}

function pdfNameKey(name) {
  return name?.asString ? name.asString().replace(/^\//, "") : String(name || "").replace(/^\//, "");
}

function streamDictAsLiteral(dict) {
  const literal = {};

  for (const [key, value] of dict.entries()) {
    const name = pdfNameKey(key);
    if (name === "Length" || name === "Filter" || name === "DecodeParms") continue;
    literal[name] = value;
  }

  return literal;
}

function buildFontUnicodeMaps(PDFLibRef, context, resources) {
  const { PDFName, PDFDict, PDFRawStream } = PDFLibRef;
  const maps = new Map();

  if (!(resources instanceof PDFDict)) return maps;

  const fonts = resources.lookupMaybe(PDFName.of("Font"), PDFDict);
  if (!fonts) return maps;

  for (const [fontName, fontRef] of fonts.entries()) {
    let fontDict = null;
    try {
      fontDict = context.lookup(fontRef, PDFDict);
    } catch (_) {
      continue;
    }

    const toUnicode = fontDict?.lookupMaybe(PDFName.of("ToUnicode"), PDFRawStream);
    if (!toUnicode) continue;

    try {
      maps.set(pdfNameKey(fontName), parseToUnicodeCMap(decodeRawStreamToString(PDFLibRef, toUnicode)));
    } catch (_) {
      // ToUnicode okunamazsa bu fontla eslesen bloklari ellemeden gec.
    }
  }

  return maps;
}

function decodeTextBytes(bytes, cmap) {
  let out = "";
  const twoByteish = bytes.length >= 2 && bytes.some((byte, index) => index % 2 === 0 && byte === 0);

  if (twoByteish || cmap.size > 0) {
    for (let i = 0; i < bytes.length;) {
      let code;
      if (i + 1 < bytes.length) {
        code = (bytes[i] << 8) | bytes[i + 1];
        i += 2;
      } else {
        code = bytes[i];
        i += 1;
      }
      out += cmap.get(code) || String.fromCharCode(code);
    }
  } else {
    out = String.fromCharCode(...bytes);
  }

  return out;
}

function decodeTextArray(arrayBody, cmap) {
  let text = "";
  const itemRe = /<([0-9A-Fa-f\s]+)>|\(([^()]*(?:\\.[^()]*)*)\)/g;
  let item;

  while ((item = itemRe.exec(arrayBody))) {
    const bytes = item[1] ? hexToBytes(item[1]) : parsePdfLiteralBytes(item[2] || "");
    text += decodeTextBytes(bytes, cmap);
  }

  return text;
}

function decodeTextBlock(block, fontMaps) {
  let currentFont = "";
  let text = "";
  const tokenRe = /\/([^\s\/\[\]()<>]+)\s+[-\d.]+\s+Tf|<([0-9A-Fa-f\s]+)>\s*Tj|\(([^()]*(?:\\.[^()]*)*)\)\s*Tj|\[([\s\S]*?)\]\s*TJ/g;
  let token;

  while ((token = tokenRe.exec(block))) {
    if (token[1]) {
      currentFont = token[1];
      continue;
    }

    const cmap = fontMaps.get(currentFont) || new Map();
    if (token[2]) text += decodeTextBytes(hexToBytes(token[2]), cmap);
    else if (token[3]) text += decodeTextBytes(parsePdfLiteralBytes(token[3]), cmap);
    else if (token[4]) text += decodeTextArray(token[4], cmap);
  }

  return text;
}

function simplifyText(text) {
  return Array.from(String(text || ""))
    .map(simplifyChar)
    .join("")
    .replace(/\s+/g, " ")
    .trim();
}

function compactText(text) {
  return simplifyText(text).replace(/[^a-z0-9]/g, "");
}

function isStandaloneReplacementText(text) {
  const raw = String(text || "").trim();
  const simplified = simplifyText(raw);
  const keywordMatch = simplified.match(KEYWORD_RE);

  if (keywordMatch) {
    const rest = (
      simplified.slice(0, keywordMatch.index)
      + simplified.slice(keywordMatch.index + keywordMatch[0].length)
    ).replace(/[:\s._\-/]/g, "");

    return rest.length <= 2 && simplified.length <= 40;
  }

  const compact = compactText(raw);
  const compactKeywordMatch = compact.match(KEYWORD_COMPACT_RE);
  if (compactKeywordMatch) {
    const rest = (
      compact.slice(0, compactKeywordMatch.index)
      + compact.slice(compactKeywordMatch.index + compactKeywordMatch[0].length)
    );

    return rest.length <= 2 && compact.length <= 40;
  }

  const placeholderMatch = raw.match(PLACEHOLDER_RE);
  if (!placeholderMatch) return false;

  const rest = raw
    .replace(PLACEHOLDER_RE, "")
    .replace(/[:\s._\-/]/g, "");

  return rest.length <= 2 && raw.length <= 60;
}

function stripReplacementTextFromStream(PDFLibRef, context, ref, object, resources) {
  const { PDFRawStream } = PDFLibRef;
  if (!(object instanceof PDFRawStream) || !ref || !resources) return 0;

  const fontMaps = buildFontUnicodeMaps(PDFLibRef, context, resources);
  if (fontMaps.size === 0) return 0;

  let decoded = "";
  try {
    decoded = decodeRawStreamToString(PDFLibRef, object);
  } catch (_) {
    return 0;
  }

  let removed = 0;
  const cleaned = decoded.replace(/BT[\s\S]*?ET/g, (block) => {
    const text = decodeTextBlock(block, fontMaps);
    if (!isStandaloneReplacementText(text)) return block;
    removed += 1;
    return "";
  });

  if (cleaned !== decoded) {
    context.assign(ref, context.flateStream(cleaned, streamDictAsLiteral(object.dict)));
  }

  return removed;
}

function stripStandaloneReplacementTextBlocks(pdfDoc, PDFLibRef) {
  const { PDFName, PDFDict, PDFRawStream, PDFArray } = PDFLibRef;
  if (!PDFName || !PDFDict || !PDFRawStream || !PDFArray || !PDFLibRef.decodePDFRawStream) return 0;

  const context = pdfDoc.context;
  const processed = new Set();
  let removed = 0;

  const processOnce = (ref, object, resources) => {
    if (!ref || !Number.isFinite(ref.objectNumber)) return;
    const key = ref?.toString ? ref.toString() : String(ref || "");
    if (!key || processed.has(key)) return;
    processed.add(key);
    removed += stripReplacementTextFromStream(PDFLibRef, context, ref, object, resources);
  };

  for (const [ref, object] of context.enumerateIndirectObjects()) {
    if (!(object instanceof PDFRawStream)) continue;

    const resources = object.dict.lookupMaybe(PDFName.of("Resources"), PDFDict);
    if (resources) processOnce(ref, object, resources);
  }

  for (const page of pdfDoc.getPages()) {
    const resources = page.node?.Resources?.();
    const contents = page.node?.Contents?.();
    if (!resources || !contents) continue;

    const processContent = (entry) => {
      let ref = entry;
      let stream = null;

      try {
        stream = context.lookupMaybe(entry, PDFRawStream);
      } catch (_) {
        if (entry instanceof PDFRawStream) {
          stream = entry;
        }
      }

      if (stream) {
        ref = context.getObjectRef(stream) || ref;
        processOnce(ref, stream, resources);
      }
    };

    if (contents instanceof PDFArray) {
      for (let i = 0; i < contents.size(); i += 1) {
        processContent(contents.get(i));
      }
    } else {
      processContent(contents);
    }
  }

  return removed;
}

/**
 * PDF'te isim yazilacak alani arar (kilit kelime > yer tutucu > vektor cizgi
 * > genis bosluk > dikey bosluk).
 *
 * @returns {Promise<{found: boolean, pageIndex?: number, x?: number, y?: number,
 *                    width?: number, height?: number, bold?: boolean,
 *                    alignLeft?: boolean, score?: number}>}
 */
async function analyzePdfTemplate(arrayBuffer) {
  const pdfjs = loadPdfJs();

  // pdf.js veriyi devraldigi icin kopya ile calisiyoruz.
  const pdf = await pdfjs.getDocument({ data: arrayBuffer.slice(0) }).promise;

  // Vektor cizgi katmani (Katman 2b) icin pdf-lib ile ham icerik akisina da
  // erisiyoruz. Yuklenemezse bu katman sessizce atlanir, diger katmanlar calisir.
  let PDFLibRef = null;
  let pdfDocLib = null;
  try {
    PDFLibRef = loadPdfLib();
    pdfDocLib = await PDFLibRef.PDFDocument.load(arrayBuffer.slice(0), { ignoreEncryption: true });
  } catch (error) {
    console.warn("Vektor cizgi tespiti icin pdf-lib yuklenemedi, bu katman atlanacak:", error);
  }

  let best = null;
  const consider = (candidate) => {
    if (!best
        || candidate.score > best.score
        || (candidate.score === best.score && candidate.width > best.width)) {
      best = candidate;
    }
  };

  try {
    for (let pageNum = 1; pageNum <= pdf.numPages; pageNum += 1) {
      const page = await pdf.getPage(pageNum);
      const content = await page.getTextContent();
      const pageWidth = (page.view?.[2] || 595) - (page.view?.[0] || 0);
      const pageHeight = (page.view?.[3] || 842) - (page.view?.[1] || 0);

      const items = extractItems(content, pageNum - 1);
      const lines = groupIntoLines(items);

      for (const line of lines) {
        const lineMap = buildLineTextMap(line);
        const joinedPlain = lineMap.plain;
        const keywordMatch = joinedPlain.match(KEYWORD_RE);
        const compactKeywordMatch = compactText(joinedPlain).match(KEYWORD_COMPACT_RE);
        const lineHasKeyword = Boolean(keywordMatch || compactKeywordMatch);
        const keywordStart = keywordMatch ? keywordMatch.index : -1;
        const keywordTextEnd = keywordMatch ? keywordStart + keywordMatch[0].length : -1;
        let keywordEraseEnd = keywordTextEnd;
        while (keywordMatch && keywordEraseEnd < joinedPlain.length && /[:\s.]/.test(joinedPlain[keywordEraseEnd])) {
          keywordEraseEnd += 1;
        }
        const keywordBounds = keywordMatch
          ? getRangeBounds(lineMap.refs, keywordStart, keywordEraseEnd)
          : compactKeywordMatch
            ? getRangeBounds(lineMap.refs, 0, lineMap.refs.length)
          : null;
        const beforeKeyword = keywordMatch
          ? joinedPlain.slice(0, keywordStart).replace(/[:\s.]/g, "")
          : "";
        const afterKeyword = keywordMatch
          ? joinedPlain.slice(keywordTextEnd).replace(/[:\s.]/g, "")
          : "";

        // ── Katman 1-2: yer tutucu (noktali/cizgili/etiketli alan) ──────────
        // Kilit kelimeyle ayni satirdaysa oncelik yukselir (isim satiri kesin).
        for (const item of line) {
          const ph = item.text.match(PLACEHOLDER_RE);
          if (!ph) continue;

          const textLen = item.text.length || 1;
          const startFrac = ph.index / textLen;
          const lenFrac = ph[0].length / textLen;
          const placeholderBox = {
            pageIndex: item.pageIndex,
            x: item.x + item.width * startFrac,
            y: item.y,
            width: Math.max(item.width * lenFrac, item.height * 2),
            height: item.height,
            bold: item.bold
          };

          consider({
            ...placeholderBox,
            found: true,
            score: (lineHasKeyword ? 110 : 50) + Math.min(ph[0].length, 30)
          });
        }

        // ── Katman 1b: kilit kelime tek basina yer tutucuysa yerine yaz. ─────
        if (keywordBounds) {
          const keywordIsWholeLine = beforeKeyword.length <= 2 && afterKeyword.length <= 2;
          const naturalWidth = Math.max(
            keywordBounds.width,
            keywordBounds.height * (keywordIsWholeLine ? 18 : 14)
          );
          const maxWidth = Math.max(keywordBounds.width, pageWidth - keywordBounds.x - 40);
          const width = Math.min(naturalWidth, maxWidth);
          const centeredX = keywordBounds.x + keywordBounds.width / 2 - width / 2;
          const x = keywordIsWholeLine
            ? clamp(centeredX, 40, Math.max(40, pageWidth - width - 40))
            : keywordBounds.x;

          consider({
            found: true,
            score: keywordIsWholeLine ? 108 : 104,
            pageIndex: keywordBounds.pageIndex,
            x,
            y: keywordBounds.y,
            width,
            height: keywordBounds.height,
            bold: keywordBounds.bold,
            alignLeft: !keywordIsWholeLine
          });
        }

        // ── Katman 1c: satir kilit kelimeyle bitiyorsa sag taraf yedek alandir.
        if (lineHasKeyword) {
          if (afterKeyword.length <= 2) {
            const lastItem = line[line.length - 1];
            const x = lastItem.x + lastItem.width + lastItem.height * 0.6;
            const width = Math.max(
              Math.min(pageWidth - x - 40, lastItem.height * 16),
              lastItem.height * 6
            );

            consider({
              found: true,
              score: 90,
              pageIndex: lastItem.pageIndex,
              x,
              y: lastItem.y,
              width,
              height: lastItem.height,
              bold: lastItem.bold,
              alignLeft: true
            });
          }
        }

        // ── Katman 3: paragraf icinde isim sigacak genis yatay bosluk ───────
        for (let i = 0; i < line.length - 1; i += 1) {
          const current = line[i];
          const next = line[i + 1];
          const gapStart = current.x + current.width;
          const gap = next.x - gapStart;
          const lineHeight = Math.max(current.height, next.height);

          // Bosluk en az 4 karakter yuksekligi kadar genisse isim alani sayilir.
          if (gap >= lineHeight * 4) {
            consider({
              found: true,
              score: (lineHasKeyword ? 95 : 42) + Math.min(gap / lineHeight, 20),
              pageIndex: current.pageIndex,
              x: gapStart + lineHeight * 0.3,
              y: current.y,
              width: gap - lineHeight * 0.6,
              height: lineHeight,
              bold: current.bold || next.bold
            });
          }
        }
      }

      // ── Katman 2b: cizilmis (vektor) yatay cizgi/ince dikdortgen ─────────
      // Canva vb. sablonlarda isim alani cogunlukla METIN degil, ince bir
      // dolgulu dikdortgen ya da cizgi (kesikli/duz "alt cizgi") olarak
      // cizilir; bu yuzden 1-3. katmanlar (hepsi metin tabanli) bunu goremez.
      // Ustteki en yakin metin satiri "sunulur/presented to" gibi bir ibare
      // iceriyorsa yuksek, icermiyorsa dusuk oncelikle degerlendirilir.
      if (PDFLibRef && pdfDocLib) {
        try {
          const rawContent = getPageContentString(PDFLibRef, pdfDocLib, pageNum - 1);
          const vectorCandidates = extractHorizontalLineCandidates(rawContent, pageNum - 1);

          for (const candidate of vectorCandidates) {
            const width = candidate.x2 - candidate.x1;
            if (width < MIN_VECTOR_LINE_LENGTH) continue;

            let labelLine = null;
            let labelGap = Infinity;
            for (const line of lines) {
              const lineY = line[0].y;
              if (lineY <= candidate.y) continue; // PDF'te y yukari dogru artar.
              const gap = lineY - candidate.y;
              if (gap < labelGap) {
                labelGap = gap;
                labelLine = line;
              }
            }

            let hasLabel = false;
            let labelHeight = null;
            if (labelLine && labelGap < Math.max(width, 60) * 1.5) {
              const simplified = buildLineTextMap(labelLine).plain;
              hasLabel = KEYWORD_RE.test(simplified) || PRESENT_PHRASE_RE.test(simplified);
              labelHeight = Math.max(...labelLine.map((it) => it.height));
            }

            consider({
              found: true,
              score: hasLabel ? 100 : 58,
              pageIndex: candidate.pageIndex,
              x: candidate.x1,
              y: candidate.y,
              width,
              height: labelHeight || clamp(width * 0.11, 10, 40),
              bold: false
            });
          }
        } catch (error) {
          console.warn("Sayfa vektor cizimi okunamadi:", error);
        }
      }

      // ── Katman 4: baska hicbir aday bulunamazsa yedek -- iki metin satiri
      // arasindaki anormal genis DIKEY bosluk isim alani sayilir. Etiketsiz/
      // cizgisiz, sadece bos birakilmis alanlar icin (Canva vb. sablonlarda
      // "Bu belge sunulur / <BOS SATIR> / ... icin katilim..." duzeni cok
      // yaygin -- ne kilit kelime ne yer tutucu karakteri ne de ayni satirda
      // iki metin ogesi vardir, bu yuzden 1-3. katmanlar bunu goremez).
      // En UST (sayfada ilk rastlanan) genis bosluk secilir: sertifikalarda
      // sira hep baslik -> isim -> aciklama -> imza seklindedir; imza
      // bloklarindan once de benzer genislikte bosluklar olabilir ama bunlar
      // isim alanindan SONRA gelir, bu yuzden ilkini almak imza bosluguyla
      // karisma riskini azaltir. Puan kasti dusuk: 1-3. katmanlardan biri
      // bulunduysa bu katman hicbir zaman onu gecemez.
      if (lines.length >= 3) {
        const rows = lines
          .map((rowLine) => {
            const height = Math.max(...rowLine.map((it) => it.height));
            const xs = rowLine.map((it) => it.x);
            const rights = rowLine.map((it) => it.x + (it.width || 0));
            return {
              y: rowLine[0].y,
              height,
              left: Math.min(...xs),
              right: Math.max(...rights),
              pageIndex: rowLine[0].pageIndex
            };
          })
          .sort((a, b) => b.y - a.y);

        const gaps = [];
        for (let i = 0; i < rows.length - 1; i += 1) {
          gaps.push(rows[i].y - rows[i + 1].y);
        }

        const sortedGaps = [...gaps].sort((a, b) => a - b);
        const median = sortedGaps[Math.floor(sortedGaps.length / 2)] || 0;

        for (let i = 0; i < gaps.length; i += 1) {
          const gap = gaps[i];
          const upper = rows[i];
          const lower = rows[i + 1];
          const typicalHeight = Math.max(upper.height, lower.height) || 12;

          const isFarLargerThanMedian = median > 0 && gap > median * 2.2;
          const isTallEnough = gap > typicalHeight * 3.2;
          const notAtPageEdge = lower.y > pageHeight * 0.08 && upper.y < pageHeight * 0.94;

          if (isFarLargerThanMedian && isTallEnough && notAtPageEdge) {
            const width = Math.max(
              upper.right - upper.left,
              lower.right - lower.left,
              pageWidth * 0.32
            );
            const centerX = (
              (upper.left + upper.right) / 2
              + (lower.left + lower.right) / 2
            ) / 2;
            const boxHeight = Math.min(gap * 0.5, typicalHeight * 2.6);
            const y = lower.y + (gap - boxHeight) / 2 + boxHeight * 0.12;

            consider({
              found: true,
              score: 34,
              pageIndex: upper.pageIndex,
              x: clamp(centerX - width / 2, 40, Math.max(40, pageWidth - width - 40)),
              y,
              width: Math.min(width, pageWidth - 80),
              height: boxHeight,
              bold: false
            });

            break; // en ust uygun bosluk yeterli, alttakilere (imza vb.) bakma.
          }
        }
      }
    }
  } finally {
    try { pdf.destroy(); } catch (_) { /* yoksay */ }
  }

  return best || { found: false };
}

// Type0 (composite) fontlarda gercek FontDescriptor DescendantFonts icinde olur.
function resolveFontDescriptor(PDFLibRef, context, fontDict) {
  const { PDFName, PDFDict, PDFArray } = PDFLibRef;

  const subtype = pdfNameKey(fontDict.lookupMaybe(PDFName.of("Subtype"), PDFName));
  let target = fontDict;

  if (subtype === "Type0") {
    const descendants = fontDict.lookupMaybe(PDFName.of("DescendantFonts"), PDFArray);
    const firstRef = descendants && descendants.size() > 0 ? descendants.get(0) : null;
    if (!firstRef) return null;
    try {
      target = context.lookup(firstRef, PDFDict);
    } catch (_) {
      return null;
    }
  }

  return target.lookupMaybe(PDFName.of("FontDescriptor"), PDFDict) || null;
}

// FontDescriptor'daki gomulu font programini (TrueType/OpenType) cikarir.
// Bare CFF tablosu (Type1C/CIDFontType0C) tam dosya olmadigindan atlanir —
// embedFont zaten try/catch ile korunuyor, bu sadece gereksiz denemeyi onler.
function extractFontProgram(PDFLibRef, context, descriptor) {
  const { PDFName, PDFRawStream } = PDFLibRef;
  if (!descriptor) return null;

  const fontFile2 = descriptor.lookupMaybe(PDFName.of("FontFile2"), PDFRawStream);
  if (fontFile2) {
    try {
      return PDFLibRef.decodePDFRawStream(fontFile2).decode();
    } catch (_) { /* devam */ }
  }

  const fontFile3 = descriptor.lookupMaybe(PDFName.of("FontFile3"), PDFRawStream);
  if (fontFile3) {
    const subtype3 = pdfNameKey(fontFile3.dict.lookupMaybe(PDFName.of("Subtype"), PDFName));
    if (subtype3 === "OpenType") {
      try {
        return PDFLibRef.decodePDFRawStream(fontFile3).decode();
      } catch (_) { /* devam */ }
    }
  }

  return null;
}

// Sayfanin /Resources/Font sozlugunu tarar; isim alaninin kalinligina
// (wantBold) en yakin eslesen fontu -- mumkunse gomulu font programiyla
// birlikte -- dondurur. Belgede tek font varsa dogrudan o secilir.
function analyzePageFontResources(PDFLibRef, context, resources, wantBold) {
  const { PDFName, PDFDict } = PDFLibRef;
  if (!(resources instanceof PDFDict)) return null;

  const fonts = resources.lookupMaybe(PDFName.of("Font"), PDFDict);
  if (!fonts) return null;

  let best = null;

  for (const [, fontRef] of fonts.entries()) {
    let fontDict;
    try {
      fontDict = context.lookup(fontRef, PDFDict);
    } catch (_) {
      continue;
    }

    const baseFontRaw = pdfNameKey(fontDict.lookupMaybe(PDFName.of("BaseFont"), PDFName)) || "";
    const baseFontName = baseFontRaw.replace(/^[A-Z]{6}\+/, ""); // "ABCDEF+" subset etiketini at

    let descriptor = null;
    try {
      descriptor = resolveFontDescriptor(PDFLibRef, context, fontDict);
    } catch (_) { /* yoksay */ }

    let flags = 0;
    if (descriptor) {
      try {
        flags = Number(descriptor.lookupMaybe(PDFName.of("Flags"), PDFLibRef.PDFNumber)?.asNumber() || 0);
      } catch (_) { /* yoksay */ }
    }

    const nameHints = classifyBaseFontName(baseFontName);
    const serif = Boolean(flags & FONT_FLAG_SERIF) || nameHints.serif;
    const bold = Boolean(flags & FONT_FLAG_FORCE_BOLD) || nameHints.bold;
    const italic = Boolean(flags & FONT_FLAG_ITALIC) || nameHints.italic;

    let program = null;
    try {
      program = extractFontProgram(PDFLibRef, context, descriptor);
    } catch (_) { /* yoksay */ }

    // Kalinlik tam eslesirse ve font gomuluyse en yuksek oncelik.
    const score = (bold === wantBold ? 2 : 0) + (program ? 1 : 0);
    if (!best || score > best.score) {
      best = { baseFontName, serif, bold, italic, program, score };
    }
  }

  return best;
}

/**
 * Bulunan alana ogrencinin adini isler; yeni PDF baytlarini dondurur.
 * Yazi boyutu alanin yuksekligiyle eslesir, sigmazsa kucultulur.
 * alignLeft: etiket sagina yazim (ortalama yerine soldan hizali).
 *
 * Yazi tipi secimi: once belgenin kendi font kaynaklari taranir.
 * Gomulu font programi bulunur ve sorunsuz kullanilabilirse (Turkce
 * karakterler dahil) AYNEN o font ile yazilir. Bulunamaz/kullanilamazsa
 * belgede tespit edilen uslup (serif/sans + kalinlik) ile en yakin
 * esleseh yedek fontla yazilir; hicbir font bilgisi cikarilamazsa
 * onceki davranis (kalinliga gore DejaVu Sans) korunur.
 */
async function personalizePdfWithName(arrayBuffer, analysis, fullName) {
  const PDFLibRef = loadPdfLib();
  const { PDFDocument, rgb } = PDFLibRef;

  const pdfDoc = await PDFDocument.load(arrayBuffer, { ignoreEncryption: true });
  pdfDoc.registerFontkit(fontkit);

  try {
    stripStandaloneReplacementTextBlocks(pdfDoc, PDFLibRef);
  } catch (error) {
    console.warn("PDF yer tutucu metni kaldirilamadi:", error);
  }

  const pages = pdfDoc.getPages();
  const page = pages[Math.min(analysis.pageIndex || 0, pages.length - 1)];

  const wantBold = analysis.bold === true;
  let font = null;

  try {
    const resources = page.node?.Resources?.();
    const fontInfo = analyzePageFontResources(PDFLibRef, pdfDoc.context, resources, wantBold);

    if (fontInfo?.program?.length) {
      try {
        font = await pdfDoc.embedFont(fontInfo.program, { subset: true });
        font.widthOfTextAtSize(fullName, 12); // Turkce karakter uyumlulugunu hemen sina.
      } catch (embedError) {
        console.warn("Belgenin gomulu fontu kullanilamadi, uslup eslestirmesine geciliyor:", embedError);
        font = null;
      }
    }

    if (!font && fontInfo) {
      const fontBytes = getFontBytes(fontInfo.bold, fontInfo.serif);
      font = await pdfDoc.embedFont(fontBytes, { subset: true });
    }
  } catch (error) {
    console.warn("Sayfa font kaynaklari analiz edilemedi, varsayilan stil kullanilacak:", error);
  }

  if (!font) {
    const fontBytes = getFontBytes(wantBold, false);
    font = await pdfDoc.embedFont(fontBytes, { subset: true });
  }

  let size = Math.min(Math.max(analysis.height * 0.92, 9), 64);
  let textWidth = font.widthOfTextAtSize(fullName, size);

  // Genis bir alan varsa ve isim sigmiyorsa alana sigacak kadar kucult.
  if (analysis.width > 30 && textWidth > analysis.width) {
    size = Math.max((size * analysis.width) / textWidth, 8);
    textWidth = font.widthOfTextAtSize(fullName, size);
  }

  const x = analysis.alignLeft
    ? analysis.x
    : analysis.x + (analysis.width - textWidth) / 2;
  const y = analysis.y + Math.max(1.5, analysis.height * 0.08);

  page.drawText(fullName, { x, y, size, font, color: rgb(0.09, 0.11, 0.16) });

  return pdfDoc.save();
}

module.exports = { analyzePdfTemplate, personalizePdfWithName };
