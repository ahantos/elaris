# Elaris - Project Context

Grid-based, turn-based dungeon crawler using D&D 5e rules. Godot 4.5, GDScript.
Pitch: "Hades meets Battle Brothers meets classic D&D".

## Read first
- `docs/ASSESSMENT_AND_PLAN_2026-11.md` - what actually works, what does not, the
  phased plan, and the design decisions already made. Source of truth for state.
- `docs/ARCHITECTURE_CONTRACTS.md` - ids, schemas and rules every system follows.
- `PROGRESS.md` - where the work is right now and what is waiting on Ákos. Update it
  whenever the state changes.
- `docs/GEAR_FANTASY_PROPOSAL.md` - an open proposal to make gear the centre of the
  game. Not decided; do not build towards it until Ákos answers it.

## State in one paragraph
A working combat prototype with a real shell around it: main menu, character creation,
a seeded dungeon, saves that restore the same world, a pause menu and a game-over
screen. Around that sit systems that exist as code but are mostly unreachable in play:
crafting beyond the basics, quests past the first objective, zones, factions, and
companions outside a debug button. No town, no audio, placeholder art. Do not describe
a system as working because its manager runs; check that a player can reach it.

## Running and checking
- Engine: `C:\Users\Akos\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe`
  (the folder really is named `.exe`). Override with `GODOT_EXE`.
- **`tools\run_checks.bat`** - run before every commit. Import, headless smoke test,
  then a windowed screenshot tour written to `tools/out/screenshots/`. `--no-shots`
  skips the window. Look at the pictures after any change to UI or the map. The checks
  keep their saves in scratch folders and fail on any engine error line.
- Running `scenes/world.tscn` on its own (F6 in the editor) still works: it starts a
  default fighter and skips the menu.
- After adding art or a `class_name` script, the engine needs an import
  (`--headless --import`, or just open the editor) before a command-line run sees it.
- A headless boot only proves the scripts parse. It cannot see layout. That is how
  every panel shipped off-screen once.
- Scripts started with `--script` are compiled before the autoloads exist: reach them
  with `root.get_node("Name")`, never by global name.
- Per-script `--check-only` false-positives on autoload names. Do not use it.

## Architecture
- 22 autoload singletons, listed in `project.godot` (databases, then managers, then
  UIManager). `EventBus` carries all cross-system signals.
- Three scenes: `scenes/main_menu.tscn` (main scene), `scenes/character_creation_screen.tscn`,
  `scenes/world.tscn`. `GameManager` owns the transitions and `reset_game_state()`;
  `SaveManager` owns save files; the World scene saves and restores its own state.
  See contracts section 1a before touching any of it.
- `scripts/world.gd` - the game scene: start-up from a seed or a save, spawning,
  hotkeys, panel registration, loot and XP on kill, companion nodes. It owns the
  combat controller (`world.combat`) and lists the combatants in the scene
  (`get_combatants()`, `get_combatant_at()`, `is_tile_occupied()`). `world.in_combat`
  is read-only and comes from the controller.
- `scripts/combatant.gd` - `Combatant`, the base of every creature that fights: tile
  and grid conversion, stats, team, `is_hostile_to()`, `is_alive()`, `can_act()`,
  walkability, the one A* pathfinder (`find_path`), HP bar and damage flash.
  `scripts/grid_character.gd` (player: input, path preview), `scripts/enemy.gd` (enemy
  AI) and `scripts/companion.gd` (follow, ally AI) extend it. Hostility is by team,
  never by "is it in `world.enemies`".
- `scripts/combat_controller.gd` - `CombatController`, a Node under World and the one
  authority for whose turn it is: starts a fight when a hostile is near the player,
  rolls initiative for every combatant in it (companions included), hands out turns,
  counts rounds, ends the fight when one side is left. Anything that acts in combat
  asks it first (`is_turn_of`, or `Combatant.can_act()`). See contracts section 4.
- `scripts/initiativetracker.gd`, `scripts/turn_ui.gd` - display only; they show what
  the controller says and keep no turn state of their own.
