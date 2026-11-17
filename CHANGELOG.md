# Development Changelog

All notable changes and session notes documented here.

---

## [Session - November 17, 2026] - Phase 2, step 5: Gear Wears

### Added
- Notches. Every weapon, shield, body armour, helmet and piece in the shoulder,
  back, wrist, hands, waist, legs and feet slots has notches: its material's
  count, one more when masterforged, one more for each plus of magic. Neck, rings
  and trinkets do not wear. At no notches a piece is broken: it gives nothing, a
  broken weapon cannot attack, and nothing is ever destroyed.
- What a lost notch costs. Every second one costs a weapon 1 to hit and medium or
  heavy armour 1 armour class; light armour and shields keep their bonus until the
  last notch goes.
- Wear marks. A fight leaves one mark for every two rounds on everything used in
  it: the weapon that attacked, the armour and shield of whoever was attacked. At
  the material's hardness times 3 a piece loses a notch (times 6 for the seven
  secondary slots).
- Blows. A critical hit takes a notch from the shield, or without one from the body
  armour two times in three and another worn piece otherwise; two notches from a
  two-handed or bludgeoning weapon. A natural 1 takes one from the attacker's
  weapon. Hardness is compared where two pieces meet: a striker harder by 2 takes
  one more, a piece harder by 2 takes a mark and no notch. Magic gear has a small
  chance to ignore a notch lost to a blow.
- Debuffs, which come only with a lost notch and go with any repair: cracked,
  breached, dented, torn, chipped. Buffs, which stay: Battle-Honed, Blood-Forged,
  Mage-Touched, Dragon-Hardened (the last two cannot be earned until enemies cast
  spells and breathe fire).
- Field repair on the character sheet, outside a fight. A repair kit and one unit
  of scrap of the piece's kind, at least as hard, restore one notch. Salvaging a
  spare piece gives scrap. One button repairs everything worn while kits and scrap
  last. Every character starts with two kits; kits turn up in loot.
- Ageing: every repaired notch ages a piece, and enough age costs it a maximum
  notch, never the last.
- Looted weapons and armour arrive worn, having lost up to half their notches.
- A party member's critical hit notches an enemy's shield or armour and lowers its
  armour class. Goblins carry a wooden shield and bandits wear leather for this.
- On screen: a segmented bar on every slot of the sheet and in the item tooltip, a
  tooltip that lists each debuff and buff with what it does, the cost of wear in
  the armour class breakdown and in the attack readout, a line on the HUD for a
  piece that is broken or on its last notch, and a combat log line and a toast
  whenever a piece loses a notch, breaks, is repaired or earns a buff.

### Changed
- The old durability points are gone. Save format 5 converts them to notches in
  proportion; wands keep their charges under a name of their own.
- Enemy attacks have a damage type: goblins, skeletons and bandits slash, wolves
  pierce. They were untyped before.
- Cloaks and belts are made of wool and cowhide, because their slots wear.
- The unused gold-and-material repair in the crafting manager is removed.

### Checks
- 506 smoke checks, up from 417, and 38 screenshots.

---

## [Session - November 17, 2026] - Phase 2, step 4: Damage, Armour Class, Materials, Weapon Sets

### Added
- One damage pipeline, `CombatManager.deal_damage`. Weapons, spells and status
  effects all go through it. It applies immunity, resistance (half) and
  vulnerability (double), and raises four hooks other systems can listen to: an
  attack was resolved, damage is incoming, damage was applied, a combatant would
  drop to 0 hit points.
- Skeletons take double damage from bludgeoning. Dwarves take half from poison. A
  half-orc stays on 1 hit point instead of dropping, once per long rest. Damage
  numbers, the combat log and the attack readout say when damage was resisted,
  doubled or negated.
- Two weapon sets for every character, each with a main hand and an off hand.
  Swapping costs the action in a fight and is free outside one. The character
  sheet shows both sets; the action bar has a Swap button on key 7, and End Turn
  moved to key 8.
- The character sheet lists what the armour class is made of.

