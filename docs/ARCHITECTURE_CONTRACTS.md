# Architecture Contracts — Full-Systems Build-Out

This document is the binding contract for the parallel system-build agents (A1–A8).
Read it fully before writing code. When this doc and your instincts disagree, the doc wins.
When the doc is silent, follow existing codebase conventions and report the gap.

## 0. Ground rules (every agent)

1. **File ownership is absolute.** Edit/create ONLY files you own (matrix below). You may READ anything.
   Never edit: `project.godot`, `autoload/event_bus.gd`, another agent's files, `scenes/*.tscn`, `CLAUDE.md`.
2. **EventBus signals are pre-declared** in `autoload/event_bus.gd`. Emit/connect the ones relevant to
   your system. If you need a signal that doesn't exist, DO NOT add it — note it in your report.
3. **Style:** GDScript 4.5, TAB indentation, snake_case, docstrings `"""..."""`, `print()` logging with a
   system prefix, `push_error()` for programmer errors. NO `class_name` on autoload scripts.
   Prefix intentionally-unused parameters with `_`.
4. **Stats discipline:** Only A2 edits `CharacterStats`. Other systems track per-character runtime state
   in their OWN manager keyed by the `CharacterStats` instance (Dictionary key), and never write
   CharacterStats fields directly.
5. **Save discipline:** Every stateful manager implements `to_dict() -> Dictionary` / `from_dict(data)`.
   Save dicts contain ONLY primitives (String/int/float/bool/Array/Dictionary) — never Resources,
   Nodes, or object references. Item instances serialize as
   `{item_id, quality_modifier, magic_modifier, current_durability, stack_count}` and are rebuilt
   through `ItemDatabase`.
6. **Data lives in code registries**, like the existing materials: definitions are plain Dictionaries
   registered programmatically in `_ready()` (or loaded helper files under `data/<system>/`).
   Do NOT hand-author `.tres` files for new content (exception: A2 owns the existing class/race `.tres`).
   Append-only rule for any existing enum you extend (e.g. `ItemData.ItemType`).
7. **Placeholder content is fine; broken content is not.** Numbers don't need balance; every code path
   needs to run without errors.
8. **Autoload order** is `project.godot` order (databases before managers before UIManager). Your
   `_ready()` may call earlier autoloads freely; for SAME-WAVE autoloads later in the list, defer with
   `call_deferred()` or lazy access.
9. **Validation:** per-script `--check-only` false-positives on autoload names — do NOT use it. Validate with a full boot:
   `& "C:\Users\Akos\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe" --headless --path "C:\Users\Akos\Documents\GitHub\elaris" --quit-after 20`
   Pass = exit 0 and no `SCRIPT ERROR` lines mentioning your files. Run it before reporting done.
10. **Report format (mandatory):** (a) files created/modified, (b) public API summary, (c) EventBus
    signals emitted/listened, (d) save schema of your to_dict, (e) integration TODOs for the
    orchestrator (exact hook points), (f) signals/contracts you needed but didn't have.
11. No mutating git commands. No new dependencies. Build UI in code (no .tscn).

## 1. File ownership matrix

| Agent | Owns (create/edit) |
|---|---|
| **A1 Items & Loot** | `autoload/item_database.gd`, `autoload/loot_manager.gd`, `data/items/item_data.gd`, `data/materials/material_data.gd`, `data/items/**` (new helper files), `scripts/ground_item.gd` (new) |
| **A2 Progression** | `autoload/class_database.gd`, `autoload/race_database.gd`, `autoload/skill_database.gd`, `data/stats/character_stats.gd`, `data/stats/character_builder.gd` (new), `data/classes/**`, `data/races/**`, `ui/character_creation.gd` (new) |
| **A3 Combat Expansion** | `autoload/combat_manager.gd`, `autoload/status_effect_manager.gd`, `scripts/combat_grid.gd` (new), `data/status_effects/**` (new) |
| **A4 Magic** | `autoload/spell_database.gd`, `autoload/spell_manager.gd`, `data/spells/**` (new), `ui/spellbook_panel.gd` (new) |
| **A5 Crafting** | `autoload/recipe_database.gd`, `autoload/crafting_manager.gd`, `data/recipes/**` (new), `ui/crafting_panel.gd` (new) |
| **A6 World & Story** | `autoload/dialogue_manager.gd`, `autoload/quest_manager.gd`, `autoload/faction_manager.gd`, `autoload/world_event_manager.gd`, `autoload/zone_manager.gd`, `data/dialogues/**`, `data/quests/**`, `data/zones/**`, `data/world_events/**`, `ui/dialogue_panel.gd`, `ui/quest_log_panel.gd`, `ui/world_map_panel.gd` (all new) |
| **A7 Social** | `autoload/companion_manager.gd`, `data/companions/**` (new), `ui/companion_panel.gd` (new), `scripts/companion.gd` (new) |
| **A8 Save/Load** | `autoload/save_manager.gd`, `scripts/save_load_menu.gd` |
| **Orchestrator only** | `project.godot`, `autoload/event_bus.gd`, `autoload/game_manager.gd`, `autoload/inventory_manager.gd`, `autoload/ui_manager.gd`, `scripts/world.gd`, `scripts/grid_character.gd`, `scripts/enemy.gd`, everything else |

