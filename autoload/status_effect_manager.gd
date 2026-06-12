# status_effect_manager.gd
# AutoLoad singleton - runtime status effects (poisoned, stunned, prone, ...) per combatant,
# plus the modifier queries CombatManager uses (AC/speed modifiers, advantage state, incapacitation).
# Effects NEVER write CharacterStats fields directly; all modifiers are queried from here.
# Definitions live in data/status_effects/status_effect_library.gd (see ARCHITECTURE_CONTRACTS.md).
extends Node

# Effect definitions: {effect_id: definition Dictionary} - loaded once from StatusEffectLibrary
var effect_definitions: Dictionary = {}

# Active effects per combatant: {Node: {effect_id: {duration_remaining: int, source: Node}}}
# Nodes are NOT RefCounted, so keying by Node is weak by nature; freed nodes are purged
# lazily (is_instance_valid) at the start of every public query/mutation.
var active_effects: Dictionary = {}


func _ready():
	effect_definitions = StatusEffectLibrary.get_definitions()
	EventBus.rest_taken.connect(_on_rest_taken)
	print("StatusEffects: StatusEffectManager initialized (%d effect definitions)" % effect_definitions.size())


# === EFFECT APPLICATION ===

func apply_effect(target: Node, effect_id: String, duration_turns: int = -1, source: Node = null) -> bool:
	"""Apply a status effect to a combatant. Returns false if invalid.
	duration_turns: -1 = until removed / long rest, 0 = use the effect's default_duration,
	>0 = explicit number of turns. Re-application refreshes the duration (indefinite stays
	indefinite; finite durations keep the longer of old/new)."""
	_purge_freed_targets()
	if not _is_valid_target(target):
		push_error("StatusEffectManager.apply_effect: invalid target for '%s'" % effect_id)
		return false
	if not effect_definitions.has(effect_id):
		push_error("StatusEffectManager.apply_effect: unknown effect id '%s'" % effect_id)
		return false

	var duration = duration_turns
	if duration == 0:
		duration = int(effect_definitions[effect_id].get("default_duration", -1))

	if not active_effects.has(target):
		active_effects[target] = {}

	var target_effects: Dictionary = active_effects[target]
	if target_effects.has(effect_id):
		var current = int(target_effects[effect_id].get("duration_remaining", -1))
		if current == -1 or duration == -1:
			duration = -1
		else:
			duration = max(current, duration)
		target_effects[effect_id]["duration_remaining"] = duration
		target_effects[effect_id]["source"] = source
	else:
		target_effects[effect_id] = {"duration_remaining": duration, "source": source}

	var duration_text = "until removed" if duration == -1 else "%d turns" % duration
	print("StatusEffects: %s gains '%s' (%s)" % [target.name, effect_id, duration_text])
	EventBus.status_effect_applied.emit(target, effect_id, duration)
	return true


func remove_effect(target: Node, effect_id: String):
	"""Remove a single effect from a combatant (emits status_effect_removed)."""
	_purge_freed_targets()
	if target == null or not is_instance_valid(target):
		return
	if not active_effects.has(target) or not active_effects[target].has(effect_id):
		return
	active_effects[target].erase(effect_id)
	if active_effects[target].is_empty():
		active_effects.erase(target)
	print("StatusEffects: %s loses '%s'" % [target.name, effect_id])
	EventBus.status_effect_removed.emit(target, effect_id)


func has_effect(target: Node, effect_id: String) -> bool:
	"""True when the combatant currently has the given effect."""
	_purge_freed_targets()
	if target == null or not is_instance_valid(target):
		return false
	return active_effects.has(target) and active_effects[target].has(effect_id)


func get_active_effects(target: Node) -> Array:
	"""Array of {effect_id, duration_remaining, source} dictionaries"""
	_purge_freed_targets()
	if target == null or not is_instance_valid(target) or not active_effects.has(target):
		return []
	var result: Array = []
	for effect_id in active_effects[target]:
		var entry = active_effects[target][effect_id]
		var source = entry.get("source", null)
		if source != null and not is_instance_valid(source):
			source = null
		result.append({
			"effect_id": effect_id,
			"duration_remaining": int(entry.get("duration_remaining", -1)),
			"source": source
		})
	return result


func clear_effects(target: Node):
	"""Remove every effect from a combatant (emits status_effect_removed per effect)."""
	_purge_freed_targets()
	if target == null or not is_instance_valid(target) or not active_effects.has(target):
		return
	for effect_id in active_effects[target].keys():
		remove_effect(target, effect_id)


# === TURN HOOKS (called by combat flow integration) ===

