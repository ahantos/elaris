# combat_manager.gd
# AutoLoad singleton - handles all combat logic, damage calculation, attack rolls,
# saving throws, status-effect integration, positional modifiers (cover/flanking via
# CombatGrid) and the reaction framework (opportunity attacks).
extends Node

# Combat constants
const BASE_AC: int = 10  # Base armor class (10 + DEX)
const CRIT_THRESHOLD: int = 20  # Natural 20 = crit
const FUMBLE_THRESHOLD: int = 1  # Natural 1 = fumble

# Damage types
enum DamageType {
	PHYSICAL,
	SLASHING,
	PIERCING,
	BLUDGEONING,
	FIRE,
	COLD,
	LIGHTNING,
	ACID,
	POISON,
	NECROTIC,
	RADIANT,
	FORCE,
	PSYCHIC
}

# Contract damage-type strings -> DamageType enum (see ARCHITECTURE_CONTRACTS.md 2.4)
const DAMAGE_TYPE_FROM_STRING: Dictionary = {
	"physical": DamageType.PHYSICAL,
	"slashing": DamageType.SLASHING,
	"piercing": DamageType.PIERCING,
	"bludgeoning": DamageType.BLUDGEONING,
	"fire": DamageType.FIRE,
	"cold": DamageType.COLD,
	"lightning": DamageType.LIGHTNING,
	"acid": DamageType.ACID,
	"poison": DamageType.POISON,
	"necrotic": DamageType.NECROTIC,
	"radiant": DamageType.RADIANT,
	"force": DamageType.FORCE,
	"psychic": DamageType.PSYCHIC
}

# One reaction per combatant per round, keyed by instance id (safe across node frees).
# The combat orchestrator calls reset_round_reactions() when a new initiative round
# begins; the set is also cleared automatically when combat ends.
var reactions_used: Dictionary = {}

func _ready():
	EventBus.combat_ended.connect(_on_combat_ended)
	print("CombatManager initialized")

# === ATTACK SYSTEM ===

