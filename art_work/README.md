# Art work files

Source files for the game's own art. Godot ignores this folder (`.gdignore`); the
game loads only what is exported into `assets/`.

- `fighter.px.js` - the test fighter as text grids for the `pxl` tool
  (https://github.com/uilianks/pxl, MIT): nine gear layers, at 32x32 and at 32x48,
  with mirrored and recoloured variants.
- `aseprite/layers_to_aseprite.lua` - builds one layered Aseprite file from a folder
  of per-layer PNGs.

- `barbarian/` - the barbarian that set the art style (`a1.px.js`), the chunkier
  alternative that was turned down (`a2.px.js`), and their review sheets.
- `items/` - item pictures; the first is a longsword, 32x96.
- `bakeoff/` - the working folder of the method experiment.
- `local_refs/` - reference pictures that are not ours to publish; not committed.

Build with the `pxl` checkout that sits next to this repository, at `..\pxl`
(Node 22.18 or newer):

    node ../pxl/bin/pxl.js build art_work/barbarian/a1.px.js
    node ../pxl/bin/pxl.js lint art_work/barbarian/a1.px.js a1
    node ../pxl/bin/pxl.js serve art_work/barbarian/a1.px.js     # live viewer on 127.0.0.1:4321

Output goes to an `out/` folder beside the art file, which is not committed.

The style direction and the decisions behind it are in section 8 of
`docs/ASSESSMENT_AND_PLAN_2026-11.md` ("Own art: how it gets made"). The theory
reference is `docs/art/PIXEL_ART_THEORY.md`.
