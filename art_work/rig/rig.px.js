// The rig masters for the barbarian: separate parts, each drawn in full.
//
// Sprite names are <source>__<piece>: "body__near_thigh" is the bare body's near
// thigh, "fur_boots__near_shin" is the boot as it rides on the near shin.
// tools/bake.py turns these masters into the angle variants and the atlas;
// rig.src.json says how the pieces hang together (parents, pivots, draw order).
//
// Two kinds of master:
//  - LIMB PARTS (arms, legs) are their own small drawings, upright, with a round
//    cap at each end and the pivot on a pixel corner. They are not cut out of the
//    standing figure: each is a straight, closed limb that can be turned to any
//    angle of the set and still read as a limb.
//  - HEAD, TORSO, HIPS, CLOAK, SHIELD, SWORD are drawn in place on the 32 x 48
//    figure (they only move by whole pixels, or turn about a grip), with the parts
//    another piece normally covers drawn in.
//
// Style, palette and proportions are A1's (art_work/barbarian/a1.px.js).
// LIGHT as in A1: from above and slightly in front (upper right of this master).

pal({
  K: "#17121c",                                              // shared near-black, blue-purple
  a: "#5f2f33", b: "#8c5540", c: "#b57a55", d: "#dba878",    // skin: red shadows, tan lights
  h: "#2b2126", H: "#55403a",                                // hair
  f: "#40363a", F: "#6a5c4c", u: "#928369", U: "#b9aa88",    // wolf fur, grey-brown, pale tips
  l: "#38211f", L: "#59362a", m: "#7e4c36", M: "#a07048",    // leather
  w: "#59362a", W: "#7a5c3a", y: "#9f8052",                  // shield wood (darkest shared with leather)
  0: "#0f1a28", 1: "#202e37", 2: "#3d4f56", 3: "#819796", 4: "#c7cfcc", 5: "#f1f2ec",   // steel
  p: "#24141c", q: "#4c2a26", r: "#774528", s: "#a06c34", t: "#c9984f", v: "#ecd6a2",   // bronze
})
ramps("Kabcd", "KhH", "KfFuU", "KlLmM", "KwWy", "012345", "pqrstv")

const W = 32, T = 48

// ---------------------------------------------------------------- helpers
// A drawing in place on the figure, written as runs: { y: [[x, "chars"], ...] }
function px(runs) {
  const m = new Map()
  for (const [y, list] of Object.entries(runs))
    for (const [x, chars] of list)
      for (let i = 0; i < chars.length; i++) if (chars[i] !== ".") m.set((x + i) + "," + y, chars[i])
  return m
}
function take(m, pred) {
  const out = new Map()
  for (const [k, v] of m) { const [x, y] = k.split(",").map(Number); if (pred(x, y)) out.set(k, v) }
  return out
}
function over(...maps) {                      // later maps win
  const out = new Map()
  for (const m of maps) for (const [k, v] of m) out.set(k, v)
  return out
}
function gridOf(m, w, h) {
  const out = []
  for (let y = 0; y < h; y++) {
    let line = ""
    for (let x = 0; x < w; x++) line += m.get(x + "," + y) ?? "."
    out.push(line)
  }
  return out.join("\n")
}
// a small drawing written as rows of text ("." = empty)
function part(rows) {
  const m = new Map()
  rows.forEach((row, y) => { for (let x = 0; x < row.length; x++) if (row[x] !== ".") m.set(x + "," + y, row[x]) })
  return m
}
const figure = (name, m) => sprite(name, { w: W, h: T }, gridOf(m, W, T))
const local = (name, m, w, h) => sprite(name, { w, h }, gridOf(m, w, h))

// Light is baked into a drawing, so a part turned far round would carry its dark back
// edge on top. For those angles the baker starts from a second master, "__r": the same
// silhouette, pixel for pixel, with the shading run the other way across the width
// (each row reversed in place). Length and volume cannot change.
function relit(maps) {
  const lo = {}, hi = {}
  for (const m of maps) for (const k of m.keys()) {
    const [x, y] = k.split(",").map(Number)
    lo[y] = Math.min(lo[y] ?? x, x); hi[y] = Math.max(hi[y] ?? x, x)
  }
  return maps.map((m) => {
    const out = new Map()
    for (const [k, v] of m) { const [x, y] = k.split(",").map(Number); out.set((lo[y] + hi[y] - x) + "," + y, v) }
    return out
  })
}

