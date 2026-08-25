"""assets/brand/regipass_mark.svg -> Android/iOS uygulama simgeleri.

Uygulama simgesi marka sembolunun ("R") kendisi: marka gradyanindan bir zemin
(BrandColors.red -> BrandColors.redDark, 135deg) ve uzerinde beyaz sembol.

Uretilenler:
  * android/app/src/main/res/mipmap-*/ic_launcher.png     (eski usul simge)
  * ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png   (alfasiz, tam kare)

Android 8+ adaptif simgeyi kullanir ve o tamamen vektordur (elle yazildi;
bkz. res/mipmap-anydpi-v26/ic_launcher.xml). Buradaki PNG'ler yalnizca daha
eski surumler icin; adaptif on plan PNG'si bilerek uretilmiyor.

Ortamda cairosvg/inkscape/ImageMagick yok; sembolun yolu (yalnizca M/L/C/Z,
mutlak koordinat) burada elle taranip Pillow ile cizdiriliyor: egriler duz
parcalara bolunuyor, sekil yuksek cozunurlukte doldurulup asagi orneklenerek
kenar yumusatmasi elde ediliyor.
"""
from __future__ import annotations

import json
import os
import re

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARK_SVG = os.path.join(ROOT, 'assets', 'brand', 'regipass_mark.svg')

# BrandColors.red -> BrandColors.redDark (lib/app/theme.dart)
GRAD_FROM = (0xE5, 0x38, 0x3B)
GRAD_TO = (0xBA, 0x18, 0x1B)
MARK_COLOR = (0xFF, 0xFF, 0xFF)

# Sembolun yuksekligi, tam kare simgenin kenarinin kaci kadar.
MARK_H_FULL = 0.56
# Adaptif on plan 108dp'lik tuvale cizilir, gorunen alan ortadaki 72dp.
# Maskelendikten sonra tam kare simgeyle ayni buyuklukte okunsun diye sembol
# 0.56 * 72/108 = 0.373 * 108dp ~ 40.32dp yuksekliginde. Bu deger burada
# uretilmiyor, res/drawable/ic_launcher_foreground.xml icine islenmis durumda;
# ikisi birlikte degismeli.
MARK_H_ADAPTIVE = MARK_H_FULL * 72.0 / 108.0
# Eski usul PNG'de kose yuvarlamasi (kenarin orani). Adaptif simgeyi
# okumayan baslaticilar kirpma yapmiyor; cip kare durmasin.
CORNER_R = 0.20

ANDROID_RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
# yogunluk -> eski usul simgenin kenari (px)
DENSITIES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}
IOS_ICONSET = os.path.join(
    ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')


# ── SVG yolu -> coklu cizgi ─────────────────────────────────────────────
def _flatten_cubic(p0, p1, p2, p3, steps):
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
        yield (a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
               a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1])


def parse_path(d: str, steps: int = 24):
    """M/L/C/Z (mutlak) iceren yolu alt-yollarin nokta listesine cevirir."""
    tokens = re.findall(r'[MLCZmlcz]|-?\d*\.?\d+(?:e[-+]?\d+)?', d)
    subpaths, cur, start, i = [], [], (0.0, 0.0), 0
    pos = (0.0, 0.0)
    while i < len(tokens):
        cmd = tokens[i]
        if cmd not in 'MLCZmlcz':
            raise ValueError(f'beklenmeyen belirtec: {cmd}')
        i += 1
        if cmd in 'Zz':
            if len(cur) > 2:
                subpaths.append(cur)
            cur, pos = [], start
            continue
        while i < len(tokens) and tokens[i] not in 'MLCZmlcz':
            if cmd in 'Mm':
                pos = (float(tokens[i]), float(tokens[i + 1]))
                i += 2
                if len(cur) > 2:
                    subpaths.append(cur)
                cur, start = [pos], pos
                cmd = 'L'  # M'den sonraki fazladan cift ciftler L sayilir
            elif cmd in 'Ll':
                pos = (float(tokens[i]), float(tokens[i + 1]))
                i += 2
                cur.append(pos)
            else:  # C
                p1 = (float(tokens[i]), float(tokens[i + 1]))
                p2 = (float(tokens[i + 2]), float(tokens[i + 3]))
                p3 = (float(tokens[i + 4]), float(tokens[i + 5]))
                i += 6
                cur.extend(_flatten_cubic(pos, p1, p2, p3, steps))
                pos = p3
    if len(cur) > 2:
        subpaths.append(cur)
    return subpaths


def signed_area(pts) -> float:
    s = 0.0
    for j in range(len(pts)):
        x0, y0 = pts[j]
        x1, y1 = pts[(j + 1) % len(pts)]
        s += x0 * y1 - x1 * y0
    return s / 2.0


