# Barbarian rig

A paper-doll figure cut into parts that hang on each other, with gear that rides on the
parts, and animations written as plain data. Nothing is turned or scaled at run time:
every part that turns is pre-drawn at a fixed set of angles, and a pose only picks one
picture per part and places it on whole pixels.

The game needs three things from this folder:

| File | What it is |
|---|---|
| `rig.json` | the parts, how they hang together, their joint ranges, the gear, the effect pictures, and where every picture is in the atlas |
| `atlas.png` | all pictures (every part and gear layer at every angle, and the effects) |
| `anims/*.json` | one file per animation: `idle`, `idle2`, `walk`, `walk2`, `swing` |

Everything else here is source and tooling (see "Sources and tools").

## Conventions

- The figure is 32 x 48 and faces right. Figure coordinates: x to the right, y down,
  (0, 0) is the top left of the 32 x 48 box, row 47 is the ground line of the near foot.
- Facing left is the whole composed figure mirrored about the line between columns 15
  and 16. The data only describes the right-facing figure.
- Angles are whole numbers from a fixed set: 0, 14, 27, 45, 63, 90, 117, 135, 153, 180
  and their negatives. They are labels for 0, atan(1/4), atan(1/2), 45, atan(2), 90 ...
  (`angle_degrees` gives the true values). Positive is clockwise on screen.
- A limb's angle 0 is hanging straight down. The sword's angle 0 is blade straight up.
  Angles in a pose are absolute (not relative to the parent), so a pose never adds
  angles up; it just names a picture.

## rig.json

```
format         "elaris-rig/1"
atlas          "atlas.png"
figure         { w, h, ground_y, facing }
angle_degrees  { "14": 14.036, "27": 26.565, ... }      true angle behind each label
pieces         [ piece, ... ]                           parents always before children
layers         [ { sprite, piece, z }, ... ]            the bare body's pictures
slots          [ "cloak", "legs", "boots", "torso_gear", "helmet", "shield", "arm_gear", "weapon" ]
gear           { id: { slot, metal, layers: [ { sprite, piece, z }, ... ] } }
materials      { "steel": [six colours], "bronze": [six colours] }
fx             { name: { sprite, origin: [x, y] } }
sprites        { "<sprite>@<angle>": { rect: [x, y, w, h], origin: [ox, oy] } }
```

A **piece** is a part of the figure that moves as one:

| Field | Meaning |
|---|---|
| `name`, `parent` | `hips` is the root (`parent` null). |
| `at` | root only: the pixel of the figure where its pivot sits at rest. |
| `rest` | its angle in the rest pose (0 for all but the far forearm, which reaches forward: -90). |
| `rest_offset` | where its pivot sits, counted from its parent's pivot, in the rest pose. |
| `angles` | the angles it has pictures for. A piece with `[0]` never turns. |
| `joints` | per angle of THIS piece: `{ child or anchor name: [dx, dy] }`, where each child's pivot (and each named point, such as `sole`, `hand`, `tip`) sits, counted from this piece's pivot. This is the only place rotation shows up, and it is a lookup, not arithmetic. |
| `range` | `[lo, hi]`: allowed values of (this piece's angle minus its parent's angle), in true degrees. See "Joint ranges". |
| `slot` | present on pieces that exist only for gear: `weapon`, `shield`, `cloak_upper`, `cloak_lower`, `skirt`. They are drawn only if that slot is filled. |

The pivot of a piece is not stored as a point in a picture; each sprite stores its
`origin`, the offset from the pivot pixel to the sprite's top-left corner. So "draw the
sprite at pivot + origin" is the whole placement rule.

The pieces: `hips` > `torso` > `head`; `torso` > `near_upper_arm` > `near_forearm` >
`weapon`; `torso` > `far_upper_arm` > `far_forearm` > `shield`; `hips` > `near_thigh` >
`near_shin`; `hips` > `far_thigh` > `far_shin`; `hips` > `skirt`; `torso` >
`cloak_upper` > `cloak_lower`. Eleven body parts, five gear-only parts.

