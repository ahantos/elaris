"""Print pictures as palette keys with rulers.

usage: python tools/dump.py a.png [b.png ...] [--box x0,y0,x1,y1]
Several pictures are printed side by side (same size expected).
"""
import sys
from PIL import Image
from pal import ascii_dump

a = sys.argv[1:]
box = None
if "--box" in a:
    i = a.index("--box")
    box = [int(v) for v in a[i + 1].split(",")]
    del a[i:i + 2]
blocks = []
for p in a:
    im = Image.open(p)
    lines = ascii_dump(im, *(box or (0, 0, None, None))).split("\n")
    blocks.append([p.replace("\\", "/").split("/")[-1]] + lines)
h = max(len(b) for b in blocks)
wid = [max(len(l) for l in b) + 2 for b in blocks]
for i in range(h):
    print("".join((b[i] if i < len(b) else "").ljust(w) for b, w in zip(blocks, wid)))
