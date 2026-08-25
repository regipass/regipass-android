"""regipass_kirmizi.svg -> assets/brand/regipass_logo.svg (zeminsiz tam logo).

Kaynak dosya kelime logosunu maske + filtre zinciriyle ciziyor; flutter_svg
`feColorMatrix` destekelemedigi icin dogrudan kullanilamiyor. Burada ayni
kompozisyon duz elemanlara aciliyor:

  * "R" sembolu  -> tek dolu path (fill #a4161a)
  * "egipass"    -> maskedeki harf yollari, radyal gradyanla doldurulmus

Kaynaktaki siyah kare zemin BILEREK alinmiyor: logo uygulamada acik ve koyu
temada, farkli renkteki ekranlarin uzerinde duruyor; kare zemin oralarda
yamaliyordu. Bunun yerine viewBox icerigin sinirlarina daraltiliyor, boylece
logonun etrafinda bos saydam alan da kalmiyor.

Gradyan duraklari orijinalde ~120 adet; goze ayni gelen 9 durak birakiliyor.
"""
import re
import sys

SRC = r'C:\Users\5sana\Downloads\regipass_kirmizi.svg'
OUT = sys.argv[1] if len(sys.argv) > 1 else 'assets/brand/regipass_logo.svg'

src = open(SRC, encoding='utf-8').read()

# "R" sembolu: fill="#a4161a" olan tek path.
mark = re.search(r'<path\s+fill="#a4161a"\s+d="([^"]+)"', src).group(1).strip()

# Kelime markasi: maske icindeki harf yollari (her biri kendi translate'inde).
mask = src[src.find('<mask id="eafac0b6c0"'):src.find('</mask>')]
glyphs = re.findall(
    r'<g transform="translate\(([-\d.]+),\s*([-\d.]+)\)">\s*<g\s*>\s*<path d="([^"]+)"',
    mask,
)
assert len(glyphs) == 7, len(glyphs)

# Radyal gradyan: geometri aynen, duraklar seyreltilmis.
grad = re.search(r'<radialGradient([^>]*)id="35652bfed3"([^>]*)>(.*?)</radialGradient>',
                 src, re.S)
gattrs = (grad.group(1) + grad.group(2)).strip()
gattrs = re.sub(r'\s*id="[^"]*"', '', gattrs)
stops = re.findall(r'stop-color="([^"]+)"\s*offset="([^"]+)"', grad.group(3))
keep = [stops[round(i * (len(stops) - 1) / 8)] for i in range(9)]


def to_hex(rgb: str) -> str:
    a, b, c = re.findall(r'([\d.]+)%', rgb)
    return '#%02x%02x%02x' % tuple(round(float(v) * 255 / 100) for v in (a, b, c))


# Icerigin sinirlari: sembol kutusu kaynaktaki clipPath'ten (bkz.
# extract_logo_mark.py), yazinin sag kenari harf yollarindan geliyor. `pad`
# harflerin kenara degmemesi icin kucuk bir nefes payi.
PAD = 6.0
BOX = (147.515625, 517.0, 1334.022652, 983.0)  # x0, y0, x1, y1
vb = (BOX[0] - PAD, BOX[1] - PAD,
      BOX[2] - BOX[0] + PAD * 2, BOX[3] - BOX[1] + PAD * 2)

parts = [
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'viewBox="%g %g %g %g" width="%g" height="%g">' % (vb + vb[2:]),
    '<defs><radialGradient id="rpWord" ' + gattrs + '>',
]
parts += ['<stop offset="%s" stop-color="%s"/>' % (off, to_hex(col))
          for col, off in keep]
parts += [
    '</radialGradient></defs>',
    '<path fill="#a4161a" fill-rule="nonzero" d="%s"/>' % mark,
    '<g transform="translate(206,405)">',
]
parts += ['<g transform="translate(%s,%s)"><path fill="url(#rpWord)" '
          'fill-rule="nonzero" d="%s"/></g>' % (x, y, d) for x, y, d in glyphs]
parts += ['</g>', '</svg>']

open(OUT, 'w', encoding='utf-8').write(''.join(parts))
print(OUT, 'yazildi')