// ================================================================ LIMB PARTS
// Each is upright: an arm or leg hanging straight down from its pivot. Across the
// width, as on A1: contour K on the back edge, deep shadow, shadow, base, one light
// stripe set in from the front edge. The top cap of a lower part repeats the pixels
// of the part above it, so a straight limb shows no seam; the bottom cap of an upper
// part carries the contour round, and shows as the elbow or the knee when it bends.

// NEAR UPPER ARM  8 x 11, pivot (shoulder) 4,2  elbow 4,8
const NEAR_UPPER_ARM = part([
  "..cddc..",
  ".Kcdddc.",
  ".Kbcddc.",      // shoulder pivot at the top of this row
  ".Kbccdc.",
  ".Kabccb.",
  ".Kabcdc.",
  ".Kabcdc.",
  ".Kabccc.",
  ".Kabcc..",      // elbow joint at the top of this row
  "..Kabc..",
  "...ab...",
])

// NEAR FOREARM AND FIST  8 x 12, pivot (elbow) 5,2  fist centre 2,10
// The back edge is straight and the bulk tapers on the front, as on A1; the fist
// sits a pixel behind the wrist, which is what lets the blade stand clear of the arm.
const NEAR_FOREARM = part([
  "....bc..",
  "...abcc.",
  "..Kabcc.",      // elbow pivot at the top of this row
  ".Kabccb.",
  ".Kabcdc.",
  ".Kabcc..",
  ".Kbbcc..",
  ".Kbcc...",
  ".cdc....",      // fist: four by four with the corners off
  "Kbcc....",
  "Kbcc....",
  ".bbb....",
])
const NEAR_HAND = take(NEAR_FOREARM, (x, y) => y >= 8)
const BRACER = part([
  "........",
  "........",
  "........",
  ".KlLmmm.",
  ".KlLm4m.",
  ".KlLmm..",
])

// FAR UPPER ARM  6 x 8, one step darker than the near side, pivot 3,2  elbow 3,6
const FAR_UPPER_ARM = part([
  "..cb..",
  ".abba.",
  ".abba.",        // shoulder pivot at the top of this row
  ".aaba.",
  ".abba.",
  ".abbc.",
  ".aabb.",        // elbow joint at the top of this row
  "..aa..",
])

// FAR FOREARM AND FIST  4 x 7, pivot (elbow) 2,1  fist centre 2,5
// Its rest angle is -90: it reaches forward, so the right-hand column here is its top.
const FAR_FOREARM = part([
  ".ab.",
  "abb.",          // elbow pivot at the top of this row
  "abb.",
  "abc.",
  "abcb",          // fist
  "bccc",
  "abbb",
])

// NEAR THIGH  8 x 13, pivot (hip) 4,2  knee 4,10
const NEAR_THIGH = part([
  "..bccd..",
  ".Kbccdc.",
  ".Kbccdc.",      // hip pivot at the top of this row
  ".Kbccdc.",
  ".Kbccdc.",
  ".Kabccc.",
  ".Kabcdc.",
  ".Kbbcdc.",
  ".Kbccdc.",
  ".Kbcdd..",
  ".Kabcc..",      // knee joint at the top of this row
  "..bbcc..",
  "...cc...",
])

// NEAR SHIN AND FOOT  10 x 14, pivot (knee) 5,2  sole under the ankle 4,14
const NEAR_SHIN = part([
  "...bcc....",
  "..Kbcdd...",
  "..Kabcc...",    // knee pivot at the top of this row
  ".Kabbcc...",
  ".Kabcc....",
  ".Kabcc....",
  ".Kabcc....",
  "..Kbcc....",
  "..Kbcc....",
  "..Kbcb....",
  "..Kbcc....",
  "..Kbcdc...",
  ".Kabccddc.",
  ".aabbbccb.",
])
const NEAR_BOOT = part([
  "..........",
  "..........",
  "..........",
  "..........",
  "..........",
  ".FuuFuu...",
  "KffFFFf...",
  ".KllLLl...",
  ".KlLmmL...",
  ".KlLmmL...",
  ".KllLmL...",
  ".KlLmmmL..",
  "KllLmmmMm.",
  "lllllLLLl.",
])

