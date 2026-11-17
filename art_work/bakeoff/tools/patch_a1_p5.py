import sys; sys.path.insert(0, sys.argv[2])
from patchlib import *
p = sys.argv[1]; s = load(p)
s = block(s, "CLOAK", '''
  11: [[9, "uuu"]],
  12: [[7, "fFuuFFf"]],
  13: [[6, "fFFFFuFf"]],
  14: [[5, "FFffffff"]],
  15: [[5, "FFffffff"]],
  16: [[5, "FFffffff"]],
  17: [[5, "FFffffff"]],
  18: [[5, "FFffffff"]],
  19: [[4, "FFFffffff"]],
  20: [[4, "FFFffffff"]],
  21: [[4, "FFFffffff"]],
  22: [[4, "FFFffffff"]],
  23: [[4, "FFFffffff"]],
  24: [[4, "FFFffffff"]],
  25: [[4, "FFFffffff"]],
  26: [[4, "FFFffffff"]],
  27: [[3, "uFFFFffffffffff"]],
  28: [[3, "uFFFffffffffff"]],
  29: [[3, "FFFFFffffffffKf"]],
  30: [[3, "FFfFFffffffffKf"]],
  31: [[3, "uFfFFFffffffKKf"]],
  32: [[3, "uFFfFFffffffKKf"]],
  33: [[3, "FFFfFFffffffKKf"]],
  34: [[3, "FFFFfFffffffKKf"]],
  35: [[3, "uFFFfFffffffKKK"]],
  36: [[3, "uFF.FFf.fff.KKK"]],
  37: [[4, "Ff..Ff"]],
''')
s = setrow(s, "BODY", 6, '[[13, "Khhhbdd"]]')
s = setrow(s, "TORSO_GEAR", 19, '[[18, "lm"]]')
s = setrow(s, "TORSO_GEAR", 20, '[[19, "lm"]]')
s = setrow(s, "SHIELD", 20, '[[21, "1WW2454WW3"]]')
s = setrow(s, "SHIELD", 21, '[[21, "1WW2333WW3"]]')
s = setrow(s, "LEGS", 25, '[[11, "Klmmmm22mLl"]]')
s = setrow(s, "LEGS", 32, '[[11, "ff..F..F"]]')
s = setrow(s, "NEAR_ARM", 30, '[[5, "bbb"]]')
s = setrow(s, "BOOTS", 46, '[[8, "KllLmmmMm"], [18, "lllllLLl"]]')
for y, r in {13: "2134", 14: "1034", 15: "1034", 16: "2134"}.items():
    s = setrow(s, "WEAPON", y, '[[3, "%s"]]' % r)
s = rep(s, 'p: "#24141c", q: "#4f2a26", r: "#7a4628", s: "#ad782f", t: "#d6a84c", v: "#f0deaa"',
           'p: "#24141c", q: "#4c2a26", r: "#774528", s: "#a06c34", t: "#c9984f", v: "#ecd6a2"')
save(p, s)
