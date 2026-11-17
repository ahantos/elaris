# Pixel Art Theory Reference

A working reference for hand-placed sprites: 32×48 side-facing paper-doll figures on 32 px tiles, larger item pictures, and later monsters, tiles and effects. Mood target: gritty, muted, earthy, blocky in a 1990s way. Compiled 2026-11-17 from the sources listed at the end.

## 0. How to read this

**The problem this document addresses.** The sprites are already clean and aligned. They look plain for five reasons, each with a cure:

| Symptom | Usual cause | Cure |
|---|---|---|
| Flat shading | Tones follow the outline or sit in even stripes, with no planes and no cast shadows | Section 2 |
| Timid contrast | Neighbouring ramp steps are too close, and the darkest and lightest tones are barely used | 3.1, 3.4 |
| Weak materials | Every material is drawn with the same ramp shape and the same highlight | Section 5 |
| Dead colour | Ramps change brightness only | 3.2, 3.3 |
| No focus | Detail is spread evenly, so nothing stands out | 1.3, 8.5 |

**The five rules that do most of the work**

1. **Spend the value range.** Every material shows at least three clearly separate values, and the sprite's lightest light sits next to a dark at the focal point. Judge in greyscale.
2. **Shade planes and cast shadows, not edges.** One light. Top planes light, facing planes middle, under and back planes dark, plus a hard shadow wherever one piece overhangs another.
3. **Separate materials by contrast and highlight shape.** Steel is near-black against near-white in hard bands. Cloth is three close tones and no highlight. Hue comes last.
4. **Bend every ramp.** Shift hue and saturation along with brightness.
5. **Large uneven clusters first, a few deliberate accents last.** Every patch of tone needs a reason to exist.

**Conventions used here**

- Grid key: `.` transparent, `0` outline or darkest tone, `1` deep shadow, `2` shadow, `3` base, `4` light, `5` highlight. Other letters are explained beside the grid.
- Every example is lit from **above and slightly from the right**, which is "above and slightly in front" of a right-facing figure (see 2.1). Mirror the examples if the project's light comes from the upper left.
- The grids are schematics of tone placement. Each was rendered once to confirm it reads. They are not finished art.
- A tag such as [Cure] or [S11: Metal] names the source of a rule (see Sources). **[own]** marks a derivation made for this project's sizes that no source states directly. Treat those as defaults to test, not as established teaching.

---

## 1. Fundamentals at low resolution

### 1.1 Readability outranks everything
Judge at 1x, on the real floor tile, before judging anything else. A sprite that reads only when zoomed in has failed [OM-p]. Low-resolution art works because information is missing and the viewer fills it in [Sly 47], so the job is to choose which few facts to state: who this is, which way it faces, what it carries, what it is made of.

### 1.2 Silhouette first
- Start every sprite as a single-colour shape. The silhouette is the first thing the viewer notices, and it should already say "humanoid, armoured, has a sword" [S11: Silhouette]. At small sizes begin with coloured shapes, not line art, because an outline spends pixels that shading needs [Yu].
- Build strong, simple features into the outline: a helmet crest, a shield rim, a weapon held clear of the body. A weapon drawn across the torso disappears.
- Keep every protruding part at least 2 px thick, and 3 px if it must show form. A 1 px limb cannot be shaded and looks flimsy [Yu 2, OM-p].
- For monsters later: long limbs, snake-like curves, pointed and complicated shapes read as dangerous [S11: Silhouette].
- Test: fill the sprite with one colour. Is it recognisable, is the facing clear, is the weapon visible [Pixnote, OM-s]?

### 1.3 Clusters
A cluster is a group of touching pixels of one colour. Clusters are the unit of drawing, not pixels [Cure, Sly 5].

- Use few, large clusters. Many small ones read as noise [S11: Fundamentals 1].
- A single pixel that touches no pixel of its own colour is an orphan. Remove it unless it is a specular highlight, an eye, a rivet or a similar essential detail [Cure, S11]. Pixels touching only at a corner connect poorly and count as nearly orphaned [S11: Fundamentals 1].
- Every patch of tone must have a nameable reason: a plane, a fold, a cast shadow, a highlight, a seam. A patch with no reason is noise [Codixel, S11: Darkness].
- Avoid accidental squares. Same-colour pixels tend to clump into 2×2 and 3×3 blocks that expose the grid. Offset rows like brickwork [S11: Fundamentals 2].

```
noisy     clustered
334333    444333
323343    443332
333233    333322
343332    333222
```

### 1.4 Lines and jaggies
A jaggy is a pixel or short run that breaks the rhythm of a line [Yu, Cure].

- Straight lines: make every step the same length (1, 2 or 3 px per step). When an exact slope is impossible, repeat a pattern of adjacent numbers such as 2, 2, 3, 2, 2, 3 [S11: Fundamentals 2].
- Curves: run lengths only shrink toward the bend, then only grow. 5, 2, 2, 1, 1 is smooth; 5, 2, 1, 2, 1 has a lump [Lospec O1].
- Steps connect at corners only. A step that also touches along a side makes a thick spot, called a double. Use that only on purpose, to sharpen a corner [Lospec O1, S11].

```
regular    jagged      curve: 4, 2, 1, 1, then down
......00   .....000    0000......
....00..   ....0...    ....00....
..00....   ..00....    ......0...
00......   00......    .......0..
                       ........0.
                       ........0.
```

### 1.5 Anti-aliasing by hand
Manual anti-aliasing (AA) puts a pixel of an in-between tone where a step is too harsh [Cure, Parmesan].

- Ask first whether it is needed. Often it is not, and on small sprites AA reads as noise [Parmesan].
- Never anti-alias an outer edge. AA tuned to one background makes a halo on another [Yu, OM-s]. On paper-doll layers the "background" is whatever layer lies underneath, so the rule is absolute there. Use no semi-transparent pixels in any layer [own].
- Inside a shape, scale the AA to the step: a 2 px step gets none, a 4 px step gets 1 px, an 8 px step gets 2 px [OM-p]. "The longer the segment, the longer the AA" [Parmesan].
- Take the AA colour from the existing ramp. Do not add a colour for it [Parmesan].
- AA pixels that run the full length of the line they soften create banding [Cure].
- A broken line often does the same job with no extra colour [Parmesan].
- At 32×48, expect to use AA almost nowhere. On item pictures, use it inside long curves such as a cuirass contour or a blade edge [own].

### 1.6 Banding
Banding is two neighbouring runs of pixels that begin and end at the same place, so the eye sees the grid in place of the form [Cure]. Variants: a tone that hugs the outline one pixel in, stacked stripes of equal width, the same stripes with a gap between, and diagonal rows one pixel thick [Cure]. Parallel runs of equal length also form tangents that stop the eye [Parmesan].

- Give shading bands unequal widths. "Avoid even shading bands" [Sly 6]. Compress the dark bands and let one tone dominate each plane [S11: Shading].
- End each band at a different place from its neighbour.
- If a band exists only to smooth a step, delete it.

### 1.7 Pillow shading
Pillow shading is darkening inward from the outline in rings, so the centre is lightest and no light direction exists [Cure, Yu 2]. Test: point to the light. If that is impossible, the sprite is pillow shaded [Pixnote]. The fix is in Section 2.

```
pillow     directional
.00000.    .00000.
0222220    0334440
0233320    0333450
0234320    0233340
0233320    0223330
0222220    0122230
.00000.    .00000.
```

### 1.8 Dithering
Dithering mixes two colours in a pattern to imply a third [Cure, Yu].

- Do not dither figures or faces. One source rules dither out below 32×32 and on faces [OM-p]. At 32×48 the parts are still only a few pixels wide, so the pattern is as large as the features [own].
- Do not dither metal. Dither reads as texture, and metal is smooth [eishiya].
- If dither would cover about half of a shape, add a colour instead [Cure].
- Where it is used (large item surfaces, rough stone, later tiles), keep it to a thin strip where two flat bands meet [Codixel], use one pattern per piece [OM-p], and avoid random scatter [Cure].
- Anything rotated or moved in code should carry no dither, because the pattern crawls [own].

---

## 2. Light and form

### 2.1 One light, written down
Fix one light for the whole game and write it at the top of every sprite file.

- For figures, light from **above and slightly in front** of the character: the top and front are lit, the bottom and back are shaded [Yu]. The face and chest carry identity, so they get the light. Because this light is defined relative to the character, a mirrored sprite stays correct.
- Make "above" dominant, roughly two thirds top and one third front [own]. A light straight overhead is the safest choice for flipped sprites [Kenney]; a strong side light is the least safe.
- Items are never mirrored. Light them all from one corner. Upper left is the common default [Pixnote, OM-s].
- Sources disagree on the default direction; see Sources. Consistency matters more than the choice.

