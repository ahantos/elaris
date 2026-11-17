// B: longsword item picture, 32 x 96, in the style of the A1 figure: the same steel,
// bronze and leather ramps, no dark contour on lit edges, dark only on the shade side
// and undersides. LIGHT: from the upper right, as on A1's own blade.
// Anatomy, top to bottom: point, blade with a fuller, guard with a garnet, wrapped
// grip, wheel pommel. Ornament sits on the hilt; the blade is kept calm.

pal({
  0: "#0f1a28", 1: "#202e37", 2: "#3d4f56", 3: "#819796", 4: "#c7cfcc", 5: "#f1f2ec",   // steel (A1)
  p: "#24141c", q: "#4c2a26", r: "#774528", s: "#a06c34", t: "#c9984f", v: "#ecd6a2",   // bronze (A1)
  l: "#38211f", L: "#59362a", m: "#7e4c36", M: "#a07048",                               // leather (A1)
  a: "#3a0f1c", b: "#70182a", c: "#a42a36", d: "#d85c4c",                               // garnet
})
ramps("012345", "pqrstv", "lLmM", "abcd")

const CX = 16                       // the ridge runs down column 16
const TIP = 2, BASE = 66            // first and last blade rows
const FULLER = [24, 62]             // rows where the fuller is cut

// Half-width of the blade per row: the point opens in runs of 2, 3, 6, then holds
function half(y) {
  if (y < 4) return 0
  if (y < 7) return 1
  if (y < 13) return 2
  return 3
}

// Tone across the blade: soft back edge, shade plane, fuller shadow, lit lip, lit
// plane, bright working edge
function tone(y, x) {
  const h = half(y), i = x - CX
  if (h === 0) return 4
  if (i === h) return 5
  if (i === -h) return y > 44 && h > 1 ? 1 : 2
  if (i < 0) return i === -1 && y >= FULLER[0] && y <= FULLER[1] ? 1 : 2
  if (i === 0) return 4
  return i === h - 1 && h > 2 ? 4 : 3
}

// Reflections, [first row, last row, step]: a sheen high up, one dark band, the
// brightest patch just above the guard. Each one slants up toward the working edge.
const BANDS = [[19, 21, 1], [37, 39, -1], [57, 61, 1]]

sprite("longsword", { w: 32, h: 96 },
  (c) => {
    for (let y = TIP; y <= BASE; y++) {
      const h = half(y)
      for (let x = CX - h; x <= CX + h; x++) {
        let t = tone(y, x)
        const yy = y + Math.floor((x - CX) / 2)
        for (const [y0, y1, d] of BANDS)
          if (yy >= y0 && yy <= y1 && !(d > 0 && t === 1)) t += d
        c.px(x, y, String(Math.max(1, Math.min(5, t))))
      }
    }
    // the fuller ends in a soft stop at each end
    c.px(CX - 1, FULLER[0] - 1, "2"); c.px(CX - 1, FULLER[1] + 1, "2")
    // wear: two nicks in the working edge, one scratch on the shade plane
    c.px(CX + 3, 28, "_"); c.px(CX + 2, 28, "5"); c.px(CX + 2, 29, "5")
    c.px(CX + 3, 49, "_"); c.px(CX + 2, 49, "5"); c.px(CX + 2, 50, "5")
    c.px(CX - 3, 44, "3"); c.px(CX - 2, 45, "3"); c.px(CX - 2, 46, "3")
  },

  // guard: knobbed arms and a centre block set with a garnet
  grid(2, 67, `
    .st.......stttttttv......tv.
    rstttttttttsqcddqtvttttvstvt
    qrssssssssrqbcd5cttsssstrstt
    qrrsrrrrrrrqbccdcstrrrrrrsss
    pqrrppppppqqacbcbssppppqqrsr
    .pp.......qrqaabrss......pp.
    ..........pqrrrrssq.........
    ...........ppppppp..........`),

  // grip: leather wrap, dark on the shade side, with a bronze ring half way
  grid(14, 75, `
    lLmMm
    lLmMm
    llLLm
    lLmMm
    lLmMm
    llLLm
    rstvs
    qrsts
    lLmMm
    lLmMm
    llLLm
    lLmmm`),

  // wheel pommel set with a second, smaller garnet
  grid(12, 87, `
    ..stttv..
    .rsttvvt.
    qrssttvts
    qrscd5tts
    qrqbcdsts
    pqrbbcssr
    .pqrrrsr.
    ..ppqqp..`))

// The same picture on the two floor colours and a dark inventory slot, for review
scene("longsword_review", { w: 120, h: 104, bg: "#181616" },
  layer("slots", rect(4, 4, 32, 96, "#3a322c"), rect(44, 4, 32, 96, "#56483a"), rect(84, 4, 32, 96, "#1e2422")),
  layer("items", stamp("longsword", 4, 4), stamp("longsword", 44, 4), stamp("longsword", 84, 4)))
