# spell_manager.gd
# AutoLoad singleton - known spells, spell slots, casting, concentration, pending casts,
# spell scrolls/wands and item enchanting.
# Per-character state is tracked HERE keyed by the CharacterStats instance (knowledge/slots)
# or the caster Node (concentration/pending casts) - never written onto CharacterStats.
# Owned by A4 (Magic) - see docs/ARCHITECTURE_CONTRACTS.md.
extends Node

const MAX_ENCHANT_BONUS: int = 3
const INCAPACITATING_EFFECTS: Array = ["stunned", "paralyzed", "frozen"]

# CharacterStats -> Array[String] of known spell_ids
var known_spells: Dictionary = {}

# CharacterStats -> {slot_level int: remaining int} (levels 1-9; cantrips are free)
var current_slots: Dictionary = {}

# caster Node -> {spell_id: String, effect_id: String, targets: Array[Node]}
var concentration_state: Dictionary = {}

# caster Node -> spell_id readied from the spellbook UI, consumed by the combat flow
var pending_casts: Dictionary = {}


func _ready():
	EventBus.rest_taken.connect(_on_rest_taken)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.status_effect_applied.connect(_on_status_effect_applied)
	EventBus.character_died.connect(_on_combatant_died)
	EventBus.enemy_died.connect(_on_combatant_died)
	print("SpellManager: initialized (slots, casting, concentration online)")


# === SPELL KNOWLEDGE ===

func learn_spell(stats, spell_id: String) -> bool:
	"""Teach a character a spell. Returns true when the spell is known afterwards
	(idempotent: re-learning a known spell succeeds without re-emitting spell_learned)."""
	if stats == null or not stats is CharacterStats:
		push_error("SpellManager.learn_spell: invalid stats for '%s'" % spell_id)
		return false
	var spell = SpellDatabase.get_spell(spell_id)
	if spell.is_empty():
		push_error("SpellManager.learn_spell: unknown spell '%s'" % spell_id)
		return false
	if not known_spells.has(stats):
		known_spells[stats] = []
	if spell_id in known_spells[stats]:
		return true
	known_spells[stats].append(spell_id)
	print("SpellManager: %s learned '%s'" % [_stats_label(stats), spell_id])
	EventBus.spell_learned.emit(stats, spell_id)
	return true


func knows_spell(stats, spell_id: String) -> bool:
	"""True when the character has learned the given spell."""
	if stats == null or not known_spells.has(stats):
		return false
	return spell_id in known_spells[stats]


func get_known_spells(stats) -> Array:
	"""All spell_ids the character knows. Casters with NO spells yet are lazily
	granted their class spell list first (grant_class_spells)."""
	if stats == null or not stats is CharacterStats:
		return []
	if not known_spells.has(stats) or (known_spells[stats] as Array).is_empty():
		grant_class_spells(stats)
	return (known_spells.get(stats, []) as Array).duplicate()


func grant_class_spells(stats) -> int:
	"""Auto-learn class-appropriate spells up to the character's castable level:
	cantrips up to the class cantrip budget (deterministic alphabetical order) and
	every class spell of each level the character has at least one slot for.
	Classless / non-caster characters are silently skipped. Returns spells learned."""
	if stats == null or not stats is CharacterStats:
		return 0
	if stats.class_id == "":
		return 0
	var class_data = _get_class_data(stats.class_id)
	if class_data == null or not class_data.is_spellcaster:
		return 0

	var character_level = mini(int(stats.level), 20)
	var learned = 0

	# Cantrips: respect the class cantrip budget, stable alphabetical order
	var budget = class_data.get_cantrips_known(character_level)
	var cantrip_ids: Array = []
	for spell in SpellDatabase.get_spells_by_level(0):
		if stats.class_id in spell.get("classes", []):
			cantrip_ids.append(str(spell.get("spell_id", "")))
	cantrip_ids.sort()
	for spell_id in cantrip_ids:
		if budget <= 0:
			break
		if knows_spell(stats, spell_id):
			budget -= 1
			continue
		if learn_spell(stats, spell_id):
			learned += 1
			budget -= 1

	# Leveled spells: every class spell of each slot level the character can cast
	for slot_level in range(1, 10):
		if get_max_slots(stats, slot_level) <= 0:
			continue
		for spell in SpellDatabase.get_spells_by_level(slot_level):
			var spell_id = str(spell.get("spell_id", ""))
			if stats.class_id in spell.get("classes", []) and not knows_spell(stats, spell_id):
				if learn_spell(stats, spell_id):
					learned += 1

	if learned > 0:
		print("SpellManager: granted %d class spells to %s (%s level %d)" % [
			learned, _stats_label(stats), stats.class_id, stats.level])
	return learned