### 2.2 The parts of a lit form
From lightest to darkest [S11: Shading, Sly 6]:

- **Highlight:** the small spot that mirrors the light. Present on glossy surfaces only.
- **Light:** planes facing the light.
- **Terminator:** the line where the form turns away from the light.
- **Core shadow:** the darkest band, just past the terminator.
- **Reflected light:** light bounced from the floor and nearby objects into the shadow side. It is lighter than the core shadow, darker than the base, and tinted by what it bounced from.
- **Cast shadow:** the shadow one object throws on another. It has a hard edge. Form shadow has a softer edge [S11: Shading].

At these sizes a hard edge is a jump of two ramp steps with nothing between. A soft edge passes through the step between [own].

### 2.3 Planes before curves
Reduce every object to a few flat faces and give each face one value. Faces are mostly one solid colour; avoid gradients inside them [S11: Shading]. The default assignment is top = light (4), facing the light = base to light (3 to 4), facing away = shadow (2), underside = deep shadow (1). Curvature is then added as one extra step at the edges of a face.

### 2.4 Sphere

```
10 px                5 px
...3444...           .344.
..344455..           33454
.33444454.           23344
1233444444           12333
1233344444           .122.
1223334444
1122333333
.21223333.
..211222..
...2222...
```

- The highlight is a small cluster set in from the edge, toward the light. It is never on the outline.
- The light tone is the largest area. The shadow occupies about a third.
- The core shadow (1) is a crescent just inside the far edge. The outermost pixels along the bottom step back up to 2: that is reflected light, and it is what makes the form look round.
- At 5 px the highlight is one pixel. This is a legitimate lone pixel.

### 2.5 Cylinder
Tone changes across the width only. Along the length it stays constant, except for cast shadows and a gradual darkening toward the floor.

```
cloth sleeve, 6 px     steel, 6 px
223343                 311542
223343                 311542
223343                 311542
```

- Matte: shadow, base, one light stripe set in from the lit edge. Three tones, soft.
- Metal: reflected light at the back edge (3), the darkest band (1), then the specular (5) directly beside it, then light (4), then a darker lit edge (2). The dark-to-bright jump is the metal.

### 2.6 Box

```
..4444..
44444444
22444433
22223333
22223333
22223333
..2233..
```

Three faces, three values, no gradients. Add form only at edges: one lighter line where two lit faces meet, one darker line along the bottom.

### 2.7 How many tones fit [own]

| Width of the part | Tones across it |
|---|---|
| 1 px | 1. Choose it from where the part sits |
| 2 px | 2: base and light, or shadow and base |
| 3 px | 3: shadow, base, light |
| 4–5 px | 3–4. Add the core shadow |
| 6 px and more | Full set, including reflected light |

### 2.8 The figure as volumes
- **Head:** a sphere on a short box (the jaw). Lightest on the crown and brow, darker under the brow, under the nose and under the jaw.
- **Helmet:** a dome on a ring. Shade the dome as the top of a sphere and give the brim a light top edge and a dark underside.

```
...0000..
..034440.
.02344540
.01234540
012233440
021223340
023344450
012233340
.0000000.
```

- **Torso:** a barrel. The shoulder row is lightest because it faces up. The chest is lit toward the front, a core band runs down the back third, the belly darkens as it turns under, and the lower rim picks up bounce light.

```
..0000000.
.034444440
0223445540
0212344540
0212334440
0211233430
0111223330
0111122320
.011112230
.012223330
..0000000.
```

- **Limbs:** cylinders, as in 2.5. A limb angled forward faces up and takes one step lighter. Mark the elbow and knee with a one-pixel change of plane, not a line.
- **Far-side limbs:** one whole step darker and lower in contrast than the near ones. This is the cheapest depth cue available [own].
- **Top-to-bottom falloff:** let the figure darken about one step from shoulders to shins. Light from above weakens toward the floor, and the eye is led to the head [Tsugumo 6 applies the same idea to tiles; own for figures].

### 2.9 Cast shadows between parts
Cast shadows add depth to simple sprites cheaply [Sly 6]. They are the most common missing ingredient in plain sprites. Put a hard-edged band, one or two steps darker, in these places:

- under the helmet brim, across the upper face
- under the jaw, on the neck and collar
- under the pauldron, on the upper arm
- along the back edge of the near arm, on the torso
- under the hem of the cuirass, on the thighs
- behind the shield, on the far arm and body
- on the floor: a dark ellipse 1–2 px tall under the feet, drawn as a separate sprite so that it neither mirrors nor moves with the body sections [own]

---

## 3. Colour

### 3.1 Value first
Value carries form and readability. Hue and saturation decorate. If a sprite does not work in about four values, more colours will not rescue it [Cure]. When a sprite looks weak, remove colours and raise the contrast between those that remain, so each colour has a distinct job [Yu 2]. Check by desaturating [Yu].

### 3.2 Hue shifting
A ramp that changes brightness only is a straight ramp and looks dead [Sly 1, Cure, Codixel].

- Shift hue as value changes: shadows toward blue and purple, lights toward yellow [S11: Shading, Cure, OM-p].
- Amount: 10–20° per step is the common advice [OM-p], and 20° per step is described as about the maximum [Sly 1]. For a muted earthy look use roughly 8–12° per step [own]. The Apollo palette's brown ramp travels about 50° over six steps, from rose-purple darks to yellow-cream lights [Apollo, measured for this document].
- Measured small sprites often shift hue very little [Pixnote], so the shift is not what makes a sprite readable. It is what makes it look alive once the values work. It pays off on ramps of three or more steps.
- Metal may reverse the rule: lights colder and less saturated, darks warmer and more saturated [S11: Metal]. See Sources for the disagreement.
- Consider the colour of the light [S11: Wood]. In a torch-lit dungeon, lights lean warm and shadows cool.

### 3.3 Saturation across a ramp
- Saturation peaks in the middle of the ramp and falls toward both ends. Never pair high saturation with high brightness [Sly 1].
- The first shadow step should keep or slightly gain saturation. A desaturated shadow looks muddy [Pixnote]. Only the last near-black step loses it.
- The lightest step of a mid-toned object stays clear of white [Codixel]. White is reserved for speculars on metal, gems and wet surfaces.

### 3.4 Value steps
- Aim for evenly perceived steps along a ramp [Sly 1], then widen them for hard materials.
- Working minimums: about 12 lightness points between neighbouring steps on matte materials and 20 or more on metal. One source asks for at least 20 everywhere [OM-p]; measured 16×16 art shows a median base-to-shadow drop of 16.5 [Pixnote].
- No single tone should cover more than half of an object, and both ends of the ramp must appear somewhere on it [Codixel].

### 3.5 Tones per material
- By sprite size: 16 px sprites carry 2 tones per material, 32 px carry 3, 48 px carry 3–4, 64 px and above carry 4–5 [Pixnote].
- On the 32×48 figure, a gear piece gets 3–4 tones plus the outline dark. Polished metal gets a fifth, the specular. Item pictures get 5–6.
- Per-sprite budget: characters 8–12 colours, large items and bosses 12–16 [OM-s]. Each layer of the paper doll is far below that.

### 3.6 Sharing colours between ramps
- Ramps may share their darkest and lightest colours, and neutral mid-tones (grey-browns) can serve several ramps [Cure]. Sharing ties the image together and keeps the palette controllable.
- Share one near-black, tinted blue-purple, as the darkest tone of every ramp, and one warm off-white as every specular [own].
- Do not share colours between two areas of one piece that must recolour separately (see 7.6) [Swap].

### 3.7 A muted palette that still has contrast
Muted means low saturation. It does not mean low value contrast.

- Keep most saturation between 15% and 45%. Keep lightness running from under 10% to about 90% [own].
- Shadows are never neutral black; give them a hue [Tsugumo 5].
- Allow two or three saturated accents (dried-blood red, copper orange, one cold blue) and use them only at focal points.
- Example ramps from the Apollo palette [Apollo]. These illustrate ramp structure and are not this game's palette. Lower their saturation by a fifth for a grittier result [own].

| Use | Dark to light |
|---|---|
| Steel and stone neutrals | `#10141f #202e37 #394a50 #577277 #819796 #a8b5b2 #c7cfcc #ebede9` |
| Leather and skin | `#4d2b32 #7a4841 #ad7757 #c09473 #d7b594 #e7d5b3` |
| Wood and bronze | `#341c27 #602c2c #884b2b #be772b #de9e41 #e8c170` |
| Red cloth | `#241527 #411d31 #752438 #a53030 #cf573c #da863e` |

In each ramp the darks converge on purple-blue and the lights drift toward yellow.

