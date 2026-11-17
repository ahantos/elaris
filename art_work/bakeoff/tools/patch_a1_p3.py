import sys; sys.path.insert(0, sys.argv[2])
from patchlib import *
p = sys.argv[1]; s = load(p)
s = block(s, "CLOAK", '''
  11: [[9, "uUu"]],
  12: [[7, "fFuuFFf"]],
  13: [[6, "KfFFFuFf"]],
  14: [[5, "KfFFffff"]],
  15: [[5, "Kfffffff"]],
  16: [[5, "KffFFfff"]],
  17: [[5, "Kfffffff"]],
  18: [[5, "Kfffffff"]],
  19: [[4, "KfFFfffff"]],
  20: [[4, "Kffffffff"]],
  21: [[4, "Kffffffff"]],
  22: [[4, "KffFFffff"]],
  23: [[4, "Kffffffff"]],
  24: [[4, "Kffffffff"]],
  25: [[4, "KfFFfffff"]],
  26: [[4, "Kffffffff"]],
  27: [[3, "KfffffFFfffffff"]],
  28: [[3, "KfFFfffffffffff"]],
  29: [[3, "KffffffffffffKf"]],
  30: [[3, "KfffffFFffffKKf"]],
  31: [[3, "KfFFffffffffKKf"]],
  32: [[3, "KfffffffffffKKf"]],
  33: [[3, "KffffFFfffffKKf"]],
  34: [[3, "KfFFffffffffKKf"]],
  35: [[3, "KfffffffffffKKK"]],
  36: [[3, "KfffFFfffffKKK"]],
  37: [[3, "KfffffffffffKK"]],
  38: [[4, "KfK.KfK.KfK"]],
  39: [[5, "K...K...K"]],
''')
s = block(s, "LEGS", '''
  24: [[11, "KLmMMM45mLl"]],
  25: [[11, "KlLmmm23LLl"]],
  26: [[10, "KfFFuuFFuuuF"]],
  27: [[10, "KfFFFFFFFuFf"]],
  28: [[10, "KffFFffFFFff"]],
  29: [[10, "KfFuuFFFuuFf"]],
  30: [[10, "KffFFFffFFFK"]],
  31: [[11, "fF.FF.Fu.f"]],
  32: [[12, "f..f..F"]],
''')
s = block(s, "BOOTS", '''
  39: [[9, "FuFuuF"], [19, "FuFFu"]],
  40: [[8, "KfFffFf"], [18, "ffFffF"]],
  41: [[9, "KllLLl"], [19, "llLLl"]],
  42: [[9, "KlLmmL"], [19, "lLLmL"]],
  43: [[9, "KlLmmL"], [19, "llLLl"]],
  44: [[9, "KllLmL"], [19, "lLLmmL"]],
  45: [[9, "KlLmmmL"], [18, "KlLLmmmL"]],
  46: [[8, "KlLLmmmMm"], [18, "lllllLLl"]],
  47: [[8, "lllllLLLl"]],
''')
for y, r in {
  28: '[[11, "Kbccdcabbcb"]]', 29: '[[11, "Kbccdcabbccb"]]', 30: '[[10, "Kbccdcaabbccb"]]',
  31: '[[10, "Kabccc"], [17, "aabbbb"]]', 32: '[[10, "Kabcdc"], [18, "abbcb"]]',
  33: '[[10, "Kbbcdc"], [18, "abccb"]]', 34: '[[10, "Kbccdc"], [18, "abbccb"]]',
  35: '[[10, "Kbcdd"], [19, "abccb"]]', 36: '[[10, "Kabcc"], [19, "aabb"]]',
  37: '[[9, "Kabbcc"], [19, "abcb"]]', 38: '[[9, "Kabcc"], [19, "abcb"]]',
}.items():
    s = setrow(s, "BODY", y, r)
s = setrow(s, "WEAPON", 0, '[[5, "4"]]')
s = setrow(s, "WEAPON", 1, '[[4, "24"]]')
# reflection bands offset by one row between the two blade planes
for y, r in {9: "0245", 10: "0245", 11: "0244", 12: "0144", 13: "0134", 14: "0123", 15: "0234", 16: "0244",
             20: "0244", 21: "0234", 22: "0244"}.items():
    s = setrow(s, "WEAPON", y, '[[3, "%s"]]' % r)
s = rep(s, 'f: "#4b403b", F: "#7b6b57", u: "#a39378", U: "#c7b999"', 'f: "#40363a", F: "#6a5c4c", u: "#928369", U: "#b9aa88"')
s = rep(s, 'd: "#d7a273"', 'd: "#dba878"')
save(p, s)
