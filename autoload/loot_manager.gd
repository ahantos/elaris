# loot_manager.gd
# AutoLoad singleton - loot tables by enemy type and drop rolling.
extends Node

# enemy_type -> loot table Dictionary
# Table schema:
#   drop_chance: float  (0.0-1.0 chance any loot drops at all)
#   entries: Array of:
#     { "item_id": String OR "category": String("weapon"/"armor"/"material"/"consumable"),
#       "weight": float, "count_min": int, "count_max": int }
#   gold_min: int
#   gold_max: int
#   gold_level_scale: float  (extra gold per enemy level)
var loot_tables: Dictionary = {}

func _ready():
	_build_tables()
	print("LootManager initialized: ", loot_tables.size(), " loot tables")


# =====================================================================
# TABLE DEFINITIONS
# =====================================================================

func _build_tables():
	"""Register all loot tables."""

	# ── GOBLIN ───────────────────────────────────────────────────────
	loot_tables["goblin"] = {
		"drop_chance": 0.70,
		"entries": [
			{"item_id": "dagger",               "weight": 20, "count_min": 1, "count_max": 1},
			{"item_id": "shortbow",             "weight": 10, "count_min": 1, "count_max": 1},
			{"item_id": "material_hide",        "weight": 25, "count_min": 1, "count_max": 3},
			{"item_id": "material_oak",         "weight": 15, "count_min": 1, "count_max": 2},
			{"item_id": "potion_healing_minor", "weight": 10, "count_min": 1, "count_max": 1},
			{"category": "material",            "weight": 20, "count_min": 1, "count_max": 1},
		],
		"gold_min": 1, "gold_max": 5,
		"gold_level_scale": 0.5
	}

	# ── SKELETON ─────────────────────────────────────────────────────
	loot_tables["skeleton"] = {
		"drop_chance": 0.65,
		"entries": [
			{"item_id": "longsword",            "weight": 15, "count_min": 1, "count_max": 1},
			{"item_id": "shortbow",             "weight": 10, "count_min": 1, "count_max": 1},
			{"item_id": "chain_mail",           "weight": 10, "count_min": 1, "count_max": 1},
			{"item_id": "material_iron",        "weight": 20, "count_min": 1, "count_max": 2},
			{"item_id": "material_bronze",      "weight": 15, "count_min": 1, "count_max": 3},
			{"item_id": "antidote",             "weight": 5,  "count_min": 1, "count_max": 1},
			{"category": "weapon",              "weight": 25, "count_min": 1, "count_max": 1},
		],
		"gold_min": 2, "gold_max": 8,
		"gold_level_scale": 0.8
	}

	# ── BANDIT ───────────────────────────────────────────────────────
	loot_tables["bandit"] = {
		"drop_chance": 0.80,
		"entries": [
			{"category": "weapon",              "weight": 25, "count_min": 1, "count_max": 1},
			{"category": "armor",               "weight": 15, "count_min": 1, "count_max": 1},
			{"item_id": "potion_healing_minor", "weight": 20, "count_min": 1, "count_max": 2},
			{"item_id": "potion_healing",       "weight": 10, "count_min": 1, "count_max": 1},
			{"item_id": "thieves_tools",        "weight": 8,  "count_min": 1, "count_max": 1},
			{"item_id": "material_leather",     "weight": 15, "count_min": 1, "count_max": 2},
			{"item_id": "material_iron",        "weight": 7,  "count_min": 1, "count_max": 2},
		],
		"gold_min": 5, "gold_max": 20,
		"gold_level_scale": 1.5
	}

	# ── WOLF ─────────────────────────────────────────────────────────
	loot_tables["wolf"] = {
		"drop_chance": 0.55,
		"entries": [
			{"item_id": "material_hide",        "weight": 40, "count_min": 1, "count_max": 3},
			{"item_id": "material_leather",     "weight": 20, "count_min": 1, "count_max": 2},
			{"item_id": "cooked_meat",          "weight": 25, "count_min": 1, "count_max": 2},
			{"item_id": "material_scaled_leather","weight": 15,"count_min": 1, "count_max": 1},
		],
		"gold_min": 0, "gold_max": 2,
		"gold_level_scale": 0.2
	}

	# ── BOSS ─────────────────────────────────────────────────────────
	loot_tables["boss"] = {
		"drop_chance": 1.00,
		"entries": [
			{"category": "weapon",              "weight": 20, "count_min": 1, "count_max": 2},
			{"category": "armor",               "weight": 20, "count_min": 1, "count_max": 2},
			{"item_id": "potion_healing_greater","weight": 15, "count_min": 1, "count_max": 2},
			{"item_id": "potion_healing",       "weight": 15, "count_min": 1, "count_max": 3},
			{"category": "material",            "weight": 20, "count_min": 2, "count_max": 4},
			{"item_id": "ring_protection",      "weight": 5,  "count_min": 1, "count_max": 1},
			{"item_id": "amulet_health",        "weight": 5,  "count_min": 1, "count_max": 1},
		],
		"gold_min": 20, "gold_max": 100,
		"gold_level_scale": 5.0
	}

	# ── DEFAULT FALLBACK ─────────────────────────────────────────────
	loot_tables["default"] = {
		"drop_chance": 0.40,
		"entries": [
			{"category": "consumable",          "weight": 40, "count_min": 1, "count_max": 1},
			{"category": "material",            "weight": 35, "count_min": 1, "count_max": 2},
			{"category": "weapon",              "weight": 15, "count_min": 1, "count_max": 1},
			{"category": "armor",               "weight": 10, "count_min": 1, "count_max": 1},
		],
		"gold_min": 0, "gold_max": 5,
		"gold_level_scale": 0.3
	}