### 3.8 Dark sprites on dark floors
- Floors recede. Keep floor tiles low in contrast and darker than figures [Tsugumo 6]. On dark backgrounds, draw background detail in very few tones [S11: Darkness]. "If it's lighter, it's closer" [Tsugumo 5].
- Put the figure's base tones above the floor's lightest tone. A working split: floor between 10% and 25% lightness, figure base tones from about 33% upward [own].
- A dark outline cannot separate a figure from a dark floor, because an outline only helps where it is darker than both sides [Lospec O2]. The lit top and front edges do the separating. Let the shadow side sink into the floor; the viewer completes it [S11: Darkness].
- Check: at least half of the silhouette's edge should be bounded by tones clearly lighter than the floor [own].
- Dark materials such as blackened iron or black cloth are drawn as mid-darks with a full set of lights. Black armour drawn in blacks is a hole in the screen.
- A strong rim or back light is the standard way to pull a dark shape off a dark ground [S11: Darkness].

---

## 4. Outlines

### 4.1 What an outline is for
An outline separates an object from the background and its parts from each other [Lospec O1]. It also costs space. At very low resolution, avoid outlines where shading can do the separating [S11: Outlines, Yu].

### 4.2 Black, coloured, selective
- **Black:** the most robust on unknown backgrounds, and it reads as retro and flat [Lospec O2, Parmesan].
- **Coloured:** each area is outlined with a darker shade of itself. Softer [Lospec O2, Pixnote].
- **Selective (sel-out):** the outline is lighter where the light hits, darker in shade, and missing where a lit edge already separates the form [Yu, S11: Outlines]. "Use the outline to reinforce the shading" [S11: Outlines].
- The governing rule: an outline must add contrast. If the shape reads better without it at that spot, change it or drop it [Lospec O2].
- Sources disagree on sel-out (see Sources). The safe reading: vary the outline with the light, and never fade it toward a background colour that is not guaranteed.

### 4.3 Recommended outline scheme [own, built on the rules above]
- Outer contour: 1 px, in the darkest tone of the local material ramp (slot `0`). On the shade side and the underside it stays that dark.
- On lit top and front edges, replace it with step 2 of the material, or remove it and let the light plane be the edge.
- Do not use pure black. A near-black tinted toward blue-purple sits better with the ramps [Pixnote].

### 4.4 Inner lines
- Draw an inner line only where two neighbouring areas have nearly the same value. Where they already contrast, leave it out [Lospec O1].
- Default colour: one step darker than the area around it. Darker lines look thicker [Lospec O2, Codixel].
- Between two parts, use the outline colour of the part nearer the viewer, or of the darker part if one is in shadow [Lospec O2].
- Break the line. Show it only near the shadow side and let it fade out. The eye completes it [Lospec O2, Parmesan]. Suggest separation "just enough so the viewer gets the idea" [Lospec O1].
- No outline at contact points: where a hand grips a handle, where feet meet the floor. An outline there makes the object float [Lospec O1].

### 4.5 Outlines when gear layers stack [own]
A full outline on every layer produces 2 px dark seams wherever two layers meet, and the figure looks like stacked stickers.

- A gear piece carries a dark outline only on edges that lie on the outer silhouette of the figure.
- On edges that lie inside the figure, replace the outline with what the overlap would really show: a dark edge of one row (step 0 or 1) along the lower and back side, which reads as outline and cast shadow at once, and a light edge (step 4) along the upper and front side, which reads as thickness.
- Hard gear sits one pixel outside the body's silhouette on its outer side and covers the body's own outline. Cloth sits flush.
- Never depend on a neighbouring layer for an outline. That layer may not be equipped.
- An alternative is to draw no outer outline on any layer and generate a 1 px contour around the assembled figure. This cannot double up. The cost is that the contour must be regenerated whenever the pose changes. If this route is taken, add the contour after rigging, since an outline pass shifts coordinates by a pixel [Codixel].

```
bare thigh    cloth, flush    plate, one px proud
.02340.       .02340.         0213540
```

---

## 5. Materials, with recipes

Materials differ on five axes: value span, highlight (size, sharpness, position), edge hardness between tones, strength of reflected light, and texture marks. "Different materials react differently to light" [Sly 6]. The lightness figures below are starting values to tune by eye [own]; the ordering and the relative spans are what the sources support [S11, eishiya, Pixnote].

| Material | Lightness of slots 1–5 | Highlight | Tone edges | Marks |
|---|---|---|---|---|
| Polished steel | 15, 28, 52, 78, 92 | 1–2 px near-white streak beside the darkest band | Hard, skips steps | Scratches, nicks |
| Dull iron | 14, 24, 38, 52, 60 | Broad patch one step up, no white | Medium | Pitting, rust in recesses |
| Bronze | 16, 27, 42, 58, 78 | Pale yellow, small | Hard | Dents, dark tarnish |
| Copper | 16, 26, 42, 58, 76 | Pale pink-cream, small | Hard | Dents, dark tarnish |
| Boiled leather | 14, 22, 33, 45, 54 | Dull sheen, 2–3 px, one step up | Medium | Rivets, edge wear, cracks |
| Soft leather | 16, 24, 34, 44, 46 | None | Soft | Creases, stitches |
| Cloth, wool | 18, 27, 38, 48, 48 | None | Soft | Folds only |
| Fur | 14, 24, 36, 48, 52 | Light tips on the lit side | Broken | Tufts |
| Wood | 16, 25, 36, 47, 50 | Almost none | Slow | Grain, knots, cracks |
| Skin | 24, 37, 51, 62, 62 | None at this size | Soft | None |
| Bone | 25, 40, 58, 74, 84 | Matte light | Medium | Cracks, sockets |
| Stone | 14, 24, 38, 52, 62 | Light on top planes | Hard, by plane | Cracks, chips |

Where slot 5 equals slot 4, the specular vanishes. That is how one drawn piece becomes matte (see 7.6).

### 5.1 Polished steel
"What gives metal its distinct look is its reflectiveness" [eishiya].

- Get the form right in plain light and shadow first, then add shine [eishiya].
- Use the widest span in the game. Let dark and bright meet directly: place the near-white streak beside the darkest band.
- On curved plate, reflections stretch into bands that run along the form. Two or three alternating light and dark bands are enough to say "metal" [eishiya, S11: Metal].
- Expect a strong back light: the reflected light on the shadow edge is brighter than on any other material [S11: Metal].
- No dither, no soft gradients [eishiya].
- Keep it nearly neutral in hue. Tint the darks blue-black and choose one of two looks for the lights: cold (sky-lit) or faintly warm (torch-lit) [S11: Metal, own].
- Ramp example: `#10141f` outline, then `#202e37`, `#394a50`, `#819796`, `#c7cfcc`, `#ebede9`. The jump from the second to the third tone is deliberate.

### 5.2 Dull iron and worn metal
- Same construction as steel, with the top of the ramp cut off. No near-white.
- Brushed or rough metal reflects "in vague clouds rather than in clear bands" [eishiya]: replace streaks with one broad lighter patch.
- Add pitting as small dark marks two pixels in size, never single scattered pixels. Put an orange-brown rust tone in recesses and along lower edges.
- "Scratches and bruises tell a story about that object" [S11: Metal]. Worn metal is what the mood calls for. When one studio's setting turned grimmer, it redrew sprites whose bones were pristine and whose armour looked new, making them decayed [Stoneshard].

### 5.3 Bronze and copper
- High contrast like steel, with warm hue and high saturation in the middle of the ramp.
- Bronze: shadows deep red-brown, mid orange-brown, lights yellow, specular pale yellow. Never white.
- Copper: shift everything toward red. Shadows purple-brown, mid orange-red (hue about 15–20°), lights peach, specular pale pink-cream.
- One mid tone is not enough for a yellow metal. It needs brown shadows and near-white lights around it [general painting advice, found only in summary].
- Start bronze from the wood-and-bronze ramp in 3.7, with `#e7d5b3` as the specular.
- A green-blue patina tone in recesses separates old bronze from gold [own].

### 5.4 Leather
- **Soft leather** (belts, boots, jerkins): middle contrast, three to four tones, no specular. Shadows shift toward red-purple, lights toward tan. Put creases only where it bends (ankle, elbow, waist), as short lines one step darker. A stitch line one step lighter along a seam is the cheapest leather signal.
- **Boiled leather** (hardened armour): shaped like plate, lit like wood. Keep plate's hard edges and forms, narrow the span, and replace the specular with a short dull sheen one step above the light tone. Edges wear lighter. Rivets and straps complete it.