A **layer** is one picture drawn on a piece: `sprite` is the name in `sprites` without
the `@angle`, `z` is the draw order (low first). The body's layers are in `layers`; each
gear item brings its own in `gear[id].layers`. Gear that rides a body part simply names
that part (`iron_cap__head` on `head`, `fur_boots__near_shin` on `near_shin`), and is
drawn at the same pivot with the same angle, so it turns with it. The fist is drawn
twice: with the forearm (z 72) and again over the weapon (z 82), so the hand covers
the grip.

Draw order, back to front: cloak hem 10, mantle 12, far upper arm 20, far forearm 22,
far shin 30, far thigh 32, far boot 34, torso 40, near shin 42, near thigh 44, near
boot 46, hips 48, head 50, kilt 52, belt 53, baldric 54, helmet 56, shield 60, near
upper arm 70, shoulder fur 71, near forearm 72, bracer 76, weapon 80, fist 82.

### Putting a pose together

A pose is `{ piece: { "a": angle, "dx": .., "dy": .. } }`; anything left out is at rest
(`a` = the piece's `rest`, offsets 0).

```
for piece in pieces (in file order):
    a = pose[piece].a or piece.rest
    if piece is the root:  pivot = piece.at + (dx, dy)
    else:                  pivot = pivot[parent] + parent.joints[angle of parent][piece.name] + (dx, dy)
for layer in (body layers + layers of every equipped gear item), sorted by z:
    s = sprites[layer.sprite + "@" + angle of layer.piece]
    draw atlas rect s.rect at pivot[layer.piece] + s.origin
```

`tools/riglib.py` is this, in forty lines, and is the reference reader.

### Joint ranges

`range` is what keeps a pose anatomical. Bend = a piece's angle minus its parent's.

| Joint | Range | In words |
|---|---|---|
| elbows (`near_forearm`, `far_forearm`) | -155 .. 0 | the forearm folds toward the front only, never behind the upper arm |
| knees (`near_shin`, `far_shin`) | 0 .. 150 | the shin folds back only |
| shoulders (`*_upper_arm`) | -180 .. 45 | forward and up to overhead, a little back |
| hips (`*_thigh`) | -110 .. 30 | well forward, a little back |
| wrist (`weapon`) | -30 .. 180 | from blade laid back along the arm to blade in line with the forearm |
| `shield` | 60 .. 120 | |
| `head`, `torso` | -20 .. 20 | (they have no turned pictures yet) |

The game does not have to enforce these: they are checked when animations are made
(`tools/check_limits.py`, and inside `tools/preview.py`). They are in the file so that
any later tool or procedural pose can be checked the same way. The test looks at each
joint against its own parent only; it cannot tell that an arm passes through the head.

### Recolouring and removing gear

Metal is drawn in six steel colours (`materials.steel`, dark to light). A gear item with
`metal: true` is recoloured by replacing each of those six with the same slot of another
material. Nothing else on the figure uses those six colours. Removing gear is leaving
its layers out; the body is complete under every piece.

## Animation files

```
format    "elaris-anim/1"
name
loop      true / false
canvas    { w, h, origin: [x, y] }        only for the preview tool: frame size and where figure (0, 0) goes
travel    [px, ...]                       optional, one number per frame: how far the figure moves forward
                                          during that frame (walks). Sum = distance per cycle.
planted   { "near": [[frames], ...], "far": [[frames], ...] }   which frames each foot is meant to stand still
frames    [ { ms, pieces: { piece: { a, dx, dy } }, fx: [ { name, x, y, z, needs } ] }, ... ]
```

- `ms` is how long the frame is shown.
- `pieces` is a pose as above. `dx`, `dy` are offsets from where the joint puts the
  piece. Joints overlap, so an offset of a pixel opens nothing.
- `fx` are the effect layers: `name` is a key of `fx` in `rig.json`; the picture's
  `origin` pixel is put on figure position `x`, `y`; `z` places it among the layers
  (default: on top); `needs` names a gear slot that must be filled (the sword's smear).
  The hit pictures are written here at the spot where the blade meets a target in the
  next tile; the game will more likely play them on the target itself.
- `travel`: `walk` and `walk2` cover 32 px, one tile, per cycle. If the figure is
  advanced by `travel[i]` when frame `i` ends, a planted foot stays on the same floor
  pixel. If the game slides the figure evenly instead, the foot drifts by up to one
  frame's travel and snaps back.
- `planted` is only for the checks.

## Adding things

**A piece of gear.** Draw it over the part it rides, on that part's canvas (for limbs
the small upright canvases in `rig.px.js`, for head, torso, hips, shield, weapon, cloak
the 32 x 48 figure), as a sprite named `<gear id>__<piece>`. A piece that spans several
parts is cut into one sprite per part (a cuirass with sleeves: torso, both upper arms).
Use the six steel keys `0`-`5` for metal. Add the item to `gear` in `rig.src.json` with
its slot and one layer per sprite (`piece`, `z`). Run `python tools/build.py`. The baker
turns it with the part's own map, so it cannot slip against the body.
A weapon is a sprite on the `weapon` piece, drawn upright with its grip where the
sword's is (centre 6, 29 on the 32 x 48 canvas); a thin straight crossbar can be listed
under `bars` so it is re-drawn as a regular line at every angle.

**An angle.** Add the number to the piece's `angles` in `rig.src.json` and rebuild. Look
at the result (`python tools/bake.py --review` writes sheets to `bake/review/`,
`--show sprite@angle` prints one as text) and correct single pixels in `patches.py`.

**An animation.** Either write the JSON by hand, or add a function to
`tools/make_anims.py` (it has a helper that plants a foot on a chosen pixel by picking
thigh and shin angles inside the joint ranges). Then `python tools/preview.py
anims/NAME.json` writes the GIFs and sheets to `preview/` and prints the checks;
`python tools/final_anim.py NAME` writes the `final_NAME` set.

**A body part.** Add it to `pieces` (parent, `centre` on its own canvas, `at` on the
parent's canvas, `angles`, `range`) and its sprite to `body`, then rebuild.

## Sources and tools

| File | Role |
|---|---|
| `rig.px.js` | the master drawings, for `pxl` (`../../../pxl`). Limbs are upright parts on small canvases with round caps; head, torso, hips, cloak, shield, sword are drawn in place. |
| `fx.px.js`, `fx_gen.px.js` | effect pictures; the second is written by `make_anims.py` (the smear, fitted to the swing). |
| `rig.src.json` | the hand-written rig: centres, attachment points, angle lists, ranges, draw order, gear. |
| `patches.py` | hand corrections to single turned pictures. |
| `tools/build.py` | runs everything in order and all checks; `--finals` also rewrites the `final_*` pictures. |
| `tools/bake.py` | masters -> turned variants -> `atlas.png` + `rig.json`. |
| `tools/make_anims.py`, `tools/author.py` | the hand-written animations -> `anims/*.json`, `poses.json`, `fx.json`. |
| `tools/riglib.py` | reads the rig and puts a pose together (reference reader). |
| `tools/preview.py` | one animation + gear set + material -> 4x GIF, 1x GIF, frame sheet, onion skins, trail, checks. |
| `tools/check_limits.py` | joint ranges over every test pose and every frame. |
| `tools/rest_check.py` | the rest pose against the A1 build (`ref/`), pixel by pixel. |
| `tools/final_rig.py`, `tools/final_anim.py` | the `final_*` sheets and GIFs. |
| `tools/look.py`, `zoom.py`, `pose_sheet.py`, `dump.py`, `visible.py`, `check.py` | working aids for looking closely. |

How a part is turned: all pictures on one part are laid over each other, that composite
is enlarged eight times with Scale2x, and each pixel of the turned picture looks up one
pixel of it; what is kept is which master pixel it came from, and every layer on the
part is drawn through that same map. For angles where the baked light would end up on
the wrong side (an arm raised, a blade level), the turn starts from a second master
with the shading reversed across the width and the silhouette unchanged (`__r`).

The checks `preview.py` runs on every animation: every part overlaps its parent and the
joint point is covered; every joint is inside its range; the weapon's length along its
axis at each angle used, against the rest pose; planted feet do not move (root travel
included); the weapon tip and the near hand per frame, with step lengths and turns;
the largest one-colour block. Every GIF is read back and compared with its frames.
