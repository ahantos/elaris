"""The finished pictures of one animation, under clear names in the rig folder.

usage: python tools/final_anim.py NAME [NAME ...]        (NAME = idle, walk, swing)

Writes, for NAME:
  final_NAME.png                    frames with full gear, with helmet and shield off, in bronze,
                                    and bare; 1x and 2x; onion skins; the tip and hand trail; the checks
  final_NAME_4x.gif, _1x.gif        full gear
  final_NAME_nohelm_noshield_4x.gif helmet and shield removed
  final_NAME_bronze_4x.gif          metal recoloured to bronze
  final_NAME_checks.txt             what the checks printed, for all three gear sets
Every GIF is read back and compared with its frames (see preview.py).
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, gear_set, ROOT  # noqa: E402
from preview import Shot, load_anim, write_gif, run_checks, onion, trail, TEXT  # noqa: E402
from pal import FLOOR_DARK, FLOOR_MID, PAGE  # noqa: E402

SETS = [("full gear", "full", "steel", ""), ("helmet and shield off", "full-helmet-shield", "steel", "_nohelm_noshield"),
        ("bronze", "full", "bronze", "_bronze"), ("bare body", "body", "steel", None)]
W = 1900


def cropped(shot, box):
    """the same shot, every frame cut down to `box` (so sheets waste no space)"""
    s = Shot.__new__(Shot)
    s.__dict__.update(shot.__dict__)
    s.frames = [f.crop(box) for f in shot.frames]
    s.size = (box[2] - box[0], box[3] - box[1])
    s.origin = (shot.origin[0] - box[0], shot.origin[1] - box[1])
    return s


def union_box(shots, pad=3):
    box = None
    for s in shots:
        for f in s.frames:
            b = f.getbbox()
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    w, h = shots[0].size
    return (max(0, box[0] - pad), max(0, box[1] - pad), min(w, box[2] + pad), min(h, box[3] + pad + 2))


def strip(shot, scale, title, loop_cell=True):
    """one row (wrapped if needed) of numbered frames"""
    n = len(shot.frames)
    shown = list(range(n)) + ([0] if loop_cell and shot.anim.get("loop", True) else [])
    labels = ["%d  %d ms" % (i, shot.durs[i]) for i in range(n)] + ["0 again"]
    w, h = shot.size
    cw, ch = w * scale + 4, h * scale + 14
    cols = max(1, min(len(shown), (W - 12) // cw))
    rows = (len(shown) + cols - 1) // cols
    out = Image.new("RGB", (W, rows * ch + 18), PAGE)
    d = ImageDraw.Draw(out)
    d.text((6, 2), title, fill=TEXT)
    for k, i in enumerate(shown):
        x, y = 6 + (k % cols) * cw, 16 + (k // cols) * ch
        out.paste(shot.on_floor(i).resize((w * scale, h * scale), Image.NEAREST), (x, y + 12))
        d.text((x, y), labels[k], fill=(170, 160, 145))
    return out


def small_strip(shot):
    n = len(shot.frames)
    w, h = shot.size
    out = Image.new("RGB", (W, h * 2 + 22), PAGE)
    d = ImageDraw.Draw(out)
    d.text((6, 2), "actual size and 2x, on the dark floor #3a322c and the mid floor #56483a", fill=TEXT)
    x = 6
    for floor in (FLOOR_DARK, FLOOR_MID):
        for s in (1, 2):
            for i in range(n):
                if x + w * s > W - 6:
                    break
                out.paste(shot.on_floor(i, floor).resize((w * s, h * s), Image.NEAREST), (x, 18))
                x += w * s + 2
            x += 10
    return out


def travel_frames(shot, cycles=2):
    """the figure really moving: each frame shifted by the root travel so far, over a floor
    with a tick every 8 px and a tile line every 32, so a planted foot can be seen to stay put"""
    travel = shot.anim["travel"]
    per = sum(travel)
    w, h = shot.size
    W_ = w + per * cycles
    gy = shot.rig.data["figure"]["ground_y"] + shot.origin[1]
    out, durs = [], []
    for c in range(cycles):
        for i in range(len(shot.frames)):
            x = c * per + sum(travel[:i])
            cell = Image.new("RGBA", (W_, h), FLOOR_DARK + (255,))
            d = ImageDraw.Draw(cell)
            for t in range(0, W_, 8):
                d.line((t, gy + 3, t, gy + (6 if t % 32 == 0 else 4)), fill=(0x5a, 0x4e, 0x44, 255))
            d.ellipse((x + shot.origin[0] + 6, gy - 2, x + shot.origin[0] + 27, gy + 2), fill=(0x2b, 0x25, 0x21, 255))
            cell.alpha_composite(shot.frames[i], (x, 0))
            out.append(cell.convert("RGB"))
            durs.append(shot.durs[i])
    return out, durs


def make(name):
    rig = Rig()
    anim = load_anim(os.path.join(ROOT, "anims", name + ".json"))
    shots = [Shot(rig, anim, gear_set(spec), mat) for _, spec, mat, _ in SETS]
    box = union_box(shots)
    parts = []
    log = []
    all_fails = []
    for (title, spec, mat, suffix), shot in zip(SETS, shots):
        c = cropped(shot, box)
        cells = len(c.frames) + (1 if anim.get("loop", True) else 0)
        if title == "full gear":
            # as large as fits in one row, down to 4x (which may wrap)
            scale = next((s_ for s_ in (6, 5) if cells * (c.size[0] * s_ + 4) <= W - 12), 4)
        else:
            scale = 3 if cells * (c.size[0] * 3 + 4) <= W - 12 else 2
        parts.append(strip(c, scale, title))
        if suffix is not None:
            frames = [shot.on_floor(i) for i in range(len(shot.frames))]
            base = os.path.join(ROOT, "final_%s%s" % (name, suffix))
            log.append(write_gif(base + "_4x.gif", frames, shot.durs, 4))
            if suffix == "":
                log.append(write_gif(base + "_1x.gif", frames, shot.durs, 1))
            lines, fails = run_checks(shot)
            log.append("---- %s (%s, %s)" % (title, spec, mat))
            log += lines
            all_fails += ["%s: %s" % (title, f) for f in fails]
    full = cropped(shots[0], box)
    parts.append(small_strip(full))
    if anim.get("travel"):
        tf, td = travel_frames(full, 2)
        log.append(write_gif(os.path.join(ROOT, "final_%s_travel_4x.gif" % name), tf, td, 4))
        n = len(full.frames)
        sc = 3
        tw, th = tf[0].size
        cols = max(1, (W - 12) // (tw * sc + 4))
        rows = (n + 1 + cols - 1) // cols
        tr_ = Image.new("RGB", (W, rows * (th * sc + 16) + 18), PAGE)
        dd = ImageDraw.Draw(tr_)
        dd.text((6, 2), "moving: each frame shifted by its root travel (%s px, %d per cycle); floor ticks every 8 px, tile lines every 32. A planted foot stays on its tick."
                % (anim["travel"], sum(anim["travel"])), fill=TEXT)
        for k in range(n + 1):
            x_, y_ = 6 + (k % cols) * (tw * sc + 4), 18 + (k // cols) * (th * sc + 16)
            tr_.paste(tf[k].resize((tw * sc, th * sc), Image.NEAREST), (x_, y_ + 12))
            dd.text((x_, y_), "%d" % (k % n), fill=(170, 160, 145))
        parts.append(tr_)
    on = onion(full, 3)
    tr = trail(full, 5)
    lines, _ = run_checks(shots[0])
    # the checks as text beside the trail
    txt = Image.new("RGB", (W, max(tr.size[1], 13 * (len(lines) + 2)) + 24), PAGE)
    d = ImageDraw.Draw(txt)
    d.text((6, 2), "paths of the weapon tip and the near hand; the checks for the full-gear set", fill=TEXT)
    txt.paste(tr, (6, 18))
    for k, line in enumerate(lines):
        col = (255, 120, 100) if "FAIL" in line or "<--" in line else ((235, 225, 200) if line[:1] != " " else (170, 160, 145))
        d.text((tr.size[0] + 20, 18 + 13 * k), line[:230], fill=col)
    ont = Image.new("RGB", (W, on.size[1] + 18), PAGE)
    ImageDraw.Draw(ont).text((6, 2), "onion skins", fill=TEXT)
    ont.paste(on.crop((0, 0, min(W, on.size[0]), on.size[1])), (0, 16))
    parts += [ont, txt]
    H = sum(p.size[1] for p in parts) + 8
    sheet = Image.new("RGB", (W, H), PAGE)
    y = 4
    for p in parts:
        sheet.paste(p, (0, y))
        y += p.size[1]
    out = os.path.join(ROOT, "final_%s.png" % name)
    sheet.save(out)
    open(os.path.join(ROOT, "final_%s_checks.txt" % name), "w", encoding="utf-8", newline="\n").write("\n".join(log) + "\n")
    print(out, sheet.size)
    for l in log:
        if "read back" in l:
            print("  " + l)
    print("  checks: %s" % ("all pass" if not all_fails else "%d problem(s)" % len(all_fails)))
    for f in all_fails:
        print("    FAIL " + f)


if __name__ == "__main__":
    for n in sys.argv[1:]:
        make(n)
