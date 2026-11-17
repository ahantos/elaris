# combat_manager.gd
# AutoLoad singleton - every die rolled in a fight: attack rolls, damage, saving
# throws, initiative, opportunity attacks. It works out what a combatant attacks
# with (the weapon in hand, by 5e rules), reads status effects and position
# (cover and flanking via CombatGrid), and applies the damage. It does not know
# whose turn it is: the CombatController decides what may be done and asks here
# for the outcome.
extends Node

# Combat constants
const BASE_AC: int = 10  # Base armor class (10 + DEX)
const CRIT_THRESHOLD: int = 20  # Natural 20 = crit
const FUMBLE_THRESHOLD: int = 1  # Natural 1 = fumble

# An unarmed strike (5e): 1 + Strength modifier, bludgeoning, always proficient
const UNARMED_NAME: String = "Unarmed strike"
const UNARMED_DAMAGE: int = 1
const UNARMED_DAMAGE_TYPE: String = "bludgeoning"

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

func _ready():
	print("CombatManager initialized")

# === WHAT A COMBATANT ATTACKS WITH ===

func get_attack_profile(attacker: Combatant) -> Dictionary:
	"""How the combatant attacks right now: the weapon in its hand, or an
	unarmed strike when it holds none. See build_attack_profile for the keys."""
	return build_attack_profile(attacker, attacker.get_wielded_weapon())

func get_unarmed_profile(attacker: Combatant) -> Dictionary:
	"""The combatant's unarmed strike, whatever it is holding"""
	return build_attack_profile(attacker, null)

func build_attack_profile(attacker: Combatant, weapon: ItemData) -> Dictionary:
	"""One attack by 5e rules, as numbers. weapon null is an unarmed strike.
	- Ability: Strength; a finesse weapon uses Dexterity when that is higher;
	  a ranged weapon uses Dexterity.
	- Proficiency bonus only when the attacker is proficient with the weapon.
	- A versatile weapon uses its larger dice when the off hand is empty.
	- A two-handed weapon with something in the off hand, and (until ranged
	  attacks are built) a ranged weapon, cannot attack: usable is false and
	  reason says why.
	Returns {weapon: ItemData or null, weapon_name, damage_dice ("" when the
	damage has no dice), flat_damage, damage_type (contract string), ability
	("str" | "dex"), ability_modifier, proficient, attack_bonus, two_handed_grip,
	is_ranged, usable, reason}."""
	var stats: CharacterStats = attacker.stats
	var strength: int = stats.get_str_modifier()
	var profile: Dictionary = {
		"weapon": null,
		"weapon_name": UNARMED_NAME,
		"damage_dice": "",
		"flat_damage": UNARMED_DAMAGE,
		"damage_type": UNARMED_DAMAGE_TYPE,
		"ability": "str",
		"ability_modifier": strength,
		"proficient": true,
		"attack_bonus": strength + stats.proficiency_bonus,
		"two_handed_grip": false,
		"is_ranged": false,
		"usable": true,
		"reason": "",
	}
	if weapon == null or not weapon.is_weapon:
		return profile

	profile["weapon"] = weapon
	profile["weapon_name"] = weapon.item_name
	profile["damage_type"] = weapon.damage_type if weapon.damage_type != "" else "physical"
	profile["is_ranged"] = weapon.is_ranged
	if weapon.damage_dice != "":
		profile["damage_dice"] = weapon.damage_dice
		profile["flat_damage"] = 0

	var off_hand_free: bool = attacker.is_off_hand_free()
	if _weapon_has_property(weapon, "versatile") and weapon.versatile_dice != "" and off_hand_free:
		profile["damage_dice"] = weapon.versatile_dice
		profile["two_handed_grip"] = true

	var dexterity: int = stats.get_dex_modifier()
	if weapon.is_ranged or (_weapon_has_property(weapon, "finesse") and dexterity > strength):
		profile["ability"] = "dex"
		profile["ability_modifier"] = dexterity

	profile["proficient"] = stats.is_proficient_with_weapon(weapon)
	var attack_bonus: int = int(profile["ability_modifier"])
	if profile["proficient"]:
		attack_bonus += stats.proficiency_bonus
	if weapon.magic_modifier > 0:
		attack_bonus += weapon.magic_modifier
	profile["attack_bonus"] = attack_bonus

	if weapon.is_ranged:
		profile["usable"] = false
		profile["reason"] = "%s is a ranged weapon - ranged attacks cannot be made yet" % weapon.item_name
	elif weapon.is_two_handed and not off_hand_free:
		profile["usable"] = false
		profile["reason"] = "%s needs both hands - empty the off hand" % weapon.item_name
	return profile

