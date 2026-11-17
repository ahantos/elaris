# Progress

Last updated: 2026-11-17

This is the status file: what is done, what is next, what is waiting on Ákos. It was
called `CURRENT_WORK.md` until Phase 1. The plan it tracks is in section 7 of
`docs/ASSESSMENT_AND_PLAN_2026-11.md`; `CHANGELOG.md` has the detail of each phase.

## Where things stand

| Phase | Status |
|---|---|
| 0. Truthful baseline | Done. Committed on `phase-0-truthful-baseline` |
| 1. Game shell and state | Done. Committed on `phase-1-game-shell`, which builds on Phase 0. Not yet played by Ákos |
| 2. Combat core | Next. Waiting for Ákos's go, and for his durability system (below) |

- Nothing is pushed and nothing is merged into `main`. `main` is still the June commit.
- `tools\run_checks.bat` passes at the Phase 1 commit: 154 smoke checks, no engine
  errors, 27 screenshots.
- Standing agreement since 2026-11-16: commit as work proceeds, on the phase branch.
  Push and merge only when Ákos asks.

## Waiting on Ákos

1. **Play the Phase 1 build:** menu, new game, save, load, die, load again. Say what
   feels wrong.
2. **His durability system.** Direction is set (erosion, special attention to crits,
   scaled by material rarity and magic level), but the rules will be based on the
   system he designed for his homebrew D&D campaign, which also has passive
   degradation by combat length, and notch counts that rise with magic bonus and
   with the material itself. He will bring it and has a lot of input to add. The
   rules in section 8 of the plan are a provisional sketch, not the design.
3. **Go for Phase 2.** Everything in it except the durability rules can be built
   without that input; the damage pipeline gets the hooks durability needs.
4. **Merge and push:** whether Phases 0 and 1 go into `main`, and whether to push.
5. `tilesets/TX Tileset Stone Ground.png` is unused and its licence is not recorded.
   Delete it?

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

- The player can attack or cast during enemy turns (Phase 2, turn authority).
- A combatant that dies on its own turn makes the next one skip (Phase 2).
- Area spells always include the caster; self-buffs expire a round early (Phase 2 / 5).
- Combat starts through walls (Phase 2, perception).
- The main quest stops at its second objective; no quest is completable (Phase 4).
- Dialogue rewards repeat; talk objectives complete on any dialogue end (Phase 4).
- Five dangling references are listed in `KNOWN_GAPS` in `tools/smoke_test.gd`.
