"""Joint limits: every test pose and every frame of every animation.

usage: python tools/check_limits.py
Prints each joint's range, how far it is actually bent across everything checked,
and every pose or frame that bends a joint outside its range. Exit code 1 if any does.
(The same test runs inside tools/preview.py for the animation being previewed.)
"""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from riglib import Rig, ROOT  # noqa: E402


def main():
    rig = Rig()
    items = [("pose rest", {})]
    poses = json.load(open(os.path.join(ROOT, "poses.json"), encoding="utf-8"))
    items += [("pose " + n, p) for n, p in poses.items() if n != "rest"]
    for path in sorted(glob.glob(os.path.join(ROOT, "anims", "*.json"))):
        a = json.load(open(path, encoding="utf-8"))
        items += [("%s frame %d" % (a["name"], i), f.get("pieces", {})) for i, f in enumerate(a["frames"])]
    used = {}
    faults = []
    for label, pose in items:
        for name in rig.order:
            p = rig.pieces[name]
            if p["parent"] and "range" in p:
                d = rig.bend(pose, name)
                u = used.setdefault(name, [d, d])
                u[0], u[1] = min(u[0], d), max(u[1], d)
        for name, d, rng in rig.limit_faults(pose):
            faults.append("%s: %s is bent %+.0f degrees, its range is %d..%d" % (label, name, d, rng[0], rng[1]))
    print("checked %d poses and frames" % len(items))
    print("%-16s %-12s %s" % ("joint", "range", "bend actually used"))
    for name, (lo, hi) in used.items():
        rng = rig.pieces[name]["range"]
        print("%-16s %4d..%-5d  %+5.0f .. %+5.0f" % (name, rng[0], rng[1], lo, hi))
    if faults:
        print("%d OUT OF RANGE:" % len(faults))
        for f in faults:
            print("  " + f)
        return 1
    print("every joint is inside its range everywhere")
    return 0


if __name__ == "__main__":
    sys.exit(main())