### Changed
- Armour class follows 5e: body armour, Dexterity as the armour allows, shield, and
  magic or craftsmanship bonuses. Helmets, gloves, greaves, boots and the other
  slots give none. Heavy armour without the Strength for it costs 10 feet of speed.
  Armour or a shield without the class proficiency gives disadvantage on attacks
  and blocks spellcasting.
- Materials no longer add damage or armour class. A material sets a durability
  score, a hardness, a notch count, a price and a trait. The first 24 materials
  from Ákos's tables replace the old ladder of 20; mythril and adamantite exist
  but never drop. Old ids still load through an alias table.
- Attack uses only the weapon set in hand. Out of reach with a sword, the button
  says which set to swap to. In a fight, gear cannot be changed from the sheet.
- The separate ranged slot is gone. Save format 4 moves its item into the second
  weapon set.
- Cover follows 5e's corner rule: half cover +2, three-quarters +5. An open shot
  down a corridor has none.
- A weapon's own craftsmanship or magic bonus now applies to its attacks, and
  armour's to armour class.
- The longbow's range is 30/120 tiles.

### Fixed
- Ring and Cloak of Protection now grant their armour class.
- The Elixir of Fire Resistance gives real fire resistance.
- Two timers leaked when the world was freed while a turn was waiting. The checks
  now fail on a leak.

### Checks
- 417 smoke checks, up from 326, and 33 screenshots.

---

## [Session - November 17, 2026] - Phase 2, step 3: Ranged Attacks and Targeting

### Added
- Attack shoots the ranged weapon a character carries at an enemy beyond reach,
  with Dexterity for the roll and the damage. An adjacent enemy still gets the
  main-hand weapon. Enemies and companions can shoot through the same request; none
  is given a ranged weapon yet.
- Range, line of sight and cover: a plain attack up to normal range, disadvantage
  beyond it, refused beyond the maximum or with no line of sight. Cover raises the
  target's armour class. Shooting with an enemy adjacent is at disadvantage.
- While an attack is aimed, every attackable enemy is marked, a line runs to the
  hovered one, and a readout shows the weapon, the chance to hit, the damage and the
  reasons for any advantage or disadvantage, or why the target cannot be attacked.
  The chance comes from `CombatManager.get_hit_chance`, which rolls nothing.
- A ranged attack shows an arrow in flight.

### Changed
- The Attack button lists both weapons when a character carries a melee and a
  ranged one.
- A bow or crossbow cannot be fired with a shield in the off hand; the button says
  why.
- A click on an enemy that cannot be attacked gives the reason and keeps Attack
  selected.
- A hostile attacked from outside the fight joins it.

### Checks
- 326 smoke checks, up from 283, and 31 screenshots.

---

## [Session - November 17, 2026] - Phase 2, step 2: Turn Resources and the Action Bar

### Added
- An action bar replaces the light, medium and heavy attack buttons: Attack, Cast,
  Use Item, Dash, Disengage, Dodge, End Turn. Keys 1 to 7 in that order; Space still
  ends the turn. A button that cannot be used is disabled and says why.
- A turn has resources: movement, one action, one bonus action, and one reaction
  that returns at the start of the combatant's own turn. A strip above the bar shows
  them for whoever holds the turn.
- Dash adds the combatant's speed to its movement. Disengage stops its movement
  provoking opportunity attacks for the turn. Dodge gives attackers disadvantage and
  the dodger advantage on Dexterity saves until its next turn.

### Changed
- Attacks use the equipped weapon: its damage die and type, Strength (or the better
  of Strength and Dexterity for a finesse weapon), and the proficiency bonus only
  when the class is proficient. A versatile weapon uses its larger die with an empty
  off hand. With no weapon the attack is an unarmed strike.
- Every action is a request to the turn authority,
  `CombatController.request_action(combatant, action_id, params)`, which checks it
  and applies it. The player, enemies and companions all go through it.
- A spell costs the action or bonus action its data says. Reaction spells are
  refused for now.