## 2. Shared identifiers & conventions

### 2.1 Character identity
- Runtime: key per-character state by the `CharacterStats` instance.
- Persistence: A2 adds `character_uid: String` to CharacterStats (`"player"` for the player,
  `"companion_<id>"` for companions). Save by uid, resolve back on load.
- Combat entities are NODES (`GridCharacter`, `Enemy`, future `Companion`) each exposing `.stats`
  (CharacterStats) and `.grid_position` (Vector2i). APIs that need position/damage take the Node;
  APIs about knowledge/resources take the CharacterStats.

### 2.2 Equipment slot strings (exact)
`head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, main_hand, off_hand, ranged`
plus multi-slots `rings`, `trinkets` (InventoryManager stores Arrays for those two).
`ItemData.equip_slot` must use exactly these strings (note: `rings`/`trinkets` PLURAL).

### 2.3 Item id scheme (A1 implements; everyone references)
- Material variants: `"{material_id}_{base_id}"` → `iron_longsword`, `leather_jerkin`, `steel_helmet`.
- Plain-base aliases REQUIRED: `"{base_id}"` (e.g. `longsword`, `chain_mail`) registered as the
  default-material version, because `ClassData.starting_equipment_list` uses plain ids
  (fighter: chain_mail, longsword, shield, light_crossbow, explorer_pack; wizard: quarterstaff,
  component_pouch, scholar_pack, spellbook — A1 must read cleric.tres/rogue.tres and cover those too;
  packs/pouches/spellbook = simple MISC items).
- Canonical weapon bases: dagger, shortsword, longsword, greatsword, handaxe, battleaxe, greataxe,
  mace, warhammer, spear, quarterstaff, club, shortbow, longbow, light_crossbow, heavy_crossbow.
- Canonical armor bases (slot): helmet(head), chain_mail(chest), chestplate(chest), gauntlets(hands),
  greaves(legs), plate_boots(feet), shield(off_hand); leather: leather_cap(head), jerkin(chest),
  gloves(hands), leggings(legs), boots(feet); cloth: hood(head), robe(chest), wraps(hands),
  pants(legs), slippers(feet).
- Accessories: `ring_*`, `amulet_*`, `cloak_*`, `belt_*`, `trinket_*` (e.g. `ring_protection`).
- Consumables: `potion_healing_minor`, `potion_healing`, `potion_healing_greater`, `antidote`,
  food ids (`bread`, `cooked_meat`, ...).
- Crafting materials as items: `material_{material_id}` (`material_iron`, `material_leather`, ...).
- Spell items (A4 registers at runtime via `ItemDatabase.register_item()`): `scroll_{spell_id}`,
  `wand_{spell_id}`.
- **Lazy regeneration REQUIRED:** `ItemDatabase.get_item(item_id)` must re-create any generatable id
  on demand (so saves and recipes never dangle). Generation must be deterministic per id.

### 2.4 Damage types
Data uses STRINGS: `physical, slashing, piercing, bludgeoning, fire, cold, lightning, acid, poison,
necrotic, radiant, force, psychic`. A3 adds `CombatManager.damage_type_from_string(name: String) -> int`
mapping to the existing `DamageType` enum (unknown → PHYSICAL).

### 2.5 Skills (canonical ids)
`athletics; acrobatics, sleight_of_hand, stealth; arcana, history, investigation, nature, religion;
animal_handling, insight, medicine, perception, survival; deception, intimidation, performance,
persuasion`. A2 normalizes any `.tres` values with spaces (e.g. "animal handling") to these ids.

### 2.6 Factions / zones / stations
- Factions (A6 defines 3 placeholders for Zone 1): suggested `merchants_guild`, `order_of_dawn`,
  `gravewardens` — final naming A6's choice; ids snake_case, statuses
  `hostile|unfriendly|neutral|friendly|allied` with thresholds -50/-10/+10/+50.
- Zones: `zone_1`..`zone_9`; zone_1 = "The Borderlands"; each maps to one existing dungeon biome
  (`house|cave|dungeon|crypt|forest`).
