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
  scratch folder before anything else, so they can never touch real saves. The folder
  is named after the run's process id and removed when the run ends: `user://` is
  shared by every checkout of the project, and two runs must not share a folder.

## 2. Shared identifiers and conventions

### 2.1 Character identity
- Runtime: key per-character state by the `CharacterStats` instance.
- Persistence: `CharacterStats.character_uid` (`"player"` for the player,
  `"companion_<id>"` for companions). Save by uid, resolve back on load.
- Combat entities are Nodes that extend `Combatant` (`scripts/combatant.gd`):
  `GridCharacter` (the player), `Enemy`, `Companion`. Each exposes `.stats`
  (CharacterStats), `.grid_position` (Vector2i) and `.team` (`Combatant.Team.PARTY` or
  `HOSTILE`). APIs that need position or damage take the Node; APIs about knowledge or
  resources take the CharacterStats.
- **Hostility is by team.** Ask `a.is_hostile_to(b)`, `combatant.get_hostiles()` or
  `get_ally_positions()`. Do not test membership of `world.enemies` or compare with
  the player; `world.enemies` and `world.companion_nodes` remain as the world's own
  bookkeeping (spawning, saving). Enemy AI still picks only the player as its target,
  and a companion's move provokes no opportunity attack: nothing may hurt a companion
  until companions have death rules.
- **Alive is `combatant.is_alive()`**, not `is_instance_valid`: the player's body stays
  in the scene after death.
- **What the base owns:** grid conversion (`grid_to_world`, `world_to_grid`,
  `spawn_at`, `teleport_to_grid`), `is_walkable` (a floor or door tile no other
  combatant stands on), `find_path` (the only A* in the project), `take_damage`,
  `flash_damage`, `draw_hp_bar`, `animate_attack`, opportunity-attack checks on
  leaving a hostile's reach, and the turn interface the combat controller calls:
  `is_player_controlled()`, `take_turn()`, `on_combat_started()`,
  `on_combat_ended()`, `follow_path(tiles)`. For the HUD it answers
  `is_aiming_attack()` and `get_aim_preview()` (section 5). A subclass that
  overrides `_ready()` calls `super._ready()` first. What a combatant does on its
  turn stays in the subclass, and it does it by asking:
  `combatant.request_action(action_id, params)` (section 4).
- **Turn resources live on the base** (5e): `movement_left` and `movement_granted`
  (tiles), `action_used`, `bonus_action_used`, `reaction_used`, and the two states a
  turn can leave behind, `disengaged` and `dodging` (ask `is_dodging()`). The
  controller hands them out with `refresh_turn_resources()` when the combatant's turn
  starts - movement from `get_turn_speed()`, the action, the bonus action and the
  reaction back, a Dodge over - and `expire_turn_resources()` when it ends (unused
  movement gone, a Disengage over). Only the controller and CombatManager spend them.
  Walking spends a tile of movement per tile reached while `is_taking_turns()` (a
  fight; for the player also the turn mode outside one). The action economy exists
  only in a fight.
- **Weapons.** `get_melee_weapon()` is the melee weapon in the main hand (null: an
  unarmed strike) and `get_ranged_weapon()` the weapon in the `ranged` slot (null:
  none). `get_wielded_weapon()` is what is in hand when no target has been named:
  the melee weapon; without one, the ranged weapon; with neither, null. Which of
  them an attack uses depends on the target (section 4). Enemies answer with a
  stand-in 1d6 melee weapon and carry no ranged weapon (`Enemy.ranged_weapon` is
  null) until the bestiary. `is_off_hand_free()` and `get_flank_partners()` complete
  what an attack needs to know (enemies have no flank partners yet).
- The world lists the combatants in the scene: `World.get_combatants()`,
  `get_combatant_at(tile)`, `is_tile_occupied(tile, exclude)`.

### 2.2 Equipment slot strings (exact)
`head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, main_hand, off_hand, ranged`
plus multi-slots `rings`, `trinkets` (InventoryManager stores Arrays for those two).
`ItemData.equip_slot` uses exactly these strings (`rings` and `trinkets` are plural).
`InventoryManager.equip_item()` refuses a two-handed weapon in the main hand while the
off hand holds something, and anything in the off hand beside a two-handed weapon.

