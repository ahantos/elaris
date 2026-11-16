# Elaris - Project Context

Grid-based, turn-based dungeon crawler using D&D 5e rules. Godot 4.5, GDScript.
Pitch: "Hades meets Battle Brothers meets classic D&D".

## Read first
- `docs/ASSESSMENT_AND_PLAN_2026-11.md` - what actually works, what does not, the
  phased plan, and the design decisions already made. Source of truth for state.
- `docs/ARCHITECTURE_CONTRACTS.md` - ids, schemas and rules every system follows.
- `CURRENT_WORK.md` - where the work is right now.

## State in one paragraph
A working combat prototype (walk a small dungeon, fight, loot, level, save) surrounded
by systems that exist as code but are mostly unreachable in play: spells (the default
character is a fighter), crafting beyond the basics, quests past the first objective,
zones, factions, and companions outside a debug button. No menu, no game over, no town,
no art, no audio. Phase 0 made everything that exists visible and stopped it crashing. Do not
describe a system as working because its manager runs; check that a player can reach it.

## Running and checking
- Engine: `C:\Users\Akos\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe`
  (the folder really is named `.exe`). Override with `GODOT_EXE`.
- **`tools\run_checks.bat`** - run before every commit. Headless smoke test, then a
  windowed screenshot tour written to `tools/out/screenshots/`. `--no-shots` skips the
  window. Look at the pictures after any change to UI or the map.
- A headless boot only proves the scripts parse. It cannot see layout. That is how
  every panel shipped off-screen once.
- Scripts started with `--script` are compiled before the autoloads exist: reach them
  with `root.get_node("Name")`, never by global name.
- Per-script `--check-only` false-positives on autoload names. Do not use it.

## Architecture
- 22 autoload singletons, listed in `project.godot` (databases, then managers, then
  UIManager). `EventBus` carries all cross-system signals.
- `scripts/world.gd` - main scene script: spawning, the combat loop, hotkeys, panel
  registration, loot and XP on kill. Too large; split planned in Phase 1.
- `scripts/grid_character.gd` (player), `scripts/enemy.gd`, `scripts/companion.gd` -
  three unrelated scripts; a shared combatant model is Phase 2.
- `ui/*.gd` - panels built in code and registered with `UIManager`, which owns
  exclusivity and pausing. `ui/notification_toasts.gd` draws `EventBus.ui_notification`.
- `scripts/character_screen.gd`, `scripts/save_load_menu.gd` - older screens with their
  own pause handling.
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
| Esc | Cancel, or close the open panel |
| F3 | Toggle debug keys: R new dungeon, N new character, Y talk to the Reeve, M reveal map |

## Decisions already made (2026-11-16)
Weapon-based action bar replaces the three attack buttons. The player controls each
party member, with an AI option. Towns are a screen, with a world map of locations.
Durability is a core mechanic; its design is still open. Levels 1-5 first. Art is
32x32, own art later, DCSS CC0 tiles as placeholders. Multiplayer is shelved. Names
and lore are deferred. Details in section 8 of the plan.

## Working agreement
- Small commits on a branch per phase. Commit and push only when asked.
- A feature is done when a player can reach it, it has been seen working in the
  running game, and Ákos has played it.
