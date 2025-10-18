# class_data.gd
# Resource defining a character class (Fighter, Wizard, Rogue, Cleric, etc.)
extends Resource
class_name ClassData

# Class identity
@export var class_id: String = ""  # Unique ID: "fighter", "wizard", "rogue", "cleric"
@export var display_name: String = ""  # Display name: "Fighter", "Wizard"
@export var description: String = ""
@export var icon: Texture2D  # Class icon (48x48)

# Hit points
@export var hit_die: String = "1d10"  # Hit die type: "1d6", "1d8", "1d10", "1d12"
@export var hp_per_level: int = 6  # Average HP gain per level (used for quick calc)

# Proficiencies
@export_group("Proficiencies")
@export var armor_proficiencies: Array[String] = []  # ["light", "medium", "heavy", "shields"]
@export var weapon_proficiencies: Array[String] = []  # ["simple", "martial", "longsword", "bow"]
@export var saving_throw_proficiencies: Array[String] = []  # ["str", "con"] for Fighter
@export var skill_proficiency_count: int = 2  # Number of skill proficiencies at level 1
@export var skill_proficiency_choices: Array[String] = []  # Available skills to choose from

# Primary ability scores (for quick reference)
@export var primary_abilities: Array[String] = []  # ["str", "con"] for Fighter, ["int"] for Wizard

# Starting equipment
@export_group("Starting Equipment")
@export var starting_gold: int = 0  # Starting gold (alternative to equipment package)
@export var starting_equipment_list: Array[String] = []  # List of item IDs

# Class features by level
@export_group("Class Features")
@export var level_1_features: Array[String] = []  # Feature names/IDs
@export var level_2_features: Array[String] = []
@export var level_3_features: Array[String] = []
# ... Continue for all 40 levels as needed

# Spellcasting (if applicable)
@export_group("Spellcasting")
@export var is_spellcaster: bool = false
@export var spellcasting_ability: String = ""  # "int" for Wizard, "wis" for Cleric
@export var cantrips_known: Array[int] = []  # Cantrips known at each level [0, 3, 3, 4, ...]
@export var spell_slots_level_1: Array[int] = []  # Spell slots by character level
@export var spell_slots_level_2: Array[int] = []
@export var spell_slots_level_3: Array[int] = []
@export var spell_slots_level_4: Array[int] = []
@export var spell_slots_level_5: Array[int] = []
@export var spell_slots_level_6: Array[int] = []
@export var spell_slots_level_7: Array[int] = []
@export var spell_slots_level_8: Array[int] = []
@export var spell_slots_level_9: Array[int] = []

# Subclass options (for future expansion)
@export_group("Subclass")
@export var subclass_name: String = ""  # "Archetype", "School", "Domain", etc.
@export var subclass_level: int = 3  # Level when subclass is chosen
@export var available_subclasses: Array[String] = []  # List of subclass IDs

# === HELPER FUNCTIONS ===

func get_hit_die_average() -> int:
	"""Get average value of hit die"""
	match hit_die:
		"1d6": return 4
		"1d8": return 5
		"1d10": return 6
		"1d12": return 7
	return 5

func get_spell_slots(character_level: int, spell_level: int) -> int:
	"""Get number of spell slots at a given character and spell level"""
	if not is_spellcaster:
		return 0
	
	if character_level < 1 or character_level > spell_slots_level_1.size():
		return 0
	
	match spell_level:
		1: return spell_slots_level_1[character_level - 1] if spell_slots_level_1.size() >= character_level else 0
		2: return spell_slots_level_2[character_level - 1] if spell_slots_level_2.size() >= character_level else 0
		3: return spell_slots_level_3[character_level - 1] if spell_slots_level_3.size() >= character_level else 0
		4: return spell_slots_level_4[character_level - 1] if spell_slots_level_4.size() >= character_level else 0
		5: return spell_slots_level_5[character_level - 1] if spell_slots_level_5.size() >= character_level else 0
		6: return spell_slots_level_6[character_level - 1] if spell_slots_level_6.size() >= character_level else 0
		7: return spell_slots_level_7[character_level - 1] if spell_slots_level_7.size() >= character_level else 0
		8: return spell_slots_level_8[character_level - 1] if spell_slots_level_8.size() >= character_level else 0
		9: return spell_slots_level_9[character_level - 1] if spell_slots_level_9.size() >= character_level else 0
	
	return 0

func get_cantrips_known(character_level: int) -> int:
	"""Get number of cantrips known at a given level"""
	if not is_spellcaster or cantrips_known.is_empty():
		return 0
	
	if character_level < 1 or character_level > cantrips_known.size():
		return 0
	
	return cantrips_known[character_level - 1]

func has_feature_at_level(feature_name: String, level: int) -> bool:
	"""Check if class has a specific feature at given level"""
	match level:
		1: return level_1_features.has(feature_name)
		2: return level_2_features.has(feature_name)
		3: return level_3_features.has(feature_name)
		# ... Add more levels as needed
	return false

func get_features_at_level(level: int) -> Array[String]:
	"""Get all features gained at a specific level"""
	match level:
		1: return level_1_features
		2: return level_2_features
		3: return level_3_features
		# ... Add more levels as needed
	return []

func is_proficient_with_armor(armor_type: String) -> bool:
	"""Check if class is proficient with an armor type"""
	return armor_proficiencies.has(armor_type)

func is_proficient_with_weapon(weapon_type: String) -> bool:
	"""Check if class is proficient with a weapon type"""
	return weapon_proficiencies.has(weapon_type)

func get_tooltip_text() -> String:
	"""Generate tooltip/description text"""
	var tooltip = "[b]" + display_name + "[/b]\n"
	tooltip += description + "\n\n"
	tooltip += "[b]Hit Die:[/b] " + hit_die + "\n"
	
	var primary_str = ""
	for ability in primary_abilities:
		if primary_str != "":
			primary_str += ", "
		primary_str += ability
	tooltip += "[b]Primary Abilities:[/b] " + primary_str + "\n"
	
	if is_spellcaster:
		tooltip += "[b]Spellcasting Ability:[/b] " + spellcasting_ability.to_upper() + "\n"
	
	return tooltip
