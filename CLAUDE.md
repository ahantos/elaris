# Elaris - Project Context

## Quick Summary
**Elaris (Dungeon Delver)** — Grid-based, turn-based dungeon crawler RPG using D&D 5e rules. Built in Godot 4.5 with GDScript.

**Elevator Pitch:** "Hades meets Battle Brothers meets classic D&D"

## Tech Stack
- **Engine:** Godot 4.5 (exe: `C:\Users\Akos\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe`)
- **Language:** GDScript
- **Architecture:** Manager-based, 22 autoload singletons, EventBus signal hub
- **Resolution:** 1920x1080

## IMPORTANT: Architecture Contracts
`docs/ARCHITECTURE_CONTRACTS.md` is the binding reference for system boundaries, data
schemas (spells/quests/dialogues/recipes/effects/companions/zones), item-id naming,
equipment slot strings, save-format rules (primitives only), and UI panel conventions.
Read it before modifying any system.

## Validation
Per-script `--check-only` false-positives on autoload names — do NOT use it. Validate with:
```
& "C:\Users\Akos\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe" --headless --path "C:\Users\Akos\Documents\GitHub\elaris" --quit-after 30
```
Pass = exit 0 + no `SCRIPT ERROR` lines.

## Autoloads (project.godot order)
| Autoload | Purpose |
|---|---|
| EventBus | Signal hub (all cross-system events; ~90 signals) |
| GameManager | Game state, settings, player/world/dungeon refs, short/long rests |
| ItemDatabase | 20 materials, 263 generated items (lazy id regeneration), use_consumable, starting kits |
| CombatManager | d20 rolls, crits, cover/flanking/status-aware attacks, saves, reactions/opportunity attacks |
| InventoryManager | Party inventory, gold, weight, equipment (multi-slot rings/trinkets), primitive save format |
| SaveManager | Multi-slot saves, format v2 (all systems), v1-tolerant |
| ClassDatabase | 4 classes (.tres) with spell slot tables, hit dice |
| RaceDatabase | 5 races (.tres) incl. half_orc |
| SkillDatabase | 18 D&D skills → governing stats |
| SpellDatabase | 82 spells, 8 schools, lv 0-9 + scroll_/wand_ item registration |
| RecipeDatabase | 115 recipes across forge/alchemy_table/enchanting_table/cooking_fire |
| LootManager | Loot tables (goblin/skeleton/bandit/wolf/boss/default), level-scaled tiers |
| StatusEffectManager | 17 effects, ticks, modifier queries (AC/speed/advantage/incapacitation) |
| SpellManager | Known spells, slots, casting, concentration, scrolls/wands, enchanting, pending-cast |
| CraftingManager | can_craft/craft/repair, enchant recipes target equipped items |
| DialogueManager | Dialogue trees: choices, skill checks, conditions, effects |
| QuestManager | 8 quests + procedural generator; auto-advances from EventBus |
| FactionManager | 3 factions, reputation -100..100, status thresholds |
| WorldEventManager | 6 random events + lich_king_rises crisis (4 phases) |
| ZoneManager | 9 zones (zone_1 The Borderlands active), travel, biome mapping |
| CompanionManager | 4 companions (2 romanceable), relationships, gifts, party (cap 3) |
| UIManager | Exclusive full-screen panel registry; owns pause; ESC closes |

## Key Scene Scripts
- `scripts/world.gd` — coordinator: combat loop (await-recursive with re-entrancy guards), panel registration, hotkeys, loot/XP on kill, zone travel, companion spawning, load resync
- `scripts/grid_character.gd` — player: WASD + click-move, attacks (pass nodes for status/cover), spell-targeting click flow, step-on loot pickup, turn hooks
- `scripts/enemy.gd` — A* AI, enemy_type/enemy_level, turn hooks, opportunity attacks
- `scripts/companion.gd` — allied follower node (acts in player's initiative slot)
- `scripts/combat_grid.gd` — static LoS (Bresenham), cover AC bonus, flanking, Chebyshev distance
- `scripts/ground_item.gd` — dropped-loot node (GroundItem.spawn / pickup)
- `ui/*.gd` — code-built panels: spellbook, crafting, quest_log, world_map, dialogue, companions, character_creation (+ combat_log)

## Keymap
| Key | Action |
|---|---|
| WASD | Move (exploration) |
| Click / Ctrl+Click / RMB | Move-preview & confirm / waypoint / cancel (click casts when a spell is pending) |
| T / Space | Toggle turn-based / end turn |
| 1 / 2 / 3 | Light (1d4) / Medium (1d8) / Heavy (1d12) attack |
| Esc | Cancel attack/pending spell; close open panel |
| I | Character screen (equipment/inventory; right-click item = use) |
| B / C / J / O / P / N | Spellbook / Crafting / Quest log / World map / Companions / Character creation |
| Y | Talk to the Reeve of Brackenford (placeholder dialogue entry; starts main quest) |
| F7 / F8 | Short / long rest (out of combat) |
| G / M / R | Grid overlay / minimap fog / regenerate dungeon |
| F5 / F6 | Save / load menu |

## Conventions (enforced — see contracts doc)
- Tabs; docstrings; print logging with system prefixes; push_error for programmer errors
- No class_name on autoloads; data registries in code (not .tres), except classes/races
- Managers never write CharacterStats fields directly (StatusEffectManager pattern)
- Save payloads are primitives only; item instances rebuild via ItemDatabase ids
- New combat-path timers must be pause-bound: `create_timer(t, false)`
- Preserve hardening: is_instance_valid after awaits, re-entrancy guards in turn flow
- Node name "World" and player node name are load-bearing (cached lookups, death routing)

## Current State (after 2026-06-11/12 full-systems build-out)
All Phase 2-8 SYSTEMS are built, integrated, and validated headless (zero script errors;
19/19 gameplay-probe checks). Content is intentionally placeholder: balance untested,
zones 2-9 skeletal, minimal quest/dialogue volume.

### Known gaps / next steps
1. Balance pass (damage/HP/XP/prices/drop rates are placeholder numbers)
2. NPCs are not world nodes — dialogue entry is the Y hotkey; needs town/NPC placement
3. Companions: not in initiative tracker (act in player's slot); enemies never target them; their pathing ignores enemy occupancy
4. Spells: ally-targeting resolves on player; cones/lines approximated as radii; reaction spells (shield/counterspell) not trigger-wired
5. Crafting stations not placed in world (all stations in one panel)
6. Save: mid-combat state not persisted (warned); loaded position not validated against regenerated dungeon
7. Character screen is standalone (predates UIManager) — migration optional
8. Phase 9 multiplayer: skipped (roadmap marks optional)
9. Cosmetic: duplicate death prints; ObjectDB leak warnings at quit (Resource registries)

## Documentation
- `docs/ARCHITECTURE_CONTRACTS.md` — system contracts (BINDING)
- `DESIGN_OVERVIEW.md` — game design doc
- `ROADMAP.md` — phases (see status update at top)
- `CURRENT_WORK.md` / `CHANGELOG.md` — session tracking
