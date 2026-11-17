# combat_manager.gd
# AutoLoad singleton - every die rolled in a fight: attack rolls, damage, saving
# throws, initiative, opportunity attacks. It works out what a combatant attacks
# with (the melee weapon in hand or the ranged weapon it carries, by 5e rules),
# reads status effects and position (range, cover and flanking via CombatGrid),
# says what the chance to hit is before anything is rolled, and applies the
# damage. It does not know whose turn it is: the CombatController decides what
# may be done and asks here for the outcome.
#
# THE DAMAGE PIPELINE
# All damage - a weapon hit, a spell, a status effect's tick, anything else -
# is applied by deal_damage(source, target, amount, damage_type, context), in
# this order:
#   1. EventBus.damage_incoming(event). event.amount is what was rolled; a
#      listener may change it (a flat bonus or reduction). The event already
#      says whether the target is immune, resistant or vulnerable to the type.
#   2. The target's immunity (no damage), resistance (half, rounded down) and
#      vulnerability (double) to the damage type, as in 5e.
#   3. If that would leave the target on 0 hit points:
#      EventBus.dropping_to_zero(event). A listener may set event.prevented =
#      true (and event.hp_left, 1 unless it says otherwise, and
#      event.prevented_by, a name to show).
#   4. The hit points are taken. EventBus.damage_applied(event), with
#      event.amount now the hit points lost, and EventBus.damage_dealt for
#      listeners that only need to know someone was hurt.
#   5. Death, when the target is on 0.
# The event Dictionary, the same object through all the steps:
#   source        Combatant or null: who or what did it
#   target        Combatant
#   damage_type   contract string ("slashing", "fire", "poison")
#   amount        see the steps above
#   rolled        the amount handed to deal_damage; never changed
#   is_critical   bool
#   kind          "weapon" | "spell" | "effect" | "other"
#   context       what the caller passed: weapon (ItemData), weapon_instance,
#                 spell_id, effect_id
#   immune, resistant, vulnerable   bool: what the target is to this type
#   response      "" | "immune" | "resisted" | "vulnerable": what its nature did
#   prevented, hp_left, prevented_by   see step 3
#   hp_before, hp_after, killed        filled in step 4
#
# An attack roll is announced with EventBus.attack_resolved(event), once the
# roll is made and its damage applied - for a hit and for a miss, for weapon
# attacks (make_attack) and spell attacks (make_spell_attack):
#   attacker, target
#   kind             "weapon" | "unarmed" | "spell"
#   roll             the natural d20 that counted
#   hit, is_crit, is_fumble (a natural 1)
#   outcome          "critical" | "hit" | "miss" | "natural_1"
#   weapon           ItemData or null
#   weapon_instance  the item instance in the attacker's hand, {} when there is
#                    none behind the attack
#   natural_weapon   true when no item instance is behind a weapon attack: an
#                    unarmed strike, or a creature's own attack (every enemy
#                    until the bestiary gives them gear)
#   weapon_name, damage_type, is_ranged
#   two_handed       the weapon is a two-handed weapon
#   two_handed_grip  it was swung in both hands (also a versatile weapon)
#   damage           hit points the target lost; 0 on a miss
#   damage_response  the response of the damage event ("resisted", ...)
#   spell_id         for a spell attack
#   result           the whole attack result
extends Node

# Combat constants
const BASE_AC: int = 10  # Base armor class (10 + DEX)
const CRIT_THRESHOLD: int = 20  # Natural 20 = crit
const FUMBLE_THRESHOLD: int = 1  # Natural 1 = fumble
const D20_FACES: int = 20

# How far a melee attack reaches, in tiles
const MELEE_REACH: int = 1

# An unarmed strike (5e): 1 + Strength modifier, bludgeoning, always proficient
const UNARMED_NAME: String = "Unarmed strike"
const UNARMED_DAMAGE: int = 1
const UNARMED_DAMAGE_TYPE: String = "bludgeoning"

