# skill_database.gd
# AutoLoad singleton - definitions for all 18 canonical D&D skills.
# Canonical skill ids are defined in docs/ARCHITECTURE_CONTRACTS.md section 2.5.
extends Node

# skill_id -> {skill_id: String, display_name: String, stat: String, description: String}
var skills: Dictionary = {}

func _ready():
	_register_skills()
	print("SkillDatabase loaded: ", skills.size(), " skills")

func _register_skills():
	"""Register the 18 canonical skills with their governing stats"""
	# STR
	_register("athletics", "Athletics", "str", "Climbing, jumping, swimming, and feats of raw physical power.")
	# DEX
	_register("acrobatics", "Acrobatics", "dex", "Balance, tumbling, and staying on your feet in tricky situations.")
	_register("sleight_of_hand", "Sleight of Hand", "dex", "Manual trickery such as picking pockets, palming objects, or planting items.")
	_register("stealth", "Stealth", "dex", "Concealing yourself and moving silently to avoid detection.")
	# INT
	_register("arcana", "Arcana", "int", "Knowledge of spells, magic items, planes of existence, and arcane lore.")
	_register("history", "History", "int", "Recalling lore about historical events, people, and ancient civilizations.")
	_register("investigation", "Investigation", "int", "Deducing clues, searching for hidden details, and solving puzzles.")
	_register("nature", "Nature", "int", "Knowledge of terrain, plants, animals, weather, and natural cycles.")
	_register("religion", "Religion", "int", "Knowledge of deities, rites, prayers, holy symbols, and divine lore.")
	# WIS
	_register("animal_handling", "Animal Handling", "wis", "Calming, controlling, and reading the intentions of animals.")
	_register("insight", "Insight", "wis", "Reading body language and determining the true intentions of others.")
	_register("medicine", "Medicine", "wis", "Stabilizing the dying and diagnosing illness or injury.")
	_register("perception", "Perception", "wis", "Spotting, hearing, or otherwise detecting the presence of something.")
	_register("survival", "Survival", "wis", "Tracking, foraging, navigating the wilds, and predicting the weather.")
	# CHA
	_register("deception", "Deception", "cha", "Hiding the truth convincingly, through words or actions.")
	_register("intimidation", "Intimidation", "cha", "Influencing others through threats, hostility, and force of presence.")
	_register("performance", "Performance", "cha", "Delighting an audience with music, dance, acting, or storytelling.")
	_register("persuasion", "Persuasion", "cha", "Influencing others with tact, social grace, and good nature.")

func _register(skill_id: String, display_name: String, stat: String, description: String):
	"""Register a single skill definition"""
	skills[skill_id] = {
		"skill_id": skill_id,
		"display_name": display_name,
		"stat": stat,
		"description": description
	}

func get_skill(skill_id: String) -> Dictionary:
	"""Get skill definition by ID"""
	return skills.get(normalize_skill_id(skill_id), {})

func get_all_skills() -> Array:
	"""Get all skill definitions"""
	return skills.values()

func get_all_skill_ids() -> Array:
	"""Get all canonical skill ids"""
	return skills.keys()

func get_governing_stat(skill_id: String) -> String:
	"""Get the ability stat ('str'..'cha') that governs a skill"""
	return skills.get(normalize_skill_id(skill_id), {}).get("stat", "str")

func get_display_name(skill_id: String) -> String:
	"""Get the display name of a skill (falls back to capitalized id)"""
	var skill = get_skill(skill_id)
	if skill.is_empty():
		return skill_id.capitalize()
	return skill.display_name

func has_skill(skill_id: String) -> bool:
	"""Check whether a skill id is a known canonical skill"""
	return skills.has(normalize_skill_id(skill_id))

func normalize_skill_id(skill_id: String) -> String:
	"""Normalize legacy skill names ('Animal Handling') to canonical ids ('animal_handling')"""
	return skill_id.strip_edges().to_lower().replace(" ", "_")
