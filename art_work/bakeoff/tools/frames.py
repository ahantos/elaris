"""Numbered frame sheet and an enlarged GIF from an animation strip.

usage: python tools/frames.py STRIP.png DURATIONS OUT_SHEET.png [--scale 3] [--cols 4] [--gif OUT.gif] [--gifscale 4]

DURATIONS is the pxl / Aseprite JSON beside the strip (frame durations are read from
it), or a comma-separated list of milliseconds. Frames are equal-width cells of the
strip. The sheet shows every frame on the dark floor, numbered, with its duration,
and repeats frame 0 after the last one so the loop seam can be judged.
"""
import json
import sys
from PIL import Image, ImageDraw

DARK = (0x3a, 0x32, 0x2c)
MID = (0x56, 0x48, 0x3a)
PAGE = (24, 22, 22)


def durations(arg):
    if arg.endswith(".json"):
        d = json.load(open(arg))
        fr = d["frames"]
        items = list(fr.values()) if isinstance(fr, dict) else fr
        return [int(f["duration"]) for f in items]
    return [int(v) for v in arg.split(",")]


def main():
    a = sys.argv[1:]
    opt = {"--scale": "3", "--cols": "4", "--gif": "", "--gifscale": "4"}
    for k in list(opt):
        if k in a:
            i = a.index(k)
            opt[k] = a[i + 1]
            del a[i:i + 2]
    strip, dur_arg, out = a[:3]
    durs = durations(dur_arg)
    im = Image.open(strip).convert("RGBA")
    n = len(durs)
    fw, fh = im.size[0] // n, im.size[1]
    frames = [im.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(n)]
    s, cols = int(opt["--scale"]), int(opt["--cols"])
    shown = frames + [frames[0]]
    labels = ["%d  %d ms" % (i, durs[i]) for i in range(n)] + ["0 again (loop)"]
    rows = (len(shown) + cols - 1) // cols
    cw, ch = fw * s + 8, fh * s + 22
    sheet = Image.new("RGBA", (cols * cw + 8, rows * ch + 8), PAGE + (255,))
    d = ImageDraw.Draw(sheet)
    for i, (f, l) in enumerate(zip(shown, labels)):
        x, y = 8 + (i % cols) * cw, 8 + (i // cols) * ch
        cell = Image.new("RGBA", f.size, DARK + (255,))
        cell.alpha_composite(f)
        sheet.alpha_composite(cell.resize((fw * s, fh * s), Image.NEAREST), (x, y + 16))
        d.text((x, y + 2), l, fill=(220, 210, 190))
    sheet.convert("RGB").save(out)
    print(out, sheet.size, "frames", n, "total ms", sum(durs))
    if opt["--gif"]:
        g = int(opt["--gifscale"])
        rgb = []
        for f in frames:
            cell = Image.new("RGBA", f.size, DARK + (255,))
            cell.alpha_composite(f)
            # RGB, not RGBA: quantising an RGBA picture gives a four-byte palette that the
            # GIF writer then reads three bytes at a time, which scrambles every colour
            rgb.append(cell.convert("RGB").resize((fw * g, fh * g), Image.NEAREST))
        cols = set()
        for f in rgb:
            cols |= {c for _, c in f.getcolors(1 << 20)}
        assert len(cols) <= 256, "too many colours for one GIF palette: %d" % len(cols)
        pal_im = Image.new("P", (1, 1))
        flat = [v for c in sorted(cols) for v in c]
        pal_im.putpalette(flat + [0] * (768 - len(flat)))
        big = [f.quantize(palette=pal_im, dither=Image.Dither.NONE) for f in rgb]
        big[0].save(opt["--gif"], save_all=True, append_images=big[1:], duration=durs, loop=0, disposal=1, optimize=False)
        # read back: every frame must match its source exactly
        chk = Image.open(opt["--gif"])
        assert chk.n_frames == len(rgb), "frame count %d, expected %d" % (chk.n_frames, len(rgb))
        for i, src in enumerate(rgb):
            chk.seek(i)
            got = chk.convert("RGB")
            assert got.size == src.size
            diff = sum(1 for a, b in zip(got.getdata(), src.getdata()) if a != b)
            assert diff == 0, "frame %d: %d pixels differ from the source" % (i, diff)
        print(opt["--gif"], "read back: %d frames, %d colours, every pixel matches the strip" % (len(rgb), len(cols)))


main()