# === ATTACK SYSTEM ===

func make_attack(attacker: Combatant, target: Combatant, profile: Dictionary = {}) -> Dictionary:
	"""One melee attack, start to finish: the weapon in the attacker's hand (or
	the profile given), the d20, the damage, and the damage applied to the
	target with the weapon's damage type. Every weapon attack in the game comes
	through here - the Attack action and opportunity attacks, by the player,
	companions and enemies alike.
	Returns the roll_attack result, or {} when the attack could not be made."""
	if profile.is_empty():
		profile = get_attack_profile(attacker)
	if not profile.get("usable", false):
		print("CombatManager: %s cannot attack (%s)" % [attacker.name, str(profile.get("reason", ""))])
		return {}
	var result: Dictionary = roll_attack(attacker, target, profile)
	if result.is_empty():
		return result
	if result.hit:
		apply_damage(target, result.damage, damage_type_from_string(result.damage_type), attacker, result.is_crit)
	return result

func roll_attack(attacker: Combatant, target: Combatant, profile: Dictionary = {},
				 advantage: bool = false, disadvantage: bool = false) -> Dictionary:
	"""Roll one attack by attacker against target, without applying anything.
	profile is what the attacker attacks with (default: get_attack_profile).
	On top of the d20 and the profile's attack bonus:
	- an incapacitated attacker (stunned, paralyzed, frozen) cannot attack at
	  all (the result has auto_fail = true),
	- status effects on either side give advantage or disadvantage, and blessed
	  or cursed change the roll,
	- a target that is dodging gives the attacker disadvantage,
	- a heavily laden party member attacks at disadvantage,
	- an ally of the attacker on the far side of the target (flanking) gives
	  advantage; the attacker says who its flank partners are,
	- the target's AC takes status-effect modifiers and cover,
	- a melee hit on a paralyzed or frozen target next to the attacker is a
	  critical hit.
	Returns {hit, roll, total, target_ac, is_crit, is_fumble, damage,
	damage_type, damage_dice, weapon_name, attack_bonus, advantage,
	disadvantage, cover_bonus, flanking, auto_fail}."""
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target) \
			or attacker.stats == null or target.stats == null:
		push_error("CombatManager.roll_attack: missing attacker or target")
		return {}
	if profile.is_empty():
		profile = get_attack_profile(attacker)

	var attacker_stats: CharacterStats = attacker.stats
	var target_stats: CharacterStats = target.stats
	var result: Dictionary = {
		"hit": false, "roll": 0, "total": 0,
		"target_ac": target_stats.armor_class,
		"is_crit": false, "is_fumble": false,
		"damage": 0,
		"damage_type": str(profile.get("damage_type", "physical")),
		"damage_dice": str(profile.get("damage_dice", "")),
		"weapon_name": str(profile.get("weapon_name", UNARMED_NAME)),
		"attack_bonus": 0,
		"advantage": false, "disadvantage": false,
		"cover_bonus": 0, "flanking": false,
		"auto_fail": false
	}

	# Incapacitated combatants (stunned/paralyzed/frozen) cannot attack at all
	if StatusEffectManager.is_incapacitated(attacker):
		print("CombatManager: %s is incapacitated and cannot attack!" % attacker.name)
		result["auto_fail"] = true
		return result

	# Encumbrance disadvantage - only for whoever is carrying the party's load
	if InventoryManager.is_party_member(attacker_stats) and InventoryManager.has_disadvantage_on_physical_rolls():
		disadvantage = true
		print("⚠️ Heavily encumbered! Disadvantage on attack roll")

	# Status effects on both sides
	var adv_state = StatusEffectManager.get_attack_advantage_state(attacker, target)
	advantage = advantage or adv_state.get("advantage", false)
	disadvantage = disadvantage or adv_state.get("disadvantage", false)

	# The Dodge action: attack rolls against the dodger have disadvantage
	if target.is_dodging():
		disadvantage = true

	var attacker_pos: Vector2i = attacker.get_grid_position()
	var target_pos: Vector2i = target.get_grid_position()

	# Flanking: an ally mirrored on the far side of the target grants advantage
	var flank_partners: Array = attacker.get_flank_partners()
	var flanking = false
	if not flank_partners.is_empty():
		flanking = CombatGrid.is_flanking(attacker_pos, target_pos, flank_partners)
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

	# Ability modifier, proficiency and the weapon's own bonus come from the
	# profile; blessed and cursed add to the roll
	var attack_bonus: int = int(profile.get("attack_bonus", 0)) + StatusEffectManager.get_attack_roll_modifier(attacker)
	var total = roll + attack_bonus

	# Target AC: base + status-effect AC modifiers + positional cover
	var target_ac = target_stats.armor_class + StatusEffectManager.get_ac_modifier(target)
	var cover_bonus = 0
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
	if hit and not is_crit and not profile.get("is_ranged", false):
		if CombatGrid.get_distance_tiles(attacker_pos, target_pos) <= 1:
			if StatusEffectManager.has_effect(target, "paralyzed") or StatusEffectManager.has_effect(target, "frozen"):
				is_crit = true
				print("CombatManager: melee hit on a helpless target - automatic critical!")

	result["hit"] = hit
	result["roll"] = roll
	result["total"] = total
	result["target_ac"] = target_ac
	result["is_crit"] = is_crit
	result["is_fumble"] = is_fumble
	result["damage"] = roll_damage(profile, is_crit) if hit else 0
	result["attack_bonus"] = attack_bonus
	result["advantage"] = advantage
	result["disadvantage"] = disadvantage
	result["cover_bonus"] = cover_bonus
	result["flanking"] = flanking
	return result

