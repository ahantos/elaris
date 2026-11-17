"""Preview and check one animation of the rig.

usage: python tools/preview.py anims/NAME.json [--gear full|body|full-helmet-shield ...]
                                [--material steel|bronze] [--tag TAG] [--quiet]

Writes to preview/ (TAG defaults to "<gear>_<material>"):
  NAME_TAG_4x.gif    enlarged four times on the dark floor colour
  NAME_TAG_1x.gif    actual size
  NAME_TAG_sheet.png numbered frames with durations, frame 0 repeated after the last
  NAME_TAG_onion.png onion skins: all frames over each other, then each frame over the one before
  NAME_TAG_trail.png the paths of the weapon tip and the near hand over all frames
  NAME_TAG_checks.txt what the checks below printed

Every GIF is read back from disk and compared pixel by pixel with the frames it was
made from (frames are RGB, one shared palette, no dithering).

Checks, run every time:
  joints    every piece overlaps its parent at every frame, and the joint point itself is covered
  weapon    the weapon's length along its axis, at every angle used, against the rest pose (within 1 px)
  planted   a foot listed as planted keeps its sole point still in world space (root travel included)
  paths     weapon tip and near hand per frame: coordinates, step lengths, turn between steps
  flats     the largest one-colour block in each frame (a "slab" warning from 4 x 4 up)
  limits    every joint's bend (its angle minus its parent's) is inside the range rig.json gives it
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, gear_set, paste, ROOT  # noqa: E402
from pal import FLOOR_DARK, FLOOR_MID, PAGE  # noqa: E402

TEXT = (220, 210, 190)
SHADOW = {FLOOR_DARK: (0x2b, 0x25, 0x21), FLOOR_MID: (0x43, 0x38, 0x2d)}


def load_anim(path):
    a = json.load(open(path, encoding="utf-8"))
    a.setdefault("canvas", {"w": 64, "h": 64, "origin": [16, 12]})
    a.setdefault("loop", True)
    return a


class Shot:
    """all frames of one animation with one gear set, plus what the checks need"""

    def __init__(self, rig, anim, gear, material):
        self.rig, self.anim, self.gear, self.material = rig, anim, gear, material
        c = anim["canvas"]
        self.size, self.origin = (c["w"], c["h"]), tuple(c["origin"])
        self.frames, self.solved, self.masks, self.durs = [], [], [], []
        for f in anim["frames"]:
            items, solved = rig.draw_list(f.get("pieces", {}), gear, material)
            drawn = [(it["layer"]["z"], it["im"], it["x"], it["y"], it["layer"]["piece"]) for it in items]
            for e in f.get("fx", []):
                if e.get("needs") and e["needs"] not in gear:
                    continue                      # a blade's smear without a blade
                fx = rig.data["fx"][e["name"]]
                im, (ox, oy) = rig.sprite(fx["sprite"] + "@0")
                drawn.append((e.get("z", 1000), im, e["x"] + ox, e["y"] + oy, None))
            drawn.sort(key=lambda d: d[0])
            canvas = Image.new("RGBA", self.size, (0, 0, 0, 0))
            piece_mask = {}
            for z, im, x, y, piece in drawn:
                paste(canvas, im, x + self.origin[0], y + self.origin[1])
                if piece:
                    m = piece_mask.setdefault(piece, set())
                    px = im.load()
                    for yy in range(im.size[1]):
                        for xx in range(im.size[0]):
                            if px[xx, yy][3]:
                                m.add((x + xx, y + yy))
            self.frames.append(canvas)
            self.solved.append(solved)
            self.masks.append(piece_mask)
            self.durs.append(int(f["ms"]))

    def on_floor(self, i, floor=FLOOR_DARK, shadow=True):
        cell = Image.new("RGBA", self.size, floor + (255,))
        if shadow:
            gy = self.rig.data["figure"]["ground_y"] + self.origin[1]
            d = ImageDraw.Draw(cell)
            d.ellipse((self.origin[0] + 6, gy - 2, self.origin[0] + 27, gy + 2), fill=SHADOW[floor] + (255,))
        cell.alpha_composite(self.frames[i])
        return cell.convert("RGB")


# ------------------------------------------------------------------ outputs
def write_gif(path, frames, durs, scale):
    big = [f.resize((f.size[0] * scale, f.size[1] * scale), Image.NEAREST) for f in frames]
    cols = set()
    for f in big:
        cols |= {c for _, c in f.getcolors(1 << 22)}
    assert len(cols) <= 256, "too many colours for one GIF palette: %d" % len(cols)
    pal_im = Image.new("P", (1, 1))
    flat = [v for c in sorted(cols) for v in c]
    pal_im.putpalette(flat + [0] * (768 - len(flat)))
    q = [f.quantize(palette=pal_im, dither=Image.Dither.NONE) for f in big]
    q[0].save(path, save_all=True, append_images=q[1:], duration=durs, loop=0, disposal=1, optimize=False)
    chk = Image.open(path)
    assert chk.n_frames == len(big), "%s: %d frames, expected %d" % (path, chk.n_frames, len(big))
    for i, src in enumerate(big):
        chk.seek(i)
        got = chk.convert("RGB")
        assert got.size == src.size
        if got.tobytes() != src.tobytes():
            bad = sum(1 for a, b in zip(got.getdata(), src.getdata()) if a != b)
            raise AssertionError("%s frame %d: %d pixels differ from the source" % (path, i, bad))
        assert chk.info.get("duration", durs[i]) == durs[i], "duration of frame %d" % i
    return "%s: read back, %d frames, %d colours, every pixel and duration matches" % (
        os.path.basename(path), len(big), len(cols))


def sheet(shot, scale=3, cols=None, floor=FLOOR_DARK, loop_cell=True, small=True):
    n = len(shot.frames)
    shown = list(range(n)) + ([0] if loop_cell and shot.anim.get("loop", True) else [])
    labels = ["%d   %d ms" % (i, shot.durs[i]) for i in range(n)] + ["0 again (loop)"]
    cols = cols or min(len(shown), 6)
    rows = (len(shown) + cols - 1) // cols
    w, h = shot.size
    cw, ch = w * scale + 6, h * scale + 16
    extra = (h * 2 + 20) if small else 0
    out = Image.new("RGB", (cols * cw + 6, rows * ch + 6 + extra), PAGE)
    d = ImageDraw.Draw(out)
    for k, i in enumerate(shown):
        x, y = 6 + (k % cols) * cw, 6 + (k // cols) * ch
        out.paste(shot.on_floor(i, floor).resize((w * scale, h * scale), Image.NEAREST), (x, y + 12))
        d.text((x, y), labels[k], fill=TEXT)
    if small:
        y = rows * ch + 10
        d.text((6, y), "1x and 2x on the mid floor", fill=TEXT)
        x = 6
        for i in range(n):
            out.paste(shot.on_floor(i, FLOOR_MID), (x, y + 14 + h))
            x += w + 2
        x += 8
        for i in range(n):
            if x + w * 2 > out.size[0]:
                break
            out.paste(shot.on_floor(i, FLOOR_MID).resize((w * 2, h * 2), Image.NEAREST), (x, y + 14))
            x += w * 2 + 2
    return out


def tint(frame, colour, alpha):
    a = frame.getchannel("A").point(lambda v: alpha if v else 0)
    t = Image.new("RGBA", frame.size, colour + (0,))
    t.putalpha(a)
    return t


def onion(shot, scale=4):
    n = len(shot.frames)
    w, h = shot.size
    cells = []
    # all frames over each other, the first one solid
    allf = Image.new("RGBA", shot.size, FLOOR_DARK + (255,))
    for i in range(n - 1, 0, -1):
        f = shot.frames[i].copy()
        f.putalpha(f.getchannel("A").point(lambda v: 70 if v else 0))
        allf.alpha_composite(f)
    allf.alpha_composite(shot.frames[0])
    cells.append(("all frames (0 solid)", allf))
    pairs = [(i, i + 1) for i in range(n - 1)] + ([(n - 1, 0)] if shot.anim.get("loop", True) and n > 1 else [])
    for a, b in pairs:
        c = Image.new("RGBA", shot.size, FLOOR_DARK + (255,))
        c.alpha_composite(tint(shot.frames[a], (70, 120, 255), 150))
        f = shot.frames[b].copy()
        f.putalpha(f.getchannel("A").point(lambda v: 170 if v else 0))
        c.alpha_composite(f)
        cells.append(("%d (blue) under %d" % (a, b), c))
    cols = min(len(cells), 5)
    rows = (len(cells) + cols - 1) // cols
    cw, ch = w * scale + 6, h * scale + 16
    out = Image.new("RGB", (cols * cw + 6, rows * ch + 6), PAGE)
    d = ImageDraw.Draw(out)
    for k, (label, c) in enumerate(cells):
        x, y = 6 + (k % cols) * cw, 6 + (k // cols) * ch
        out.paste(c.convert("RGB").resize((w * scale, h * scale), Image.NEAREST), (x, y + 12))
        d.text((x, y), label, fill=TEXT)
    return out


def tracked_points(shot):
    """per frame: weapon tip, near hand, both soles, in figure coordinates"""
    rig = shot.rig
    pts = {"tip": [], "hand": [], "near_sole": [], "far_sole": []}
    for s in shot.solved:
        pts["tip"].append(rig.anchor(s, "weapon", "tip"))
        pts["hand"].append(rig.anchor(s, "near_forearm", "hand"))
        pts["near_sole"].append(rig.anchor(s, "near_shin", "sole"))
        pts["far_sole"].append(rig.anchor(s, "far_shin", "sole"))
    return pts


def trail(shot, scale=6):
    pts = tracked_points(shot)
    w, h = shot.size
    base = Image.new("RGBA", shot.size, FLOOR_DARK + (255,))
    for i in range(len(shot.frames)):
        f = shot.frames[i].copy()
        f.putalpha(f.getchannel("A").point(lambda v: 60 if v else 0))
        base.alpha_composite(f)
    out = base.convert("RGB").resize((w * scale, h * scale), Image.NEAREST)
    d = ImageDraw.Draw(out)
    ox, oy = shot.origin

    def P(p):
        return ((p[0] + ox + 0.5) * scale, (p[1] + oy + 0.5) * scale)

    for name, col in (("tip", (255, 220, 60)), ("hand", (80, 220, 255))):
        if "weapon" not in shot.gear and name == "tip":
            continue
        seq = pts[name] + ([pts[name][0]] if shot.anim.get("loop", True) else [])
        d.line([P(p) for p in seq], fill=col, width=1)
        for i, p in enumerate(pts[name]):
            x, y = P(p)
            d.rectangle((x - 2, y - 2, x + 2, y + 2), fill=col)
            d.text((x + 4, y - 5), str(i), fill=col)
    d.text((4, 2), "weapon tip (yellow), near hand (blue); numbers are frames", fill=TEXT)
    return out


# ------------------------------------------------------------------ checks
def weapon_length(rig, angle, sprite="broad_sword__weapon"):
    """extent of the weapon picture along its axis at this angle, in pixels"""
    im, _ = rig.sprite("%s@%d" % (sprite, angle))
    deg = float(rig.data.get("angle_degrees", {}).get(str(abs(angle)), abs(angle))) * (1 if angle >= 0 else -1)
    t = math.radians(deg)
    ax, ay = math.sin(t), -math.cos(t)              # the blade points up at rest; clockwise turn
    px = im.load()
    proj, cross = [], []
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            if px[x, y][3]:
                proj.append((x + 0.5) * ax + (y + 0.5) * ay)
                cross.append(-(x + 0.5) * ay + (y + 0.5) * ax)
    return max(proj) - min(proj) + 1, max(cross) - min(cross) + 1, len(proj)


def flat_block(frame):
    """side of the largest square of one colour in the picture (ignores transparency)"""
    w, h = frame.size
    px = frame.load()
    best, where = 1, None
    size = [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0:
                continue
            s = 1
            if x and y and px[x - 1, y] == p and px[x, y - 1] == p and px[x - 1, y - 1] == p:
                s = 1 + min(size[y][x - 1], size[y - 1][x], size[y - 1][x - 1])
            size[y][x] = s
            if s > best:
                best, where = s, (x - s + 1, y - s + 1)
    return best, where


def run_checks(shot):
    rig, anim = shot.rig, shot.anim
    n = len(shot.frames)
    out, fails = [], []
    say = out.append

    # --- joints
    say("JOINTS  (overlap in pixels between a piece and its parent; joint point covered or not)")
    worst = {}
    for i in range(n):
        masks, solved = shot.masks[i], shot.solved[i]
        for name in rig.order:
            p = rig.pieces[name]
            if not p["parent"] or name not in masks or p["parent"] not in masks:
                continue
            child, parent = masks[name], masks[p["parent"]]
            ov = len(child & parent)
            x, y, _ = solved[name]
            near = [(x + dx, y + dy) for dx in (-1, 0) for dy in (-1, 0)]      # the four pixels round the joint corner
            covered = sum(1 for q in near if q in child or q in parent)
            w = worst.get(name)
            if w is None or ov < w[0]:
                worst[name] = (ov, i, covered)
            # a weapon or shield hangs on an anchor: it must touch, body joints must overlap well
            need = 1 if p.get("slot") in ("weapon", "shield") else 3
            if ov < need:
                fails.append("frame %d: %s overlaps %s by only %d px" % (i, name, p["parent"], ov))
            if covered < 3 and not p.get("slot"):
                fails.append("frame %d: joint of %s is open (%d of 4 pixels covered)" % (i, name, covered))
    for name, (ov, i, cov) in worst.items():
        say("  %-15s least overlap %3d px (frame %d), joint pixels covered %d/4" % (name, ov, i, cov))

    # --- joint limits
    say("JOINT LIMITS  (bend = a piece's angle minus its parent's; every joint has a range in rig.json)")
    seen = {}
    bad = 0
    for i, f in enumerate(anim["frames"]):
        pose = f.get("pieces", {})
        for name in rig.order:
            p = rig.pieces[name]
            if p["parent"] and "range" in p and name in shot.masks[i]:
                d = rig.bend(pose, name)
                lo_hi = seen.setdefault(name, [d, d])
                lo_hi[0], lo_hi[1] = min(lo_hi[0], d), max(lo_hi[1], d)
        for name, d, rng in rig.limit_faults(pose):
            bad += 1
            fails.append("frame %d: %s is bent %+.0f degrees, its range is %d..%d" % (i, name, d, rng[0], rng[1]))
    for name, (lo, hi) in seen.items():
        rng = rig.pieces[name]["range"]
        if lo != hi or abs(lo) > 0.5:
            say("  %-15s bends %+4.0f .. %+4.0f   (range %d .. %d)" % (name, lo, hi, rng[0], rng[1]))
    say("  %s" % ("every joint inside its range in every frame" if not bad else "%d joint(s) out of range, listed under RESULT" % bad))

    # --- weapon length
    if "weapon" in shot.gear:
        say("WEAPON LENGTH along its axis (rest pose first)")
        l0, w0, n0 = weapon_length(rig, 0)
        used = sorted({s["weapon"][2] for s in shot.solved})
        say("  angle   0: length %.1f, width %.1f, %d px" % (l0, w0, n0))
        for a in used:
            if a == 0:
                continue
            l, w, cnt = weapon_length(rig, a)
            flag = "" if abs(l - l0) <= 1.0 else "   <-- more than 1 px off"
            say("  angle %3d: length %.1f (%+.1f), width %.1f, %d px (%+d%%)%s"
                % (a, l, l - l0, w, cnt, round(100 * (cnt - n0) / n0), flag))
            if abs(l - l0) > 1.0:
                fails.append("weapon length at %d degrees is %.1f, rest is %.1f" % (a, l, l0))

    # --- planted feet
    pts = tracked_points(shot)
    travel = anim.get("travel") or [0] * n
    cum = [sum(travel[:i]) for i in range(n)]
    planted = anim.get("planted", {})
    say("PLANTED FEET  (sole point in world space = figure position + root travel so far)")
    for foot, groups in planted.items():
        key = foot + "_sole"
        for group in groups:
            world = []
            for i in group:
                # a group may run over the loop seam: frames after the wrap have one more cycle of travel
                lap = sum(travel) if (group.index(i) > 0 and i < group[0]) else 0
                world.append((pts[key][i][0] + cum[i] + lap, pts[key][i][1]))
            moved = max(abs(w[0] - world[0][0]) for w in world), max(abs(w[1] - world[0][1]) for w in world)
            say("  %-4s frames %-16s world %s  moved %d,%d px" % (foot, group, world, moved[0], moved[1]))
            if moved != (0, 0):
                fails.append("%s foot moves %s px while planted in frames %s" % (foot, moved, group))
    if not planted:
        say("  (none declared)")
    for foot in ("near", "far"):
        say("  %s sole per frame (figure coords): %s" % (foot, pts[foot + "_sole"]))
    if any(travel):
        say("  root travel per frame: %s (sum %d)" % (travel, sum(travel)))

    # --- paths
    say("PATHS  (figure coordinates; step = distance to the next frame; turn = change of heading)")
    for name in ("tip", "hand"):
        if name == "tip" and "weapon" not in shot.gear:
            continue
        seq = pts[name]
        loop = anim.get("loop", True)
        m = len(seq)
        steps = []
        for i in range(m if loop else m - 1):
            a, b = seq[i], seq[(i + 1) % m]
            steps.append((b[0] - a[0], b[1] - a[1]))
        say("  %s: %s" % (name, " ".join("%d:(%d,%d)" % (i, p[0], p[1]) for i, p in enumerate(seq))))
        lens = [math.hypot(*s) for s in steps]
        say("    steps: %s" % " ".join("%.1f" % l for l in lens))
        turns = []
        for i in range(1, len(steps)):
            a, b = steps[i - 1], steps[i]
            if math.hypot(*a) < 2.5 or math.hypot(*b) < 2.5:
                turns.append(None)
                continue
            t = math.degrees(math.atan2(a[0] * b[1] - a[1] * b[0], a[0] * b[0] + a[1] * b[1]))
            turns.append(t)
        say("    turns: %s" % " ".join("-" if t is None else "%+.0f" % t for t in turns))
        sharp = [(i + 1, t) for i, t in enumerate(turns) if t is not None and abs(t) > 100]
        for i, t in sharp:
            say("    note: the path doubles back at frame %d (%+.0f degrees)" % (i, t))

    # --- flat blocks
    worst_flat = max((flat_block(f) + (i,) for i, f in enumerate(shot.frames)), key=lambda v: v[0])
    say("FLATS  largest one-colour square: %d x %d (frame %d, at %s)" % (
        worst_flat[0], worst_flat[0], worst_flat[2], worst_flat[1]))
    if worst_flat[0] >= 4:
        fails.append("a one-colour block of %d x %d shows in frame %d" % (worst_flat[0], worst_flat[0], worst_flat[2]))

    say("RESULT  " + ("all checks pass" if not fails else "%d problem(s):" % len(fails)))
    for f in fails:
        say("  FAIL " + f)
    return out, fails


def make(anim_path, spec="full", material="steel", tag=None, quiet=False, outdir=None):
    rig = Rig()
    anim = load_anim(anim_path)
    gear = gear_set(spec)
    shot = Shot(rig, anim, gear, material)
    name = anim.get("name") or os.path.splitext(os.path.basename(anim_path))[0]
    tag = tag or ("%s_%s" % (spec, material))
    outdir = outdir or os.path.join(ROOT, "preview")
    os.makedirs(outdir, exist_ok=True)
    base = os.path.join(outdir, "%s_%s" % (name, tag))
    lines = ["%s  gear=%s material=%s  frames=%d  total=%d ms" % (name, spec, material, len(shot.frames), sum(shot.durs))]
    frames = [shot.on_floor(i) for i in range(len(shot.frames))]
    lines.append(write_gif(base + "_4x.gif", frames, shot.durs, 4))
    lines.append(write_gif(base + "_1x.gif", frames, shot.durs, 1))
    sheet(shot).save(base + "_sheet.png")
    onion(shot).save(base + "_onion.png")
    trail(shot).save(base + "_trail.png")
    out, fails = run_checks(shot)
    lines += out
    open(base + "_checks.txt", "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    if not quiet:
        print("\n".join(lines))
    return shot, fails, base


if __name__ == "__main__":
    a = sys.argv[1:]
    opt = {"--gear": "full", "--material": "steel", "--tag": None}
    for k in list(opt):
        if k in a:
            i = a.index(k)
            opt[k] = a[i + 1]
            del a[i:i + 2]
    quiet = "--quiet" in a
    a = [v for v in a if v != "--quiet"]
    for path in a:
        make(path, opt["--gear"], opt["--material"], opt["--tag"], quiet)
