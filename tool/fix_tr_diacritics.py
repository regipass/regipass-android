"""language.js tr blogundaki ASCII Turkce metinleri duzeltilmis halleriyle degistirir.

Yalnizca tr blogu icindeki degerlere dokunur; en blogu ve anahtar adlari
degismez. Degistirilen her deger, tr_fixes.json'daki karsiligiyla birebir
yer degistirir (kismi/regex esleme yok, yanlis yere yazma riski sifir).

Kullanim:
    python tool/fix_tr_diacritics.py <fixes.json> [--dry-run]
Calisma dizini: Desktop/REGIPASS (language.js yolu buna gore)
"""
import json
import re
import sys

LANGUAGE_JS = 'js/modules/i18n/language.js'


def tr_block_span(src: str) -> tuple[int, int]:
    """tr: { ... } blogunun (baslangic, bitis) indekslerini dondurur."""
    m = re.search(r'\btr:\s*\{', src)
    if not m:
        raise SystemExit('tr blogu bulunamadi')
    start = m.end()
    depth = 1
    i = start
    while depth > 0:
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
        i += 1
    return start, i - 1


def escape_js(value: str) -> str:
    """JS cift tirnakli dize icin kacis."""
    return value.replace('\\', '\\\\').replace('"', '\\"')


def main() -> None:
    fixes_path = sys.argv[1]
    dry_run = '--dry-run' in sys.argv

    fixes = json.load(open(fixes_path, encoding='utf-8'))

    # newline='' : satir sonlarini oldugu gibi oku/yaz. Aksi halde Python
    # LF dosyayi Windows'ta CRLF olarak yazar ve tum dosya degismis gorunur —
    # 139 deger degisikligi 1253 satirlik bir diff'e donusur.
    src = open(LANGUAGE_JS, encoding='utf-8-sig', newline='').read()
    start, end = tr_block_span(src)
    block = src[start:end]

    applied = 0
    missing = []
    unchanged = []

    for key, new_value in fixes.items():
        # Anahtari tr blogunda bul, degerini degistir.
        pattern = re.compile(
            r'("' + re.escape(key) + r'":\s*")((?:[^"\\]|\\.)*)(")'
        )
        match = pattern.search(block)
        if not match:
            missing.append(key)
            continue
        if match.group(2) == escape_js(new_value):
            unchanged.append(key)
            continue
        block = (
            block[:match.start()]
            + match.group(1) + escape_js(new_value) + match.group(3)
            + block[match.end():]
        )
        applied += 1

    print(f'uygulanan: {applied}')
    if unchanged:
        print(f'zaten dogru: {len(unchanged)}')
    if missing:
        print(f'ANAHTAR BULUNAMADI ({len(missing)}): ' + ', '.join(missing[:10]))

    if dry_run:
        print('(dry-run — dosya yazilmadi)')
        return

    with open(LANGUAGE_JS, 'w', encoding='utf-8', newline='') as f:
        f.write(src[:start] + block + src[end:])
    print(f'{LANGUAGE_JS} guncellendi')


if __name__ == '__main__':
    main()
