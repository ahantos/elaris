# status_effect_library.gd
# Static registry of every status effect definition in the game (pure data, no state).
# StatusEffectManager loads this once in _ready(). Owned by A3 (Combat Expansion).
# Schema per docs/ARCHITECTURE_CONTRACTS.md section 3:
#   effect_id: String
#   display_name: String
#   kind: "buff" | "debuff"
#   tick: {timing: "turn_start"|"turn_end", damage_dice, damage_type, heal_dice} (optional)
#   modifiers: {ac: int, speed_tiles: int, attack_bonus: int, save_bonus: int,
#               attack_advantage: bool, attack_disadvantage: bool,
#               grants_advantage_to_attackers: bool, grants_disadvantage_to_attackers: bool,
#               incapacitated: bool, no_reactions: bool} (all optional)
#   save_to_end: {stat: String, dc: int} (optional - end-of-turn save shakes the effect off)
#   persists_through_rest: bool (optional - survives a long rest; default false)
#   default_duration: int (turns; -1 = until removed / long rest)
#   description: String
# NOTE: attack_bonus / save_bonus and grants_disadvantage_to_attackers are A3 extensions of
# the contract schema (all modifier keys are optional, so additive keys are safe).
class_name StatusEffectLibrary
extends RefCounted


static func get_definitions() -> Dictionary:
	"""Return {effect_id: definition Dictionary} for all status effects."""
	var defs: Dictionary = {}

	defs["poisoned"] = {
		"effect_id": "poisoned",
		"display_name": "Poisoned",
		"kind": "debuff",
		"tick": {"timing": "turn_start", "damage_dice": "1d4", "damage_type": "poison"},
		"modifiers": {"attack_disadvantage": true},
		"save_to_end": {"stat": "con", "dc": 12},
		"default_duration": 3,
		"description": "Venom courses through the veins: 1d4 poison damage at the start of each turn and disadvantage on attack rolls. CON save DC 12 at end of turn ends it."
	}

	defs["stunned"] = {
		"effect_id": "stunned",
		"display_name": "Stunned",
		"kind": "debuff",
		"modifiers": {"incapacitated": true, "no_reactions": true, "grants_advantage_to_attackers": true},
		"save_to_end": {"stat": "con", "dc": 12},
		"default_duration": 1,
		"description": "Reeling and unable to act. Attacks against a stunned creature have advantage. CON save DC 12 at end of turn ends it."
	}

	defs["prone"] = {
		"effect_id": "prone",
		"display_name": "Prone",
		"kind": "debuff",
		"modifiers": {"attack_disadvantage": true, "grants_advantage_to_attackers": true},
		"default_duration": 1,
		"description": "Knocked to the ground: disadvantage on own attacks, attackers gain advantage. The creature stands back up at the end of its turn (duration 1)."
	}

	defs["frightened"] = {
		"effect_id": "frightened",
		"display_name": "Frightened",
		"kind": "debuff",
		"modifiers": {"attack_disadvantage": true},
		"save_to_end": {"stat": "wis", "dc": 12},
		"default_duration": 3,
		"description": "Gripped by fear: disadvantage on attack rolls. WIS save DC 12 at end of turn ends it."
	}

	defs["blinded"] = {
		"effect_id": "blinded",
		"display_name": "Blinded",
		"kind": "debuff",
		"modifiers": {"attack_disadvantage": true, "grants_advantage_to_attackers": true},
		"save_to_end": {"stat": "con", "dc": 12},
		"default_duration": 2,
		"description": "Cannot see: disadvantage on own attacks, attackers gain advantage. CON save DC 12 at end of turn ends it."
	}

	defs["restrained"] = {
		"effect_id": "restrained",
		"display_name": "Restrained",
		"kind": "debuff",
		"modifiers": {"speed_tiles": -99, "attack_disadvantage": true, "grants_advantage_to_attackers": true},
		"save_to_end": {"stat": "str", "dc": 12},
		"default_duration": 3,
		"description": "Bound in place: speed becomes 0, disadvantage on own attacks, attackers gain advantage. STR save DC 12 at end of turn breaks free."
	}

	defs["paralyzed"] = {
		"effect_id": "paralyzed",
		"display_name": "Paralyzed",
		"kind": "debuff",
		"modifiers": {"incapacitated": true, "no_reactions": true, "grants_advantage_to_attackers": true, "speed_tiles": -99},
		"save_to_end": {"stat": "con", "dc": 14},
		"default_duration": 2,
		"description": "Rigid and helpless: cannot act or move, attackers gain advantage, and melee hits from adjacent attackers are automatic criticals. CON save DC 14 at end of turn ends it."
	}

	defs["slowed"] = {
		"effect_id": "slowed",
		"display_name": "Slowed",
		"kind": "debuff",
		"modifiers": {"speed_tiles": -2, "ac": -2},
		"save_to_end": {"stat": "wis", "dc": 12},
		"default_duration": 3,
		"description": "Time drags: -2 tiles of movement and -2 AC. WIS save DC 12 at end of turn ends it."
	}

	defs["hasted"] = {
		"effect_id": "hasted",
		"display_name": "Hasted",
		"kind": "buff",
		"modifiers": {"speed_tiles": 2, "ac": 2},
		"default_duration": 5,
		"description": "Magically quickened: +2 tiles of movement and +2 AC."
	}

	defs["blessed"] = {
		"effect_id": "blessed",
		"display_name": "Blessed",
		"kind": "buff",
		"modifiers": {"attack_bonus": 2, "save_bonus": 2},
		"default_duration": 5,
		"description": "Divine favor: +2 to attack rolls and +2 to saving throws."
	}

	defs["cursed"] = {
		"effect_id": "cursed",
		"display_name": "Cursed",
		"kind": "debuff",
		"modifiers": {"attack_bonus": -2, "save_bonus": -2},
		"persists_through_rest": true,
		"default_duration": -1,
		"description": "A lingering hex: -2 to attack rolls and -2 to saving throws. Persists until removed (survives long rests - needs remove curse or similar)."
	}

	defs["burning"] = {
		"effect_id": "burning",
		"display_name": "Burning",
		"kind": "debuff",
		"tick": {"timing": "turn_start", "damage_dice": "1d6", "damage_type": "fire"},
		"save_to_end": {"stat": "dex", "dc": 12},
		"default_duration": 3,
		"description": "On fire: 1d6 fire damage at the start of each turn. DEX save DC 12 at end of turn pats the flames out."
	}

	defs["frozen"] = {
		"effect_id": "frozen",
		"display_name": "Frozen",
		"kind": "debuff",
		"modifiers": {"incapacitated": true, "no_reactions": true, "grants_advantage_to_attackers": true, "speed_tiles": -99},
		"save_to_end": {"stat": "str", "dc": 12},
		"default_duration": 2,
		"description": "Encased in ice: cannot act or move, attackers gain advantage, and melee hits from adjacent attackers are automatic criticals. STR save DC 12 at end of turn shatters the ice."
	}

	defs["shocked"] = {
		"effect_id": "shocked",
		"display_name": "Shocked",
		"kind": "debuff",
		"modifiers": {"no_reactions": true},
		"save_to_end": {"stat": "con", "dc": 10},
		"default_duration": 2,
		"description": "Nerves jangled by lightning: cannot take reactions. CON save DC 10 at end of turn ends it."
	}

	defs["regenerating"] = {
		"effect_id": "regenerating",
		"display_name": "Regenerating",
		"kind": "buff",
		"tick": {"timing": "turn_start", "heal_dice": "1d6"},
		"default_duration": 5,
		"description": "Wounds knit closed: regain 1d6 HP at the start of each turn."
	}

	defs["invisible"] = {
		"effect_id": "invisible",
		"display_name": "Invisible",
		"kind": "buff",
		"modifiers": {"attack_advantage": true, "grants_disadvantage_to_attackers": true},
		"default_duration": 3,
		"description": "Unseen: advantage on own attacks, attackers have disadvantage."
	}

	defs["shielded"] = {
		"effect_id": "shielded",
		"display_name": "Shielded",
		"kind": "buff",
		"modifiers": {"ac": 5},
		"default_duration": 1,
		"description": "A shimmering barrier of force: +5 AC until the end of the next turn."
	}

	return defs
