# Development Changelog

All notable changes and session notes documented here.

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
