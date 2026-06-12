# character_stats.gd
# Manages all character statistics and calculations
extends RefCounted
class_name CharacterStats

# === XP / LEVEL CONSTANTS ===

const MAX_LEVEL: int = 40

# 5e cumulative XP thresholds: XP_TABLE_5E[n - 1] = total XP needed to BE level n (levels 1-20).
# Levels 21-40 are extrapolated at ~x1.25 per level (see get_xp_for_level).
const XP_TABLE_5E: Array[int] = [
	0, 300, 900, 2700, 6500,
	14000, 23000, 34000, 48000, 64000,
	85000, 100000, 120000, 140000, 165000,
	195000, 225000, 265000, 305000, 355000
]
const XP_EXTRAPOLATION_FACTOR: float = 1.25

# Ability Score Improvement levels (each grants +2 ability points).
# Beyond 20, every 4th level (24, 28, 32, 36, 40) grants another ASI.
const ASI_LEVELS: Array[int] = [4, 8, 12, 16, 19]
const ABILITY_SCORE_CAP: int = 20        # Base-stat cap while level <= 20
const ABILITY_SCORE_CAP_EPIC: int = 24   # Base-stat cap beyond level 20

# === IDENTITY (used for persistence / progression events) ===
var character_uid: String = "player"  # "player" for the player, "companion_<id>" for companions
var character_name: String = ""
var class_id: String = ""  # "" = classless (enemies / placeholder)
var race_id: String = ""

# Core D&D stats (3-20 range typical)
var strength: int = 10
var dexterity: int = 10
var constitution: int = 10
var intelligence: int = 10
var wisdom: int = 10
var charisma: int = 10

# Derived stats
var max_hp: int = 20
var current_hp: int = 20
var armor_class: int = 10
var initiative_bonus: int = 0
var movement_speed: int = 30  # Base movement speed in feet (6 tiles)
var carrying_capacity: int = 150  # Pounds

# Hit die sides used when class_id is empty (enemies / monsters built without a class)
var default_hit_die_sides: int = 10

# Level and XP (experience is CUMULATIVE; thresholds come from get_xp_for_level)
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 300  # Cumulative XP needed for the NEXT level (display/back-compat)

# Ability Score Improvements
var unspent_ability_points: int = 0

# Proficiency
var proficiency_bonus: int = 2  # +2 at level 1, increases every 4 levels

# Saving throw proficiencies (set by class)
var str_save_proficient: bool = false
var dex_save_proficient: bool = false
var con_save_proficient: bool = false
var int_save_proficient: bool = false
var wis_save_proficient: bool = false
var cha_save_proficient: bool = false

# Skill / tool / equipment proficiencies (canonical snake_case ids - see contracts 2.5)
var skill_proficiencies: Array[String] = []
var tool_proficiencies: Array[String] = []
var expertise: Array[String] = []  # Skills with doubled proficiency bonus
var weapon_proficiencies: Array[String] = []
var armor_proficiencies: Array[String] = []
var racial_traits: Array[String] = []

# Attack bonuses
var melee_attack_bonus: int = 0
var ranged_attack_bonus: int = 0
var spell_attack_bonus: int = 0
var spell_save_dc: int = 10

# Equipment bonuses (from equipped items)
var equipment_str_bonus: int = 0
var equipment_dex_bonus: int = 0
var equipment_con_bonus: int = 0
var equipment_int_bonus: int = 0
var equipment_wis_bonus: int = 0
var equipment_cha_bonus: int = 0
var equipment_ac_bonus: int = 0

# Temporary modifiers (buffs/debuffs)
var temp_modifiers: Dictionary = {}  # {"bless": 1d4, "haste": +2_ac, etc}

func _init(base_stats: Dictionary = {}):
	"""Initialize with optional base stats"""
	if base_stats.has("str"):
		strength = base_stats.str
	if base_stats.has("dex"):
		dexterity = base_stats.dex
	if base_stats.has("con"):
		constitution = base_stats.con
	if base_stats.has("int"):
		intelligence = base_stats.int
	if base_stats.has("wis"):
		wisdom = base_stats.wis
	if base_stats.has("cha"):
		charisma = base_stats.cha

	experience_to_next_level = get_xp_for_level(level + 1)
	recalculate_derived_stats()

# === STAT MODIFIERS ===

func get_stat_modifier(stat_value: int) -> int:
	"""Calculate D&D stat modifier: floor((stat - 10) / 2)"""
	return floori((stat_value - 10) / 2.0)