func roll_damage(profile: Dictionary, is_crit: bool = false) -> int:
	"""Roll the damage of one hit with an attack profile: its dice (rolled
	twice on a critical hit), any flat damage, and the same ability modifier
	the attack roll used. Never less than 1."""
	var damage: int = int(profile.get("flat_damage", 0))
	var dice: String = str(profile.get("damage_dice", ""))
	if dice != "":
		damage += roll_dice(dice)
		if is_crit:
			damage += roll_dice(dice)
	damage += int(profile.get("ability_modifier", 0))
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
	"""Apply damage to target, returns true if still alive. damage_type (a
	DamageType) travels with the damage and is announced with it; it changes
	nothing yet (resistances come with the damage pipeline)."""
	if not target:
		push_error("CombatManager.apply_damage: No target provided!")
		return false

	# Check if target has stats property
	if not target.get("stats") or not target.stats:
		push_error("CombatManager.apply_damage: Target '%s' has no CharacterStats!" % target.name)
		return false

	var still_alive = target.stats.take_damage(amount)

	if attacker:
		EventBus.damage_dealt.emit(attacker, target, amount, is_critical, damage_type)

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
	- a combatant that is dodging makes DEX saves with advantage,
	- blessed/cursed add +2/-2 to the save total (reported as status_modifier).
	Returns: {success, roll, total, dc, modifier, status_modifier, advantage,
	disadvantage, auto_fail}
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
		return {"success": false, "roll": 0, "total": 0, "dc": dc, "modifier": 0, "status_modifier": 0,
			"advantage": false, "disadvantage": false, "auto_fail": true}

	# Restrained creatures dodge poorly
	if node_valid and is_dex_save and StatusEffectManager.has_effect(target_node, "restrained"):
		disadvantage = true

	# The Dodge action: Dexterity saves with advantage
	if node_valid and is_dex_save and target_node is Combatant and target_node.is_dodging():
		advantage = true

	# Check for encumbrance disadvantage on physical saves (STR, DEX, CON)
	if stat_key in ["str", "strength", "dex", "dexterity", "con", "constitution"]:
		if InventoryManager.is_party_member(character_stats) and InventoryManager.has_disadvantage_on_physical_rolls():
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
		"advantage": advantage,
		"disadvantage": disadvantage,
		"auto_fail": false
	}

