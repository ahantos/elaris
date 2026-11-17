"""Review sheet for the item picture: 1x, 2x, 4x on the two floors and a dark slot, greyscale, and beside A1 at the same scale."""
from PIL import Image
DARK=(0x3a,0x32,0x2c); MID=(0x56,0x48,0x3a); SLOT=(0x1e,0x24,0x22); PAGE=(24,22,22)
it = Image.open("out/sprites/longsword.png").convert("RGBA")
a1 = Image.open("out/sprites/a1.png").convert("RGBA")
def on(bg, im, s, pad=2):
    t = Image.new("RGBA", (im.size[0]+2*pad, im.size[1]+2*pad), bg+(255,)); t.alpha_composite(im,(pad,pad))
    return t.resize((t.size[0]*s, t.size[1]*s), Image.NEAREST)
def grey(im):
    g = im.convert("LA").convert("RGBA"); g.putalpha(im.getchannel("A")); return g
cells = [on(DARK,it,1), on(DARK,it,2), on(DARK,it,4), on(MID,it,4), on(SLOT,it,4), on(MID,grey(it),4)]
pair = Image.new("RGBA", (32+4+32, 96), (0,0,0,0)); pair.alpha_composite(a1,(0,48)); pair.alpha_composite(it,(36,0))
cells.append(on(DARK, pair, 4))
H = max(c.size[1] for c in cells); Wd = sum(c.size[0]+6 for c in cells)+6
sh = Image.new("RGBA",(Wd,H+12),PAGE+(255,)); x=6
for c in cells: sh.alpha_composite(c,(x,6+H-c.size[1])); x+=c.size[0]+6
sh.convert("RGB").save("final_b.png"); print(sh.size)