- Using a potion, scroll or wand in a fight costs the action and is refused when it
  is not your turn. Outside a fight it stays free.
- A two-handed weapon cannot be equipped with something in the off hand, or the
  reverse. The quarterstaff is versatile, not two-handed.
- Companions move at most their speed in a turn.
- A blow lands with the lunge instead of a moment after it.

### Fixed
- An enemy that moves and then attacks runs its end-of-turn effects after the blow.
- Clicks on the bottom bar no longer also click the map behind it.

### Checks
- 283 smoke checks, up from 193, and 29 screenshots.

---

## [Session - November 17, 2026] - Phase 2, step 1: Combatant Base and Turn Authority

Phase 2 (combat core) started on branch `phase-2-combat-core`. This is the first of
ten steps; `PROGRESS.md` lists them.

### Changed
- The player, enemies and companions share one base, `Combatant`
  (`scripts/combatant.gd`): team, grid position, movement, hit points, damage flash,
  the HP bar and a single pathfinder. Each had its own copy before.
- One authority decides whose turn it is: `CombatController`
  (`scripts/combat_controller.gd`), owned by the World scene as `world.combat`. It
  starts and ends fights, rolls initiative, hands out turns and counts rounds. The
  combat loop left `world.gd`, which went from 1120 lines to 881.
- Companions roll initiative and take their own turn. They appear in the initiative
  bar with a green frame, and the banner names whose turn it is.
- Hostility is decided by team wherever it was hard-coded as "the enemies against
  the player": spell targeting, opportunity attacks, the initiative bar.
- The initiative tracker and the turn banner only display what the controller says.

### Fixed
- On anyone else's turn the player can no longer attack, cast, move or end the turn.
  Pressing SPACE during an enemy turn no longer burns a turn off the player's effects.
- A combatant that dies on its own turn no longer makes the next one skip.
- Removing a dead combatant from the order no longer shifts whose turn it is.
- Companions can no longer path through or onto an enemy's tile.

### Checks
- 193 smoke checks, up from 154: teams, companions in the initiative order, the turn
  gate, death on a combatant's own turn, and a fight ending when one side is gone.
- Each check run keeps its saves in its own scratch folder, so two runs at once
  (two working copies) no longer make each other's save checks fail.

---

## [Session - November 16, 2026] - Phase 1: Game Shell and State

### Art
- Placeholder art: 142 Dungeon Crawl Stone Soup tiles (CC0) copied into `assets/`,
  named by role. Every file can be replaced in place by own art with no code change.
- The grid is 32x32. Camera zoom 2 with whole-number steps (PageUp / PageDown, 1x to
  4x), nearest-neighbour filtering, movement speeds rescaled so the pace in tiles is
  unchanged.
- The dungeon is drawn with `TileMapLayer`. Each of the five biomes has its own floor,
  wall, door and decoration, with per-cell variants chosen by a coordinate hash.
- Real sprites for the player (by class), goblin, skeleton, bandit, wolf, the four
  companions and ground loot. Enemies are no longer told apart by tint.
- Item icons for all 283 items, shown in the character sheet with stack count and tooltip.
- `ArtLibrary` (`scripts/art_library.gd`), the art manifest (`data/art/art_manifest.gd`)
  and `docs/ART_CHECKLIST.md`, generated by `tools/art_checklist.gd`.
- Missing art shows a magenta checker and fails the smoke test instead of crashing.

### Added
- Main menu as the first scene: Continue, New Game, Load Game, Settings, Quit.
- New Game runs character creation as its own screen and starts the world with the
  created character. Creation has a class skill choice.
- Pause menu on ESC: resume, save, load, settings, main menu, quit.
- Game-over screen: load the last save, main menu, or quit.
- Settings: fullscreen, vertical sync, master volume.
- Autosave slot, written when a new game starts and on zone travel.
- A small UI theme (`ui/theme/elaris_theme.tres`) used by the new screens, which are
  scenes laid out with containers rather than code with fixed positions.

