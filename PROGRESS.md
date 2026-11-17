# Progress

Last updated: 2026-11-17

This is the status file: what is done, what is next, what is waiting on Ákos. It was
called `CURRENT_WORK.md` until Phase 1. The plan it tracks is in section 7 of
`docs/ASSESSMENT_AND_PLAN_2026-11.md`; `CHANGELOG.md` has the detail of each phase.

## Where things stand

| Phase | Status |
|---|---|
| 0. Truthful baseline | Done. Committed on `phase-0-truthful-baseline` |
| 1. Game shell and state | Done. Committed on `phase-1-game-shell`, which builds on Phase 0. Ákos has played it a little; no complaints given yet |
| 2. Combat core | In progress on `phase-2-combat-core`. Go given 2026-11-17. Steps below |

- Phases 0 and 1 were pushed to origin on 2026-11-17. Nothing is merged into
  `main`; `main` is still the June commit. The durability design commits on
  `phase-1-game-shell` after that push, and all of `phase-2-combat-core`, are
  local only.
- `tools\run_checks.bat` passes at the step 3 merge on `phase-2-combat-core`: 326
  smoke checks, no engine errors, 31 screenshots.
- Standing agreement since 2026-11-16: commit as work proceeds, on the phase branch.
  Push and merge only when Ákos asks.
