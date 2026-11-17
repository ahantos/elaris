"""Checks from the theory reference's checklist that a script can do.

usage: python check.py sprite.png [more.png ...]

- orphans (same rule as pxl lint, but the full list, with the colour)
- colour count, near-duplicate pairs
- semi-transparent pixels
- share of the outer edge that is lighter than each floor colour
- one-pixel protrusions (an opaque pixel whose left and right, or upper and lower,
  neighbours are both transparent, on a run of 3 or more)
- value spread: darkest and lightest luminance, share of pixels in four value bins
"""
import sys
from PIL import Image

FLOORS = {"dark #3a322c": (0x3a, 0x32, 0x2c), "mid #56483a": (0x56, 0x48, 0x3a)}
N8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]


def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def check(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()

    def get(x, y):
        if x < 0 or y < 0 or x >= w or y >= h:
            return None
        p = px[x, y]
        return None if p[3] == 0 else p

    print("==", path.replace("\\", "/").split("/")[-1], "%dx%d" % (w, h))
    semi = [(x, y) for y in range(h) for x in range(w) if 0 < px[x, y][3] < 255]
    print("  semi-transparent pixels:", len(semi))

    orphans = []
    for y in range(h):
        for x in range(w):
            c = get(x, y)
            if c is None:
                continue
            if any(get(x + dx, y + dy) == c for dx, dy in N8):
                continue
            if any(get(x + dx, y + dy) is None for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                continue
            around = sum(lum(get(x + dx, y + dy) or (0, 0, 0)) for dx, dy in N8) / 8
            if abs(lum(c) - around) < 48:
                orphans.append((x, y, "#%02x%02x%02x" % c[:3]))
    print("  orphans: %d" % len(orphans))
    for o in orphans:
        print("     %2d,%2d %s" % o)

    cols = {}
    for y in range(h):
        for x in range(w):
            c = get(x, y)
            if c is not None:
                cols[c[:3]] = cols.get(c[:3], 0) + 1
    total = sum(cols.values())
    print("  colours: %d   opaque pixels: %d" % (len(cols), total))
    ks = list(cols)
    for i in range(len(ks)):
        for j in range(i + 1, len(ks)):
            d = sum((a - b) ** 2 for a, b in zip(ks[i], ks[j])) ** 0.5
            if d < 10:
                print("  near-duplicate: #%02x%02x%02x ~ #%02x%02x%02x (%.1f)" % (ks[i] + ks[j] + (d,)))

    edge = []
    for y in range(h):
        for x in range(w):
            c = get(x, y)
            if c is None:
                continue
            if any(get(x + dx, y + dy) is None for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                edge.append(c)
    for name, f in FLOORS.items():
        lf = lum(f)
        lighter = sum(1 for c in edge if lum(c) > lf + 12)
        darker = sum(1 for c in edge if lum(c) < lf - 12)
        print("  edge vs floor %s: %d%% clearly lighter, %d%% clearly darker, %d%% within 12"
              % (name, 100 * lighter // len(edge), 100 * darker // len(edge),
                 100 * (len(edge) - lighter - darker) // len(edge)))

    thin = []
    for y in range(h):
        for x in range(w):
            if get(x, y) is None:
                continue
            if get(x - 1, y) is None and get(x + 1, y) is None:
                thin.append((x, y, "v"))
            elif get(x, y - 1) is None and get(x, y + 1) is None:
                thin.append((x, y, "h"))
    print("  1-px-thick silhouette pixels: %d %s" % (len(thin), thin[:24]))

    ls = sorted(lum(c) for c in cols)
    bins = [0, 0, 0, 0]
    for c, n in cols.items():
        bins[min(3, int(lum(c) / 64))] += n
    print("  luminance range: %.0f to %.0f; share by quarter (dark to light): %s"
          % (ls[0], ls[-1], " ".join("%d%%" % (100 * b // total) for b in bins)))


for p in sys.argv[1:]:
    check(p)
