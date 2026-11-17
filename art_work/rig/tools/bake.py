"""Bake the rig: masters -> angle variants -> atlas.png + rig.json.

usage: python tools/bake.py [--show SPRITE@ANGLE ...] [--review]

Reads rig.src.json, the master pictures built by pxl (out/sprites/*.png, 32 x 48,
figure coordinates), patches.py (hand corrections to single variants) and, if it
exists, out/sprites/fx__*.png (effect pictures).

Rotation method ("index map", after RotSprite): all pictures that ride on one piece
are laid over each other; that composite is enlarged 8 times with Scale2x (three
passes), which smooths stair-steps without inventing colours; each pixel of the
turned picture then looks up ONE pixel of the enlarged composite. What is stored is
not a colour but which master pixel it came from. Every layer of the piece (body,
boot, bracer ...) is then drawn through the same map, so gear turns exactly with the
body under it and no layer can peek out from under another.

--show prints a variant as palette keys in figure coordinates (the coordinates that
patches.py uses). --review writes one enlarged sheet per piece to bake/review/.
"""
import json
import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, ROOT)
from pal import key_of, rgba_of, FLOOR_DARK, FLOOR_MID, PAGE  # noqa: E402

PAD = 44          # margin around a master picture while turning
UP = 8            # Scale2x three times


def load_src():
    return json.load(open(os.path.join(ROOT, "rig.src.json"), encoding="utf-8"))


def degrees(src, label):
    return float(src.get("angle_degrees", {}).get(str(abs(label)), abs(label))) * (1 if label >= 0 else -1)


def master(name, fw, fh):
    im = Image.open(os.path.join(ROOT, "out", "sprites", name + ".png")).convert("RGBA")
    assert im.size == (fw, fh), "%s is %s, the canvas of its piece is %s" % (name, im.size, (fw, fh))
    a = np.zeros((fh + 2 * PAD, fw + 2 * PAD, 4), np.uint8)
    a[PAD:PAD + fh, PAD:PAD + fw] = np.asarray(im)
    return a


def colour_key(a):
    a = a.astype(np.uint32)
    k = (a[..., 0] << 24) | (a[..., 1] << 16) | (a[..., 2] << 8) | a[..., 3]
    return np.where(a[..., 3] == 0, 0, k)


def shift(a, dy, dx, fill):
    out = np.full_like(a, fill)
    h, w = a.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


def scale2x(ids, lut):
    """Scale2x on a picture of master-pixel ids; colours are compared through lut."""
    E = ids
    B, D, F, H = shift(E, 1, 0, -1), shift(E, 0, 1, -1), shift(E, 0, -1, -1), shift(E, -1, 0, -1)
    cB, cD, cF, cH = lut[B], lut[D], lut[F], lut[H]
    h, w = E.shape
    out = np.empty((h * 2, w * 2), E.dtype)
    out[0::2, 0::2] = np.where((cD == cB) & (cB != cF) & (cD != cH), D, E)
    out[0::2, 1::2] = np.where((cB == cF) & (cB != cD) & (cF != cH), F, E)
    out[1::2, 0::2] = np.where((cD == cH) & (cD != cB) & (cH != cF), D, E)
    out[1::2, 1::2] = np.where((cH == cF) & (cD != cH) & (cB != cF), F, E)
    return out


