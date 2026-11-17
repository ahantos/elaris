"""Enlarged contact sheet of reference tiles for study.

usage: python -I contact.py out.png SCALE COLS item [item ...]
An item is a PNG path, or several paths joined with '+' (composited in that order).
"""
import os
import sys
from PIL import Image, ImageDraw

BG = (0x56, 0x48, 0x3a)
PAGE = (24, 22, 22)


def load(item):
    parts = item.split("+")
    base = Image.open(parts[0]).convert("RGBA")
    for p in parts[1:]:
        o = Image.open(p).convert("RGBA")
        if o.size != base.size:
            c = Image.new("RGBA", base.size, (0, 0, 0, 0))
            c.alpha_composite(o.crop((0, 0, min(o.size[0], base.size[0]), min(o.size[1], base.size[1]))))
            o = c
        base.alpha_composite(o)
    return base


def main():
    out, scale, cols = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    items = sys.argv[4:]
    ims = [load(i) for i in items]
    cw = max(i.size[0] for i in ims) * scale + 8
    ch = max(i.size[1] for i in ims) * scale + 20
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw, rows * ch), PAGE)
    d = ImageDraw.Draw(sheet)
    for n, (im, item) in enumerate(zip(ims, items)):
        x, y = (n % cols) * cw, (n // cols) * ch
        tile = Image.new("RGBA", im.size, BG + (255,))
        tile.alpha_composite(im)
        tile = tile.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST).convert("RGB")
        sheet.paste(tile, (x + 4, y + 16))
        label = "+".join(os.path.splitext(os.path.basename(p))[0] for p in item.split("+"))
        d.text((x + 4, y + 2), label[:int(cw / 6)], fill=(220, 210, 190))
    sheet.save(out)
    print(out, sheet.size)


main()
