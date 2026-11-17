"""final_rig.png: the parts apart with their pivots, the rest pose beside A1 with the
pixel difference, and poses put together from the same parts.

usage: python tools/final_rig.py [OUT.png]
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, gear_set, FULL_GEAR, paste, ROOT  # noqa: E402
from pal import FLOOR_DARK, FLOOR_MID, PAGE  # noqa: E402
from pose_sheet import load_poses  # noqa: E402

TEXT = (220, 210, 190)
DIM = (150, 142, 128)
PIVOT = (255, 60, 200)
JOINT = (70, 220, 255)
SIZE, ORIGIN = (96, 80), (30, 28)


def master(name):
    return Image.open(os.path.join(ROOT, "out", "sprites", name + ".png")).convert("RGBA")


def part_tile(src, piece, sprites, S, bg=FLOOR_MID):
    """the master(s) of one piece, enlarged, pivot (magenta) and child joints (blue) marked"""
    ims = [master(s) for s in sprites]
    comp = Image.new("RGBA", ims[0].size, (0, 0, 0, 0))
    for im in ims:
        comp.alpha_composite(im)
    box = comp.getbbox()
    c = piece["centre"]
    pts = [(c, PIVOT)]
    for q in src["pieces"]:
        if q["parent"] == piece["name"]:
            pts.append((q["at"], JOINT))
    # the box must hold the marks too
    x0 = int(min([box[0]] + [p[0] - 1 for p, _ in pts])) - 1
    y0 = int(min([box[1]] + [p[1] - 1 for p, _ in pts])) - 1
    x1 = int(max([box[2]] + [p[0] + 1 for p, _ in pts])) + 1
    y1 = int(max([box[3]] + [p[1] + 1 for p, _ in pts])) + 1
    t = Image.new("RGBA", (x1 - x0, y1 - y0), bg + (255,))
    paste(t, comp, -x0, -y0)
    t = t.convert("RGB").resize(((x1 - x0) * S, (y1 - y0) * S), Image.NEAREST)
    d = ImageDraw.Draw(t)
    for (px_, py_), col in pts:
        X, Y = (px_ - x0) * S, (py_ - y0) * S
        r = max(2, S // 3)
        d.ellipse((X - r, Y - r, X + r, Y + r), outline=col, width=2)
        d.line((X - r - 2, Y, X + r + 2, Y), fill=col)
        d.line((X, Y - r - 2, X, Y + r + 2), fill=col)
    return t


def figure_tile(im, S, bg=FLOOR_DARK, box=None):
    box = box or (0, 0) + im.size
    t = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), bg + (255,))
    paste(t, im, -box[0], -box[1])
    return t.convert("RGB").resize((t.size[0] * S, t.size[1] * S), Image.NEAREST)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "final_rig.png")
    rig = Rig()
    src = json.load(open(os.path.join(ROOT, "rig.src.json"), encoding="utf-8"))
    pieces = {p["name"]: p for p in src["pieces"]}
    poses = load_poses()

    sheet = Image.new("RGB", (1920, 2000), PAGE)
    d = ImageDraw.Draw(sheet)

    def label(x, y, text, col=TEXT):
        d.text((x, y), text, fill=col)

    # ---- 1. body parts
    y = 8
    label(8, y, "THE BODY: eleven parts, each drawn whole.  Magenta = the part's own pivot.  Blue = where a child part hangs.")
    y += 16
    body = [("head", ["body__head"], "head  (in place)"), ("torso", ["body__torso"], "torso  (in place)"),
            ("hips", ["body__hips"], "hips  (root)"),
            ("near_upper_arm", ["body__near_upper_arm"], "near upper arm"),
            ("near_forearm", ["body__near_forearm"], "near forearm + fist"),
            ("far_upper_arm", ["body__far_upper_arm"], "far upper arm"),
            ("far_forearm", ["body__far_forearm"], "far forearm + fist"),
            ("near_thigh", ["body__near_thigh"], "near thigh"), ("near_shin", ["body__near_shin"], "near shin + foot"),
            ("far_thigh", ["body__far_thigh"], "far thigh"), ("far_shin", ["body__far_shin"], "far shin + foot")]
    x = 8
    rowh = 0
    for pname, sprites, text in body:
        t = part_tile(src, pieces[pname], sprites, 9)
        sheet.paste(t, (x, y + 14))
        label(x, y, text)
        x += max(t.size[0], len(text) * 6 + 6) + 14
        rowh = max(rowh, t.size[1])
    y += rowh + 26

    # ---- 2. gear parts
    label(8, y, "THE GEAR, cut so that each part rides one body part (named under it). Shown on the body part it rides, body dimmed.")
    y += 16
    gear = [("cloak_upper", ["wolf_cloak__cloak_upper"], [], "cloak, mantle > torso"),
            ("cloak_lower", ["wolf_cloak__cloak_lower"], [], "cloak, hem > mantle"),
            ("hips", ["fur_kilt__hips"], ["body__hips"], "belt > hips"),
            ("skirt", ["fur_kilt__skirt"], [], "kilt > hangs from hips"),
            ("torso", ["baldric__torso"], ["body__torso"], "baldric > torso"),
            ("torso", ["fur_bracer__torso"], ["body__torso"], "shoulder fur > torso"),
            ("head", ["iron_cap__head"], ["body__head"], "iron cap > head"),
            ("near_forearm", ["fur_bracer__near_forearm"], ["body__near_forearm"], "bracer > forearm"),
            ("near_shin", ["fur_boots__near_shin"], ["body__near_shin"], "boot > near shin"),
            ("far_shin", ["fur_boots__far_shin"], ["body__far_shin"], "boot > far shin"),
            ("shield", ["round_shield__shield"], [], "shield > far fist"),
            ("weapon", ["broad_sword__weapon"], [], "sword > near fist")]
    x = 8
    rowh = 0
    for pname, sprites, under, text in gear:
        S = 6
        ims = [master(s) for s in sprites]
        comp = Image.new("RGBA", ims[0].size, (0, 0, 0, 0))
        for u in under:
            b = master(u)
            b.putalpha(b.getchannel("A").point(lambda v: 70 if v else 0))
            comp.alpha_composite(b)
        for im in ims:
            comp.alpha_composite(im)
        box = comp.getbbox()
        c = pieces[pname]["centre"]
        x0, y0 = min(box[0], int(c[0]) - 1) - 1, min(box[1], int(c[1]) - 1) - 1
        x1, y1 = max(box[2], int(c[0]) + 1) + 1, max(box[3], int(c[1]) + 1) + 1
        t = figure_tile(comp, S, FLOOR_MID, (x0, y0, x1, y1))
        dd = ImageDraw.Draw(t)
        X, Y = (c[0] - x0) * S, (c[1] - y0) * S
        dd.ellipse((X - 2, Y - 2, X + 2, Y + 2), outline=PIVOT, width=2)
        dd.line((X - 5, Y, X + 5, Y), fill=PIVOT)
        dd.line((X, Y - 5, X, Y + 5), fill=PIVOT)
        sheet.paste(t, (x, y + 14))
        label(x, y, text)
        x += max(t.size[0], len(text) * 6 + 6) + 14
        rowh = max(rowh, t.size[1])
    y += rowh + 26

    # ---- 3. rest pose against A1
    S = 7
    a1 = Image.open(os.path.join(ROOT, "ref", "out", "sprites", "a1.png")).convert("RGBA")
    rest, _ = rig.render({}, dict(FULL_GEAR))
    pa, pr = a1.load(), rest.load()
    diff = Image.new("RGBA", a1.size, (0, 0, 0, 0))
    n = total = 0
    for yy in range(a1.size[1]):
        for xx in range(a1.size[0]):
            p, q = pa[xx, yy], pr[xx, yy]
            if p[3] or q[3]:
                total += 1
            if (p[3] or q[3]) and p != q:
                n += 1
                diff.putpixel((xx, yy), (255, 60, 200, 255))
            elif q[3]:
                diff.putpixel((xx, yy), tuple(int(v * 0.35) for v in q[:3]) + (255,))
    body_a1 = Image.open(os.path.join(ROOT, "ref", "out", "sprites", "a1_body.png")).convert("RGBA")
    body_rest, _ = rig.render({}, {})
    pb, pq = body_a1.load(), body_rest.load()
    nb = sum(1 for yy in range(48) for xx in range(32)
             if (pb[xx, yy][3] or pq[xx, yy][3]) and pb[xx, yy] != pq[xx, yy])
    tb = sum(1 for yy in range(48) for xx in range(32) if pb[xx, yy][3] or pq[xx, yy][3])
    x = 8
    label(x, y, "REST POSE")
    y += 16
    for text, im in (("A1, the original", a1), ("the rig at rest", rest), ("where they differ", diff),
                     ("A1, bare", body_a1), ("the rig, bare", body_rest)):
        t = figure_tile(im, S)
        sheet.paste(t, (x, y + 14))
        label(x, y, text)
        x += t.size[0] + 10
    # 1x and 2x on both floors
    for bg in (FLOOR_DARK, FLOOR_MID):
        for s in (1, 2):
            for im in (a1, rest):
                t = figure_tile(im, s, bg)
                sheet.paste(t, (x, y + 14 + (0 if bg == FLOOR_DARK else 110)))
                x += t.size[0] + 4
        x -= (32 * 1 + 4) * 2 + (32 * 2 + 4) * 2
    label(x, y, "1x, 2x: A1 | rig")
    restx = x + 220
    label(restx, y + 20, "Full gear: %d of %d pixels differ from A1." % (n, total))
    label(restx, y + 36, "Bare body: %d of %d pixels differ." % (nb, tb))
    notes = ["Drawn new as separate upright parts (A1's limb shading,",
             "straightened, closed with round caps at both ends):",
             "both upper arms, both forearms with fists, both thighs,",
             "both shins with feet; the bracer and boots re-cut to fit.",
             "",
             "Still A1's own pixels, with the covered parts drawn in:",
             "head, torso, hips (they move by whole pixels only).",
             "A1's as drawn (they were separate layers already):",
             "helmet, baldric, kilt, shoulder furs, shield, sword",
             "(the sword's grip is new). Cloak: half redrawn.",
             "",
             "So the rest pose is a pose like any other, not a copy."]
    for k, line in enumerate(notes):
        label(restx, y + 60 + 14 * k, line, DIM)
    y += 48 * S + 30

    # ---- 4. the same parts in other poses
    bad = sum(len(rig.limit_faults(poses[p])) for p in poses)
    label(8, y, "THE SAME PARTS, MOVED: nothing here is redrawn per pose. Each part is one of its pre-drawn angles, placed on whole pixels."
          "  Every joint has a range (an elbow folds forward only, a knee back only); joints out of range in these poses: %d." % bad)
    y += 16
    x = 8
    S = 6
    shots = [("arm_raised", "full", "steel", "near arm raised, elbow folded"),
             ("arm_raised", "body", "steel", "the same, bare"),
             ("step_forward", "full", "steel", "a leg stepped forward"),
             ("step_forward", "body", "steel", "the same, bare"),
             ("strike", "full-helmet-shield", "bronze", "lunge, no helmet or shield, bronze"),
             ("strike", "body", "steel", "the same, bare")]
    ims = [rig.render(poses[p], gear_set(spec), mat, SIZE, ORIGIN)[0] for p, spec, mat, _ in shots]
    top = min(im.getbbox()[1] for im in ims) - 2
    for (pname, spec, mat, text), im in zip(shots, ims):
        b = im.getbbox()
        box = (b[0] - 2, top, b[2] + 2, ORIGIN[1] + 50)
        t = figure_tile(im, S, FLOOR_DARK, box)
        sheet.paste(t, (x, y + 14))
        label(x, y, text)
        x += max(t.size[0], len(text) * 6 + 6) + 10
    y += (ORIGIN[1] + 50 - top) * S + 18

    # ---- 5. the angle set
    y += 10
    label(8, y, "ONE MASTER, A FIXED SET OF ANGLES: 0, 27 (a 2:1 slope), 45, 63 (1:2), 90 and their turns; the legs also have 14 (4:1) for small steps. The game only ever shows these pictures; it never turns one itself.")
    y += 16
    x = 8
    rowh = 0
    strips = [("weapon", [-63, -45, -27, 0, 27, 45, 63, 90, 117], 3, "sword"),
              ("near_forearm", [0, -27, -45, -63, -90, -117, -135, -153, 180, 153, 135, 117, 90, 63, 45, 27], 4, "near forearm, fist and bracer"),
              ("near_shin", [-45, -27, -14, 0, 14, 27, 45, 63, 90], 4, "near shin, foot and boot")]
    for pname, angles, S, text in strips:
        label(x, y, text)
        xx = x
        for ang in angles:
            ls = [l for l in rig.layers(dict(FULL_GEAR)) if l["piece"] == pname]
            ims = [rig.sprite("%s@%d" % (l["sprite"], ang)) for l in ls]
            x0 = min(o[0] for _, o in ims); y0 = min(o[1] for _, o in ims)
            x1 = max(o[0] + im.size[0] for im, o in ims); y1 = max(o[1] + im.size[1] for im, o in ims)
            t = Image.new("RGBA", (x1 - x0 + 2, y1 - y0 + 2), FLOOR_DARK + (255,))
            for im, o in ims:
                paste(t, im, o[0] - x0 + 1, o[1] - y0 + 1)
            t = t.convert("RGB").resize((t.size[0] * S, t.size[1] * S), Image.NEAREST)
            sheet.paste(t, (xx, y + 26))
            label(xx, y + 13, str(ang), DIM)
            xx += t.size[0] + 4
            rowh = max(rowh, t.size[1])
        x = xx + 16
        if pname == "near_forearm":          # the last strip goes on its own line
            x = 8
            y += rowh + 34
            rowh = 0
    y += rowh + 30

    sheet = sheet.crop((0, 0, 1920, y + 8))
    sheet.save(out)
    print(out, sheet.size, "full gear diff %d/%d, bare %d/%d" % (n, total, nb, tb))


main()
