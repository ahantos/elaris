# race_data.gd
# Resource defining a character race (Human, Elf, Dwarf, Halfling, etc.)
extends Resource
class_name RaceData

# Race identity
@export var race_id: String = ""  # Unique ID: "human", "elf", "dwarf", "halfling", "half_orc"
@export var display_name: String = ""  # Display name: "Human", "Elf", "Dwarf"
@export var description: String = ""
@export var icon: Texture2D  # Race icon (48x48)

# Physical properties
@export_group("Physical Properties")
enum Size {
	TINY,
	SMALL,
	MEDIUM,
	LARGE,
	HUGE,
	GARGANTUAN
}
@export var size: Size = Size.MEDIUM
@export var base_speed: int = 30  # Movement speed in feet (30 for most, 25 for dwarf/halfling)
@export var height_min: int = 60  # Height in inches (min)
@export var height_max: int = 72  # Height in inches (max)
@export var weight_min: int = 120  # Weight in pounds (min)
@export var weight_max: int = 180  # Weight in pounds (max)

# Ability score bonuses
@export_group("Ability Score Increases")
@export var str_bonus: int = 0
@export var dex_bonus: int = 0
@export var con_bonus: int = 0
@export var int_bonus: int = 0
@export var wis_bonus: int = 0
@export var cha_bonus: int = 0

# Racial traits
@export_group("Racial Traits")
@export var racial_traits: Array[String] = []  # ["darkvision", "fey_ancestry", "trance"]
@export var languages: Array[String] = ["Common"]  # Languages known
@export var extra_language_count: int = 0  # Number of additional languages player can choose

# Vision
@export var darkvision_range: int = 0  # 0 = none, 60 = normal darkvision, 120 = superior
@export var has_sunlight_sensitivity: bool = false

# Proficiencies (from race)
@export_group("Proficiencies")
@export var weapon_proficiencies: Array[String] = []  # e.g., ["longsword", "shortsword"] for Elves
@export var armor_proficiencies: Array[String] = []
@export var skill_proficiencies: Array[String] = []  # e.g., ["perception"] for Elves
@export var tool_proficiencies: Array[String] = []  # e.g., ["smith_tools"] for Dwarves

# Special abilities
@export_group("Special Abilities")
@export var special_abilities: Array[String] = []  # Descriptions of special abilities
@export var resistance_types: Array[String] = []  # ["poison"] for Dwarves, ["charm", "sleep"] for Elves
@export var advantage_types: Array[String] = []  # ["poison_saves"] for Dwarves

# Subraces (for future expansion)
@export_group("Subraces")
@export var has_subraces: bool = false
@export var subrace_options: Array[String] = []  # ["high_elf", "wood_elf", "dark_elf"]

# Lore and flavor
@export_group("Lore")
@export var typical_alignment: String = "Any"  # "Lawful Good", "Chaotic Neutral", etc.
@export var typical_age_range: String = "Adult: 18-80"
@export var cultural_background: String = ""

# === HELPER FUNCTIONS ===

func get_total_ability_bonuses() -> int:
	"""Get total ability score increase points"""
	return str_bonus + dex_bonus + con_bonus + int_bonus + wis_bonus + cha_bonus

func get_ability_bonuses_dict() -> Dictionary:
	"""Get ability bonuses as a dictionary"""
	return {
		"str": str_bonus,
		"dex": dex_bonus,
		"con": con_bonus,
		"int": int_bonus,
		"wis": wis_bonus,
		"cha": cha_bonus
	}

func apply_to_character_stats(stats: CharacterStats):
	"""Apply racial bonuses to a CharacterStats instance"""
	if str_bonus > 0:
		stats.strength += str_bonus
	if dex_bonus > 0:
		stats.dexterity += dex_bonus
	if con_bonus > 0:
		stats.constitution += con_bonus
	if int_bonus > 0:
		stats.intelligence += int_bonus
	if wis_bonus > 0:
		stats.wisdom += wis_bonus
	if cha_bonus > 0:
		stats.charisma += cha_bonus
	
	# Apply speed
	stats.movement_speed = base_speed
	
	# Recalculate derived stats
	stats.recalculate_derived_stats()

func get_size_name() -> String:
	"""Get human-readable size category"""
	match size:
		Size.TINY: return "Tiny"
		Size.SMALL: return "Small"
		Size.MEDIUM: return "Medium"
		Size.LARGE: return "Large"
		Size.HUGE: return "Huge"
		Size.GARGANTUAN: return "Gargantuan"
	return "Unknown"

func has_darkvision() -> bool:
	"""Check if race has darkvision"""
	return darkvision_range > 0

func has_trait(trait_name: String) -> bool:
	"""Check if race has a specific trait"""
	return racial_traits.has(trait_name)

func has_resistance(damage_type: String) -> bool:
	"""Check if race has resistance to a damage type"""
	return resistance_types.has(damage_type)

func has_advantage(check_type: String) -> bool:
	"""Check if race has advantage on specific checks"""
	return advantage_types.has(check_type)

func get_speed_in_tiles(tile_size: int = 5) -> int:
	"""Convert speed to grid tiles (D&D uses 5ft tiles)"""
	return base_speed / tile_size

func get_tooltip_text() -> String:
	"""Generate tooltip/description text"""
	var tooltip = "[b]" + display_name + "[/b]\n"
	tooltip += description + "\n\n"
	
	# Ability bonuses
	var bonuses = []
	if str_bonus > 0: bonuses.append("STR +" + str(str_bonus))
	if dex_bonus > 0: bonuses.append("DEX +" + str(dex_bonus))
	if con_bonus > 0: bonuses.append("CON +" + str(con_bonus))
	if int_bonus > 0: bonuses.append("INT +" + str(int_bonus))
	if wis_bonus > 0: bonuses.append("WIS +" + str(wis_bonus))
	if cha_bonus > 0: bonuses.append("CHA +" + str(cha_bonus))
	
	if not bonuses.is_empty():
		var bonus_str = ""
		for bonus in bonuses:
			if bonus_str != "":
				bonus_str += ", "
			bonus_str += bonus
		tooltip += "[b]Ability Score Increase:[/b] " + bonus_str + "\n"
	
	tooltip += "[b]Size:[/b] " + get_size_name() + "\n"
	tooltip += "[b]Speed:[/b] " + str(base_speed) + " ft.\n"
	
	if has_darkvision():
		tooltip += "[b]Darkvision:[/b] " + str(darkvision_range) + " ft.\n"
	
	if not languages.is_empty():
		var lang_str = ""
		for lang in languages:
			if lang_str != "":
				lang_str += ", "
			lang_str += lang
		tooltip += "[b]Languages:[/b] " + lang_str + "\n"
	
	return tooltip