### Changed
- Dungeons are generated from a seed (`DungeonGenerator.dungeon_seed`); the same seed
  and biome give the same layout, and the starting enemies follow from the seed.
- Save format 3: adds the world (seed, biome, living enemies with HP and position,
  ground loot, explored map, companion HP). Formats 1 and 2 are migrated on read; a
  save written by a newer format is refused.
- Loading no longer patches the running game. `GameManager.load_game()` wipes all
  state (`reset()` on every stateful manager) and starts a fresh World scene that
  rebuilds itself from the save.
- The world generates its dungeon immediately instead of waiting on a timer.
- Death no longer frees the player node.
- Saving is refused in combat and after death. Overwriting a slot takes a second click.
- ESC that cancels an attack or a readied spell no longer falls through to anything else.
- Gifting requires the item to actually be in the bag.

### Checks
- The smoke test now walks the whole flow: menu, new game, save, load (same dungeon,
  enemies, loot, explored map, quests, companion), no saving in combat, death and
  recovery, pause menu, and loading format-1, format-2 and too-new saves.
- The checks write saves to scratch folders and fail on any engine error line, not
  only script errors. They run an import first.

### Docs
- `CURRENT_WORK.md` is now `PROGRESS.md`.

---

## [Session - November 16, 2026] - Assessment and Phase 0: Truthful Baseline

Full assessment and the plan it produced: `docs/ASSESSMENT_AND_PLAN_2026-11.md`.
The June entry below overstates the state of the game: its systems were built, but
most were not reachable in play, and every panel it added rendered off-screen. The
"zero script errors / 19 of 19" validation was headless and could not see that.

### Interface
- Every June panel (spellbook, crafting, quest log, world map, companions, character
  creation, dialogue) and the top and bottom HUD now lay out on screen. They called
  `set_anchors_preset()` in `_ready()`, which keeps the current 0x0 rectangle; they now
  call `set_anchors_and_offsets_preset()`.
- `EventBus.ui_notification` is drawn on screen (`ui/notification_toasts.gd`, owned by
  UIManager). 33 call sites had no renderer.
- Window scales: stretch mode `canvas_items`, aspect `keep`, design size 1920x1080.
- Character sheet shows item names and hover details instead of a single letter, the
  character's name and class, and speed in feet and tiles.
- Initiative bar sits below the turn banner and tints enemy icons.

### Fixed
- Gifting a companion threw a script error on every call; gift preferences compared
  against the wrong item-type numbers.
- Crafting never saw the player (`Engine.has_singleton` on an autoload), so every recipe
  above level 1 was uncraftable.
- Loot the bag refused was destroyed on pickup; crafted items and quest, dialogue and
  event rewards were lost the same way. Refused loot now stays on the ground, and
  anything the game hands over drops at the player's feet
  (`InventoryManager.add_item_or_drop`).
- Right-clicking a scroll deleted it without casting.
- A dismissed companion could never rejoin (`CompanionManager.rejoin_party`).
- Crafting panel's X button left the game paused.
- Speed is stored in feet everywhere (30 ft = 6 tiles). Encumbrance used to subtract
  feet from a tile count, leaving zero movement.
- Encumbrance disadvantage applied to every roller, enemies included; it now applies
  only to party members.
- Starting kit is equipped (AC 17 instead of 11 for the fighter).
- Re-creating a character no longer orphans equipment or stacks a second kit.
- Wizard: INT and WIS saves, corrected slot table from level 11, no Eldritch Blast.
- Starting cantrips follow a priority list instead of alphabetical order.
- Casters are granted spells when a level-up opens a new spell level.

### Changed
- R (new dungeon), N (new character), Y (talk to the Reeve), M (reveal map) and the
  companion debug-recruit button only work while debug keys are on. F3 toggles them.
- Removed dead scripts: `test_inventory_setup.gd`, `cameracontroller.gd`,
  `dungeon_test_controller.gd`.

### Added
- `tools/run_checks.bat`: headless smoke test (75 checks, content-reference validation,
  a scripted fight) and a windowed screenshot tour. Run against the June commit, the
  smoke test fails 40 checks.