def index_map(composite, centre, deg, mirror_axis=None):
    """dest pixel -> id of the master pixel it shows (-1 = nothing). Padded coordinates."""
    h, w = composite.shape[:2]
    lut = np.append(colour_key(composite).reshape(-1), 0)       # lut[-1] = transparent
    ids = np.arange(h * w, dtype=np.int64).reshape(h, w)
    big = ids
    for _ in range(3):
        big = scale2x(big, lut)
    cx, cy = centre[0] + PAD, centre[1] + PAD
    t = math.radians(deg)
    cs, sn = math.cos(t), math.sin(t)
    yy, xx = np.mgrid[0:h, 0:w]
    dx, dy = xx + 0.5 - cx, yy + 0.5 - cy
    # inverse of a clockwise turn (screen coordinates, y down)
    sx, sy = cs * dx + sn * dy, -sn * dx + cs * dy
    if mirror_axis is not None:                                  # reflect across the piece's own axis first
        ax, ay = mirror_axis
        d = sx * ax + sy * ay
        sx, sy = 2 * d * ax - sx, 2 * d * ay - sy
    sx, sy = sx + cx, sy + cy
    ix, iy = np.floor(sx * UP).astype(np.int64), np.floor(sy * UP).astype(np.int64)
    ok = (ix >= 0) & (iy >= 0) & (ix < w * UP) & (iy < h * UP)
    out = np.full((h, w), -1, np.int64)
    out[ok] = big[iy[ok], ix[ok]]
    return out


def through(layer, imap):
    flat = np.append(layer.reshape(-1, 4), np.zeros((1, 4), np.uint8), axis=0)
    return flat[imap]


def rnd(v):
    return int(math.floor(v + 0.5))


def turned(point, centre, deg):
    t = math.radians(deg)
    cs, sn = math.cos(t), math.sin(t)
    dx, dy = point[0] - centre[0], point[1] - centre[1]
    return centre[0] + cs * dx - sn * dy, centre[1] + sn * dx + cs * dy