func roll_attack(attacker_stats: CharacterStats, target_stats: CharacterStats,
				 weapon: ItemData = null, advantage: bool = false,
				 disadvantage: bool = false, attacker_node: Node = null,
				 target_node: Node = null, ally_positions: Array = []) -> Dictionary:
	"""
	Roll an attack using D&D 5e rules.
	Backward compatible: existing callers pass (stats, stats, weapon[, adv, disadv]).
	Optional trailing params unlock the combat-expansion integrations:
	- attacker_node / target_node (combat Nodes exposing .stats and .grid_position):
	  * status-effect advantage/disadvantage merged in (StatusEffectManager),
	  * incapacitated attacker auto-fails (result has auto_fail = true),
	  * target AC gains StatusEffectManager.get_ac_modifier + CombatGrid cover bonus
	    (dungeon grid resolved from GameManager - gracefully skipped when missing),
	  * blessed/cursed flat attack modifiers,
	  * melee hits on paralyzed/frozen targets within 1 tile are automatic crits.
	- ally_positions: Array of Vector2i for the ATTACKER's allies; an ally on the exact
	  opposite side of the target (flanking) grants advantage. Integration decides who
	  counts as an ally and passes positions in.
	Finesse weapons ("finesse" in special_properties) use the better of STR/DEX.
	Returns: {hit, roll, total, target_ac, is_crit, is_fumble, damage, attack_bonus,
	          advantage, disadvantage, cover_bonus, flanking, auto_fail}
	"""

	if not attacker_stats or not target_stats:
		push_error("CombatManager.roll_attack: Missing attacker or target stats!")
		return {}

	var attacker_valid = attacker_node != null and is_instance_valid(attacker_node)
	var target_valid = target_node != null and is_instance_valid(target_node)

	# Incapacitated combatants (stunned/paralyzed/frozen) cannot attack at all
	if attacker_valid and StatusEffectManager.is_incapacitated(attacker_node):
		print("CombatManager: %s is incapacitated and cannot attack!" % attacker_node.name)
		return {
			"hit": false, "roll": 0, "total": 0,
			"target_ac": target_stats.armor_class,
			"is_crit": false, "is_fumble": false,
			"damage": 0, "attack_bonus": 0,
			"advantage": false, "disadvantage": false,
			"cover_bonus": 0, "flanking": false,
			"auto_fail": true
		}

	# Check for encumbrance disadvantage
	if InventoryManager.has_disadvantage_on_physical_rolls():
		disadvantage = true
		print("⚠️ Heavily encumbered! Disadvantage on attack roll")

	# Merge status-effect advantage state from both sides
	if attacker_valid or target_valid:
		var adv_state = StatusEffectManager.get_attack_advantage_state(
			attacker_node if attacker_valid else null,
			target_node if target_valid else null)
		advantage = advantage or adv_state.get("advantage", false)
		disadvantage = disadvantage or adv_state.get("disadvantage", false)

	# Positional context (null when nodes/grid positions are unavailable)
	var attacker_pos = _get_node_grid_position(attacker_node)
	var target_pos = _get_node_grid_position(target_node)
	var has_positions = attacker_pos != null and target_pos != null

	# Flanking: an ally mirrored on the far side of the target grants advantage
	var flanking = false
	if has_positions and not ally_positions.is_empty():
		flanking = CombatGrid.is_flanking(attacker_pos, target_pos, ally_positions)
		if flanking:
			advantage = true
			print("CombatManager: flanking! Advantage on the attack")

	# Roll d20 (with advantage/disadvantage)
	var roll1 = randi_range(1, 20)
	var roll2 = randi_range(1, 20) if (advantage or disadvantage) else roll1

	var roll = roll1
	if advantage and not disadvantage:  # Advantage cancels disadvantage
		roll = max(roll1, roll2)
	elif disadvantage and not advantage:
		roll = min(roll1, roll2)

	# Check for crit/fumble
	var is_crit = (roll == CRIT_THRESHOLD)
	var is_fumble = (roll == FUMBLE_THRESHOLD)

	# Calculate attack bonus (STR melee, DEX ranged, best of both for finesse)
	var attack_bonus = attacker_stats.get_str_modifier() + attacker_stats.proficiency_bonus

	if weapon and weapon.is_weapon:
		if _weapon_has_property(weapon, "finesse"):
			attack_bonus = max(attacker_stats.get_str_modifier(), attacker_stats.get_dex_modifier()) + attacker_stats.proficiency_bonus
		elif weapon.is_ranged:
			attack_bonus = attacker_stats.get_dex_modifier() + attacker_stats.proficiency_bonus
		if weapon.magic_modifier > 0:
			attack_bonus += weapon.magic_modifier

	# Flat attack-roll modifiers from status effects (blessed +2 / cursed -2)
	if attacker_valid:
		attack_bonus += StatusEffectManager.get_attack_roll_modifier(attacker_node)

	# Total attack roll
	var total = roll + attack_bonus

	# Target AC: base + status-effect AC modifiers + positional cover
	var target_ac = target_stats.armor_class
	if target_valid:
		target_ac += StatusEffectManager.get_ac_modifier(target_node)

	var cover_bonus = 0
	if has_positions:
		var dungeon_grid = _get_dungeon_grid()
		if not dungeon_grid.is_empty():
			cover_bonus = CombatGrid.get_cover_ac_bonus(attacker_pos, target_pos, dungeon_grid)
			if cover_bonus > 0:
				print("CombatManager: target has cover (+%d AC)" % cover_bonus)
	target_ac += cover_bonus

	# Check if hit
	var hit = false
	if is_crit:
		hit = true
	elif is_fumble:
		hit = false
	else:
		hit = (total >= target_ac)

	# Melee hits on helpless (paralyzed/frozen) targets within 1 tile auto-crit
	if hit and not is_crit and target_valid and has_positions:
		var is_melee = weapon == null or not weapon.is_ranged
		if is_melee and CombatGrid.get_distance_tiles(attacker_pos, target_pos) <= 1:
			if StatusEffectManager.has_effect(target_node, "paralyzed") or StatusEffectManager.has_effect(target_node, "frozen"):
				is_crit = true
				print("CombatManager: melee hit on a helpless target - automatic critical!")

	# Roll damage if hit
	var damage = 0
	if hit:
		damage = roll_damage(weapon, attacker_stats, is_crit)

	return {
		"hit": hit,
		"roll": roll,
		"total": total,
		"target_ac": target_ac,
		"is_crit": is_crit,
		"is_fumble": is_fumble,
		"damage": damage,
		"attack_bonus": attack_bonus,
		"advantage": advantage,
		"disadvantage": disadvantage,
		"cover_bonus": cover_bonus,
		"flanking": flanking,
		"auto_fail": false
	}

