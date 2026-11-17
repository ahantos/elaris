"""Close look at chosen frames of an animation (working aid).

usage: python tools/look.py anims/NAME.json OUT.png [--frames 0,1,2] [--scale 7] [--gear full] [--material steel]
Frames are cropped to the figure and shown side by side on the dark floor.
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, gear_set  # noqa: E402
from preview import Shot, load_anim  # noqa: E402
from pal import PAGE  # noqa: E402

a = sys.argv[1:]
opt = {"--frames": "", "--scale": "7", "--gear": "full", "--material": "steel"}
for k in list(opt):
    if k in a:
        i = a.index(k)
        opt[k] = a[i + 1]
        del a[i:i + 2]
anim = load_anim(a[0])
shot = Shot(Rig(), anim, gear_set(opt["--gear"]), opt["--material"])
idx = [int(v) for v in opt["--frames"].split(",")] if opt["--frames"] else list(range(len(shot.frames)))
S = int(opt["--scale"])
box = None
for i in idx:
    b = shot.frames[i].getbbox()
    box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
box = (max(0, box[0] - 2), max(0, box[1] - 2), min(shot.size[0], box[2] + 2), min(shot.size[1], box[3] + 3))
w, h = box[2] - box[0], box[3] - box[1]
sheet = Image.new("RGB", (len(idx) * (w * S + 6) + 6, h * S + 22), PAGE)
d = ImageDraw.Draw(sheet)
for k, i in enumerate(idx):
    t = shot.on_floor(i).crop(box).resize((w * S, h * S), Image.NEAREST)
    sheet.paste(t, (6 + k * (w * S + 6), 16))
    d.text((6 + k * (w * S + 6), 2), "%d  %d ms" % (i, shot.durs[i]), fill=(220, 210, 190))
sheet.save(a[1])
print(a[1], sheet.size)