### 5.5 Cloth and wool
- Most fabric has soft shadows and no highlights [S11: Fabric].
- Folds radiate from the point where the cloth is compressed or hung: shoulder, belt, elbow. Folds run parallel where tension is high and across where it is low [S11: Fabric].
- Folds cast shadows on the cloth itself. Dark areas carry less detail. Too many folds become noise [S11: Fabric].
- Respect the body underneath: cloth lies flat over the shoulder and thigh and folds beside them.
- A fold in cross-section, lit from the right, is shadow slope (2), top (3), lit slope (4), followed by a hard drop into the next fold. Vary the widths, and let the boundaries drift one pixel every two to four rows so the folds lean and widen:

```
233422344234
```

- Wool is thick: few, broad folds. Linen is thin: more, narrower folds near the gather points.

### 5.6 Fur
- Draw clumps, not hairs. Break the silhouette with tufts 2–3 px long that all lean the way the fur lies.
- Inside, use staggered short marks one step darker, in rows offset like brickwork. Put lighter tips on the lit side only.
- Keep it matte. Each mark is at least two pixels, so none is an orphan.

```
.4..4..4..
3434434434
3423423423
3323323323
2332332332
```

### 5.7 Wood
- Moderate contrast, slow transitions, almost no highlight. Shift the shadow hue. Do not overdo the highlight [S11: Wood].
- Big shapes and bevels first, grain afterward. Raise the contrast where boards meet [S11: Wood].
- Grain is a few long broken lines one step darker, running along the length, staggered so that no two line ends align. Add at most one knot, crack or nail per small object.

```
444444444444
333322233333
332333333223
333333222333
322233333333
222222222222
```

### 5.8 Skin
- Three tones at figure size. Soft steps. Shadows lean red, not grey [Pixnote].
- No inner outlines on the face. Separate features by value.
- Skin sits in the upper-middle of the value range, so a face surrounded by dark hair or a dark helmet becomes a focal point by default.

### 5.9 Bone
- Off-white lights, warm grey-brown or greenish shadows, matte.
- On skulls, spend the pixels in this order: eye sockets, upper jaw, cheekbone, teeth, nose hole, lower jaw. On the smallest skulls keep only the eyes and nose [S11: Skulls].
- Simple bones are ribbon shapes with a knob at each end. Diagonal bones use fewer pixels [S11: Skulls].

### 5.10 Stone
- Stone is planes. Start from the silhouette, add base shadows, then a softer second layer, then highlight areas, then back light. Reduce noise at the end [S11: Rock].
- Keep large clean areas, with hard changes of tone at edges. Avoid orphan pixels and too many colours on details [S11: Rock].
- Layered stone gets big soft highlights and crumbling edges. Hard stone gets stronger highlights and breaks in large chunks. Porous volcanic stone gets rounded shapes, holes and very soft highlights [S11: Rock].
- Rough surfaces need irregular pixel-level breakup, not a smooth gradient, which looks like plastic [Tsugumo 3].

### 5.11 Small marks

- **Rivet:** a 2×2 stud. Light pixel toward the light, dark pixel opposite, and one shadow pixel beside it on the shade side.

```
33333
33453
32123
33333
```

- **Nick in an edge:** remove one edge pixel and put a highlight pixel beside the gap.
- **Scratch:** a diagonal of 2–3 px, one step lighter than the plane.
- **Dent:** one dark pixel with one light pixel on its lit side.

---

## 6. Small figures

### 6.1 Proportions at 32×48
- Realistic bodies are about 8 heads tall. That is too tall for pixel work, and 6 heads already reads as fairly realistic [Sly 17]. Canvases of 48 px and more suit 4–6 heads [Pixnote]. Smaller sprites need relatively larger heads [Yu].
- For a gritty figure that still reads, use about 5 heads [own]. Check the existing body template against this budget; do not redraw the template because of it.

| Part | Rows (0–47) | Size |
|---|---|---|
| Headroom for crests and helmets | 0–2 | 3 px |
| Head | 3–11 | 9 tall, 7–8 wide |
| Neck (mostly hidden) | 12 | 1 |
| Shoulders to crotch | 13–26 | 14 tall; shoulders 11–13 wide, waist 8 |
| Legs | 27–44 | 18; knee near row 35; each leg 4–5 wide |
| Feet | 45–47 | 3 tall, 5–7 long; row 47 is the ground line |

- Arms are 3–4 px wide and hands 3–4 px across. Thinner limbs cannot carry shading.
- Keep the body centred on the mirror axis (between columns 15 and 16), so that flipping does not move the feet [own].

### 6.2 Heads and faces
- The eyes sit halfway down the head. The nose ends halfway between eyes and chin. The mouth sits a third to a half of the way from nose to chin [Sly 17].
- Eye sizes by canvas: 1×1 on the smallest sprites, 1×2 or 2×1 at 16 px, 2×2 at 32 px [Pixnote]. On a 9 px head use 1×1 or 1×2.
- Moving an eye by one pixel changes the expression [Pixnote]. Place eyes deliberately and compare alternatives.
- In three-quarter view the face occupies the front four or five columns. The near eye sits inside the face, the far eye sits at or beside the profile edge, and the nose is one pixel breaking the profile.
- A row of shadow under the brow does more for a grim face than any eye detail. A mouth is one or two pixels of shadow tone, or nothing. Never draw it in the outline colour.
- Hair and beards are masses with their own light and shadow, not strands.
- When the head gets smaller, drop facial detail before anything else [S11: Resizing].

```
..hHHH..      h, H = hair dark, light
.hhHHHH.      e    = eye
hhhH444.      2–4  = skin
hhh3333.      row 3 is the brow shadow
hh23e3e.
hh233444      nose tip at the right edge
.h23322.      mouth as two pixels of shadow
.h22333.
..1222..      under the jaw
```

### 6.3 Hands
- A hand is a 3×3 or 3×4 block with rounded corners and no fingers. Add one thumb pixel on the side toward the body if the hand is open.
- A gripping hand is a fist drawn over the handle: the weapon layer goes under the near-hand layer, so the hand covers the grip. Leave no outline between hand and handle [Lospec O1].
- Shade the hand as a small box: light on top, one darker pixel underneath.

### 6.4 Feet
- In this view the near foot points in the facing direction: 5–7 px long, 2–3 px tall, with the heel one pixel behind the ankle.
- The far foot sits one pixel higher on screen and is one pixel shorter. Higher on screen means further away.
- Soles are flat on the ground row. No outline under the sole [Lospec O1]. The floor shadow does the grounding.

### 6.5 The three-quarter side view
- The body is turned 30–45° toward the viewer from pure profile. Both shoulders show. The chest is visible as a plane, and the far arm and leg are partly hidden.
- Depth comes from overlap (near arm over torso, torso over far arm), from the one-pixel rise of the far foot, and from the darker far limbs (2.8).
- Do not flatten into profile, which loses the chest and makes armour unreadable. Do not turn to front view, which loses the facing.

### 6.6 Stance and weight
- Draw the pose as one line first: a single stroke for the spine, then a wireframe, then shapes [Sly 17].
- A fighting stance has the hips between the feet and the knees slightly bent [Sly 9]. Lean the torso a pixel forward and set the head ahead of the chest.
- Avoid symmetry. Put the weight on one leg, tilt shoulders and hips one pixel in opposite directions, and let one side carry something [Pixnote].
- Think in volumes and exaggerate what defines the character. The grid pulls everything toward straight, stiff lines [Yu 2].

### 6.7 Reading at 1x and 2x
At 1x the viewer gets three things, in this order: the silhouette, three or four value masses (head, torso, legs, weapon), and two or three accents (face, weapon highlight, one bright trim). Anything smaller than 2 px that is not an accent is invisible at 1x and noisy at 2x. Draw for 1x. Use 2x to check that the clusters are clean.

---

## 7. Layered paper-doll characters

### 7.1 The template is law
- Lock the body template before drawing gear. Every later piece must match its proportions and joints, and changing it later means redoing all gear [Soulbound].
- The classic component split is head, torso, legs, each arm, weapon and shield, drawn separately, with mock-ups made first to test that the pieces fit together [D2].
- The template file should hold [own]: the body silhouette; a shaded mannequin showing where light, base and shadow fall; the joint pivots; the anchor points; the depth slot of each section.

### 7.2 Anchor points
- Define each anchor as an exact pixel: the grip point of the near hand, the mount point on the far forearm, the neck pivot, the shoulder and hip pivots.
- Each weapon stores its own grip pixel, and each helmet stores the pixel that sits on the neck pivot. The game aligns anchor to anchor.
- Read positions off a ruler overlay; do not estimate them [Codixel].
- Fit helmets to the skull, not to the hair. Hair is a layer that a helmet replaces or hides.

### 7.3 Depth order
A gear piece that spans several depths must be cut into one sub-piece per depth: a cuirass with sleeves is a torso part, a near-arm part and a far-arm part. Recommended order for the right-facing master, back to front [own]:

