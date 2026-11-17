// A1: barbarian fighter drawn from the theory reference alone (no reference pictures).
// 32 x 48, faces right in a three-quarter side view; facing left is the mirror image.
// LIGHT: from above and slightly in front (upper right of this master). Top planes
// lightest, the back (left) side and undersides dark, falloff toward the feet.
//
// Slots per material: contour / deep shadow / shadow / base / light / highlight.

pal({
  K: "#17121c",                                              // shared near-black, blue-purple
  a: "#5f2f33", b: "#8c5540", c: "#b57a55", d: "#dba878",    // skin: red shadows, tan lights
  h: "#2b2126", H: "#55403a",                                // hair
  f: "#40363a", F: "#6a5c4c", u: "#928369", U: "#b9aa88",    // wolf fur, grey-brown, pale tips
  l: "#38211f", L: "#59362a", m: "#7e4c36", M: "#a07048",    // leather
  w: "#59362a", W: "#7a5c3a", y: "#9f8052",                  // shield wood (darkest shared with leather)
  // steel: wide span, blue-black darks, cold off-white specular
  0: "#0f1a28", 1: "#202e37", 2: "#3d4f56", 3: "#819796", 4: "#c7cfcc", 5: "#f1f2ec",
  // bronze, same six slots
  p: "#24141c", q: "#4c2a26", r: "#774528", s: "#a06c34", t: "#c9984f", v: "#ecd6a2",
})
ramps("Kabcd", "KhH", "KfFuU", "KlLmM", "KwWy", "012345", "pqrstv")

const W = 32, T = 48

// Rows are written as runs: { y: [[x, "chars"], ...] }
function rows(runs) {
  const out = []
  for (let y = 0; y < T; y++) {
    const line = Array(W).fill(".")
    for (const [x, chars] of runs[y] ?? [])
      for (let i = 0; i < chars.length; i++) if (chars[i] !== ".") line[x + i] = chars[i]
    out.push(line.join(""))
  }
  return out.join("\n")
}

// Fur cloak hanging down the back, behind everything. In shadow, so mostly the
// shadow tone; lighter tufts along the outer edge stand in for a contour.
const CLOAK = rows({
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
  27: [[3, "FFFFFffffffffff"]],
  28: [[3, "FFFFffffffffff"]],
  29: [[3, "FFFFFffffffffKf"]],
  30: [[3, "FFfFFffffffffKf"]],
  31: [[3, "uFfFFFffffffKKf"]],
  32: [[3, "uFFfFFffffffKKf"]],
  33: [[3, "FFFfFFffffffKKf"]],
  34: [[3, "FFFFfFffffffKKf"]],
  35: [[3, "uFFFfFffffffKKK"]],
  36: [[3, "uFF.FFf.fff.KKK"]],
  37: [[4, "Ff..Ff"]],
})

