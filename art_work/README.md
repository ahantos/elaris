# Art work files

Source files for the game's own art. Godot ignores this folder (`.gdignore`); the
game loads only what is exported into `assets/`.

- `fighter.px.js` - the test fighter as text grids for the `pxl` tool
  (https://github.com/uilianks/pxl, MIT): nine gear layers, at 32x32 and at 32x48,
  with mirrored and recoloured variants.
- `aseprite/layers_to_aseprite.lua` - builds one layered Aseprite file from a folder
  of per-layer PNGs.

Build, with a checkout of `pxl` somewhere on disk (Node 22.18 or newer):

    node <pxl>/bin/pxl.js build art_work/fighter.px.js
    node <pxl>/bin/pxl.js lint art_work/fighter.px.js fighter_tall
    node <pxl>/bin/pxl.js serve art_work/fighter.px.js     # live viewer on 127.0.0.1:4321

Output goes to `art_work/out/`, which is not committed.

The style direction and the decisions behind it are in section 8 of
`docs/ASSESSMENT_AND_PLAN_2026-11.md` ("Own art: how it gets made"). The theory
reference is `docs/art/PIXEL_ART_THEORY.md`.