func roll_damage(weapon: ItemData, attacker_stats: CharacterStats, is_crit: bool = false) -> int:
	"""Roll damage for a weapon attack (crits double the dice).
	Stat bonus: STR by default, DEX for ranged weapons, best of STR/DEX for finesse."""
	var damage = 0

	if weapon and weapon.is_weapon and weapon.damage_dice != "":
		damage = roll_dice(weapon.damage_dice)
		if is_crit:
			damage += roll_dice(weapon.damage_dice)
	else:
		# Unarmed strike fallback
		damage = randi_range(1, 4)
		if is_crit:
			damage += randi_range(1, 4)

	var stat_bonus = attacker_stats.get_str_modifier()
	if weapon and _weapon_has_property(weapon, "finesse"):
		stat_bonus = max(attacker_stats.get_str_modifier(), attacker_stats.get_dex_modifier())
	elif weapon and weapon.is_ranged:
		stat_bonus = attacker_stats.get_dex_modifier()

	damage += stat_bonus
	return max(1, damage)

func roll_dice(dice_string: String) -> int:
	"""Roll dice notation: "1d6", "2d4", "1d8+2", "2d6-1", or a plain number ("3").
	Returns 0 for blank/invalid strings (with a push_error for invalid ones)."""
	var text = dice_string.strip_edges().to_lower()
	if text == "":
		return 0

	var flat_bonus = 0
	var plus_idx = text.find("+")
	var minus_idx = text.rfind("-")
	if plus_idx > 0:
		flat_bonus = int(text.substr(plus_idx + 1))
		text = text.substr(0, plus_idx)
	elif minus_idx > 0:
		flat_bonus = -int(text.substr(minus_idx + 1))
		text = text.substr(0, minus_idx)

	var parts = text.split("d")
	if parts.size() != 2:
		if text.is_valid_int():
			return int(text) + flat_bonus
		push_error("CombatManager.roll_dice: invalid dice string '%s'" % dice_string)
		return 0

	var num_dice = max(1, int(parts[0]))
	var die_size = max(1, int(parts[1]))
	var total = flat_bonus
	for i in range(num_dice):
		total += randi_range(1, die_size)
	return total

func damage_type_from_string(type_name: String) -> int:
	"""Map a contract damage-type string ("fire", "slashing", ...) to the DamageType
	enum. Unknown strings map to PHYSICAL (see ARCHITECTURE_CONTRACTS.md 2.4)."""
	return DAMAGE_TYPE_FROM_STRING.get(type_name.to_lower().strip_edges(), DamageType.PHYSICAL)

func apply_damage(target: Node, amount: int, damage_type: int = DamageType.PHYSICAL, attacker: Node = null, is_critical: bool = false) -> bool:
	"""Apply damage to target, returns true if still alive"""
	if not target:
		push_error("CombatManager.apply_damage: No target provided!")
		return false

	# Check if target has stats property
	if not target.get("stats") or not target.stats:
		push_error("CombatManager.apply_damage: Target '%s' has no CharacterStats!" % target.name)
		return false

	var still_alive = target.stats.take_damage(amount)

	if attacker:
		EventBus.damage_dealt.emit(attacker, target, amount, is_critical)

	if not still_alive:
		handle_death(target)

	return still_alive

func handle_death(target: Node):
	"""Handle character/enemy death"""
	print("%s has died!" % target.name)

	# Emit event first
	if target.name.begins_with("Player") or target.name == "Character" or target is GridCharacter:
		EventBus.character_died.emit(target)
	else:
		EventBus.enemy_died.emit(target)

	# Call the target's die() function if it has one
	if target.has_method("die"):
		target.die()
	else:
		# Fallback: just remove from scene
		target.queue_free()

func roll_initiative(character_stats: CharacterStats) -> int:
	"""Roll initiative (d20 + DEX modifier)"""
	return randi_range(1, 20) + character_stats.get_dex_modifier()

# === SAVING THROWS ===

