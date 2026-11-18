# Architecture Contracts

Shared ids, data schemas and rules that every system in Elaris follows. When this
document and a habit disagree, the document wins; when the document is wrong, change
it in the same commit as the code.

Revised 2026-11-16. The first version was a brief for eight parallel build agents and
carried a file-ownership matrix, a report format and per-agent done-criteria. Those
are gone. Two of its rules were also reversed: UI no longer has to be built in code,
and "the boot has no script errors" is no longer what done means.

## 0. Ground rules

1. **Done means seen.** A feature is done when a player can reach it through normal
   play and it has been watched working in the running game. A manager that runs is
   not a feature.
2. **Checks.** `tools\run_checks.bat` before every commit: headless smoke test plus a
   windowed screenshot tour. A headless boot proves only that scripts parse. Do not use
   per-script `--check-only`; it false-positives on autoload names.
3. **Style.** GDScript 4.5, tab indentation, snake_case, `"""docstrings"""`, `print()`
   logging with a system prefix, `push_error()` for programmer errors. No `class_name`
   on autoload scripts. Prefix intentionally unused parameters with `_`.
4. **Signals.** Cross-system events go through `autoload/event_bus.gd`. Add a signal
   there when one is needed.
5. **Stats discipline.** Managers keep per-character runtime state in their own
   dictionaries keyed by the `CharacterStats` instance. They do not write
   `CharacterStats` fields directly.
6. **Save discipline.** Every stateful manager implements `to_dict() -> Dictionary` and
   `from_dict(data)`. Payloads hold only primitives (String, int, float, bool, Array,
   Dictionary), never Resources, Nodes or object references. Item instances serialize
   as `{item_id, quality_modifier, magic_modifier, current_durability, stack_count}`
   and are rebuilt through `ItemDatabase`.
7. **Content lives in code registries** (plain Dictionaries registered in `_ready()` or
   in helper files under `data/<system>/`), except classes and races, which are `.tres`.
   This will change when the content pipeline is built (Phase 7).
8. **Content references are validated.** `tools/content_validator.gd` walks every
   registry. A reference to an id that does not exist fails the smoke test unless it is
   listed, with a reason, in `KNOWN_GAPS` in `tools/smoke_test.gd`.
9. **Autoload order** is `project.godot` order: databases, then managers, then
   UIManager. A `_ready()` may call earlier autoloads freely; for later ones, defer.
10. **Tool scripts** started with `--script` are compiled before the autoloads exist.
    They reach managers with `root.get_node("Name")`, never by global name.

## 1. Rules learned the hard way

- **Layout.** On a Control that is already in the tree, use
  `set_anchors_and_offsets_preset()`. `set_anchors_preset()` changes the anchors and
  keeps the current rectangle, which in `_ready()` is 0x0. Every panel of the first
  build was invisible for this reason.
- **Resources are not Dictionaries.** `Object.get()` takes one argument. Item instances
  are Dictionaries (`.get("key", default)` is fine); the `item_data` inside them is an
  `ItemData` Resource (read `item_data.item_id` directly).
- **Engine singletons are not autoloads.** `Engine.has_singleton("GameManager")` is
  always false. Use the autoload name.
- **Units.** `CharacterStats.movement_speed` is feet (30 = 6 tiles). Encumbrance
  penalties are feet. `get_modified_movement_speed()` returns tiles;
  `get_modified_speed_feet()` returns feet. `CharacterStats.FEET_PER_TILE` is 5.
- **Never lose an item.** Anything the game hands the player (crafted, rewarded, given
  in dialogue, found in an event) goes through `InventoryManager.add_item_or_drop()`,
  which drops it at the player's feet when the bag refuses it. Ground loot the bag
  refuses stays on the ground.
- **Player-facing messages** go out as `EventBus.ui_notification(message, type)` with
  type `info`, `success`, `warning` or `error`. `ui/notification_toasts.gd` draws them.
- **Party-only rules** check `InventoryManager.is_party_member(stats)`. Encumbrance
  applies to the party, not to every creature that rolls a die.
- **Pause-bound timers** in the combat path: `create_timer(t, false)`. After every
  await, check `is_instance_valid` and that combat is still running.

## 1a. Game flow and saves

- **Three scenes.** `scenes/main_menu.tscn` (the main scene),
  `scenes/character_creation_screen.tscn`, `scenes/world.tscn`. `GameManager` owns
  every transition: `begin_character_creation()`, `start_new_game(stats)`,
  `load_game(slot)`, `continue_game()`, `go_to_main_menu()`.
