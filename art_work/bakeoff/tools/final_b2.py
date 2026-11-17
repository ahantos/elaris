"""final_b2.png: the kept longsword and the slim version side by side.
Run from the work folder: python tools/final_b2.py"""
from PIL import Image, ImageDraw
DARK=(0x3a,0x32,0x2c); MID=(0x56,0x48,0x3a); SLOT=(0x1e,0x24,0x22); PAGE=(24,22,22)
a = Image.open("out/sprites/longsword.png").convert("RGBA")
b = Image.open("out/sprites/longsword_slim.png").convert("RGBA")
a1 = Image.open("out/sprites/a1.png").convert("RGBA")
def pair(x, y, gap=2):
    p = Image.new("RGBA", (x.size[0]+gap+y.size[0], max(x.size[1], y.size[1])), (0,0,0,0))
    p.alpha_composite(x, (0, p.size[1]-x.size[1])); p.alpha_composite(y, (x.size[0]+gap, p.size[1]-y.size[1])); return p
def on(bg, im, s, pad=2):
    t = Image.new("RGBA", (im.size[0]+2*pad, im.size[1]+2*pad), bg+(255,)); t.alpha_composite(im,(pad,pad))
    return t.resize((t.size[0]*s, t.size[1]*s), Image.NEAREST)
def grey(im):
    g = im.convert("LA").convert("RGBA"); g.putalpha(im.getchannel("A")); return g
ab = pair(a, b)
cells = [on(DARK,ab,1), on(DARK,ab,2), on(DARK,ab,4), on(MID,ab,4), on(SLOT,ab,4), on(MID,grey(ab),4), on(DARK, pair(a1, b, 4), 4)]
H = max(c.size[1] for c in cells); Wd = sum(c.size[0]+6 for c in cells)+6
sh = Image.new("RGBA",(Wd,H+26),PAGE+(255,)); x=6; d = ImageDraw.Draw(sh)
labels = ["1x","2x","4x dark floor: longsword | longsword_slim","4x mid floor","4x dark slot","greyscale","A1 with the slim sword, 4x"]
for c, l in zip(cells, labels):
    sh.alpha_composite(c,(x,20+H-c.size[1])); d.text((x, 4), l, fill=(220,210,190)); x+=c.size[0]+6
sh.convert("RGB").save("final_b2.png"); print("final_b2.png", sh.size)
