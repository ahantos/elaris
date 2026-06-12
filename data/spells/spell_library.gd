# spell_library.gd
# Static registry of every spell definition in the game (pure data, no state).
# SpellDatabase loads this once in _ready(). Owned by A4 (Magic).
# Schema per docs/ARCHITECTURE_CONTRACTS.md section 3:
#   spell_id: String
#   display_name: String
#   level: int 0-9 (0 = cantrip)
#   school: "abjuration"|"conjuration"|"divination"|"enchantment"|"evocation"|
#           "illusion"|"necromancy"|"transmutation"
#   classes: Array[String] ("wizard", "cleric", ...)
#   casting_time: "action"|"bonus_action"|"reaction"
#   range_tiles: int (0 = self)
#   target_type: "enemy"|"ally"|"self"|"point"
#   area_radius_tiles: int (0 = single target, Chebyshev radius otherwise)
#   attack_roll: bool (spell attack vs AC)
#   save: {stat: String, half_on_save: bool} ({} = none; attack_roll=false AND save={}
#         with damage_dice set = auto-hit, e.g. magic_missile)
#   damage_dice: String ("8d6", "1d8+3", "100", "" = none)
#   damage_type: String per contracts 2.4 ("fire", "cold", "force", ...)
#   heal_dice: String ("" = none)
#   applies_effect: {effect_id: String, duration: int} ({} = none; duration 0 = effect default)
#   concentration: bool
#   duration_turns: int
#   description: String
# A4 EXTENSIONS of the contract schema (all optional, additive - documented in the report):
#   attack_count: int        - number of separate spell attack rolls (scorching_ray = 3)
#   teleport: bool           - point-target teleport; cast result carries {teleport_to: Vector2i}
#   counters: bool           - counterspell placeholder; cast result carries {countered: true}
#   removes_effects: Array   - effect ids stripped from the target (lesser_restoration, dispel_magic)
#   clears_all_effects: bool - StatusEffectManager.clear_effects on the target (greater_restoration)
#   revive: bool             - may target a downed (0 HP) character; heal brings them back up
#   drain_half: bool         - caster heals for half the damage dealt (vampiric_touch)
class_name SpellLibrary
extends RefCounted


static func _spell(overrides: Dictionary) -> Dictionary:
	"""Merge a partial definition over the schema defaults so every spell
	dictionary always carries every contract key."""
	var spell: Dictionary = {
		"spell_id": "",
		"display_name": "",
		"level": 0,
		"school": "evocation",
		"classes": [],
		"casting_time": "action",
		"range_tiles": 12,
		"target_type": "enemy",
		"area_radius_tiles": 0,
		"attack_roll": false,
		"save": {},
		"damage_dice": "",
		"damage_type": "",
		"heal_dice": "",
		"applies_effect": {},
		"concentration": false,
		"duration_turns": 0,
		"description": ""
	}
	for key in overrides:
		spell[key] = overrides[key]
	return spell


static func get_definitions() -> Dictionary:
	"""Return {spell_id: definition Dictionary} for all spells (82 total)."""
	var defs: Dictionary = {}
	for spell in _build_all():
		defs[spell["spell_id"]] = spell
	return defs


static func _build_all() -> Array:
	"""All spell definitions, grouped by level."""
	var spells: Array = []
	spells.append_array(_cantrips())
	spells.append_array(_level_1())
	spells.append_array(_level_2())
	spells.append_array(_level_3())
	spells.append_array(_level_4())
	spells.append_array(_level_5())
	spells.append_array(_level_6_plus())
	return spells


# === CANTRIPS (LEVEL 0) ===

