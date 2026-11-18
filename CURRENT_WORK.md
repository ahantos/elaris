# Current Work

Last updated: 2026-11-16

## Where things stand

Phase 0 (truthful baseline) is implemented on branch `phase-0-truthful-baseline`,
uncommitted. `tools\run_checks.bat` passes: 75 smoke checks, no script errors,
screenshot tour complete.

Done in Phase 0, in short: every panel and the HUD render on screen, notifications are
drawn, the window scales, the confirmed crashes and data-loss paths are fixed, debug
keys sit behind F3, dead scripts are gone, and the checks exist. Full list in
`CHANGELOG.md`.

## Waiting on Ákos

1. Play the Phase 0 build for ten minutes and say what feels wrong.
2. Commit Phase 0 (and decide whether `art_source/` is committed or ignored).
3. The durability design: section 8 of `docs/ASSESSMENT_AND_PLAN_2026-11.md` has the
   brief. Needed before Phase 2, not before Phase 1.

## Next: Phase 1 - game shell and state

Main menu, character creation as the start of a new game, game over, seeded dungeons,
saves that restore the same world, input map, `world.gd` split, 32-pixel tiles and
placeholder art. Scope and exit test are in section 7 of the plan.

## Known and deliberately left for later

These are real defects. They were left because the phase that rebuilds the code around
them is the right place to fix them.

- The player can attack or cast during enemy turns (Phase 2, turn authority).
- A combatant that dies on its own turn makes the next one skip (Phase 2).
- Area spells always include the caster; self-buffs expire a round early (Phase 2 / 5).
- Combat starts through walls (Phase 2, perception).
- Loading after a restart puts the player in a different dungeon (Phase 1, seeds).
- Death frees the player with no way back (Phase 1, game over).
- The main quest stops at its second objective; no quest is completable (Phase 4).
- Dialogue rewards repeat; talk objectives complete on any dialogue end (Phase 4).
- Five dangling references are listed in `KNOWN_GAPS` in `tools/smoke_test.gd`.