### 2.3 Item id scheme
- Material variants: `"{material_id}_{base_id}"`, for example `steel_longsword`,
  `cowhide_jerkin`, `wrought_iron_helmet`. Every base exists in every material of
  its kind (a metal base in every metal).
- Plain-base aliases: `"{base_id}"` (`longsword`, `chain_mail`) registered as the
  default-material version, because class starting kits use plain ids. The defaults
  (`ItemDatabase.DEFAULT_MATERIALS`): wrought iron, oak, cowhide, fine linen.
- Weapon bases: dagger, shortsword, longsword, greatsword, handaxe, battleaxe,
  greataxe, mace, warhammer, spear, rapier, quarterstaff, club, shortbow, longbow,
  light_crossbow, heavy_crossbow. They follow the 5e SRD weapon table
  (`ItemDatabase.WEAPON_BASES`). A weapon item carries `weapon_type` (its base id),
  `weapon_category` (`simple` or `martial`), `damage_dice`, `damage_type`,
  `is_two_handed`, `is_ranged`, and `special_properties` (`finesse`, `versatile`,
  `thrown`); a versatile weapon also has `versatile_dice`, its dice in both hands.
  A ranged weapon has `range_normal` and `range_max`, **in tiles** (one tile is 5
  feet): a shortbow's 16 and 64 are the 5e 80 and 320 feet. Read them through
  `CombatManager.get_weapon_range(weapon)`, the one place that knows the unit. All
  four ranged bases are two-handed and go in the `ranged` slot.
  `CharacterStats.is_proficient_with_weapon(weapon)` reads proficiency from the class
  data and the character's own list, by category or by base id.
- Armour bases (slot), `ItemDatabase.ARMOR_BASES`: metal: helmet (head), chestplate,
  chain_mail, scale_mail (chest), gauntlets (hands), greaves (legs), plate_boots
  (feet), shield (off_hand); leather: leather_cap (head), jerkin (chest), gloves
  (hands), leggings (legs), boots (feet); cloth: hood (head), robe (chest), wraps
  (hands), pants (legs), slippers (feet). What they do for armour class is in 2.3b.
- Accessories: `ring_*`, `amulet_*`, `cloak_*`, `belt_*`, `trinket_*`.
- Consumables: `potion_healing_minor`, `potion_healing`, `potion_healing_greater`,
  `antidote`, food ids (`bread`, `cooked_meat`, ...).
- Crafting materials as items: `material_{material_id}`.
- Spell items, registered at runtime by SpellDatabase: `scroll_{spell_id}`,
  `wand_{spell_id}`.
- `ItemDatabase.get_item(item_id)` re-creates any generatable id on demand, so saves
  and recipes never dangle. Generation is deterministic per id.
- **Renamed materials.** `ItemDatabase.MATERIAL_ALIASES` maps the material ids of the
  old list to what they became (iron to wrought_iron, mithril to mythril, adamantine
  to adamantite, hide to pigskin, leather to cowhide, linen to fine_linen).
  `get_material()` and `get_item()` follow it, so `iron_longsword` in an old save is
  the wrought iron longsword, and it is saved under its new id from then on. No save
  migration is involved. `canonical_item_id(id)` gives the id the database knows an
  item by. Content must use that id: gift lists, quest targets and dialogue
  conditions compare ids as text, and the content validator fails on a retired one.
- An item instance carries its own `quality_modifier` (craftsmanship) and
  `magic_modifier`. Rules read them from the instance, never from the `ItemData`
  template: `ItemDatabase.get_instance_bonus(instance)` is the higher of the two.

### 2.3a Materials
A material (`MaterialData`, registered in `ItemDatabase.load_materials()`) sets how an
item wears, what it costs and one trait. It never changes damage, armour class,
weight or any other number of the item.

| Field | Meaning |
|---|---|
| `category` / `get_kind()` | `metal`, `wood`, `leather`, `cloth` |
| `durability_score` | the score in Ákos's material tables |
| `notches` | `durability_score` / 8, rounded half up, at least 2 (`MaterialData.notches_for`) |
| `hardness` | one scale for all four kinds |
| `price_multiplier` | an item's `base_value` is its base type's price times this |
| `trait_id` | `rusts_easily`, `silvered`, `warm`, ... or `""`. Data only: no trait has an effect yet. (`trait` is a reserved word in GDScript.) |
| `stage` | 1: can drop, be bought and be crafted (`is_obtainable()`). 0: defined, and an item made of it loads and works, but nothing hands it out |

