"""Review sheet for one or more sprites.

usage: python view.py out.png sprite1.png [sprite2.png ...] [--big N]

Per sprite, one row: 1x 2x 4x 8x on the dark floor, the same on the mid floor,
then greyscale, one-colour silhouette and the mirrored facing.
"""
import sys
from PIL import Image, ImageDraw

DARK = (0x3a, 0x32, 0x2c)
MID = (0x56, 0x48, 0x3a)
PAGE = (24, 22, 22)


def on(bg, im, scale):
    w, h = im.size
    tile = Image.new("RGBA", (w + 4, h + 4), bg + (255,))
    tile.alpha_composite(im, (2, 2))
    return tile.resize(((w + 4) * scale, (h + 4) * scale), Image.NEAREST)


def grey(im):
    g = im.convert("LA").convert("RGBA")
    g.putalpha(im.getchannel("A"))
    return g


def sil(im, col=(214, 200, 170)):
    s = Image.new("RGBA", im.size, col + (255,))
    s.putalpha(im.getchannel("A").point(lambda a: 255 if a else 0))
    return s


def row(im, big=8):
    cells = []
    for bg in (DARK, MID):
        for s in (1, 2, 4, big):
            cells.append(on(bg, im, s))
    cells.append(on(MID, grey(im), 4))
    cells.append(on(DARK, sil(im), 4))
    cells.append(on(MID, im.transpose(Image.FLIP_LEFT_RIGHT), 4))
    h = max(c.size[1] for c in cells)
    w = sum(c.size[0] for c in cells) + 6 * (len(cells) + 1)
    out = Image.new("RGBA", (w, h + 12), PAGE + (255,))
    x = 6
    for c in cells:
        out.alpha_composite(c, (x, 6 + h - c.size[1]))
        x += c.size[0] + 6
    return out


def main():
    args = sys.argv[1:]
    big = 8
    if "--big" in args:
        i = args.index("--big")
        big = int(args[i + 1])
        del args[i:i + 2]
    out, files = args[0], args[1:]
    rows = [row(Image.open(f).convert("RGBA"), big) for f in files]
    W = max(r.size[0] for r in rows)
    H = sum(r.size[1] for r in rows)
    sheet = Image.new("RGBA", (W, H), PAGE + (255,))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.size[1]
    sheet.convert("RGB").save(out)
    print(out, sheet.size)


main()