# === SLOTS ===

func get_max_slots(stats, slot_level: int) -> int:
	"""Maximum slots of a level from the character's class table (0 for classless,
	non-casters, or out-of-range levels). Character levels beyond 20 use the 20 row."""
	if stats == null or not stats is CharacterStats:
		return 0
	if slot_level < 1 or slot_level > 9:
		return 0
	if stats.class_id == "":
		return 0
	var class_data = _get_class_data(stats.class_id)
	if class_data == null or not class_data.is_spellcaster:
		return 0
	return class_data.get_spell_slots(mini(int(stats.level), 20), slot_level)


func get_remaining_slots(stats, slot_level: int) -> int:
	"""Current remaining slots of a level (initialized lazily to the class maximum)."""
	if stats == null or not stats is CharacterStats:
		return 0
	if slot_level < 1 or slot_level > 9:
		return 0
	_ensure_slot_state(stats)
	return int(current_slots[stats].get(slot_level, 0))


func consume_slot(stats, slot_level: int) -> bool:
	"""Spend one slot of the given level. Returns false when none remain.
	Emits EventBus.spell_slot_used on success."""
	var remaining = get_remaining_slots(stats, slot_level)
	if remaining <= 0:
		return false
	current_slots[stats][slot_level] = remaining - 1
	EventBus.spell_slot_used.emit(stats, slot_level, remaining - 1)
	return true


func restore_all_slots(stats):
	"""Refill every slot level to the class maximum (emits spell_slots_restored)."""
	if stats == null or not stats is CharacterStats:
		return
	var slots: Dictionary = {}
	for slot_level in range(1, 10):
		slots[slot_level] = get_max_slots(stats, slot_level)
	current_slots[stats] = slots
	EventBus.spell_slots_restored.emit(stats)


func _ensure_slot_state(stats):
	"""Lazily initialize a character's slot tracker to their class maximums."""
	if current_slots.has(stats):
		return
	var slots: Dictionary = {}
	for slot_level in range(1, 10):
		slots[slot_level] = get_max_slots(stats, slot_level)
	current_slots[stats] = slots


func _on_rest_taken(rest_type: String):
	"""Long rests restore all spell slots for every tracked caster."""
	if rest_type != "long":
		return
	var restored = 0
	var tracked: Array = current_slots.keys()
	for stats in known_spells.keys():
		if not tracked.has(stats):
			tracked.append(stats)
	for stats in tracked:
		if stats is CharacterStats and stats.class_id != "":
			restore_all_slots(stats)
			restored += 1
	if restored > 0:
		print("SpellManager: long rest restored spell slots for %d caster(s)" % restored)


# === CASTING ===

func can_cast(caster: Node, spell_id: String) -> Dictionary:
	"""Returns {ok: bool, reason: String}. Checks: valid caster node with stats,
	known spell, spellcasting class, not incapacitated, and a free slot (cantrips skip)."""
	if caster == null or not is_instance_valid(caster) or caster.get("stats") == null:
		return {"ok": false, "reason": "Invalid caster"}
	var stats = caster.stats
	var spell = SpellDatabase.get_spell(spell_id)
	if spell.is_empty():
		return {"ok": false, "reason": "Unknown spell '%s'" % spell_id}
	if stats.class_id == "":
		return {"ok": false, "reason": "No spellcasting ability"}
	var class_data = _get_class_data(stats.class_id)
	if class_data == null or not class_data.is_spellcaster:
		return {"ok": false, "reason": "%s is not a spellcasting class" % stats.class_id.capitalize()}
	if not knows_spell(stats, spell_id):
		return {"ok": false, "reason": "Spell not known"}
	if StatusEffectManager.has_method("is_incapacitated") and StatusEffectManager.is_incapacitated(caster):
		return {"ok": false, "reason": "Incapacitated"}
	var level = int(spell.get("level", 0))
	if level > 0 and get_remaining_slots(stats, level) <= 0:
		return {"ok": false, "reason": "No level %d spell slots remaining" % level}
	return {"ok": true, "reason": ""}