func get_str_modifier() -> int:
	return get_stat_modifier(strength + equipment_str_bonus)

func get_dex_modifier() -> int:
	return get_stat_modifier(dexterity + equipment_dex_bonus)

func get_con_modifier() -> int:
	return get_stat_modifier(constitution + equipment_con_bonus)

func get_int_modifier() -> int:
	return get_stat_modifier(intelligence + equipment_int_bonus)

func get_wis_modifier() -> int:
	return get_stat_modifier(wisdom + equipment_wis_bonus)

func get_cha_modifier() -> int:
	return get_stat_modifier(charisma + equipment_cha_bonus)

func get_modifier_for_stat(stat: String) -> int:
	"""Get the (equipment-inclusive) modifier for a stat by name ('str'/'strength'/...)"""
	match stat.to_lower():
		"str", "strength": return get_str_modifier()
		"dex", "dexterity": return get_dex_modifier()
		"con", "constitution": return get_con_modifier()
		"int", "intelligence": return get_int_modifier()
		"wis", "wisdom": return get_wis_modifier()
		"cha", "charisma": return get_cha_modifier()
	return 0

# === MOVEMENT SPEED ===

func get_modified_movement_speed() -> int:
	"""Get movement speed with encumbrance penalties applied"""
	var base_speed = movement_speed
	var encumbrance_penalty = InventoryManager.get_encumbrance_speed_penalty()
	return max(0, base_speed + encumbrance_penalty)

# === DERIVED STATS ===

func get_hit_die_sides() -> int:
	"""Hit die sides from the character's class (d10 fallback for classless characters)"""
	if class_id != "":
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data:
			return class_data.get_hit_die_sides()
	return default_hit_die_sides

func recalculate_derived_stats():
	"""Recalculate all derived stats from base + equipment"""
	# Proficiency bonus (increases every 4 levels) — computed first, used by attack bonuses below
	proficiency_bonus = 2 + int((level - 1) / 4.0)

	# HP: max hit die at level 1, then average rolls per level (deterministic; die from class)
	var hit_die_sides = get_hit_die_sides()
	var hp_per_level = int(hit_die_sides / 2.0) + 1  # Average roll, rounded up (d10 -> 6)
	max_hp = max(1, hit_die_sides + get_con_modifier() + (level - 1) * (hp_per_level + get_con_modifier()))
	current_hp = mini(current_hp, max_hp)  # Don't exceed max

	# AC (10 + DEX modifier + equipment)
	armor_class = 10 + get_dex_modifier() + equipment_ac_bonus

	# Initiative
	initiative_bonus = get_dex_modifier()

	# Attack bonuses
	melee_attack_bonus = proficiency_bonus + get_str_modifier()
	ranged_attack_bonus = proficiency_bonus + get_dex_modifier()

	# Spellcasting uses the class's spellcasting ability (INT fallback for classless casters)
	var cast_mod = get_modifier_for_stat(get_spellcasting_ability())
	spell_attack_bonus = proficiency_bonus + cast_mod
	spell_save_dc = 8 + proficiency_bonus + cast_mod

	# Carrying capacity
	carrying_capacity = (strength + equipment_str_bonus) * 15

func get_spellcasting_ability() -> String:
	"""Spellcasting ability from class data ('int' fallback)"""
	if class_id != "":
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data and class_data.spellcasting_ability != "":
			return class_data.spellcasting_ability
	return "int"

func apply_equipment_bonuses(equipped_items: Array):
	"""Apply stat bonuses from all equipped items"""
	# Reset equipment bonuses
	equipment_str_bonus = 0
	equipment_dex_bonus = 0
	equipment_con_bonus = 0
	equipment_int_bonus = 0
	equipment_wis_bonus = 0
	equipment_cha_bonus = 0
	equipment_ac_bonus = 0

	# Sum up bonuses from all equipped items
	for item_instance in equipped_items:
		if item_instance == null:
			continue

		# Item instances are Dictionaries wrapping an ItemData Resource under "item_data"
		# (see ItemDatabase.create_item_instance); bare ItemData Resources are accepted too.
		# NOTE: use the "in" operator, never .has() - Resources/Objects have no has() method.
		var item_data = null
		if item_instance is Resource:
			item_data = item_instance
		elif "item_data" in item_instance:
			item_data = item_instance.item_data

		if item_data == null:
			continue

		# Armor AC bonus (ItemData always declares armor_class_bonus; default 0)
		if "armor_class_bonus" in item_data and item_data.armor_class_bonus > 0:
			equipment_ac_bonus += item_data.armor_class_bonus

		# Stat bonuses from magic items (ItemData always declares stat_bonuses; default {})
		if "stat_bonuses" in item_data:
			for stat in item_data.stat_bonuses:
				match stat:
					"str": equipment_str_bonus += item_data.stat_bonuses[stat]
					"dex": equipment_dex_bonus += item_data.stat_bonuses[stat]
					"con": equipment_con_bonus += item_data.stat_bonuses[stat]
					"int": equipment_int_bonus += item_data.stat_bonuses[stat]
					"wis": equipment_wis_bonus += item_data.stat_bonuses[stat]
					"cha": equipment_cha_bonus += item_data.stat_bonuses[stat]

	# Recalculate derived stats with new bonuses
	recalculate_derived_stats()

