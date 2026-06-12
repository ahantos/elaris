# recipe_database.gd
# AutoLoad singleton - definitions for all crafting recipes (blacksmithing, alchemy, enchanting, cooking).
# Recipes are generated programmatically in _ready(). Schema per contracts §3:
#   {recipe_id, display_name, station, inputs: [{item_id, count}], output_item_id, output_count,
#    gold_cost, required_player_level, auto_known, description}
# Special enchant recipes additionally carry: {is_enchant: true, enchant_slot: String, plus_level: int}
extends Node

# recipe_id -> recipe definition Dictionary
var recipes: Dictionary = {}

func _ready():
	_register_forge_recipes()
	_register_alchemy_recipes()
	_register_cooking_recipes()
	_register_enchanting_recipes()
	print("RecipeDatabase: ", recipes.size(), " recipes loaded")

# ---------------------------------------------------------------------------
#  REGISTRATION HELPER
# ---------------------------------------------------------------------------

func _reg(r: Dictionary):
	"""Register a single recipe."""
	recipes[r.recipe_id] = r

# ---------------------------------------------------------------------------
#  FORGE  (metals × weapon bases  +  metals × armor bases  +  wood weapons)
# ---------------------------------------------------------------------------

func _register_forge_recipes():
	"""Generate all forge recipes: metal weapons, metal armor, wood weapons."""

	# Tier data: [material_id, unit_count, gold_cost, required_level, auto_known]
	var metals := [
		["bronze",     3,   10,  1, true],
		["iron",       3,   25,  3, true],
		["steel",      4,   75,  6, false],
		["mithril",    4,  300, 10, false],
		["adamantine", 5, 1000, 15, false],
	]

	var weapon_bases := [
		# [base_id, display_suffix, two_handed]
		["dagger",     "Dagger",     false],
		["shortsword", "Shortsword", false],
		["longsword",  "Longsword",  false],
		["greatsword", "Greatsword", true],
		["handaxe",    "Handaxe",    false],
		["battleaxe",  "Battleaxe",  false],
		["greataxe",   "Greataxe",   true],
		["mace",       "Mace",       false],
		["warhammer",  "Warhammer",  true],
		["spear",      "Spear",      false],
	]

	var armor_bases := [
		# [base_id, display_suffix]
		["helmet",     "Helmet"],
		["chestplate", "Chestplate"],
		["gauntlets",  "Gauntlets"],
		["greaves",    "Greaves"],
		["plate_boots","Plate Boots"],
		["shield",     "Shield"],
		["chain_mail", "Chain Mail"],
	]

	# Metal weapons
	for metal in metals:
		var mat_id: String   = metal[0]
		var units: int       = metal[1]
		var gold: int        = metal[2]
		var req_level: int   = metal[3]
		var known: bool      = metal[4]
		var mat_name: String = mat_id.capitalize()

		for wb in weapon_bases:
			var base_id: String  = wb[0]
			var disp: String     = wb[1]
			var recipe_id := "%s_%s_forge" % [mat_id, base_id]
			_reg({
				"recipe_id":            recipe_id,
				"display_name":         "%s %s" % [mat_name, disp],
				"station":              "forge",
				"inputs":               [{"item_id": "material_%s" % mat_id, "count": units}],
				"output_item_id":       "%s_%s" % [mat_id, base_id],
				"output_count":         1,
				"gold_cost":            gold,
				"required_player_level": req_level,
				"auto_known":           known,
				"description":          "Forge a %s %s at the forge." % [mat_name, disp],
			})

	# Metal armor
	for metal in metals:
		var mat_id: String   = metal[0]
		var units: int       = metal[1] + 1   # armor uses one extra unit
		var gold: int        = metal[2]
		var req_level: int   = metal[3]
		var known: bool      = metal[4]
		var mat_name: String = mat_id.capitalize()

		for ab in armor_bases:
			var base_id: String = ab[0]
			var disp: String    = ab[1]
			var recipe_id := "%s_%s_forge" % [mat_id, base_id]
			_reg({
				"recipe_id":            recipe_id,
				"display_name":         "%s %s" % [mat_name, disp],
				"station":              "forge",
				"inputs":               [{"item_id": "material_%s" % mat_id, "count": units}],
				"output_item_id":       "%s_%s" % [mat_id, base_id],
				"output_count":         1,
				"gold_cost":            gold,
				"required_player_level": req_level,
				"auto_known":           known,
				"description":          "Forge a %s %s at the forge." % [mat_name, disp],
			})

	# Wood weapons
	# Tier data: [material_id, unit_count, gold_cost, required_level, auto_known]
	var woods := [
		["oak", 3,  8, 1, true],
		["ash", 3, 20, 3, true],
		["yew", 4, 60, 6, false],
	]

	var wood_bases := [
		["quarterstaff", "Quarterstaff"],
		["club",         "Club"],
		["shortbow",     "Shortbow"],
		["longbow",      "Longbow"],
	]

	for wood in woods:
		var mat_id: String   = wood[0]
		var units: int       = wood[1]
		var gold: int        = wood[2]
		var req_level: int   = wood[3]
		var known: bool      = wood[4]
		var mat_name: String = mat_id.capitalize()

		for wb in wood_bases:
			var base_id: String = wb[0]
			var disp: String    = wb[1]
			var recipe_id := "%s_%s_forge" % [mat_id, base_id]
			_reg({
				"recipe_id":            recipe_id,
				"display_name":         "%s %s" % [mat_name, disp],
				"station":              "forge",
				"inputs":               [{"item_id": "material_%s" % mat_id, "count": units}],
				"output_item_id":       "%s_%s" % [mat_id, base_id],
				"output_count":         1,
				"gold_cost":            gold,
				"required_player_level": req_level,
				"auto_known":           known,
				"description":          "Carve a %s %s at the forge." % [mat_name, disp],
			})