func cast_spell(caster: Node, spell_id: String, target = null, affected_override: Array = []) -> Dictionary:
	"""Cast a spell at a target (Node, Vector2i grid point, or null for self).
	affected_override: integration hook - explicit list of target Nodes that bypasses
	the built-in area resolution (e.g. line shapes, ally-only area heals).
	Returns {ok, reason, spell_id, hits: Array, total_damage, healed, teleport_to,
	applied_effects: Array} plus countered=true for counterspell."""
	var result = _blank_result(spell_id)
	var check = can_cast(caster, spell_id)
	if not check.get("ok", false):
		result["reason"] = check.get("reason", "Cannot cast")
		print("SpellManager: %s cannot cast '%s' (%s)" % [caster.name if caster != null and is_instance_valid(caster) else "?", spell_id, result["reason"]])
		return result

	var spell = SpellDatabase.get_spell(spell_id)
	var level = int(spell.get("level", 0))
	if level > 0 and not consume_slot(caster.stats, level):
		result["reason"] = "No level %d spell slots remaining" % level
		return result

	return _resolve_cast(caster, spell, target, affected_override, result)


func _blank_result(spell_id: String) -> Dictionary:
	"""Fresh cast-result skeleton (the contract result schema)."""
	return {
		"ok": false,
		"reason": "",
		"spell_id": spell_id,
		"hits": [],
		"total_damage": 0,
		"healed": 0,
		"teleport_to": null,
		"applied_effects": []
	}


func _resolve_cast(caster: Node, spell: Dictionary, target, affected_override: Array, result: Dictionary) -> Dictionary:
	"""Shared resolution core for slot casts, scrolls and wands. Assumes costs are paid."""
	var spell_id = str(spell.get("spell_id", ""))

	# Starting any concentration spell breaks the caster's previous concentration
	if spell.get("concentration", false):
		break_concentration(caster)

	# Special case: teleports (misty_step) - no targets, just a destination
	if spell.get("teleport", false):
		if target is Vector2i:
			result["teleport_to"] = target
		else:
			print("SpellManager: '%s' cast without a Vector2i destination - movement is integration's job" % spell_id)
		result["ok"] = true
		_finish_cast(caster, spell, [], result)
		return result

	# Special case: counterspell placeholder (reaction trigger wired at integration)
	if spell.get("counters", false):
		result["countered"] = true
		result["ok"] = true
		_finish_cast(caster, spell, [], result)
		return result

	# Resolve affected combat nodes
	var affected: Array = _resolve_targets(caster, spell, target, affected_override)

	# Per-target resolution
	for node in affected:
		if node == null or not is_instance_valid(node) or node.get("stats") == null:
			continue
		if not node.stats.is_alive() and not spell.get("revive", false):
			continue
		if spell.get("attack_roll", false):
			_resolve_attack(caster, spell, node, result)
		elif not (spell.get("save", {}) as Dictionary).is_empty():
			_resolve_save(caster, spell, node, result)
		else:
			_resolve_automatic(caster, spell, node, result)

	# Vampiric drain: caster heals for half the damage dealt
	if spell.get("drain_half", false) and result["total_damage"] > 0:
		if is_instance_valid(caster) and caster.get("stats") != null:
			var drained = int(result["total_damage"] / 2.0)
			caster.stats.heal(drained)
			_notify_player_hp(caster)
			print("SpellManager: %s drains %d HP" % [caster.name, drained])

	result["ok"] = true
	_finish_cast(caster, spell, affected, result)
	return result


func _finish_cast(caster: Node, spell: Dictionary, affected: Array, result: Dictionary):
	"""Post-cast bookkeeping: start concentration tracking and emit spell_cast."""
	var spell_id = str(spell.get("spell_id", ""))
	if spell.get("concentration", false) and is_instance_valid(caster):
		var effect_id = str((spell.get("applies_effect", {}) as Dictionary).get("effect_id", ""))
		var effect_targets: Array = []
		for entry in result.get("applied_effects", []):
			if entry.get("effect_id", "") == effect_id and entry.get("target") != null:
				effect_targets.append(entry["target"])
		concentration_state[caster] = {
			"spell_id": spell_id,
			"effect_id": effect_id,
			"targets": effect_targets
		}
		print("SpellManager: %s is now concentrating on '%s'" % [caster.name, spell_id])
		EventBus.concentration_started.emit(caster, spell_id)
	print("SpellManager: %s casts '%s' (%d target(s), %d damage, %d healed)" % [
		caster.name if is_instance_valid(caster) else "?", spell_id,
		affected.size(), int(result["total_damage"]), int(result["healed"])])
	EventBus.spell_cast.emit(caster, spell_id, affected)


# === TARGET RESOLUTION ===

