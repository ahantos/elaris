"""bakeoff.png: the comparison sheet. Run from the work folder: python tools/bakeoff.py

Rows:
  1  A1, A2 and the previous fighter_tall at 1x 2x 4x 8x on the dark floor
  2  the same on the mid floor
  3  each one in bronze, and each one with helmet and shield removed (4x)
  4  item pictures at 4x, and the axe drawn in Aseprite
  5  the swing: strip from pxl, and the sheet exported from the Aseprite file
"""
import os
from PIL import Image, ImageDraw

DARK = (0x3a, 0x32, 0x2c)
MID = (0x56, 0x48, 0x3a)
PAGE = (24, 22, 22)
INK = (236, 226, 200)
DIM = (170, 160, 140)


def rgba(p):
    return Image.open(p).convert("RGBA")


def on(bg, im, s, pad=2):
    t = Image.new("RGBA", (im.size[0] + 2 * pad, im.size[1] + 2 * pad), bg + (255,))
    t.alpha_composite(im, (pad, pad))
    return t.resize((t.size[0] * s, t.size[1] * s), Image.NEAREST)


def prev_without_helmet_and_shield():
    d = "prev/out/sprites/fighter_tall"
    out = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    for n in ["body", "trousers", "boots", "jerkin", "near_arm", "sleeve", "sword"]:
        out.alpha_composite(rgba(os.path.join(d, n + ".png")))
    return out


FIG = [
    ("A1  theory only (the style the owner chose)", rgba("out/sprites/a1.png"), rgba("out/sprites/a1_bronze.png"),
     rgba("out/sprites/a1_nohelm_noshield.png")),
    ("A2  reference first, chunkier (turned down)", rgba("out/sprites/a2.png"), rgba("out/sprites/a2_bronze.png"),
     rgba("out/sprites/a2_nohelm_noshield.png")),
    ("Previous attempt  fighter_tall", rgba("prev/out/sprites/fighter_tall.png"),
     rgba("prev/out/sprites/fighter_tall_bronze.png"), prev_without_helmet_and_shield()),
]

GROUP_W = 6 + sum((32 + 4) * s + 6 for s in (1, 2, 4, 8))      # one figure at four sizes
W = 12 + 3 * GROUP_W + 12
blocks = []                                                     # (height, draw function)


def sizes_row(bg, title):
    h = (48 + 4) * 8 + 34

    def draw(sheet, d, y):
        d.text((12, y), title, fill=INK)
        for gi, (name, im, _, _) in enumerate(FIG):
            x = 12 + gi * GROUP_W
            d.text((x, y + 14), name, fill=DIM)
            for s in (1, 2, 4, 8):
                cell = on(bg, im, s)
                sheet.alpha_composite(cell, (x, y + 30 + (48 + 4) * 8 - cell.size[1]))
                x += cell.size[0] + 6
    return h, draw


def variants_row():
    h = (48 + 4) * 4 + 34

    def draw(sheet, d, y):
        d.text((12, y), "Bronze by palette swap, and with helmet and shield removed, 4x, dark floor then mid floor", fill=INK)
        for gi, (name, _, bronze, bare) in enumerate(FIG):
            x = 12 + gi * GROUP_W
            for label, im, bg in (("bronze", bronze, DARK), ("no helmet, no shield", bare, DARK),
                                  ("bronze", bronze, MID)):
                cell = on(bg, im, 4)
                d.text((x, y + 14), label, fill=DIM)
                sheet.alpha_composite(cell, (x, y + 30))
                x += cell.size[0] + 6
    return h, draw


def items_row():
    h = (96 + 4) * 4 + 34
    items = [
        ("longsword (first)", rgba("out/sprites/longsword.png"), DARK),
        ("longsword_slim", rgba("out/sprites/longsword_slim.png"), DARK),
        ("longsword_final", rgba("out/sprites/longsword_final.png"), DARK),
        ("longsword_final, mid", rgba("out/sprites/longsword_final.png"), MID),
    ]
    axe = [
        ("A1 with the axe", rgba("ase/out/a1_axe.png"), DARK),
        ("axe, mid floor", rgba("ase/out/a1_axe.png"), MID),
        ("axe layer alone", rgba("ase/out/weapon_axe.png"), DARK),
        ("axe in bronze", rgba("ase/out/a1_axe_bronze.png"), DARK),
        ("A1 with the sword", rgba("out/sprites/a1.png"), DARK),
    ]

    def draw(sheet, d, y):
        d.text((12, y), "Item pictures at 4x (32 x 96, A1's steel, bronze and leather)", fill=INK)
        x = 12
        for label, im, bg in items:
            cell = on(bg, im, 4)
            d.text((x, y + 14), label, fill=DIM)
            sheet.alpha_composite(cell, (x, y + 30))
            x += cell.size[0] + 6
        x += 24
        d.text((x, y), "Bearded axe, drawn in Aseprite as a new layer on A1 (same grip point as the sword), 4x", fill=INK)
        for label, im, bg in axe:
            cell = on(bg, im, 4)
            d.text((x, y + 14), label, fill=DIM)
            sheet.alpha_composite(cell, (x, y + 30))
            x += cell.size[0] + 6
    return h, draw


def strip_row(path, title, scale=2):
    im = rgba(path)
    h = im.size[1] * scale + 22

    def draw(sheet, d, y):
        d.text((12, y), title, fill=INK)
        cell = Image.new("RGBA", im.size, DARK + (255,))
        cell.alpha_composite(im)
        sheet.alpha_composite(cell.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST), (12, y + 16))
    return h, draw


blocks.append(sizes_row(DARK, "1x  2x  4x  8x on the dark floor #3a322c"))
blocks.append(sizes_row(MID, "1x  2x  4x  8x on the mid floor #56483a"))
blocks.append(variants_row())
blocks.append(items_row())
blocks.append(strip_row("out/anims/a1_swing.png",
                        "A1 sword swing, 8 frames, 167 83 167 83 83 167 167 83 ms: frame strip from pxl, 2x"))
blocks.append(strip_row("a1_swing_ase_sheet.png",
                        "The same swing exported from a1_swing.aseprite (frames, tag 'swing', gear on its own layers): identical pixel for pixel, 2x"))

H = 12 + sum(h + 14 for h, _ in blocks)
sheet = Image.new("RGBA", (max(W, 12 + 640 * 2 + 12), H), PAGE + (255,))
d = ImageDraw.Draw(sheet)
y = 12
for h, draw in blocks:
    draw(sheet, d, y)
    y += h + 14
sheet.convert("RGB").save("bakeoff.png")
print("bakeoff.png", sheet.size)
