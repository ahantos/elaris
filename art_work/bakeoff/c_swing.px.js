// C: sword swing for the A1 barbarian, 8 frames at 12 a second (some frames held).
// Made by moving sections on whole pixels: the built A1 layer pictures are placed at
// offsets, and only the swinging arm, the sword at its other angles and the effects
// are drawn here. Build a1.px.js first: this file reads out/sprites/a1/<layer>.png.
//
// Parts of the action: idle, anticipation (lean back, sword tips back), a held peak,
// strike with one smear, impact flash, held impact with a burst, settle, return.

pal({
  K: "#17121c",
  a: "#5f2f33", b: "#8c5540", c: "#b57a55", d: "#dba878",    // skin (A1)
  l: "#38211f", L: "#59362a", m: "#7e4c36", M: "#a07048",    // leather (A1)
  0: "#0f1a28", 1: "#202e37", 2: "#3d4f56", 3: "#819796", 4: "#c7cfcc", 5: "#f1f2ec",   // steel (A1)
  s: "#a06c34", t: "#c9984f", v: "#ecd6a2",                  // spark colours (A1 bronze lights)
})

const CW = 80, CH = 74          // animation canvas
const OX = 14, OY = 26          // where the 32 x 48 figure stands on it
const PX = 14, PY = 8           // origin of figure coordinates inside a part sprite
const PW = 72, PH = 60

// A part sprite written in figure coordinates: { y: [[x, "chars"], ...] }
function part(name, runs, extra = []) {
  sprite(name, { w: PW, h: PH }, (cv) => {
    for (const [y, list] of Object.entries(runs))
      for (const [x, chars] of list)
        for (let i = 0; i < chars.length; i++)
          if (chars[i] !== ".") cv.px(PX + x + i, PY + Number(y), chars[i])
    for (const [x, y, k] of extra) cv.px(PX + x, PY + y, k)
  })
}

// A1's blade from the guard to the point, across: back edge, dark band, lit plane, edge
const BLADE = ["2145", "2145", "2134", "2134", "2144", "214.", "2145", "2145", "2134", "1034", "1034", "2134",
  "2144", "2144", "2145", "2145", "2134", "2134", "2144", "2144", "2145", "2145", "2145", ".24.", "..4."]

// The sword tipped back about 27 degrees (one pixel left every two rows), for the wind-up.
// The fist is where it is in the idle pose: x4-7, y27-30.
const back = []
BLADE.forEach((row, k) => {
  for (let j = 0; j < 4; j++) if (row[j] !== ".") back.push([3 - Math.floor(k / 2) + j, 24 - k, row[j]])
})
part("_sword_back", {
  25: [[5, "4454"]],
  26: [[1, "3444"], [5, "2110"]],
  27: [[1, "0112"]],
  31: [[6, "44"]],
  32: [[6, "22"]],
}, back)

// Near arm thrown forward and a little down; fist at x22-25, y17-21
part("_arm_fwd", {
  13: [[8, "cddc"]],
  14: [[7, "Kcddddddc"]],
  15: [[7, "Kbcddcccdddc"]],
  16: [[7, "Kbcccccccccdddc"]],
  17: [[7, "Kabccbbbccccccccddc"]],
  18: [[8, "Kabbaaabbbccccccdc"]],
  19: [[9, "KKKKKKaaabbbbbccc"]],
  20: [[15, "KKKaaabbbcb"]],
  21: [[18, "KKKKaabb"]],
  22: [[22, "KKKK"]],
})

// Bracer for the forward arm (the fur on the shoulder is A1's own, it does not move)
part("_bracer_fwd", {
  16: [[18, "MMm"]],
  17: [[18, "m4m"]],
  18: [[18, "LLL"]],
  19: [[18, "lll"]],
})

// The sword pointing forward and down about 27 degrees (one pixel down every two across).
// Light still comes from above, so the bright edge is the upper one.
const fwd = []
BLADE.forEach((row, k) => {
  for (let j = 0; j < 4; j++) if (row[3 - j] !== ".") fwd.push([28 + k, 17 + Math.floor(k / 2) + j, row[3 - j]])
})
part("_sword_fwd", {
  14: [[26, "34"]],
  15: [[26, "14"]],
  16: [[26, "14"]],
  17: [[26, "25"]],
  18: [[26, "24"]],
  19: [[26, "24"]],
  20: [[26, "14"]],
  21: [[26, "14"]],
  22: [[26, "13"]],
  23: [[26, "02"]],
}, fwd)