# Why an attack roll has advantage or disadvantage, or its target more armour:
# the words get_attack_modifiers and get_hit_chance give in their reasons.
# Status effects add their own names (StatusEffectManager.get_attack_advantage_sources).
const REASON_LONG_RANGE: String = "long range"
const REASON_ENEMY_ADJACENT: String = "enemy adjacent"
const REASON_ENCUMBERED: String = "encumbered"
const REASON_UNTRAINED_ARMOR: String = "armour without proficiency"
const REASON_TARGET_DODGING: String = "target dodging"
const REASON_FLANKING: String = "flanking"
const REASON_HALF_COVER: String = "half cover"
const REASON_FULL_COVER: String = "full cover"
const REASON_INCAPACITATED: String = "incapacitated"

# What a target's nature did to damage of a type (the damage event's response)
const RESPONSE_IMMUNE: String = "immune"
const RESPONSE_RESISTED: String = "resisted"
const RESPONSE_VULNERABLE: String = "vulnerable"

# Who dealt the damage, in the damage event's kind
const KIND_WEAPON: String = "weapon"
const KIND_UNARMED: String = "unarmed"
const KIND_SPELL: String = "spell"
const KIND_EFFECT: String = "effect"
const KIND_OTHER: String = "other"

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

func get_attack_profile(attacker: Combatant, target: Combatant = null) -> Dictionary:
	"""How the combatant attacks. With a target, the weapon follows it:
	- a target in reach (adjacent): the melee weapon in the main hand, or an
	  unarmed strike;
	- a target beyond reach: the ranged weapon the attacker carries, if it has
	  one;
	- an adjacent target and nothing but a ranged weapon: that weapon (the shot
	  has disadvantage, see get_attack_modifiers), or an unarmed strike when it
	  cannot be fired.
	Without a target: the weapon in hand (Combatant.get_wielded_weapon).
	Whether the target can be attacked at all - reach, range, line of sight - is
	the CombatController's to say. See build_attack_profile for the keys."""
	if target == null or not is_instance_valid(target):
		return build_attack_profile(attacker, attacker.get_wielded_weapon())
	var melee: ItemData = attacker.get_melee_weapon()
	var ranged: ItemData = attacker.get_ranged_weapon()
	if CombatGrid.get_distance_tiles(attacker.get_grid_position(), target.get_grid_position()) > MELEE_REACH:
		return build_attack_profile(attacker, ranged if ranged != null else melee)
	if melee != null or ranged == null:
		return build_attack_profile(attacker, melee)
	var shot: Dictionary = build_attack_profile(attacker, ranged)
	return shot if shot.usable else get_unarmed_profile(attacker)

func get_melee_profile(attacker: Combatant) -> Dictionary:
	"""The combatant's attack on a target in reach: its melee weapon, or an
	unarmed strike"""
	return build_attack_profile(attacker, attacker.get_melee_weapon())

func get_ranged_profile(attacker: Combatant) -> Dictionary:
	"""The combatant's attack on a target beyond reach, or {} when it carries
	no ranged weapon"""
	var weapon: ItemData = attacker.get_ranged_weapon()
	return build_attack_profile(attacker, weapon) if weapon != null else {}

func get_unarmed_profile(attacker: Combatant) -> Dictionary:
	"""The combatant's unarmed strike, whatever it is holding"""
	return build_attack_profile(attacker, null)

func get_weapon_range(weapon: ItemData) -> Dictionary:
	"""{normal, max}: how far a ranged weapon shoots, in tiles (one tile is 5
	feet). Up to normal it shoots plainly, up to max at disadvantage, further
	not at all. The weapon table stores its ranges in tiles already: a shortbow's
	16 and 64 are the 5e 80 and 320 feet. {0, 0} for anything that is not a
	ranged weapon."""
	if weapon == null or not weapon.is_ranged:
		return {"normal": 0, "max": 0}
	return {"normal": weapon.range_normal, "max": max(weapon.range_normal, weapon.range_max)}

func get_damage_text(profile: Dictionary) -> String:
	"""An attack profile's damage as the player reads it: '1d8+2 slashing' for a
	weapon, '3 bludgeoning' for an unarmed strike"""
	var modifier: int = int(profile.get("ability_modifier", 0)) + int(profile.get("damage_bonus", 0))
	var amount: String = str(profile.get("damage_dice", ""))
	if amount == "":
		amount = str(max(1, int(profile.get("flat_damage", 0)) + modifier))
	elif modifier > 0:
		amount += "+%d" % modifier
	elif modifier < 0:
		amount += str(modifier)
	return "%s %s" % [amount, str(profile.get("damage_type", "physical"))]

