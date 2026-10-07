"""Draws the Nuvara launcher icon from the brand mark and writes every Android, iOS, web and Windows size.

Run from the project root:  python tool/make_icons.py   (needs Pillow)

The mark (an orange "u" standing on two feet, with two sky-blue dots: the "ü" of nüvara) was traced from the
brand artwork into tool/nuvara_mark.json. lib/widgets/brand.dart paints the same geometry in the app.
The icon is the full-colour mark on Nuvara navy, with soft sky and orange light behind it.
"""
import json
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supersampling for smooth edges

NAVY = (1, 0, 57)        # #010039, the wordmark
INDIGO = (27, 31, 122)   # #1B1F7A, the lighter end of the app's hero gradient
ORANGE = (234, 80, 30)   # #EA501E, the "u"
SKY = (54, 169, 224)     # #36A9E0, the dots

with open(os.path.join(ROOT, 'tool', 'nuvara_mark.json')) as f:
    MARK = json.load(f)  # {"u": [[x, y], ...], "circles": [[x, y, r], ...]}; centred, 1 unit = mark height


def draw_mark(img, cx, cy, height, mono=None):
    """The mark centred on (cx, cy), [height] pixels tall."""
    d = ImageDraw.Draw(img)
    d.polygon([(cx + x * height, cy + y * height) for x, y in MARK['u']], fill=mono or ORANGE)
    for x, y, r in MARK['circles']:
        d.ellipse([cx + (x - r) * height, cy + (y - r) * height, cx + (x + r) * height, cy + (y + r) * height], fill=mono or SKY)


def background(size, rounded=0.0):
    """Navy-to-indigo gradient with soft sky light top-right and warm orange light bottom-left."""
    s = size * SS
    n = 128  # the gradient is smooth: paint it small and scale up
    small = Image.new('RGBA', (n, n))
    px = small.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2 * (n - 1))
            px[x, y] = tuple(int(NAVY[i] * (1 - t) + INDIGO[i] * t) for i in range(3)) + (255,)
    img = small.resize((s, s), Image.BICUBIC)
    glow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse([s * 0.55, -s * 0.45, s * 1.45, s * 0.45], fill=SKY + (70,))
    g.ellipse([-s * 0.5, s * 0.6, s * 0.45, s * 1.5], fill=ORANGE + (60,))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.14))
    img = Image.alpha_composite(img, glow)
    if rounded:
        mask = Image.new('L', (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * rounded), fill=255)
        img.putalpha(mask)
    return img


def with_shadow(layer, s):
    """A soft navy shadow under the mark, for depth on the icon."""
    alpha = layer.split()[3]
    shadow = Image.new('RGBA', layer.size, (0, 0, 20, 0))
    shadow.putalpha(alpha.point(lambda a: int(a * 0.45)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(s * 0.018))
    out = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, int(s * 0.014)))
    out.alpha_composite(layer)
    return out


def mark_layer(size, mark_height, mono=None, shadow=False):
    s = size * SS
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw_mark(img, s / 2, s / 2, s * mark_height, mono)
    return with_shadow(img, s) if shadow else img


def full_icon(size, rounded=0.0, mark_height=0.58):
    s = size * SS
    img = background(size, rounded)
    mark = mark_layer(size, mark_height, shadow=True)
    if rounded:
        mark.putalpha(Image.composite(mark.split()[3], Image.new('L', mark.size, 0), img.split()[3]))
    img.alpha_composite(mark)
    return img.resize((size, size), Image.LANCZOS)


def mark_only(size, mark_height, mono=None):
    return mark_layer(size, mark_height, mono, shadow=mono is None).resize((size, size), Image.LANCZOS)


def save(img, *parts, **kw):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True, **kw) if not path.endswith('.ico') else img.save(path, **kw)
    print('wrote', os.path.relpath(path, ROOT))


def main():
    save(full_icon(1024), 'assets', 'brand', 'icon.png')
    save(mark_only(1024, 0.92), 'assets', 'brand', 'mark.png')

    # ---- Android: legacy icons (pre-8.0), adaptive layers and the themed (monochrome) layer ----------
    res = ('android', 'app', 'src', 'main', 'res')
    legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for dpi, px in legacy.items():
        save(full_icon(px, rounded=0.22), *res, f'mipmap-{dpi}', 'ic_launcher.png')
        # Adaptive layers are 108dp; only the centre 66dp circle is guaranteed visible.
        layer = px * 108 // 48
        save(mark_only(layer, 0.42), *res, f'mipmap-{dpi}', 'ic_launcher_foreground.png')
        save(background(layer).resize((layer, layer), Image.LANCZOS), *res, f'mipmap-{dpi}', 'ic_launcher_background.png')
        save(mark_only(layer, 0.42, mono=(255, 255, 255)), *res, f'mipmap-{dpi}', 'ic_launcher_monochrome.png')

    # ---- iOS: full-bleed square (iOS applies its own mask; alpha is not allowed) --------------------
    appicon = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    with open(os.path.join(appicon, 'Contents.json')) as f:
        images = json.load(f)['images']
    for im in images:
        pts = float(im['size'].split('x')[0])
        px = round(pts * int(im['scale'][0]))
        save(full_icon(px).convert('RGB'), 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', im['filename'])

    # The native launch screens are plain navy (no image): the in-app splash animates the mark in from
    # nothing, so showing it natively first would make it vanish and reappear. iOS's storyboard still names
    # LaunchImage, so it stays a transparent pixel.
    for suffix in ('', '@2x', '@3x'):
        save(Image.new('RGBA', (1, 1), (0, 0, 0, 0)), 'ios', 'Runner', 'Assets.xcassets', 'LaunchImage.imageset', f'LaunchImage{suffix}.png')

    # ---- Web: favicon, PWA icons (rounded) and maskable icons (full bleed, mark in the safe zone) ---------
    save(full_icon(64, rounded=0.22), 'web', 'favicon.png')
    for px in (192, 512):
        save(full_icon(px, rounded=0.22), 'web', 'icons', f'Icon-{px}.png')
        save(full_icon(px, mark_height=0.46), 'web', 'icons', f'Icon-maskable-{px}.png')

    # ---- Windows: one .ico with every size the shell asks for ------------------------------------------
    big = full_icon(256, rounded=0.2)
    save(big, 'windows', 'runner', 'resources', 'app_icon.ico', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


if __name__ == '__main__':
    main()