func process_turn_start(target: Node):
	"""Tick all turn_start damage/heal effects on the combatant whose turn is beginning.
	The combat orchestrator calls this when a combatant's turn starts."""
	_purge_freed_targets()
	if not _is_valid_target(target) or not target.stats.is_alive():
		return  # dead-but-not-yet-freed nodes must not tick (would re-trigger death handling)
	_process_ticks(target, "turn_start")


func process_turn_end(target: Node):
	"""End-of-turn bookkeeping for the combatant whose turn is ending:
	tick turn_end effects, roll save_to_end saves, decrement durations and expire.
	The combat orchestrator calls this when a combatant's turn ends."""
	_purge_freed_targets()
	if not _is_valid_target(target) or not active_effects.has(target):
		return
	if not target.stats.is_alive():
		return  # dead-but-not-yet-freed nodes must not tick or roll saves
	_process_ticks(target, "turn_end")
	if not is_instance_valid(target) or not active_effects.has(target):
		return

	var expired: Array = []
	for effect_id in active_effects[target].keys():
		var entry = active_effects[target][effect_id]
		var definition: Dictionary = effect_definitions.get(effect_id, {})

		# End-of-turn save to shake the effect off
		var save_to_end: Dictionary = definition.get("save_to_end", {})
		if not save_to_end.is_empty() and target.get("stats") != null:
			var save_stat = str(save_to_end.get("stat", "con"))
			var save_dc = int(save_to_end.get("dc", 10))
			var save_result = CombatManager.make_saving_throw(target.stats, save_stat, save_dc, false, false, target)
			if not save_result.is_empty() and save_result.get("success", false):
				print("StatusEffects: %s saves against '%s' (%d vs DC %d)" % [target.name, effect_id, save_result.get("total", 0), save_dc])
				expired.append(effect_id)
				continue

		# Duration countdown (-1 = until removed / long rest)
		var duration = int(entry.get("duration_remaining", -1))
		if duration > 0:
			duration -= 1
			entry["duration_remaining"] = duration
			if duration <= 0:
				expired.append(effect_id)

	for effect_id in expired:
		remove_effect(target, effect_id)


# === MODIFIER QUERIES (used by CombatManager and others) ===

func get_ac_modifier(target: Node) -> int:
	"""Flat AC delta from all active effects (e.g. shielded +5, hasted +2, slowed -2)."""
	return _sum_int_modifier(target, "ac")


func get_speed_modifier_tiles(target: Node) -> int:
	"""Movement delta in tiles (slowed -2, hasted +2, restrained/paralyzed/frozen -99).
	Callers clamp the final speed at 0."""
	return _sum_int_modifier(target, "speed_tiles")


func get_attack_roll_modifier(target: Node) -> int:
	"""Flat bonus to attack roll totals (blessed +2, cursed -2)."""
	return _sum_int_modifier(target, "attack_bonus")


func get_save_modifier(target: Node) -> int:
	"""Flat bonus to saving throw totals (blessed +2, cursed -2)."""
	return _sum_int_modifier(target, "save_bonus")


func get_attack_advantage_state(attacker: Node, defender: Node) -> Dictionary:
	"""Returns {advantage: bool, disadvantage: bool} from status effects on both sides.
	Attacker side: attack_advantage effects (invisible) grant advantage; attack_disadvantage
	effects (blinded/frightened/poisoned/prone/restrained) impose disadvantage.
	Defender side: grants_advantage_to_attackers (prone/restrained/stunned/paralyzed/
	blinded/frozen) grants advantage; grants_disadvantage_to_attackers (invisible) imposes
	disadvantage. Both can be true at once - CombatManager treats that as a straight roll."""
	var advantage = false
	var disadvantage = false
	if attacker != null and is_instance_valid(attacker):
		if _any_bool_modifier(attacker, "attack_advantage"):
			advantage = true
		if _any_bool_modifier(attacker, "attack_disadvantage"):
			disadvantage = true
	if defender != null and is_instance_valid(defender):
		if _any_bool_modifier(defender, "grants_advantage_to_attackers"):
			advantage = true
		if _any_bool_modifier(defender, "grants_disadvantage_to_attackers"):
			disadvantage = true
	return {"advantage": advantage, "disadvantage": disadvantage}


func is_incapacitated(target: Node) -> bool:
	"""True when any active effect incapacitates (stunned, paralyzed, frozen)."""
	return _any_bool_modifier(target, "incapacitated")


func can_take_reactions(target: Node) -> bool:
	"""False when incapacitated or under a no_reactions effect (shocked, stunned, ...)."""
	if target == null or not is_instance_valid(target):
		return false
	return not (is_incapacitated(target) or _any_bool_modifier(target, "no_reactions"))