// Head x13-20 (face on the right), torso x10-21, near leg x9-16, far leg x17-25.
// The far arm reaches forward at y18-21 and is one step darker than the near side.
const BODY = rows({
  3:  [[15, "hHHH"]],
  4:  [[14, "hhHHHH"]],
  5: [[13, "KhhhHdd"]],
  6: [[13, "Khhhbdd"]],
  7:  [[13, "KhhbbKc"]],
  8:  [[13, "Khhbcddc"]],
  9:  [[13, "KhhbcHH"]],
  10: [[13, "KhhahHh"]],
  11: [[13, "Khhahh"]],
  12: [[12, "Khhaabb"]],
  13: [[11, "Khhhbbbcddc"]],
  14: [[10, "Kbbbcddcddddcb"]],
  15: [[10, "Kabbccdcddddbba"]],
  16: [[10, "Kabbcccbcddcbba"]],
  17: [[10, "Kaabbccbcccbaba"]],
  18: [[10, "Kaaaabbbbbbaabba"], [26, "bcb"]],
  19: [[11, "Kabbccbcdcbabbcccb"]],
  20: [[11, "Kabbccbcccbaabbbcb"]],
  21: [[11, "Kaabbcbcdcaaaaaaba"]],
  22: [[12, "Kabbcbccb"]],
  23: [[12, "Kabbccccb"]],
  24: [[12, "Kaabbccbb"]],
  25: [[12, "KlLLmmmLl"]],
  26: [[11, "KlLLLmLmLl"]],
  27: [[11, "KllLLLLLLLl"]],
  28: [[11, "Kbccdcabbcb"]],
  29: [[11, "Kbccdcabbccb"]],
  30: [[10, "Kbccdcaabbccb"]],
  31: [[10, "Kabccc"], [17, "aabbbb"]],
  32: [[10, "Kabcdc"], [18, "abbcb"]],
  33: [[10, "Kbbcdc"], [18, "abccb"]],
  34: [[10, "Kbccdc"], [18, "abbccb"]],
  35: [[10, "Kbcdd"], [19, "abccb"]],
  36: [[10, "Kabcc"], [19, "aabb"]],
  37: [[9, "Kabbcc"], [19, "abcb"]],
  38: [[9, "Kabcc"], [19, "abcb"]],
  39: [[9, "Kabcc"], [19, "abcb"]],
  40: [[9, "Kabcc"], [19, "abcb"]],
  41: [[10, "Kbcc"], [19, "abbb"]],
  42: [[10, "Kbcc"], [20, "abb"]],
  43: [[10, "Kbcb"], [20, "abb"]],
  44: [[10, "Kbcc"], [20, "abcb"]],
  45: [[10, "Kbcdc"], [19, "Kabbccb"]],
  46: [[9, "Kabccddc"], [19, "aaabbba"]],
  47: [[9, "aabbbccb"]],
})

// Fur kilt under a wide belt with a metal buckle
const LEGS = rows({
  24: [[11, "KlmMMM44mLl"]],
  25: [[11, "Klmmmm22mLl"]],
  26: [[10, "KfFFuuFFuuuF"]],
  27: [[10, "KfFFFFFFFuFf"]],
  28: [[10, "KffFFffFFFff"]],
  29: [[10, "KfFuuFFFuuFf"]],
  30: [[10, "KffFFFffFFFK"]],
  31: [[11, "ff.FF.FFff"]],
  32: [[11, "ff..F..F"]],
})

// Dark leather boots with a fur cuff; the far one a step darker
const BOOTS = rows({
  39: [[9, "FuuFuu"], [19, "FuuFu"]],
  40: [[8, "KffFFFf"], [18, "ffFFff"]],
  41: [[9, "KllLLl"], [19, "llLLl"]],
  42: [[9, "KlLmmL"], [19, "lLmmL"]],
  43: [[9, "KlLmmL"], [19, "llLLL"]],
  44: [[9, "KllLmL"], [19, "lLLmmm"]],
  45: [[9, "KlLmmmL"], [18, "KlLLmmmm"]],
  46: [[8, "KllLmmmMm"], [18, "lllllLLl"]],
  47: [[8, "lllllLLLl"]],
})

// Baldric from the near shoulder to the far hip, a metal plate on it, fur on the far shoulder
const TORSO_GEAR = rows({
  12: [[19, "uUUu"]],
  13: [[18, "FFuuFF"]],
  14: [[13, "lm"], [19, "fFFff"]],
  15: [[14, "lm"], [21, "fff"]],
  16: [[16, "344"]],
  17: [[16, "345"]],
  18: [[16, "122"]],
  19: [[18, "lm"]],
  20: [[19, "lm"]],
  21: [[19, "lm"]],
  22: [[19, "lm"]],
  23: [[19, "lm"]],
})

// Iron cap: dome, raised rim, short nasal, a knob on top
const HELMET = rows({
  0:  [[16, "34"]],
  1:  [[15, "2443"]],
  2:  [[14, "112543"]],
  3:  [[13, "02115442"]],
  4:  [[13, "02113432"]],
  5:  [[12, "0232345432"]],
  6:  [[20, "3"]],
  7:  [[20, "2"]],
})