1. Cloak, back panel
2. Far arm, with its sleeve or armour
3. Shield (drawn over the far forearm so that its face shows)
4. Far leg, with its boot and leg armour
5. Torso and head
6. Near leg
7. Leg clothing and boots of the near leg
8. Body armour, torso part
9. Helmet or hair
10. Cloak collar or clasp
11. Weapon
12. Near arm and hand, with its sleeve or armour (the hand covers the grip)

Notes:
- Showing the shield's face is a convention. Physically it would be mostly hidden behind the body. Decide once.
- Order can depend on facing and on the equipped weapon [Soulbound]. A two-handed grip needs its own arm sub-pieces.

### 7.4 Consistent light across separately drawn pieces
- Draw every piece on top of the shaded mannequin and copy its light map before adding material. A piece drawn alone will drift.
- Use the same slot meanings everywhere (7.6).
- Layers cannot shade each other, so build the overlap in [own]:
  - each upper piece ends in a dark lower or back edge, which stands in for its cast shadow (4.5)
  - each upper piece starts with a light upper edge
  - lower layers are pre-shaded for what usually covers them: the neck and upper thighs are darker than open skin
- Check that all parts share one light direction and that parts meant to touch do touch [Codixel].

### 7.5 What mirroring does
- It flips the light. This is harmless only if the light is mostly from above or is defined relative to the character (2.1) [Kenney, Yu].
- It swaps hands. The right-facing figure holds the weapon in the right hand; the mirrored figure appears left-handed. Accept this and design nothing that depends on handedness.
- It reverses asymmetric details: a scabbard side, a shoulder guard on one side, lettering, heraldry. Keep devices symmetric or abstract.
- It moves the anchors. Mirror them with the sprite.

### 7.6 Keeping pieces recolourable
- Draw each piece in slots, not colours: `0` contour, `1` deep shadow, `2` shadow, `3` base, `4` light, `5` highlight. A material is a table of six colours.
- When recolouring, keep the relative value steps [Swap]. The material's character lives in the table: steel spreads the slots wide, cloth packs them close and sets slot 5 equal to slot 4 (Section 5 table).
- Use slot 5 only where a matte material would also be at its lightest. Then collapsing it does no harm [own].
- Outline and any AA tone must be slots of the same material, so that they recolour with it.
- A piece made of two materials (plate with leather straps) uses two independent slot groups. A colour shared between the groups cannot be recoloured separately [Swap].
- Leave material-specific texture (wood grain, weave, scratches) out of the shared drawing, or keep two masters per piece: a hard one for steel, bronze, copper and boiled leather, and a soft one for cloth, soft leather and fur. Highlight shapes differ too much between those families for one drawing to serve both well [own].
- Test every piece in its highest-contrast and its lowest-contrast material, and on the floor tile [Swap].

---

## 8. Item pictures

A 32×96 sword or a 64×96 cuirass has room for what the figure cannot show: 5–6 tones per material, inner anti-aliasing on long curves, bevels, wear.

### 8.1 Silhouette
- Reduce the object to its most recognisable form [Sly 24]. The type must be clear from the outline alone: blade taper, guard shape, pommel, axe beard, the waist and arm openings of a cuirass.
- Fill the long axis of the canvas. Keep one viewing angle and one scale logic across the whole set, so that the items feel like one world [Sly 24].
- Know the anatomy of what is drawn. A sword is pommel, grip, guard, blade with fuller or ridge, and point [S11: Swords].

### 8.2 Planes and bevels
- A blade is two long planes meeting at a ridge or fuller. Light one plane and shade the other. Do not run a gradient across both.
- Every edge facing the light gets a lighter line one pixel wide. Every edge facing away gets a darker one. This is what gives plate, rims and guards their thickness.
- Change the value along the length as well: a long surface in one tone from end to end is a stripe. Darken it toward the end away from the light and break it with one or two reflection bands [own, following 1.6].

```
022143350    blade, 9 px wide: 0 outline, 2 shade plane,
022143350    1 dark band beside the ridge, 4 ridge,
022143550    3 lit plane, 5 bright edge.
022155550    A diagonal shine band 2 px thick crosses it,
022155350    brightest on the lit plane and one step
022453350    weaker on the shade plane.
023343350
033143350
022143350
```

### 8.3 Edge highlights and shine
- A shine is a diagonal band that crosses the surface. In its simplest form it is a single bright stripe [S11: Shine].
- For easy reflections, draw several lines of light and shadow [S11: Metal].
- Put the brightest highlight where two lit planes meet, and at the focal point of the item: the blade near the guard, the centre of the breastplate.
- A gem needs the full run: point highlight, highlight, midtone, shadow, deep shadow. Each facet is lit as a whole, and the bright parts stay small [S11: Gems, Codixel].

### 8.4 Wear and damage
- Hand-placed irregularity is what stops a surface looking like plastic [Tsugumo 3].
- Use three to five marks per item, and put them where use would put them: nicks along the working edge, scratches across the widest plane, dark wear on the grip, a dent on the boss, a patch or cut in cloth [Kenney].
- Keep marks in clusters of two pixels or more, one step from the surrounding tone, and leave large areas untouched.

### 8.5 Making it look valuable
- Contrast and saturation signal worth. Give the best items the widest value span, the cleanest large planes, and one saturated accent such as a gem or gilding.
- Concentrate ornament in one zone (guard and pommel, collar and rim) and keep the rest calm. Texture in selected areas reads as richness; uniform texture reads as noise [Sly 2].
- Poor items get a narrower span, duller highlights and more wear. Tiers should be distinguishable in greyscale.
- Over-rendering is a risk: many soft gradients make a hand-placed item look like a shrunken 3D render. Diablo II's art was built and rendered in 3D software [D2], and the lesson to take from it is dark mood and strong speculars, not smoothness.

### 8.6 Consistent light and edges
- One light for all items (2.1). One outline rule for all items.
- On a dark inventory slot a dark outline does nothing (3.8). Light edges must carry the shape.
- Draw first with a few large, bold groups of tone that capture the overall contrast, then refine. Stop when the eye can fill in the rest. Outline last [Sly 57].

---

## 9. Animation for small sprites

### 9.1 Timing and spacing come first
- Nothing moves at constant speed. Linear motion looks dull [S11: Easings]. The distance moved per frame is what conveys acceleration.
- Slow in and slow out for ordinary moves. For attacks, back in and back out: a small move the wrong way first (anticipation) and a small pass beyond the target (overshoot) [S11: Easings].
- For fast, strong moves, delete the middle frames and jump from wind-up to full extension [S11: Impact, Easings]. Too many in-betweens make motion sluggish [Sly 8].
- Offsets must be whole pixels, so write the table by hand instead of rounding a curve [own]:

| Move | Position per tick, in px |
|---|---|
| Ease out, 8 px | 3, 5, 7, 8 |
| Ease in and out, 8 px | 1, 2, 4, 6, 7, 8 |
| Lunge of 6 px with anticipation and overshoot | −1, −2, −2, 5, 7, 6 |

### 9.2 Arcs
Limbs turn about joints, so hands and weapon tips travel on arcs. Plot the tip's path as a clean arc with regular steps (1.4). A sword cut covering about 90°, from overhead to straight ahead, is a readable default; wide arcs read as slow and powerful, short arcs as fast and light [Sly 9].

### 9.3 The parts of an action
An impact has five parts: idle, anticipation, motion, overshoot, rest [S11: Impact].

- **Anticipation** makes the motion feel stronger. It moves opposite to the action [S11: Squash]. Real-time games often skip it on player attacks to avoid a feeling of input lag [S11: Attack]; a turn-based game has no such cost, so use it [own].
- **Freeze:** hold one frame just before or at the impact. Keep it short and reserve it for big hits [S11: Impact, Sly 9].
- **Motion:** one or two frames, with a smear (9.8).
- **Overshoot:** one frame past the rest pose, then settle. The faster the move, the bigger the overshoot; one pixel for one frame is often enough [Sly 9]. The last frame of a recovery can bounce slightly past the idle position [S11: Attack].
- **Recovery** is the longest and slowest part [S11: Swords]. Holding the follow-through gives a weapon weight [Sly 9].
- **The target** must react: bounce, flash, shake [S11: Impact].

Reference timings [OM-s; treat as starting points]: anticipation 120 ms, swing 50 + 50 ms, impact hold 100 ms, recovery 80 ms. Typical frame lengths: idle 200–300 ms, walk 100–150 ms, attack wind-up 100–150 ms, fastest action frames 50–80 ms.