// One smear for the strike: a crescent swept about the point the forward blade aims
// back at (figure 9,10), so the blade itself closes its leading end. Widest and
// brightest just behind the blade, thinning and darkening toward the tail.
const SMEAR_UP = 20
sprite("_smear", { w: PW, h: PH + SMEAR_UP }, (cv) => {
  const cx = PX + 9, cy = PY + SMEAR_UP + 10, R = 47, FROM = -24, TO = 40
  for (let y = 0; y < cv.h; y++)
    for (let x = 0; x < cv.w; x++) {
      const dx = x - cx, dy = cy - y, r = Math.hypot(dx, dy)
      const deg = Math.atan2(dy, dx) * 180 / Math.PI
      if (deg < FROM || deg > TO) continue
      const t = (deg - FROM) / (TO - FROM)           // 0 at the blade, 1 at the tail
      const w = 12 * Math.pow(1 - t, 1.4) + 1
      if (r > R || r < R - w) continue
      const inner = (R - r) / w                      // 0 on the outer rim
      cv.px(x, y, t < 0.25 ? (inner < 0.6 ? "5" : "4") : t < 0.5 ? (inner < 0.5 ? "4" : "3") : t < 0.78 ? "3" : "2")
    }
})

// Hit effect, three steps: flash, burst, fading sparks
sprite("_hit_0", `
  .....v.....
  .....5.....
  ..v..5..v..
  ...v.5.v...
  ....555....
  v555555555v
  ....555....
  ...v.5.v...
  ..v..5..v..
  .....5.....
  .....v.....`)
sprite("_hit_1", `
  .......v.......
  .v.....v.....v.
  ..v.........v..
  ...v.......v...
  ...............
  ......v5v......
  vvv...555...vvv
  ......v5v......
  ...............
  ...t.......t...
  ..t.........t..
  .t.....t.....t.
  .......t.......`)
sprite("_hit_2", `
  .......t.......
  t.............t
  ...............
  ...............
  ...............
  ...............
  .......v.......
  tt...........tt
  ...............
  ...............
  ...............
  ...............
  .s...........s.
  s......s......s
  .......s.......`)

const A1 = (n) => `out/sprites/a1/${n}.png`
const pic = (n, x, y) => image(A1(n), x, y, { palette: false })
const WAIST = 24                // figure row where the upper body is cut from the hips

// One frame: the upper body leans by `lean` and sinks by `sink`; the cloak follows a
// frame late (`cloak`); `arm` gives the arm, its gear and the sword; `fx` goes on top.
function pose({ lean = 0, sink = 0, cloak = lean, arm, under = [], fx = [] }) {
  const ux = OX + lean, uy = OY + sink
  return [
    pic("cloak", OX + cloak, OY),
    clip([0, OY + WAIST, CW, CH - OY - WAIST], pic("body", OX, OY)),
    clip([0, 0, CW, OY + WAIST + sink], pic("body", ux, uy)),
    pic("legs", OX, OY), pic("boots", OX, OY),
    pic("torso_gear", ux, uy), pic("helmet", ux, uy), pic("shield", ux, uy),
    ...under,
    ...arm(ux, uy), ...fx,
  ]
}

const idle = (dx = 0, dy = 0) => (ux, uy) =>
  [pic("near_arm", ux + dx, uy + dy), pic("arm_gear", ux + dx, uy + dy), pic("weapon", ux + dx, uy + dy)]
const windup = (dx, dy) => (ux, uy) =>
  [pic("near_arm", ux + dx, uy + dy), pic("arm_gear", ux + dx, uy + dy), stamp("_sword_back", ux + dx - PX, uy + dy - PY)]
const strike = (dx = 0, dy = 0) => (ux, uy) => [
  stamp("_sword_fwd", ux + dx - PX, uy + dy - PY),
  stamp("_arm_fwd", ux + dx - PX, uy + dy - PY),
  clip([0, 0, CW, uy + 18], pic("arm_gear", ux, uy)),          // the fur stays on the shoulder
  stamp("_bracer_fwd", ux + dx - PX, uy + dy - PY),
]
const HIT = [OX + 54, OY + 31]   // where the point lands

anim("a1_swing", { w: CW, h: CH, fps: 12 },
  frame({ hold: 2 }, ...pose({ arm: idle() })),
  frame(...pose({ lean: -1, cloak: 0, arm: windup(-1, -1) })),
  frame({ hold: 2 }, ...pose({ lean: -1, arm: windup(-2, -3) })),
  frame(...pose({ lean: 1, cloak: -1, arm: strike(), under: [stamp("_smear", OX + 1 - PX, OY - PY - SMEAR_UP)] })),
  frame(...pose({ lean: 2, sink: 1, cloak: 1, arm: strike(1, 1), fx: [stamp("_hit_0", HIT[0] - 5, HIT[1] - 5)] })),
  frame({ hold: 2 }, ...pose({ lean: 2, sink: 1, arm: strike(1, 2), fx: [stamp("_hit_1", HIT[0] - 7, HIT[1] - 6)] })),
  frame({ hold: 2 }, ...pose({ lean: 1, cloak: 2, arm: strike(0, 1), fx: [stamp("_hit_2", HIT[0] - 7, HIT[1] - 6)] })),
  frame(...pose({ lean: 0, cloak: 1, arm: idle(1, -1) })))

// Exported copies of the drawn parts, so the same animation can be assembled as an
// Aseprite file (ase/build_swing.lua reads out/sprites/swing_<part>.png)
for (const n of ["sword_back", "arm_fwd", "bracer_fwd", "sword_fwd", "smear", "hit_0", "hit_1", "hit_2"])
  sprite("swing_" + n, { base: "_" + n })