static func _cantrips() -> Array:
	return [
		_spell({"spell_id": "fire_bolt", "display_name": "Fire Bolt", "level": 0,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 24,
			"attack_roll": true, "damage_dice": "1d10", "damage_type": "fire",
			"description": "Hurl a mote of fire at a creature within range."}),
		_spell({"spell_id": "ray_of_frost", "display_name": "Ray of Frost", "level": 0,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 12,
			"attack_roll": true, "damage_dice": "1d8", "damage_type": "cold",
			"applies_effect": {"effect_id": "slowed", "duration": 1},
			"description": "A frigid beam of blue-white light chills and slows the target."}),
		_spell({"spell_id": "sacred_flame", "display_name": "Sacred Flame", "level": 0,
			"school": "evocation", "classes": ["cleric"], "range_tiles": 12,
			"save": {"stat": "dex", "half_on_save": false},
			"damage_dice": "1d8", "damage_type": "radiant",
			"description": "Flame-like radiance descends on a creature; DEX save or take radiant damage."}),
		_spell({"spell_id": "eldritch_blast", "display_name": "Eldritch Blast", "level": 0,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 24,
			"attack_roll": true, "damage_dice": "1d10", "damage_type": "force",
			"description": "A beam of crackling otherworldly energy streaks toward the target."}),
		_spell({"spell_id": "mage_hand", "display_name": "Mage Hand", "level": 0,
			"school": "conjuration", "classes": ["wizard"], "range_tiles": 6,
			"target_type": "point", "duration_turns": 10,
			"description": "A spectral floating hand that can manipulate objects at a distance. (Utility - no combat effect yet.)"}),
		_spell({"spell_id": "light", "display_name": "Light", "level": 0,
			"school": "evocation", "classes": ["wizard", "cleric"], "range_tiles": 1,
			"target_type": "ally", "duration_turns": 100,
			"description": "An object glows with bright light. (Utility - no combat effect yet.)"}),
		_spell({"spell_id": "guidance", "display_name": "Guidance", "level": 0,
			"school": "divination", "classes": ["cleric"], "range_tiles": 1,
			"target_type": "ally", "applies_effect": {"effect_id": "blessed", "duration": 3},
			"description": "A touch of divine insight blesses an ally's next efforts."}),
		_spell({"spell_id": "true_strike", "display_name": "True Strike", "level": 0,
			"school": "divination", "classes": ["wizard"], "range_tiles": 0,
			"target_type": "self", "applies_effect": {"effect_id": "blessed", "duration": 1},
			"concentration": true, "duration_turns": 1,
			"description": "A glimpse of the future sharpens your next attack."}),
		_spell({"spell_id": "toll_the_dead", "display_name": "Toll the Dead", "level": 0,
			"school": "necromancy", "classes": ["cleric", "wizard"], "range_tiles": 12,
			"save": {"stat": "wis", "half_on_save": false},
			"damage_dice": "1d8", "damage_type": "necrotic",
			"description": "A dolorous bell tolls for the target; WIS save or take necrotic damage."}),
		_spell({"spell_id": "poison_spray", "display_name": "Poison Spray", "level": 0,
			"school": "conjuration", "classes": ["wizard"], "range_tiles": 2,
			"save": {"stat": "con", "half_on_save": false},
			"damage_dice": "1d12", "damage_type": "poison",
			"description": "A puff of noxious gas; CON save or take poison damage."}),
		_spell({"spell_id": "shocking_grasp", "display_name": "Shocking Grasp", "level": 0,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 1,
			"attack_roll": true, "damage_dice": "1d8", "damage_type": "lightning",
			"applies_effect": {"effect_id": "shocked", "duration": 1},
			"description": "Lightning springs from your hand; the jolt steals the target's reactions."}),
		_spell({"spell_id": "chill_touch", "display_name": "Chill Touch", "level": 0,
			"school": "necromancy", "classes": ["wizard"], "range_tiles": 24,
			"attack_roll": true, "damage_dice": "1d8", "damage_type": "necrotic",
			"applies_effect": {"effect_id": "cursed", "duration": 1},
			"description": "A ghostly skeletal hand clutches the target with grave-chill."}),
		_spell({"spell_id": "minor_illusion", "display_name": "Minor Illusion", "level": 0,
			"school": "illusion", "classes": ["wizard"], "range_tiles": 6,
			"target_type": "point", "duration_turns": 10,
			"description": "Create a sound or image within range. (Utility - no combat effect yet.)"})
	]


