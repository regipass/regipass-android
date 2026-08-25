"""replace_brand_mark.py degisikligini geri alir.

Gerekce: logo bu arada theme.css tarafinda `.brand-logo::before` ile tek
parca arka plan gorseli olarak cozuldu ve `.brand-mark` display:none yapildi.
HTML'e gomulen buyuk path verisi artik hem olu hem de dokumante edilen
"HTML degismeden logo guncellenebilir" yaklasimiyla celisiyor.
"""
import glob
import re
import sys

ORIGINAL_SVG = (
    '<svg viewBox="0 0 24 24">'
    '<path d="M7 20V5h6a4.5 4.5 0 0 1 0 9H7"/>'
    '<path d="M11 14l6 6"/>'
    '</svg>'
)

# replace_brand_mark.py'nin yazdigi bicim.
INSERTED = re.compile(
    r'<svg class="brand-glyph" viewBox="[^"]*" aria-hidden="true">'
    r'<path d="[^"]*"/>'
    r'</svg>'
)


def main() -> None:
    dry = '--dry-run' in sys.argv
    changed = []

    for path in sorted(glob.glob('*.html')):
        src = open(path, encoding='utf-8-sig', newline='').read()
        new_src, count = INSERTED.subn(ORIGINAL_SVG, src)
        if count == 0:
            continue
        changed.append((path, count))
        if not dry:
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(new_src)

    print(f'geri alinan dosya: {len(changed)}')
    for path, count in changed:
        print(f'  {path} ({count})')
    if dry:
        print('(dry-run — yazilmadi)')


if __name__ == '__main__':
    main()