Stage one is 24 materials, six of each kind. Mythril and adamantite are defined at
stage 0, as are the eight materials of the old list that have no equivalent yet.
Loot categories pick only obtainable materials, a dearer one less often (weight 1 /
price multiplier); the content validator fails on a loot entry, recipe, starting kit
or reward that names an item of a material that cannot be obtained. Nothing wears
yet: notches and hardness are shown on the tooltip and used from step 5.

### 2.3b Armour class
5e rules, worked out in `CharacterStats.apply_equipment_bonuses()` from what is worn
and stored in `CharacterStats.armor_class`:

**AC = body armour base + Dexterity modifier as the armour allows + shield + the
armour's and the shield's own bonus + magic that grants AC.** Unarmoured: 10 +
Dexterity.

| Chest base | 5e armour | `armor_type` | `armor_base` | Dexterity | Strength | Stealth |
|---|---|---|---|---|---|---|
| `robe` | clothes | `""` | 0 (unarmoured, 10) | full | | |
| `jerkin` | leather | `light` | 11 | full | | |
| `scale_mail` | scale mail | `medium` | 14 | at most +2 | | disadvantage |
| `chain_mail` | chain mail | `heavy` | 16 | none | 13 | disadvantage |
| `chestplate` | plate | `heavy` | 18 | none | 15 | disadvantage |

- A shield (`armor_type` `shield`, `armor_class_bonus` 2) adds 2.
- **No other slot gives armour class**: head, shoulder, back, wrist, hands, waist,
  legs, feet. Helmets, gauntlets, greaves and boots have `armor_type` `""`, no base
  and no bonus. They stay in the game; their job comes in a later phase.
- Body armour and a shield add the higher of their own craftsmanship and magic bonus.
- Magic that grants AC says so in `ItemData.stat_bonuses` (`{"ac": 1}`: the ring and
  the cloak of protection) and counts from any slot.
- A wearer below the body armour's Strength requirement is 10 feet slower
  (`CharacterStats.is_slowed_by_armor()`, applied in `get_modified_speed_feet()`).
- Body armour needs the class's proficiency for its category and a shield needs
  `shields` (`CharacterStats.is_proficient_with_armor`; SRD: fighter all, cleric
  light, medium and shields, rogue light, wizard none). Without it
  (`wears_untrained_armor()`): disadvantage on attack rolls and no spellcasting
  (`SpellManager.can_cast` refuses). Clothes and the other slots need no proficiency.
- `get_armor_class_breakdown()` gives the parts as `[{label, value}]`; the character
  sheet shows them. Status effects and cover are added at the moment of an attack.
- `armor_class` is a stored field, recalculated by `recalculate_derived_stats()`.
  An enemy has no equipment: 10 + its Dexterity modifier, until the bestiary.

### 2.4 Damage types
Data uses strings: `physical, slashing, piercing, bludgeoning, fire, cold, lightning,
acid, poison, necrotic, radiant, force, psychic`.
`CombatManager.damage_type_from_string(name)` maps to the `DamageType` enum (unknown
becomes PHYSICAL). Damage is applied with its type: a weapon attack with the
weapon's, an unarmed strike as bludgeoning, a spell or a status tick with its own.
`EventBus.damage_dealt(attacker, target, amount, is_critical, damage_type)` carries
it. Nothing reads the type yet: resistance and vulnerability come with the damage
pipeline (Phase 2 step 4).

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