- **Starting the world.** Before changing to the World scene, GameManager fills
  `pending_start` (`{"mode": "new", "stats": ...}` or `{"mode": "load", "slot", "data"}`).
  `World._ready()` consumes it. With nothing pending (the scene run on its own from
  the editor or a tool) the world starts a default fighter and does not autosave.
- **Every stateful manager has `reset()`** and is listed in
  `GameManager.STATEFUL_MANAGERS`. `reset_game_state()` runs before a new game, before
  a load and on the way to the menu. A new manager that keeps per-game state must add
  both, or its state will leak into the next game.
- **Loading never patches a running game.** It resets everything and starts a fresh
  World scene that rebuilds itself from the save data.
- **Who owns what in a save.** SaveManager owns the file, the format version and the
  managers' `to_dict` / `from_dict`. The World scene owns its own part:
  `World.get_world_state()` on save and `World._restore_from_save()` on load.
  SaveManager never touches scene nodes.
- **Seeds.** `DungeonGenerator.generate_dungeon(seed)` must depend only on the seed and
  the biome. Layout code draws from the generator's own `_rng`; rendering must not use
  random state at all. Starting enemies are rolled from a generator seeded by the
  dungeon seed.
- **Format changes.** Bump `SaveManager.SAVE_FORMAT_VERSION` and add a `_migrate_vN_to_vM`
  step that only adds what the new version introduced. Never change the meaning of an
  existing key.
- **When saving is allowed** is decided in one place, `SaveManager.can_save()`: not in
  combat, not after death.
- **Death.** `GridCharacter.die()` leaves the node in the scene and calls
  `GameManager.game_over()`. Code that used `is_instance_valid(player)` to mean "the
  player is alive" must use `World._player_alive()` or check `stats.is_alive()`.
- **Checks and saves.** Tool scripts call `SaveManager.use_save_directory()` with a
  scratch folder before anything else, so they can never touch real saves.

## 2. Shared identifiers and conventions

### 2.1 Character identity
- Runtime: key per-character state by the `CharacterStats` instance.
- Persistence: `CharacterStats.character_uid` (`"player"` for the player,
  `"companion_<id>"` for companions). Save by uid, resolve back on load.
- Combat entities are Nodes (`GridCharacter`, `Enemy`, `Companion`) each exposing
  `.stats` (CharacterStats) and `.grid_position` (Vector2i). APIs that need position or
  damage take the Node; APIs about knowledge or resources take the CharacterStats.
  Phase 2 replaces the three scripts with one combatant base.

### 2.2 Equipment slot strings (exact)
`head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, main_hand, off_hand, ranged`
plus multi-slots `rings`, `trinkets` (InventoryManager stores Arrays for those two).
`ItemData.equip_slot` uses exactly these strings (`rings` and `trinkets` are plural).

### 2.3 Item id scheme
- Material variants: `"{material_id}_{base_id}"`, for example `iron_longsword`,
  `leather_jerkin`, `steel_helmet`.
- Plain-base aliases: `"{base_id}"` (`longsword`, `chain_mail`) registered as the
  default-material version, because class starting kits use plain ids.
- Weapon bases: dagger, shortsword, longsword, greatsword, handaxe, battleaxe,
  greataxe, mace, warhammer, spear, quarterstaff, club, shortbow, longbow,
  light_crossbow, heavy_crossbow.
- Armour bases (slot): helmet (head), chain_mail (chest), chestplate (chest),
  gauntlets (hands), greaves (legs), plate_boots (feet), shield (off_hand); leather:
  leather_cap (head), jerkin (chest), gloves (hands), leggings (legs), boots (feet);
  cloth: hood (head), robe (chest), wraps (hands), pants (legs), slippers (feet).
- Accessories: `ring_*`, `amulet_*`, `cloak_*`, `belt_*`, `trinket_*`.
- Consumables: `potion_healing_minor`, `potion_healing`, `potion_healing_greater`,
  `antidote`, food ids (`bread`, `cooked_meat`, ...).
- Crafting materials as items: `material_{material_id}`.
- Spell items, registered at runtime by SpellDatabase: `scroll_{spell_id}`,
  `wand_{spell_id}`.
- `ItemDatabase.get_item(item_id)` re-creates any generatable id on demand, so saves
  and recipes never dangle. Generation is deterministic per id.

### 2.4 Damage types
Data uses strings: `physical, slashing, piercing, bludgeoning, fire, cold, lightning,
acid, poison, necrotic, radiant, force, psychic`.
`CombatManager.damage_type_from_string(name)` maps to the `DamageType` enum (unknown
becomes PHYSICAL). The type is not yet used when damage is applied (Phase 2).

### 2.5 Skills (canonical ids)
`athletics; acrobatics, sleight_of_hand, stealth; arcana, history, investigation,
nature, religion; animal_handling, insight, medicine, perception, survival; deception,
intimidation, performance, persuasion`.