func build_attack_profile(attacker: Combatant, weapon: ItemData) -> Dictionary:
	"""One attack by 5e rules, as numbers. weapon null is an unarmed strike.
	- Ability: Strength; a finesse weapon uses Dexterity when that is higher;
	  a ranged weapon uses Dexterity, for the attack roll and the damage.
	- Proficiency bonus only when the attacker is proficient with the weapon.
	- A versatile weapon uses its larger dice when the off hand is empty.
	- A two-handed weapon, melee or ranged, with something in the off hand
	  cannot attack: usable is false and reason says why. What is in the main
	  hand never stops a shot: drawing and stowing a weapon is free.
	- The piece in the attacker's hand adds its own bonus, read from the item
	  instance: the higher of its craftsmanship and magic bonus to the attack
	  roll, its magic bonus to the damage.
	Returns {weapon: ItemData or null, weapon_instance (the instance the
	attacker holds of it, {} for none), weapon_name, damage_dice ("" when the
	damage has no dice), flat_damage, damage_bonus (the weapon's magic bonus to
	damage), damage_type (contract string), ability ("str" | "dex"),
	ability_modifier, proficient, attack_bonus, two_handed_grip, is_ranged,
	range_normal, range_max (tiles; 0 for a melee attack), usable, reason}."""
	var stats: CharacterStats = attacker.stats
	var strength: int = stats.get_str_modifier()
	var profile: Dictionary = {
		"weapon": null,
		"weapon_instance": {},
		"weapon_name": UNARMED_NAME,
		"damage_dice": "",
		"flat_damage": UNARMED_DAMAGE,
		"damage_bonus": 0,
		"damage_type": UNARMED_DAMAGE_TYPE,
		"ability": "str",
		"ability_modifier": strength,
		"proficient": true,
		"attack_bonus": strength + stats.proficiency_bonus,
		"two_handed_grip": false,
		"is_ranged": false,
		"range_normal": 0,
		"range_max": 0,
		"usable": true,
		"reason": "",
	}
	if weapon == null or not weapon.is_weapon:
		return profile

	var instance: Dictionary = attacker.get_weapon_instance(weapon)
	profile["weapon"] = weapon
	profile["weapon_instance"] = instance
	profile["weapon_name"] = weapon.item_name if instance.is_empty() else ItemDatabase.get_instance_name(instance)
	profile["damage_type"] = weapon.damage_type if weapon.damage_type != "" else "physical"
	profile["is_ranged"] = weapon.is_ranged
	var reach: Dictionary = get_weapon_range(weapon)
	profile["range_normal"] = reach.normal
	profile["range_max"] = reach.max
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
	attack_bonus += ItemDatabase.get_instance_bonus(instance)
	profile["attack_bonus"] = attack_bonus
	profile["damage_bonus"] = ItemDatabase.get_instance_magic_bonus(instance)

	if weapon.is_two_handed and not off_hand_free:
		profile["usable"] = false
		profile["reason"] = "%s needs both hands free" % weapon.item_name
	return profile

# === ATTACK SYSTEM ===