- `art_source/dcss-tiles/`: CC0 placeholder tiles, not yet used by the game.

---

## [Session - June 11-12, 2026] - Full-Systems Build-Out (Phases 2-8)

### 🔧 Review & Fixes
- Fixed InventoryManager autoload silently failing to parse (2-arg Object.get) — equipment
  had never actually worked at runtime
- Fixed attack-crash (missing has_disadvantage_on_physical_rolls), level-up HP wipe,
  modifier rounding for odd stats < 10, unequip item-loss when inventory full,
  .has()-on-Resource equip crash, enemy sprite-scale stranded refactor, combat timers
  running while paused, human.tres +11 STR typo, anchors warnings
- Removed stray committed tmp files; .gitignore covers *.tmp / tmpclaude*

### 🏗️ Architecture
- docs/ARCHITECTURE_CONTRACTS.md (binding system contracts), ~50 new EventBus signals,
  14 new autoload managers (22 total), UIManager exclusive panel system

### ⚔️ Systems Built (placeholder content, fully integrated)
- **Items/Loot:** 20 materials, 263 items, loot tables, ground drops, starting kits
- **Progression:** XP table to 40, ASIs, class hit dice, 18 skills, 5 races, character creation
- **Combat:** 17 status effects, line-of-sight, cover, flanking, opportunity attacks
- **Magic:** 82 spells, slots, concentration, scrolls/wands, enchanting, spellbook panel
- **Crafting:** 115 recipes, 4 stations, repair, enchanting, crafting panel
- **World/Story:** 3 factions, 8 quests + procedural generator, dialogues with skill
  checks/conditions/effects, 6 random events, Lich King crisis, 9 zones + travel
- **Social:** 4 companions (2 romanceable), relationships, gifts, party combat
- **Save v2:** every system serialized (primitives only), v1-save tolerant
- **Integration:** full keymap (B/C/J/O/P/N panels, Y dialogue, F7/F8 rest), loot/XP on
  kill, step-on pickup, status-effect turn hooks, spell click-targeting, zone regen

### ✅ Validation
- Headless boot + 600-frame run: exit 0, zero script errors
- Scripted gameplay probe through recruit/combat/cast/loot/travel/rest/dialogue/crisis: 19/19

---

## [Session - October 18, 2025] - Documentation & Planning

### 📚 Documentation Created
- **DESIGN_OVERVIEW.md** - Complete 80-section game design overview
  - Core vision and scope
  - 9-zone structure with layered difficulty design
  - All game systems documented (combat, character, equipment, magic, crafting, social)
  - Development roadmap
  - Pricing strategy ($15 Early Access → $35-40 full release)
- **CURRENT_WORK.md** - Session tracking template
- **ROADMAP.md** - Phase-by-phase development timeline
- **CHANGELOG.md** - This file

### 🎯 Major Design Decisions

**Zone Design Philosophy - Finalized:**
- ❌ Rejected: Strict level-gated zones (Zone 1 = lvl 1-10, Zone 2 = lvl 11-20)
- ✅ Adopted: "Elden Ring + Battle Brothers Hybrid"
  - Each zone has layered difficulty (onion structure)
  - Outer ring: Levels 1-10 (beginner-friendly, every zone)
  - Middle ring: Levels 10-25 (main content)
  - Inner ring: Levels 25-35+ (endgame)
  - Core: Crisis events + zone boss (level 35+)
- **Result:** All zones accessible from level 1, natural difficulty scaling, high replayability

**Pricing Model - Finalized:**
- Early Access model with growing content
- Launch (Zone 1): $15
- After Zone 2: $20 (early buyers get free)
- After Zone 3: $25 (all previous buyers get free)
- Full Release (9 zones): $35-40
- "Buy once, get all zones as we release them"
- Rejected $80 pricing (too ambitious for indie)

**Story & Scope:**
- Confirmed: Procedural games CAN have great stories
- Model: Hades-style (handcrafted story + procedural dungeons)
- Each zone: 20-30 hours handcrafted + infinite procedural
- Crisis events provide Battle Brothers-style endgame content