# === DEFINITION ACCESS ===

func get_effect_definition(effect_id: String) -> Dictionary:
	"""Deep copy of an effect definition ({} for unknown ids)."""
	if not effect_definitions.has(effect_id):
		return {}
	return effect_definitions[effect_id].duplicate(true)


func get_all_effect_ids() -> Array:
	"""Every registered effect id."""
	return effect_definitions.keys()


# === REST HANDLING ===

func _on_rest_taken(rest_type: String):
	"""Long rests clear all non-permanent effects (cursed persists - needs remove curse)."""
	if rest_type != "long":
		return
	_purge_freed_targets()
	var cleared = 0
	for target in active_effects.keys():
		var to_clear: Array = []
		for effect_id in active_effects[target]:
			if not effect_definitions.get(effect_id, {}).get("persists_through_rest", false):
				to_clear.append(effect_id)
		for effect_id in to_clear:
			remove_effect(target, effect_id)
			cleared += 1
	if cleared > 0:
		print("StatusEffects: long rest cleared %d effect(s)" % cleared)


# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Status effects are TRANSIENT BY DESIGN and are not serialized.
	Rationale: effects only exist on live combat nodes (which are not part of the save
	payload), saves happen outside combat, and a long rest - the natural checkpoint -
	clears non-permanent effects anyway. Returns {} so SaveManager round-trips cleanly."""
	return {}


func from_dict(_data: Dictionary):
	"""Transient state - nothing to restore (see to_dict)."""
	pass


# === INTERNAL HELPERS ===

func _is_valid_target(target: Node) -> bool:
	"""A usable combat node: live instance exposing a non-null `stats` property."""
	return target != null and is_instance_valid(target) and target.get("stats") != null


func _purge_freed_targets():
	"""Drop state for combatants whose nodes have been freed (lazy weak handling)."""
	for target in active_effects.keys():
		if not is_instance_valid(target):
			active_effects.erase(target)


func _sum_int_modifier(target: Node, key: String) -> int:
	"""Sum an int modifier key across all of a combatant's active effects."""
	_purge_freed_targets()
	if target == null or not is_instance_valid(target) or not active_effects.has(target):
		return 0
	var total = 0
	for effect_id in active_effects[target]:
		var modifiers: Dictionary = effect_definitions.get(effect_id, {}).get("modifiers", {})
		total += int(modifiers.get(key, 0))
	return total


func _any_bool_modifier(target: Node, key: String) -> bool:
	"""True when any of a combatant's active effects sets a bool modifier key."""
	_purge_freed_targets()
	if target == null or not is_instance_valid(target) or not active_effects.has(target):
		return false
	for effect_id in active_effects[target]:
		var modifiers: Dictionary = effect_definitions.get(effect_id, {}).get("modifiers", {})
		if modifiers.get(key, false):
			return true
	return false


func _process_ticks(target: Node, timing: String):
	"""Roll and apply all damage/heal ticks matching the given timing for one combatant."""
	if not _is_valid_target(target) or not active_effects.has(target):
		return
	for effect_id in active_effects[target].keys():
		if not is_instance_valid(target):
			return
		if not active_effects.has(target) or not active_effects[target].has(effect_id):
			continue
		var definition: Dictionary = effect_definitions.get(effect_id, {})
		var tick: Dictionary = definition.get("tick", {})
		if tick.is_empty() or str(tick.get("timing", "turn_start")) != timing:
			continue
		var entry = active_effects[target][effect_id]

		var damage_dice = str(tick.get("damage_dice", ""))
		if damage_dice != "":
			var amount = CombatManager.roll_dice(damage_dice)
			var type_string = str(tick.get("damage_type", "physical"))
			var source = entry.get("source", null)
			if source != null and not is_instance_valid(source):
				source = null
			print("StatusEffects: %s takes %d %s damage from '%s'" % [target.name, amount, type_string, effect_id])
			EventBus.status_effect_ticked.emit(target, effect_id, amount)
			CombatManager.apply_damage(target, amount, CombatManager.damage_type_from_string(type_string), source, false)
			# Stop ticking a combatant that just died
			if not is_instance_valid(target) or target.get("stats") == null or not target.stats.is_alive():
				return

		var heal_dice = str(tick.get("heal_dice", ""))
		if heal_dice != "" and is_instance_valid(target) and target.get("stats") != null:
			var heal_amount = CombatManager.roll_dice(heal_dice)
			target.stats.heal(heal_amount)
			print("StatusEffects: %s regains %d HP from '%s'" % [target.name, heal_amount, effect_id])
			EventBus.status_effect_ticked.emit(target, effect_id, heal_amount)
