# Art bake-off notes

Working notes for the method comparison of 2026-11-17. The pictures are on `bakeoff.png`;
each part also has its own `final_*.png`.

## Design reference (public domain)

John White, "A 'Warrior neighbour of the Picts'; stained body, with shield and sword",
watercolour, about 1585 to 1593, British Museum 1906,0509.1.28. Wikimedia Commons marks it
"Public domain".

- Page: https://commons.wikimedia.org/wiki/File:John_White_-_A_%27Warrior_neighbour_of_the_Picts%27;_stained_body,_with_shield_and_sword,_1906,0509.1.28.jpg
- Local copy (960 px wide): `ref_pd/white/john_white_warrior_neighbour_of_the_picts.jpg`
- Taken from it for A2: heavy build, wide stance with one foot forward, a very large sword
  carried on the shoulder as a diagonal, long hair and moustache, belted waist, round shield.
- Not taken: the face, the tunic, the body paint. A2 is our own figure.

A second public-domain picture was downloaded and not used (half figure only): Osmar
Schindler, "Germanic warrior with helmet", 1902,
https://commons.wikimedia.org/wiki/File:Germanic_warrior_with_helmet.jpg
(`ref_pd/schindler/`).

## Reference study, done before drawing A2

Sheets are in `study/`. A1 was drawn before any of this was opened.

### Dungeon Crawl Stone Soup tiles (CC0), 32 x 32

Looked at enlarged 6x and 14x: `mon/hill_giant`, `mon/cyclops`, `mon/unique/urug`,
`mon/unique/rupert`, `mon/orc_warrior`, `mon/stone_giant`, `mon/vault_guard`, and the player
doll `base/human_m` with `body/animal_skin`, `legs/loincloth_red`, `boots/middle_brown`,
`hand1/heavy_sword`, `hand2/buckler_round`, `head/helm_gimli`, `cloak/ratskin`.

What makes them work:

- **Outline.** Every edge pixel is near-black: measured 100% on all seven figures. The same
  black also separates arm from torso and leg from leg. Gear tiles carry their own full
  outline, and doubled outlines do not show because black merges with black.
- **Tone counts.** Skin has 4 or 5 tones; a whole 32 x 32 monster has 18 to 23 colours
  (Urug 34).
- **Skin is light-dominant.** On the cyclops the three lightest of five skin tones cover
  about 76% of the skin (31%, 24%, 21%); the darks cover about 15%. The darks are drawn as
  lines and wedges one or two pixels thick (under the chest, between arm and ribs, round the
  knee), not as bands along the edge.
- **Where highlights sit.** Small patches of the lightest tone on top planes: shoulders,
  top of the chest, belly, knees. Never on the outline.
- **Steel is drawn pale.** `heavy_sword` uses only #909090 to #ffffff, with a white column
  as the highlight; the black outline supplies the dark. There are no dark greys in it.
- **Cloth and hide are a dark, saturated mass** against the light skin (hill giant
  loincloth #421807 to #81300f), so materials separate by value first.
- **Hide and fur texture** (rat-skin cloak, hill giant loincloth) is a dark base with a few
  lighter vertical streaks. No checker pattern.
- **A face in few pixels.** The brow is one dark line; the eyes are one or two dark pixels
  under it; the nose is two lighter pixels; the mouth is three pixels of dark red. Nothing
  else.
- **Build.** Shoulders about twice the head width, arms held clear of the torso with a gap,
  legs a quarter to a third of the height, wide stance.

### Stoneshard store screenshots (compressed, about 3x)

- Figures: heads about 40% of the height (the owner finds this too big), a thick warm-dark
  contour, three muted tones per cloth, faces carried by large dark eyes.
- Item pictures: a blade is two planes with a crisp ridge, a light working edge and a dark
  contour; a helmet is a few large hard-edged highlight planes; leather is dark with warm
  wraps. Everything is muted except small accents.
- Used for proportion and palette only. No pixels were copied.

### `reddit/clip_frames.jpg`

The model-made variants of the wizard keep the original's silhouette, outline weight and
tone count when the original is supplied. That supports "like this, but ...".

## What the study changed in A2, compared with A1

- Full near-black contour instead of A1's contour on the shade side only.
- Light-dominant skin with dark accent lines.
- Shorter legs (16 rows instead of 20), wider torso, A-stance.
- Cloth as a dark saturated mass (the red loincloth), brass and red as the only accents.
- The pose from the John White picture.

The owner preferred A1. The study still gave two things worth keeping for later figures:
the build (short legs, arms clear of the body) and the pose taken from a real picture.

## How A1 was made (so it can be repeated)

1. Top of the file: the light direction in words, one shared near-black, four tones per
   material from the theory reference's table, the steel ramp of section 5.1 unchanged.
2. Layout by the row table in 6.1 (head rows 3 to 11, shoulders 13, crotch 27, knee 35,
   ground 47), body centred between columns 15 and 16.
3. The bare body first, as its own layer, with the dark contour on the back and underside
   only; far-side limbs one tone darker.
4. Each gear piece as its own layer over the body: one pixel proud, a dark lower and back
   edge, a light upper and front edge.
5. The blade is four pixels across: soft back edge, dark band, lit plane, bright edge;
   reflections in pairs of rows.
6. After every build: a sheet with 1x, 2x, 4x and 8x on both floors, greyscale, silhouette
   and mirror (`tools/view.py`). Fix the first failing item of the checklist only.
7. From pass 4: edit by coordinates from `pxl ascii`, and run `tools/check.py` (full list of
   stray pixels, near-duplicate colours, share of the edge lighter than each floor) until
   `pxl lint` is clean.

Passes: 1 full draft; 2 helmet raised one row so the brow shows, straight blade, darker
leather; 3 kilt shortened to show the thighs, boots lowered and darkened; 4 stray pixels
32 to 7, four near-duplicate colour pairs resolved, lit share of the edge 36% to 55% by
replacing the blade's dark contour with the soft-edge recipe; 5 cloak given a readable
tone, shield boss lit from the correct side, bronze less yellow; 6 lint clean, 23 colours.
Sheets for every pass are in `review/`.

## Two traps met on the way

- **GIF colours.** Quantising an RGBA frame gives Pillow a four-byte palette, and its GIF
  writer reads it three bytes at a time, so every colour shifts. `tools/frames.py` now
  converts to RGB first, uses one exact shared palette, and reads the GIF back and compares
  every pixel with the strip.
- **Aseprite import.** `Image{ fromFile }` returns palette indices for an indexed PNG, which
  made ten empty layers without any error. `ase/palette.lua` now opens the file as a sprite,
  converts it to RGB and reads the cel with its offset. Only a pixel comparison with the
  pxl picture caught it.