def redraw_bar(arr, imap, src_master, bar, centre, deg):
    """A thin straight bar (a sword's guard) comes out of any rotation ragged. Take out
    the pixels that were sampled from it and draw it again as a regular stepped line:
    hung on its attached edge (the side toward the blade), the same number of pixels
    thick in every column (or row), colours read along the master's rows."""
    x0, y0, x1, y1 = bar["rect"]                    # master pixels, half open
    H, W = arr.shape[:2]
    sy, sx = np.divmod(np.where(imap >= 0, imap, 0), W)
    hit = (imap >= 0) & (sx - PAD >= x0) & (sx - PAD < x1) & (sy - PAD >= y0) & (sy - PAD < y1)
    before = arr.copy()
    arr[hit] = 0
    t = math.radians(deg)
    e = (math.cos(t), math.sin(t))                  # along the bar
    f = (-math.sin(t), math.cos(t))                 # across it, away from the attached edge
    thick, length = y1 - y0, x1 - x0
    mid = ((x0 + x1) / 2.0, (y0 + y1) / 2.0)
    C = turned(mid, centre, deg)
    edge = (C[0] - thick / 2.0 * f[0], C[1] - thick / 2.0 * f[1])
    # how far past its true end the bar may run, in pixels along it: half a pixel gives
    # even pairs of steps on the 2:1 slopes; on the diagonal a quarter keeps it from growing
    slack = 0.25 if abs(abs(e[0]) - abs(e[1])) < 0.01 else 0.5
    major = 0 if abs(e[0]) >= abs(e[1]) else 1      # 0: walk the columns, 1: walk the rows
    minor = 1 - major
    n = max(thick, int(math.floor(thick / abs(e[major]) + 0.5)))
    sgn = 1 if f[minor] > 0 else -1
    lo = int(math.floor(C[major] - length)) - 1
    drawn = set()
    for A in range(lo, lo + 2 * length + 4):
        ac = A + 0.5
        s_ = (ac - C[major]) / e[major]
        if abs(s_) > length / 2.0 + slack:
            continue
        b_edge = edge[minor] + (ac - edge[major]) / e[major] * e[minor]
        B0 = int(math.ceil(b_edge - 0.5)) if sgn > 0 else int(math.floor(b_edge - 0.5))
        mx = min(x1 - 1, max(x0, int(math.floor(mid[0] + s_))))
        for k in range(n):
            B = B0 + sgn * k
            stripe = min(thick - 1, k * thick // n)
            X, Y = (A, B) if major == 0 else (B, A)
            arr[Y + PAD, X + PAD] = src_master[y0 + stripe + PAD, mx + PAD]
            drawn.add((X, Y))
    # a sampled pixel that the regular bar no longer covers, but that sits between two
    # opaque pixels, would be a hole: give it back
    ys, xs = np.nonzero(hit)
    for Y, X in zip(ys, xs):
        if arr[Y, X, 3]:
            continue
        if (arr[Y - 1, X, 3] and arr[Y + 1, X, 3]) or (arr[Y, X - 1, 3] and arr[Y, X + 1, 3]):
            arr[Y, X] = before[Y, X]


def apply_patches(arr, patches):
    """patches: list of (x0, y0, [rows]) in figure coordinates; '.' leave, '_' erase."""
    for x0, y0, rows in patches:
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == "." or ch == " ":
                    continue
                arr[y0 + j + PAD, x0 + i + PAD] = rgba_of(ch)


def show(arr, title):
    ys, xs = np.nonzero(arr[..., 3])
    if len(ys) == 0:
        print(title, "(empty)")
        return
    x0, x1, y0, y1 = xs.min() - 1, xs.max() + 2, ys.min() - 1, ys.max() + 2
    print(title, "  (figure coordinates)")
    print("      " + "".join(("%d" % (abs(x - PAD) // 10 % 10)) if (x - PAD) % 10 == 0 else " " for x in range(x0, x1)))
    print("      " + "".join("%d" % (abs(x - PAD) % 10) for x in range(x0, x1)))
    for y in range(y0, y1):
        print("%4d  " % (y - PAD) + "".join(key_of(tuple(arr[y, x])) for x in range(x0, x1)))


def main():
    args = sys.argv[1:]
    want_show = []
    while "--show" in args:
        i = args.index("--show")
        want_show.append(args[i + 1])
        del args[i:i + 2]
    review = "--review" in args

    src = load_src()
    fw, fh = src["figure"]["w"], src["figure"]["h"]
    pieces = {p["name"]: p for p in src["pieces"]}
    try:
        import patches as patch_mod
        PATCHES = patch_mod.PATCHES
    except ImportError:
        PATCHES = {}

    # every drawable layer, by piece
    layers = [dict(l, gear=None) for l in src["body"]]
    for gid, g in src["gear"].items():
        layers += [dict(l, gear=gid) for l in g["layers"]]
    layers.sort(key=lambda l: l["z"])
    by_piece = {}
    for l in layers:
        by_piece.setdefault(l["piece"], []).append(l)

    sprites = {}        # "name@angle" -> (cropped RGBA array, ox, oy)
    out_pieces = []
    review_rows = {}
    for p in src["pieces"]:
        name, c = p["name"], p["centre"]
        cw, ch = p.get("canvas", [fw, fh])
        P = (int(math.floor(c[0])), int(math.floor(c[1])))
        fp = (c[0] - P[0], c[1] - P[1])
        mine = by_piece.get(name, [])
        masters = {l["sprite"]: master(l["sprite"], cw, ch) for l in mine}
        comp = np.zeros((ch + 2 * PAD, cw + 2 * PAD, 4), np.uint8)
        for l in mine:
            m = masters[l["sprite"]]
            comp = np.where(m[..., 3:4] > 0, m, comp)
        # second masters for angles where the baked light would end up on the wrong side
        relit = set(p.get("relit", []))
        if relit:
            masters_r = {l["sprite"]: master(l["sprite"] + "__r", cw, ch) for l in mine}
            comp_r = np.zeros_like(comp)
            for l in mine:
                m = masters_r[l["sprite"]]
                comp_r = np.where(m[..., 3:4] > 0, m, comp_r)
            assert ((comp[..., 3] > 0) == (comp_r[..., 3] > 0)).all(), "relit master of %s changes the silhouette" % name
        children = [q for q in src["pieces"] if q["parent"] == name]
        joints = {}
        mirror = set(p.get("mirror", []))
        axis = None
        if mirror:
            to = p["axis_to"]
            n = math.hypot(to[0] - c[0], to[1] - c[1])
            axis = ((to[0] - c[0]) / n, (to[1] - c[1]) / n)
        for ang in p["angles"]:
            deg = degrees(src, ang)
            use_r = ang in relit
            imap = None if ang == 0 else index_map(comp_r if use_r else comp, c, deg, axis if ang in mirror else None)
            jt = {}
            for q in children:
                # where the pivot pixel of the child goes, counted from the pivot pixel of this
                # piece: the centre of the child is pinned to the point `at` here, which turns with it
                c2 = q["centre"]
                f2 = (c2[0] - math.floor(c2[0]), c2[1] - math.floor(c2[1]))
                r = turned(q["at"], c, deg)
                jt[q["name"]] = [rnd(fp[0] + r[0] - c[0] - f2[0]), rnd(fp[1] + r[1] - c[1] - f2[1])]
            for an, a in p.get("anchors", {}).items():
                r = turned(a, c, deg)
                jt[an] = [int(math.floor(r[0])) - P[0], int(math.floor(r[1])) - P[1]]
            for k, v in p.get("joint_fix", {}).get(str(ang), {}).items():
                jt[k] = v
            joints[str(ang)] = jt
            outs = {}
            for l in mine:
                src_m = (masters_r if use_r else masters)[l["sprite"]]
                arr = src_m if imap is None else through(src_m, imap)
                arr = arr.copy()
                key = "%s@%d" % (l["sprite"], ang)
                if imap is not None and ang % 90 != 0:
                    for bar in l.get("bars", []):
                        redraw_bar(arr, imap, src_m, bar, c, deg)
                apply_patches(arr, PATCHES.get(key, []))
                outs[l["sprite"]] = arr
            # one crop for all layers of the piece at this angle keeps them trivially aligned
            for sname, arr in outs.items():
                ys, xs = np.nonzero(arr[..., 3])
                key = "%s@%d" % (sname, ang)
                if len(ys) == 0:
                    sprites[key] = (np.zeros((1, 1, 4), np.uint8), 0, 0)
                else:
                    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
                    sprites[key] = (arr[y0:y1, x0:x1].copy(), int(x0 - PAD - P[0]), int(y0 - PAD - P[1]))
                if key in want_show:
                    show(arr, key)
            if review:
                review_rows.setdefault(name, []).append((ang, [outs[l["sprite"]] for l in mine], [l["sprite"] for l in mine]))
        op = {"name": name, "parent": p["parent"], "rest": p.get("rest", 0), "angles": p["angles"], "joints": joints}
        if not p["parent"]:
            op["at"] = [int(math.floor(p["at"][0])), int(math.floor(p["at"][1]))]
        if "range" in p:
            op["range"] = p["range"]
        if "slot" in p:
            op["slot"] = p["slot"]
        out_pieces.append(op)

    # for convenience: where each piece's pivot sits from its parent's pivot in the rest pose
    by_name = {op["name"]: op for op in out_pieces}
    for op in out_pieces:
        if op["parent"]:
            par = by_name[op["parent"]]
            op["rest_offset"] = par["joints"][str(par["rest"])][op["name"]]

    # effect pictures: out/sprites/fx__NAME.png, origin from fx.json
    fx = {}
    fxj = os.path.join(ROOT, "fx.json")
    if os.path.exists(fxj):
        fx = json.load(open(fxj, encoding="utf-8"))["fx"]
        for fname, f in fx.items():
            path = os.path.join(ROOT, "out", "sprites", f["sprite"] + ".png")
            if not os.path.exists(path):
                print("  effect %s: %s is not built yet, left out" % (fname, f["sprite"]))
                continue
            im = np.asarray(Image.open(path).convert("RGBA"))
            ys, xs = np.nonzero(im[..., 3])
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            sprites[f["sprite"] + "@0"] = (im[y0:y1, x0:x1].copy(), int(x0 - f["origin"][0]), int(y0 - f["origin"][1]))

    # pack: shelves, 1 px apart
    order = sorted(sprites, key=lambda k: (-sprites[k][0].shape[0], k))
    AW = 256
    x = y = shelf = 0
    place = {}
    for k in order:
        h, w = sprites[k][0].shape[:2]
        if x + w > AW:
            x, y, shelf = 0, y + shelf + 1, 0
        place[k] = (x, y)
        x += w + 1
        shelf = max(shelf, h)
    AH = y + shelf
    atlas = np.zeros((AH, AW, 4), np.uint8)
    table = {}
    for k in sorted(sprites):
        arr, ox, oy = sprites[k]
        px_, py_ = place[k]
        h, w = arr.shape[:2]
        atlas[py_:py_ + h, px_:px_ + w] = arr
        table[k] = {"rect": [px_, py_, w, h], "origin": [ox, oy]}
    Image.fromarray(atlas, "RGBA").save(os.path.join(ROOT, "atlas.png"))

    rig = {
        "format": "elaris-rig/1",
        "atlas": "atlas.png",
        "figure": src["figure"],
        "angle_degrees": src.get("angle_degrees", {}),
        "pieces": out_pieces,
        "layers": [{"sprite": l["sprite"], "piece": l["piece"], "z": l["z"]} for l in layers if l["gear"] is None],
        "slots": src["slots"],
        "gear": src["gear"],
        "materials": src["materials"],
        "fx": fx,
        "sprites": table,
    }
    text = json.dumps(rig, indent=1)
    # keep short arrays on one line
    text = re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2]", text)
    text = re.sub(r"\[\s+(-?\d+),\s+(-?\d+),\s+(-?\d+),\s+(-?\d+)\s+\]", r"[\1, \2, \3, \4]", text)
    open(os.path.join(ROOT, "rig.json"), "w", encoding="utf-8", newline="\n").write(text + "\n")
    print("atlas.png %dx%d, %d sprites; rig.json written" % (AW, AH, len(table)))

    if review:
        os.makedirs(os.path.join(ROOT, "bake", "review"), exist_ok=True)
        S = 8
        for name, rows in review_rows.items():
            if len(rows) < 2:
                continue
            tiles = []
            for ang, arrs, snames in rows:
                comp = np.zeros_like(arrs[0])
                for a in arrs:
                    comp = np.where(a[..., 3:4] > 0, a, comp)
                ys, xs = np.nonzero(comp[..., 3])
                x0, x1, y0, y1 = xs.min() - 1, xs.max() + 2, ys.min() - 1, ys.max() + 2
                pair = []
                for arr, bg in ((comp, FLOOR_DARK), (arrs[0], FLOOR_MID)):
                    t = Image.new("RGBA", (x1 - x0, y1 - y0), bg + (255,))
                    t.alpha_composite(Image.fromarray(arr[y0:y1, x0:x1], "RGBA"))
                    pair.append(t.convert("RGB").resize(((x1 - x0) * S, (y1 - y0) * S), Image.NEAREST))
                tiles.append((ang, pair))
            # flow layout
            maxw = 1900
            x = y = 6
            rowh = 0
            spots = []
            for ang, pair in tiles:
                w, h = pair[0].size[0] * 2 + 6, pair[0].size[1] + 14
                if x + w > maxw:
                    x, y, rowh = 6, y + rowh + 6, 0
                spots.append((x, y))
                x += w + 10
                rowh = max(rowh, h)
            sheet = Image.new("RGB", (maxw, y + rowh + 6), PAGE)
            d = ImageDraw.Draw(sheet)
            for (ang, pair), (X, Y) in zip(tiles, spots):
                d.text((X, Y), "%s @%d   all layers | first layer" % (name, ang), fill=(220, 210, 190))
                sheet.paste(pair[0], (X, Y + 12))
                sheet.paste(pair[1], (X + pair[0].size[0] + 6, Y + 12))
            sheet.save(os.path.join(ROOT, "bake", "review", name + ".png"))
        print("review sheets in bake/review/")

main()