func make_attack(attacker: Combatant, target: Combatant, profile: Dictionary = {}) -> Dictionary:
	"""One weapon attack, melee or ranged, start to finish: the weapon that
	suits the target (or the profile given), the d20, the damage, and the damage
	put through the pipeline (deal_damage) with the weapon's damage type. Every
	weapon attack in the game comes through here - the Attack action and
	opportunity attacks, by the player, companions and enemies alike. Announces
	the attack with EventBus.attack_resolved, hit or miss.
	Returns the roll_attack result, or {} when the attack could not be made. On
	a hit, damage is the hit points the target lost, damage_rolled what the dice
	gave, damage_response what the target's nature did to it ("resisted",
	"vulnerable", "immune" or "") and prevented_by what kept the target on its
	feet, if anything did."""
	if profile.is_empty():
		profile = get_attack_profile(attacker, target)
	if not profile.get("usable", false):
		print("CombatManager: %s cannot attack (%s)" % [attacker.name, str(profile.get("reason", ""))])
		return {}
	var result: Dictionary = roll_attack(attacker, target, profile)
	if result.is_empty() or result.auto_fail:
		return result
	result["damage_rolled"] = result.damage
	result["damage_response"] = ""
	result["prevented_by"] = ""
	var weapon: ItemData = profile.get("weapon")
	var instance: Dictionary = profile.get("weapon_instance", {})
	if result.hit:
		var dealt: Dictionary = deal_damage(attacker, target, result.damage, result.damage_type, {
			"kind": KIND_WEAPON, "is_critical": result.is_crit, "weapon": weapon, "weapon_instance": instance,
		})
		result["damage"] = int(dealt.get("amount", 0))
		result["damage_response"] = str(dealt.get("response", ""))
		result["prevented_by"] = str(dealt.get("prevented_by", ""))
	EventBus.attack_resolved.emit({
		"attacker": attacker,
		"target": target,
		"kind": KIND_WEAPON if weapon != null else KIND_UNARMED,
		"roll": result.roll,
		"hit": result.hit,
		"is_crit": result.is_crit,
		"is_fumble": result.is_fumble,
		"outcome": _attack_outcome(result),
		"weapon": weapon,
		"weapon_instance": instance,
		"natural_weapon": instance.is_empty(),
		"weapon_name": result.weapon_name,
		"damage_type": result.damage_type,
		"is_ranged": result.is_ranged,
		"two_handed": weapon != null and weapon.is_two_handed,
		"two_handed_grip": bool(profile.get("two_handed_grip", false)) or (weapon != null and weapon.is_two_handed),
		"damage": result.damage,
		"damage_response": result.damage_response,
		"result": result,
	})
	return result

func make_spell_attack(caster: Combatant, target: Combatant, spell: Dictionary) -> Dictionary:
	"""One spell attack: a d20 plus the caster's spell attack bonus against the
	target's armour class (with its status effects), and on a hit the spell's
	damage dice, rolled twice on a natural 20, put through the pipeline with the
	spell's damage type. A natural 1 always misses. Announces the attack with
	EventBus.attack_resolved, hit or miss.
	Returns {hit, roll, total, attack_bonus, target_ac, is_crit, is_fumble,
	damage (hit points lost), damage_rolled, damage_type, damage_response,
	prevented_by}."""
	var spell_id: String = str(spell.get("spell_id", ""))
	var damage_type: String = str(spell.get("damage_type", "physical"))
	var roll: int = randi_range(1, D20_FACES)
	var is_crit: bool = roll == CRIT_THRESHOLD
	var is_fumble: bool = roll == FUMBLE_THRESHOLD
	var attack_bonus: int = int(caster.stats.spell_attack_bonus) if is_instance_valid(caster) and caster.stats != null else 0
	var target_ac: int = int(target.stats.armor_class) + StatusEffectManager.get_ac_modifier(target)
	var result: Dictionary = {
		"hit": is_crit or (not is_fumble and roll + attack_bonus >= target_ac),
		"roll": roll, "total": roll + attack_bonus, "attack_bonus": attack_bonus, "target_ac": target_ac,
		"is_crit": is_crit, "is_fumble": is_fumble,
		"damage": 0, "damage_rolled": 0, "damage_type": damage_type, "damage_response": "", "prevented_by": "",
	}
	var dice: String = str(spell.get("damage_dice", ""))
	if result.hit and dice != "":
		var rolled: int = roll_dice(dice)
		if is_crit:
			rolled += roll_dice(dice)
		result["damage_rolled"] = rolled
		if rolled > 0:
			var dealt: Dictionary = deal_damage(caster, target, rolled, damage_type, {
				"kind": KIND_SPELL, "is_critical": is_crit, "spell_id": spell_id,
			})
			result["damage"] = int(dealt.get("amount", 0))
			result["damage_response"] = str(dealt.get("response", ""))
			result["prevented_by"] = str(dealt.get("prevented_by", ""))
	EventBus.attack_resolved.emit({
		"attacker": caster,
		"target": target,
		"kind": KIND_SPELL,
		"roll": roll,
		"hit": result.hit,
		"is_crit": is_crit,
		"is_fumble": is_fumble,
		"outcome": _attack_outcome(result),
		"weapon": null,
		"weapon_instance": {},
		"natural_weapon": false,
		"weapon_name": str(spell.get("display_name", spell_id)),
		"damage_type": damage_type,
		"is_ranged": int(spell.get("range_tiles", 0)) > MELEE_REACH,
		"two_handed": false,
		"two_handed_grip": false,
		"damage": result.damage,
		"damage_response": result.damage_response,
		"spell_id": spell_id,
		"result": result,
	})
	return result

