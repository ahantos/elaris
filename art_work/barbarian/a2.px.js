// A2: barbarian fighter, reference first. Finish studied from Dungeon Crawl Stone Soup
// tiles (hill giant, cyclops, Urug, Rupert) and Stoneshard figures; pose and costume from
// John White's "A Warrior neighbour of the Picts" (public domain, see notes.md).
// 32 x 48, faces right in a three-quarter side view; facing left is the mirror image.
// LIGHT: from above and slightly in front (upper right of this master).
// Style: a near-black contour all round, big light-dominant shapes, dark accent lines.

pal({
  K: "#1b1416",                                              // contour
  a: "#6e4038", b: "#a06a50", c: "#c8946f", d: "#e6ba94",    // skin
  h: "#33261f", H: "#5c4130",                                // hair
  f: "#3f3733", F: "#6b5f52", u: "#978a75",                  // fur
  l: "#33261f", L: "#5c4130", m: "#8a6244",                  // leather
  r: "#48181b", R: "#742628", e: "#9a3a30",                  // dyed cloth, shield paint
  y: "#8f6a2a", Y: "#d9b254",                                // brass
  0: "#141820", 1: "#2e3742", 2: "#5d6871", 3: "#98a1a3", 4: "#cdd2ce", 5: "#f2f3ec",   // steel
  p: "#24161a", q: "#55301f", t: "#855224", s: "#b07e36", v: "#d0a04c", w: "#f0dba6",   // bronze
})
ramps("Kabcd", "KhH", "KfFu", "KlLm", "KrRe", "KyY", "012345", "pqtsvw")

const W = 32, T = 48

// Rows are written as runs: { y: [[x, "chars"], ...] }; later runs paint over earlier ones
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

// Fur mantle and cape, behind everything: a thick collar across the shoulders and a
// short cape down the back
const CLOAK = rows({
  9:  [[3, "KKK.KKK"]],
  10: [[2, "KFuuKFuuK"], [23, "KKK"]],
  11: [[1, "KFFuFFFFFuFK"], [22, "KFuuK"]],
  12: [[1, "KFFFFFfFFFFF"], [22, "KFFuFK"]],
  13: [[1, "KFuFFffFFFFf"], [22, "KfFFFK"]],
  14: [[1, "KFuFffffffff"]],
  15: [[1, "KFFFffffffff"]],
  16: [[1, "KFFfffffffff"]],
  17: [[1, "KuFfffffffff"]],
  18: [[1, "KuFfffffffff"]],
  19: [[1, "KFFfffffffff"]],
  20: [[1, "KFFfffffffff"]],
  21: [[1, "KFFfffffffff"]],
  22: [[1, "KFuFffffffff"]],
  23: [[1, "KFuFffffffff"]],
  24: [[0, "KFFFFffffffff"]],
  25: [[0, "KFFFFfffffff"]],
  26: [[0, "KuFFFFffffff"]],
  27: [[0, "KuFFFFFffff"]],
  28: [[0, "KFFFuFFfff"]],
  29: [[0, "KFFFuFFfff"]],
  30: [[0, "KFuFFFFfff"]],
  31: [[0, "KFuFFFffff"]],
  32: [[0, "KFFFFFfFff"]],
  33: [[0, "KFFFuFfFff"]],
  34: [[0, "KKFFuKKfFKK"]],
  35: [[2, "KKK..KK"]],
})