func _resolve_targets(caster: Node, spell: Dictionary, target, affected_override: Array) -> Array:
	"""Affected combat nodes for a cast. affected_override (non-empty) wins outright;
	point targets resolve enemies + the player within the Chebyshev area radius;
	Node targets are taken as-is; null/self fall back to the caster."""
	if not affected_override.is_empty():
		var filtered: Array = []
		for node in affected_override:
			if node != null and is_instance_valid(node):
				filtered.append(node)
		return filtered

	if spell.get("target_type", "enemy") == "self" or target == null:
		return [caster]
	if target is Vector2i:
		return _resolve_area_targets(target, int(spell.get("area_radius_tiles", 0)))
	if target is Node:
		return [target]
	push_error("SpellManager: unsupported target type for '%s'" % str(spell.get("spell_id", "")))
	return []


func _resolve_area_targets(center: Vector2i, radius: int) -> Array:
	"""Enemies (GameManager.world.enemies) plus the player whose grid positions lie
	within a Chebyshev radius of the center tile."""
	var affected: Array = []
	var world = GameManager.world
	if world != null and is_instance_valid(world):
		var enemies = world.get("enemies")
		if enemies is Array:
			for enemy in enemies:
				if enemy == null or not is_instance_valid(enemy) or enemy.get("stats") == null:
					continue
				var pos = _get_grid_position(enemy)
				if pos != null and _chebyshev(pos, center) <= radius:
					affected.append(enemy)
	var player = GameManager.player
	if player != null and is_instance_valid(player) and player.get("stats") != null:
		var player_pos = _get_grid_position(player)
		if player_pos != null and _chebyshev(player_pos, center) <= radius:
			affected.append(player)
	return affected


func _get_grid_position(node: Node):
	"""Vector2i grid position of a combat node, or null when unavailable."""
	if node == null or not is_instance_valid(node):
		return null
	var pos = node.get("grid_position")
	if pos is Vector2i:
		return pos
	if node.has_method("get_grid_position"):
		pos = node.get_grid_position()
		if pos is Vector2i:
			return pos
	return null


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	"""Chebyshev (chessboard) distance in tiles."""
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# === PER-TARGET RESOLUTION ===

func _resolve_attack(caster: Node, spell: Dictionary, target: Node, result: Dictionary):
	"""Spell attack: own d20 + caster spell_attack_bonus vs target AC (+ status AC mods).
	Nat 20 doubles the damage dice; nat 1 always misses. attack_count rolls multiple
	independent attacks (scorching_ray)."""
	var rays = maxi(1, int(spell.get("attack_count", 1)))
	for _i in range(rays):
		if not is_instance_valid(target) or target.get("stats") == null or not target.stats.is_alive():
			break
		var roll = randi_range(1, 20)
		var is_crit = roll == 20
		var is_fumble = roll == 1
		var attack_bonus = int(caster.stats.spell_attack_bonus) if is_instance_valid(caster) and caster.get("stats") != null else 0
		var total = roll + attack_bonus
		var target_ac = int(target.stats.armor_class)
		if StatusEffectManager.has_method("get_ac_modifier"):
			target_ac += StatusEffectManager.get_ac_modifier(target)
		var hit = is_crit or (not is_fumble and total >= target_ac)

		var entry = {
			"target": target, "kind": "attack", "roll": roll, "total": total,
			"target_ac": target_ac, "hit": hit, "is_crit": is_crit, "damage": 0
		}
		if hit:
			var damage = _roll_spell_damage(str(spell.get("damage_dice", "")), is_crit)
			if damage > 0:
				_deal_damage(target, damage, str(spell.get("damage_type", "")), caster, is_crit)
				entry["damage"] = damage
				result["total_damage"] += damage
			_apply_heal(spell, target, result, entry)
			_apply_spell_effect(spell, target, result)
			_apply_effect_removal(spell, target)
		result["hits"].append(entry)


