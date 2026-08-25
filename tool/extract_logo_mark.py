"""regipass_kirmizi.svg icindeki "R" sembolunu tek basina bir SVG'ye cikarir.

Kaynak dosya kelime logosunun tamami: "R" sembolu (tek, dolu path) + "egipass"
yazisi (yol olarak cizilmis, radyal gradyanli, maske/filtre zinciriyle).
Uygulamada sembol ile yazi ayri elemanlar oldugu icin yalnizca sembol gerekli;
yazi canli metin olarak kaliyor.

Sembolun sinirlarini kaynaktaki clipPath tanimindan aliyoruz:
    <path d="M 152 517 L 549.515625 517 L 549.515625 983 L 152 983 Z"/>
"""
import re
import sys

SRC = r'C:\Users\5sana\Downloads\regipass_kirmizi.svg'

# Kaynaktaki clipPath 7c64a51ff7 sembolun kutusunu veriyor.
BOX = (152.0, 517.0, 549.515625, 983.0)  # x0, y0, x1, y1


def main() -> None:
    out_path = sys.argv[1]
    src = open(SRC, encoding='utf-8').read()

    # Sembol: fill="#a4161a" olan tek path.
    m = re.search(r'<path\s+fill="#a4161a"\s+d="([^"]+)"', src)
    if not m:
        raise SystemExit('sembol path bulunamadi')
    d = m.group(1).strip()

    x0, y0, x1, y1 = BOX
    # Kucuk bir nefes payi: sembol kutunun kenarina degmesin.
    pad = 6.0
    vb_x = x0 - pad
    vb_y = y0 - pad
    vb_w = (x1 - x0) + pad * 2
    vb_h = (y1 - y0) + pad * 2

    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{vb_x:g} {vb_y:g} {vb_w:g} {vb_h:g}" '
        'fill="none">\n'
        '  <!-- Regipass sembolu. Renk currentColor ile disaridan verilir; '
        'boylece koyu zeminde beyaz, acik zeminde marun kullanilabilir. -->\n'
        f'  <path fill="currentColor" fill-rule="nonzero" d="{d}"/>\n'
        '</svg>\n'
    )

    open(out_path, 'w', encoding='utf-8', newline='\n').write(svg)
    print(f'yazildi: {out_path}')
    print(f'viewBox: {vb_x:g} {vb_y:g} {vb_w:g} {vb_h:g}')
    print(f'path uzunlugu: {len(d)} karakter')


if __name__ == '__main__':
    main()