func make_saving_throw(character_stats: CharacterStats, stat: String, dc: int,
					   advantage: bool = false, disadvantage: bool = false,
					   target_node: Node = null) -> Dictionary:
	"""
	Make a saving throw (d20 + modifier vs DC).
	Backward compatible: existing callers pass (stats, stat, dc[, adv, disadv]).
	Optional target_node (the combat Node the stats belong to) unlocks status effects:
	- incapacitated (stunned/paralyzed/frozen) auto-fails DEX saves (auto_fail = true),
	- restrained imposes disadvantage on DEX saves,
	- blessed/cursed add +2/-2 to the save total (reported as status_modifier).
	Returns: {success, roll, total, dc, modifier, status_modifier, auto_fail}
	"""

	if not character_stats:
		push_error("CombatManager.make_saving_throw: No character stats provided!")
		return {}

	var stat_key = stat.to_lower()
	var is_dex_save = stat_key in ["dex", "dexterity"]
	var node_valid = target_node != null and is_instance_valid(target_node)

	# Incapacitated creatures can't dodge - DEX saves auto-fail
	if node_valid and is_dex_save and StatusEffectManager.is_incapacitated(target_node):
		print("CombatManager: %s is incapacitated - DEX save automatically fails!" % target_node.name)
		return {"success": false, "roll": 0, "total": 0, "dc": dc, "modifier": 0, "status_modifier": 0, "auto_fail": true}

	# Restrained creatures dodge poorly
	if node_valid and is_dex_save and StatusEffectManager.has_effect(target_node, "restrained"):
		disadvantage = true

	# Check for encumbrance disadvantage on physical saves (STR, DEX, CON)
	if stat_key in ["str", "strength", "dex", "dexterity", "con", "constitution"]:
		if InventoryManager.has_disadvantage_on_physical_rolls():
			disadvantage = true
			print("⚠️ Heavily encumbered! Disadvantage on %s save" % stat.to_upper())

	var modifier = 0

	match stat_key:
		"str", "strength": modifier = character_stats.get_str_modifier()
		"dex", "dexterity": modifier = character_stats.get_dex_modifier()
		"con", "constitution": modifier = character_stats.get_con_modifier()
		"int", "intelligence": modifier = character_stats.get_int_modifier()
		"wis", "wisdom": modifier = character_stats.get_wis_modifier()
		"cha", "charisma": modifier = character_stats.get_cha_modifier()

	# Add proficiency if proficient in this save
	if character_stats.is_proficient_in_save(stat):
		modifier += character_stats.proficiency_bonus

	# Flat save modifiers from status effects (blessed +2 / cursed -2)
	var status_modifier = 0
	if node_valid:
		status_modifier = StatusEffectManager.get_save_modifier(target_node)

	# Roll d20 with advantage/disadvantage
	var roll1 = randi_range(1, 20)
	var roll2 = randi_range(1, 20) if (advantage or disadvantage) else roll1

	var final_roll = roll1
	if advantage and not disadvantage:
		final_roll = max(roll1, roll2)
	elif disadvantage and not advantage:
		final_roll = min(roll1, roll2)

	var total = final_roll + modifier + status_modifier
	var success = total >= dc

	return {
		"success": success,
		"roll": final_roll,
		"total": total,
		"dc": dc,
		"modifier": modifier,
		"status_modifier": status_modifier,
		"auto_fail": false
	}

# === REACTIONS ===

