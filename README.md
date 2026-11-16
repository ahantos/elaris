# Dungeon Delver

Grid-based D&D 5e-style dungeon crawler RPG built in Godot 4.

## 📖 Documentation
- **[Design Overview](docs/DESIGN_OVERVIEW.md)** ⭐ Start here
- [Full Design Document](docs/DESIGN_FULL.md) (80 pages)
- [Current Work Status](docs/PROGRESS.md) (updated each session)
- [Roadmap](docs/ROADMAP.md)
- [Changelog](docs/CHANGELOG.md)
- [Zone Designs](docs/ZONES.md)

## 🎮 Current Status
- **Phase:** Refactoring (Day 1 Complete ✅)
- **Playable:** Single character, D&D 5e combat, procedural dungeons
- **Next:** Day 2 refactor (ClassData, RaceData, SaveManager)

## 🚀 Running the Project
1. Open in Godot 4.x
2. Run `world.tscn`
3. Press **T** for turn-based mode
4. Press **1/2/3** to attack, **Space** to end turn

## 🏗️ Architecture
- **Autoload Singletons:** EventBus, GameManager, ItemDatabase, CombatManager, InventoryManager
- **Data-Driven:** CharacterStats, MaterialData, ItemData, ClassData, RaceData
- **Managers:** All logic in managers, characters handle input/visuals only

## 🎯 Design Philosophy
- **Hybrid Scope:** Handcrafted story + procedural content (Hades-style)
- **9 Zones:** Layered difficulty (beginner outer rings, endgame cores)
- **D&D 5e Rules:** d20 combat, AC, crits, advantage, reactions
- **No Level Gates:** All zones accessible from level 1 (natural difficulty scaling)

## 📊 Development Timeline
- **Year 1:** Zone 1 + Early Access ($15)
- **Year 2-3:** Zones 2-3 added (price → $25)
- **Year 4-5:** Full release with all 9 zones ($35-40)

## 🛠️ Tech Stack
- Engine: Godot 4.x
- Language: GDScript
- Version Control: Git/GitHub
- Art: [TBD]
- Audio: [TBD]

---

For detailed design info, see [Design Overview](docs/DESIGN_OVERVIEW.md).