func _attack_outcome(result: Dictionary) -> String:
	"""An attack result in one word: critical, hit, miss or natural_1"""
	if result.get("is_fumble", false):
		return "natural_1"
	if not result.get("hit", false):
		return "miss"
	return "critical" if result.get("is_crit", false) else "hit"

func get_attack_modifiers(attacker: Combatant, target: Combatant, profile: Dictionary,
						  advantage: bool = false, disadvantage: bool = false) -> Dictionary:
	"""Everything that bears on one attack roll before the die is cast, and why.
	roll_attack rolls with it and get_hit_chance turns it into a chance, so what
	the player is shown is what is rolled. No dice.
	- Status effects on either side give advantage or disadvantage; blessed or
	  cursed change the attack bonus; the target's AC takes its effects.
	- A target that is dodging gives disadvantage.
	- A heavily laden party member attacks at disadvantage.
	- An attacker in body armour or with a shield its class is not proficient
	  with attacks at disadvantage.
	- Melee: an ally of the attacker on the far side of the target (flanking)
	  gives advantage; the attacker says who its flank partners are.
	- Ranged: beyond the weapon's normal range, disadvantage; a hostile next to
	  the attacker that is not incapacitated, disadvantage.
	- Cover (CombatGrid.get_cover_ac_bonus) adds to the target's AC. Only an
	  attack from beyond reach can meet any.
	Returns {advantage, disadvantage, advantage_reasons, disadvantage_reasons,
	reasons (both lists and the cover, as words to show: "long range", "enemy
	adjacent", "half cover"), attack_bonus, target_ac, cover_bonus, flanking,
	distance (tiles)}. Advantage and disadvantage together cancel out."""
	var advantage_reasons: Array[String] = []
	var disadvantage_reasons: Array[String] = []
	if advantage:
		advantage_reasons.append("advantage")
	if disadvantage:
		disadvantage_reasons.append("disadvantage")

	var attacker_pos: Vector2i = attacker.get_grid_position()
	var target_pos: Vector2i = target.get_grid_position()
	var distance: int = CombatGrid.get_distance_tiles(attacker_pos, target_pos)
	var is_ranged: bool = profile.get("is_ranged", false)

	# Encumbrance - only for whoever is carrying the party's load
	if InventoryManager.is_party_member(attacker.stats) and InventoryManager.has_disadvantage_on_physical_rolls():
		disadvantage_reasons.append(REASON_ENCUMBERED)
	if attacker.stats.wears_untrained_armor():
		disadvantage_reasons.append(REASON_UNTRAINED_ARMOR)

	# Status effects on both sides
	var sources: Dictionary = StatusEffectManager.get_attack_advantage_sources(attacker, target)
	advantage_reasons.append_array(sources.advantage)
	disadvantage_reasons.append_array(sources.disadvantage)

	# The Dodge action: attack rolls against the dodger have disadvantage
	if target.is_dodging():
		disadvantage_reasons.append(REASON_TARGET_DODGING)

	var flanking: bool = false
	if is_ranged:
		if distance > int(profile.get("range_normal", 0)):
			disadvantage_reasons.append(REASON_LONG_RANGE)
		if _has_threat_adjacent(attacker):
			disadvantage_reasons.append(REASON_ENEMY_ADJACENT)
	else:
		# Flanking: an ally mirrored on the far side of the target
		var flank_partners: Array = attacker.get_flank_partners()
		flanking = not flank_partners.is_empty() and CombatGrid.is_flanking(attacker_pos, target_pos, flank_partners)
		if flanking:
			advantage_reasons.append(REASON_FLANKING)

	# Positional cover adds to the target's AC
	var cover_bonus: int = 0
	var dungeon_grid: Array = _get_dungeon_grid()
	if not dungeon_grid.is_empty():
		cover_bonus = CombatGrid.get_cover_ac_bonus(attacker_pos, target_pos, dungeon_grid)

	var reasons: Array[String] = []
	reasons.append_array(disadvantage_reasons)
	reasons.append_array(advantage_reasons)
	if cover_bonus >= CombatGrid.COVER_FULL:
		reasons.append(REASON_FULL_COVER)
	elif cover_bonus > 0:
		reasons.append(REASON_HALF_COVER)

	return {
		"advantage": not advantage_reasons.is_empty(),
		"disadvantage": not disadvantage_reasons.is_empty(),
		"advantage_reasons": advantage_reasons,
		"disadvantage_reasons": disadvantage_reasons,
		"reasons": reasons,
		# Ability modifier, proficiency and the weapon's own bonus come from the
		# profile; blessed and cursed add to the roll
		"attack_bonus": int(profile.get("attack_bonus", 0)) + StatusEffectManager.get_attack_roll_modifier(attacker),
		"target_ac": target.stats.armor_class + StatusEffectManager.get_ac_modifier(target) + cover_bonus,
		"cover_bonus": cover_bonus,
		"flanking": flanking,
		"distance": distance,
	}

