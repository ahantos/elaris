// Side-facing fighter for Elaris, built from gear layers on one body.
// Faces right; facing left is the same sprite flipped.

pal({
  o: "#15110f",                                  // outline
  S: "#dba07e", s: "#b9795a", d: "#84503c",      // skin
  H: "#52443a", h: "#2a2420",                    // hair
  U: "#9c958a", u: "#777067",                    // undercloth
  L: "#9a6a3e", l: "#74492a", k: "#4c2e1a", b: "#2a180e",   // leather
  y: "#c2a04e", Y: "#d8b860",                    // brass
  W: "#d0d2d6", m: "#9a9ca6", g: "#666874", G: "#3e4048",   // steel
  T: "#7a4a34", t: "#5c3626", r: "#3c2218",      // trousers
  M: "#5a4c40", n: "#3a322c",                    // boots
  C: "#a67440", B: "#7e522c", N: "#54341c",      // shield wood
  // bronze, for the material swap
  1: "#e6c078", 2: "#b88a40", 3: "#84602a", 4: "#553c18",
  // boiled leather
  5: "#6a4a3a", 6: "#4a3228", 7: "#2e1e18",
})
ramps("odsS", "ohH", "ouU", "obklL", "oyY", "oGgmW", "ortT", "onM", "oNBC", "o4321", "o765")

// Rows are written as runs: { y: [[x, "chars"], ...] }
function rows(runs, h = 32) {
  const out = []
  for (let y = 0; y < h; y++) {
    const line = Array(32).fill(".")
    for (const [x, chars] of runs[y] ?? [])
      for (let i = 0; i < chars.length; i++) if (chars[i] !== ".") line[x + i] = chars[i]
    out.push(line.join(""))
  }
  return out.join("\n")
}

// Head x12-19 with the face on its right half; torso x11-20; near leg x13-15,
// far leg x17-18; the far arm reaches forward at y15-16.
const BODY = rows({
  2:  [[13, "oooooo"]],
  3:  [[12, "ohHHhhho"]],
  4:  [[11, "ohhHHhhhho"]],
  5:  [[11, "ohhhhSSSso"]],
  6:  [[11, "ohhhSSoSSo"]],
  7:  [[11, "ohhsSSSSso"]],
  8:  [[12, "ohsssssdo"]],
  9:  [[14, "odssdo"]],
  10: [[14, "osdo"]],
  11: [[10, "oooooSdooooo"]],
  12: [[10, "oSSsSSssssdo"]],
  13: [[10, "oSssSSssssdo"]],
  14: [[10, "osssSssssddo"], [21, "ooooo"]],
  15: [[11, "osssssssd"], [20, "ssssSo"]],
  16: [[11, "ossssssdd"], [20, "sdddso"]],
  17: [[12, "osssssdo"], [20, "oooooo"]],
  18: [[12, "oUUuuuuo"]],
  19: [[12, "ouUuuuuo"]],
  20: [[12, "oSssosdo"]],
  21: [[12, "oSsdosdo"]],
  22: [[12, "oSsdosdo"]],
  23: [[12, "ossdosdo"]],
  24: [[12, "oSsdosdo"]],
  25: [[12, "ossdosdo"]],
  26: [[12, "ossdosdo"]],
  27: [[12, "oSsssdsssdo"]],
  28: [[12, "ooooooooooo"]],
})

const TROUSERS = rows({
  18: [[12, "oTTtttro"]],
  19: [[12, "oTttttro"]],
  20: [[12, "oTtrotro"]],
  21: [[12, "oTtrotro"]],
  22: [[12, "oTtrotro"]],
  23: [[12, "ottrotro"]],
  24: [[12, "oTtrotro"]],
})

const BOOTS = rows({
  24: [[12, "oMMnoMno"]],
  25: [[12, "oMnnoMno"]],
  26: [[12, "oMnnonbo"]],
  27: [[12, "oMMnnbnnnbo"]],
  28: [[12, "ooooooooooo"]],
})