// Round shield on the far arm, seen at an angle: iron rim, planks, iron boss
const SHIELD = rows({
  13: [[24, "3444"]],
  14: [[23, "3yyyy5"]],
  15: [[22, "2yWyyWy5"]],
  16: [[22, "2yWyyWy4"]],
  17: [[21, "1yyWyyWyy4"]],
  18: [[21, "1WWwWWWyy4"]],
  19: [[21, "1WWw44WWy3"]],
  20: [[21, "1WW2454WW3"]],
  21: [[21, "1WW2333WW3"]],
  22: [[21, "1wWw22wWW3"]],
  23: [[21, "1wwwwwwWW2"]],
  24: [[21, "1wwlwwlWW2"]],
  25: [[21, "1wwlwwlww2"]],
  26: [[22, "1wlwwlw2"]],
  27: [[22, "1wwwwww2"]],
  28: [[23, "1wwww2"]],
  29: [[24, "1221"]],
})

// Near arm, in front of the torso, hanging a little back; fist at x4-7, y27-30
const NEAR_ARM = rows({
  13: [[8, "cddc"]],
  14: [[7, "Kcdddc"]],
  15: [[7, "Kbcddc"]],
  16: [[7, "Kbccdc"]],
  17: [[7, "Kabccb"]],
  18: [[6, "Kabcdc"]],
  19: [[6, "Kabcdc"]],
  20: [[6, "Kabccc"]],
  21: [[6, "Kabcc"]],
  22: [[5, "Kabccb"]],
  23: [[5, "Kabcdc"]],
  24: [[5, "Kabcc"]],
  25: [[5, "Kbbcc"]],
  26: [[5, "Kbcc"]],
  27: [[5, "cdc"]],
  28: [[4, "Kbcc"]],
  29: [[4, "Kbcc"]],
  30: [[5, "bbb"]],
})

// Fur over the near shoulder, leather bracer with a stud
const ARM_GEAR = rows({
  12: [[8, "uUUu"]],
  13: [[7, "FuUuuF"]],
  14: [[6, "KFFuFuF"]],
  15: [[6, "KfFFFFf"]],
  16: [[6, "KffFfFf"]],
  17: [[7, "ff.fF"]],
  22: [[5, "KlLmmm"]],
  23: [[5, "KlLm4m"]],
  24: [[5, "KlLmm"]],
})

// Broad sword held upright. Across the blade: soft back edge, dark band, lit plane,
// bright edge. The grip is inside the fist.
const WEAPON = rows({
  0:  [[5, "4"]],
  1:  [[4, "24"]],
  2:  [[3, "2145"]],
  3:  [[3, "2145"]],
  4:  [[3, "2145"]],
  5:  [[3, "2144"]],
  6:  [[3, "2144"]],
  7:  [[3, "2134"]],
  8:  [[3, "2134"]],
  9:  [[3, "2145"]],
  10: [[3, "2145"]],
  11: [[3, "2144"]],
  12: [[3, "2144"]],
  13: [[3, "2134"]],
  14: [[3, "1034"]],
  15: [[3, "1034"]],
  16: [[3, "2134"]],
  17: [[3, "2145"]],
  18: [[3, "2145"]],
  19: [[3, "214"]],
  20: [[3, "2144"]],
  21: [[3, "2134"]],
  22: [[3, "2134"]],
  23: [[3, "2145"]],
  24: [[3, "2145"]],
  25: [[1, "34444454"]],
  26: [[1, "01122110"]],
  31: [[5, "44"]],
  32: [[5, "22"]],
})

const A1 = { CLOAK, BODY, LEGS, BOOTS, TORSO_GEAR, HELMET, SHIELD, NEAR_ARM, ARM_GEAR, WEAPON }
const ORDER = ["cloak", "body", "legs", "boots", "torso_gear", "helmet", "shield", "near_arm", "arm_gear", "weapon"]
const BRONZE = { 0: "p", 1: "q", 2: "r", 3: "s", 4: "t", 5: "v" }

function doll(name, opts, skip = []) {
  sprite(name, { w: W, h: T, ...opts },
    ...ORDER.filter((n) => !skip.includes(n)).map((n) => layer(n, A1[n.toUpperCase()])))
}

doll("a1", { layers: true })
doll("a1_bronze", { swap: BRONZE })
doll("a1_nohelm_noshield", {}, ["helmet", "shield"])
doll("a1_bare", {}, ["helmet", "shield", "weapon", "torso_gear"])
doll("a1_body", {}, ["cloak", "legs", "boots", "torso_gear", "helmet", "shield", "arm_gear", "weapon"])
sprite("a1_left", { base: "a1", flip: "x" })
