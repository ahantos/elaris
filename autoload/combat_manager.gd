# combat_manager.gd
# AutoLoad singleton - handles all combat logic, damage calculation, attack rolls
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

func _ready():
	print("CombatManager initialized")

# === ATTACK SYSTEM ===

func roll_attack(attacker_stats: CharacterStats, target_stats: CharacterStats, 
				 weapon: ItemData = null, advantage: bool = false, 
				 disadvantage: bool = false) -> Dictionary:
	"""
	Roll an attack using D&D 5e rules
	Returns: {hit: bool, roll: int, total: int, target_ac: int, is_crit: bool, is_fumble: bool, damage: int}
	"""
	
	if not attacker_stats or not target_stats:
		push_error("CombatManager.roll_attack: Missing attacker or target stats!")
		return {}
	
	# Check for encumbrance disadvantage
	if InventoryManager.has_disadvantage_on_physical_rolls():
		disadvantage = true
		print("⚠️ Heavily encumbered! Disadvantage on attack roll")
	
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
	
	# Calculate attack bonus
	var attack_bonus = attacker_stats.get_str_modifier() + attacker_stats.proficiency_bonus
	
	if weapon and weapon.is_weapon:
		if weapon.is_ranged:
			attack_bonus = attacker_stats.get_dex_modifier() + attacker_stats.proficiency_bonus
		if weapon.magic_modifier > 0:
			attack_bonus += weapon.magic_modifier
	
	# Total attack roll
	var total = roll + attack_bonus
	var target_ac = target_stats.armor_class
	
	# Check if hit
	var hit = false
	if is_crit:
		hit = true
	elif is_fumble:
		hit = false
	else:
		hit = (total >= target_ac)
	
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
		"attack_bonus": attack_bonus
	}

func roll_damage(weapon: ItemData, attacker_stats: CharacterStats, is_crit: bool = false) -> int:
	"""Roll damage for a weapon attack"""
	var damage = 0
	
	if weapon and weapon.is_weapon and weapon.damage_dice != "":
		var dice_parts = weapon.damage_dice.split("d")
		if dice_parts.size() == 2:
			var num_dice = int(dice_parts[0])
			var die_size = int(dice_parts[1])
			
			for i in range(num_dice):
				damage += randi_range(1, die_size)
			
			if is_crit:
				for i in range(num_dice):
					damage += randi_range(1, die_size)
	else:
		damage = randi_range(1, 4)
		if is_crit:
			damage += randi_range(1, 4)
	
	var stat_bonus = attacker_stats.get_str_modifier()
	if weapon and weapon.is_ranged:
		stat_bonus = attacker_stats.get_dex_modifier()
	
	damage += stat_bonus
	return max(1, damage)

func apply_damage(target: Node, amount: int, damage_type: int = DamageType.PHYSICAL, attacker: Node = null) -> bool:
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
		EventBus.damage_dealt.emit(attacker, target, amount, false)
	
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
					   advantage: bool = false, disadvantage: bool = false) -> Dictionary:
	"""
	Make a saving throw (d20 + modifier vs DC)
	Returns: {success: bool, roll: int, total: int, dc: int, modifier: int}
	"""
	
	if not character_stats:
		push_error("CombatManager.make_saving_throw: No character stats provided!")
		return {}
	
	# Check for encumbrance disadvantage on physical saves (STR, DEX, CON)
	if stat.to_lower() in ["str", "strength", "dex", "dexterity", "con", "constitution"]:
		if InventoryManager.has_disadvantage_on_physical_rolls():
			disadvantage = true
			print("⚠️ Heavily encumbered! Disadvantage on %s save" % stat.to_upper())
	
	var modifier = 0
	
	match stat.to_lower():
		"str", "strength": modifier = character_stats.get_str_modifier()
		"dex", "dexterity": modifier = character_stats.get_dex_modifier()
		"con", "constitution": modifier = character_stats.get_con_modifier()
		"int", "intelligence": modifier = character_stats.get_int_modifier()
		"wis", "wisdom": modifier = character_stats.get_wis_modifier()
		"cha", "charisma": modifier = character_stats.get_cha_modifier()
	
	# Add proficiency if proficient in this save
	if character_stats.is_proficient_in_save(stat):
		modifier += character_stats.proficiency_bonus
	
	# Roll d20 with advantage/disadvantage
	var roll1 = randi_range(1, 20)
	var roll2 = randi_range(1, 20) if (advantage or disadvantage) else roll1
	
	var final_roll = roll1
	if advantage and not disadvantage:
		final_roll = max(roll1, roll2)
	elif disadvantage and not advantage:
		final_roll = min(roll1, roll2)
	
	var total = final_roll + modifier
	var success = total >= dc
	
	return {
		"success": success,
		"roll": final_roll,
		"total": total,
		"dc": dc,
		"modifier": modifier
	}
