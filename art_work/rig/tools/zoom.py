"""Enlarged look at baked sprites, all layers of the piece laid together.
usage: python tools/zoom.py OUT.png SCALE key [key ...]     key = piece@angle  (e.g. weapon@45)
"""
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, FULL_GEAR, paste
from pal import FLOOR_DARK, FLOOR_MID, PAGE

a = sys.argv[1:]
floors = (FLOOR_DARK, FLOOR_MID)
if "--one" in a:
    a.remove("--one")
    floors = (FLOOR_DARK,)
out, S, keys = a[0], int(a[1]), a[2:]
rig = Rig()
tiles = []
for k in keys:
    piece, ang = k.split("@")
    ang = int(ang)
    ls = [l for l in rig.layers(FULL_GEAR) if l["piece"] == piece]
    ims = [rig.sprite("%s@%d" % (l["sprite"], ang)) for l in ls]
    x0 = min(o[0] for _, o in ims); y0 = min(o[1] for _, o in ims)
    x1 = max(o[0] + im.size[0] for im, o in ims); y1 = max(o[1] + im.size[1] for im, o in ims)
    for bg in floors:
        t = Image.new("RGBA", (x1 - x0 + 2, y1 - y0 + 2), bg + (255,))
        for im, o in ims:
            paste(t, im, o[0] - x0 + 1, o[1] - y0 + 1)
        tiles.append((k, t.convert("RGB").resize((t.size[0] * S, t.size[1] * S), Image.NEAREST)))
W = sum(t.size[0] + 8 for _, t in tiles) + 8
H = max(t.size[1] for _, t in tiles) + 24
sheet = Image.new("RGB", (W, H), PAGE)
d = ImageDraw.Draw(sheet)
x = 8
for k, t in tiles:
    sheet.paste(t, (x, 16)); d.text((x, 2), k, fill=(220, 210, 190)); x += t.size[0] + 8
sheet.save(out); print(out, sheet.size)