### 2.6 Factions, zones, stations, rests
- Factions: `merchants_guild`, `order_of_dawn`, `gravewardens`. Reputation runs -100 to
  100; statuses `hostile | unfriendly | neutral | friendly | allied` at -50 / -10 / +10
  / +50.
- Zones: `zone_1` to `zone_9`; `zone_1` is The Borderlands. Each maps to a dungeon biome
  (`house | cave | dungeon | crypt | forest`).
- Crafting stations: `forge`, `alchemy_table`, `enchanting_table`, `cooking_fire`.
- Rests: `GameManager.take_short_rest()` / `take_long_rest()` emit
  `EventBus.rest_taken("short" | "long")`. SpellManager restores slots and
  StatusEffectManager clears non-permanent effects on a long rest.

## 3. Data schemas (Dictionaries)

**Status effect:**
`{effect_id, display_name, kind: "buff"|"debuff", tick: {timing: "turn_start"|"turn_end", damage_dice: "1d4", damage_type: String, heal_dice: String} (optional), modifiers: {ac: int, speed_tiles: int, attack_advantage: bool, attack_disadvantage: bool, grants_advantage_to_attackers: bool, incapacitated: bool, no_reactions: bool} (all optional), save_to_end: {stat: String, dc: int} (optional), default_duration: int, description}`

**Spell:**
`{spell_id, display_name, level: 0-9 (0 = cantrip), school, classes: ["wizard","cleric",...], casting_time: "action"|"bonus_action"|"reaction", range_tiles: int (0 = self), target_type: "enemy"|"ally"|"self"|"point", area_radius_tiles: int (0 = single target), attack_roll: bool, save: {stat, half_on_save: bool} (optional), damage_dice, damage_type, heal_dice, applies_effect: {effect_id, duration} (optional), concentration: bool, duration_turns, description}`

**Recipe:** `{recipe_id, display_name, station, inputs: [{item_id, count}], output_item_id, output_count, gold_cost: int, required_player_level: int, auto_known: bool, description}`
Enchant recipes add `{is_enchant: true, enchant_slot, plus_level}` and have no output item.

**Quest:** `{quest_id, title, description, quest_type: "main"|"side"|"faction"|"procedural", giver_npc_id, objectives: [{objective_id, description, type: "kill"|"collect"|"reach"|"talk", target_id, required_count}], rewards: {xp, gold, items: [{item_id, quality, magic, count}], reputation: {faction_id: delta}}, next_quest_id, faction_id}`
Objectives advance from EventBus: kill from `enemy_died` (matches `enemy.enemy_type` or
"any"), collect from `item_picked_up`, talk from `dialogue_ended`, reach from
`zone_changed`. This model is replaced in Phase 4 (stages, givers, turn-in).

**Dialogue:** `{dialogue_id, npc_name, start_node: "root", nodes: {node_id: {speaker, text, choices: [{text, next: node_id|"" (end), skill_check: {skill, dc, success_next, failure_next} (optional), condition: {type: "quest_active"|"quest_completed"|"quest_not_started"|"reputation_at_least"|"relationship_at_least"|"has_item", ...} (optional), effects: [{type: "start_quest"|"give_item"|"take_item"|"give_gold"|"reputation"|"relationship"|"recruit_companion"|"start_crisis", ...}] (optional)}]}}}`

**Companion:** `{companion_id, display_name, class_id, race_id, personality, backstory, recruit_zone, recruit_dialogue_id, romanceable: bool, gift_loved: [item_id...], gift_liked: [...], gift_disliked: [...], base_stats: {str,dex,con,int,wis,cha}}`
Gift lists hold item ids, `material_*` prefixes, or `type:weapon | type:armor |
type:consumable | type:misc | type:scroll | type:cloth` tokens. Romance statuses:
`none | interested | dating | committed`.

**Zone:** `{zone_id, display_name, description, biome, danger_tier: 1-9, cities: [{city_id, name, description}], unlocked: bool}`

**Random event / crisis:** events `{event_id, display_name, description, weight, effects}`;
crisis `{crisis_id, display_name, phases: [{phase: int, name, description}]}`.

## 4. Cross-system calls

- **CombatManager** owns `roll_attack`, `roll_damage`, `apply_damage`,
  `make_saving_throw`, `roll_initiative`, `trigger_opportunity_attack`. It reads
  StatusEffectManager for advantage, AC modifiers and incapacitation, and
  `scripts/combat_grid.gd` for `has_line_of_sight`, `get_cover_ac_bonus`, `is_flanking`
  and `get_distance_tiles` (Chebyshev).