# ---------------------------------------------------------------------------
#  ALCHEMY TABLE
# ---------------------------------------------------------------------------

func _register_alchemy_recipes():
	"""Register potion and elixir recipes for the alchemy table."""

	# Healing potions (escalating tier)
	_reg({
		"recipe_id":            "brew_potion_healing_minor",
		"display_name":         "Brew Minor Healing Potion",
		"station":              "alchemy_table",
		"inputs":               [{"item_id": "material_linen", "count": 2}],
		"output_item_id":       "potion_healing_minor",
		"output_count":         1,
		"gold_cost":            5,
		"required_player_level": 1,
		"auto_known":           true,
		"description":          "Brew a minor healing potion from linen herbs.",
	})

	_reg({
		"recipe_id":            "brew_potion_healing",
		"display_name":         "Brew Healing Potion",
		"station":              "alchemy_table",
		"inputs":               [
			{"item_id": "material_linen",  "count": 2},
			{"item_id": "material_silk",   "count": 1},
		],
		"output_item_id":       "potion_healing",
		"output_count":         1,
		"gold_cost":            20,
		"required_player_level": 3,
		"auto_known":           false,
		"description":          "Brew a standard healing potion.",
	})

	_reg({
		"recipe_id":            "brew_potion_healing_greater",
		"display_name":         "Brew Greater Healing Potion",
		"station":              "alchemy_table",
		"inputs":               [
			{"item_id": "material_silk",   "count": 3},
			{"item_id": "material_linen",  "count": 2},
		],
		"output_item_id":       "potion_healing_greater",
		"output_count":         1,
		"gold_cost":            60,
		"required_player_level": 6,
		"auto_known":           false,
		"description":          "Brew a greater healing potion from rare silk extracts.",
	})

	# Antidote
	_reg({
		"recipe_id":            "brew_antidote",
		"display_name":         "Brew Antidote",
		"station":              "alchemy_table",
		"inputs":               [{"item_id": "material_linen", "count": 3}],
		"output_item_id":       "antidote",
		"output_count":         1,
		"gold_cost":            15,
		"required_player_level": 2,
		"auto_known":           true,
		"description":          "Brew an antidote that cures poison.",
	})

	# Elixirs (5 misc elixirs using existing consumable/accessory ids)
	_reg({
		"recipe_id":            "brew_elixir_strength",
		"display_name":         "Brew Elixir of Strength",
		"station":              "alchemy_table",
		"inputs":               [
			{"item_id": "material_hide",   "count": 2},
			{"item_id": "material_linen",  "count": 1},
		],
		"output_item_id":       "elixir_strength",
		"output_count":         1,
		"gold_cost":            30,
		"required_player_level": 4,
		"auto_known":           false,
		"description":          "An elixir that temporarily boosts strength.",
	})

	_reg({
		"recipe_id":            "brew_elixir_agility",
		"display_name":         "Brew Elixir of Agility",
		"station":              "alchemy_table",
		"inputs":               [
			{"item_id": "material_leather", "count": 1},
			{"item_id": "material_linen",   "count": 2},
		],
		"output_item_id":       "elixir_agility",
		"output_count":         1,
		"gold_cost":            30,
		"required_player_level": 4,
		"auto_known":           false,
		"description":          "An elixir that temporarily boosts agility.",
	})

	_reg({
		"recipe_id":            "brew_elixir_resist_fire",
		"display_name":         "Brew Elixir of Fire Resistance",
		"station":              "alchemy_table",
		"inputs":               [
			{"item_id": "material_silk",    "count": 2},
			{"item_id": "material_leather", "count": 1},
		],
		"output_item_id":       "elixir_resist_fire",
		"output_count":         1,
		"gold_cost":            50,
		"required_player_level": 5,
		"auto_known":           false,
		"description":          "An elixir that temporarily grants fire resistance.",
	})

	_reg({
		"recipe_id":            "brew_elixir_mana",
		"display_name":         "Brew Elixir of Mana",
		"station":              "alchemy_table",
		"inputs":               [
			{"item_id": "material_silk",   "count": 2},
			{"item_id": "material_linen",  "count": 3},
		],
		"output_item_id":       "elixir_mana",
		"output_count":         1,
		"gold_cost":            40,
		"required_player_level": 3,
		"auto_known":           false,
		"description":          "An elixir that restores magical energy.",
	})

	_reg({
		"recipe_id":            "brew_elixir_fortitude",
		"display_name":         "Brew Elixir of Fortitude",
		"station":              "alchemy_table",
		"inputs":               [
			{"item_id": "material_hide",    "count": 3},
			{"item_id": "material_leather", "count": 1},
		],
		"output_item_id":       "elixir_fortitude",
		"output_count":         1,
		"gold_cost":            35,
		"required_player_level": 4,
		"auto_known":           false,
		"description":          "An elixir that temporarily boosts constitution.",
	})