- **CombatController** (`scripts/combat_controller.gd`, a Node under World, reached as
  `world.combat`) is the one authority for whose turn it is and what may be done
  with it. It is not an autoload: it lives and dies with the World scene, so it needs
  no `reset()`.
  - It owns the initiative order (Combatants, highest roll first, companions rolling
    like everyone else), the turn-holder, the round count, handing out each turn's
    resources (section 2.1), and starting and ending a fight.
  - Read it with `active`, `current_combatant()`, `is_turn_of(combatant)`,
    `get_order()`, `get_initiative(combatant)`, `round_number`.
  - **Everything done with a turn is a request.**
    `request_action(combatant, action_id, params) -> Dictionary` is the one entry
    point; `combatant.request_action(action_id, params)` is the same call from the
    combatant's side. The controller checks that it is the combatant's turn, that the
    action, bonus action or movement it costs is still there and that the action is
    legal; then it applies it and returns `{ok, action, reason, ...}`. A refusal
    changes nothing and says why in `reason` (`final: true` when asking again with
    another target would not help). Player input, enemy AI and companion AI all act
    this way; input and UI code never change game state, roll a die or spend a
    resource themselves. `check_action(combatant, action_id, params)` answers
    `{ok, reason}` without applying anything; the action bar uses it.

    | `action_id` | `params` | Costs | Adds to the result |
    |---|---|---|---|
    | `attack` | `{target: Combatant}` | action | the `CombatManager.make_attack` result (`hit`, `damage`, `damage_type`, `is_crit`, `weapon_name`, `is_ranged`, `advantage`, `disadvantage`, `reasons`, `cover_bonus`, `distance`, ...), `target` |
    | `dash` | | action | `movement_added` |
    | `disengage` | | action | |
    | `dodge` | | action | |
    | `cast` | `{spell_id, target: Combatant or Vector2i}` | the spell's `casting_time` (`action` or `bonus_action`) | `cast`: the SpellManager result |
    | `use_item` | `{item: instance}` | action | `cast` for a scroll or wand |
    | `move` | `{path: Array[Vector2i]}` from the combatant's tile | a tile of movement per tile | `steps` |
    | `end_turn` | | | |

    In a fight a request is approved only on the combatant's own turn. Outside a
    fight nothing is spent and there is no turn to wait for: items, moves and spells
    on oneself are free, and `attack`, `dash`, `disengage` and `dodge` are refused
    ("Not in combat"). A `reaction` spell cannot be cast yet.
  - **An attack is one weapon attack on a hostile, and the weapon follows the
    target.** An adjacent target: the melee weapon in the main hand, or an unarmed
    strike. A target beyond reach: the ranged weapon the combatant carries, when the
    target is within the weapon's maximum range and in line of sight
    (`CombatGrid.has_line_of_sight`). With nothing but a ranged weapon an adjacent
    target is shot, or struck unarmed when the weapon cannot be fired. Refused, with
    the reason: a target beyond reach and no ranged weapon; beyond the maximum
    range; out of sight; a two-handed weapon, melee or ranged, beside a full off
    hand. What is in the main hand never stops a shot: drawing and stowing a weapon
    is the free object interaction, and there is no weapon-swap action. Any
    combatant attacks this way; the weapons come from `get_melee_weapon()` and
    `get_ranged_weapon()`.
  - An attack is resolved at once: the roll and the damage happen inside the
    request. A melee attack shows its floating number at once. A ranged one sends
    a `Projectile` (`scripts/projectile.gd`: drawn in code, display only, moved in
    `_process` so it stands still while the game is paused) from the attacker to
    the target, and the number appears when it lands. A hostile that is attacked
    from outside the fight joins it (`add_combatant`).
  - `get_attack_targets(combatant)` lists the living hostiles the combatant could
    attack from where it stands, by weapon, reach, range and line of sight; it says
    nothing about the turn. `preview_attack(combatant, target)` is what attacking
    one target would be: `{ok, reason}` as `check_action` answers it, plus `target`,
    `profile`, `weapon_name`, `damage_text`, `distance` and `hit_chance` (the
    `CombatManager.get_hit_chance` answer). Neither changes anything or rolls a
    die; they are what the targeting display draws.
  - **Anything that acts in a fight asks first.** `Combatant.can_act()` is true outside
    a fight and, inside one, only for the turn-holder. Never keep a second idea of
    whose turn it is (a flag, an index in a UI widget).
  - `ACTION_BAR` lists the seven actions of the action bar in button and key order.
  - A fight starts by itself when a living hostile is within `detection_range` of the
    player; hostiles within `activation_range` join, with the whole party.
    `start_combat(participants)` starts one explicitly. `add_combatant()` brings a
    latecomer in; `remove_combatant()` takes out one that died or left. Neither changes
    whose turn it is, and a combatant that dies on its own turn does not cost the next
    one its turn. `end_combat()` stops the fight; it ends by itself, after a short
    delay, when the order no longer holds two living combatants hostile to each other.
  - Turns: a player-controlled combatant gets `start_new_turn()` and keeps the turn
    until it requests `end_turn`. Everyone else gets `take_turn()`; the controller
    waits for the move to finish, pauses, and passes the turn on. Status-effect turn
    hooks are still called by the combatant itself; an enemy runs its end-of-turn
    hooks after its attack, whether or not it moved first.
  - Signals: `combat_started(combatants)`, `combat_ended(victory)`,
    `turn_started(combatant)`, `turn_ended(combatant)`, `round_started(number)`,
    `order_changed()`, `action_taken(combatant, action_id, result)` for every
    approved request. It also emits `EventBus.combat_started(hostiles)`,
    `combat_ended(victory)`, `turn_started(combatant)` and `turn_ended(combatant)` for
    every combatant. `victory` means the party outlived every hostile in that fight.
    Outside combat (manual turn mode, T) the player emits the two turn signals itself.
  - `scripts/initiativetracker.gd`, `scripts/turn_ui.gd` and the action bar only
    draw what the controller says.