func _resolve_save(caster: Node, spell: Dictionary, target: Node, result: Dictionary):
	"""Saving-throw spell: target saves vs the caster's spell_save_dc. Failed save =
	full damage + effect; success = half damage when half_on_save, else nothing."""
	var save_info: Dictionary = spell.get("save", {})
	var dc = int(caster.stats.spell_save_dc) if is_instance_valid(caster) and caster.get("stats") != null else 10
	var save_result = _make_save(target, str(save_info.get("stat", "dex")), dc)
	var success = save_result.get("success", false)

	var entry = {
		"target": target, "kind": "save", "hit": not success,
		"save": save_result, "damage": 0
	}
	var damage_dice = str(spell.get("damage_dice", ""))
	if damage_dice != "":
		var damage = _roll_spell_damage(damage_dice, false)
		if success:
			damage = int(damage / 2.0) if save_info.get("half_on_save", false) else 0
		if damage > 0:
			_deal_damage(target, damage, str(spell.get("damage_type", "")), caster, false)
			entry["damage"] = damage
			result["total_damage"] += damage
	if not success:
		_apply_heal(spell, target, result, entry)
		_apply_spell_effect(spell, target, result)
		_apply_effect_removal(spell, target)
	result["hits"].append(entry)


func _resolve_automatic(caster: Node, spell: Dictionary, target: Node, result: Dictionary):
	"""No attack roll, no save: auto-hit damage (magic_missile, power_word_kill),
	heals, buffs/debuffs, effect removal and revives."""
	var entry = {"target": target, "kind": "auto", "hit": true, "damage": 0}

	if spell.get("revive", false) and target.get("stats") != null and not target.stats.is_alive():
		print("SpellManager: %s is called back from death!" % target.name)

	var damage_dice = str(spell.get("damage_dice", ""))
	if damage_dice != "":
		var damage = _roll_spell_damage(damage_dice, false)
		if damage > 0:
			_deal_damage(target, damage, str(spell.get("damage_type", "")), caster, false)
			entry["damage"] = damage
			result["total_damage"] += damage

	_apply_heal(spell, target, result, entry)
	_apply_spell_effect(spell, target, result)
	_apply_effect_removal(spell, target)
	result["hits"].append(entry)


func _apply_heal(spell: Dictionary, target: Node, result: Dictionary, entry: Dictionary):
	"""Roll heal_dice and apply via CharacterStats.heal (player HP signal included)."""
	var heal_dice = str(spell.get("heal_dice", ""))
	if heal_dice == "" or not is_instance_valid(target) or target.get("stats") == null:
		return
	var amount = _roll_dice(heal_dice)
	if amount <= 0:
		return
	target.stats.heal(amount)
	entry["healed"] = amount
	result["healed"] += amount
	_notify_player_hp(target)


func _apply_spell_effect(spell: Dictionary, target: Node, result: Dictionary):
	"""Apply the spell's status effect through StatusEffectManager and record it."""
	var effect_info: Dictionary = spell.get("applies_effect", {})
	if effect_info.is_empty():
		return
	var effect_id = str(effect_info.get("effect_id", ""))
	if effect_id == "":
		return
	if not StatusEffectManager.has_method("apply_effect"):
		return
	var duration = int(effect_info.get("duration", 0))
	if StatusEffectManager.apply_effect(target, effect_id, duration):
		result["applied_effects"].append({"target": target, "effect_id": effect_id, "duration": duration})


func _apply_effect_removal(spell: Dictionary, target: Node):
	"""Handle removes_effects lists and clears_all_effects (restoration spells)."""
	if spell.get("clears_all_effects", false):
		if StatusEffectManager.has_method("clear_effects"):
			StatusEffectManager.clear_effects(target)
		return
	var to_remove: Array = spell.get("removes_effects", [])
	if to_remove.is_empty():
		return
	if not StatusEffectManager.has_method("remove_effect"):
		return
	for effect_id in to_remove:
		if StatusEffectManager.has_method("has_effect") and not StatusEffectManager.has_effect(target, str(effect_id)):
			continue
		StatusEffectManager.remove_effect(target, str(effect_id))


# === DICE / DAMAGE / SAVE PLUMBING (has_method-guarded cross-system calls) ===

func _roll_dice(dice_string: String) -> int:
	"""Roll dice notation, preferring CombatManager's parser with a local fallback."""
	if CombatManager.has_method("roll_dice"):
		return CombatManager.roll_dice(dice_string)
	var text = dice_string.strip_edges().to_lower()
	if text == "":
		return 0
	if text.is_valid_int():
		return int(text)
	var bonus = 0
	var plus_idx = text.find("+")
	if plus_idx > 0:
		bonus = int(text.substr(plus_idx + 1))
		text = text.substr(0, plus_idx)
	var parts = text.split("d")
	if parts.size() != 2:
		return bonus
	var total = bonus
	for _i in range(maxi(1, int(parts[0]))):
		total += randi_range(1, maxi(1, int(parts[1])))
	return total


