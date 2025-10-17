# character_stats.gd
# Manages all character statistics and calculations
extends RefCounted
class_name CharacterStats

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
var movement_speed: int = 6  # Tiles per turn
var carrying_capacity: int = 150  # Pounds

# Level and XP
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 300

# Proficiency
var proficiency_bonus: int = 2  # +2 at level 1, increases every 4 levels

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
	
	recalculate_derived_stats()

# === STAT MODIFIERS ===

func get_stat_modifier(stat_value: int) -> int:
	"""Calculate D&D stat modifier: (stat - 10) / 2"""
	return int((stat_value - 10) / 2.0)

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

# === DERIVED STATS ===

func recalculate_derived_stats():
	"""Recalculate all derived stats from base + equipment"""
	# HP (base + CON modifier per level)
	var hp_per_level = 10  # Class-dependent (should be from class data)
	max_hp = hp_per_level + (get_con_modifier() * level)
	current_hp = mini(current_hp, max_hp)  # Don't exceed max
	
	# AC (10 + DEX modifier + equipment)
	armor_class = 10 + get_dex_modifier() + equipment_ac_bonus
	
	# Initiative
	initiative_bonus = get_dex_modifier()
	
	# Attack bonuses
	melee_attack_bonus = proficiency_bonus + get_str_modifier()
	ranged_attack_bonus = proficiency_bonus + get_dex_modifier()
	spell_attack_bonus = proficiency_bonus + get_int_modifier()  # Wizard default
	
	# Spell save DC
	spell_save_dc = 8 + proficiency_bonus + get_int_modifier()
	
	# Carrying capacity
	carrying_capacity = (strength + equipment_str_bonus) * 15
	
	# Proficiency bonus (increases every 4 levels)
	proficiency_bonus = 2 + int((level - 1) / 4)

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
		
		# item_instance should have item_data property
		var item_data = null
		if item_instance is Resource:
			item_data = item_instance
		elif item_instance.has("item_data"):
			item_data = item_instance.item_data
		
		if item_data == null:
			continue
		
		# Armor AC bonus
		if item_data.has("armor_class_bonus") and item_data.armor_class_bonus > 0:
			equipment_ac_bonus += item_data.armor_class_bonus
		
		# Stat bonuses from magic items
		if item_data.has("stat_bonuses"):
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
	current_hp -= amount
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

func gain_experience(amount: int):
	"""Gain XP, level up if threshold reached"""
	experience += amount
	
	while experience >= experience_to_next_level:
		level_up()

func level_up():
	"""Level up character"""
	level += 1
	experience -= experience_to_next_level
	
	# Increase XP requirement (increases by 50% each level)
	experience_to_next_level = int(experience_to_next_level * 1.5)
	
	# Increase HP (roll hit die + CON mod)
	var hit_die = 10  # Class-dependent
	var hp_gain = hit_die + get_con_modifier()
	max_hp += max(1, hp_gain)  # Minimum 1 HP per level
	current_hp = max_hp  # Full heal on level up
	
	# Recalculate everything
	recalculate_derived_stats()
	
	print("LEVEL UP! Now level ", level)

# === SAVING THROWS ===

func make_saving_throw(stat: String, dc: int, advantage: bool = false, disadvantage: bool = false) -> bool:
	"""Make a saving throw (d20 + modifier vs DC)"""
	var modifier = 0
	
	match stat.to_lower():
		"str", "strength": modifier = get_str_modifier()
		"dex", "dexterity": modifier = get_dex_modifier()
		"con", "constitution": modifier = get_con_modifier()
		"int", "intelligence": modifier = get_int_modifier()
		"wis", "wisdom": modifier = get_wis_modifier()
		"cha", "charisma": modifier = get_cha_modifier()
	
	var roll1 = randi() % 20 + 1
	var roll2 = randi() % 20 + 1 if (advantage or disadvantage) else roll1
	
	var final_roll = roll1
	if advantage:
		final_roll = max(roll1, roll2)
	elif disadvantage:
		final_roll = min(roll1, roll2)
	
	var total = final_roll + modifier
	return total >= dc

# === SKILL CHECKS ===

func make_skill_check(skill: String, dc: int, advantage: bool = false, disadvantage: bool = false) -> bool:
	"""Make a skill check (d20 + stat modifier + proficiency if proficient)"""
	# Map skills to stats (simplified - should be from character class)
	var skill_to_stat = {
		"athletics": "str",
		"acrobatics": "dex",
		"stealth": "dex",
		"perception": "wis",
		"insight": "wis",
		"investigation": "int",
		"arcana": "int",
		"persuasion": "cha",
		"intimidation": "cha",
		"deception": "cha"
	}
	
	var stat = skill_to_stat.get(skill.to_lower(), "str")
	return make_saving_throw(stat, dc, advantage, disadvantage)

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Export stats to dictionary for saving"""
	return {
		"str": strength,
		"dex": dexterity,
		"con": constitution,
		"int": intelligence,
		"wis": wisdom,
		"cha": charisma,
		"level": level,
		"xp": experience,
		"current_hp": current_hp,
		"max_hp": max_hp
	}

func from_dict(data: Dictionary):
	"""Import stats from dictionary (loading)"""
	strength = data.get("str", 10)
	dexterity = data.get("dex", 10)
	constitution = data.get("con", 10)
	intelligence = data.get("int", 10)
	wisdom = data.get("wis", 10)
	charisma = data.get("cha", 10)
	level = data.get("level", 1)
	experience = data.get("xp", 0)
	current_hp = data.get("current_hp", 20)
	max_hp = data.get("max_hp", 20)
	
	recalculate_derived_stats()