- Crafting stations: `forge`, `alchemy_table`, `enchanting_table`, `cooking_fire`.
- Rests: `EventBus.rest_taken("short"|"long")` emitted by `GameManager.take_short_rest()/take_long_rest()`.
  SpellManager restores slots on long rest; StatusEffectManager clears non-permanent effects on long rest.

## 3. Data schemas (Dictionaries)

**Status effect definition (A3):**
`{effect_id, display_name, kind: "buff"|"debuff", tick: {timing: "turn_start"|"turn_end", damage_dice: "1d4", damage_type: String, heal_dice: String} (optional), modifiers: {ac: int, speed_tiles: int, attack_advantage: bool, attack_disadvantage: bool, grants_advantage_to_attackers: bool, incapacitated: bool, no_reactions: bool} (all optional), save_to_end: {stat: String, dc: int} (optional), default_duration: int, description}`
Required effect ids (D&D staples, 15+): poisoned, stunned, prone, frightened, blinded, restrained,
paralyzed, slowed, hasted, blessed, cursed, burning, frozen, shocked, regenerating, invisible, shielded.

**Spell definition (A4):** 
`{spell_id, display_name, level: 0-9 (0 = cantrip), school, classes: ["wizard","cleric",...], casting_time: "action"|"bonus_action"|"reaction", range_tiles: int (0=self), target_type: "enemy"|"ally"|"self"|"point", area_radius_tiles: int (0 = single target), attack_roll: bool, save: {stat, half_on_save: bool} (optional), damage_dice, damage_type, heal_dice, applies_effect: {effect_id, duration} (optional), concentration: bool, duration_turns, description}`

**Recipe (A5):** `{recipe_id, display_name, station, inputs: [{item_id, count}], output_item_id, output_count, gold_cost: int, required_player_level: int, auto_known: bool, description}`

**Quest (A6):** `{quest_id, title, description, quest_type: "main"|"side"|"faction"|"procedural", giver_npc_id, objectives: [{objective_id, description, type: "kill"|"collect"|"reach"|"talk", target_id, required_count}], rewards: {xp, gold, items: [{item_id, quality, magic, count}], reputation: {faction_id: delta}}, next_quest_id, faction_id}`
Objectives auto-advance from EventBus: kill←`enemy_died` (match `enemy.enemy_type` or "any"),
collect←`item_picked_up`, talk←`dialogue_ended`, reach←`zone_changed`.

**Dialogue (A6):** `{dialogue_id, npc_name, start_node: "root", nodes: {node_id: {speaker, text, choices: [{text, next: node_id|"" (end), skill_check: {skill, dc, success_next, failure_next} (optional), condition: {type: "quest_active"|"quest_completed"|"reputation_at_least"|"relationship_at_least"|"has_item", ...} (optional), effects: [{type: "start_quest"|"give_item"|"take_item"|"give_gold"|"reputation"|"relationship"|"recruit_companion"|"start_crisis", ...}] (optional)}]}}}`

**Companion (A7):** `{companion_id, display_name, class_id, race_id, personality, backstory, recruit_zone, recruit_dialogue_id, romanceable: bool, gift_loved: [item_id...], gift_liked: [...], base_stats: {str,dex,con,int,wis,cha}}`
4 companions minimum, 2 romanceable. Romance statuses: `none|interested|dating|committed`.

**Zone (A6):** `{zone_id, display_name, description, biome, danger_tier: 1-9, cities: [{city_id, name, description}], unlocked: bool}` — all 9 zones defined, zone_1 fleshed out (3 cities), others skeletal.

**Random event / crisis (A6):** events `{event_id, display_name, description, weight, effects}`;
crisis `{crisis_id, display_name, phases: [{phase: int, name, description}]}` — define
`lich_king_rises` with 4 phases.

## 4. Cross-system API contracts

The stub files in `autoload/` already declare the exact public signatures other systems will call —
**keep every stub signature working** (you may add params with defaults and new methods freely).
Critical interactions:

- **A3 CombatManager** keeps `roll_attack`, `roll_damage`, `apply_damage`, `make_saving_throw`,
  `roll_initiative` signatures backward compatible (existing callers in grid_character/enemy).
  Integrates StatusEffectManager queries into rolls (advantage state, AC mod, incapacitation),
  and `scripts/combat_grid.gd` static helpers:
  `has_line_of_sight(from: Vector2i, to: Vector2i, dungeon_grid: Array) -> bool`,
  `get_cover_ac_bonus(from, to, dungeon_grid) -> int` (0/+2/+5),
  `is_flanking(attacker_pos, target_pos, ally_positions: Array) -> bool`,
  `get_distance_tiles(a, b) -> int` (Chebyshev).
  Reactions: framework + opportunity attacks (`can_take_reactions` gate); actual triggering hook
  is wired by the orchestrator during integration — expose
  `CombatManager.trigger_opportunity_attack(reactor: Node, mover: Node) -> Dictionary`.