func _roll_spell_damage(damage_dice: String, is_crit: bool) -> int:
	"""Spell damage roll; a critical hit doubles the dice (rolled twice)."""
	if damage_dice == "":
		return 0
	var damage = _roll_dice(damage_dice)
	if is_crit:
		damage += _roll_dice(damage_dice)
	return damage


func _deal_damage(target: Node, amount: int, damage_type_string: String, caster: Node, is_crit: bool):
	"""Apply spell damage through CombatManager (string -> enum mapped per contracts 2.4),
	with a minimal direct fallback if the expanded CombatManager API is unavailable."""
	if amount <= 0 or target == null or not is_instance_valid(target):
		return
	var damage_type = 0
	if CombatManager.has_method("damage_type_from_string"):
		damage_type = CombatManager.damage_type_from_string(damage_type_string)
	if CombatManager.has_method("apply_damage"):
		CombatManager.apply_damage(target, amount, damage_type, caster, is_crit)
	else:
		if target.get("stats") == null:
			return
		var still_alive = target.stats.take_damage(amount)
		EventBus.damage_dealt.emit(caster, target, amount, is_crit)
		if not still_alive and target.has_method("die"):
			target.die()
	if is_instance_valid(target):
		_notify_player_hp(target)


func _make_save(target: Node, stat: String, dc: int) -> Dictionary:
	"""Saving throw through CombatManager (with target_node for status-effect rules),
	falling back to a plain d20 + stat modifier when unavailable."""
	if target == null or not is_instance_valid(target) or target.get("stats") == null:
		return {"success": false, "roll": 0, "total": 0, "dc": dc}
	if CombatManager.has_method("make_saving_throw"):
		var save_result = CombatManager.make_saving_throw(target.stats, stat, dc, false, false, target)
		if save_result is Dictionary and not save_result.is_empty():
			return save_result
	var roll = randi_range(1, 20)
	var modifier = 0
	if target.stats.has_method("get_modifier_for_stat"):
		modifier = target.stats.get_modifier_for_stat(stat)
	var total = roll + modifier
	return {"success": total >= dc, "roll": roll, "total": total, "dc": dc, "modifier": modifier}


func _notify_player_hp(node: Node):
	"""Emit player_hp_changed when the affected node is the player (UI refresh)."""
	var player = GameManager.player
	if player == null or not is_instance_valid(player) or node != player:
		return
	if player.get("stats") == null:
		return
	EventBus.player_hp_changed.emit(player.stats.current_hp, player.stats.max_hp)


# === CONCENTRATION ===

func is_concentrating(caster: Node) -> String:
	"""Returns the spell_id being concentrated on, or '' if none."""
	_purge_freed_nodes()
	if caster == null or not is_instance_valid(caster) or not concentration_state.has(caster):
		return ""
	return str(concentration_state[caster].get("spell_id", ""))


func break_concentration(caster: Node):
	"""End the caster's concentration: removes the linked status effect from every
	tracked target and emits concentration_broken."""
	_purge_freed_nodes()
	if caster == null or not concentration_state.has(caster):
		return
	var entry: Dictionary = concentration_state[caster]
	concentration_state.erase(caster)
	var effect_id = str(entry.get("effect_id", ""))
	if effect_id != "" and StatusEffectManager.has_method("remove_effect"):
		for target in entry.get("targets", []):
			if target != null and is_instance_valid(target):
				StatusEffectManager.remove_effect(target, effect_id)
	var spell_id = str(entry.get("spell_id", ""))
	if is_instance_valid(caster):
		print("SpellManager: %s's concentration on '%s' ends" % [caster.name, spell_id])
	EventBus.concentration_broken.emit(caster, spell_id)


func _on_damage_dealt(_attacker, target, amount, _is_critical):
	"""Concentration check on damage: CON save DC max(10, damage/2), fail = broken."""
	if target == null or not (target is Node) or not is_instance_valid(target):
		return
	if not concentration_state.has(target):
		return
	var dc = maxi(10, int(int(amount) / 2.0))
	var save_result = _make_save(target, "con", dc)
	if not save_result.get("success", false):
		print("SpellManager: %s fails the concentration save (DC %d)!" % [target.name, dc])
		break_concentration(target)


func _on_status_effect_applied(target, effect_id: String, _duration: int):
	"""Becoming incapacitated (stunned/paralyzed/frozen) breaks concentration."""
	if effect_id in INCAPACITATING_EFFECTS and target is Node and concentration_state.has(target):
		break_concentration(target)