### 9.4 Idle
- The minimum is two frames: body down one pixel with arms slightly out and knees bent, then body up one pixel with arms down. The mass must stay the same [S11: Idle].
- A third frame slows the fall and lets the head arrive late [S11: Idle].
- Vertical motion alone is boring. Add a small horizontal counter-move [S11: Idle].
- With sections moved in code: move the torso first, the head one tick later, hair and cloak one tick after that. The contents follow the silhouette [S11: Idle].

### 9.5 Follow-through, squash and stretch
- Cloaks and hair lag behind the body and settle after it stops. Cloth in wind moves as a sine wave travelling away from the wind [S11: Fabric].
- Squash and stretch preserve mass: wider means shorter [S11: Squash]. Stiff things barely deform [S11: Squash], and metal does not stretch at all, though its parts can move separately [S11: Metal]. For armoured figures, express squash as a one-pixel crouch.
- A block should show contact without damage: small movement, long recovery, a shine passing over the armour or shield, and a rounded burst in place of shrapnel [S11: Defend].

### 9.6 Walking, when needed
- Four frames are enough: contact, passing, contact, passing. The body is lowest on contact and highest on passing [OM-s, Pixnote]. Six frames suit most cases [Sly 8]. Fewer strong frames beat many weak ones [OM-s].
- Feet must not slide. Frame time = stride length ÷ speed ÷ frames per stride [OM-p]. For tile movement, make one tile two strides of 16 px [own].

### 9.7 Sub-pixel animation (for the rare drawn frames)
Movement of less than a pixel is faked by changing colours while the outline stays put. It is animated anti-aliasing [2DWND, S11: Subpixel].

- Move the light and keep the shape. The silhouette barely changes [S11: Subpixel].
- Move part of the object first, or move the interior a frame before or after the silhouette [S11: Subpixel].
- Too many steps make the object look bent. Too many colours make it blurry [S11: Subpixel].
- Use it for breathing, cloth, a turning head, a blink [OM-p].

```
a bright edge moving one pixel right in three frames
frame 1   2533
frame 2   2443
frame 3   2353
```

### 9.8 Smears
- A smear is a blurred in-between that connects one pose to the next [S11: Motion Blur]. One is usually enough. Smears "should always be few and fast" [Sly 9].
- For a weapon, draw a crescent along the arc: thick and bright at the leading edge, thinning toward the tail.
- Lighter colours bleed over darker ones. Darker colours are used for the fading tail [S11: Motion Blur].
- For the fastest moves, one frame flashed in the complementary colour adds snap [S11: Motion Blur].
- Stretching the arm or weapon slightly at full extension adds reach [Sly 9].

### 9.9 Animation and effects made in code

The motion in this game comes mostly from code. One inspected game drew everything in code on a canvas: sprites typed as text grids, one human template with separate weapon sprites, sprites rotated in code, and skill animations drawn as code effects, with no image files and no drawn frame sequences [reported by the agent that commissioned this document, from its own inspection; not verified here]. Code-driven motion needs its own discipline to stay pixel art.

**Moving parts**
- Draw at whole-pixel positions only. Keep fractional positions for the motion calculation, round once with one method, and draw at the rounded value. Fractions rounded inconsistently make a sprite jitter [OM-p].
- Step poses at a fixed tick, about 50–100 ms, not on every screen frame. Frame times under about 50 ms are flagged as too short for sprite animation [OM-p]. Plain translation, such as sliding between tiles, may run every frame.
- One pixel density everywhere: sprites, effects and UI. Whole-number scaling with nearest-neighbour filtering, and no fractional zoom [OM-p, OM-s]. Check filter and pixel-snap settings against the engine's own documentation.

**Rotating parts**
- Rotating a small sprite by anything other than 90° resamples it off the grid. Straight edges get irregular steps, one-pixel lines break or double, single-pixel details vanish, and with smoothing turned on new colours appear [OM-p, Wiki]. "Scaling and rotating pixel art should always be avoided"; done properly, it means redrawing [S11: Resizing]. "Avoid rotation and scaling when possible" [S11: Modular].
- The damage is worst on long thin shapes (blades, shafts) and on anything under about 24 px [game-assets, via the skills catalogue].
- Usual fixes, best first:
  1. **Pre-draw the angles.** Draw the part at 0°, about 27° (a 2:1 slope) and 45°. Flips and 90° turns of those three give sixteen directions with clean, regular edges, because those slopes are the regular lines of 1.4 [own]. One source recommends hand-drawing every 45° [OM-p].
  2. **Allow only 90° turns and flips** [OM-p].
  3. **Rotate large, then reduce.** Rotate at a multiple of the size, shrink with nearest-neighbour, then repair by hand [OM-p]. RotSprite does this at 8× and adds no new colours [Wiki]. For small sprites, another route is to rig at full size and convert every frame to pixels afterward [Codixel].
  4. **Hide it.** Rotate freely only where a smear covers the result, or on particles and projectiles of a few pixels [OM-p]. Put joints behind solid parts, and use a different material at the joint [S11: Modular].
- Baked light turns with the sprite. Shade parts that rotate so that they survive it: a highlight along the centre ridge, not along one edge. Otherwise redraw the highlight for each pre-drawn angle; reflections on metal should change with the angle [S11: Metal, own].
- Prefer moving a section and swapping to a pre-drawn pose over rotating it.

**Effect design**
- Phases:
  - **Anticipation:** a gather or a tell. A beam shows thin warning lines before the bright beam [Codixel].
  - **Impact frame:** one tick of maximum contrast, such as a white or complementary flash [S11: Defend, Motion Blur].
  - **Follow-through:** a ring, debris or smoke that continues the motion. An explosion gathers, flashes, rings, then rises and thins [Codixel].
  - **Fade:** over several frames, by shrinking and stepping down the ramp. Never stop dead, and never slow to a stop and restart [Codixel].
- Use few particles [Codixel]. Things affected by gravity, smoke puffs and debris sell an impact [S11: Impact].
- Keep the brightest core small and put the darkest colour at edges and tips. Smoke has no bright core: it starts as a thin stream, curls, spreads and fades [Codixel].
- Take colours from the game palette, 3–5 per effect, with a ramp ending in near-white for the hottest part [Codixel]. Fade by ramp step. If transparency is used, use two or three fixed levels, never a smooth fade [OM-s, Codixel].
- Draw particles as whole pixels or 2×2 blocks on the sprite's grid. No glow filters, no blur, no smooth scaling.
- Rounded shapes read as "blocked, no damage". Shrapnel reads as "broken" [S11: Defend].

**Timing in frames**
- At 60 screen frames per second, one 50 ms tick is 3 screen frames.
- A basic hit [own, consistent with 9.3]: wind-up 2–3 ticks, hold 1, strike 1 with the smear, impact flash 1 on the target with a knock-back of 1–2 px, sparks 3–4 ticks, recovery 4–6 ticks. That is about 600 ms in total.
- A camera shake of 2 px for about 100 ms is enough [OM-s].
- Compute speed before rendering: pixels per frame = real speed × seconds per frame ÷ metres per pixel. "Too fast" is the most common mistake [Codixel].
- A surface texture moving more than 1 px per frame boils. A calm area where more than about a fifth of the pixels change per frame is too fast [Codixel].
- Loops must close: a whole number of cycles per loop [Codixel].
- Useful real rates: flames flicker about ten times a second, smoke rises 1–3 m/s and slows, branches sway every 1–3 s [Codixel].

**Working method for effects**
- Make 5–10 rough variants, render each as a short clip, pick the one that is clearly the right direction, then refine motion and timing. The owner sets the quality bar. Do not ship the first version [SF].
- Review motion on a numbered frame sheet, with the last frame beside the first. A still viewer shows only the first frame of an animation [Codixel].
- Change one number at a time. When told "too much" or "too little", correct by about half [Codixel].

---