const JERKIN = rows({
  11: [[10, "ooooo"], [17, "ooooo"]],
  12: [[10, "oLLlL..lllko"]],
  13: [[10, "oLllLLllllko"]],
  14: [[10, "ollLLllllkko"]],
  15: [[11, "oLlLllllko"]],
  16: [[11, "olLlllllko"]],
  17: [[12, "obbyybbo"]],
  18: [[12, "oLllllko"]],
  19: [[12, "okkkkkko"]],
})

// Kettle helm from the side: the brim reaches forward, the nasal is on the face side
const HELMET = rows({
  0:  [[13, "oooooo"]],
  1:  [[12, "oomWmgoo"]],
  2:  [[11, "omWWmmmggo"]],
  3:  [[11, "oWWmmmmggo"]],
  4:  [[9,  "oWWmmmmmmmmggGo"]],
  5:  [[9,  "oooGGGGGGmggooo"]],
  6:  [[18, "mg"]],
  7:  [[18, "gg"]],
})

// Round shield on the far arm, held forward, seen at an angle
const SHIELD = rows({
  10: [[21, "oooo"]],
  11: [[20, "omWmgo"]],
  12: [[19, "omCCBNgo"]],
  13: [[19, "oWCBBNgo"]],
  14: [[19, "omCBBNgo"]],
  15: [[19, "omBWmNgo"]],
  16: [[19, "omBmmNgo"]],
  17: [[19, "omBBNNgo"]],
  18: [[19, "omBBNNgo"]],
  19: [[19, "ogBNNNGo"]],
  20: [[20, "ogggGo"]],
  21: [[21, "oooo"]],
})

// The near arm hangs in front of the torso; its hand is at x12-14, y18-19
const NEAR_ARM = rows({
  12: [[11, "oSSso"]],
  13: [[11, "oSSso"]],
  14: [[11, "oSsdo"]],
  15: [[11, "oSsdo"]],
  16: [[11, "oSsdo"]],
  17: [[11, "oSsdo"]],
  18: [[11, "oSSso"]],
  19: [[11, "osddo"]],
  20: [[11, "ooooo"]],
})

const SLEEVE = rows({
  12: [[11, "oLLlo"]],
  13: [[11, "oLllo"]],
  14: [[11, "okkko"]],
})

// Longsword in the near hand, blade up and back over the shoulder
const SWORD = rows({
  1:  [[5, "o"]],
  2:  [[4, "oWo"]],
  3:  [[4, "oWmo"]],
  4:  [[4, "oWmo"]],
  5:  [[5, "oWmo"]],
  6:  [[5, "oWmo"]],
  7:  [[6, "oWmo"]],
  8:  [[6, "oWmo"]],
  9:  [[7, "oWmo"]],
  10: [[7, "oWmo"]],
  11: [[8, "oWmo"]],
  12: [[8, "oWmo"]],
  13: [[9, "oWmo"]],
  // The guard is a diagonal two pixels thick through the base of the blade, lit
  // on its upper edge: (11,18) (12,17) (13,16) (14,15) over (12,18) (13,17) (14,16)
  14: [[9, "oWmo"]],
  15: [[10, "oWmoYo"]],
  16: [[10, "oWmYyo"]],
  17: [[10, "ooYyo"]],
  18: [[10, "oYyo"]],
  19: [[10, "ooo"]],
  20: [[13, "oYo"]],
  21: [[14, "o"]],
})

// Back to front. Each piece of gear is its own layer, exported as its own image.
sprite("fighter", { w: 32, h: 32, layers: true },
  layer("body", BODY),
  layer("trousers", TROUSERS),
  layer("boots", BOOTS),
  layer("jerkin", JERKIN),
  layer("helmet", HELMET),
  layer("shield", SHIELD),
  layer("near_arm", NEAR_ARM),
  layer("sleeve", SLEEVE),
  layer("sword", SWORD))

