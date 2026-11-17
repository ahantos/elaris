"""Read rig.json + atlas.png and put a posed figure together.

This is the reference reader for the data format (README.md): the game does the same
thing with its own drawing calls. Nothing here turns or scales a picture; a pose only
chooses a pre-drawn variant per piece and adds whole-pixel offsets.
"""
import json
import os

from PIL import Image

from pal import rgb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FULL_GEAR = {"cloak": "wolf_cloak", "legs": "fur_kilt", "boots": "fur_boots", "torso_gear": "baldric",
             "helmet": "iron_cap", "shield": "round_shield", "arm_gear": "fur_bracer", "weapon": "broad_sword"}


def gear_set(spec):
    """'full', 'bare', or 'full-helmet-shield' style: full gear minus the named slots"""
    parts = spec.split("-")
    g = dict(FULL_GEAR) if parts[0] == "full" else {}
    if parts[0] == "body":
        return {}
    for slot in parts[1:]:
        g.pop(slot, None)
    return g


class Rig:
    def __init__(self, root=ROOT):
        self.root = root
        self.data = json.load(open(os.path.join(root, "rig.json"), encoding="utf-8"))
        self.atlas = Image.open(os.path.join(root, self.data["atlas"])).convert("RGBA")
        self.pieces = {p["name"]: p for p in self.data["pieces"]}
        self.order = [p["name"] for p in self.data["pieces"]]          # parents come first
        self._cache = {}

    # ---- pictures
    def sprite(self, key, material="steel"):
        ck = (key, material)
        if ck not in self._cache:
            s = self.data["sprites"][key]
            x, y, w, h = s["rect"]
            im = self.atlas.crop((x, y, x + w, y + h))
            if material != "steel":
                src = [rgb(c) for c in self.data["materials"]["steel"]]
                dst = [rgb(c) for c in self.data["materials"][material]]
                table = dict(zip(src, dst))
                px = im.load()
                for yy in range(h):
                    for xx in range(w):
                        p = px[xx, yy]
                        if p[3] and p[:3] in table:
                            px[xx, yy] = table[p[:3]] + (255,)
            self._cache[ck] = (im, s["origin"])
        return self._cache[ck]

    # ---- pose
    def solve(self, pose):
        """pose: {piece: {"dx","dy","a"}} -> {piece: (x, y, angle)} pivot pixel in figure coordinates"""
        out = {}
        for name in self.order:
            p = self.pieces[name]
            q = pose.get(name, {})
            a = int(q.get("a", p.get("rest", 0)))
            if a not in p["angles"]:
                raise ValueError("piece %s has no variant at %d degrees (has %s)" % (name, a, p["angles"]))
            dx, dy = int(q.get("dx", 0)), int(q.get("dy", 0))
            if p["parent"] is None:
                x, y = p["at"][0] + dx, p["at"][1] + dy
            else:
                px_, py_, pa = out[p["parent"]]
                j = self.pieces[p["parent"]]["joints"][str(pa)][name]
                x, y = px_ + j[0] + dx, py_ + j[1] + dy
            out[name] = (x, y, a)
        return out

    def degrees(self, label):
        """the true angle behind a label of the angle set (27 stands for 26.565 ...)"""
        v = float(self.data.get("angle_degrees", {}).get(str(abs(label)), abs(label)))
        return v if label >= 0 else -v

    def bend(self, pose, name):
        """angle of a piece minus the angle of its parent, in degrees, -180 < bend <= 180"""
        p = self.pieces[name]
        a = self.degrees(int(pose.get(name, {}).get("a", p.get("rest", 0))))
        q = self.pieces[p["parent"]]
        b = self.degrees(int(pose.get(q["name"], {}).get("a", q.get("rest", 0))))
        d = (a - b) % 360.0
        return d - 360.0 if d > 180.0 else d

    def limit_faults(self, pose):
        """joints bent outside their range: [(piece, bend, [lo, hi])]"""
        out = []
        for name in self.order:
            p = self.pieces[name]
            if not p["parent"] or "range" not in p:
                continue
            lo, hi = p["range"]
            d = self.bend(pose, name)
            if not (lo - 0.6 <= d <= hi + 0.6 or lo - 0.6 <= d - 360.0 <= hi + 0.6):
                out.append((name, d, p["range"]))
        return out

    def anchor(self, solved, piece, name):
        x, y, a = solved[piece]
        j = self.pieces[piece]["joints"][str(a)][name]
        return (x + j[0], y + j[1])

    def layers(self, gear):
        """drawables for a gear set {slot: gear id}, back to front"""
        ls = [dict(l, gear=None) for l in self.data["layers"]]
        for slot, gid in gear.items():
            if gid:
                g = self.data["gear"][gid]
                assert g["slot"] == slot, (gid, slot)
                ls += [dict(l, gear=gid) for l in g["layers"]]
        return sorted(ls, key=lambda l: l["z"])

    def draw_list(self, pose, gear, material="steel"):
        solved = self.solve(pose)
        out = []
        for l in self.layers(gear):
            x, y, a = solved[l["piece"]]
            metal = l["gear"] and self.data["gear"][l["gear"]].get("metal")
            mat = material if metal else "steel"
            im, (ox, oy) = self.sprite("%s@%d" % (l["sprite"], a), mat)
            out.append({"layer": l, "im": im, "x": x + ox, "y": y + oy})
        return out, solved

    def render(self, pose, gear, material="steel", size=None, origin=(0, 0), only=None):
        """-> RGBA picture; the figure's (0, 0) is put at `origin` on a canvas of `size`"""
        fw, fh = self.data["figure"]["w"], self.data["figure"]["h"]
        size = size or (fw, fh)
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        items, solved = self.draw_list(pose, gear, material)
        for it in items:
            if only and it["layer"]["piece"] not in only:
                continue
            paste(canvas, it["im"], it["x"] + origin[0], it["y"] + origin[1])
        return canvas, solved


def paste(canvas, im, x, y):
    """alpha_composite that tolerates pictures hanging over the canvas edge"""
    w, h = im.size
    cw, ch = canvas.size
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, cw), min(y + h, ch)
    if x1 <= x0 or y1 <= y0:
        return
    canvas.alpha_composite(im.crop((x0 - x, y0 - y, x1 - x, y1 - y)), (x0, y0))