# === COMBAT ===

func take_damage(amount: int) -> bool:
	"""Take damage, returns true if still alive"""
	current_hp = max(0, current_hp - amount)
	return current_hp > 0

func heal(amount: int):
	"""Heal HP, cannot exceed max"""
	current_hp = mini(current_hp + amount, max_hp)

func is_alive() -> bool:
	return current_hp > 0

func get_hp_percent() -> float:
	"""Get HP as 0.0-1.0 percentage"""
	return float(current_hp) / float(max_hp)

# === LEVELING ===

static func get_xp_for_level(target_level: int) -> int:
	"""Total (cumulative) XP required to reach target_level.
	Levels 1-20 use the 5e table; 21-40 extrapolate at ~x1.25 per level."""
	if target_level <= 1:
		return 0
	var capped_level = mini(target_level, MAX_LEVEL)
	if capped_level <= XP_TABLE_5E.size():
		return XP_TABLE_5E[capped_level - 1]
	var xp := float(XP_TABLE_5E[XP_TABLE_5E.size() - 1])
	for _i in range(XP_TABLE_5E.size() + 1, capped_level + 1):
		xp *= XP_EXTRAPOLATION_FACTOR
	return int(round(xp))

static func is_asi_level(check_level: int) -> bool:
	"""Whether a level grants an Ability Score Improvement (+2 points)"""
	if check_level in ASI_LEVELS:
		return true
	if check_level > 20 and (check_level - 20) % 4 == 0:
		return true
	return false

func gain_experience(amount: int):
	"""Gain XP (cumulative), level up while thresholds are crossed"""
	experience += amount
	EventBus.player_gained_xp.emit(amount)

	while level < MAX_LEVEL and experience >= get_xp_for_level(level + 1):
		level_up()

	experience_to_next_level = get_xp_for_level(mini(level + 1, MAX_LEVEL))

func level_up():
	"""Level up character (XP is cumulative - nothing is subtracted)"""
	level += 1
	experience_to_next_level = get_xp_for_level(mini(level + 1, MAX_LEVEL))

	# Ability Score Improvement levels grant +2 points to spend
	if is_asi_level(level):
		unspent_ability_points += 2
		print("CharacterStats: ASI gained at level ", level, " (+2 ability points, ", unspent_ability_points, " unspent)")

	# Recalculate everything (HP growth comes from the level-based formula)
	recalculate_derived_stats()
	current_hp = max_hp  # Full heal on level up

	print("LEVEL UP! Now level ", level)

	if character_uid == "player":
		EventBus.player_leveled_up.emit(level)

func spend_ability_point(stat: String) -> bool:
	"""Spend one unspent ASI point on a base ability score.
	Caps at 20 while level <= 20, up to 24 beyond level 20. Returns success."""
	if unspent_ability_points <= 0:
		print("CharacterStats: no unspent ability points")
		return false

	var cap = ABILITY_SCORE_CAP if level <= 20 else ABILITY_SCORE_CAP_EPIC
	var stat_key = stat.to_lower()
	var new_value = 0

	match stat_key:
		"str", "strength":
			if strength >= cap: return false
			strength += 1
			new_value = strength
			stat_key = "str"
		"dex", "dexterity":
			if dexterity >= cap: return false
			dexterity += 1
			new_value = dexterity
			stat_key = "dex"
		"con", "constitution":
			if constitution >= cap: return false
			constitution += 1
			new_value = constitution
			stat_key = "con"
		"int", "intelligence":
			if intelligence >= cap: return false
			intelligence += 1
			new_value = intelligence
			stat_key = "int"
		"wis", "wisdom":
			if wisdom >= cap: return false
			wisdom += 1
			new_value = wisdom
			stat_key = "wis"
		"cha", "charisma":
			if charisma >= cap: return false
			charisma += 1
			new_value = charisma
			stat_key = "cha"
		_:
			push_error("CharacterStats.spend_ability_point: unknown stat '%s'" % stat)
			return false

	unspent_ability_points -= 1
	recalculate_derived_stats()
	print("CharacterStats: +1 ", stat_key.to_upper(), " -> ", new_value, " (", unspent_ability_points, " points left)")
	EventBus.ability_score_increased.emit(self, stat_key, new_value)
	return true