sprite("fighter_left", { base: "fighter", flip: "x" })
sprite("fighter_bronze", { base: "fighter", swap: { W: "1", m: "2", g: "3", G: "4", L: "5", l: "6", k: "7" } })

sheet("fighters", ["fighter", "fighter_left", "fighter_bronze"], { pad: 1 })


// ---------------------------------------------------------------------------
// The same fighter on a 32 x 48 canvas: he stands on one 32-pixel tile and
// overlaps the tile above. Head x12-20, torso x10-21, legs x13-19, feet y44.
// ---------------------------------------------------------------------------
const T = 48

const T_BODY = rows({
  4:  [[13, "oooooo"]],
  5:  [[12, "ohHHhhho"]],
  6:  [[11, "ohhHHhhhho"]],
  7:  [[11, "ohhhhhSSso"]],
  8:  [[11, "ohhhhSSSSo"]],
  9:  [[11, "ohhhSSoSSSo"]],
  10: [[11, "ohhsSSSSso"]],
  11: [[12, "ohsSSSsdo"]],
  12: [[14, "ossssdo"]],
  13: [[15, "osdo"]],
  14: [[10, "oooooosdooooo"]],
  15: [[9,  "oSSSsSSssssddo"]],
  16: [[9,  "oSSssSSssssddo"]],
  17: [[9,  "oSssSSsssssddo"]],
  18: [[10, "oSssSSssssddo"], [22, "ooooo"]],
  19: [[10, "osssSssssdd"], [21, "ssssSo"]],
  20: [[10, "ossssssssdd"], [21, "sdddSo"]],
  21: [[11, "osssssssdd"], [21, "sdddso"]],
  22: [[11, "osssssssddo"], [21, "oooooo"]],
  23: [[11, "ossssssdddo"]],
  24: [[12, "osssssddo"]],
  25: [[12, "oUUUuuuuo"]],
  26: [[12, "oUUuuuuuo"]],
  27: [[12, "ouUuuuuuo"]],
  28: [[12, "oSssossdo"]],
  29: [[12, "oSsdossdo"]],
  30: [[12, "oSssossdo"]],
  31: [[12, "oSsdossdo"]],
  32: [[12, "oSsdossdo"]],
  33: [[12, "ossdossdo"]],
  34: [[12, "oSsdossdo"]],
  35: [[12, "oSSdosSdo"]],
  36: [[12, "ossdossdo"]],
  37: [[12, "oSsdossdo"]],
  38: [[12, "ossdossdo"]],
  39: [[12, "oSsdossdo"]],
  40: [[12, "ossdossdo"]],
  41: [[12, "ossdossdo"]],
  42: [[12, "ossdossdo"]],
  43: [[12, "ossdossdo"]],
  44: [[12, "oSsssdsssdo"]],
  45: [[12, "ooooooooooo"]],
}, T)

const T_TROUSERS = rows({
  25: [[12, "oTTTtttro"]],
  26: [[12, "oTTttttro"]],
  27: [[12, "oTtttttro"]],
  28: [[12, "oTtrottro"]],
  29: [[12, "oTtrottro"]],
  30: [[12, "ottrottro"]],
  31: [[12, "oTtrottro"]],
  32: [[12, "oTtrottro"]],
  33: [[12, "ottrottro"]],
  34: [[12, "oTtrottro"]],
  35: [[12, "oTTrottro"]],
  36: [[12, "ottrottro"]],
  37: [[12, "oTtrottro"]],
}, T)

const T_BOOTS = rows({
  37: [[12, "oMMnoMMno"]],
  38: [[12, "oMnnoMnno"]],
  39: [[12, "oMnnoMnno"]],
  40: [[12, "oMnnoMnno"]],
  41: [[12, "oMnnoMnno"]],
  42: [[12, "oMnbonnbo"]],
  43: [[12, "oMnbonnbo"]],
  44: [[12, "oMMnnnnnnno"]],
  45: [[12, "ooooooooooo"]],
}, T)