func get_hit_chance(attacker: Combatant, target: Combatant, profile: Dictionary = {}) -> Dictionary:
	"""The chance that an attack by attacker on target hits, worked out and not
	rolled: what the player is shown before committing. profile is what the
	attacker attacks with (default: get_attack_profile for this target).
	A natural 20 always hits and a natural 1 always misses; with advantage the
	better of two d20 counts, with disadvantage the worse, and the two cancel.
	Returns {chance (0.0 to 1.0), percent (rounded), needed (the lowest d20
	face that hits, 2 to 20), attack_bonus, target_ac, cover_bonus, advantage,
	disadvantage, advantage_reasons, disadvantage_reasons, reasons, flanking,
	distance, auto_fail} - the modifiers as get_attack_modifiers gives them.
	An incapacitated attacker cannot attack: chance 0 and auto_fail."""
	var preview: Dictionary = {
		"chance": 0.0, "percent": 0, "needed": CRIT_THRESHOLD,
		"attack_bonus": 0, "target_ac": 0, "cover_bonus": 0,
		"advantage": false, "disadvantage": false,
		"advantage_reasons": [], "disadvantage_reasons": [], "reasons": [],
		"flanking": false, "distance": 0, "auto_fail": false,
	}
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target) \
			or attacker.stats == null or target.stats == null:
		return preview
	if profile.is_empty():
		profile = get_attack_profile(attacker, target)
	preview.merge(get_attack_modifiers(attacker, target, profile), true)

	if StatusEffectManager.is_incapacitated(attacker):
		preview["auto_fail"] = true
		preview["reasons"] = [REASON_INCAPACITATED]
		return preview

	var needed: int = clampi(int(preview.target_ac) - int(preview.attack_bonus), FUMBLE_THRESHOLD + 1, CRIT_THRESHOLD)
	var chance: float = float(D20_FACES - needed + 1) / float(D20_FACES)
	if preview.advantage and not preview.disadvantage:
		chance = 1.0 - (1.0 - chance) * (1.0 - chance)
	elif preview.disadvantage and not preview.advantage:
		chance = chance * chance
	preview["needed"] = needed
	preview["chance"] = chance
	preview["percent"] = int(round(chance * 100.0))
	return preview