# === LEVEL 1 ===

static func _level_1() -> Array:
	return [
		_spell({"spell_id": "magic_missile", "display_name": "Magic Missile", "level": 1,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 24,
			"attack_roll": false, "save": {},
			"damage_dice": "3d4+3", "damage_type": "force",
			"description": "Three darts of glowing force strike unerringly - no attack roll, no save."}),
		_spell({"spell_id": "cure_wounds", "display_name": "Cure Wounds", "level": 1,
			"school": "evocation", "classes": ["cleric"], "range_tiles": 1,
			"target_type": "ally", "heal_dice": "1d8+3",
			"description": "A touch of healing energy closes wounds."}),
		_spell({"spell_id": "healing_word", "display_name": "Healing Word", "level": 1,
			"school": "evocation", "classes": ["cleric"], "casting_time": "bonus_action",
			"range_tiles": 12, "target_type": "ally", "heal_dice": "1d4+2",
			"description": "A word of divine power knits flesh from a distance."}),
		_spell({"spell_id": "bless", "display_name": "Bless", "level": 1,
			"school": "enchantment", "classes": ["cleric"], "range_tiles": 6,
			"target_type": "ally", "applies_effect": {"effect_id": "blessed", "duration": 10},
			"concentration": true, "duration_turns": 10,
			"description": "Divine favor bolsters an ally's attacks and saving throws."}),
		_spell({"spell_id": "shield_spell", "display_name": "Shield", "level": 1,
			"school": "abjuration", "classes": ["wizard"], "casting_time": "reaction",
			"range_tiles": 0, "target_type": "self",
			"applies_effect": {"effect_id": "shielded", "duration": 1}, "duration_turns": 1,
			"description": "An invisible barrier of force springs up around you for one turn."}),
		_spell({"spell_id": "burning_hands", "display_name": "Burning Hands", "level": 1,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 2,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "3d6", "damage_type": "fire",
			"description": "A thin sheet of flame shoots from your outstretched fingertips."}),
		_spell({"spell_id": "thunderwave", "display_name": "Thunderwave", "level": 1,
			"school": "evocation", "classes": ["wizard", "cleric"], "range_tiles": 2,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "con", "half_on_save": true},
			"damage_dice": "2d8", "damage_type": "force",
			"description": "A wave of thunderous force sweeps out from you."}),
		_spell({"spell_id": "sleep", "display_name": "Sleep", "level": 1,
			"school": "enchantment", "classes": ["wizard"], "range_tiles": 18,
			"save": {"stat": "wis", "half_on_save": false},
			"applies_effect": {"effect_id": "stunned", "duration": 2},
			"description": "Magical slumber overtakes the target; WIS save or fall senseless."}),
		_spell({"spell_id": "mage_armor", "display_name": "Mage Armor", "level": 1,
			"school": "abjuration", "classes": ["wizard"], "range_tiles": 1,
			"target_type": "ally", "applies_effect": {"effect_id": "shielded", "duration": 20},
			"duration_turns": 20,
			"description": "A protective magical force surrounds an unarmored ally."}),
		_spell({"spell_id": "guiding_bolt", "display_name": "Guiding Bolt", "level": 1,
			"school": "evocation", "classes": ["cleric"], "range_tiles": 24,
			"attack_roll": true, "damage_dice": "4d6", "damage_type": "radiant",
			"applies_effect": {"effect_id": "cursed", "duration": 1},
			"description": "A flash of light streaks toward the target, marking it with glittering motes."}),
		_spell({"spell_id": "inflict_wounds", "display_name": "Inflict Wounds", "level": 1,
			"school": "necromancy", "classes": ["cleric"], "range_tiles": 1,
			"attack_roll": true, "damage_dice": "3d10", "damage_type": "necrotic",
			"description": "Your touch channels withering negative energy."}),
		_spell({"spell_id": "shield_of_faith", "display_name": "Shield of Faith", "level": 1,
			"school": "abjuration", "classes": ["cleric"], "casting_time": "bonus_action",
			"range_tiles": 12, "target_type": "ally",
			"applies_effect": {"effect_id": "shielded", "duration": 10},
			"concentration": true, "duration_turns": 10,
			"description": "A shimmering field of faith surrounds an ally."}),
		_spell({"spell_id": "detect_magic", "display_name": "Detect Magic", "level": 1,
			"school": "divination", "classes": ["wizard", "cleric"], "range_tiles": 0,
			"target_type": "self", "concentration": true, "duration_turns": 10,
			"description": "You sense the presence of magic nearby. (Utility - no combat effect yet.)"}),
		_spell({"spell_id": "false_life", "display_name": "False Life", "level": 1,
			"school": "necromancy", "classes": ["wizard"], "range_tiles": 0,
			"target_type": "self", "heal_dice": "1d4+4",
			"description": "Bolster yourself with a necromantic facsimile of life."}),
		_spell({"spell_id": "ray_of_sickness", "display_name": "Ray of Sickness", "level": 1,
			"school": "necromancy", "classes": ["wizard"], "range_tiles": 12,
			"attack_roll": true, "damage_dice": "2d8", "damage_type": "poison",
			"applies_effect": {"effect_id": "poisoned", "duration": 2},
			"description": "A sickly green ray poisons whatever it touches."})
	]


