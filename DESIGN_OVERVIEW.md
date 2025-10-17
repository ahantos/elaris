# Dungeon Delver - Design Overview

**Version:** 0.2.0 (Refactor Phase)  
**Last Updated:** [Current Date]  
**Status:** Pre-Alpha / Refactoring  

---

## 🎯 Core Vision

A grid-based, turn-based dungeon crawler RPG inspired by D&D 5e rules, combining handcrafted storylines with procedurally generated content for infinite replayability.

**Elevator Pitch:**  
"Hades meets Battle Brothers meets classic D&D - explore a vast continent zone by zone, experience deep stories, and fight tactical turn-based battles using real D&D 5e rules."

**Target Audience:**
- D&D/TTRPG fans who want solo dungeon crawling
- Tactics RPG players (XCOM, Fire Emblem fans)
- Roguelike fans who want more narrative (Hades, Dead Cells)
- Classic CRPG fans (Baldur's Gate, Divinity)

**Platform:** PC (Steam)  
**Engine:** Godot 4.x  
**Development:** Solo/Small Team  

---

## 🌍 World & Setting

**The Continent of [Your World Name]**

A single massive continent divided into **9 distinct zones**, each with its own:
- Geography and climate
- Cultural identity and factions
- 2-3 major cities
- Handcrafted storylines
- Zone-wide crisis event (endgame)
- Procedural dungeons for replayability

**Lore Foundation:**  
Based on an existing D&D campaign world with rich history, established factions, and deep lore. The game explores [time period/event] of this world's history.

**Tone:**  
Dark fantasy with moments of levity. Tactical and challenging, but fair. Player choices matter.

---

## 🗺️ Zone Design Philosophy

### Structure: "Onion Layers of Difficulty"

Each zone is accessible from Level 1, but contains multiple difficulty layers:
```
ZONE STRUCTURE:
┌─────────────────────────────────────┐
│  OUTER RING (Beginner)              │  Levels 1-10
│  - Starting towns/villages          │  Safe exploration
│  - Easy procedural quests           │  Tutorial content
│  - Low-level enemies                │
│  ┌───────────────────────────────┐  │
│  │  MIDDLE RING (Mid-Game)       │  │  Levels 10-25
│  │  - Main cities                │  │  Core content
│  │  - Story quests               │  │  Medium danger
│  │  - Medium dungeons            │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  INNER RING (Late-Game) │  │  │  Levels 25-35
│  │  │  - Ancient ruins        │  │  │  High danger
│  │  │  - Elite enemies        │  │  │  Legendary loot
│  │  │  ┌─────────────────┐    │  │  │
│  │  │  │  CORE (Endgame) │    │  │  │  Level 35+
│  │  │  │  - Crisis events│    │  │  │  Zone boss
│  │  │  │  - Zone boss    │    │  │  │  Best rewards
│  │  │  └─────────────────┘    │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Key Benefits:**
- ✅ No artificial level gates - explore anywhere from Level 1
- ✅ Natural difficulty progression (venture deeper = harder)
- ✅ High replayability (start in different zones)
- ✅ Player freedom (choose your own path)
- ✅ Each zone feels complete at all player levels

---

## 🏰 The 9 Zones (Summary)

### **Zone 1: The Borderlands** (Base Game Launch)
- **Theme:** Traditional fantasy, forests, human kingdoms
- **Geography:** Mixed forests, caves, rolling hills
- **Cities:** Ironhold (starting), Silverwood (mid), Blackstone Keep (late)
- **Factions:** Royal Guard, Thieves Guild, Order of Light
- **Enemies:** Goblins, bandits, wolves, undead
- **Crisis Event:** "The Lich King Rises" (undead invasion)
- **Status:** First zone to be developed

### **Zone 2: The Desert Wastes**
- **Theme:** Scorching desert, ancient ruins, nomadic tribes
- **Geography:** Sand dunes, oases, canyons, buried tombs
- **Enemies:** Scorpions, mummies, sand elementals, bandits
- **Crisis Event:** "The Sand Worm Awakens" (colossal beast)
- **Status:** Planned (DLC/Update 1)

### **Zone 3: The Frozen North**
- **Theme:** Eternal winter, viking-inspired culture
- **Geography:** Snow, glaciers, frozen lakes, ice caves
- **Enemies:** Ice trolls, frost wyrms, barbarians, yetis
- **Crisis Event:** "The Ice Dragon" (eternal winter spreads)
- **Status:** Planned (DLC/Update 2)

### **Zones 4-9:** [To be designed - placeholders for now]
- Zone 4: [Concept TBD]
- Zone 5: [Concept TBD]
- Zone 6: [Concept TBD]
- Zone 7: [Concept TBD]
- Zone 8: [Concept TBD]
- Zone 9: [Concept TBD]

### **Cross-Zone Crisis** (Final Endgame)
Once all zones are released:
- **"The Cataclysm"** - Continent-wide event affecting all 9 zones
- Requires completing objectives across multiple zones
- Ultimate challenge for max-level parties
- Best rewards in the entire game

---

## 🎮 Core Gameplay Loop

### **Exploration Phase** (Real-Time)
```
Enter Town → Accept Quests → Travel to Dungeon → Explore (WASD/Click)
```
- Free movement with WASD or click-to-move
- Grid-based pathfinding with A* algorithm
- Discover secrets, loot chests, read lore notes
- Trigger random events and encounters

### **Combat Phase** (Turn-Based)
```
Encounter Enemy → Press T (Enter Combat) → Take Turns → Victory/Defeat
```
- Grid-based tactical combat
- D&D 5e rules (d20 rolls, AC, advantage, reactions)
- Action economy: Movement + Action + Bonus Action per turn
- Positioning matters (flanking, cover, terrain)

### **Progression Loop**
```
Complete Quests → Gain XP/Gold/Loot → Level Up → Get Better Gear → 
Tackle Harder Content → Repeat
```

### **Endgame Loop**
```
Complete Zone Story → Trigger Crisis Event → Defend Zone → 
Repeat Crisis (scalable difficulty) → Infinite Replayability
```

---

## ⚔️ Combat System (D&D 5e Rules)

### **Core Mechanics**

**Attack Resolution:**
```
1. Roll d20 + Attack Bonus
2. Compare to Target's AC (Armor Class)
3. If hit: Roll damage dice + modifiers
4. Apply damage to HP
```

**Critical Hits & Fumbles:**
- Natural 20 (crit): Double damage dice
- Natural 1 (fumble): Automatic miss

**Advantage/Disadvantage:**
- Roll 2d20, take higher (advantage) or lower (disadvantage)
- Sources: Flanking, status effects, terrain, abilities

**Action Economy (Per Turn):**
- **Movement:** Up to movement speed (based on stats)
- **Action:** Attack, cast spell, use item, dash, disengage
- **Bonus Action:** Special abilities, second attack (if class allows)
- **Reaction:** Opportunity attacks, counterspell, etc. (Phase 4)

**Combat Features:**
- Positioning matters (flanking, cover, high ground)
- Line of sight and range calculations
- Area of effect spells
- Status effects (poisoned, stunned, etc.)
- Terrain hazards (fire, acid, traps)

---

## 📊 Character System

### **Core Stats (D&D 5e)**

**The Six Abilities:**
- **STR (Strength):** Melee damage, carrying capacity, athletic checks
- **DEX (Dexterity):** Ranged attacks, AC, initiative, stealth
- **CON (Constitution):** HP per level, concentration saves
- **INT (Intelligence):** Wizard spells, knowledge checks, investigation
- **WIS (Wisdom):** Cleric/Druid spells, perception, insight
- **CHA (Charisma):** Persuasion, intimidation, Bard/Warlock spells

**Derived Stats:**
- **HP:** CON modifier × level + base HP
- **AC:** 10 + DEX modifier + armor bonus
- **Initiative:** DEX modifier + d20
- **Proficiency Bonus:** +2 at level 1, increases every 4 levels
- **Carrying Capacity:** STR × 15 lbs

### **Leveling (1-40)**
- Level 1-10: Early game (tutorial, basics)
- Level 11-20: Mid game (core content)
- Level 21-30: Late game (challenging content)
- Level 31-40: Endgame (crisis events, ultimate challenges)

**XP Progression:**
- Kill enemies: XP based on enemy level/difficulty
- Complete quests: Fixed XP rewards
- Discover locations: Exploration XP
- Milestone leveling for story quests

---

## 🧙 Classes (8 Total)

### **Phase 3 Launch Classes (4 Core):**

**1. Fighter** (Tank/DPS)
- Role: Frontline warrior, high HP, multiple attacks
- Primary: STR/DEX, Secondary: CON
- Playstyle: Straightforward, reliable damage

**2. Wizard** (Ranged Caster)
- Role: AOE damage, crowd control, utility
- Primary: INT, Secondary: DEX
- Playstyle: Glass cannon, spell slots management

**3. Rogue** (Stealth/DPS)
- Role: Single-target burst, mobility, skills
- Primary: DEX, Secondary: CHA
- Playstyle: Sneak attack, cunning action

**4. Cleric** (Healer/Support)
- Role: Healing, buffs, divine magic
- Primary: WIS, Secondary: CON
- Playstyle: Keep party alive, utility spells

### **Phase 5+ Advanced Classes (4 More):**

**5. Ranger** (Ranged/Pet)
- Role: Archery, animal companion, tracking
- Primary: DEX/WIS, Secondary: CON

**6. Paladin** (Tank/Support)
- Role: Melee tank with healing, smite attacks
- Primary: STR/CHA, Secondary: CON

**7. Warlock** (Caster/DPS)
- Role: Eldritch blasts, pact magic, dark powers
- Primary: CHA, Secondary: CON

**8. Bard** (Support/Face)
- Role: Buffs, inspiration, jack-of-all-trades
- Primary: CHA, Secondary: DEX

**Class Features:**
- Unique ability trees per class
- Subclasses at level 3 (e.g., Fighter → Champion vs Battle Master)
- Class-specific equipment restrictions
- Spellcasting (prepared vs known spells)

---

## 🧝 Races (5 Total)

### **Phase 3 Launch Races:**

**1. Human**
- Bonus: +1 to all stats
- Feature: Extra skill proficiency
- Lore: Versatile, adaptable, most common race

**2. Elf**
- Bonus: +2 DEX, +1 INT
- Feature: Darkvision, resistance to charm
- Lore: Ancient, magical, long-lived

**3. Dwarf**
- Bonus: +2 CON, +1 STR
- Feature: Poison resistance, stonecunning
- Lore: Tough, crafters, underground dwellers

**4. Halfling**
- Bonus: +2 DEX, +1 CHA
- Feature: Lucky (reroll 1s), small size
- Lore: Nimble, lucky, cheerful

**5. Half-Orc**
- Bonus: +2 STR, +1 CON
- Feature: Relentless endurance (survive lethal blow)
- Lore: Strong, intimidating, savage heritage

**Race Impact:**
- Starting stat modifiers
- Unique racial abilities
- Dialogue options (some NPCs react differently)
- Height/weight affects carrying capacity

---

## ⚔️ Equipment System

### **Material Tiers**

Equipment quality based on materials:

| Tier | Material | Damage Mult | Armor Mult | Value Mult | Rarity |
|------|----------|-------------|------------|------------|--------|
| 1 | Wood/Cloth | 1.0x | 1.0x | 1x | Common |
| 2 | Bronze | 1.1x | 1.1x | 3x | Common |
| 3 | Iron | 1.25x | 1.25x | 5x | Uncommon |
| 4 | Steel | 1.5x | 1.5x | 10x | Uncommon |
| 5 | Silver | 1.75x | 1.5x | 20x | Rare |
| 6 | Mithril | 2.0x | 2.0x | 50x | Rare |
| 7 | Adamantine | 2.5x | 2.5x | 100x | Epic |
| 8 | Dragon Bone | 3.0x | 3.0x | 500x | Legendary |

### **Equipment Slots**

**Per Character:**
- Head (helmet, hat, crown)
- Chest (armor, robe)
- Hands (gloves, gauntlets)
- Legs (greaves, pants)
- Feet (boots)
- Main Hand (weapon, staff, wand)
- Off Hand (shield, second weapon, tome)
- Neck (amulet)
- Ring 1
- Ring 2
- Back (cloak, cape)

### **Weapon Types**

**Melee:**
- Simple: Dagger (1d4), Club (1d6), Quarterstaff (1d6)
- Martial: Longsword (1d8), Greatsword (2d6), Warhammer (1d8)

**Ranged:**
- Simple: Shortbow (1d6), Crossbow (1d8)
- Martial: Longbow (1d8), Heavy Crossbow (1d10)

**Magic:**
- Wands (focus for casters)
- Staves (focus + melee weapon)
- Tomes (spell books)

### **Armor Types**

**Light Armor:** (DEX-based AC)
- Padded, Leather, Studded Leather
- AC = 11-13 + DEX modifier

**Medium Armor:** (DEX limited)
- Hide, Chain Shirt, Scale Mail
- AC = 12-15 + DEX modifier (max +2)

**Heavy Armor:** (No DEX bonus)
- Ring Mail, Chain Mail, Plate
- AC = 14-18 (fixed)

### **Enchanting System** (Phase 5)
- Add magical properties to equipment
- Socket gems for stat bonuses
- Prefix/Suffix system (e.g., "Flaming Longsword of Haste")
- Upgrade materials improve enchantments

---

## 🎒 Inventory System

### **Party Inventory (Shared)**
- All 4 party members share one inventory
- Gold is pooled
- Weight limit based on total party STR

**Weight System:**
- Carrying Capacity = (Sum of all party members' STR × 15) lbs
- Over capacity = movement penalties
- Gold weight: 50 coins = 1 lb

**Item Management:**
- Stackable consumables (potions, scrolls)
- Unique items (equipment, quest items)
- Sorting by: name, weight, value, type
- Filter by item type

### **Loot System**
- Random loot from enemies (loot tables by enemy type)
- Chests with tiered loot (common → legendary)
- Boss-specific drops (guaranteed epic/legendary)
- Material drops for crafting

---

## 🔨 Crafting System (Phase 6)

### **Crafting Stations**
- Forge: Weapons, armor, tools
- Alchemy Lab: Potions, elixirs, poisons
- Enchanting Table: Magical enhancements
- Cooking Fire: Food, buffs

### **Recipe System**
- Discover recipes through:
  - Looting recipe scrolls
  - Buying from vendors
  - Experimenting (trial and error)
  - Quest rewards

### **Material Quality**
- Better materials = better results
- Steel sword > Iron sword > Bronze sword
- Rare materials unlock unique properties

### **Durability** (Optional)
- Equipment degrades with use
- Repair at blacksmith or with repair kits
- Legendary items don't break (or very slow degradation)

---

## ✨ Magic System (Phase 5)

### **Spell Slots** (D&D 5e System)
- Spellcasters have spell slots by level
- Slots consumed when casting spells
- Regain on rest (long rest = full recovery)

**Spell Slot Progression:**
```
Level 1: 2 × 1st level slots
Level 3: 4 × 1st, 2 × 2nd level slots
Level 5: 4 × 1st, 3 × 2nd, 2 × 3rd level slots
... (follows D&D 5e progression)
```

### **Spell Schools**
- Evocation (damage, blasting)
- Abjuration (protection, wards)
- Conjuration (summoning)
- Transmutation (buffs, alterations)
- Enchantment (mind control, charm)
- Illusion (tricks, deception)
- Necromancy (death, undead)
- Divination (knowledge, foresight)

### **Spell Types**
- **Cantrips:** Unlimited use, low power (e.g., Fire Bolt)
- **Leveled Spells:** Use spell slots, powerful (e.g., Fireball)
- **Rituals:** Cast without spell slot, takes 10 minutes
- **Concentration:** Can only maintain one at a time

### **Scrolls**
- Single-use spell items
- Any class can use scrolls (if they can read)
- Found as loot or crafted by scribes

---

## 🏛️ Faction System (Phase 7)

### **Faction Types**

**Major Factions (Per Zone):**
- 3-4 major factions per zone
- Each has unique questlines (10-15 quests)
- Reputation system (Hostile → Neutral → Friendly → Honored)
- Faction-specific rewards and vendors

**Examples (Zone 1):**
- **Royal Guard:** Lawful, protect citizens, hunt criminals
- **Thieves Guild:** Chaotic, stealth missions, underworld
- **Order of Light:** Religious, hunt undead, heal sick
- **Mercenary Company:** Neutral, contracts for coin

### **Reputation System**
```
Hostile (-1000 to -500): Attacked on sight
Unfriendly (-500 to 0): Refuse service, high prices
Neutral (0 to 500): Basic service, normal prices
Friendly (500 to 2000): Discounts, side quests unlocked
Honored (2000 to 5000): Best prices, unique rewards
Exalted (5000+): Legendary items, faction home base access
```

**Reputation Changes:**
- Complete faction quests: +50 to +200
- Kill faction members: -100 to -500
- Betray faction: -1000 (instant Hostile)
- Opposing factions: Gain rep with one, lose with rival

### **Faction Rewards**
- Unique equipment (faction armor sets)
- Faction mounts/pets
- Safe houses and storage
- Discounts at faction vendors
- Allied NPCs join you in crisis events

---

## 💑 Social System (Phase 8)

### **Companion System**
- 12+ recruitable companions (4 active party members)
- Each companion has:
  - Unique personality and backstory
  - Personal quest chain
  - Relationship meter (friendship/romance)
  - Combat AI and abilities

### **Relationship Mechanics**
- Companions react to player choices
- Gain/lose relationship based on:
  - Dialogue choices
  - Quest decisions
  - Actions in combat
  - Gift-giving

### **Romance Options**
- 6 romanceable companions (3 male, 3 female)
- Relationship stages:
  - Stranger → Acquaintance → Friend → Close Friend → Romance
- Romance quests unlock at high relationship
- Multiple endings based on relationships

### **NPC Interactions**
- Dynamic dialogue based on:
  - Faction reputation
  - Completed quests
  - Party composition
  - Player choices
- Persuasion/Intimidation/Deception checks (CHA-based)
- Barter system (haggle for better prices)

---

## 🌐 Multiplayer (Phase 9 - Optional)

### **Co-op Mode (2-4 Players)**
- Each player controls 1 character
- Shared world, shared loot
- Turn-based combat (players take turns in initiative order)
- Host-migration support

### **Competitive Mode (Optional)**
- PvP arena battles
- Leaderboards for crisis events
- Time-attack dungeon runs

**Note:** Multiplayer is OPTIONAL and will only be developed if:
- Single-player is complete and polished
- There's community demand
- Budget and time allow

---

## 🎨 Art & Audio Direction

### **Visual Style**
- **Target:** 2D pixel art or low-poly 3D (TBD based on budget/skill)
- **Inspiration:** Octopath Traveler, Darkest Dungeon, Into the Breach
- **Palette:** Dark fantasy, muted colors with vibrant magic effects
- **UI:** Clean, readable, fantasy-themed

### **Audio**
- **Music:** Orchestral fantasy, dynamic (calm exploration → intense combat)
- **SFX:** Impactful combat sounds, ambient dungeon noises
- **Voice Acting:** None (too expensive) - text-only dialogue

### **Animation**
- Character sprites: Idle, walk, attack, cast, hurt, death
- Enemy sprites: Similar to characters
- VFX: Spell effects, damage numbers, environmental hazards

---

## 📅 Development Roadmap

### **Phase 1: Core Prototype** ✅ COMPLETE
- Grid-based movement
- Basic turn-based combat
- Procedural dungeon generation (5 biomes)
- Enemy AI with pathfinding
- Simple inventory and stats

### **Phase 2: Equipment Foundation** 🔄 IN PROGRESS (Refactor)
- **Day 1:** ✅ CombatManager, InventoryManager
- **Day 2:** ⏳ ClassData, RaceData, SaveManager
- **Day 3:** Material-based equipment system
- **Day 4:** Weight/encumbrance refinement
- **Day 5:** Full equipment UI (equip/unequip)

### **Phase 3: Character Systems** (3-4 months)
- 4 classes fully implemented (Fighter, Wizard, Rogue, Cleric)
- 5 races implemented
- Character creation screen
- Leveling 1-40 with ability score increases
- Skill system

### **Phase 4: Combat Expansion** (2-3 months)
- Reactions (opportunity attacks, counterspells)
- Status effects (poisoned, stunned, prone, etc.)
- Environmental hazards (fire, acid, traps)
- Advantage/disadvantage system
- Line of sight and cover mechanics
- Flanking and positioning bonuses

### **Phase 5: Magic System** (3-4 months)
- Spell slots and spell management
- 50+ spells across all schools
- Scrolls and wands
- Concentration mechanic
- Ritual casting
- Enchanting system

### **Phase 6: Crafting System** (2-3 months)
- Crafting stations (forge, alchemy, enchanting)
- 100+ recipes
- Material gathering and processing
- Durability and repair system

### **Phase 7: World & Story** (6-8 months)
- Zone 1 fully implemented:
  - 3 cities (handcrafted)
  - Main quest (10-15 missions)
  - City storylines (15 quests)
  - 3 faction questlines (30 quests)
  - 20 side quests
  - Crisis event: "The Lich King Rises"
- Procedural quest system
- Random events system
- Dialogue system with choices

### **Phase 8: Social Systems** (2-3 months)
- 12 companions (4 available for Zone 1 launch)
- Relationship system
- 6 romance options (2 for Zone 1)
- Dynamic NPC reactions
- Persuasion/Intimidation system

### **Phase 9: Multiplayer** (4-6 months, OPTIONAL)
- Netcode implementation
- Co-op mode (2-4 players)
- Host migration
- Shared loot system
- Matchmaking

### **Phase 10: Polish & Launch** (3-4 months)
- Bug fixing
- Balance pass
- UI/UX polish
- Performance optimization
- Steam integration
- Marketing materials
- Early Access launch

---

## 💰 Business Model

### **Pricing Strategy: Early Access with Growing Content**
```
Launch (Zone 1):     $15 - Early Access
After Zone 2 added:  $20 (early buyers get Zone 2 free)
After Zone 3 added:  $25 (all previous buyers get Zone 3 free)
Full Release (9 zones): $35-40 (complete edition)
```

**Why this model:**
- ✅ Rewards early adopters (lowest price, all content free)
- ✅ Fair pricing (price grows with content)
- ✅ No DLC confusion (single purchase)
- ✅ Sustainable (new sales fund development)
- ✅ Competitive ($35-40 for 200+ hours is great value)

### **Monetization:**
- ❌ No microtransactions
- ❌ No loot boxes
- ❌ No pay-to-win
- ✅ One-time purchase
- ✅ All updates free

### **Revenue Goals:**
- **Conservative:** 5,000 sales × $20 avg = $100k gross → ~$70k net (after Steam cut)
- **Moderate:** 20,000 sales × $25 avg = $500k gross → ~$350k net
- **Success:** 100,000 sales × $30 avg = $3M gross → ~$2.1M net

---

## 🎯 Success Metrics

### **Pre-Launch (Early Access):**
- ✅ Stable 60 FPS gameplay
- ✅ Zone 1 complete (20-30 hours of content)
- ✅ All Phase 1-7 systems implemented
- ✅ Positive playtester feedback
- ✅ Steam page ready with trailer

### **Launch (Early Access):**
- 🎯 1,000 sales in first week
- 🎯 "Mostly Positive" Steam reviews (70%+)
- 🎯 Active Discord community (500+ members)
- 🎯 Streamer/YouTuber coverage

### **Post-Launch (Updates):**
- 🎯 5,000+ total sales by end of Year 1
- 🎯 Zone 2 released within 6-12 months
- 🎯 "Very Positive" Steam reviews (80%+)
- 🎯 Growing community

### **Full Release:**
- 🎯 20,000+ total sales
- 🎯 All 9 zones complete
- 🎯 "Overwhelmingly Positive" reviews (90%+)
- 🎯 Cult following for potential sequel

---

## 🛠️ Technical Architecture

### **Autoload Singletons (Managers)**
- `EventBus`: Global event system (decoupled communication)
- `GameManager`: Game state, scene management, player reference
- `ItemDatabase`: Centralized item/material data
- `CombatManager`: All combat logic (d20 rolls, damage, status effects)
- `InventoryManager`: Party inventory, equipment, gold, weight
- `SaveManager`: Save/load system
- `QuestManager`: Quest tracking and progression
- `DialogueManager`: NPC conversations and choices

### **Data Resources (GDScript Classes)**
- `CharacterStats`: Character attributes, HP, AC, XP
- `MaterialData`: Material properties (damage mult, armor mult, rarity)
- `ItemData`: Item properties (type, weight, value, stats)
- `ClassData`: Class definitions (abilities, progression)
- `RaceData`: Race definitions (bonuses, features)
- `SpellData`: Spell definitions (damage, effects, slots)
- `QuestData`: Quest definitions (objectives, rewards)

### **Core Systems (Scenes & Scripts)**
- `World`: Main scene, dungeon integration, turn management
- `GridCharacter`: Player character (input, movement, combat)
- `Enemy`: Enemy behavior (AI, pathfinding, combat)
- `DungeonGenerator`: Procedural dungeon generation
- `TurnManager`: Turn-based combat orchestration
- `UIManager`: All UI elements (inventory, character sheet, etc.)

### **Design Philosophy:**
- ✅ **Manager-based architecture:** Logic in managers, not in character scripts
- ✅ **Data-driven:** Everything configurable via resources
- ✅ **Event-driven:** Decoupled systems via EventBus
- ✅ **Single responsibility:** Each script has ONE job
- ✅ **Scalable:** Easy to add new content without breaking existing systems

---

## 📝 Current Status

### **Completed:**
- ✅ Phase 1: Core Prototype
  - Grid movement (click-to-move + WASD)
  - Turn-based combat toggle
  - Procedural dungeons (5 biomes)
  - Enemy AI with A* pathfinding
  - Basic damage system
  - Minimap with fog of war

- ✅ Refactor Day 1:
  - CombatManager (D&D 5e combat system)
  - InventoryManager (party inventory, equipment)
  - Refactored GridCharacter and Enemy to use managers
  - CharacterStats system
  - Material-based items

### **In Progress:**
- 🔄 Refactor Day 2:
  - ClassData (Fighter, Wizard, Rogue, Cleric)
  - RaceData (Human, Elf, Dwarf, Halfling, Half-Orc)
  - SaveManager (save/load entire game state)

### **Next Steps:**
1. Complete Day 2 refactor
2. Define Zone 1 identity (theme, cities, story)
3. Implement character creation screen
4. Build Zone 1 content (main quest, faction quests)
5. Crisis event system (Battle Brothers style)
6. Early Access prep (trailer, Steam page, marketing)

---

## 🔗 Additional Resources

- **Full Design Document:** [DESIGN_FULL.md](DESIGN_FULL.md) (80 pages)
- **Current Work:** [CURRENT_WORK.md](CURRENT_WORK.md)
- **Roadmap:** [ROADMAP.md](ROADMAP.md)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)
- **Zone Designs:** [ZONES.md](ZONES.md)

---

## 📞 Contact & Community

- **GitHub:** [Your Repo URL]
- **Discord:** [TBD]
- **Twitter:** [TBD]
- **Steam:** [TBD]

---

**Last Updated:** [Date]  
**Next Review:** After Day 2 Refactor Complete