func roll_attack(attacker: Combatant, target: Combatant, profile: Dictionary = {},
				 advantage: bool = false, disadvantage: bool = false) -> Dictionary:
	"""Roll one attack by attacker against target, without applying anything.
	profile is what the attacker attacks with (default: get_attack_profile for
	this target). The d20 is rolled with what get_attack_modifiers says:
	advantage or disadvantage, the attack bonus, the target's AC with cover.
	Besides:
	- an incapacitated attacker (stunned, paralyzed, frozen) cannot attack at
	  all (the result has auto_fail = true),
	- a melee hit on a paralyzed or frozen target next to the attacker is a
	  critical hit.
	Returns {hit, roll, total, target_ac, is_crit, is_fumble, damage,
	damage_type, damage_dice, weapon_name, is_ranged, attack_bonus, advantage,
	disadvantage, reasons, cover_bonus, flanking, distance, auto_fail}."""
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target) \
			or attacker.stats == null or target.stats == null:
		push_error("CombatManager.roll_attack: missing attacker or target")
		return {}
	if profile.is_empty():
		profile = get_attack_profile(attacker, target)

	var result: Dictionary = {
		"hit": false, "roll": 0, "total": 0,
		"target_ac": target.stats.armor_class,
		"is_crit": false, "is_fumble": false,
		"damage": 0,
		"damage_type": str(profile.get("damage_type", "physical")),
		"damage_dice": str(profile.get("damage_dice", "")),
		"weapon_name": str(profile.get("weapon_name", UNARMED_NAME)),
		"is_ranged": bool(profile.get("is_ranged", false)),
		"attack_bonus": 0,
		"advantage": false, "disadvantage": false, "reasons": [],
		"cover_bonus": 0, "flanking": false, "distance": 0,
		"auto_fail": false
	}

	# Incapacitated combatants (stunned/paralyzed/frozen) cannot attack at all
	if StatusEffectManager.is_incapacitated(attacker):
		print("CombatManager: %s is incapacitated and cannot attack!" % attacker.name)
		result["auto_fail"] = true
		return result

	var modifiers: Dictionary = get_attack_modifiers(attacker, target, profile, advantage, disadvantage)
	advantage = modifiers.advantage
	disadvantage = modifiers.disadvantage
	var attack_bonus: int = modifiers.attack_bonus
	var target_ac: int = modifiers.target_ac
	if not modifiers.reasons.is_empty():
		print("CombatManager: %s attacks %s - %s" % [attacker.name, target.name, ", ".join(modifiers.reasons)])

	# Roll d20 (with advantage/disadvantage)
	var roll1 = randi_range(1, D20_FACES)
	var roll2 = randi_range(1, D20_FACES) if (advantage or disadvantage) else roll1

	var roll = roll1
	if advantage and not disadvantage:  # Advantage cancels disadvantage
		roll = max(roll1, roll2)
	elif disadvantage and not advantage:
		roll = min(roll1, roll2)

	# Check for crit/fumble
	var is_crit = (roll == CRIT_THRESHOLD)
	var is_fumble = (roll == FUMBLE_THRESHOLD)
	var total = roll + attack_bonus

	# Check if hit
	var hit = false
	if is_crit:
		hit = true
	elif is_fumble:
		hit = false
	else:
		hit = (total >= target_ac)

	# Melee hits on helpless (paralyzed/frozen) targets within 1 tile auto-crit
	if hit and not is_crit and not result.is_ranged and modifiers.distance <= MELEE_REACH:
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
	result["reasons"] = modifiers.reasons
	result["cover_bonus"] = modifiers.cover_bonus
	result["flanking"] = modifiers.flanking
	result["distance"] = modifiers.distance
	return result

func roll_damage(profile: Dictionary, is_crit: bool = false) -> int:
	"""Roll the damage of one hit with an attack profile: its dice (rolled
	twice on a critical hit), any flat damage, the same ability modifier the
	attack roll used and the weapon's magic bonus. Never less than 1."""
	var damage: int = int(profile.get("flat_damage", 0))
	var dice: String = str(profile.get("damage_dice", ""))
	if dice != "":
		damage += roll_dice(dice)
		if is_crit:
			damage += roll_dice(dice)
	damage += int(profile.get("ability_modifier", 0)) + int(profile.get("damage_bonus", 0))
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

func is_damage_type(type_name: String) -> bool:
	"""True for a damage type of the rules ("fire", "poison", "bludgeoning")"""
	return DAMAGE_TYPE_FROM_STRING.has(type_name)

func get_damage_response(target, damage_type: String) -> Dictionary:
	"""What the target's nature does to damage of a type, without dealing any:
	{immune, resistant, vulnerable, response, text}. response is what the damage
	event will say ("immune", "resisted", "vulnerable", or "" when nothing
	changes the amount - also when resistance and vulnerability meet); text is
	the same for the player ("Immune to fire: no damage", "Resists poison: half
	damage", "Vulnerable to bludgeoning: double damage")."""
	var answer: Dictionary = {"immune": false, "resistant": false, "vulnerable": false, "response": "", "text": ""}
	if not is_instance_valid(target) or not (target is Combatant):
		return answer
	answer["immune"] = damage_type in target.get_immunities()
	answer["resistant"] = damage_type in target.get_resistances()
	answer["vulnerable"] = damage_type in target.get_vulnerabilities()
	if answer.immune:
		answer["response"] = RESPONSE_IMMUNE
		answer["text"] = "Immune to %s: no damage" % damage_type
	elif answer.resistant and not answer.vulnerable:
		answer["response"] = RESPONSE_RESISTED
		answer["text"] = "Resists %s: half damage" % damage_type
	elif answer.vulnerable and not answer.resistant:
		answer["response"] = RESPONSE_VULNERABLE
		answer["text"] = "Vulnerable to %s: double damage" % damage_type
	return answer

