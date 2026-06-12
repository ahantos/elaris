# Development Roadmap

## 🚨 STATUS UPDATE — 2026-06-12
The 2026-06-11/12 build-out session implemented the **systems** for Phases 2-8 in one pass
(see CHANGELOG). Phase statuses below are historical; reinterpret as:
- **Phases 2-8:** systems BUILT & integrated with placeholder content — remaining work is
  content volume, balance, world placement (NPCs/stations), and polish
- **Phase 9 (multiplayer):** skipped (optional per this roadmap)
- **Phase 10 (polish/launch):** unchanged, still ahead
Current focus: playtesting, balance, and content production within the built systems.

## 📊 Current Phase: Content & Balance (systems complete)

---

## ✅ Phase 1: Core Prototype (COMPLETE)
**Duration:** [Your actual timeline]  
**Status:** ✅ Complete

### Deliverables:
- ✅ Grid-based movement (click + WASD)
- ✅ Turn-based combat toggle
- ✅ Procedural dungeon generation (5 biomes)
- ✅ Enemy AI with A* pathfinding
- ✅ Basic inventory and stats
- ✅ Minimap with fog of war

---

## 🔄 Phase 2: Equipment Foundation (IN PROGRESS)
**Target Duration:** 2-3 weeks  
**Status:** 🔄 Day 1 Complete, Day 2 In Progress

### Week 1: Manager Refactor
- ✅ **Day 1:** CombatManager, InventoryManager
- 🔄 **Day 2:** ClassData, RaceData, SaveManager
- ⏳ **Day 3:** Complete save/load testing
- ⏳ **Day 4:** Character creation screen
- ⏳ **Day 5:** Equipment UI (equip/unequip)

### Week 2: Material System
- ⏳ Material-based weapon generation
- ⏳ Material-based armor generation
- ⏳ Material rarities and drop rates
- ⏳ Loot tables by enemy type

### Week 3: Testing & Polish
- ⏳ Balance pass on materials
- ⏳ Weight system refinement
- ⏳ Bug fixes
- ⏳ Documentation updates

### Deliverables:
- ⏳ 8 material tiers fully functional
- ⏳ Equipment slots (11 per character)
- ⏳ Weight/encumbrance system
- ⏳ Save/load complete game state
- ⏳ Character creation screen
- ⏳ 4 classes + 5 races implemented

---

## ⏳ Phase 3: Character Systems
**Target Duration:** 3-4 months  
**Status:** ⏳ Not Started

### Month 1: Classes
- Implement Fighter (abilities, progression)
- Implement Wizard (spellcasting basics)
- Implement Rogue (sneak attack, cunning action)
- Implement Cleric (healing, divine magic)

### Month 2: Races & Stats
- All 5 races with unique abilities
- Racial dialogue variations
- Stat point allocation on level up
- Ability score improvements

### Month 3: Skills & Proficiencies
- Skill system (Athletics, Stealth, Persuasion, etc.)
- Proficiency system
- Skill checks in dialogue
- Tool proficiencies

### Deliverables:
- 4 playable classes (Fighter, Wizard, Rogue, Cleric)
- 5 playable races
- Full leveling system (1-40)
- Skill system
- Character sheet UI

---

## ⏳ Phase 4: Combat Expansion
**Target Duration:** 2-3 months  
**Status:** ⏳ Not Started

### Features:
- Reactions (opportunity attacks, counterspells)
- Status effects (poisoned, stunned, prone, frightened, etc.)
- Environmental hazards (fire, acid, traps)
- Advantage/disadvantage mechanics
- Line of sight calculations
- Cover system (half cover, full cover)
- Flanking bonuses
- Difficult terrain

### Deliverables:
- Full D&D 5e combat rules
- 15+ status effects
- Environmental combat
- Tactical positioning matters

---

## ⏳ Phase 5: Magic System
**Target Duration:** 3-4 months  
**Status:** ⏳ Not Started

### Month 1: Spell Framework
- Spell slots system
- Spell preparation (Wizard, Cleric)
- Known spells (Bard, Sorcerer)
- Cantrips (unlimited use)

### Month 2: Spell Schools
- Evocation spells (Fireball, Lightning Bolt, etc.)
- Abjuration spells (Shield, Counterspell, etc.)
- Conjuration spells (Summon creatures)
- Transmutation spells (Haste, Slow, Polymorph)