- Two folders sit next to the repo since 2026-11-17. `..\elaris-worktrees\` holds
  the separate working copy for whichever Phase 2 step is being built. `..\pxl\` is
  a checkout of the drawing tool (https://github.com/uilianks/pxl). Temporary
  session folders are not used for work any more: one was withdrawn mid-run and
  stopped two background jobs.
- `art_work\bakeoff\` is untracked while the art experiment is still running in it.

## Waiting on Ákos

0. **Review `docs/GEAR_FANTASY_PROPOSAL.md`.** A proposal, nothing decided: whether
   gear, loot and maintenance become the centre of the game, at one of three levels.
   Crafting interests him; he is not sure about a full pivot. It ends with six
   questions for him. Phase 2 is the same whichever level he picks.
1. **Play the Phase 1 build:** menu, new game, save, load, die, load again. Say what
   feels wrong.
2. **Durability: done for Phase 2.** The design was settled with him on 2026-11-17
   from his homebrew system and is written up in section 8 of the plan, small items
   included. Left for later, by his choice: material traits. Left for their phases:
   climate (Phase 3) and what worn gear does socially (Phase 4).
3. **During Phase 2:** play each step's build when it lands, and give the win-rate
   band the simulator should aim for at levels 1 to 3 (needed at step 10).
3a. **Resting rules.** He wants them; a separate discussion, not started. His
   homebrew resting system has been read (see the table below).
3b. **Co-op.** Decided 2026-11-17: online with friends, four players at most, one
   per party member, not needed for the first playable. The rules that keep new
   code ready for it are in section 8 of the plan under "Co-op". No networking
   work before the first playable; he turned down an early two-player test.
4. **Merge:** whether Phases 0 and 1 go into `main`. (Both branches are on origin.)
5. `tilesets/TX Tileset Stone Ground.png` is unused and its licence is not recorded.
   Delete it?

## Phase 2 steps

Each step is committed with the checks passing and the game still playable. Scope and
exit test are in section 7 of the plan; the durability rules are in section 8.

| # | Step | Status |
|---|---|---|
| 1 | One combatant base with teams for the player, enemies and companions; one authority for whose turn it is; the combat loop out of `world.gd` | Done 2026-11-17. Built on `phase-2-step-1`, reviewed, merged. Not yet played by Ákos |
| 2 | Turn resources (movement, action, bonus action, reaction) and the action bar: Attack with the equipped weapon, Dash, Disengage, Dodge, End Turn | Done 2026-11-17. Built on `phase-2-step-2`, reviewed, merged. Not yet played by Ákos |
| 3 | Ranged attacks: range, line of sight, targeting, hit chance shown before committing | Done 2026-11-17. Built on `phase-2-step-3`, reviewed, merged. Not yet played by Ákos |
| 4 | One damage pipeline with types, resistance, vulnerability and hooks; 5e armour class; armour and material data reworked so materials add no stats; two weapon sets swapped with an action; the smaller fixes from step 3 (longbow range, cover) | Being built on branch `phase-2-step-4` by a background agent (started 2026-11-17), in the working copy at `C:\Users\Akos\Documents\GitHub\elaris-worktrees\step4`. Not yet reviewed or merged. It was interrupted once with only the material data rewritten and uncommitted. If the session that started it has ended: look at `git status` and `git log phase-2-combat-core..phase-2-step-4` in that working copy, run the checks there, finish or review, then merge |
| 5 | Durability as designed: notches, marks, blows, hardness, debuffs, buffs, field kits and scrap, ageing, the segmented bar. Also, agreed 2026-11-17: the figure on the map shows what the character is wearing, assembled from layers (the placeholder set has layers for body, legs, boots, gloves, cloak, head and both hands; none for shoulder, wrist or waist), so a broken or missing piece is visible | |
| 6 | Bestiary as data (goblin, skeleton, bandit, wolf, one boss); behaviours (rusher, archer, caster, pack); perception by line of sight; encounters by budget | |
| 7 | Companions as party combatants that enemies target, driven by the same behaviours. Settle here, by Ákos playing both, whether companions default to player control or to acting on their own (he wondered on 2026-11-17 whether anyone wants to control four characters, then left the decision as it stands; my lean is AI by default because fights are frequent and small) | |
| 8 | Readability: movement range, valid targets, status icons, a working turn-order bar, faster enemy turns | |
| 9 | `AStarGrid2D` pathfinding; an input map with rebindable actions | |
| 10 | Headless combat simulator; tune the durability dials and encounter budgets against the run target | |

## Art track

Runs beside Phase 2 since 2026-11-17. The decisions and the method are in section 8
of the plan under "Own art: how it gets made"; this is only where things stand.

- **Style: settled.** The rendered barbarian, `art_work/barbarian/a1.px.js`. The
  final longsword is `art_work/items/longsword_final.png`.
- **Method: settled** by a bake-off (`art_work/bakeoff/`). Drawn with the `pxl`
  tool by an agent that does nothing else, applying `docs/art/PIXEL_ART_THEORY.md`
  in rounds of render, look and fix. Aseprite is not part of the pipeline.
- **Animation rig: first version finished** 2026-11-17, in `art_work/rig/`. Its
  `README.md` describes the data format and how to add gear or an animation. Ákos
  is shown each part when it is finished, never mid-way, and judges motion by
  watching, which the agent cannot do.
  - What exists: sixteen pieces with pivots and joint ranges (`rig.json`,
    `atlas.png`); five animations as pose data (`anims/`: idle, idle2, walk,
    walk2, swing); a preview tool with checks (no joint opens, joints inside their
    ranges, weapon length constant, planted feet still). All checks pass. The
    agent's own verdict: correct, readable pose sequences with almost no hand
    polish, not commercial quality.
  - His verdicts so far: the first idle "isn't bad", and would be better with the
    lower body moving (idle2 does that; not yet judged); the first walk was
    "choppy" and "a little silly", moving too much (walk2 halves the movement and
    uses eight frames; not yet judged); the swing on the rig not yet judged. He
    caught an elbow bending backwards, which led to the joint ranges.
  - **His open decision:** he expects a rig drawn as fully separate parts from the
    start to be better than this one, where the limbs are separate drawings but
    head, torso and hips are still slices of the standing figure. He said he would
    decide after seeing the animations. The agent's account of what that would
    change: it fixes the shoulder and hip sockets, borrowed shadows on the torso,
    thigh tops showing beside the hips, and gives a neck and hair that can lag; it
    does not fix a torso twist (that needs two or three extra drawn views in any
    rig), the rough machine-turned limbs, or any timing question. The data format,
    tools, checks, angle set, joint ranges, all eight limb parts and the five
    animation files carry over.
- Step 5 of Phase 2 puts worn gear on the map figure and will use the rig's data.

## Homebrew source document

`C:\Users\Akos\Downloads\Elaris Gameplay.md` is Ákos's tabletop supplement: 10,154
lines, 775 KB, outside the repo. It holds many systems; which of them the game needs
is to be discussed one by one. One read call cannot take the whole file, so read it
in parts by line range. Nothing prevents reading all of it.

What has been read, as of 2026-11-17:

| Lines | Section | Read |
|---|---|---|
| 1–260 | Blacksmithing: Stormfire, Deepfrost, Bloodiron, Stoneshaper, start of Dreadblack | Yes |
| 261–429 | Blacksmithing: the remaining forging techniques | No |
| 430–503 | Blacksmithing: Pyrestone Smelting, Worldforged Smiths | Yes |
| 504–3230 | Leatherworking, Tailoring, Alchemy, Craftsmanship, Cooking, Glassblowing, Jewelcrafting, Masonry, Poisoner | No |
| 3231–3290 | Metallurgy: opening only | Yes |
| 3291–3545 | Metallurgy (the rest), Woodworking | No |
| 3546–3644 | Resting System | Yes |
| 3645–6900 | Travel Pacing, Travel Roleplay, Travel D100s | No |
| 6901–7561 | Durability rules; materials tables (metal, wood, cloth, leather, stone, gems, herbs); enchantment materials; magic and masterforged gear; weapon and armour states; arrows; trinkets | Yes, in full |
| 7562–9185 | Legendary Items | No |
| 9186–9348 | Finds table, Loot D100 tables | No |
| 9349–9970 | Tea, coffee, tobacco, alcohol, sweets, drugs, diseases | No |
| 9971–10030 | Weather: the layer and exposure rules, the first regional table | Yes |
| 10031–10154 | Weather: the remaining regional tables | No |

## What exists now

- Main menu, character creation as the start of a new game (with a skill choice),
  pause menu on ESC, settings, game-over screen.
- Seeded dungeons and save format 3: a save restores the same dungeon, the living
  enemies with their wounds, ground loot, the explored map, quests and companions.
  Loading wipes all state and starts a fresh World scene. Older saves are migrated.
- Autosave on new game and zone travel; Continue loads the newest save.
- No saving in combat or after death; overwriting a slot takes a second click.
- 32-pixel grid and placeholder art for every tile, creature, companion and item,
  replaceable file by file. `docs/ART_CHECKLIST.md` is the list to draw against.
- Combat, loot, levelling, the character sheet, and the panels from the June build
  (spellbook, crafting, quest log, world map, companions, dialogue), all visible.
- Checks: `tools\run_checks.bat`.

## Next: Phase 2 - combat core

One combatant model for player, party and enemies; action, bonus action, movement and
reaction; a weapon-based action bar; ranged attacks; 5e armour class; durability wear;
a data-driven bestiary with behaviours; encounters by budget; a combat simulator for
balance. Also carried over from Phase 1: the input map (named, rebindable actions) and
pulling the combat loop out of `world.gd`. Scope and exit test are in the plan.

## Things noticed and not fixed

- Doors stand alone in open floor: corridors are five tiles wide and only one cell is
  a door (Phase 3, generation).
- The default dungeon floor is very dark and may be hard to read on a dim screen.
  Swap `assets/tiles/dungeon/floor_*.png` or pick lighter stand-ins.
- A new game starts in the "dungeon" biome although zone 1 is defined as forest
  (Phase 3).
- The player sprite follows class, not race or equipped gear. The source set has
  layered character parts that would allow it.
- The minimap does not draw decoration tiles.
- Random world events fire on every dungeon regeneration, including the debug key.

## Known and deliberately left for later

- A bow or crossbow cannot be fired with a shield in the off hand. Ákos confirmed
  the rule and decided on two weapon sets swapped with an action (step 4).
- The longbow's range is 24/96 tiles; the SRD's 150/600 feet is 30/120 (step 4,
  with the item data).
- Cover is generous: most shots down a corridor count as half cover, and the player
  now sees it in the hit chance (`scripts/combat_grid.gd`, step 8).
- No ammunition, no thrown weapons, and an adjacent enemy cannot be shot by choice
  while a melee weapon is in hand.
- The smoke log sometimes ends with a warning about two leaked timers. It depends on
  the dice and predates step 3; probably the World being freed while a turn is
  still waiting. It fails nothing.
- Equipping gear in a fight is free and works off-turn (step 4 or 5).
- Aimed scrolls and wands cannot be used at all: there is no targeting flow for
  them. Two consumables (cure poison, food buffs) do nothing but are consumed.
- A weapon's own magic or quality bonus is not applied to its attacks; only the
  item template's is read (step 4).
- Dodge ignores "you can see the attacker"; the rule that a bonus-action spell
  allows only a cantrip besides is not applied (Phase 5).
- Companions (step 7): the AI picks the nearest hostile in the whole dungeon, even
  one outside the fight; it does not attack on a turn it moves; status effects on a
  companion never tick or expire; nothing can damage one yet, and the death path
  would treat it as an enemy.
- For co-op later: WASD movement while exploring still changes position in input
  code, and the spellbook panel still reads the single player.
- The combat log names combatants by their node names ("Goblin_18", "Character")
  (step 8).
- Fights still start around the single player character; co-op will need a party
  leader instead (after the first playable).
- Area spells always include the caster; self-buffs expire a round early; spells
  aimed at an ally still resolve on the caster (Phase 2 / 5).
- Combat starts through walls (Phase 2, perception).
- The main quest stops at its second objective; no quest is completable (Phase 4).
- Dialogue rewards repeat; talk objectives complete on any dialogue end (Phase 4).
- Five dangling references are listed in `KNOWN_GAPS` in `tools/smoke_test.gd`.