// Jerkin with an open collar, a strap from the near shoulder to the far hip,
// a belt with a buckle and a short skirt
const T_JERKIN = rows({
  14: [[10, "oooooo"], [18, "ooooo"]],
  15: [[9,  "oLLLlll"], [18, "lllko"]],
  16: [[9,  "oLLllLl"], [18, "llkko"]],
  17: [[9,  "oLlllLLllllkko"], [12, "b"]],
  18: [[10, "oLllLLllllkko"], [13, "b"]],
  19: [[10, "ollLLlllllkko"], [14, "b"]],
  20: [[10, "olLlllllllkko"], [15, "b"]],
  21: [[11, "oLlllllllko"], [16, "b"]],
  22: [[11, "olLllllllko"], [17, "b"]],
  23: [[11, "olllllllkko"], [18, "b"]],
  24: [[12, "obbbbbyyo"]],
  25: [[12, "oLLllllko"]],
  26: [[12, "oLlllllko"]],
  27: [[12, "olllllkko"]],
  28: [[12, "okkkkkkko"]],
}, T)

const T_HELMET = rows({
  1:  [[13, "oooooo"]],
  2:  [[12, "ooWWWmgoo"]],
  3:  [[11, "omWWWmmmggo"]],
  4:  [[11, "oWWWmmmmggo"]],
  5:  [[11, "oWWmmmmmggo"]],
  6:  [[8,  "oWWmmmmmmmmmggGGo"]],
  7:  [[8,  "oooGGGGGGGGmggooo"]],
  8:  [[19, "mgo"]],
  9:  [[19, "mgo"]],
  10: [[19, "ggo"]],
}, T)

const T_SHIELD = rows({
  12: [[23, "ooooo"]],
  13: [[22, "omWWmgo"]],
  14: [[21, "omCCCBNgo"]],
  15: [[21, "oWCCBBNgo"]],
  16: [[21, "oWCBBBNgo"]],
  17: [[21, "omCBBBNgo"]],
  18: [[21, "omCBBBNgo"]],
  19: [[21, "omBBWmNgo"]],
  20: [[21, "omBBmmNgo"]],
  21: [[21, "omBBggNgo"]],
  22: [[21, "omBBBNNgo"]],
  23: [[21, "omBBBNNgo"]],
  24: [[21, "omBBNNNgo"]],
  25: [[21, "ogBBNNNgo"]],
  26: [[21, "ogBNNNNGo"]],
  27: [[22, "ogggGGo"]],
  28: [[23, "ooooo"]],
}, T)

// Near arm in front of the torso; its hand is at x10-12, y26-28
const T_NEAR_ARM = rows({
  15: [[9, "oSSso"]],
  16: [[9, "oSSso"]],
  17: [[9, "oSSso"]],
  18: [[9, "oSsdo"]],
  19: [[9, "oSsdo"]],
  20: [[9, "oSsdo"]],
  21: [[9, "oSsdo"]],
  22: [[9, "oSsdo"]],
  23: [[9, "oSsdo"]],
  24: [[9, "oSsdo"]],
  25: [[9, "oSsdo"]],
  26: [[9, "oSSso"]],
  27: [[9, "oSsdo"]],
  28: [[9, "osddo"]],
  29: [[9, "ooooo"]],
}, T)

const T_SLEEVE = rows({
  15: [[9, "oLLlo"]],
  16: [[9, "oLLlo"]],
  17: [[9, "oLllo"]],
  18: [[9, "okkko"]],
}, T)