func _on_combatant_died(character):
	"""Death ends concentration immediately."""
	if character is Node and concentration_state.has(character):
		break_concentration(character)


# === PENDING-CAST API (spellbook UI -> combat flow handoff) ===

func set_pending_cast(caster: Node, spell_id: String):
	"""Ready a spell for casting (set by the spellbook panel; the combat/targeting
	flow reads it with get_pending_cast and resolves the target)."""
	_purge_freed_nodes()
	if caster == null or not is_instance_valid(caster):
		return
	pending_casts[caster] = spell_id
	print("SpellManager: %s readies '%s' (pending cast)" % [caster.name, spell_id])


func get_pending_cast(caster: Node) -> String:
	"""The spell_id readied by this caster, or '' if none."""
	_purge_freed_nodes()
	if caster == null or not is_instance_valid(caster):
		return ""
	return str(pending_casts.get(caster, ""))


func clear_pending_cast(caster: Node):
	"""Clear a readied spell (after casting or cancelling)."""
	if caster != null and pending_casts.has(caster):
		pending_casts.erase(caster)


# === SPELL ITEMS (scrolls / wands) ===

func use_scroll(item_instance: Dictionary, caster: Node, target = null) -> Dictionary:
	"""Cast a scroll_<spell_id> item's spell without a slot or knowing the spell,
	then consume the scroll via InventoryManager.remove_item. Returns a cast result."""
	var spell = _spell_from_item(item_instance, "scroll_")
	var result = _blank_result(str(spell.get("spell_id", "")))
	if spell.is_empty():
		result["reason"] = "Not a usable spell scroll"
		return result
	if caster == null or not is_instance_valid(caster) or caster.get("stats") == null:
		result["reason"] = "Invalid caster"
		return result
	if StatusEffectManager.has_method("is_incapacitated") and StatusEffectManager.is_incapacitated(caster):
		result["reason"] = "Incapacitated"
		return result

	result = _resolve_cast(caster, spell, target, [], result)
	if result.get("ok", false):
		var instance_id = str(item_instance.get("instance_id", ""))
		if instance_id != "" and not InventoryManager.get_item(instance_id).is_empty():
			InventoryManager.remove_item(instance_id)
		print("SpellManager: scroll of '%s' crumbles to dust" % str(spell.get("spell_id", "")))
	return result


func use_wand(item_instance: Dictionary, caster: Node, target = null) -> Dictionary:
	"""Cast a wand_<spell_id> item's spell, spending one charge (current_durability).
	A spent wand fizzles with a ui_notification instead of casting."""
	var spell = _spell_from_item(item_instance, "wand_")
	var result = _blank_result(str(spell.get("spell_id", "")))
	if spell.is_empty():
		result["reason"] = "Not a usable wand"
		return result
	if caster == null or not is_instance_valid(caster) or caster.get("stats") == null:
		result["reason"] = "Invalid caster"
		return result
	if StatusEffectManager.has_method("is_incapacitated") and StatusEffectManager.is_incapacitated(caster):
		result["reason"] = "Incapacitated"
		return result

	var charges = int(item_instance.get("current_durability", 0))
	if charges <= 0:
		result["reason"] = "The wand is out of charges"
		EventBus.ui_notification.emit("The wand fizzles - no charges remain.", "warning")
		return result

	item_instance["current_durability"] = charges - 1
	EventBus.item_durability_changed.emit(item_instance, charges - 1, int(item_instance.get("max_durability", SpellDatabase.WAND_CHARGES)))
	print("SpellManager: wand discharge (%d charge(s) left)" % (charges - 1))
	return _resolve_cast(caster, spell, target, [], result)


func _spell_from_item(item_instance: Dictionary, prefix: String) -> Dictionary:
	"""Resolve the spell definition encoded in a scroll_/wand_ item id ({} if invalid)."""
	if item_instance == null or item_instance.is_empty():
		return {}
	var item_data = item_instance.get("item_data", null)
	if item_data == null or not (item_data is ItemData):
		return {}
	var item_id = str(item_data.item_id)
	if not item_id.begins_with(prefix):
		return {}
	return SpellDatabase.get_spell(item_id.substr(prefix.length()))


# === ENCHANTING ===