# === SAVING THROW PROFICIENCIES ===

func is_proficient_in_save(stat: String) -> bool:
	"""Check if character is proficient in a saving throw"""
	match stat.to_lower():
		"str", "strength": return str_save_proficient
		"dex", "dexterity": return dex_save_proficient
		"con", "constitution": return con_save_proficient
		"int", "intelligence": return int_save_proficient
		"wis", "wisdom": return wis_save_proficient
		"cha", "charisma": return cha_save_proficient
	return false

func set_save_proficiency(stat: String, proficient: bool):
	"""Set saving throw proficiency for a stat ('str'..'cha' or long names)"""
	match stat.to_lower():
		"str", "strength": str_save_proficient = proficient
		"dex", "dexterity": dex_save_proficient = proficient
		"con", "constitution": con_save_proficient = proficient
		"int", "intelligence": int_save_proficient = proficient
		"wis", "wisdom": wis_save_proficient = proficient
		"cha", "charisma": cha_save_proficient = proficient
		_: push_error("CharacterStats.set_save_proficiency: unknown stat '%s'" % stat)

func get_save_proficiencies() -> Array[String]:
	"""Get proficient saving throws as short stat keys"""
	var result: Array[String] = []
	if str_save_proficient: result.append("str")
	if dex_save_proficient: result.append("dex")
	if con_save_proficient: result.append("con")
	if int_save_proficient: result.append("int")
	if wis_save_proficient: result.append("wis")
	if cha_save_proficient: result.append("cha")
	return result

# === SKILL / TOOL PROFICIENCIES ===

func add_skill_proficiency(skill_id: String):
	"""Add a skill proficiency (normalized to canonical snake_case id, deduplicated)"""
	var normalized = SkillDatabase.normalize_skill_id(skill_id)
	if normalized != "" and not skill_proficiencies.has(normalized):
		skill_proficiencies.append(normalized)

func add_tool_proficiency(tool_id: String):
	"""Add a tool proficiency (deduplicated)"""
	if tool_id != "" and not tool_proficiencies.has(tool_id):
		tool_proficiencies.append(tool_id)

func add_weapon_proficiency(weapon_type: String):
	"""Add a weapon proficiency (deduplicated)"""
	if weapon_type != "" and not weapon_proficiencies.has(weapon_type):
		weapon_proficiencies.append(weapon_type)

func add_armor_proficiency(armor_type: String):
	"""Add an armor proficiency (deduplicated)"""
	if armor_type != "" and not armor_proficiencies.has(armor_type):
		armor_proficiencies.append(armor_type)

func is_proficient_in_skill(skill_id: String) -> bool:
	"""Check if character is proficient in a skill"""
	return skill_proficiencies.has(SkillDatabase.normalize_skill_id(skill_id))

func has_expertise_in(skill_id: String) -> bool:
	"""Check if character has expertise (double proficiency) in a skill"""
	return expertise.has(SkillDatabase.normalize_skill_id(skill_id))

# === SKILL CHECKS ===

func make_skill_check(skill: String, dc: int, advantage: bool = false, disadvantage: bool = false) -> bool:
	"""Make a skill check; returns success as bool (back-compat wrapper).
	Use make_skill_check_detailed() for the full roll breakdown."""
	return make_skill_check_detailed(skill, dc, advantage, disadvantage).get("success", false)

