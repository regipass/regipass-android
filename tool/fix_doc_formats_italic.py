"""club-documents.html: "Desteklenen Formatlar" satirini kismi italik yapar.

Once tamami <em> icindeydi (hepsi italik). Simdi etiket duz, format listesi
italik olacak sekilde iki parcaya bolunur. Iki ayri i18n anahtari kullanilir
ki her iki parca da cevrilebilsin.
"""
import re
import sys

HTML = 'club-documents.html'
CSS = 'css/club-documents.css'
LANG = 'js/modules/i18n/language.js'

OLD_EM = (
    '<em class="doc-drop-format" data-i18n="clubDocuments.upload.formats">'
    'Desteklenen Formatlar: PDF, JPEG, PNG (En fazla 5MB)</em>'
)
NEW_SPAN = (
    '<span class="doc-drop-format">'
    '<span data-i18n="clubDocuments.upload.formatsLabel">Desteklenen Formatlar:</span> '
    '<em data-i18n="clubDocuments.upload.formatsList">PDF, JPEG, PNG (En fazla 5MB)</em>'
    '</span>'
)

OLD_CSS = """.doc-drop-format {
  font-size: 12px;
  color: #8a8384;
  font-style: italic;
  font-weight: 500;
}"""
NEW_CSS = """.doc-drop-format {
  font-size: 12px;
  color: #8a8384;
  font-style: normal;
  font-weight: 500;
}

/* Yalnizca format listesi italik; "Desteklenen Formatlar:" etiketi duz kalir. */
.doc-drop-format em {
  font-style: italic;
}"""


def read(path: str) -> str:
    return open(path, encoding='utf-8-sig', newline='').read()


def write(path: str, text: str) -> None:
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(text)


def add_keys(src: str, lang: str, label: str, formats: str) -> str:
    """Yeni iki anahtari ilgili dil blogundaki mevcut formats satirindan
    hemen sonra ekler."""
    anchor = re.search(
        r'(\n(\s*)"clubDocuments\.upload\.formats":\s*"[^"]*",)',
        src[_block_start(src, lang):_block_end(src, lang)],
    )
    if not anchor:
        raise SystemExit(f'{lang}: clubDocuments.upload.formats bulunamadi')

    offset = _block_start(src, lang)
    insert_at = offset + anchor.end(1)
    indent = anchor.group(2)
    addition = (
        f'\n{indent}"clubDocuments.upload.formatsLabel": "{label}",'
        f'\n{indent}"clubDocuments.upload.formatsList": "{formats}",'
    )
    return src[:insert_at] + addition + src[insert_at:]


def _block_start(src: str, lang: str) -> int:
    return re.search(r'\b' + lang + r':\s*\{', src).end()


def _block_end(src: str, lang: str) -> int:
    i = _block_start(src, lang)
    depth = 1
    while depth > 0:
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
        i += 1
    return i - 1


def main() -> None:
    dry = '--dry-run' in sys.argv

    html = read(HTML)
    count = html.count(OLD_EM)
    html = html.replace(OLD_EM, NEW_SPAN)
    print(f'HTML: {count} yerde format satiri bolundu')

    css = read(CSS)
    css_ok = OLD_CSS in css
    css = css.replace(OLD_CSS, NEW_CSS)
    print(f'CSS: {"guncellendi" if css_ok else "KALIP BULUNAMADI"}')

    lang = read(LANG)
    if '"clubDocuments.upload.formatsLabel"' in lang:
        print('language.js: anahtarlar zaten var')
    else:
        lang = add_keys(lang, 'tr', 'Desteklenen Formatlar:', 'PDF, JPEG, PNG (En fazla 5MB)')
        lang = add_keys(lang, 'en', 'Supported formats:', 'PDF, JPEG, PNG (5MB max)')
        print('language.js: 2 anahtar x 2 dil eklendi')

    if dry:
        print('(dry-run — yazilmadi)')
        return

    write(HTML, html)
    write(CSS, css)
    write(LANG, lang)
    print('yazildi')


if __name__ == '__main__':
    main()