// Head x13-22, torso x9-23, near leg x6-16, far leg x16-27. The head sits low between
// the shoulders. The far arm reaches forward at y22-25 and is a step darker.
const BODY = rows({
  4:  [[15, "KKKKKK"]],
  5: [[14, "KhHHHHHK"]],
  6:  [[13, "KhhHHcddK"]],
  7:  [[13, "KhhhhaaaK"]],
  8:  [[13, "KhhhbcKddK"]],
  9:  [[13, "KhHhbccddK"]],
  10: [[13, "KhHhhhhHK"]],
  11: [[13, "KhhhahHhK"]],
  12: [[13, "KhhhaahhK"]],
  13: [[9, "KKKKKKKKKKKKKKKKKK"], [12, "Khhhh"]],
  14: [[9, "KbccdddddddddcKbcK"], [12, "KhhhK"]],
  15: [[9, "KbccdddcdddddcKbbK"], [12, "KhhK"]],
  16: [[9, "KbccdddcddddccKbbK"], [13, "KK"]],
  17: [[9, "KbcccddcdddcccKabK"]],
  18: [[9, "KbbccccbcccccbKabK"]],
  19: [[9, "KbbaaaabbaaaabKabK"]],
  20: [[9, "KabccccbccddcbKabK"]],
  21: [[9, "KabccccbccddcbKabKKKKK"]],
  22: [[10, "KabcccbcddcbK"], [23, "KabbcccK"]],
  23: [[10, "KabbccbcccbbK"], [23, "KaabbccK"]],
  24: [[10, "KabcccbcddcbK"], [23, "KKaabbcK"]],
  25: [[10, "KabcccbcccbbK"], [24, "KKKabbK"]],
  26: [[10, "KabbccccccbbK"], [27, "KKKK"]],
  27: [[10, "KaabbbbbbbbbK"]],
  28: [[9, "KlLLLLLLLLLLLlK"]],
  29: [[9, "KlLLLLLLLLLLLlK"]],
  30: [[9, "KllLLLLKLLLLllK"]],
  31: [[9, "KbcddccKabccbbK"]],
  32: [[9, "KbcddccKabccbbK"]],
  33: [[8, "KbcddccK"], [17, "KabccbbK"]],
  34: [[8, "KbcddccK"], [17, "KabccbbK"]],
  35: [[8, "KbcddcbK"], [18, "KabccbbK"]],
  36: [[7, "KbccdcbK"], [18, "KabccbbK"]],
  37: [[7, "KbcdddcK"], [18, "KabcdcbK"]],
  38: [[7, "KaabccbK"], [18, "KaabcbbK"]],
  39: [[7, "KabccbK"], [19, "KabcbbK"]],
  40: [[7, "KabccbK"], [19, "KabcbbK"]],
  41: [[7, "KabccbK"], [19, "KabcbbK"]],
  42: [[7, "KabccbK"], [19, "KabcbbK"]],
  43: [[7, "KabccbK"], [19, "KabcbbKKK"]],
  44: [[7, "KabccbKKK"], [19, "KabcccccK"]],
  45: [[6, "KabcccddcK"], [19, "KaabbbccK"]],
  46: [[6, "KabbbbbccK"], [19, "KKKKKKKKK"]],
  47: [[6, "KKKKKKKKKK"]],
})

// Wide belt with a brass buckle, a dyed loincloth with a front flap
const LEGS = rows({
  27: [[9, "KLmmmmmmmyYYmmK"]],
  28: [[9, "KLLLLLLmmyyYLLK"]],
  29: [[9, "KrRRReeReeeeRRK"]],
  30: [[9, "KrRRRReRReeeeRK"]],
  31: [[9, "KKrRRReRReeeeKK"]],
  32: [[10, "KKKrRReRReeKKK"]],
  33: [[12, "KrRReRReeK"]],
  34: [[12, "KrRRerReeK"]],
  35: [[12, "KrrRRrRReK"]],
  36: [[12, "KKrRKrRRKK"]],
  37: [[14, "KK.KKK"]],
})

// Fur boots, each bound with one leather strap
const BOOTS = rows({
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
})

// Iron chest disc on a leather harness
const TORSO_GEAR = rows({
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
})

// Plain iron cap with a raised rim; the rim's shadow is the brow
const HELMET = rows({
  0:  [[16, "KKKK"]],
  1:  [[15, "K3454K"]],
  2:  [[14, "K234543K"]],
  3:  [[13, "K12345443K"]],
  4:  [[13, "K11234443K"]],
  5:  [[13, "K11223443K"]],
  6:  [[12, "K2334455443K"]],
  7:  [[12, "KKKKKKKKKKKK"]],
  8:  [[21, "4K"]],
  9: [[21, "4K"]],
  10: [[21, "K"]],
})