- **CombatManager** rolls every die of a fight. It owns `get_attack_profile`,
  `get_attack_modifiers`, `get_hit_chance`, `make_attack`, `roll_attack`,
  `roll_damage`, `apply_damage`, `make_saving_throw`, `roll_initiative`,
  `trigger_opportunity_attack`. It reads StatusEffectManager for advantage, AC
  modifiers and incapacitation, and `scripts/combat_grid.gd` for
  `has_line_of_sight`, `get_cover_ac_bonus`, `is_flanking` and `get_distance_tiles`
  (Chebyshev). It rolls and applies; it does not know whose turn it is.
  - `get_attack_profile(combatant, target)` is how the combatant attacks that
    target, by 5e rules, as numbers: `{weapon, weapon_name, damage_dice,
    flat_damage, damage_type, ability, ability_modifier, proficient, attack_bonus,
    two_handed_grip, is_ranged, range_normal, range_max, usable, reason}`. The
    weapon follows the target (melee in reach, ranged beyond it; see the `attack`
    request above); without a target it is the weapon in hand.
    `get_melee_profile(combatant)` and `get_ranged_profile(combatant)` (`{}` with no
    ranged weapon) give the two on their own, `get_unarmed_profile` the unarmed
    strike. Strength, or Dexterity for a finesse weapon when it is the higher, and
    always Dexterity for a ranged weapon, for the roll and the damage alike; the
    proficiency bonus only with proficiency; the larger dice of a versatile weapon
    when the off hand is empty; an unarmed strike (1 + Strength modifier,
    bludgeoning, proficient) with no weapon. `range_normal` and `range_max` are
    tiles (`get_weapon_range`). `usable` is false, with the reason, for a two-handed
    weapon, melee or ranged, beside a full off hand. `get_damage_text(profile)` is
    the damage as the player reads it ("1d8+2 slashing").
  - `get_attack_modifiers(attacker, target, profile)` is everything that bears on
    the roll before the die is cast, and why: `{advantage, disadvantage,
    advantage_reasons, disadvantage_reasons, reasons, attack_bonus, target_ac,
    cover_bonus, flanking, distance}`. Status effects on either side; a dodging
    target (disadvantage); a heavily laden party member (disadvantage); for a melee
    attack, flanking (advantage); for a ranged attack, a target beyond the weapon's
    normal range (disadvantage, "long range") and a hostile next to the attacker
    that is not incapacitated (disadvantage, "enemy adjacent"); cover from
    `CombatGrid.get_cover_ac_bonus` on the target's AC ("half cover"), which only an
    attack from beyond reach can meet. Advantage and disadvantage together cancel.
    `reasons` are words to show the player; the `REASON_*` constants name them.
  - `get_hit_chance(attacker, target, profile)` turns those modifiers into the
    chance to hit, exactly and without rolling: `{chance (0 to 1), percent, needed
    (the lowest d20 face that hits), ...the modifiers, auto_fail}`. A natural 20
    always hits and a natural 1 always misses, so the chance never leaves 5% to
    95%; advantage is the better of two dice, disadvantage the worse.
    `roll_attack` rolls with the same `get_attack_modifiers` answer, so what is
    shown is what is rolled. Interface code shows this; it never rolls.
  - `make_attack(attacker, target, profile)` is the one weapon attack, melee or
    ranged: profile, d20, damage (dice doubled on a critical hit, plus the same
    ability modifier), applied with the weapon's damage type. The Attack action
    and opportunity attacks of the player, companions and enemies all come through
    it. `roll_attack(attacker, target, profile)` rolls without applying. Neither
    judges reach, range or sight: that is the controller's check. An opportunity
    attack is always made with the melee weapon or an unarmed strike.
  - A dodging target gives the attacker disadvantage and makes Dexterity saves with
    advantage.
  - Reactions: an opportunity attack spends the reactor's `reaction_used`, which
    comes back at the start of the reactor's own turn. A combatant that has
    disengaged provokes none.