# ---------------------------------------------------------------------------
#  COOKING FIRE
# ---------------------------------------------------------------------------

func _register_cooking_recipes():
	"""Register food recipes for the cooking fire."""

	_reg({
		"recipe_id":            "cook_bread",
		"display_name":         "Bake Bread",
		"station":              "cooking_fire",
		"inputs":               [],
		"output_item_id":       "bread",
		"output_count":         1,
		"gold_cost":            2,
		"required_player_level": 1,
		"auto_known":           true,
		"description":          "Bake a simple loaf of bread.",
	})

	_reg({
		"recipe_id":            "cook_cooked_meat",
		"display_name":         "Cook Meat",
		"station":              "cooking_fire",
		"inputs":               [{"item_id": "material_hide", "count": 1}],
		"output_item_id":       "cooked_meat",
		"output_count":         1,
		"gold_cost":            3,
		"required_player_level": 1,
		"auto_known":           true,
		"description":          "Cook raw meat over a fire.",
	})

	_reg({
		"recipe_id":            "cook_hearty_stew",
		"display_name":         "Cook Hearty Stew",
		"station":              "cooking_fire",
		"inputs":               [
			{"item_id": "material_hide",  "count": 1},
			{"item_id": "material_linen", "count": 1},
		],
		"output_item_id":       "hearty_stew",
		"output_count":         1,
		"gold_cost":            8,
		"required_player_level": 2,
		"auto_known":           true,
		"description":          "A hearty stew that fills the belly and restores stamina.",
	})

# ---------------------------------------------------------------------------
#  ENCHANTING TABLE
# ---------------------------------------------------------------------------