func make_skill_check_detailed(skill: String, dc: int, advantage: bool = false, disadvantage: bool = false) -> Dictionary:
	"""Make a skill check: d20 + governing stat modifier + proficiency (doubled for expertise).
	Returns {success, roll, total, dc, modifier, skill, stat, proficient, expertise}."""
	var skill_id = SkillDatabase.normalize_skill_id(skill)
	var stat = SkillDatabase.get_governing_stat(skill_id)

	# Encumbrance gives disadvantage on physical (STR/DEX/CON) checks, matching saves/attacks
	if stat in ["str", "dex", "con"] and InventoryManager.has_disadvantage_on_physical_rolls():
		disadvantage = true

	var modifier = get_modifier_for_stat(stat)
	var proficient = is_proficient_in_skill(skill_id)
	var has_exp = has_expertise_in(skill_id)
	if proficient:
		modifier += proficiency_bonus
	if has_exp:
		modifier += proficiency_bonus

	# Roll d20 with advantage/disadvantage (they cancel out)
	var roll1 = randi_range(1, 20)
	var roll2 = randi_range(1, 20) if (advantage or disadvantage) else roll1
	var roll = roll1
	if advantage and not disadvantage:
		roll = max(roll1, roll2)
	elif disadvantage and not advantage:
		roll = min(roll1, roll2)

	var total = roll + modifier
	var success = total >= dc

	EventBus.skill_check_made.emit(self, skill_id, dc, success)

	return {
		"success": success,
		"roll": roll,
		"total": total,
		"dc": dc,
		"modifier": modifier,
		"skill": skill_id,
		"stat": stat,
		"proficient": proficient,
		"expertise": has_exp
	}

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Export stats to dictionary for saving (primitives only)"""
	return {
		# Identity
		"character_uid": character_uid,
		"character_name": character_name,
		"class_id": class_id,
		"race_id": race_id,
		# Base abilities
		"str": strength,
		"dex": dexterity,
		"con": constitution,
		"int": intelligence,
		"wis": wisdom,
		"cha": charisma,
		# Level / XP
		"level": level,
		"xp": experience,
		"unspent_ability_points": unspent_ability_points,
		# HP (saved so post-construction overrides, e.g. enemies, survive round-trips)
		"current_hp": current_hp,
		"max_hp": max_hp,
		"default_hit_die_sides": default_hit_die_sides,
		# Movement
		"movement_speed": movement_speed,
		# Proficiencies
		"save_proficiencies": Array(get_save_proficiencies()),
		"skill_proficiencies": Array(skill_proficiencies),
		"tool_proficiencies": Array(tool_proficiencies),
		"expertise": Array(expertise),
		"weapon_proficiencies": Array(weapon_proficiencies),
		"armor_proficiencies": Array(armor_proficiencies),
		"racial_traits": Array(racial_traits),
		# Misc
		"temp_modifiers": temp_modifiers.duplicate(true)
	}

func from_dict(data: Dictionary):
	"""Import stats from dictionary (loading). Tolerant of missing keys (old saves)."""
	character_uid = data.get("character_uid", "player")
	character_name = data.get("character_name", "")
	class_id = data.get("class_id", "")
	race_id = data.get("race_id", "")

	strength = data.get("str", 10)
	dexterity = data.get("dex", 10)
	constitution = data.get("con", 10)
	intelligence = data.get("int", 10)
	wisdom = data.get("wis", 10)
	charisma = data.get("cha", 10)

	level = clampi(data.get("level", 1), 1, MAX_LEVEL)
	experience = data.get("xp", 0)
	unspent_ability_points = data.get("unspent_ability_points", 0)
	default_hit_die_sides = data.get("default_hit_die_sides", 10)
	movement_speed = data.get("movement_speed", movement_speed)

	# Saving throw proficiencies
	str_save_proficient = false
	dex_save_proficient = false
	con_save_proficient = false
	int_save_proficient = false
	wis_save_proficient = false
	cha_save_proficient = false
	for stat in data.get("save_proficiencies", []):
		set_save_proficiency(str(stat), true)

	skill_proficiencies.assign(data.get("skill_proficiencies", []))
	tool_proficiencies.assign(data.get("tool_proficiencies", []))
	expertise.assign(data.get("expertise", []))
	weapon_proficiencies.assign(data.get("weapon_proficiencies", []))
	armor_proficiencies.assign(data.get("armor_proficiencies", []))
	racial_traits.assign(data.get("racial_traits", []))

	temp_modifiers = data.get("temp_modifiers", {}).duplicate(true)

	experience_to_next_level = get_xp_for_level(mini(level + 1, MAX_LEVEL))
	recalculate_derived_stats()

	# Restore HP AFTER recalculation so saved overrides (enemies/monsters) survive
	max_hp = data.get("max_hp", max_hp)
	current_hp = clampi(data.get("current_hp", max_hp), 0, max_hp)
