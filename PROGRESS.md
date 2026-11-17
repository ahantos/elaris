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
- `tools\run_checks.bat` passes at the step 1 merge on `phase-2-combat-core`: 193
  smoke checks, no engine errors, 27 screenshots.
- Standing agreement since 2026-11-16: commit as work proceeds, on the phase branch.
  Push and merge only when Ákos asks.

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
| 2 | Turn resources (movement, action, bonus action, reaction) and the action bar: Attack with the equipped weapon, Dash, Disengage, Dodge, End Turn | |
| 3 | Ranged attacks: range, line of sight, targeting, hit chance shown before committing | |
| 4 | One damage pipeline with types, resistance, vulnerability and hooks; 5e armour class; armour and material data reworked so materials add no stats | |
| 5 | Durability as designed: notches, marks, blows, hardness, debuffs, buffs, field kits and scrap, ageing, the segmented bar. Also, agreed 2026-11-17: the figure on the map shows what the character is wearing, assembled from layers (the placeholder set has layers for body, legs, boots, gloves, cloak, head and both hands; none for shoulder, wrist or waist), so a broken or missing piece is visible | |
| 6 | Bestiary as data (goblin, skeleton, bandit, wolf, one boss); behaviours (rusher, archer, caster, pack); perception by line of sight; encounters by budget | |
| 7 | Companions as party combatants that enemies target, driven by the same behaviours. Settle here, by Ákos playing both, whether companions default to player control or to acting on their own (he wondered on 2026-11-17 whether anyone wants to control four characters, then left the decision as it stands; my lean is AI by default because fights are frequent and small) | |
| 8 | Readability: movement range, valid targets, status icons, a working turn-order bar, faster enemy turns | |
| 9 | `AStarGrid2D` pathfinding; an input map with rebindable actions | |
| 10 | Headless combat simulator; tune the durability dials and encounter budgets against the run target | |

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

- Potions, scrolls and wands can be used from the character sheet at any time,
  enemy turns included, at no action cost (step 2, turn resources).
- Companions (step 7): the AI picks the nearest hostile in the whole dungeon, even
  one outside the fight; a companion walks its whole path in one turn, with no
  movement budget; it attacks unarmed, without status effects, cover or flanking;
  nothing can damage one yet, and the death path would treat it as an enemy.
- An enemy that moves and then attacks runs its end-of-turn effects before the blow
  lands (step 2).
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