func _register_enchanting_recipes():
	"""Register enchant recipes. These are SPECIAL recipes:
	   - is_enchant: true
	   - enchant_slot: 'main_hand' for weapon enchants, 'chest' for armor enchants
	   - plus_level: 1/2/3 (the magic_modifier increment)
	   CraftingManager handles them by calling SpellManager.enchant_item instead
	   of creating a new item instance.
	"""

	# Weapon enchantments: consume silk (tier 1-2) or mithril-grade (tier 3)
	_reg({
		"recipe_id":            "enchant_weapon_plus1",
		"display_name":         "Enchant Weapon +1",
		"station":              "enchanting_table",
		"inputs":               [{"item_id": "material_silk",   "count": 2}],
		"output_item_id":       "",          # no new item; modifies equipped weapon
		"output_count":         0,
		"gold_cost":            100,
		"required_player_level": 5,
		"auto_known":           false,
		"description":          "Infuse a weapon with magical energy (+1 magic modifier).",
		"is_enchant":           true,
		"enchant_slot":         "main_hand",
		"plus_level":           1,
	})

	_reg({
		"recipe_id":            "enchant_weapon_plus2",
		"display_name":         "Enchant Weapon +2",
		"station":              "enchanting_table",
		"inputs":               [
			{"item_id": "material_silk",    "count": 3},
			{"item_id": "material_mithril", "count": 1},
		],
		"output_item_id":       "",
		"output_count":         0,
		"gold_cost":            500,
		"required_player_level": 10,
		"auto_known":           false,
		"description":          "Deeply enchant a weapon (+2 magic modifier). Requires mithril dust.",
		"is_enchant":           true,
		"enchant_slot":         "main_hand",
		"plus_level":           2,
	})

	_reg({
		"recipe_id":            "enchant_weapon_plus3",
		"display_name":         "Enchant Weapon +3",
		"station":              "enchanting_table",
		"inputs":               [
			{"item_id": "material_silk",       "count": 4},
			{"item_id": "material_mithril",    "count": 2},
			{"item_id": "material_adamantine", "count": 1},
		],
		"output_item_id":       "",
		"output_count":         0,
		"gold_cost":            2000,
		"required_player_level": 15,
		"auto_known":           false,
		"description":          "Master enchant a weapon (+3 magic modifier, cap). Requires adamantine dust.",
		"is_enchant":           true,
		"enchant_slot":         "main_hand",
		"plus_level":           3,
	})

	# Armor enchantments
	_reg({
		"recipe_id":            "enchant_armor_plus1",
		"display_name":         "Enchant Armor +1",
		"station":              "enchanting_table",
		"inputs":               [{"item_id": "material_silk",   "count": 2}],
		"output_item_id":       "",
		"output_count":         0,
		"gold_cost":            100,
		"required_player_level": 5,
		"auto_known":           false,
		"description":          "Infuse armor with protective magic (+1 magic modifier).",
		"is_enchant":           true,
		"enchant_slot":         "chest",
		"plus_level":           1,
	})

	_reg({
		"recipe_id":            "enchant_armor_plus2",
		"display_name":         "Enchant Armor +2",
		"station":              "enchanting_table",
		"inputs":               [
			{"item_id": "material_silk",    "count": 3},
			{"item_id": "material_mithril", "count": 1},
		],
		"output_item_id":       "",
		"output_count":         0,
		"gold_cost":            500,
		"required_player_level": 10,
		"auto_known":           false,
		"description":          "Deeply enchant armor (+2 magic modifier).",
		"is_enchant":           true,
		"enchant_slot":         "chest",
		"plus_level":           2,
	})

	_reg({
		"recipe_id":            "enchant_armor_plus3",
		"display_name":         "Enchant Armor +3",
		"station":              "enchanting_table",
		"inputs":               [
			{"item_id": "material_silk",       "count": 4},
			{"item_id": "material_mithril",    "count": 2},
			{"item_id": "material_adamantine", "count": 1},
		],
		"output_item_id":       "",
		"output_count":         0,
		"gold_cost":            2000,
		"required_player_level": 15,
		"auto_known":           false,
		"description":          "Master enchant armor (+3 magic modifier, cap).",
		"is_enchant":           true,
		"enchant_slot":         "chest",
		"plus_level":           3,
	})

# ---------------------------------------------------------------------------
#  PUBLIC API  (keep stub signatures)
# ---------------------------------------------------------------------------

func get_recipe(recipe_id: String) -> Dictionary:
	"""Get recipe definition by ID. Returns {} if not found."""
	return recipes.get(recipe_id, {})

func get_all_recipes() -> Array:
	"""Get all recipe definitions."""
	return recipes.values()

func get_recipes_for_station(station_id: String) -> Array:
	"""Get all recipes craftable at a station ('forge', 'alchemy_table', 'enchanting_table', 'cooking_fire')."""
	var result := []
	for recipe in recipes.values():
		if recipe.get("station", "") == station_id:
			result.append(recipe)
	return result