// FAR THIGH  8 x 12, darker, pivot (hip) 3,2  knee 4,10 (the knee sits a pixel forward)
const FAR_THIGH = part([
  "..bbc...",
  ".abbcb..",
  ".abbcb..",      // hip pivot at the top of this row
  ".abbccb.",
  ".abbccb.",
  ".aabbbb.",
  ".abbcb..",
  ".abccb..",
  ".abbccb.",
  "..abccb.",
  "..aabb..",      // knee joint at the top of this row
  "...bc...",
])

// FAR SHIN AND FOOT  8 x 13, pivot (knee) 3,2  sole under the ankle 3,13
const FAR_SHIN = part([
  "..bc....",
  ".abccb..",
  ".aabb...",      // knee pivot at the top of this row
  ".abcb...",
  ".abcb...",
  ".abcb...",
  ".abcb...",
  ".abbb...",
  "..abb...",
  "..abb...",
  "..abcb..",
  ".Kabbccb",
  ".aaabbba",
])
const FAR_BOOT = part([
  "........",
  "........",
  "........",
  "........",
  "........",
  ".FuuFu..",
  "ffFFff..",
  ".llLLl..",
  ".lLmmL..",
  ".llLLL..",
  ".lLLmmm.",
  "KlLLmmmm",
  "lllllLLl",
])

local("body__near_upper_arm", NEAR_UPPER_ARM, 8, 11)
local("body__near_forearm", NEAR_FOREARM, 8, 12)
local("body__near_hand", NEAR_HAND, 8, 12)
local("fur_bracer__near_forearm", BRACER, 8, 12)
local("body__far_upper_arm", FAR_UPPER_ARM, 6, 8)
local("body__far_forearm", FAR_FOREARM, 4, 7)
local("body__near_thigh", NEAR_THIGH, 8, 13)
local("body__near_shin", NEAR_SHIN, 10, 14)
local("fur_boots__near_shin", NEAR_BOOT, 10, 14)
local("body__far_thigh", FAR_THIGH, 8, 12)
local("body__far_shin", FAR_SHIN, 8, 13)
local("fur_boots__far_shin", FAR_BOOT, 8, 13)
{
  const [ua] = relit([NEAR_UPPER_ARM])
  local("body__near_upper_arm__r", ua, 8, 11)
  const [fa, hand, bracer] = relit([NEAR_FOREARM, NEAR_HAND, BRACER])
  local("body__near_forearm__r", fa, 8, 12)
  local("body__near_hand__r", hand, 8, 12)
  local("fur_bracer__near_forearm__r", bracer, 8, 12)
}

// ================================================================ PARTS DRAWN IN PLACE
// A1's standing body, for the head, torso and hips (the limbs above replace its arms and legs).
const BODY = px({
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
  14: [[10, "Kbbbcddcdddd"]],
  15: [[10, "Kabbccdcdddd"]],
  16: [[10, "Kabbcccbcddc"]],
  17: [[10, "Kaabbccbcccb"]],
  18: [[10, "Kaaaabbbbbba"]],
  19: [[11, "Kabbccbcdcb"]],
  20: [[11, "Kabbccbcccb"]],
  21: [[11, "Kaabbcbcdca"]],
  22: [[12, "Kabbcbccb"]],
  23: [[12, "Kabbccccb"]],
  24: [[12, "Kaabbccbb"]],
  25: [[12, "KlLLmmmLl"]],
  26: [[11, "KlLLLmLmLl"]],
  27: [[11, "KllLLLLLLLl"]],
})

// HEAD: skull, face, the hair down the back, and the neck.
const HEAD = take(BODY, (x, y) => y <= 12 || (y === 13 && x <= 14))

// TORSO: shoulders to waist. Drawn in under its neighbours: the base of the neck
// under the head and hair, the belly running on under the hips.
const TORSO = over(
  px({
    12: [[13, "haaabb"]],
    13: [[12, "abb"]],
    25: [[12, "Kaabbcbbb"]],
    26: [[13, "aabbbba"]],
  }),
  take(BODY, (x, y) => y >= 13 && y <= 24 && !(y === 13 && x <= 14)))

// HIPS: the leather clout. The root of the figure.
const HIPS = take(BODY, (x, y) => y >= 25 && y <= 27)

figure("body__head", HEAD)
figure("body__torso", TORSO)
figure("body__hips", HIPS)