### Month 3: Magic Items
- Scrolls (single-use spells)
- Wands (rechargeable spell items)
- Enchanting system (add magic to equipment)
- Gem socketing

### Deliverables:
- 50+ spells across all schools
- Spell slots and resting
- Scrolls and wands
- Enchanting system
- Concentration mechanic

---

## ⏳ Phase 6: Crafting System
**Target Duration:** 2-3 months  
**Status:** ⏳ Not Started

### Features:
- Blacksmithing (weapons, armor)
- Alchemy (potions, elixirs, poisons)
- Enchanting (magical enhancements)
- Cooking (food buffs)
- Recipe discovery system
- Material gathering

### Deliverables:
- 4 crafting stations
- 100+ recipes
- Material gathering from enemies/environment
- Durability and repair system

---

## ⏳ Phase 7: World & Story (Zone 1)
**Target Duration:** 6-8 months  
**Status:** ⏳ Not Started

### Month 1-2: Zone 1 Foundation
- Design Zone 1 (The Borderlands)
- Create 3 cities (handcrafted)
- Implement fast travel system
- World map UI

### Month 3-4: Story Content
- Main quest (10-15 missions)
- City storylines (5 quests per city)
- 3 faction questlines (10 quests each)
- 20 side quests

### Month 5-6: Systems
- Dialogue system with choices
- Quest tracking UI
- Reputation system
- Random events system
- Procedural quest generator

### Month 7-8: Crisis Event
- "The Lich King Rises" crisis
- Escalating phases
- Multiple battles
- Zone-wide impact
- Repeatable endgame

### Deliverables:
- Zone 1 complete (20-30 hours handcrafted)
- 75+ quests
- 3 factions
- Crisis event system
- Infinite procedural quests

---

## ⏳ Phase 8: Social Systems
**Target Duration:** 2-3 months  
**Status:** ⏳ Not Started

### Features:
- 12 recruitable companions (4 for Zone 1)
- Relationship system (friendship/romance)
- 6 romance options (2 for Zone 1)
- Companion quests
- Dynamic NPC reactions
- Persuasion/Intimidation checks

### Deliverables:
- 4 companions with full personalities
- 2 romance options
- Relationship UI
- Companion quest chains

---

## ⏳ Phase 9: Multiplayer (OPTIONAL)
**Target Duration:** 4-6 months  
**Status:** ⏳ Not Started (May be cut)

### Features:
- Co-op mode (2-4 players)
- Netcode implementation
- Turn synchronization
- Shared loot
- Host migration

**Note:** Only if time/budget allows and community wants it.

---

## ⏳ Phase 10: Polish & Launch
**Target Duration:** 3-4 months  
**Status:** ⏳ Not Started

### Month 1-2: Polish
- Bug fixing
- Balance pass (combat, loot, XP)
- Performance optimization
- UI/UX improvements
- Accessibility features

### Month 3: Marketing
- Steam page setup
- Trailer creation
- Press kit
- Discord community
- Social media presence

### Month 4: Launch
- Early Access launch on Steam
- Community management
- Patch deployment
- Gather feedback for Zone 2

### Deliverables:
- Stable, polished game
- Steam Early Access launch
- Marketing materials
- Active community

---

## 🎯 Long-Term (Year 2+)

### DLC/Updates:
- **Update 1 (6 months post-launch):** Zone 2 - The Desert Wastes
- **Update 2 (12 months post-launch):** Zone 3 - The Frozen North
- **Update 3 (18 months post-launch):** 4 Advanced Classes (Ranger, Paladin, Warlock, Bard)
- **Updates 4-9:** Zones 4-9
- **Final Update:** Cross-zone mega crisis

### Full Release:
- All 9 zones complete
- 200+ hours of content
- Price: $35-40

---

## 📊 Timeline Summary
```
Year 1:
├─ Q1: Phases 2-3 (Refactor + Character Systems)
├─ Q2: Phases 4-5 (Combat + Magic)
├─ Q3: Phase 6 (Crafting)
└─ Q4: Phase 7 (Zone 1) + Early Access Launch

Year 2:
├─ Q1-Q2: Zone 2 Development
├─ Q3: Zone 2 Launch
└─ Q4: Zone 3 Development

Year 3+:
└─ Zones 3-9 + Full Release
```

---

**Last Updated:** [Date]