# =====================================================================
# ROLLING
# =====================================================================

func _get_table(enemy_type: String) -> Dictionary:
	return loot_tables.get(enemy_type, loot_tables.get("default", {}))


func _tier_for_level(enemy_level: int) -> MaterialData.Tier:
	"""Map enemy level to likely material tier (higher level → higher tier chance)."""
	# Roll a random value influenced by level
	var tier_roll := randf()
	# Scale thresholds based on level
	var legendary_thresh := clampf((enemy_level - 12) * 0.05, 0.0, 0.10)
	var epic_thresh      := clampf((enemy_level - 8)  * 0.05, 0.0, 0.20)
	var rare_thresh      := clampf((enemy_level - 4)  * 0.08, 0.0, 0.35)
	var uncommon_thresh  := clampf(enemy_level         * 0.08, 0.0, 0.50)

	if tier_roll < legendary_thresh:
		return MaterialData.Tier.LEGENDARY
	elif tier_roll < legendary_thresh + epic_thresh:
		return MaterialData.Tier.EPIC
	elif tier_roll < legendary_thresh + epic_thresh + rare_thresh:
		return MaterialData.Tier.RARE
	elif tier_roll < legendary_thresh + epic_thresh + rare_thresh + uncommon_thresh:
		return MaterialData.Tier.UNCOMMON
	else:
		return MaterialData.Tier.COMMON


func _roll_entry(entry: Dictionary, enemy_level: int) -> Array:
	"""Resolve one loot entry into item instances."""
	var results: Array = []
	var count: int = randi_range(entry.get("count_min", 1), entry.get("count_max", 1))

	# Determine quality and magic based on level
	var quality: int = 0
	var magic: int = 0
	if enemy_level >= 5:
		quality = ItemDatabase.roll_item_quality()
	if enemy_level >= 8:
		magic = ItemDatabase.roll_magic_modifier()

	if entry.has("item_id"):
		var inst := ItemDatabase.create_item_instance(entry["item_id"], quality, magic)
		if not inst.is_empty():
			inst["stack_count"] = count
			results.append(inst)

	elif entry.has("category"):
		var tier := _tier_for_level(enemy_level)
		var item_data := ItemDatabase.get_random_item_by_type(entry["category"], tier)
		if item_data:
			var inst := ItemDatabase.create_item_instance(item_data.item_id, quality, magic)
			if not inst.is_empty():
				inst["stack_count"] = count
				results.append(inst)

	return results


func roll_loot(enemy_type: String, enemy_level: int = 1) -> Array:
	"""
	Roll loot drops for a defeated enemy.
	Returns Array of item instance Dictionaries.
	Caller is responsible for emitting loot_dropped.
	"""
	var table := _get_table(enemy_type)
	if table.is_empty():
		return []

	# Drop-chance gate
	var drop_chance: float = table.get("drop_chance", 0.5)
	if randf() > drop_chance:
		return []

	var total_weight := 0.0
	var entries: Array = table.get("entries", [])
	for entry in entries:
		total_weight += float(entry.get("weight", 0))

	if total_weight <= 0.0:
		return []

	# Select one entry by weight
	var roll := randf() * total_weight
	var cumulative := 0.0
	var chosen_entry: Dictionary = {}
	for entry in entries:
		cumulative += float(entry.get("weight", 0))
		if roll <= cumulative:
			chosen_entry = entry
			break

	if chosen_entry.is_empty():
		return []

	return _roll_entry(chosen_entry, enemy_level)


func roll_gold(enemy_type: String, enemy_level: int = 1) -> int:
	"""Roll gold drop for a defeated enemy"""
	var table := _get_table(enemy_type)
	if table.is_empty():
		return 0

	var gold_min: int = table.get("gold_min", 0)
	var gold_max: int = table.get("gold_max", 0)
	var scale: float = table.get("gold_level_scale", 0.0)

	var base_gold := randi_range(gold_min, max(gold_min, gold_max))
	var level_bonus := int(scale * (enemy_level - 1))
	return max(0, base_gold + level_bonus)


# =====================================================================
# DATA EXPORT/IMPORT (stateless — tables rebuilt in _ready)
# =====================================================================

func to_dict() -> Dictionary:
	return {}


func from_dict(_data: Dictionary):
	pass