func enchant_item(item_instance: Dictionary, plus_level: int) -> bool:
	"""Raise an item INSTANCE's magic_modifier by plus_level, capped at +3.
	Instance-level only - the shared ItemData template is never mutated.
	Emits item_enchanted(instance, "plus<N>"). Returns false when invalid or capped."""
	if item_instance == null or item_instance.is_empty():
		push_error("SpellManager.enchant_item: empty item instance")
		return false
	if plus_level <= 0:
		return false
	var current = int(item_instance.get("magic_modifier", 0))
	var new_modifier = mini(current + plus_level, MAX_ENCHANT_BONUS)
	if new_modifier == current:
		print("SpellManager: enchantment fizzles - item is already at +%d" % current)
		return false
	item_instance["magic_modifier"] = new_modifier
	print("SpellManager: item enchanted to +%d" % new_modifier)
	EventBus.item_enchanted.emit(item_instance, "plus%d" % new_modifier)
	return true


# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Serialize known spells and current slots keyed by character_uid (primitives only).
	Characters without a resolvable uid are skipped."""
	var known_out: Dictionary = {}
	for stats in known_spells.keys():
		var uid = _uid_for_stats(stats)
		if uid == "":
			continue
		known_out[uid] = (known_spells[stats] as Array).duplicate()
	var slots_out: Dictionary = {}
	for stats in current_slots.keys():
		var uid = _uid_for_stats(stats)
		if uid == "":
			continue
		var per_level: Dictionary = {}
		for slot_level in current_slots[stats]:
			per_level[str(slot_level)] = int(current_slots[stats][slot_level])
		slots_out[uid] = per_level
	return {"known_spells": known_out, "slots": slots_out}


func from_dict(data: Dictionary):
	"""Restore known spells and slots. Uids that cannot be resolved to a live
	CharacterStats ('player' via GameManager, otherwise already-tracked stats)
	are skipped with a warning."""
	if data == null or data.is_empty():
		return
	var known_in: Dictionary = data.get("known_spells", {})
	var slots_in: Dictionary = data.get("slots", {})

	for uid in known_in.keys():
		var stats = _resolve_stats_by_uid(str(uid))
		if stats == null:
			print("SpellManager: from_dict skipping unknown character uid '%s' (known spells)" % uid)
			continue
		var spell_ids: Array = []
		for spell_id in known_in[uid]:
			if SpellDatabase.has_spell(str(spell_id)):
				spell_ids.append(str(spell_id))
			else:
				print("SpellManager: from_dict dropping unknown spell '%s' for '%s'" % [spell_id, uid])
		known_spells[stats] = spell_ids

	for uid in slots_in.keys():
		var stats = _resolve_stats_by_uid(str(uid))
		if stats == null:
			print("SpellManager: from_dict skipping unknown character uid '%s' (slots)" % uid)
			continue
		var per_level: Dictionary = {}
		for slot_level in range(1, 10):
			var saved = (slots_in[uid] as Dictionary).get(str(slot_level), null)
			per_level[slot_level] = int(saved) if saved != null else get_max_slots(stats, slot_level)
		current_slots[stats] = per_level
	print("SpellManager: state restored (%d caster(s) with known spells)" % known_spells.size())


func _uid_for_stats(stats) -> String:
	"""character_uid of a CharacterStats ('' when unavailable)."""
	if stats == null or not stats is CharacterStats:
		return ""
	var uid = stats.get("character_uid")
	return str(uid) if uid != null else ""


func _resolve_stats_by_uid(uid: String):
	"""CharacterStats for a saved uid: 'player' resolves through GameManager.player,
	anything else matches stats instances already tracked by this manager."""
	if uid == "player":
		var player = GameManager.player
		if player != null and is_instance_valid(player) and player.get("stats") != null:
			return player.stats
		return null
	for stats in known_spells.keys():
		if _uid_for_stats(stats) == uid:
			return stats
	for stats in current_slots.keys():
		if _uid_for_stats(stats) == uid:
			return stats
	return null


# === INTERNAL HELPERS ===

func _get_class_data(class_id: String):
	"""ClassData for a class id (null when missing or ClassDatabase unavailable)."""
	if class_id == "" or not ClassDatabase.has_method("get_class_data"):
		return null
	return ClassDatabase.get_class_data(class_id)


func _stats_label(stats) -> String:
	"""Readable name for log lines."""
	if stats == null or not stats is CharacterStats:
		return "?"
	if stats.character_name != "":
		return stats.character_name
	return stats.character_uid


func _purge_freed_nodes():
	"""Drop concentration/pending state for combat nodes that have been freed."""
	for node in concentration_state.keys():
		if not is_instance_valid(node):
			concentration_state.erase(node)
	for node in pending_casts.keys():
		if not is_instance_valid(node):
			pending_casts.erase(node)