- **SpellManager** resolves casts through CombatManager and StatusEffectManager, reads
  slot tables from `ClassDatabase.get_class_data(class_id).get_spell_slots(character_level, spell_level)`,
  restores slots on `rest_taken("long")`, and grants class spells when a caster is first
  asked for its list and again on `player_leveled_up`.
- **CraftingManager** consumes through `InventoryManager.remove_item / has_item /
  get_item` and produces through `ItemDatabase.create_item_instance` and
  `InventoryManager.add_item_or_drop`.
- **QuestManager** awards through `InventoryManager.add_gold`, `add_item_or_drop`,
  `GameManager.player.stats.gain_experience` and `FactionManager.modify_reputation`.
- **CompanionManager** builds stats with `CharacterBuilder.build(class_id, race_id,
  base_stats, name)` and creates nodes with `create_companion_node(companion_id)`; the
  world spawns them on `companion_recruited`. `rejoin_party()` returns a dismissed
  companion to the party.
- **SaveManager** writes `{version: 3, game_version, timestamp, player: {stats,
  position_x, position_y}, systems: {...}, world: {seed, biome, enemies, ground_items,
  explored, companions}}`. Equipment serializes as `{character_uid: {slot:
  instance-dict, or Array for rings and trinkets}}`. See section 1a.

## 5. UI

- Full-screen panels register with `UIManager.register_panel(panel_id, panel)`, which
  owns exclusivity, pausing and ESC. Panels never touch `get_tree().paused`, and close
  themselves with `UIManager.close_panel(panel_id)`, never with `hide()`.
- Optional hooks UIManager calls: `on_panel_opened()` (refresh here), `on_panel_closed()`.
- Panel ids: `spellbook`, `crafting`, `quest_log`, `world_map`, `companions`,
  `character_creation`, `dialogue`, `pause_menu`. Panels live under the UIManager
  autoload and outlive the World scene; the next World reuses them.
- ESC: anything that uses the key for itself (cancel an attack, close the character
  sheet, the save menu or the settings overlay) marks the event handled in `_input`.
  What reaches `UIManager._unhandled_input` closes the open panel, or opens the pause
  menu when nothing is open.
- Design size is 1920x1080; the window scales it (`canvas_items`, aspect `keep`). Read
  sizes from `get_viewport_rect()`, not from the window.
- New UI should be built as scenes with a shared Theme. The existing panels are built
  in code and will be rebuilt as scenes (Phase 6); do not extend that pattern.
- After any UI change, run the screenshot tour and look at the pictures.

## 6. Art

- **Grid.** A map tile is 32x32 pixels (`ArtLibrary.TILE_SIZE`). The camera starts at
  zoom 2 and changes in whole steps; textures are drawn unfiltered
  (`default_texture_filter=0`). Scripts read the tile size from
  `dungeon_generator.tilemap.tile_set.tile_size`. Speeds and sizes written in pixels
  are for that grid.
- **One lookup.** Nothing loads art by path. `ArtLibrary` (`scripts/art_library.gd`,
  static functions) maps game ids to textures: `tile_source_id` and
  `tile_texture(biome, role, cell)`, `enemy_sprite(enemy_type)`,
  `player_sprite(class_id)`, `companion_sprite(companion_id, class_id)`,
  `item_icon(item_id)`, `loot_marker(has_items)`.
- **One manifest.** `data/art/art_manifest.gd` lists every file under `assets/` and the
  stand-in it was copied from. Files are named by role
  (`assets/tiles/crypt/floor_1.png`, `assets/sprites/enemies/goblin.png`,
  `assets/icons/items/longsword.png`); replacing the file replaces the art, with no
  code change and no build step.
- **Item icons** resolve by alias, then exact id, then base type (`steel_longsword`
  uses `longsword`), then id prefix (`scroll_`). `ItemDatabase.register_item()` fills
  `ItemData.icon` for any item that has none.
- **Missing art never crashes.** A lookup that finds nothing returns
  `ArtLibrary.fallback_texture()`, a magenta checker, and records the miss in
  `ArtLibrary.get_missing()`. The smoke test fails when a spawnable enemy type, a
  class, a companion, an item or a biome tile role has no art, so a new content id
  needs a row in the manifest.
- **Drawing never uses the random number generator.** Which tile variant a cell shows
  comes from `ArtLibrary.cell_hash(cell)`, so rendering cannot disturb a seeded
  dungeon.
- **Checklist.** `docs/ART_CHECKLIST.md` is generated by `tools/art_checklist.gd`.
  Regenerate it after changing the manifest or the item list.
- `art_source/` is source material, hidden from the engine by `.gdignore`. The game
  loads nothing from it.