- **A4 SpellManager** calls `CombatManager.apply_damage(...)`, `CombatManager.make_saving_throw(...)`,
  `StatusEffectManager.apply_effect(...)`, `ClassDatabase.get_class_data(class_id).get_spell_slots(...)`.
  Listens to `damage_dealt` for concentration CON saves; listens to `rest_taken` for slot restore.
  Spell attack bonus / save DC come from `CharacterStats.spell_attack_bonus` / `spell_save_dc`.
- **A5 CraftingManager** consumes via `InventoryManager.remove_item/has_item/get_item`,
  produces via `ItemDatabase.create_item_instance` + `InventoryManager.add_item`.
  Reference only contract item ids; if an id is missing at runtime, skip gracefully + push_error.
- **A6 QuestManager** awards via `InventoryManager.add_gold`, `InventoryManager.add_item`,
  `GameManager.player.stats.gain_experience`, `FactionManager.modify_reputation`.
- **A7 CompanionManager** builds companion stats via A2's
  `CharacterBuilder.build(class_id, race_id, base_stats, name) -> CharacterStats`.
  `scripts/companion.gd` (node) may mirror enemy.gd movement; SPAWNING is integration's job —
  provide `create_companion_node(companion_id) -> Node` and document it.
- **A2 CharacterStats additions:** `character_uid`, `character_name`, `class_id`, `race_id`,
  `skill_proficiencies: Array[String]`, ASI points, XP table to level 40
  (5e thresholds to 20, extrapolated beyond), class hit-die HP (replaces the placeholder formula in
  `recalculate_derived_stats()` — keep the function signature and the
  "derive max_hp deterministically from level/class/CON" behavior), skill check API
  (`make_skill_check` using SkillDatabase + proficiency), full `to_dict/from_dict` of ALL new fields.
  `CharacterBuilder.build()` applies class+race (use `RaceData.apply_to_character_stats`),
  emits `EventBus.character_created`.
- **A8 SaveManager** aggregates `to_dict()` from: player CharacterStats, InventoryManager,
  SpellManager, CraftingManager, QuestManager, FactionManager, WorldEventManager, ZoneManager,
  CompanionManager (+ player grid position, current save version). Versioned payload
  `{version: 2, systems: {...}}`, tolerant loader (missing keys → defaults, old saves → readable error).
  Keep `save_game(slot)/load_game(slot)/get_save_info(slot)/save_exists/delete_save` signatures;
  update save_load_menu display accordingly. Rebuild item instances through ItemDatabase ids.
  Equipment serializes as `{character_uid: {slot: instance-primitive-dict or Array for rings/trinkets}}`.

## 5. UI panel standard (A4, A5, A6, A7, A2)

- One script per panel under `ui/`, `extends Control`, **built entirely in code** in `_ready()`.
- Full-rect: `set_anchors_preset(Control.PRESET_FULL_RECT)`; dark semi-transparent backdrop;
  centered content panel; 1920x1080 design resolution.
- NEVER touch `get_tree().paused` — UIManager owns pausing.
- Optional hooks UIManager calls: `on_panel_opened()` (refresh your data here), `on_panel_closed()`.
- The orchestrator instances your panel and calls
  `UIManager.register_panel("<panel_id>", panel)` during integration. Panel ids:
  `spellbook` (A4), `crafting` (A5), `quest_log`, `world_map`, `dialogue` (A6 — dialogue registers
  with `pauses_game = true`), `companions` (A7), `character_creation` (A2).
  Document any constructor needs in your report (prefer none).
- Visual placeholders: ColorRect/Label/Button/ItemList/RichTextLabel only. No textures.

## 6. Done-criteria per agent

Your system is done when: (1) boot validation passes; (2) every public stub method is implemented
(no stub returns left); (3) your data registry has the contracted placeholder content volume
(A1: full material×base catalog + consumables + loot tables for at least `goblin`, `skeleton`,
`bandit`, `wolf`, `boss` types; A3: 15+ effects; A4: 50+ spells incl. classics across schools;
A5: recipes across all 4 stations incl. potion/food/weapon/armor/enchant lines (~100 via material
tiers is fine); A6: Zone 1 with 3 cities, 1 main quest chain (3+ quests), 2 side quests, 1 faction
quest each, procedural generator, lich_king_rises crisis, 5+ dialogues; A7: 4 companions, gift
system, relationship thresholds with 2 romances); (4) to_dict/from_dict round-trips your state;
(5) report delivered in the section-0 format.
