"""Stack pictures top to bottom with a caption above each.
usage: python tools/stack.py OUT.png "caption" picture.png ["caption" picture.png ...]"""
import sys
from PIL import Image, ImageDraw
PAGE = (24, 22, 22)
a = sys.argv[1:]
out, pairs = a[0], [(a[i], Image.open(a[i + 1]).convert("RGB")) for i in range(1, len(a), 2)]
W = max(im.size[0] for _, im in pairs) + 12
H = sum(im.size[1] + 26 for _, im in pairs) + 6
sheet = Image.new("RGB", (W, H), PAGE)
d = ImageDraw.Draw(sheet)
y = 6
for cap, im in pairs:
    d.text((8, y + 3), cap, fill=(236, 226, 200))
    sheet.paste(im, (6, y + 18))
    y += im.size[1] + 26
sheet.save(out)
print(out, sheet.size)