func deal_damage(source, target, amount: int, damage_type: String = "physical", context: Dictionary = {}) -> Dictionary:
	"""The one way hit points are taken away: a weapon hit, a spell, a status
	effect's tick, a trap. source is the combatant behind it, or null. context
	says what it came from: kind ("weapon", "spell", "effect"; "other" when
	left out), is_critical, and weapon, weapon_instance, spell_id or effect_id.
	Runs the steps described at the top of this file and returns the damage
	event: amount is the hit points lost, response what the target's nature did
	to the damage, killed whether the target died of it. {} when there was no
	target to hurt."""
	if not is_instance_valid(target) or not (target is Combatant) or target.stats == null:
		push_error("CombatManager.deal_damage: no combatant to damage")
		return {}
	var response: Dictionary = get_damage_response(target, damage_type)
	var event: Dictionary = {
		"source": source if is_instance_valid(source) else null,
		"target": target,
		"damage_type": damage_type,
		"amount": maxi(0, amount),
		"rolled": maxi(0, amount),
		"is_critical": bool(context.get("is_critical", false)),
		"kind": str(context.get("kind", KIND_OTHER)),
		"context": context,
		"immune": response.immune,
		"resistant": response.resistant,
		"vulnerable": response.vulnerable,
		"response": response.response,
		"prevented": false,
		"hp_left": 1,
		"prevented_by": "",
		"hp_before": target.stats.current_hp,
		"hp_after": target.stats.current_hp,
		"killed": false,
	}

	# 1. Anyone may add to the damage or take from it
	EventBus.damage_incoming.emit(event)

	# 2. Immunity, resistance, vulnerability
	var final_amount: int = maxi(0, int(event.amount))
	if event.immune:
		final_amount = 0
	else:
		if event.resistant:
			final_amount = int(final_amount / 2.0)
		if event.vulnerable:
			final_amount *= 2

	# 3. A last chance to stay standing
	var hp_before: int = target.stats.current_hp
	if final_amount >= hp_before and hp_before > 0:
		event["amount"] = final_amount
		EventBus.dropping_to_zero.emit(event)
		if event.prevented:
			final_amount = maxi(0, hp_before - clampi(int(event.hp_left), 1, hp_before))

	# 4. The hit points go
	var still_alive: bool = target.stats.take_damage(final_amount)
	event["amount"] = final_amount
	event["hp_before"] = hp_before
	event["hp_after"] = target.stats.current_hp
	event["killed"] = not still_alive
	if event.response != "" or event.prevented:
		print("CombatManager: %s takes %d %s damage (%s)" % [target.name, final_amount, damage_type,
			", ".join([str(event.response), str(event.prevented_by)].filter(func(word): return word != ""))])
	EventBus.damage_applied.emit(event)
	if final_amount > 0:
		EventBus.damage_dealt.emit(event.source, target, final_amount, event.is_critical, damage_type_from_string(damage_type))

	# 5. Death
	if not still_alive:
		handle_death(target)
	return event

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
	with the melee weapon in the reactor's hand, never the ranged weapon it carries;
	a weapon that cannot be swung (two-handed, with a full off hand) gives way to an
	unarmed strike. Emits
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

	var profile: Dictionary = get_melee_profile(reactor)
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

func _has_threat_adjacent(attacker: Combatant) -> bool:
	"""True when a hostile that is not incapacitated stands next to the
	attacker: it spoils a ranged attack"""
	var from: Vector2i = attacker.get_grid_position()
	for hostile in attacker.get_hostiles():
		if CombatGrid.get_distance_tiles(from, hostile.get_grid_position()) <= MELEE_REACH \
				and not StatusEffectManager.is_incapacitated(hostile):
			return true
	return false

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
