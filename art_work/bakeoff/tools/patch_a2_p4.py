import sys; sys.path.insert(0, sys.argv[2])
from patchlib import *
p = sys.argv[1]; s = load(p)
# palette: hair and leather darks merged, bronze light pushed away from brass
s = rep(s, 'h: "#33261f", H: "#5a4434"', 'h: "#33261f", H: "#5c4130"')
s = rep(s, 'l: "#3a2620", L: "#5f3f2e", m: "#8a6244"', 'l: "#33261f", L: "#5c4130", m: "#8a6244"')
s = rep(s, 'v: "#d8ad58"', 'v: "#d0a04c"')
S = lambda name, y, r: setrow(s, name, y, r)
s = S("CLOAK", 11, '[[1, "KFFuFFFFFuFK"], [22, "KFuuK"]]')
for y, r in {
  5: '[[14, "KhHHHHHK"]]',
  14: '[[9, "KbccdddddddddcKbcK"], [12, "KhhhK"]]',
  16: '[[9, "KbccdddcddddccKbbK"], [13, "KK"]]',
  22: '[[10, "KabcccbcddcbK"], [23, "KabbcccK"]]',
  24: '[[10, "KabcccbcddcbK"], [23, "KKaabbcK"]]',
  27: '[[10, "KaabbbbbbbbbK"]]',
  44: '[[7, "KabccbKKK"], [19, "KabcccccK"]]',
  46: '[[6, "KabbbbbccK"], [19, "KKKKKKKKK"]]',
}.items(): s = S("BODY", y, r)
for y, r in {
  18: '[[4, "KabbccK"]]',
  21: '[[4, "KabcccK"], [13, "KKKK"]]',
  22: '[[4, "KabcaaKKKcddcK"]]',
  25: '[[4, "KKabbbbbbbbbbK"]]',
}.items(): s = S("NEAR_ARM", y, r)
s = S("ARM_GEAR", 19, '[[4, "KyyYYyK"]]')
s = S("ARM_GEAR", 25, '[[10, "LLL"]]')
s = block(s, "TORSO_GEAR", '''
  14: [[20, "lLm"]],
  15: [[19, "lLm"]],
  16: [[18, "lYY"]],
  17: [[17, "lyy"]],
  18: [[16, "lLm"]],
  19: [[15, "lLm"]],
  20: [[14, "lLm"]],
  21: [[13, "lLm"]],
  22: [[12, "lLm"]],
  23: [[11, "lLm"]],
  24: [[11, "lLm"]],
  25: [[11, "lLm"]],
  26: [[11, "lLm"]],
''')
s = S("SHIELD", 22, '[[20, "K1RR444ee3K"]]')
s = S("SHIELD", 23, '[[20, "K1R24553e3K"]]')
s = S("LEGS", 28, '[[9, "KLLLLLLLmyYyLLK"]]')
s = S("LEGS", 31, '[[9, "KKrRRReRReeeeKK"]]')
s = block(s, "BOOTS", '''
  38: [[6, "KKKKKKKKK"], [18, "KKKKKKKKK"]],
  39: [[6, "KfuuFuuFK"], [18, "KfuFFuuFK"]],
  40: [[6, "KfFFFuFFK"], [18, "KfFFFFFFK"]],
  41: [[6, "KfFFFFFFK"], [18, "KLLLmmLLK"]],
  42: [[6, "KLLLmmLLK"], [18, "KfFFuuFFK"]],
  43: [[6, "KfFFuuFFK"], [18, "KfFFFFFFKK"]],
  44: [[6, "KfFFFFFFKK"], [18, "KffFFFFuuFK"]],
  45: [[5, "KffFFFFuuFFK"], [18, "KllllllLLLK"]],
  46: [[5, "KlllllllLLLK"], [18, "KKKKKKKKKKK"]],
  47: [[5, "KKKKKKKKKKKK"]],
''')
# blade: two crisp planes, a dark reflection band; pommel one pixel left
for y, r in {
  3: '[[3, "K2245K"]]', 4: '[[3, "K224RK"]]', 5: '[[4, "K224RK"]]', 6: '[[4, "K224rK"]]',
  7: '[[5, "K2244K"]]', 8: '[[5, "K2244K"]]', 9: '[[6, "K2245K"]]', 10: '[[6, "K2245K"]]',
  11: '[[7, "K1134K"]]', 12: '[[7, "K1134K"]]', 13: '[[8, "K2244K"]]', 14: '[[8, "K2244K"]]',
  15: '[[9, "K2244K"]]', 16: '[[9, "K2244K"]]', 17: '[[10, "K2245K"]]', 18: '[[9, "KK2245KKKK"]]',
  26: '[[13, "K44K"]]', 27: '[[13, "K33K"]]', 28: '[[14, "KK"]]',
}.items(): s = S("WEAPON", y, r)
save(p, s)
