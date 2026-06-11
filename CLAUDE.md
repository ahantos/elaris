# Elaris - Project Context

## Quick Summary
**Elaris (Dungeon Delver)** — Grid-based, turn-based dungeon crawler RPG using D&D 5e rules. Built in Godot 4.5 with GDScript.

**Elevator Pitch:** "Hades meets Battle Brothers meets classic D&D"

## Tech Stack
- **Engine:** Godot 4.5
- **Language:** GDScript
- **Architecture:** Manager-based with autoload singletons
- **Combat:** D&D 5e rules (d20 rolls, AC, advantage/disadvantage, crits)
- **Resolution:** 1920x1080

## Project Structure
```
elaris/
├── autoload/           # 8 singleton managers
│   ├── event_bus.gd
│   ├── game_manager.gd
│   ├── combat_manager.gd
│   ├── inventory_manager.gd
│   ├── item_database.gd
│   ├── save_manager.gd
│   ├── class_database.gd
│   └── race_database.gd
├── scripts/            # Core game logic
│   ├── grid_character.gd   # Player (WASD + click-to-move, combat)
│   ├── enemy.gd            # AI with A* pathfinding
│   ├── world.gd            # Main coordinator
│   ├── dungeon_generator.gd
│   ├── character_screen.gd # Equipment/inventory UI
│   └── [UI scripts]
├── scenes/             # Godot scenes (.tscn)
│   ├── world.tscn          # Main scene
│   ├── character.tscn
│   ├── enemy.tscn
│   └── dungeon_generator.tscn
├── data/               # Data resources
│   ├── stats/character_stats.gd
│   ├── items/item_data.gd
│   ├── materials/material_data.gd
│   ├── classes/*.tres      # Fighter, Wizard, Rogue, Cleric
│   └── races/*.tres        # Human, Elf, Dwarf, Halfling
├── ui/                 # UI prefabs
└── tilesets/           # Tilemap assets
```

## Autoload Managers

| Manager | File | Purpose |
|---------|------|---------|
| `EventBus` | event_bus.gd | Signal hub (combat, inventory, UI events) |
| `GameManager` | game_manager.gd | Game state, settings, global refs |
| `CombatManager` | combat_manager.gd | D&D 5e combat (d20, damage, saves) |
| `InventoryManager` | inventory_manager.gd | Items, equipment, gold, weight |
| `ItemDatabase` | item_database.gd | Item/material definitions |
| `SaveManager` | save_manager.gd | Multi-slot save/load |
| `ClassDatabase` | class_database.gd | Class definitions |
| `RaceDatabase` | race_database.gd | Race definitions |

## Key Systems

### Combat (CombatManager)
- `roll_attack(attacker, target, weapon, adv, disadv)` → hit/miss/crit/fumble
- `roll_damage(weapon, attacker, is_crit)` → damage amount
- `apply_damage(target, amount, type, attacker)` → handles death
- `make_saving_throw(char, stat, dc, adv, disadv)` → success/fail

### Inventory (InventoryManager)
- `add_item()`, `remove_item()`, `get_item()`
- `equip_item(item, character, slot)` — handles multi-slots (rings/trinkets)
- `unequip_item(character, slot, item_instance)`
- Weight system: `get_total_weight()`, `is_over_encumbered()`
- `to_dict()`, `from_dict()` — serialization for saves

### Character Stats (CharacterStats)
- D&D 6 stats: STR, DEX, CON, INT, WIS, CHA
- Derived: HP, AC, initiative, movement, carrying capacity
- Leveling: XP, level, proficiency bonus
- Equipment bonuses applied via `apply_equipment_bonuses()`

### Items (ItemData)
- Types: Weapon, Armor (head/chest/legs/hands/feet), Shield, Accessories, Consumables
- Material system: tier affects damage/armor multipliers
- Quality (+0 to +3) and Magic (+0 to +3) modifiers
- Durability system (optional)

## Architecture Conventions
- **Manager-based:** Logic in managers, not character scripts
- **Event-driven:** Use EventBus signals for decoupled communication
- **Data-driven:** Everything configurable via resources
- **Single responsibility:** Each script has ONE job

## Current Phase
**Phase 2: Equipment Foundation**

### What Works
- Grid movement (WASD exploration, click-to-move in combat)
- Turn-based combat with initiative tracker
- D&D 5e attack rolls, crits, fumbles, damage
- Procedural dungeon generation (5 biomes)
- Enemy AI with A* pathfinding
- Minimap with fog of war
- Character screen UI (equipment slots, inventory grid)
- Save/load system (basic)
- Class/Race databases loaded

### What's Missing
- **ItemDatabase.load_items() is empty** — no actual items exist yet
- Can't test character screen without items
- No item drops from enemies
- No ground pickup system

## Key Input Bindings
| Key | Action |
|-----|--------|
| WASD | Move (exploration) |
| Click | Move to / Attack (combat) |
| Ctrl+Click | Add waypoint |
| T | Toggle turn-based mode |
| Space | End turn |
| 1/2/3 | Select attack type |
| I | Character screen |
| G | Toggle grid overlay |
| M | Toggle minimap fog |
| R | Regenerate dungeon |
| F5/F6 | Save/Load menu |

## Documentation
- `DESIGN_OVERVIEW.md` — Full 800+ line game design doc
- `CURRENT_WORK.md` — Session tracking
- `ROADMAP.md` — Development phases
- `CHANGELOG.md` — History

## Session Notes
<!-- Update this section at the end of each session -->

### Latest Session
- Full codebase exploration completed
- Identified blocker: ItemDatabase.load_items() is empty
- Character screen UI exists but untestable without items
- All 8 autoload managers working
- Combat system functional with temporary weapon creation

### Next Steps
1. Create test items in ItemDatabase.load_items()
2. Add items to player inventory on game start
3. Test character screen drag-and-drop
4. Test equipment stat application