// Round shield on the far arm: iron rim, worn red paint, a big iron boss
const SHIELD = rows({
  17: [[23, "KKKKK"]],
  18: [[22, "K34454K"]],
  19: [[21, "K2eeeee4K"]],
  20: [[21, "K2Reeee4K"]],
  21: [[20, "K2RReeeee3K"]],
  22: [[20, "K1RR444ee3K"]],
  23: [[20, "K1R24553e3K"]],
  24: [[20, "K1R23443R2K"]],
  25: [[20, "K1r12332R2K"]],
  26: [[20, "K1rr122RR2K"]],
  27: [[20, "K1rrrrrRR1K"]],
  28: [[20, "K1mrrrrRR1K"]],
  29: [[21, "K1mrrrr1K"]],
  30: [[21, "K11rrr11K"]],
  31: [[22, "K11221K"]],
  32: [[23, "KKKKK"]],
})

// Near arm: upper arm hanging, forearm across the waist, fist at x13-16, y22-25
const NEAR_ARM = rows({
  12: [[5, "KKKKK"]],
  13: [[4, "KcdddcK"]],
  14: [[4, "KbcddcK"]],
  15: [[4, "KbcddcK"]],
  16: [[4, "KbcddcK"]],
  17: [[4, "KbccdcK"]],
  18: [[4, "KabbccK"]],
  19: [[4, "KabcdcK"]],
  20: [[4, "KabcdcK"]],
  21: [[4, "KabcdcK"], [13, "KKKK"]],
  22: [[4, "KabccaKKKcddcK"]],
  23: [[4, "KabcadddccdccK"]],
  24: [[4, "KaabccccbcccbK"]],
  25: [[4, "KKabbbbbbbbbbK"]],
  26: [[6, "KKKKKKKKKKKK"]],
})

// Brass arm ring, leather bracer
const ARM_GEAR = rows({
  18: [[4, "KyYYYyK"]],
  19: [[4, "KyyYYyK"]],
  23: [[10, "mmL"]],
  24: [[10, "mLL"]],
  25: [[10, "LLL"]],
})

// Heavy sword carried on the shoulder: blade up and back at a 2:1 slope, guard above the
// fist, pommel below it. The grip is inside the fist. Dried blood on the edge near the point.
const WEAPON = rows({
  0: [[4, "KK"]],
  1: [[3, "K45K"]],
  2: [[3, "K445K"]],
  3: [[3, "K2245K"]],
  4: [[3, "K224RK"]],
  5: [[4, "K224RK"]],
  6: [[4, "K224rK"]],
  7: [[5, "K2244K"]],
  8: [[5, "K2244K"]],
  9: [[6, "K2245K"]],
  10: [[6, "K2245K"]],
  11: [[7, "K1134K"]],
  12: [[7, "K1134K"]],
  13: [[8, "K2244K"]],
  14: [[8, "K2244K"]],
  15: [[9, "K2244K"]],
  16: [[9, "K2244K"]],
  17: [[10, "K2245K"]],
  18: [[9, "KK2245KKKK"]],
  19: [[9, "K34444454K"]],
  20: [[9, "K11222211K"]],
  21: [[9, "KKKKKKKKKK"]],
  26: [[13, "K44K"]],
  27: [[13, "K33K"]],
  28: [[14, "KK"]],
})

const A2 = { CLOAK, BODY, LEGS, BOOTS, TORSO_GEAR, HELMET, SHIELD, NEAR_ARM, ARM_GEAR, WEAPON }
const ORDER = ["cloak", "body", "legs", "boots", "torso_gear", "helmet", "shield", "near_arm", "arm_gear", "weapon"]
const BRONZE = { 0: "p", 1: "q", 2: "t", 3: "s", 4: "v", 5: "w" }

function doll(name, opts, skip = []) {
  sprite(name, { w: W, h: T, ...opts },
    ...ORDER.filter((n) => !skip.includes(n)).map((n) => layer(n, A2[n.toUpperCase()])))
}

doll("a2", { layers: true })
doll("a2_bronze", { swap: BRONZE })
doll("a2_nohelm_noshield", {}, ["helmet", "shield"])
doll("a2_bare", {}, ["helmet", "shield", "weapon", "torso_gear"])
doll("a2_body", {}, ["cloak", "legs", "boots", "torso_gear", "helmet", "shield", "arm_gear", "weapon"])
sprite("a2_left", { base: "a2", flip: "x" })