- `ui/*.gd` - panels built in code and registered with `UIManager`, which owns
  exclusivity and pausing. `ui/notification_toasts.gd` draws `EventBus.ui_notification`.
- `scripts/character_screen.gd`, `scripts/save_load_menu.gd` - older screens with their
  own pause handling.
- `ui/main_menu.gd`, `ui/pause_menu.gd`, `ui/game_over.gd`, `ui/settings_panel.gd` -
  newer screens: scenes laid out with containers, styled by `ui/theme/elaris_theme.tres`.
  Build new UI this way.
- Art: `assets/` holds every image the game loads, named by role. `ArtLibrary`
  (`scripts/art_library.gd`) is the only code that maps game ids to textures, from the
  manifest in `data/art/art_manifest.gd`. `docs/ART_CHECKLIST.md` lists what to draw.
  The grid is 32x32. See contracts section 6.
- `tools/` - checks. `art_source/` - source art, hidden from Godot by `.gdignore`.

## Rules that bite
- Layout: `set_anchors_and_offsets_preset()`, not `set_anchors_preset()`, on any Control
  that is already in the tree. The latter keeps the current rectangle.
- Speed is in feet on `CharacterStats` (30 = 6 tiles). `get_modified_movement_speed()`
  returns tiles.
- Anything the game gives the player goes through `InventoryManager.add_item_or_drop()`.
- Item instances are Dictionaries wrapping an `ItemData` Resource. `Object.get()` takes
  one argument; a default value on a Resource is a script error.
- Save payloads are primitives only; items rebuild from ids.
- Combat timers are pause-bound: `create_timer(t, false)`. Check `is_instance_valid`
  after every await.
- The node name "World" is load-bearing (cached lookups).
- New content ids are checked by `tools/content_validator.gd`. A dangling reference
  fails the smoke test unless it is listed, with a reason, in `KNOWN_GAPS`.
- A new enemy type, class, companion, item or biome needs a row in the art manifest,
  or the smoke test fails on the missing art.
- A manager that keeps per-game state needs `reset()` and an entry in
  `GameManager.STATEFUL_MANAGERS`, or its state leaks into the next game.
- `is_instance_valid(player)` no longer means the player is alive; the body stays in
  the scene after death. Use `World._player_alive()` or `stats.is_alive()`.

## Keys
| Key | Action |
|---|---|
| WASD / click | Move. Ctrl+click adds waypoints, right-click cancels |
| 1 / 2 / 3 | Light / medium / heavy attack, then click an adjacent enemy |
| Space | End turn |
| T | Toggle turn mode outside combat |
| I | Character sheet (drag to equip, right-click to use) |
| B / C / J / O / P | Spellbook / crafting / quest log / world map / companions |
| F5 / F6 | Save / load |
| F7 / F8 | Short / long rest |
| G | Grid overlay |
| PageUp / PageDown | Zoom in / out in whole steps |
| Esc | Cancel an attack or spell; close the open panel; otherwise the pause menu |
| F3 | Toggle debug keys: R new dungeon, N new character, Y talk to the Reeve, M reveal map |

## Decisions already made (2026-11-16)
Weapon-based action bar replaces the three attack buttons. The player controls each
party member, with an AI option. Towns are a screen, with a world map of locations.
Durability is a core mechanic. Its design was settled on 2026-11-17 from Ákos's own
homebrew system and is in section 8 of the plan: notches per material, wear marks by
the length of fights, hardness, debuffs and buffs, repair by kit or smith, ageing.
The numbers are dials for the Phase 2 simulator. Two rules of his to keep: a state
never touches wear marks, and durability adds no chore beyond repair. Levels 1-5 first. Art is
32x32, own art later, DCSS CC0 tiles as placeholders. Multiplayer is shelved. Names
and lore are deferred. Details in section 8 of the plan.

## Working agreement
- A branch per phase, committed as the work proceeds (agreed 2026-11-16), with
  `tools\run_checks.bat` passing before each commit. Push and merge only when asked.
- A feature is done when a player can reach it, it has been seen working in the
  running game, and Ákos has played it.
