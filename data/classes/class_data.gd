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
@export var tool_proficiencies: Array[String] = []  # e.g. ["thieves_tools"] for Rogue

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
# Levels 4-40 live in features_by_level (built from the arrays above; extend there)

# level (int) -> Array[String] of feature ids. Built lazily from the exported
# arrays so feature queries scale to level 40 without 40 exported properties.
var _features_by_level: Dictionary = {}
var _features_built: bool = false

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

func get_hit_die_sides() -> int:
	"""Get the number of sides on the hit die (6/8/10/12)"""
	match hit_die:
		"1d6": return 6
		"1d8": return 8
		"1d10": return 10
		"1d12": return 12
	# Fallback: parse "XdY" strings generically
	var parts = hit_die.split("d")
	if parts.size() == 2 and int(parts[1]) > 0:
		return int(parts[1])
	return 10

func get_hit_die_average() -> int:
	"""Get average value of hit die (rounded up, as used for HP per level)"""
	match hit_die:
		"1d6": return 4
		"1d8": return 5
		"1d10": return 6
		"1d12": return 7
	return 5

func _get_slot_entry(slots: Array, character_level: int) -> int:
	"""Slot table lookup; levels beyond the table clamp to the LAST entry (level-40 support)"""
	if character_level < 1 or slots.is_empty():
		return 0
	var index = clampi(character_level, 1, slots.size()) - 1
	return slots[index]

func get_spell_slots(character_level: int, spell_level: int) -> int:
	"""Get number of spell slots at a given character and spell level.
	Character levels beyond the table (21-40) reuse the level-20 entry."""
	if not is_spellcaster:
		return 0

	match spell_level:
		1: return _get_slot_entry(spell_slots_level_1, character_level)
		2: return _get_slot_entry(spell_slots_level_2, character_level)
		3: return _get_slot_entry(spell_slots_level_3, character_level)
		4: return _get_slot_entry(spell_slots_level_4, character_level)
		5: return _get_slot_entry(spell_slots_level_5, character_level)
		6: return _get_slot_entry(spell_slots_level_6, character_level)
		7: return _get_slot_entry(spell_slots_level_7, character_level)
		8: return _get_slot_entry(spell_slots_level_8, character_level)
		9: return _get_slot_entry(spell_slots_level_9, character_level)

	return 0

func get_cantrips_known(character_level: int) -> int:
	"""Get number of cantrips known at a given level (clamps beyond table to last entry)"""
	if not is_spellcaster:
		return 0
	return _get_slot_entry(cantrips_known, character_level)

func get_features_by_level() -> Dictionary:
	"""Get the full level -> Array[String] feature map (levels 1 to 40)"""
	_ensure_features_built()
	return _features_by_level

func _ensure_features_built():
	"""Build the features_by_level Dictionary from the exported per-level arrays"""
	if _features_built:
		return
	_features_by_level = {}
	if not level_1_features.is_empty():
		_features_by_level[1] = level_1_features
	if not level_2_features.is_empty():
		_features_by_level[2] = level_2_features
	if not level_3_features.is_empty():
		_features_by_level[3] = level_3_features
	_features_built = true

func has_feature_at_level(feature_name: String, level: int) -> bool:
	"""Check if class has a specific feature at given level (valid for levels 1-40)"""
	return get_features_at_level(level).has(feature_name)

func get_features_at_level(level: int) -> Array[String]:
	"""Get all features gained at a specific level (valid for levels 1-40)"""
	_ensure_features_built()
	var features: Array[String] = []
	if _features_by_level.has(level):
		features = _features_by_level[level]
	return features

func get_features_up_to_level(level: int) -> Array[String]:
	"""Get all features unlocked at or below a given level"""
	_ensure_features_built()
	var features: Array[String] = []
	for feature_level in _features_by_level:
		if feature_level <= level:
			features.append_array(_features_by_level[feature_level])
	return features

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

	var saves_str = ""
	for save_stat in saving_throw_proficiencies:
		if saves_str != "":
			saves_str += ", "
		saves_str += save_stat.to_upper()
	if saves_str != "":
		tooltip += "[b]Saving Throws:[/b] " + saves_str + "\n"

	if is_spellcaster:
		tooltip += "[b]Spellcasting Ability:[/b] " + spellcasting_ability.to_upper() + "\n"

	var features_str = ""
	for feature in level_1_features:
		if features_str != "":
			features_str += ", "
		features_str += feature.capitalize()
	if features_str != "":
		tooltip += "[b]Level 1 Features:[/b] " + features_str + "\n"

	return tooltip