def read_mark():
    src = open(MARK_SVG, encoding='utf-8').read()
    vb = [float(v) for v in
          re.search(r'viewBox="([^"]+)"', src).group(1).split()]
    d = re.search(r'\sd="([^"]+)"', src).group(1)
    return vb, parse_path(d)


# ── Sembol maskesi ─────────────────────────────────────────────────────
def render_mark_mask(height_px: int, supersample: int = 4) -> Image.Image:
    """Sembolu `height_px` yuksekliginde, kenari yumusatilmis 'L' maskesi yapar.

    nonzero dolgu kurali: en genis alt-yol disi belirler; ters yonde donen
    alt-yollar (R'nin gozu) delik olur.
    """
    (vx, vy, vw, vh), subpaths = read_mark()
    scale = height_px * supersample / vh
    w = max(1, round(vw * scale))
    h = max(1, round(vh * scale))

    shaped = [(signed_area(p), [((x - vx) * scale, (y - vy) * scale)
                                for x, y in p]) for p in subpaths]
    outer_sign = 1.0 if max(shaped, key=lambda s: abs(s[0]))[0] > 0 else -1.0
    # Dis konturlar once (genisten dara), delikler sonra.
    shaped.sort(key=lambda s: (-1 if (s[0] > 0) == (outer_sign > 0) else 1,
                               -abs(s[0])))

    img = Image.new('L', (w, h), 0)
    drw = ImageDraw.Draw(img)
    for area, pts in shaped:
        fill = 255 if (area > 0) == (outer_sign > 0) else 0
        drw.polygon(pts, fill=fill)

    if supersample > 1:
        img = img.resize((max(1, w // supersample), max(1, h // supersample)),
                         Image.LANCZOS)
    return img


# ── Zemin ──────────────────────────────────────────────────────────────
def gradient_square(size: int) -> Image.Image:
    """135deg (sol-ust -> sag-alt) dogrusal gradyanli kare."""
    span = 2 * size - 1
    luts = [bytes(round(a + (b - a) * i / (span - 1)) for i in range(span))
            for a, b in zip(GRAD_FROM, GRAD_TO)]
    bands = []
    for lut in luts:
        band = Image.new('L', (size, size))
        band.putdata(b''.join(lut[y:y + size] for y in range(size)))
        bands.append(band)
    return Image.merge('RGB', bands)


def rounded_mask(size: int, radius_ratio: float, supersample: int = 4):
    ss = size * supersample
    m = Image.new('L', (ss, ss), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (0, 0, ss - 1, ss - 1), radius=ss * radius_ratio, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def paste_mark(canvas: Image.Image, master: Image.Image, height_frac: float):
    size = canvas.size[0]
    h = max(1, round(size * height_frac))
    w = max(1, round(h * master.size[0] / master.size[1]))
    mask = master.resize((w, h), Image.LANCZOS)
    layer = Image.new('RGBA', (w, h), MARK_COLOR + (0,))
    layer.putalpha(mask)
    canvas.paste(layer, ((size - w) // 2, (size - h) // 2), layer)


def full_bleed_icon(size, master, rounded: bool) -> Image.Image:
    icon = gradient_square(size).convert('RGBA')
    paste_mark(icon, master, MARK_H_FULL)
    if rounded:
        icon.putalpha(rounded_mask(size, CORNER_R))
    return icon


def main() -> None:
    master = render_mark_mask(1024)

    # Android: yalnizca eski usul simge; 8+ adaptif vektoru kullaniyor.
    for density, legacy in DENSITIES.items():
        out_dir = os.path.join(ANDROID_RES, f'mipmap-{density}')
        os.makedirs(out_dir, exist_ok=True)
        full_bleed_icon(legacy, master, rounded=True).save(
            os.path.join(out_dir, 'ic_launcher.png'))
        print(f'mipmap-{density}: {legacy}px')

    # iOS: alfa kanali olmamali, kose yuvarlamasini sistem yapar.
    meta = json.load(open(os.path.join(IOS_ICONSET, 'Contents.json'),
                          encoding='utf-8'))
    sizes = {}
    for img in meta['images']:
        px = round(float(img['size'].split('x')[0]) * int(img['scale'][0]))
        sizes.setdefault(img['filename'], px)
    for name, px in sorted(sizes.items(), key=lambda kv: kv[1]):
        full_bleed_icon(px, master, rounded=False).convert('RGB').save(
            os.path.join(IOS_ICONSET, name))
        print(f'ios {name}: {px}px')


if __name__ == '__main__':
    main()