### 🛠️ Repository Setup
- Created GitHub repository using GitHub Desktop
- Set up proper `.gitignore` for Godot
- Organized project structure with `docs/` folder
- Version control established for code sharing

### 💭 Discussions
- Can procedural games have engaging stories? → YES, with hybrid approach
- How big can we go with D&D campaign world? → Start with 1 zone, expand
- Level-gating philosophy → Natural difficulty vs artificial gates
- Pricing strategy for 9-zone game → Early Access growth model

### 📝 Notes
- Game will be set in existing D&D campaign world
- Focus on ONE region/story arc per zone
- Hub-based design: cities (handcrafted) + dungeons (procedural)
- Crisis events = repeatable endgame content
- No voice acting (text-only to manage scope)
- Target: 10-20 hours per zone, 200+ hours total at full release

### 🎯 Current Status
- Phase 1: ✅ Core Prototype Complete
- Refactor Day 1: ✅ Complete (CombatManager, InventoryManager)
- Refactor Day 2: ⏳ Next (ClassData, RaceData, SaveManager)
- Documentation: ✅ Complete

### 📅 Next Session Goals
1. Complete Refactor Day 2:
   - ClassData.gd (Fighter, Wizard, Rogue, Cleric)
   - RaceData.gd (Human, Elf, Dwarf, Halfling, Half-Orc)
   - SaveManager.gd (save/load game state)
2. Define Zone 1 identity:
   - Theme and geography
   - 3 city names and descriptions
   - Crisis event concept
3. Test combat system with new managers

---

## [Session - October 17, 2025] - Refactor Day 1 Complete ✅

### ✅ Completed
- **CombatManager.gd** (AutoLoad Singleton)
  - D&D 5e combat system (d20 + attack bonus vs AC)
  - Critical hits (natural 20 = double damage dice)
  - Fumbles (natural 1 = auto-miss)
  - Damage dice rolling (1d4, 1d8, 1d12, etc.)
  - Advantage/disadvantage support (ready for Phase 4)
  - Centralized damage application
  - Initiative rolling system
  
- **InventoryManager.gd** (AutoLoad Singleton)
  - Party inventory system (shared by 4 characters)
  - Add/remove items with weight tracking
  - Gold management (add/remove/check)
  - Equipment system (equip/unequip to character slots)
  - Encumbrance checking (weight limits)
  - Stackable items support
  - Ready for Phase 2 equipment expansion

- **Refactored GridCharacter.gd**
  - Removed hardcoded combat damage
  - Now uses `CombatManager.roll_attack()` for all attacks
  - Creates temporary weapons (will use real weapons in Phase 2)
  - Added `CharacterStats` integration
  - Combat logic separated from character controller
  - Helper functions: `create_temp_weapon()`, updated `attack_enemy()`, `take_damage()`, `heal()`

- **Refactored Enemy.gd**
  - Added `CharacterStats` (enemies now have stats like players)
  - Removed hardcoded damage
  - Uses `CombatManager.roll_attack()` for attacks
  - Enemy AI now rolls d20 vs player AC
  - Consistent combat system with player
  - Helper functions: `initialize_stats()`, `create_temp_weapon()`, updated `attack_player()`, `take_damage()`

### 🎮 Gameplay Changes
**Before:**
- Light attack = 1 damage (hardcoded)
- Medium attack = 5 damage (hardcoded)
- Heavy attack = 10 damage (hardcoded)
- No dice rolls, no misses, no crits

**After:**
- Light attack = 1d4 + STR modifier
- Medium attack = 1d8 + STR modifier
- Heavy attack = 1d12 + STR modifier
- Rolls d20 + attack bonus vs enemy AC
- Can MISS (roll too low)
- Can CRIT (natural 20 = double damage)
- Can FUMBLE (natural 1 = auto-miss)

