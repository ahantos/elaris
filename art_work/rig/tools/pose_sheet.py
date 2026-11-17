"""Still poses, enlarged, for judging the parts.

usage: python tools/pose_sheet.py OUT.png SCALE [--gear full] [--material steel] POSE [POSE ...]

A POSE is a name from poses.json (a dictionary of {piece: {"a", "dx", "dy"}}) or
"a1:<sprite>" for a picture from the A1 reference build (ref/out/sprites).
Each pose is shown on the dark and on the mid floor.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, gear_set, ROOT  # noqa: E402
from pal import FLOOR_DARK, FLOOR_MID, PAGE  # noqa: E402

SIZE, ORIGIN = (96, 80), (30, 28)


def load_poses():
    return json.load(open(os.path.join(ROOT, "poses.json"), encoding="utf-8"))


def pose_image(rig, name, spec, material, poses=None):
    if name.startswith("a1:"):
        im = Image.open(os.path.join(ROOT, "ref", "out", "sprites", name[3:] + ".png")).convert("RGBA")
        canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(im, ORIGIN)
        return canvas
    poses = poses or load_poses()
    canvas, _ = rig.render(poses[name], gear_set(spec), material, SIZE, ORIGIN)
    return canvas


def crop_box(ims):
    box = None
    for im in ims:
        b = im.getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return (box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2)


def main():
    a = sys.argv[1:]
    opt = {"--gear": "full", "--material": "steel"}
    for k in list(opt):
        if k in a:
            i = a.index(k)
            opt[k] = a[i + 1]
            del a[i:i + 2]
    out, S, names = a[0], int(a[1]), a[2:]
    rig = Rig()
    ims = [pose_image(rig, n, opt["--gear"], opt["--material"]) for n in names]
    box = crop_box(ims)
    w, h = box[2] - box[0], box[3] - box[1]
    sheet = Image.new("RGB", (len(ims) * (w * S + 8) + 8, 2 * (h * S + 18) + 8), PAGE)
    d = ImageDraw.Draw(sheet)
    for i, (n, im) in enumerate(zip(names, ims)):
        for r, bg in enumerate((FLOOR_DARK, FLOOR_MID)):
            t = Image.new("RGBA", (w, h), bg + (255,))
            t.alpha_composite(im.crop(box))
            x, y = 8 + i * (w * S + 8), 8 + r * (h * S + 18)
            sheet.paste(t.convert("RGB").resize((w * S, h * S), Image.NEAREST), (x, y + 12))
            d.text((x, y), n, fill=(220, 210, 190))
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