# === REACTIONS ===

func trigger_opportunity_attack(reactor: Node, mover: Node) -> Dictionary:
	"""
	Attempt an opportunity attack from `reactor` against `mover` (who is about to leave
	the reactor's melee reach). Combatant._check_opportunity_attacks calls this when a
	combatant steps from a tile adjacent to a hostile to a tile that is not.
	Checks performed here: both are living combatants, the reactor still has its
	reaction (Combatant.reaction_used - it comes back at the start of the reactor's
	own turn) and can take reactions (status effects), and the mover stands next to
	it (Chebyshev distance exactly 1).
	On success: spends the reaction and makes one melee attack through make_attack
	with the weapon in the reactor's hand; a weapon that cannot make a melee attack
	(a ranged one) gives way to an unarmed strike. Emits
	EventBus.reaction_triggered(reactor, "opportunity_attack", mover).
	A missed opportunity attack still spends the reaction.
	Returns {triggered: bool, reason: String, result: Dictionary (attack result if rolled)}.
	"""
	if reactor == null or not is_instance_valid(reactor) or not (reactor is Combatant) or reactor.stats == null:
		return {"triggered": false, "reason": "invalid_reactor", "result": {}}
	if mover == null or not is_instance_valid(mover) or not (mover is Combatant) or mover.stats == null:
		return {"triggered": false, "reason": "invalid_mover", "result": {}}
	if not reactor.stats.is_alive() or not mover.stats.is_alive():
		return {"triggered": false, "reason": "dead_combatant", "result": {}}
	if reactor.reaction_used:
		return {"triggered": false, "reason": "reaction_already_used", "result": {}}
	if not StatusEffectManager.can_take_reactions(reactor):
		return {"triggered": false, "reason": "cannot_react", "result": {}}
	if CombatGrid.get_distance_tiles(reactor.get_grid_position(), mover.get_grid_position()) != 1:
		return {"triggered": false, "reason": "not_adjacent", "result": {}}

	var profile: Dictionary = get_attack_profile(reactor)
	if not profile.usable:
		profile = get_unarmed_profile(reactor)

	print("CombatManager: %s makes an opportunity attack against %s!" % [reactor.name, mover.name])
	reactor.reaction_used = true

	var result = make_attack(reactor, mover, profile)
	if result.is_empty():
		return {"triggered": false, "reason": "roll_failed", "result": {}}

	if result.get("hit", false):
		print("CombatManager: opportunity attack hits for %d damage!" % result.damage)
	else:
		print("CombatManager: opportunity attack misses (%d vs AC %d)" % [result.get("total", 0), result.get("target_ac", 0)])

	EventBus.reaction_triggered.emit(reactor, "opportunity_attack", mover)
	return {"triggered": true, "reason": "ok", "result": result}

# === INTERNAL HELPERS ===

func _weapon_has_property(weapon: ItemData, property_name: String) -> bool:
	"""Check a weapon's special_properties array (e.g. "finesse", "reach", "thrown")."""
	if weapon == null:
		return false
	return property_name in weapon.special_properties

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