**Example Combat Output:**
```
Player attacks Enemy with 1d8 weapon
⚔️ Attack roll: 15 + 5 = 20 vs AC 12
⚔️ Hit! 7 damage! (rolled 5 on d8 + 2 STR)
```

Or:
```
💥 Attack roll: NAT 20! CRITICAL HIT!
💥 CRITICAL HIT! 14 damage! (rolled 5+6 on 2d8 + 2 STR)
```

### 🏗️ Architecture Changes
**Old (Messy):**
```
GridCharacter.attack_enemy() → hardcoded damage → enemy.take_damage()
```

**New (Clean):**
```
GridCharacter → CombatManager.roll_attack() → CombatManager.apply_damage() → enemy
					↓
			Uses CharacterStats for all calculations
```

### 📝 Technical Notes
- All combat math now centralized in CombatManager
- Characters only handle input/movement/visuals
- Managers handle all game logic
- Easy to add new features (advantage, reactions, status effects)
- Supports multiplayer (deterministic combat)
- Save/load friendly (managers handle data)

### 🐛 Known Issues
- Temporary weapons need to be replaced with real ItemData weapons (Phase 2)
- No equipment UI yet (Phase 2)
- Save/load not implemented yet (Day 2)

### 📅 Next Steps
- Day 2 refactor: ClassData, RaceData, SaveManager
- Replace temporary weapons with real equipment system
- Add character creation screen
- Test save/load functionality

---

## [Session - Prior] - Phase 1 Complete ✅

### ✅ Completed
- **Grid-Based Movement**
  - Click-to-move with A* pathfinding
  - WASD exploration mode (smooth free movement)
  - Multi-waypoint system (Ctrl+Click)
  - Path preview with cost indicators
  
- **Turn-Based Combat**
  - Toggle with T key
  - Movement points per turn
  - Attack system (1/2/3 keys for light/medium/heavy)
  - Turn end with Space key
  
- **Procedural Dungeon Generation**
  - 5 biomes: Crypt, Cave, Sewers, Forest, Mines
  - BSP algorithm for room generation
  - Corridors connecting rooms
  - Door placement
  - Minimap with fog of war
  
- **Enemy AI**
  - A* pathfinding toward player
  - Attack when adjacent
  - Turn-based movement
  - Multiple enemies support
  
- **Core Systems**
  - CharacterStats (HP, stats, AC, proficiency)
  - MaterialData (8 material tiers)
  - ItemData (weapons, armor, consumables)
  - EventBus (global events)
  - GameManager (game state)
  - ItemDatabase (item definitions)
  
- **UI Systems**
  - HP bars (player and enemies)
  - Damage popups (damage, miss, heal, crit)
  - Minimap with fog of war toggle (M key)
  - Grid overlay toggle (G key)
  
- **Visual Polish**
  - Attack animations (lunge effect)
  - Damage flash effects
  - Death animations (fade + shrink)
  - Color-coded damage popups
  - Path preview lines and waypoints

### 📊 Stats
- ~2000+ lines of code
- 15+ GDScript files
- 5 AutoLoad singletons
- 8 material tiers
- 5 dungeon biomes
- Playable prototype: ✅

### 🎯 Status
- Phase 1: ✅ Complete
- Ready for Phase 2: Equipment Foundation

---

## Version History

- **v0.2.0** - Refactor Phase (In Progress)
  - Manager-based architecture
  - D&D 5e combat system
  - Documentation structure
  
- **v0.1.0** - Core Prototype (Complete)
  - Basic playable game
  - Grid movement
  - Turn-based combat
  - Procedural dungeons

---

## [2025.10.19] - Savegame

### ✅ Completed
Save/load funtions done, basic UI done for it


**Changelog Format:**
```
## [Session - Date] - Title

### ✅ Completed
- Feature 1
- Feature 2

### 🔄 In Progress
- Feature 3

### 🐛 Bug Fixes
- Bug 1

### 💭 Discussions
- Topic 1

### 📝 Notes
- Note 1

### 📅 Next Steps
- Step 1
```

---

**Last Updated:** October 18, 2025
