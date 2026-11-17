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
- 23 autoload singletons, listed in `project.godot` (databases, then managers, then
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
  the resources of a turn (movement, action, bonus action, reaction), its two
  weapon sets and which is in hand, what it resists, is vulnerable and immune to,
  walkability, the one A* pathfinder (`find_path`), HP bar and damage flash. `scripts/grid_character.gd` (player:
  input, path preview, the markers of an aimed attack), `scripts/enemy.gd` (enemy
  AI) and `scripts/companion.gd` (follow, ally AI) extend it. Hostility is by team,
  never by "is it in `world.enemies`".
- `scripts/combat_controller.gd` - `CombatController`, a Node under World and the one
  authority for whose turn it is and what is done with it: starts a fight when a
  hostile is near the player, rolls initiative for every combatant in it (companions
  included), hands out turns and their resources, counts rounds, ends the fight when
  one side is left. Attack, Cast, Use Item, Dash, Disengage, Dodge, Swap, a move
  and End Turn are all `request_action(combatant, action_id, params)`: it checks
  the turn and the cost, applies the action and returns the result. So are changes
  of gear (`equip`, `unequip`), which it refuses in a fight. Player input, enemy AI,
  companion AI and the character sheet all act through it. Attack uses the weapon
  set in hand and nothing else: a melee weapon in reach, a ranged weapon in range
  and in sight; the other set takes a Swap. `get_attack_targets()` and
  `preview_attack()` tell the HUD who can be attacked and what an attack would be.
  See contracts section 4.
- `autoload/combat_manager.gd` - every die: `get_attack_profile()` (the attack with
  the weapon set in hand by 5e rules: ability, proficiency, versatile, unarmed, the
  piece's own bonus), `get_attack_modifiers()` (advantage, disadvantage and cover,
  with the reasons), `get_hit_chance()` (the exact chance, nothing rolled),
  `make_attack()` (the one weapon attack, for everyone), `make_spell_attack()`,
  saving throws, opportunity attacks. And the one damage pipeline, `deal_damage()`:
  immunity, resistance, vulnerability, and four hooks on `EventBus` that other
  systems listen to and may change (`attack_resolved`, `damage_incoming`,
  `damage_applied`, `dropping_to_zero`). See contracts section 2.4.
- `autoload/feature_manager.gd` - racial traits and class features that act through
  those hooks, and what each character has used since its last long rest. The
  first is the half-orc's Relentless Endurance.
- `scripts/projectile.gd` - the arrow a ranged attack shows on its way. Display only.
- `scripts/initiativetracker.gd`, `scripts/turn_ui.gd` - display only; they show what
  the controller says and keep no turn state of their own.
- `scripts/bottomui.gd` holds the bottom bar; the action bar in its middle is a scene
  (`scenes/ui/action_bar.tscn`, `ui/action_bar.gd`, `ui/action_button.gd`). It shows
  what `check_action()` answers and sends presses to `combatant.choose_action()`.
- `scenes/ui/attack_preview.tscn`, `ui/attack_preview.gd` - the readout beside the
  enemy an attack is aimed at: weapon, chance to hit, damage, reasons. It shows the
  controller's `preview_attack()` answer and works nothing out itself.
- `ui/*.gd` - panels built in code and registered with `UIManager`, which owns
  exclusivity and pausing. `ui/notification_toasts.gd` draws `EventBus.ui_notification`.
- `scripts/character_screen.gd`, `scripts/save_load_menu.gd` - older screens with their
  own pause handling. The character sheet shows both weapon sets and how the armour
  class is made up; every change of gear on it is a request to the controller.
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
  returns tiles. Weapon ranges (`ItemData.range_normal`, `range_max`) are in tiles:
  read them through `CombatManager.get_weapon_range()`.
- Anything the game gives the player goes through `InventoryManager.add_item_or_drop()`.
- Item instances are Dictionaries wrapping an `ItemData` Resource. `Object.get()` takes
  one argument; a default value on a Resource is a script error. A piece's own
  bonuses (`quality_modifier`, `magic_modifier`) are on the instance: read them
  there (`ItemDatabase.get_instance_bonus`), never on the `ItemData` template.
- A material sets how an item wears, what it costs and a trait. It never changes
  damage, armour class or weight. Armour class comes from body armour, Dexterity as
  the armour allows, the shield and bonuses; no other slot gives any, the helmet
  included (contracts 2.3a and 2.3b).
- All damage goes through `CombatManager.deal_damage()`. Nothing else takes hit
  points away, so resistances and the hooks always apply.
- Content names items by the id the database knows them by. An id with a renamed
  material (`iron_longsword`) still loads from a save, but the content validator
  fails on it, and on any item made of a material that cannot be obtained yet.
- Save payloads are primitives only; items rebuild from ids.
- Combat timers are pause-bound: `create_timer(t, false)`. Check `is_instance_valid`
  after every await.
- Nothing is done with a turn except through `CombatController.request_action()`.
  Input, UI and AI code ask; they do not roll dice (CombatManager does), spend an
  action or move a combatant themselves. Gear is the same: swapping weapon sets,
  equipping and unequipping are requests, and in a fight only the swap is allowed. A button asks `check_action()` whether it is
  available. Ask who controls a combatant (`is_player_controlled()`), never whether
  it is "the player".
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
| 1 | Attack with the weapon set in hand, then click a marked enemy: a melee weapon reaches an adjacent one, a ranged weapon one in range and in sight. Resting the pointer on an enemy shows the chance to hit and whether it resists the damage (1 again puts it away) |
| 2 | Cast: opens the spellbook; ready a spell, then click its target |
| 3 | Use Item: opens the character sheet; right-click a potion, scroll or wand |
| 4 / 5 / 6 | Dash / Disengage / Dodge |
| 7 | Swap weapon sets: the action in a fight, free outside one |
| 8 or Space | End turn |
| T | Toggle turn mode outside combat |
| I | Character sheet (drag to equip or to move a weapon between the two sets, SWAP to change the set in hand, right-click to use). Gear cannot be changed in a fight, only swapped |
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
32x32, own art later, DCSS CC0 tiles as placeholders. Co-op multiplayer is wanted
(decided 2026-11-17): online, up to four players, one per party member, after the
first playable. Until then, follow the three co-op rules in section 8 of the plan:
every party member has a controller, every action is a request the turn authority
approves, and dice are rolled by the authority. Names and lore are deferred.
Details in section 8 of the plan.

## Working agreement
- A branch per phase, committed as the work proceeds (agreed 2026-11-16), with
  `tools\run_checks.bat` passing before each commit. Push and merge only when asked.
- A feature is done when a player can reach it, it has been seen working in the
  running game, and Ákos has played it.