## 10. Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Pillow shading | Lightest in the middle, dark all round, cannot point to the light | Shade by planes from one light (2.3) |
| Banding | Parallel stripes of equal width; a tone tracing the outline | Unequal bands, shifted ends, fewer bands (1.6) |
| Timid contrast | Greyscale view turns into one grey; neighbouring steps under about 10 lightness points apart | Fewer tones, wider steps, use both ends of the ramp (3.4) |
| Straight ramps | Shadows look like the base colour plus black | Hue-shift, saturation peak in the middle (3.2, 3.3) |
| Too many near-identical colours | Sprite looks soft; colour count climbs | Merge them; 3–5 tones per material |
| Orphans and noise | Lone pixels, speckle | Join to a cluster or delete (1.3) |
| Jaggies | Bumps in a line; runs like 2, 1, 3 | Regular steps, monotonic curves (1.4) |
| Outer AA and halos | Fringe on a different background or layer | Hard outer edges, no semi-transparency (1.5) |
| Dither on small sprites | Checker pattern as large as the features | Flat bands or one more tone (1.8) |
| Everything is the same material | Greyscale view cannot tell steel from cloth | Change span and highlight per material (Section 5) |
| No cast shadows | Parts look pasted on | Add hard shadow bands under overhangs (2.9) |
| Highlight on the outline | Bright pixels along the silhouette | Move the highlight inward, toward the light |
| White highlights on matte | Cloth or wood looks wet or plastic | Cap matte lights; white is for metal and gems |
| Black shadows | Holes in the sprite | Tinted darks, visible reflected light |
| Even detail everywhere | Nothing draws the eye | Concentrate detail, leave rest areas (8.5) |
| Smooth gradients | Looks like a shrunken render | Flat planes, hard steps, hand-placed breakup |
| Double outlines between layers | 2 px dark seams | Edge rules for stacked gear (4.5) |
| Light drifts between pieces | Helmet lit from the left, cuirass from the right | Draw on the shaded mannequin (7.4) |
| Thin limbs | Arms 1–2 px wide and unshaded | Minimum 3 px where form must show |
| Stiff, symmetric stance | Figure looks like a mannequin | Line of action, uneven weight (6.6) |
| Sprite sinks into the floor | Disappears at 1x on the tile | Raise base values, light the top edges (3.8) |
| Unintended squares | 2×2 and 3×3 blocks of one tone | Brick offsets (1.3) |
| Rotation mush | Wobbly edges on a turned weapon | Pre-drawn angles (9.9) |
| Linear motion | Parts slide like sliders | Eased offset tables, overshoot (9.1) |
| Fixing by adding | Each pass adds detail and the sprite gets worse | Go back to values and silhouette. Know when to stop [Yu] |

---

## 11. Review checklist

Run on every draft, top to bottom. Fix the first failure before looking further. Items marked (lint) can be checked by script.

1. **Reads at 1x on the real floor tile.** Type, facing and weapon are clear. Check both facings.
2. **Silhouette.** Filled with one colour it is still recognisable. No protrusion under 2 px (lint).
3. **Values.** In greyscale there are three or four distinct masses. The lightest and darkest tones are both used and meet at the focal point. No tone covers more than half of a material (lint).
4. **Separation from the floor.** At least half of the outer edge is lighter than the floor (lint).
5. **Light.** Each piece is lit from the declared direction. Top planes are lightest, with falloff toward the feet.
6. **Form.** Every part 3 px or wider shows at least shadow, base and light. Cast shadows are present under every overhang.
7. **Materials.** Each material is identifiable in greyscale by its span and highlight. Speculars appear only on glossy materials.
8. **Colour.** Ramps are hue-shifted. No shadow is neutral grey or black. Saturated accents sit at focal points only. Colour count is within budget (lint).
9. **Outlines.** One scheme is used. Lit edges are lightened or open. No double seams between layers. Contact points are open.
10. **Clusters.** No orphans (lint), no banding, no unintended squares, no jaggies, no semi-transparent pixels (lint).
11. **Layer fit.** Anchors are correct. Hard gear sits proud of the body. Each depth slot has its own sub-piece. The piece works with neighbouring layers present and absent.
12. **Recolour.** The piece looks right in the highest-contrast and lowest-contrast material.
13. **Detail and wear.** There are three to five marks, clustered, with rest areas left alone.
14. **Regression.** Beside the previous version, nothing good has been lost [Codixel]. Beside a finished sprite from the same set, it belongs.

---

## 12. Drawing order for one sprite

Each stage must pass its check before the next begins. Look at the rendered result after every stage; never report a stage as done unseen [Codixel].

1. **Brief.** Write down what the piece is, its materials, the light direction, the canvas, the anchors and the depth slot. Collect one main reference and a few supporting ones [Sly 57].
2. **Drafts.** Make three to five rough silhouettes in one colour on the template. Pick the one that reads best at 1x. Several rough attempts beat polishing the first idea [SF].
3. **Silhouette.** Clean the chosen shape: line rules, minimum thickness, clean corners. Check 1 and 2 of Section 11.
4. **Planes in three values.** Block in light, base and shadow as a few large groups that capture the overall contrast, with cast shadows included [Sly 57]. Work in grey or in the base ramp. Check 3 to 5.
5. **Form.** Add the core shadow, reflected light and the final shape of the terminator. Make the bands uneven. Check 6.
6. **Colour.** Assign material slots and ramps. Check hue shift and floor separation.
7. **Material pass.** Set the span and highlight shape for each material, then add texture marks. Check 7.
8. **Outline pass.** Apply the outline scheme, the edge rules for stacked layers, and inner lines only where needed. Outline comes after shading [Sly 57].
9. **Accents and wear.** Add the few details the budget allows: specular, rivets, nicks, trim.
10. **Cleanup.** Remove orphans, jaggies, banding and squares. Add AA only where still needed.
11. **Final checks.** View at 1x and 2x, both facings, on the floor, with other layers, in extreme materials, in greyscale and flipped [Yu]. Run the lints.
12. **Stop.** When the checklist passes, stop. Extra passes after that point usually cost more than they add [Yu, Sly 47]. Come back later with fresh eyes if it still feels wrong.

When a correction is asked for, change only the thing named, by a measured amount, and show it again beside the previous version [Codixel].

---

## Sources

**How the sources were read.** Text pages were read through a fetch tool that returns a summary of the page, so quoted phrases from text pages are as relayed by that tool. The Saint11 tutorials and four Slynyrd tutorial images were read directly as images. Saint11's tutorials are animated; only the first frame of each was read, and some panels are blank in that frame.

### Read

