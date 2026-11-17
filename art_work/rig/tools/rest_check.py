"""Rest pose against the A1 build: count the pixels that differ, per gear set.

usage: python tools/rest_check.py
Needs ref/out (pxl build ref/a1.px.js) and a bake.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, gear_set, ROOT  # noqa: E402
from pal import key_of  # noqa: E402

CASES = [
    ("a1", "full", "steel"),
    ("a1_bronze", "full", "bronze"),
    ("a1_nohelm_noshield", "full-helmet-shield", "steel"),
    ("a1_bare", "full-helmet-shield-weapon-torso_gear", "steel"),
    ("a1_body", "body", "steel"),
]


def diff(a, b):
    pa, pb = a.load(), b.load()
    out = []
    for y in range(a.size[1]):
        for x in range(a.size[0]):
            p, q = pa[x, y], pb[x, y]
            if (p[3] == 0 and q[3] == 0) or p == q:
                continue
            out.append((x, y, key_of(q), key_of(p)))
    return out


def main():
    rig = Rig()
    total = 0
    for ref, spec, mat in CASES:
        want = Image.open(os.path.join(ROOT, "ref", "out", "sprites", ref + ".png")).convert("RGBA")
        got, _ = rig.render({}, gear_set(spec), mat)
        d = diff(got, want)
        total += len(d)
        print("%-20s gear %-40s %-7s differing pixels: %d" % (ref, spec, mat, len(d)))
        for x, y, w, g in d[:40]:
            print("     %2d,%2d  A1 %s  rig %s" % (x, y, w, g))
    print("total:", total)
    return total


if __name__ == "__main__":
    main()