# === LEVEL 2 ===

static func _level_2() -> Array:
	return [
		_spell({"spell_id": "misty_step", "display_name": "Misty Step", "level": 2,
			"school": "conjuration", "classes": ["wizard"], "casting_time": "bonus_action",
			"range_tiles": 6, "target_type": "point", "teleport": true,
			"description": "Briefly surrounded by silvery mist, you teleport to a visible spot within range."}),
		_spell({"spell_id": "hold_person", "display_name": "Hold Person", "level": 2,
			"school": "enchantment", "classes": ["wizard", "cleric"], "range_tiles": 12,
			"save": {"stat": "wis", "half_on_save": false},
			"applies_effect": {"effect_id": "paralyzed", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "The target must succeed on a WIS save or be paralyzed."}),
		_spell({"spell_id": "scorching_ray", "display_name": "Scorching Ray", "level": 2,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 24,
			"attack_roll": true, "attack_count": 3,
			"damage_dice": "2d6", "damage_type": "fire",
			"description": "Three rays of fire, each rolled as a separate spell attack."}),
		_spell({"spell_id": "spiritual_weapon", "display_name": "Spiritual Weapon", "level": 2,
			"school": "evocation", "classes": ["cleric"], "casting_time": "bonus_action",
			"range_tiles": 12, "attack_roll": true,
			"damage_dice": "1d8+3", "damage_type": "force",
			"description": "A floating spectral weapon strikes at your command."}),
		_spell({"spell_id": "aid", "display_name": "Aid", "level": 2,
			"school": "abjuration", "classes": ["cleric"], "range_tiles": 6,
			"target_type": "ally", "heal_dice": "10",
			"description": "Your spell bolsters an ally with vigor and resolve."}),
		_spell({"spell_id": "lesser_restoration", "display_name": "Lesser Restoration", "level": 2,
			"school": "abjuration", "classes": ["cleric"], "range_tiles": 1,
			"target_type": "ally",
			"removes_effects": ["poisoned", "blinded", "paralyzed", "frightened"],
			"description": "A touch of healing magic cures poison, blindness, paralysis or fear."}),
		_spell({"spell_id": "invisibility", "display_name": "Invisibility", "level": 2,
			"school": "illusion", "classes": ["wizard"], "range_tiles": 1,
			"target_type": "ally", "applies_effect": {"effect_id": "invisible", "duration": 10},
			"concentration": true, "duration_turns": 10,
			"description": "The target vanishes from sight until the spell ends or it attacks."}),
		_spell({"spell_id": "blur", "display_name": "Blur", "level": 2,
			"school": "illusion", "classes": ["wizard"], "range_tiles": 0,
			"target_type": "self", "applies_effect": {"effect_id": "shielded", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "Your body becomes blurred and hard to strike."}),
		_spell({"spell_id": "flaming_sphere", "display_name": "Flaming Sphere", "level": 2,
			"school": "conjuration", "classes": ["wizard"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 1,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "2d6", "damage_type": "fire",
			"concentration": true, "duration_turns": 10,
			"description": "A rolling sphere of fire sears everything beside it."}),
		_spell({"spell_id": "web", "display_name": "Web", "level": 2,
			"school": "conjuration", "classes": ["wizard"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "dex", "half_on_save": false},
			"applies_effect": {"effect_id": "restrained", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "Thick, sticky webbing fills the area, restraining those caught in it."}),
		_spell({"spell_id": "shatter", "display_name": "Shatter", "level": 2,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "con", "half_on_save": true},
			"damage_dice": "3d8", "damage_type": "force",
			"description": "A sudden ringing noise painfully loud bursts in the area."}),
		_spell({"spell_id": "darkness", "display_name": "Darkness", "level": 2,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 3,
			"applies_effect": {"effect_id": "blinded", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "Magical darkness spreads, blinding those within."}),
		_spell({"spell_id": "prayer_of_healing", "display_name": "Prayer of Healing", "level": 2,
			"school": "evocation", "classes": ["cleric"], "range_tiles": 6,
			"target_type": "ally", "heal_dice": "2d8+3",
			"description": "A murmured prayer mends an ally's wounds."}),
		_spell({"spell_id": "blindness_deafness", "display_name": "Blindness/Deafness", "level": 2,
			"school": "necromancy", "classes": ["wizard", "cleric"], "range_tiles": 6,
			"save": {"stat": "con", "half_on_save": false},
			"applies_effect": {"effect_id": "blinded", "duration": 3},
			"description": "You curse the target's senses; CON save or be blinded."}),
		_spell({"spell_id": "locate_object", "display_name": "Locate Object", "level": 2,
			"school": "divination", "classes": ["wizard", "cleric"], "range_tiles": 0,
			"target_type": "self", "concentration": true, "duration_turns": 10,
			"description": "Sense the direction to a known object. (Utility - no combat effect yet.)"})
	]


# === LEVEL 3 ===

static func _level_3() -> Array:
	return [
		_spell({"spell_id": "fireball", "display_name": "Fireball", "level": 3,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 30,
			"target_type": "point", "area_radius_tiles": 4,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "8d6", "damage_type": "fire",
			"description": "A bright streak blossoms into a roaring explosion of flame."}),
		_spell({"spell_id": "lightning_bolt", "display_name": "Lightning Bolt", "level": 3,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 20,
			"target_type": "point", "area_radius_tiles": 1,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "8d6", "damage_type": "lightning",
			"description": "A stroke of lightning blasts out in a line. (Line shape approximated as a small area until integration.)"}),
		_spell({"spell_id": "haste", "display_name": "Haste", "level": 3,
			"school": "transmutation", "classes": ["wizard"], "range_tiles": 6,
			"target_type": "ally", "applies_effect": {"effect_id": "hasted", "duration": 10},
			"concentration": true, "duration_turns": 10,
			"description": "The target moves with supernatural speed and reflexes."}),
		_spell({"spell_id": "slow", "display_name": "Slow", "level": 3,
			"school": "transmutation", "classes": ["wizard"], "range_tiles": 24,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "wis", "half_on_save": false},
			"applies_effect": {"effect_id": "slowed", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "Time crawls for creatures caught in the area; WIS save resists."}),
		_spell({"spell_id": "counterspell", "display_name": "Counterspell", "level": 3,
			"school": "abjuration", "classes": ["wizard"], "casting_time": "reaction",
			"range_tiles": 12, "counters": true,
			"description": "You interrupt a creature mid-incantation. (Placeholder - the reaction trigger is wired during integration.)"}),
		_spell({"spell_id": "revivify", "display_name": "Revivify", "level": 3,
			"school": "necromancy", "classes": ["cleric"], "range_tiles": 1,
			"target_type": "ally", "revive": true, "heal_dice": "1",
			"description": "A creature that died within the last minute returns to life with 1 hit point."}),
		_spell({"spell_id": "spirit_guardians", "display_name": "Spirit Guardians", "level": 3,
			"school": "conjuration", "classes": ["cleric"], "range_tiles": 3,
			"target_type": "point", "area_radius_tiles": 3,
			"save": {"stat": "wis", "half_on_save": true},
			"damage_dice": "3d8", "damage_type": "radiant",
			"concentration": true, "duration_turns": 10,
			"description": "Protective spirits flit around you, savaging nearby enemies."}),
		_spell({"spell_id": "mass_healing_word", "display_name": "Mass Healing Word", "level": 3,
			"school": "evocation", "classes": ["cleric"], "casting_time": "bonus_action",
			"range_tiles": 12, "target_type": "ally", "heal_dice": "1d4+3",
			"description": "A word of restoration mends wounds at a distance."}),
		_spell({"spell_id": "dispel_magic", "display_name": "Dispel Magic", "level": 3,
			"school": "abjuration", "classes": ["wizard", "cleric"], "range_tiles": 12,
			"removes_effects": ["blessed", "hasted", "shielded", "invisible", "regenerating"],
			"description": "Magical effects on the target unravel and end."}),
		_spell({"spell_id": "fear", "display_name": "Fear", "level": 3,
			"school": "illusion", "classes": ["wizard"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "wis", "half_on_save": false},
			"applies_effect": {"effect_id": "frightened", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "A phantasmal image of each creature's worst fears takes shape."}),
		_spell({"spell_id": "vampiric_touch", "display_name": "Vampiric Touch", "level": 3,
			"school": "necromancy", "classes": ["wizard"], "range_tiles": 1,
			"attack_roll": true, "damage_dice": "3d6", "damage_type": "necrotic",
			"drain_half": true, "concentration": true, "duration_turns": 10,
			"description": "Your shadow-wreathed touch siphons life; you heal half the damage dealt."}),
		_spell({"spell_id": "bestow_curse", "display_name": "Bestow Curse", "level": 3,
			"school": "necromancy", "classes": ["wizard"], "range_tiles": 1,
			"save": {"stat": "wis", "half_on_save": false},
			"applies_effect": {"effect_id": "cursed", "duration": 5},
			"concentration": true, "duration_turns": 5,
			"description": "Your touch lays a withering curse; WIS save resists."}),
		_spell({"spell_id": "protection_from_energy", "display_name": "Protection from Energy", "level": 3,
			"school": "abjuration", "classes": ["wizard", "cleric"], "range_tiles": 1,
			"target_type": "ally", "applies_effect": {"effect_id": "shielded", "duration": 10},
			"concentration": true, "duration_turns": 10,
			"description": "A ward of shimmering force blunts incoming harm."})
	]


# === LEVEL 4 ===

static func _level_4() -> Array:
	return [
		_spell({"spell_id": "ice_storm", "display_name": "Ice Storm", "level": 4,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 30,
			"target_type": "point", "area_radius_tiles": 3,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "4d6+8", "damage_type": "cold",
			"applies_effect": {"effect_id": "slowed", "duration": 1},
			"description": "Hail the size of fists hammers the area, chilling and battering."}),
		_spell({"spell_id": "greater_invisibility", "display_name": "Greater Invisibility", "level": 4,
			"school": "illusion", "classes": ["wizard"], "range_tiles": 1,
			"target_type": "ally", "applies_effect": {"effect_id": "invisible", "duration": 10},
			"concentration": true, "duration_turns": 10,
			"description": "The target vanishes completely, even while attacking."}),
		_spell({"spell_id": "blight", "display_name": "Blight", "level": 4,
			"school": "necromancy", "classes": ["wizard"], "range_tiles": 6,
			"save": {"stat": "con", "half_on_save": true},
			"damage_dice": "8d8", "damage_type": "necrotic",
			"description": "Necromantic energy drains moisture and vitality from the target."}),
		_spell({"spell_id": "banishment", "display_name": "Banishment", "level": 4,
			"school": "abjuration", "classes": ["wizard", "cleric"], "range_tiles": 12,
			"save": {"stat": "cha", "half_on_save": false},
			"applies_effect": {"effect_id": "stunned", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "The target is hurled into a harmless demiplane. (Approximated as a stun.)"}),
		_spell({"spell_id": "wall_of_fire", "display_name": "Wall of Fire", "level": 4,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 24,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "5d8", "damage_type": "fire",
			"applies_effect": {"effect_id": "burning", "duration": 2},
			"concentration": true, "duration_turns": 10,
			"description": "A roaring curtain of flame sets the area ablaze."}),
		_spell({"spell_id": "polymorph", "display_name": "Polymorph", "level": 4,
			"school": "transmutation", "classes": ["wizard"], "range_tiles": 12,
			"save": {"stat": "wis", "half_on_save": false},
			"applies_effect": {"effect_id": "stunned", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "The target is transformed into a harmless beast. (Approximated as a stun.)"}),
		_spell({"spell_id": "death_ward", "display_name": "Death Ward", "level": 4,
			"school": "abjuration", "classes": ["cleric"], "range_tiles": 1,
			"target_type": "ally", "applies_effect": {"effect_id": "regenerating", "duration": 10},
			"duration_turns": 10,
			"description": "Divine protection knits the target's wounds as they fight on."}),
		_spell({"spell_id": "stoneskin", "display_name": "Stoneskin", "level": 4,
			"school": "abjuration", "classes": ["wizard"], "range_tiles": 1,
			"target_type": "ally", "applies_effect": {"effect_id": "shielded", "duration": 10},
			"concentration": true, "duration_turns": 10,
			"description": "The target's flesh hardens like stone against blows."})
	]


# === LEVEL 5 ===

static func _level_5() -> Array:
	return [
		_spell({"spell_id": "cone_of_cold", "display_name": "Cone of Cold", "level": 5,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 3,
			"save": {"stat": "con", "half_on_save": true},
			"damage_dice": "8d8", "damage_type": "cold",
			"applies_effect": {"effect_id": "frozen", "duration": 1},
			"description": "A blast of killing frost erupts from your hands."}),
		_spell({"spell_id": "hold_monster", "display_name": "Hold Monster", "level": 5,
			"school": "enchantment", "classes": ["wizard"], "range_tiles": 18,
			"save": {"stat": "wis", "half_on_save": false},
			"applies_effect": {"effect_id": "paralyzed", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "Any creature must succeed on a WIS save or be paralyzed."}),
		_spell({"spell_id": "greater_restoration", "display_name": "Greater Restoration", "level": 5,
			"school": "abjuration", "classes": ["cleric"], "range_tiles": 1,
			"target_type": "ally", "clears_all_effects": true,
			"description": "Potent restorative magic strips away every affliction on the target."}),
		_spell({"spell_id": "flame_strike", "display_name": "Flame Strike", "level": 5,
			"school": "evocation", "classes": ["cleric"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "8d6", "damage_type": "radiant",
			"description": "A column of divine fire roars down from above."}),
		_spell({"spell_id": "mass_cure_wounds", "display_name": "Mass Cure Wounds", "level": 5,
			"school": "evocation", "classes": ["cleric"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 3, "heal_dice": "3d8+3",
			"description": "A wave of healing washes over creatures in the area. (Pass allies via affected_override during integration.)"}),
		_spell({"spell_id": "raise_dead", "display_name": "Raise Dead", "level": 5,
			"school": "necromancy", "classes": ["cleric"], "range_tiles": 1,
			"target_type": "ally", "revive": true, "heal_dice": "10",
			"description": "Return a dead creature to life with a measure of vigor."}),
		_spell({"spell_id": "telekinesis", "display_name": "Telekinesis", "level": 5,
			"school": "transmutation", "classes": ["wizard"], "range_tiles": 12,
			"save": {"stat": "str", "half_on_save": false},
			"applies_effect": {"effect_id": "restrained", "duration": 3},
			"concentration": true, "duration_turns": 3,
			"description": "An invisible grip seizes the target; STR save or be held fast."}),
		_spell({"spell_id": "insect_plague", "display_name": "Insect Plague", "level": 5,
			"school": "conjuration", "classes": ["cleric"], "range_tiles": 24,
			"target_type": "point", "area_radius_tiles": 3,
			"save": {"stat": "con", "half_on_save": true},
			"damage_dice": "4d10", "damage_type": "piercing",
			"concentration": true, "duration_turns": 10,
			"description": "A swirling cloud of biting locusts fills the area."})
	]


# === LEVELS 6-9 ===

static func _level_6_plus() -> Array:
	return [
		_spell({"spell_id": "chain_lightning", "display_name": "Chain Lightning", "level": 6,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 30,
			"target_type": "point", "area_radius_tiles": 2,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "10d8", "damage_type": "lightning",
			"description": "A bolt of lightning arcs from target to target."}),
		_spell({"spell_id": "heal", "display_name": "Heal", "level": 6,
			"school": "evocation", "classes": ["cleric"], "range_tiles": 12,
			"target_type": "ally", "heal_dice": "70",
			"description": "A flood of positive energy restores 70 hit points."}),
		_spell({"spell_id": "disintegrate", "display_name": "Disintegrate", "level": 6,
			"school": "transmutation", "classes": ["wizard"], "range_tiles": 12,
			"save": {"stat": "dex", "half_on_save": false},
			"damage_dice": "10d6+40", "damage_type": "force",
			"description": "A thin green ray reduces what it strikes to dust; DEX save negates."}),
		_spell({"spell_id": "finger_of_death", "display_name": "Finger of Death", "level": 7,
			"school": "necromancy", "classes": ["wizard"], "range_tiles": 12,
			"save": {"stat": "con", "half_on_save": true},
			"damage_dice": "7d8+30", "damage_type": "necrotic",
			"description": "Searing negative energy rips at the target's life force."}),
		_spell({"spell_id": "resurrection", "display_name": "Resurrection", "level": 7,
			"school": "necromancy", "classes": ["cleric"], "range_tiles": 1,
			"target_type": "ally", "revive": true, "heal_dice": "100",
			"description": "Restore a dead creature to life with most of its strength."}),
		_spell({"spell_id": "holy_aura", "display_name": "Holy Aura", "level": 8,
			"school": "abjuration", "classes": ["cleric"], "range_tiles": 6,
			"target_type": "ally", "applies_effect": {"effect_id": "blessed", "duration": 10},
			"concentration": true, "duration_turns": 10,
			"description": "Divine radiance wreathes an ally in holy protection."}),
		_spell({"spell_id": "meteor_swarm", "display_name": "Meteor Swarm", "level": 9,
			"school": "evocation", "classes": ["wizard"], "range_tiles": 40,
			"target_type": "point", "area_radius_tiles": 6,
			"save": {"stat": "dex", "half_on_save": true},
			"damage_dice": "20d6", "damage_type": "fire",
			"description": "Blazing orbs of rock plummet to the ground in a cataclysm of fire."}),
		_spell({"spell_id": "mass_heal", "display_name": "Mass Heal", "level": 9,
			"school": "evocation", "classes": ["cleric"], "range_tiles": 12,
			"target_type": "point", "area_radius_tiles": 6, "heal_dice": "70",
			"description": "A torrent of healing energy mends every ally in the area. (Pass allies via affected_override during integration.)"}),
		_spell({"spell_id": "power_word_kill", "display_name": "Power Word Kill", "level": 9,
			"school": "enchantment", "classes": ["wizard"], "range_tiles": 12,
			"damage_dice": "100", "damage_type": "necrotic",
			"description": "A single word of power snuffs out the target's life - no attack roll, no save."}),
		_spell({"spell_id": "time_stop", "display_name": "Time Stop", "level": 9,
			"school": "transmutation", "classes": ["wizard"], "range_tiles": 0,
			"target_type": "self", "applies_effect": {"effect_id": "hasted", "duration": 3},
			"duration_turns": 3,
			"description": "Time stutters around you while you act freely. (Approximated as haste.)"})
	]