func trigger_opportunity_attack(reactor: Node, mover: Node) -> Dictionary:
	"""
	Attempt an opportunity attack from `reactor` against `mover` (who is about to leave
	the reactor's melee reach). The orchestrator calls this from combat movement when a
	combatant steps from a tile adjacent to a hostile to a tile that is not.
	Checks performed here: both nodes valid + alive, reactor's reaction not yet used
	this round, reactor can take reactions (status effects), mover currently adjacent
	(Chebyshev distance exactly 1).
	On success: rolls a full melee roll_attack with the reactor's equipped main-hand
	weapon (fallback: the node's own create_temp_weapon(); ranged weapons are ignored
	in favor of an unarmed strike), applies damage on a hit, consumes the reaction and
	emits EventBus.reaction_triggered(reactor, "opportunity_attack", mover).
	A missed opportunity attack still consumes the reaction.
	Returns {triggered: bool, reason: String, result: Dictionary (attack result if rolled)}.
	"""
	if reactor == null or not is_instance_valid(reactor) or not reactor.get("stats"):
		return {"triggered": false, "reason": "invalid_reactor", "result": {}}
	if mover == null or not is_instance_valid(mover) or not mover.get("stats"):
		return {"triggered": false, "reason": "invalid_mover", "result": {}}
	if not reactor.stats.is_alive() or not mover.stats.is_alive():
		return {"triggered": false, "reason": "dead_combatant", "result": {}}
	if reactions_used.get(reactor.get_instance_id(), false):
		return {"triggered": false, "reason": "reaction_already_used", "result": {}}
	if not StatusEffectManager.can_take_reactions(reactor):
		return {"triggered": false, "reason": "cannot_react", "result": {}}

	var reactor_pos = _get_node_grid_position(reactor)
	var mover_pos = _get_node_grid_position(mover)
	if reactor_pos == null or mover_pos == null:
		return {"triggered": false, "reason": "no_grid_position", "result": {}}
	if CombatGrid.get_distance_tiles(reactor_pos, mover_pos) != 1:
		return {"triggered": false, "reason": "not_adjacent", "result": {}}

	var weapon = _resolve_reaction_weapon(reactor)
	if weapon != null and weapon.is_ranged:
		weapon = null  # opportunity attacks are melee - fall back to an unarmed strike

	print("CombatManager: %s makes an opportunity attack against %s!" % [reactor.name, mover.name])
	reactions_used[reactor.get_instance_id()] = true

	var result = roll_attack(reactor.stats, mover.stats, weapon, false, false, reactor, mover)
	if result.is_empty():
		return {"triggered": false, "reason": "roll_failed", "result": {}}

	if result.get("hit", false):
		var damage_type = DamageType.PHYSICAL
		if weapon and weapon.damage_type != "":
			damage_type = damage_type_from_string(weapon.damage_type)
		print("CombatManager: opportunity attack hits for %d damage!" % result.damage)
		apply_damage(mover, result.damage, damage_type, reactor, result.is_crit)
	else:
		print("CombatManager: opportunity attack misses (%d vs AC %d)" % [result.get("total", 0), result.get("target_ac", 0)])

	EventBus.reaction_triggered.emit(reactor, "opportunity_attack", mover)
	return {"triggered": true, "reason": "ok", "result": result}

func reset_round_reactions():
	"""Clear the once-per-round reaction tracker. The combat orchestrator calls this
	whenever a new initiative round begins; also runs automatically on combat_ended."""
	reactions_used.clear()

func _on_combat_ended(_victory: bool):
	"""Reactions never persist outside combat."""
	reset_round_reactions()

# === INTERNAL HELPERS ===

func _weapon_has_property(weapon: ItemData, property_name: String) -> bool:
	"""Check a weapon's special_properties array (e.g. "finesse", "reach", "thrown")."""
	if weapon == null:
		return false
	return property_name in weapon.special_properties

func _get_node_grid_position(node: Node):
	"""Vector2i grid position of a combat node, or null when unavailable."""
	if node == null or not is_instance_valid(node):
		return null
	var pos = node.get("grid_position")
	if pos is Vector2i:
		return pos
	return null

func _get_dungeon_grid() -> Array:
	"""Resolve the active dungeon's [y][x] tile grid for cover/LoS checks.
	Tries GameManager.current_dungeon first, then GameManager.world.current_dungeon
	(world.gd keeps its own reference and does not call set_dungeon yet).
	Returns [] when no dungeon is available - callers skip cover/LoS gracefully."""
	var dungeon = GameManager.current_dungeon
	if dungeon == null or not is_instance_valid(dungeon):
		var world = GameManager.world
		if world != null and is_instance_valid(world):
			dungeon = world.get("current_dungeon")
	if dungeon != null and is_instance_valid(dungeon):
		var grid = dungeon.get("dungeon_grid")
		if grid is Array:
			return grid
	return []

func _resolve_reaction_weapon(reactor: Node) -> ItemData:
	"""Best weapon for a reaction: the equipped main-hand weapon when available,
	otherwise the node's own create_temp_weapon() fallback (the player variant takes
	an attack-type argument; enemy/companion variants take none). Returns null for an
	unarmed strike when nothing else is available."""
	if reactor.get("stats"):
		var equipped = InventoryManager.get_equipped_item(reactor.stats, "main_hand")
		if equipped is Dictionary and not equipped.is_empty():
			var item_data = equipped.get("item_data", null)
			if item_data is ItemData and item_data.is_weapon:
				return item_data
	if reactor is GridCharacter:
		return reactor.create_temp_weapon("medium")
	if reactor.has_method("create_temp_weapon"):
		return reactor.create_temp_weapon()
	return null