// The cloak: the whole fall of fur, not only what shows behind the standing figure.
// A lighter outer band on the back edge, clumps parted by dark creases that lean
// down and forward, the deep part under the body left dark.
const CLOAK = px({
  11: [[9, "uuu"]],
  12: [[7, "fFuuFFf"]],
  13: [[6, "fFFFFuFf"]],
  14: [[5, "FFfFFfff"]],
  15: [[5, "FFfFFfff"]],
  16: [[4, "uFFFfFFff"]],
  17: [[4, "FFFFfFFff"]],
  18: [[5, "FFFfFfff"]],
  19: [[4, "FFFFffFff"]],
  20: [[4, "FFFfFfFff"]],
  21: [[3, "uFFFfFffff"]],
  22: [[3, "FFFFFfFfff"]],
  23: [[4, "FFFFfFfff"]],
  24: [[4, "FFFfFFfff"]],
  25: [[4, "FFFfFFfff"]],
  26: [[4, "FFFFfffff"]],
  27: [[3, "FFfFFfffffFffff"]],
  28: [[3, "FFfFFfffffFfff"]],
  29: [[3, "FFfFFfffFffffKf"]],
  30: [[3, "FFfFFfffFffffKf"]],
  31: [[3, "uFfFFFffffFfKKf"]],
  32: [[3, "uFFfFFffffFfKKf"]],
  33: [[3, "FFFfFFffFfffKKf"]],
  34: [[3, "FFFFfFffFfffKKf"]],
  35: [[3, "uFFFfFffffffKKK"]],
  36: [[3, "uFF.FFf.fff.KKK"]],
  37: [[4, "Ff..Ff"]],
})
// In two: the mantle on the back, and the hem that swings a tick late. The hem runs
// up two rows under the mantle.
figure("wolf_cloak__cloak_upper", take(CLOAK, (x, y) => y <= 26))
figure("wolf_cloak__cloak_lower", take(CLOAK, (x, y) => y >= 25))

// Belt and fur kilt. The belt sits on the hips; the skirt hangs from it as its own piece,
// so it can give a pixel when the thighs move under it. It runs up one row under the belt.
const KILT = px({
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
figure("fur_kilt__hips", take(KILT, (x, y) => y <= 25))
figure("fur_kilt__skirt", over(px({ 25: [[12, "FFuuFFuuu"]] }), take(KILT, (x, y) => y >= 26)))

// Baldric from the near shoulder to the far hip, a metal plate on it, fur on the far shoulder: on the torso
figure("baldric__torso", px({
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
}))

// Iron cap: on the head
figure("iron_cap__head", px({
  0:  [[16, "34"]],
  1:  [[15, "2443"]],
  2:  [[14, "112543"]],
  3:  [[13, "02115442"]],
  4:  [[13, "02113432"]],
  5:  [[12, "0232345432"]],
  6:  [[20, "3"]],
  7:  [[20, "2"]],
}))

// Fur over the near shoulder: on the torso, drawn over the upper arm. It hides the shoulder joint.
figure("fur_bracer__torso", px({
  12: [[8, "uUUu"]],
  13: [[7, "FuUuuF"]],
  14: [[6, "KFFuFuF"]],
  15: [[6, "KfFFFFf"]],
  16: [[6, "KffFfFf"]],
  17: [[7, "ff.fF"]],
}))

// Round shield, hung on the far fist: iron rim, planks, iron boss
figure("round_shield__shield", px({
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
}))

// Broad sword, upright. Across the blade: soft back edge, dark band, lit plane, bright
// edge. The grip (under the fist) is drawn, so the sword is whole when it turns in the hand.
const WEAPON = px({
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
  27: [[5, "Lm"]],
  28: [[5, "lL"]],
  29: [[5, "Lm"]],
  30: [[5, "lL"]],
  31: [[5, "44"]],
  32: [[5, "22"]],
})
figure("broad_sword__weapon", WEAPON)
// Relit sword: blade colours reversed across its four columns, the nick in the edge
// (row 19) and the point kept where they are; the guard's glint moves to the other end.
{
  const m = new Map(WEAPON)
  for (let y = 2; y <= 24; y++) {
    const row = [3, 4, 5, 6].map((x) => WEAPON.get(x + "," + y))
    if (row[3] === undefined) { [3, 4, 5].forEach((x, i) => m.set(x + "," + y, ["5", "4", "1"][i])); continue }
    ;[3, 4, 5, 6].forEach((x, i) => m.set(x + "," + y, row[3 - i]))
  }
  m.set("4,1", "4"); m.set("5,1", "2")
  ;"45444443".split("").forEach((c, i) => m.set((1 + i) + ",25", c))
  figure("broad_sword__weapon__r", m)
}
