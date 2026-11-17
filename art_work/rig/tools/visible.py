"""Which pixels of one A1 layer are visible in the assembled A1 figure.
usage: python tools/visible.py LAYER   (cloak, body, ...)
Prints the layer; pixels hidden by a later layer are shown as ':'.
"""
import sys
from PIL import Image
sys.path.insert(0, "tools")
from pal import key_of
ORDER = ["cloak", "body", "legs", "boots", "torso_gear", "helmet", "shield", "near_arm", "arm_gear", "weapon"]
name = sys.argv[1]
ims = {n: Image.open("ref/out/sprites/a1/%s.png" % n).convert("RGBA").load() for n in ORDER}
later = ORDER[ORDER.index(name) + 1:]
print("     " + "".join(str(x % 10) for x in range(32)))
for y in range(48):
    row = ""
    for x in range(32):
        p = ims[name][x, y]
        if p[3] == 0:
            row += "."
        elif any(ims[l][x, y][3] for l in later):
            row += ":"
        else:
            row += key_of(p)
    print("%3d  %s" % (y, row))
