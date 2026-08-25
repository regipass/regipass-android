"""Web'deki marka sembolunu yeni Regipass sembolu ile degistirir.

Eski sembol: 24x24 kutuda cizgi (stroke) tabanli iki path.
Yeni sembol: regipass_kirmizi.svg'den ayiklanan dolu (fill) tek path.

Onemli: eski sembol theme.css'te `stroke: currentColor; fill: none` ile
boyanyordu. Yeni sembol dolu oldugu icin CSS de guncellenmeli — bu betik
yalnizca HTML'leri degistirir, CSS ayrica elle duzenlenir.
"""
import glob
import re
import sys

OLD_SVG = (
    '<svg viewBox="0 0 24 24">'
    '<path d="M7 20V5h6a4.5 4.5 0 0 1 0 9H7"/>'
    '<path d="M11 14l6 6"/>'
    '</svg>'
)


def build_new_svg(mark_path: str, view_box: str) -> str:
    # class="brand-glyph": theme.css bu sinifa dolu boyama uygular.
    return (
        f'<svg class="brand-glyph" viewBox="{view_box}" aria-hidden="true">'
        f'<path d="{mark_path}"/>'
        '</svg>'
    )


def main() -> None:
    mark_svg_path = sys.argv[1]
    dry = '--dry-run' in sys.argv

    mark_src = open(mark_svg_path, encoding='utf-8').read()
    view_box = re.search(r'viewBox="([^"]+)"', mark_src).group(1)
    mark_path = re.search(r'<path[^>]*\sd="([^"]+)"', mark_src).group(1)
    new_svg = build_new_svg(mark_path, view_box)

    changed = []
    skipped = []

    for path in sorted(glob.glob('*.html')):
        src = open(path, encoding='utf-8-sig', newline='').read()
        if OLD_SVG not in src:
            skipped.append(path)
            continue
        count = src.count(OLD_SVG)
        src = src.replace(OLD_SVG, new_svg)
        changed.append((path, count))
        if not dry:
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(src)

    print(f'degisen dosya: {len(changed)}')
    for path, count in changed:
        print(f'  {path} ({count} yer)')
    if skipped:
        print(f'sembol icermeyen: {len(skipped)} dosya')
    if dry:
        print('(dry-run — yazilmadi)')


if __name__ == '__main__':
    main()
