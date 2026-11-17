import re, sys, io
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()

def block(name, body):
    global s
    pat = re.compile(r"const %s = rows\(\{.*?\n\}\)" % name, re.S)
    assert pat.search(s), name
    s = pat.sub(lambda m: "const %s = rows({\n%s\n})" % (name, body.strip("\n")), s, count=1)

block("CLOAK", '''
  11: [[9, "uUu"]],
  12: [[7, "fFuuFFf"]],
  13: [[6, "KfFFFuFf"]],
  14: [[5, "KffFFfFf"]],
  15: [[5, "KfffFFff"]],
  16: [[5, "KffffFff"]],
  17: [[5, "KfFfffff"]],
  18: [[5, "KfFFffff"]],
  19: [[4, "KffFFffff"]],
  20: [[4, "KfffFffff"]],
  21: [[4, "KfFffffff"]],
  22: [[4, "KfFFfffff"]],
  23: [[4, "KffFFffff"]],
  24: [[4, "KfffFffff"]],
  25: [[4, "KfFffffff"]],
  26: [[4, "KfFFfffff"]],
  27: [[3, "KffFFffffffffff"]],
  28: [[3, "KfffFFfffffffff"]],
  29: [[3, "KfFfffFffffffff"]],
  30: [[3, "KfFFfffffffffKf"]],
  31: [[3, "KffFFffffffffKf"]],
  32: [[3, "KfffFfFfffffKKf"]],
  33: [[3, "KfFfffFFffffKKf"]],
  34: [[3, "KfFFffffffffKKf"]],
  35: [[3, "KffFFfffffffKKK"]],
  36: [[3, "KfffFffffffKKK"]],
  37: [[3, "KfFfffffFffffK"]],
  38: [[4, "KfK.KfK.KfK"]],
  39: [[5, "K...K...K"]],
''')
block("LEGS", '''
  24: [[11, "KLmMMM45mLl"]],
  25: [[11, "KlLmmm23LLl"]],
  26: [[10, "KfFFuFFuuFuF"]],
  27: [[10, "KfFFFFFFuFFf"]],
  28: [[10, "KffFfFffFFfF"]],
  29: [[10, "KfFuFFuFuuFf"]],
  30: [[10, "KffFFFFFFuFK"]],
  31: [[10, "KffFffFfFFfK"]],
  32: [[11, "fF.FF.Fu.f"]],
  33: [[12, "f..f..F"]],
''')
block("BOOTS", '''
  37: [[8, ".uFuuFu"], [18, ".FuFFu"]],
  38: [[8, "KFFFuFF"], [18, "fFFFuF"]],
  39: [[8, "KffFfFf"], [18, "ffFffF"]],
  40: [[9, "KllLLl"], [19, "llLLl"]],
  41: [[9, "KlLmMm"], [19, "lLLmL"]],
  42: [[9, "KlLmMm"], [19, "lLLmL"]],
  43: [[9, "KlLLmL"], [19, "llLLl"]],
  44: [[9, "KlLmMm"], [19, "lLLmmL"]],
  45: [[9, "KlLmmMm"], [18, "KlLLmmmL"]],
  46: [[8, "KlLLmmMMm"], [18, "lllllLLl"]],
  47: [[8, "lllllLLLl"]],
''')
block("TORSO_GEAR", '''
  12: [[19, "uUu"]],
  13: [[18, "FuuFFu"]],
  14: [[13, "lm"], [19, "fFFff"]],
  15: [[14, "lm"], [21, "fFf"]],
  16: [[15, "l34"]],
  17: [[15, "2453"]],
  18: [[16, "12m"]],
  19: [[18, "lm"]],
  20: [[19, "lm"]],
  21: [[20, "lm"]],
  22: [[20, "lm"]],
  23: [[20, "lL"]],
''')
block("HELMET", '''
  0:  [[16, "34"]],
  1:  [[15, "2443"]],
  2:  [[14, "112543"]],
  3:  [[13, "02115442"]],
  4:  [[13, "02113432"]],
  5:  [[12, "0232345432"]],
  6:  [[20, "3"]],
  7:  [[20, "2"]],
''')
block("ARM_GEAR", '''
  12: [[8, "uUuu"]],
  13: [[7, "FuUuuF"]],
  14: [[6, "KFFuFuF"]],
  15: [[6, "KfFFFFf"]],
  16: [[6, "KffFfFf"]],
  17: [[7, "ff.fF"]],
  22: [[5, "KlLmMm"]],
  23: [[5, "KlL4mL"]],
  24: [[5, "KlLmm"]],
''')
block("WEAPON", '''
  1:  [[4, "24"]],
  2:  [[3, "0245"]],
  3:  [[3, "0245"]],
  4:  [[3, "0245"]],
  5:  [[3, "0244"]],
  6:  [[3, "0244"]],
  7:  [[3, "0234"]],
  8:  [[3, "0234"]],
  9:  [[3, "0245"]],
  10: [[3, "0245"]],
  11: [[3, "0244"]],
  12: [[3, "0244"]],
  13: [[3, "0134"]],
  14: [[3, "0123"]],
  15: [[3, "0134"]],
  16: [[3, "0244"]],
  17: [[3, "0245"]],
  18: [[3, "0245"]],
  19: [[3, "0244"]],
  20: [[3, "0244"]],
  21: [[3, "0234"]],
  22: [[3, "0244"]],
  23: [[3, "0245"]],
  24: [[3, "0245"]],
  25: [[1, "34444453"]],
  26: [[1, "01211210"]],
  31: [[5, "34"]],
  32: [[5, "12"]],
''')
rep = [
 ('  5:  [[13, "KhhhHcd"]],\n  6:  [[13, "Khhhcdd"]],\n  7:  [[13, "KhhbbKb"]],\n  8:  [[13, "Khhbccdc"]],\n  9:  [[13, "KhhbhHH"]],',
  '  5:  [[13, "KhhhHcd"]],\n  6:  [[13, "Khhhcdd"]],\n  7:  [[13, "KhhbbKc"]],\n  8:  [[13, "Khhbcddc"]],\n  9:  [[13, "KhhbcHH"]],'),
 ('f: "#463a36", F: "#75644f", u: "#9f8d6c", U: "#c4b48e"', 'f: "#4b403b", F: "#7b6b57", u: "#a39378", U: "#c7b999"'),
 ('l: "#3d2220", L: "#63392a", m: "#885636", M: "#ac7a48"', 'l: "#38211f", L: "#59362a", m: "#7c5037", M: "#a07048"'),
 ('w: "#49302b", W: "#6d4e36", y: "#917249"', 'w: "#523629", W: "#77573a", y: "#9d7d52"'),
]
for a, b in rep:
    assert a in s, a[:40]
    s = s.replace(a, b)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