| Tag | Source | URL | Used for |
|---|---|---|---|
| [Yu], [Yu 2] | Derek Yu, "Pixel Art Tutorial": Basics and Common Mistakes | https://www.derekyu.com/makegames/pixelart.html and https://www.derekyu.com/makegames/pixelart2.html | Process order, light above and in front, sel-out, small-sprite compromises, flip and desaturate checks, thick limbs, knowing when to stop |
| [Cure] | Cure, "The Pixel Art Tutorial" (Pixel Joint forum) | https://pixeljoint.com/forum/forum_posts.asp?TID=11299 | Clusters, AA, jaggies, banding types, pillow shading, dithering limits, ramps and shared colours, the case against sel-out |
| [Sly n] | Raymond Schlitter (Slynyrd), Pixelblog 1, 2, 5, 6, 8, 9, 17, 24, 47, 57 (16 read, not used) | https://www.slynyrd.com/pixelblog-catalogue | Ramp construction (1), texture and detail balance (2), clusters (5), lighting tips (6), key frames and frame counts (8), attack phases and smears (9), proportions and head (17), items (24), missing information (47), armour process (57). Most of the teaching is in images; images were read for 1, 6 and 17 only |
| [S11: …] | Pedro Medeiros (Saint11), pixel art tutorials: Metal, Outlines, Shading, <1 Pixel Movement, Swords, Wood, Fundamentals 1 and 2, Character Design 1 (silhouette), Modular Animation, Squash and Stretch, Motion Blur, Animation Easing, Impact, Fabric/Flags, Rock Formations, Skulls and Bones, Portraits, Character Idle, Darkness, Attack Anim, Resizing, Animation Planning, Shine, Gems, Defend | https://saint11.art/blog/pixel-art-tutorials/ | Materials, outlines, shading terms, silhouette, darkness, all animation principles, rotation and resizing |
| [Lospec O1], [Lospec O2] | Skeddles, "Pixel Art Outlines" parts 1 and 2 | https://lospec.com/articles/pixel-art-outlines and https://lospec.com/articles/pixel-art-outlines-part-2-using-color | Line rules, where to outline, coloured and selective outlines, inner lines |
| — | Lospec tutorial collection (index page) | https://lospec.com/pixel-art-tutorials | Locating sources. Only the first ten of 586 entries were visible |
| [Apollo] | AdamCYounis, Apollo palette (Lospec) | https://lospec.com/palette-list/apollo | Example ramps. The hue and lightness figures were calculated from the hex values for this document; the page has no author description |
| [Parmesan] | Pixel Parmesan, "Anti-Aliasing Fundamentals for Pixel Artists" (author not named on the page) | https://pixelparmesan.com/anti-aliasing-fundamentals-for-pixel-artists | AA rules, banding as parallel tangents, broken lines, sel-out as form |
| [Tsugumo n] | Tsugumo, "So You Want To Be A Pixel Artist?", chapters 1–6 and FAQ (mirror) | https://web.cs.wpi.edu/~claypool/courses/frontiers-06/samples/pixel-artist/chapter3.htm (and chapter1–6, faq) | Gradients look like plastic (3), tinted shadows and "lighter is closer" (5), floors recede (6). The tutorial is mostly about tiles; its sprite section is unfinished |
| [eishiya] | Pixel Joint forum thread on rendering metal | https://pixeljoint.com/forum/printer_friendly_posts.asp?TID=26155 | Metal as reflection bands, no dither, form before shine |
| — | Pixel Joint forum thread on banding | https://pixeljoint.com/forum/forum_posts.asp?TID=11303 | Definition of banding; pointer to Helm's Ramblethread |
| [Pixnote] | Pixnote, "Shading & Lighting" and "How to Draw Pixel Art Characters" | https://pixnote.net/en/learn/shading and https://pixnote.net/en/learn/character | Tones by sprite size, measurements on 16×16 assets, eye sizes, head ratios, pillow-shading test. A tool vendor's guide, not a classic source |
| [2DWND] | Kiwi, "Give your sprites depth with sub-pixel animation" | http://2dwillneverdie.com/tutorial/give-your-sprites-depth-with-sub-pixel-animation/ | Sub-pixel animation |
| [D2] | Erich Schaefer, "Postmortem: Blizzard's Diablo II" (mirror) | https://www.cs.hmc.edu/~markk/SWE_copies/postmortem__diablo_ii.html | Component characters, paper-doll mock-ups, 3D-rendered art |
| [Stoneshard] | Stoneshard development update 33, "Art Rework" (repost) | http://www.gamebanshee.com/k448y | Worn and decayed over new and shiny. It says nothing on technique |
| [Soulbound] | "How We Built A Pixel Art Character and Cosmetic System" | https://soulbound.game/news/how-we-built-a-pixel-art-character-and-cosmetic-system/ | Locking the base, order depending on facing and weapon |
| [Swap] | "Palette Swapping for Game Sprites" | https://pixelpaletteswap.pages.dev/guides/palette-swapping-for-game-sprites.html | Independent ramps, keeping value steps, testing in context |
| [Kenney] | Kenney, "Improving 2D vector art" | https://kenney.nl/knowledge-base/learning/improving-2d-vector-art | Top light for flipped sprites, wear on fabric |
| [Wiki] | Wikipedia, "Pixel-art scaling algorithms" | https://en.wikipedia.org/wiki/Pixel-art_scaling_algorithms | RotSprite, why rotation damages pixel art |
| [SF] | Hugo Duprez, "How to make (good) pixel art effects with Claude", 28 Oct 2026 | https://www.spritefusion.com/blog/how-to-make-good-pixel-art-effects-with-claude | Draft, pick, refine workflow. It gives no technical rules |
| [Codixel] | mankidev/codixel: README.md and SKILL.md (`core/pixel.js` not read) | https://github.com/mankidev/codixel | Effect design, speed checks, verification habits, band-edge dither, rig before outline. It is a tool's instruction file, so its rules are one author's practice |
| — | "Pixel art skills for Claude Code" (catalogue) | https://skillselion.com/guides/pixel-art-skills-claude-code-guide | Locating the skills below; the game-assets rule "no rotation below 24×24" comes from this page's summary only |
| [OM-s] | omer-metin/skills-for-antigravity, `pixel-art-sprites`: SKILL.md, patterns.md, sharp_edges.md, validations.md | https://github.com/omer-metin/skills-for-antigravity | Frame budgets and timings, palette budgets, scaling |
| [OM-p] | Same repository, `pixel-art`: SKILL.md, patterns.md, sharp_edges.md, validations.md | https://github.com/omer-metin/skills-for-antigravity | Rotation, whole-pixel positions, AA lengths, dither limits, foot sliding |
| — | Tuts+, "How to Make Pixel Characters" | https://design.tutsplus.com/tutorials/how-to-make-pixel-characters--cms-26263 | Cross-check on limb widths |
| — | 80.lv, article on Pixel Logic | https://80.lv/articles/pixel-logic-a-pixel-art-tutorial-book/ | Chapter list of Pixel Logic only |
| — | Minor, read and consulted, nothing unique taken: Wintermute Digital "22 Byte-Sized Pixel Art Tips"; Barbarian Meets Coding pixel art notes; PixelPad Pro "pixel art mistakes"; SetSideB on scaling and rotation | https://wintermutedigital.netlify.app/post/22pixelartips ; http://www.barbarianmeetscoding.com/notes/pixel-art/ ; https://pixelpadpro.pages.dev/pixel-art-mistakes.html ; https://setsideb.com/lets-learn-about-pixel-scaling-and-rotation/ | Cross-checks |

### Found but not read (unverified)

- **Michael Azzi (Michafrar), "Pixel Logic"** (https://gumroad.com/l/pixel-logic). A paid book. Only its chapter list was seen: line art, anti-aliasing, colours, readability, dithering, game perspectives, clean-up, subpixeling, animation. Nothing in this document is taken from it.
- **Arne Niklas Jansson's tutorials** (https://androidarts.com/art_tut.htm, https://androidarts.com/pixtut/pixelart.htm). The host could not be reached in four attempts and the web archive was not accessible. Nothing is attributed to them.
- **Pedro Medeiros, "How to start making pixel art"** (Medium, Pixel Grimoire; for example https://medium.com/pixel-grimoire/how-to-start-making-pixel-art-4-f57f51dcfa02). Access refused. The same author's image tutorials were read.
- **AdamCYounis, MortMort, Brandon James Greer.** No usable text summary of their videos was found in several searches. Only the Apollo palette values were used.
- **Reddit thread "Claude's pixel art is so good"** (https://www.reddit.com/r/ClaudeAI/comments/1wzq2l6/claudes_pixel_art_is_so_good/). The fetch tool cannot read Reddit. The description of a game from that thread in 9.9 is a finding of the agent that commissioned this document, passed on as reported.
- **Helm's "Ramblethread"** on clusters and banding (http://www.pixel.schlet.net/). The host no longer resolves. Banding definitions here come from Cure and Pixel Parmesan.
- Access refused for all of these:
  - Liberated Pixel Cup style guide (https://lpc.opengameart.org/static/lpc-style-guide/styleguide.html)
  - OpenGameArt pixel art tutorial, chapters 4 and 7 (https://opengameart.org/content/chapter-4-shadow-and-light, https://opengameart.org/content/chapter-7-textures-and-dithering)
  - gamedev.net "Color Palettes" (https://gamedev.net/articles/visual-arts/color-palettes-r4964/)
  - "Eight Ways to Improve Your Pixel Art Characters" (https://www.moddb.com/games/innkeep/tutorials/eight-ways-to-improve-your-pixel-art-characters)
- **Advice on painting gold** (5.3) was seen only as a search-result summary of a general digital-painting article (https://www.creativebloq.com/art/digital-art/how-to-paint-fabric-and-metal-textures-that-bring-clothing-to-life-in-digital-art).
- Engine-specific setting values listed in [OM-p] were not checked, and one of them (a Godot texture-filter number) looks wrong. Verify against engine documentation.

### Where sources disagree

- **Light direction.** Upper left as the default [Pixnote, OM-s]; above and slightly in front [Yu]; directly above for sprites that will be flipped [Kenney]. This document recommends above and slightly in front for figures.
- **Selective outlining.** Cure treats sel-out as a form of bad anti-aliasing that works only on predictable backgrounds and prefers a full outline varied by light. Derek Yu, Saint11 and the Lospec articles teach it as standard. Pixel Parmesan warns that it is often used without purpose.
- **How much hue shift.** Up to 20° per step [Sly 1]; 10–20° [OM-p]; measured 16×16 assets shift 8° or more in only 2% of colour pairs [Pixnote].
- **Saturation in shadows.** "Raise it slightly" [Pixnote, whose own measurements show a small median drop]; a curve that peaks mid-ramp and falls at both ends [Sly 1]; another set of notes says darker means less saturated. Section 3.3 reconciles them.
- **Hue direction on metal.** The general rule is cool shadows and warm lights. Saint11's metal tutorial gives the reverse.
- **Anti-aliasing.** A normal tool to be used sparingly [Cure, Yu, Parmesan] against "usually a mistake" [OM-s].
- **Dithering.** From "sparingly, some artists avoid it" [Yu] to "useful for texture" [S11] to "thin strips at band edges only" [Codixel].
- **Anticipation on attacks.** It strengthens motion [S11: Impact, Easings], but should be left off player attacks in real-time games [S11: Attack]. The second point does not apply to turn-based play.
- **Rotation.** Never, except in 90° steps [OM-p]; not below 24 px [game-assets]; rig and rotate at full size, then convert each frame [Codixel]; the inspected game described in 9.9 rotates its text-grid sprites in code.
- **Frame counts.** Idle 2–6 frames and walk 4–8 across sources. All agree that fewer, stronger frames are better.
- **Outline colour.** Black as the safe default [Pixnote, commenters on Lospec] against coloured outlines [Yu, S11, Lospec O2].
