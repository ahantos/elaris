"""The A1 palette (copied from art_work/barbarian/a1.px.js) and small pixel helpers.

Every rig picture uses these colours only, so a picture can be turned back into
palette keys for printing, patching and recolouring.
"""
from PIL import Image

PAL = {
    "K": "#17121c",
    "a": "#5f2f33", "b": "#8c5540", "c": "#b57a55", "d": "#dba878",
    "h": "#2b2126", "H": "#55403a",
    "f": "#40363a", "F": "#6a5c4c", "u": "#928369", "U": "#b9aa88",
    "l": "#38211f", "L": "#59362a", "m": "#7e4c36", "M": "#a07048",
    "W": "#7a5c3a", "y": "#9f8052",
    "0": "#0f1a28", "1": "#202e37", "2": "#3d4f56", "3": "#819796", "4": "#c7cfcc", "5": "#f1f2ec",
    "p": "#24141c", "q": "#4c2a26", "r": "#774528", "s": "#a06c34", "t": "#c9984f", "v": "#ecd6a2",
}
# "w" in a1.px.js is the same colour as "L" (shield wood darkest = leather shadow)
ALIAS = {"w": "L"}

# material tables: the six slots 0..5 of the metal gear
MATERIALS = {
    "steel": ["#0f1a28", "#202e37", "#3d4f56", "#819796", "#c7cfcc", "#f1f2ec"],
    "bronze": ["#24141c", "#4c2a26", "#774528", "#a06c34", "#c9984f", "#ecd6a2"],
}

FLOOR_DARK = (0x3a, 0x32, 0x2c)
FLOOR_MID = (0x56, 0x48, 0x3a)
PAGE = (24, 22, 22)


def rgb(hexs):
    hexs = hexs.lstrip("#")
    return tuple(int(hexs[i:i + 2], 16) for i in (0, 2, 4))


RGB = {k: rgb(v) for k, v in PAL.items()}
KEY = {v: k for k, v in RGB.items()}


def key_of(p):
    """palette key of an RGBA pixel, '.' for transparent, '?' for an unknown colour"""
    if p[3] == 0:
        return "."
    return KEY.get(tuple(p[:3]), "?")


def rgba_of(k):
    if k in (".", "_"):
        return (0, 0, 0, 0)
    k = ALIAS.get(k, k)
    return RGB[k] + (255,)


def ascii_dump(im, x0=0, y0=0, x1=None, y1=None):
    im = im.convert("RGBA")
    w, h = im.size
    x1 = w if x1 is None else x1
    y1 = h if y1 is None else y1
    px = im.load()
    out = ["     " + "".join(str((x // 10) % 10) if x % 10 == 0 else " " for x in range(x0, x1)),
           "     " + "".join(str(x % 10) for x in range(x0, x1))]
    for y in range(y0, y1):
        out.append("%3d  " % y + "".join(key_of(px[x, y]) for x in range(x0, x1)))
    return "\n".join(out)


def swap_material(im, material):
    """recolour the six metal slots of a picture (steel master) to another material"""
    if material == "steel":
        return im
    src = [rgb(c) for c in MATERIALS["steel"]]
    dst = [rgb(c) for c in MATERIALS[material]]
    table = dict(zip(src, dst))
    im = im.copy()
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            p = px[x, y]
            if p[3] and p[:3] in table:
                px[x, y] = table[p[:3]] + (255,)
    return im