- **SpellManager** resolves casts through CombatManager and StatusEffectManager, reads
  slot tables from `ClassDatabase.get_class_data(class_id).get_spell_slots(character_level, spell_level)`,
  restores slots on `rest_taken("long")`, and grants class spells when a caster is first
  asked for its list and again on `player_leveled_up`. A spell aimed at a point takes
  the combatants hostile to the caster within the radius, and the caster itself when
  it stands there; the caster's own side is spared.
- **CraftingManager** consumes through `InventoryManager.remove_item / has_item /
  get_item` and produces through `ItemDatabase.create_item_instance` and
  `InventoryManager.add_item_or_drop`.
- **QuestManager** awards through `InventoryManager.add_gold`, `add_item_or_drop`,
  `GameManager.player.stats.gain_experience` and `FactionManager.modify_reputation`.
- **CompanionManager** builds stats with `CharacterBuilder.build(class_id, race_id,
  base_stats, name)` and creates nodes with `create_companion_node(companion_id)` (a
  `Companion`, on the party team); the world spawns them on `companion_recruited` and,
  if a fight is running, adds them to it. `rejoin_party()` returns a dismissed
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
- **The action bar** (`scenes/ui/action_bar.tscn`, `ui/action_bar.gd`; one
  `scenes/ui/action_button.tscn` per action) sits in the middle of the bottom bar
  (`scripts/bottomui.gd`). Its buttons follow `CombatController.ACTION_BAR`: Attack,
  Cast, Use Item, Dash, Disengage, Dodge, End Turn, keys 1 to 7. Every frame it asks
  `check_action()` for each and shows the answer: a button that cannot be used is
  disabled and carries the reason. A press, or the number key, goes to
  `combatant.choose_action(action_id)`, which asks the controller. Above the buttons
  it shows the turn resources of whoever holds the turn. A new action needs an id in
  the controller, a button in the scene and a title in the bar; the bar holds no
  rules of its own. A click on the bottom bar is not a click on the map. The Attack
  button names what `CombatManager` says the combatant attacks with: one weapon as
  name and damage, a melee and a ranged weapon as a line each ("Longsword 1d8+2",
  "Light Crossbow 1d8+1"). A button that can be pressed may carry a note in the
  reason's place (`show_action(..., note)`): Attack uses it for a ranged weapon that
  cannot be fired.
- **Aiming an attack.** Picking Attack (button or key 1) starts aiming; Esc or key 1
  again puts it away. While aiming, `GridCharacter` draws what the controller says
  and decides nothing: the tiles in reach, the normal and maximum range of the
  ranged weapon as outlines, a marker on every enemy in `get_attack_targets()`, and
  the enemy under the pointer picked out, in red when it cannot be attacked. The
  bar's hint line says how far each weapon reaches. The readout beside the enemy
  under the pointer is a scene of its own (`scenes/ui/attack_preview.tscn`,
  `ui/attack_preview.gd`, on a CanvasLayer the world creates): it shows
  `combatant.get_aim_preview()`, which is the controller's `preview_attack()`
  answer - the weapon, the chance to hit, the damage, the reasons for advantage or
  disadvantage and the cover, or why the enemy cannot be attacked. A click on an
  enemy sends the `attack` request; a refusal is shown and leaves the attack
  selected while someone else can still be attacked; a click on no enemy puts the
  attack away.
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