// Longsword: a longer blade, the guard two pixels thick just above the hand,
// the pommel below it
const T_SWORD = rows({
  6:  [[1, "o"]],
  7:  [[0, "oWo"]],
  8:  [[0, "oWmo"]],
  9:  [[0, "oWmo"]],
  10: [[1, "oWmo"]],
  11: [[1, "oWmo"]],
  12: [[2, "oWmo"]],
  13: [[2, "oWmo"]],
  14: [[3, "oWmo"]],
  15: [[3, "oWmo"]],
  16: [[4, "oWmo"]],
  17: [[4, "oWmo"]],
  18: [[5, "oWmo"]],
  19: [[5, "oWmo"]],
  20: [[6, "oWmo"]],
  21: [[6, "oWmo"]],
  22: [[7, "oWmo"], [12, "o"]],
  23: [[7, "oWmo"], [11, "oYo"]],
  24: [[8, "oWmYyo"]],
  25: [[8, "ooYyo"]],
  26: [[8, "oYyo"]],
  27: [[8, "ooo"]],
  29: [[11, "oYo"]],
  30: [[12, "o"]],
}, T)

sprite("fighter_tall", { w: 32, h: T, layers: true },
  layer("body", T_BODY),
  layer("trousers", T_TROUSERS),
  layer("boots", T_BOOTS),
  layer("jerkin", T_JERKIN),
  layer("helmet", T_HELMET),
  layer("shield", T_SHIELD),
  layer("near_arm", T_NEAR_ARM),
  layer("sleeve", T_SLEEVE),
  layer("sword", T_SWORD))

sprite("fighter_tall_left", { base: "fighter_tall", flip: "x" })
sprite("fighter_tall_bronze", { base: "fighter_tall", swap: { W: "1", m: "2", g: "3", G: "4", L: "5", l: "6", k: "7" } })
sprite("fighter_tall_bare", { w: 32, h: T }, layer("body", T_BODY), layer("near_arm", T_NEAR_ARM))

// Side by side on a strip of floor, at the same scale: 32 x 32 on the left,
// 32 x 48 on the right. Each stands on its own 32-pixel tile.
scene("compare", { w: 112, h: 56, bg: "#56483a" },
  layer("tiles", rect(8, 20, 32, 32, "#4a3e32"), rect(72, 20, 32, 32, "#4a3e32")),
  layer("figures", stamp("fighter", 8, 20), stamp("fighter_tall", 72, 4)))


// ---------------------------------------------------------------------------
// The same pixels with colour theory applied: every material gets a ramp built
// around one base colour, with shadows shifted towards cool hues and lights
// towards warm ones, and steel given a wider range so it reads as hard and
// shiny. The outline is a dark violet-brown instead of near-black.
// ---------------------------------------------------------------------------
pal({ K: "#1c1420" })
// A narrow lightness range for soft, dark materials and a wide one for steel.
shades("aAi", "#c08566", { spread: 0.26, shift: 14 })     // skin
shades("fF", "#4a3a30", { spread: 0.14, shift: 10 })      // hair
shades("ceEI", "#80542f", { spread: 0.34, shift: 18 })    // leather
shades("pPqQ", "#8c909e", { spread: 0.58, shift: 20 })    // steel
shades("vVw", "#6a3e2e", { spread: 0.24, shift: 16 })     // trousers
shades("xX", "#54463a", { spread: 0.14, shift: 10 })      // boots
shades("zZD", "#86572f", { spread: 0.30, shift: 16 })     // shield wood
shades("jJ", "#c9a548", { spread: 0.20, shift: 12 })      // brass

const HUE_SHIFTED = {
  d: "a", s: "A", S: "i", h: "f", H: "F",
  b: "c", k: "e", l: "E", L: "I",
  G: "p", g: "P", m: "q", W: "Q",
  r: "v", t: "V", T: "w", n: "x", M: "X",
  N: "z", B: "Z", C: "D", y: "j", Y: "J", o: "K",
}
sprite("fighter_tall_v2", { base: "fighter_tall", swap: HUE_SHIFTED })

scene("compare2", { w: 104, h: 56, bg: "#56483a" },
  layer("tiles", rect(8, 20, 32, 32, "#4a3e32"), rect(64, 20, 32, 32, "#4a3e32")),
  layer("figures", stamp("fighter_tall", 8, 4), stamp("fighter_tall_v2", 64, 4)))
