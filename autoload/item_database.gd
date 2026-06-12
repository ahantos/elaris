# item_database.gd
# AutoLoad singleton - manages all item and material definitions
extends Node

# Databases
var materials: Dictionary = {}  # material_id -> MaterialData
var items: Dictionary = {}  # item_id -> ItemData

func _ready():
	print("ItemDatabase initializing...")
	load_materials()
	load_items()
	print("ItemDatabase ready: ", materials.size(), " materials, ", items.size(), " items")


# =====================================================================
# MATERIALS
# =====================================================================

func load_materials():
	"""Load all material definitions"""

	# ── METALS (5 tiers) ──────────────────────────────────────────────
	_reg_mat("bronze",    "Bronze",    MaterialData.Category.METAL, MaterialData.Tier.COMMON,
		20, Color(0.80, 0.50, 0.20), 1.0,    0, 0, true)
	_reg_mat("iron",      "Iron",      MaterialData.Category.METAL, MaterialData.Tier.UNCOMMON,
		40, Color(0.50, 0.50, 0.50), 2.0,    0, 0, true)
	_reg_mat("steel",     "Steel",     MaterialData.Category.METAL, MaterialData.Tier.RARE,
		70, Color(0.70, 0.70, 0.80), 5.0,    1, 1, true)
	_reg_mat("mithril",   "Mithril",   MaterialData.Category.METAL, MaterialData.Tier.EPIC,
		100, Color(0.80, 0.90, 1.00), 20.0,  2, 2, true)
	_reg_mat("adamantine","Adamantine",MaterialData.Category.METAL, MaterialData.Tier.LEGENDARY,
		150, Color(0.30, 0.10, 0.40), 100.0, 3, 3, true)

	# ── WOOD (5 tiers) ───────────────────────────────────────────────
	_reg_mat("oak",      "Oak",      MaterialData.Category.WOOD, MaterialData.Tier.COMMON,
		15, Color(0.55, 0.35, 0.15), 0.8,   0, 0, false)
	_reg_mat("ash",      "Ash",      MaterialData.Category.WOOD, MaterialData.Tier.UNCOMMON,
		28, Color(0.60, 0.45, 0.30), 1.5,   0, 0, false)
	_reg_mat("yew",      "Yew",      MaterialData.Category.WOOD, MaterialData.Tier.RARE,
		45, Color(0.40, 0.25, 0.10), 4.0,   1, 0, false)
	_reg_mat("ebony",    "Ebony",    MaterialData.Category.WOOD, MaterialData.Tier.EPIC,
		65, Color(0.10, 0.08, 0.08), 15.0,  2, 0, false)
	_reg_mat("starwood", "Starwood", MaterialData.Category.WOOD, MaterialData.Tier.LEGENDARY,
		90, Color(0.60, 0.60, 1.00), 80.0,  3, 1, false)

	# ── LEATHER (5 tiers) ────────────────────────────────────────────
	_reg_mat("hide",          "Hide",          MaterialData.Category.LEATHER, MaterialData.Tier.COMMON,
		15, Color(0.60, 0.40, 0.20), 0.8,  0, 0, false)
	_reg_mat("leather",       "Leather",       MaterialData.Category.LEATHER, MaterialData.Tier.UNCOMMON,
		30, Color(0.50, 0.30, 0.20), 1.5,  0, 1, false)
	_reg_mat("scaled_leather","Scaled Leather",MaterialData.Category.LEATHER, MaterialData.Tier.RARE,
		50, Color(0.30, 0.50, 0.30), 4.0,  0, 1, false)
	_reg_mat("wyvern_leather","Wyvern Leather",MaterialData.Category.LEATHER, MaterialData.Tier.EPIC,
		75, Color(0.20, 0.45, 0.20), 18.0, 1, 2, false)
	_reg_mat("dragon_leather","Dragon Leather",MaterialData.Category.LEATHER, MaterialData.Tier.LEGENDARY,
		110, Color(0.60, 0.15, 0.10), 90.0,2, 3, false)

	# ── CLOTH (5 tiers) ──────────────────────────────────────────────
	_reg_mat("linen",          "Linen",          MaterialData.Category.CLOTH, MaterialData.Tier.COMMON,
		10, Color(0.90, 0.90, 0.80), 0.5,  0, 0, false)
	_reg_mat("cotton",         "Cotton",         MaterialData.Category.CLOTH, MaterialData.Tier.UNCOMMON,
		18, Color(0.95, 0.92, 0.85), 1.0,  0, 0, false)
	_reg_mat("silk",           "Silk",           MaterialData.Category.CLOTH, MaterialData.Tier.RARE,
		40, Color(1.00, 0.90, 0.90), 3.0,  0, 0, false)
	_reg_mat("spidersilk",     "Spidersilk",     MaterialData.Category.CLOTH, MaterialData.Tier.EPIC,
		60, Color(0.70, 0.70, 0.90), 14.0, 1, 1, false)
	_reg_mat("celestial_cloth","Celestial Cloth",MaterialData.Category.CLOTH, MaterialData.Tier.LEGENDARY,
		80, Color(0.90, 0.80, 1.00), 75.0, 2, 2, false)

	print("ItemDatabase: Loaded ", materials.size(), " materials")


func _reg_mat(id: String, name: String, category: MaterialData.Category,
		tier: MaterialData.Tier, durability: int, color: Color,
		value_mult: float, dmg_bonus: int, arm_bonus: int, metallic: bool):
	"""Internal helper: create and register a material"""
	var mat := MaterialData.new()
	mat.material_id = id
	mat.material_name = name
	mat.category = category
	mat.tier = tier
	mat.base_durability = durability
	mat.color = color
	mat.base_value_multiplier = value_mult
	mat.damage_bonus = dmg_bonus
	mat.armor_bonus = arm_bonus
	mat.metallic = metallic
	materials[id] = mat


func create_material(id: String, name: String, category: MaterialData.Category,
		tier: MaterialData.Tier, durability: int, color: Color,
		value_mult: float) -> MaterialData:
	"""Public helper kept for backward compatibility"""
	var mat := MaterialData.new()
	mat.material_id = id
	mat.material_name = name
	mat.category = category
	mat.tier = tier
	mat.base_durability = durability
	mat.color = color
	mat.base_value_multiplier = value_mult
	mat.metallic = (category == MaterialData.Category.METAL)
	return mat


func register_material(material: MaterialData):
	"""Register a material in the database"""
	materials[material.material_id] = material


func get_material(material_id: String) -> MaterialData:
	"""Get material by ID"""
	return materials.get(material_id, null)


func get_materials_by_tier(tier: MaterialData.Tier) -> Array:
	"""Get all materials of a specific tier"""
	var result = []
	for mat in materials.values():
		if mat.tier == tier:
			result.append(mat)
	return result


func get_materials_by_category(category: MaterialData.Category) -> Array:
	"""Get all materials of a specific category"""
	var result = []
	for mat in materials.values():
		if mat.category == category:
			result.append(mat)
	return result


# =====================================================================
# ITEM CATALOG
# =====================================================================

# Weapon base definitions:
# { base_id, display_name, damage_dice, damage_type, two_handed, is_ranged,
#   range_normal, range_max, weight_base, value_base, special_props, valid_materials }
const WEAPON_BASES := [
	# ── MELEE ────────────────────────────────────────────────────────
	{
		"id": "dagger",        "name": "Dagger",        "dice": "1d4",  "dtype": "piercing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 1.0, "value": 20,
		"props": ["finesse", "thrown"], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "shortsword",    "name": "Shortsword",    "dice": "1d6",  "dtype": "piercing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 2.0, "value": 40,
		"props": ["finesse"], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "longsword",     "name": "Longsword",     "dice": "1d8",  "dtype": "slashing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 3.0, "value": 60,
		"props": [], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "greatsword",    "name": "Greatsword",    "dice": "2d6",  "dtype": "slashing",
		"2h": true,  "ranged": false, "rn": 0, "rm": 0,
		"weight": 6.0, "value": 80,
		"props": [], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "handaxe",       "name": "Handaxe",       "dice": "1d6",  "dtype": "slashing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 2.0, "value": 30,
		"props": ["thrown"], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "battleaxe",     "name": "Battleaxe",     "dice": "1d8",  "dtype": "slashing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 4.0, "value": 60,
		"props": [], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "greataxe",      "name": "Greataxe",      "dice": "1d12", "dtype": "slashing",
		"2h": true,  "ranged": false, "rn": 0, "rm": 0,
		"weight": 7.0, "value": 90,
		"props": [], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "mace",          "name": "Mace",          "dice": "1d6",  "dtype": "bludgeoning",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 4.0, "value": 50,
		"props": [], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "warhammer",     "name": "Warhammer",     "dice": "1d8",  "dtype": "bludgeoning",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 5.0, "value": 70,
		"props": [], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "spear",         "name": "Spear",         "dice": "1d6",  "dtype": "piercing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 3.0, "value": 30,
		"props": ["thrown"], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "rapier",        "name": "Rapier",        "dice": "1d8",  "dtype": "piercing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 2.0, "value": 55,
		"props": ["finesse"], "mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	# ── WOOD MELEE ───────────────────────────────────────────────────
	{
		"id": "quarterstaff",  "name": "Quarterstaff",  "dice": "1d6",  "dtype": "bludgeoning",
		"2h": true,  "ranged": false, "rn": 0, "rm": 0,
		"weight": 4.0, "value": 20,
		"props": [], "mats": ["oak","ash","yew","ebony","starwood"]
	},
	{
		"id": "club",          "name": "Club",          "dice": "1d4",  "dtype": "bludgeoning",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 2.0, "value": 10,
		"props": [], "mats": ["oak","ash","yew","ebony","starwood"]
	},
	# ── RANGED ───────────────────────────────────────────────────────
	{
		"id": "shortbow",      "name": "Shortbow",      "dice": "1d6",  "dtype": "piercing",
		"2h": true,  "ranged": true,  "rn": 16, "rm": 64,
		"weight": 2.0, "value": 40,
		"props": [], "mats": ["oak","ash","yew","ebony","starwood"]
	},
	{
		"id": "longbow",       "name": "Longbow",       "dice": "1d8",  "dtype": "piercing",
		"2h": true,  "ranged": true,  "rn": 24, "rm": 96,
		"weight": 2.0, "value": 70,
		"props": [], "mats": ["oak","ash","yew","ebony","starwood"]
	},
	{
		"id": "light_crossbow","name": "Light Crossbow","dice": "1d8",  "dtype": "piercing",
		"2h": true,  "ranged": true,  "rn": 16, "rm": 64,
		"weight": 5.0, "value": 60,
		"props": [], "mats": ["oak","ash","yew","ebony","starwood"]
	},
	{
		"id": "heavy_crossbow","name": "Heavy Crossbow","dice": "1d10", "dtype": "piercing",
		"2h": true,  "ranged": true,  "rn": 20, "rm": 80,
		"weight": 8.0, "value": 100,
		"props": [], "mats": ["oak","ash","yew","ebony","starwood"]
	},
]

# Armor base definitions:
# { base_id, display_name, slot, ac, armor_type, dex_limit, str_req, stealth_dis,
#   weight_base, value_base, valid_materials }
const ARMOR_BASES := [
	# ── METAL ARMOR ──────────────────────────────────────────────────
	{
		"id": "helmet",       "name": "Helmet",      "slot": "head",
		"ac": 1, "type": "heavy", "dex": 0,  "str": 0,  "stealth": true,
		"weight": 3.0, "value": 50,
		"mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "chestplate",   "name": "Chestplate",  "slot": "chest",
		"ac": 6, "type": "heavy", "dex": 0,  "str": 15, "stealth": true,
		"weight": 15.0, "value": 200,
		"mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "chain_mail",   "name": "Chain Mail",  "slot": "chest",
		"ac": 4, "type": "medium","dex": 2,  "str": 13, "stealth": true,
		"weight": 12.0, "value": 120,
		"mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "scale_mail",   "name": "Scale Mail",  "slot": "chest",
		"ac": 4, "type": "medium","dex": 2,  "str": 0,  "stealth": true,
		"weight": 11.0, "value": 110,
		"mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "gauntlets",    "name": "Gauntlets",   "slot": "hands",
		"ac": 1, "type": "heavy", "dex": 0,  "str": 0,  "stealth": false,
		"weight": 3.0, "value": 40,
		"mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "greaves",      "name": "Greaves",     "slot": "legs",
		"ac": 2, "type": "heavy", "dex": 0,  "str": 0,  "stealth": true,
		"weight": 5.0, "value": 70,
		"mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "plate_boots",  "name": "Plate Boots", "slot": "feet",
		"ac": 1, "type": "heavy", "dex": 0,  "str": 0,  "stealth": true,
		"weight": 3.0, "value": 50,
		"mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	{
		"id": "shield",       "name": "Shield",      "slot": "off_hand",
		"ac": 2, "type": "heavy", "dex": -1, "str": 0,  "stealth": false,
		"weight": 6.0, "value": 40,
		"mats": ["bronze","iron","steel","mithril","adamantine"]
	},
	# ── LEATHER ARMOR ────────────────────────────────────────────────
	{
		"id": "leather_cap",  "name": "Leather Cap", "slot": "head",
		"ac": 1, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 1.0, "value": 20,
		"mats": ["hide","leather","scaled_leather","wyvern_leather","dragon_leather"]
	},
	{
		"id": "jerkin",       "name": "Jerkin",      "slot": "chest",
		"ac": 3, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 8.0, "value": 80,
		"mats": ["hide","leather","scaled_leather","wyvern_leather","dragon_leather"]
	},
	{
		"id": "gloves",       "name": "Gloves",      "slot": "hands",
		"ac": 1, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 0.5, "value": 15,
		"mats": ["hide","leather","scaled_leather","wyvern_leather","dragon_leather"]
	},
	{
		"id": "leggings",     "name": "Leggings",    "slot": "legs",
		"ac": 1, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 3.0, "value": 40,
		"mats": ["hide","leather","scaled_leather","wyvern_leather","dragon_leather"]
	},
	{
		"id": "boots",        "name": "Boots",       "slot": "feet",
		"ac": 1, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 1.0, "value": 20,
		"mats": ["hide","leather","scaled_leather","wyvern_leather","dragon_leather"]
	},
	# ── CLOTH ARMOR ──────────────────────────────────────────────────
	{
		"id": "hood",         "name": "Hood",        "slot": "head",
		"ac": 0, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 0.5, "value": 10,
		"mats": ["linen","cotton","silk","spidersilk","celestial_cloth"]
	},
	{
		"id": "robe",         "name": "Robe",        "slot": "chest",
		"ac": 1, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 4.0, "value": 30,
		"mats": ["linen","cotton","silk","spidersilk","celestial_cloth"]
	},
	{
		"id": "wraps",        "name": "Wraps",       "slot": "hands",
		"ac": 0, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 0.5, "value": 8,
		"mats": ["linen","cotton","silk","spidersilk","celestial_cloth"]
	},
	{
		"id": "pants",        "name": "Pants",       "slot": "legs",
		"ac": 0, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 1.5, "value": 12,
		"mats": ["linen","cotton","silk","spidersilk","celestial_cloth"]
	},
	{
		"id": "slippers",     "name": "Slippers",    "slot": "feet",
		"ac": 0, "type": "light",  "dex": -1, "str": 0,  "stealth": false,
		"weight": 0.5, "value": 8,
		"mats": ["linen","cotton","silk","spidersilk","celestial_cloth"]
	},
]

# Value-scale per tier index (COMMON=0 … LEGENDARY=4)
const TIER_VALUE_MULT := [1.0, 2.0, 5.0, 20.0, 100.0]
# Weight-scale per tier (heavy materials cost more; slight tweak per tier)
const TIER_WEIGHT_MULT := [1.0, 1.1, 1.2, 0.9, 0.8]  # mithril/adamantine lighter


func load_items():
	"""Generate the full item catalog programmatically"""

	# ── 1. WEAPONS ───────────────────────────────────────────────────
	for wb in WEAPON_BASES:
		for mat_id in wb["mats"]:
			var mat: MaterialData = get_material(str(mat_id))
			if not mat:
				continue
			var tier_idx: int = int(mat.tier)
			var item_id: String = str(mat_id) + "_" + str(wb["id"])
			var item: ItemData = ItemData.new()
			item.item_id = item_id
			item.item_name = mat.material_name + " " + str(wb["name"])
			item.item_type = ItemData.ItemType.WEAPON
			item.material = mat
			item.damage_dice = str(wb["dice"])
			item.damage_type = str(wb["dtype"])
			item.is_weapon = true
			item.is_two_handed = bool(wb["2h"])
			item.is_ranged = bool(wb["ranged"])
			item.range_normal = int(wb["rn"])
			item.range_max = int(wb["rm"])
			item.equip_slot = "ranged" if bool(wb["ranged"]) else "main_hand"
			item.has_durability = true
			item.max_durability = mat.base_durability
			for prop in (wb["props"] as Array):
				item.special_properties.append(str(prop))
			item.weight = float(wb["weight"]) * TIER_WEIGHT_MULT[tier_idx]
			item.base_value = int(float(wb["value"]) * TIER_VALUE_MULT[tier_idx])
			item.description = mat.material_name + " " + str(wb["name"]) + " (" + mat.get_tier_name() + ")"
			register_item(item)

	# ── 2. ARMOR ─────────────────────────────────────────────────────
	for ab in ARMOR_BASES:
		for mat_id in ab["mats"]:
			var mat: MaterialData = get_material(str(mat_id))
			if not mat:
				continue
			var tier_idx: int = int(mat.tier)
			var item_id: String = str(mat_id) + "_" + str(ab["id"])
			var item: ItemData = _build_armor_item(item_id,
				mat.material_name + " " + str(ab["name"]),
				mat, str(ab["slot"]), int(ab["ac"]) + mat.armor_bonus,
				str(ab["type"]), int(ab["dex"]), int(ab["str"]), bool(ab["stealth"]))
			item.weight = float(ab["weight"]) * TIER_WEIGHT_MULT[tier_idx]
			item.base_value = int(float(ab["value"]) * TIER_VALUE_MULT[tier_idx])
			item.description = mat.material_name + " " + str(ab["name"]) + " (" + mat.get_tier_name() + ")"
			register_item(item)

	# ── 3. PLAIN-BASE ALIASES (default-material versions) ────────────
	_register_alias_weapon("dagger",        "iron")
	_register_alias_weapon("shortsword",    "iron")
	_register_alias_weapon("longsword",     "iron")
	_register_alias_weapon("greatsword",    "iron")
	_register_alias_weapon("handaxe",       "iron")
	_register_alias_weapon("battleaxe",     "iron")
	_register_alias_weapon("greataxe",      "iron")
	_register_alias_weapon("mace",          "iron")
	_register_alias_weapon("warhammer",     "iron")
	_register_alias_weapon("spear",         "iron")
	_register_alias_weapon("rapier",        "iron")
	_register_alias_weapon("quarterstaff",  "oak")
	_register_alias_weapon("club",          "oak")
	_register_alias_weapon("shortbow",      "oak")
	_register_alias_weapon("longbow",       "oak")
	_register_alias_weapon("light_crossbow","oak")
	_register_alias_weapon("heavy_crossbow","oak")

	_register_alias_armor("helmet",      "iron")
	_register_alias_armor("chestplate",  "iron")
	_register_alias_armor("chain_mail",  "iron")
	_register_alias_armor("scale_mail",  "iron")
	_register_alias_armor("gauntlets",   "iron")
	_register_alias_armor("greaves",     "iron")
	_register_alias_armor("plate_boots", "iron")
	_register_alias_armor("shield",      "iron")
	_register_alias_armor("leather_cap", "leather")
	_register_alias_armor("jerkin",      "leather")
	_register_alias_armor("gloves",      "leather")
	_register_alias_armor("leggings",    "leather")
	_register_alias_armor("boots",       "leather")
	_register_alias_armor("hood",        "linen")
	_register_alias_armor("robe",        "linen")
	_register_alias_armor("wraps",       "linen")
	_register_alias_armor("pants",       "linen")
	_register_alias_armor("slippers",    "linen")

	# Extra aliases needed by .tres starting equipment lists
	# rogue: leather_armor → alias for leather jerkin
	_register_alias_armor_custom("leather_armor", "Leather Armor", "leather", "chest", 3, "light", -1, 0, false, 8.0, 80)

	# ── 4. ACCESSORIES ───────────────────────────────────────────────
	_reg_accessory("ring_protection",   "Ring of Protection",   "rings",    ItemData.ItemType.ACCESSORY_RING,    {"ac": 1},        1, 15,  "A simple ring that wards off harm.")
	_reg_accessory("ring_strength",     "Ring of Strength",     "rings",    ItemData.ItemType.ACCESSORY_RING,    {"str": 1},       1, 20,  "A heavy band that grants physical power.")
	_reg_accessory("ring_dexterity",    "Ring of Dexterity",    "rings",    ItemData.ItemType.ACCESSORY_RING,    {"dex": 1},       1, 20,  "A sleek ring that sharpens reflexes.")
	_reg_accessory("ring_wisdom",       "Ring of Wisdom",       "rings",    ItemData.ItemType.ACCESSORY_RING,    {"wis": 1},       1, 20,  "A ring carved with celestial script.")
	_reg_accessory("amulet_health",     "Amulet of Health",     "neck",     ItemData.ItemType.ACCESSORY_NECK,    {"con": 2},       1, 50,  "A ruby-studded amulet radiating warmth.")
	_reg_accessory("amulet_charisma",   "Amulet of Charisma",   "neck",     ItemData.ItemType.ACCESSORY_NECK,    {"cha": 1},       1, 30,  "An elegant necklace of polished silver.")
	_reg_accessory("cloak_protection",  "Cloak of Protection",  "back",     ItemData.ItemType.ACCESSORY_CLOAK,   {"ac": 1},        2, 40,  "A finely woven cloak that deflects blows.")
	_reg_accessory("cloak_stealth",     "Cloak of Elvenkind",   "back",     ItemData.ItemType.ACCESSORY_CLOAK,   {"dex": 1},       2, 60,  "Shimmers and fades into surroundings.")
	_reg_accessory("belt_strength",     "Belt of Giant Strength","waist",   ItemData.ItemType.ACCESSORY_BELT,    {"str": 2},       2, 80,  "Grants the wearer formidable strength.")
	_reg_accessory("belt_constitution", "Belt of Endurance",    "waist",    ItemData.ItemType.ACCESSORY_BELT,    {"con": 1},       2, 50,  "Toughens the body against punishment.")
	_reg_accessory("trinket_luck",      "Lucky Charm",          "trinkets", ItemData.ItemType.MISC,              {"luck": 1},      0.5, 25, "A rabbit's foot that hums faintly.")
	_reg_accessory("trinket_arcane",    "Arcane Focus",         "trinkets", ItemData.ItemType.MISC,              {},               0.5, 10, "A polished crystal sphere for spellcasting.")
	_reg_accessory("holy_symbol",       "Holy Symbol",          "trinkets", ItemData.ItemType.MISC,              {},               1.0, 5,  "A divine symbol of faith.")

	# ── 5. CONSUMABLES ───────────────────────────────────────────────
	_reg_consumable("potion_healing_minor",   "Minor Healing Potion",   "heal",        6,  0.5, 10)
	_reg_consumable("potion_healing",         "Healing Potion",         "heal",        14, 0.5, 50)
	_reg_consumable("potion_healing_greater", "Greater Healing Potion", "heal",        40, 0.5, 200)
	_reg_consumable("antidote",               "Antidote",               "cure_poison",  1, 0.5, 30)
	_reg_consumable("bread",                  "Bread",                  "food_buff",    2, 1.0,  2)
	_reg_consumable("cooked_meat",            "Cooked Meat",            "food_buff",    4, 1.0,  5)
	_reg_consumable("hearty_stew",            "Hearty Stew",            "food_buff",    6, 1.5, 10)

	# Elixirs: status-effect buffs routed through StatusEffectManager on use
	_reg_consumable("elixir_strength",    "Elixir of Strength",        "elixir", 10, 0.5, 75)
	_reg_consumable("elixir_agility",     "Elixir of Agility",         "elixir", 10, 0.5, 75)
	_reg_consumable("elixir_resist_fire", "Elixir of Fire Resistance", "elixir", 10, 0.5, 75)
	_reg_consumable("elixir_mana",        "Elixir of Mana",            "elixir",  5, 0.5, 75)
	_reg_consumable("elixir_fortitude",   "Elixir of Fortitude",       "elixir", 10, 0.5, 75)

	# ── 6. MISC (packs, tools, books from starting_equipment_list) ───
	_reg_misc("explorer_pack",   "Explorer's Pack",   2.0, 10, "A sturdy pack of adventuring gear.")
	_reg_misc("component_pouch", "Component Pouch",   1.0,  5, "A leather belt pouch for spell components.")
	_reg_misc("scholar_pack",    "Scholar's Pack",    3.0, 15, "Books, ink, and academic supplies.")
	_reg_misc("spellbook",       "Spellbook",         3.0, 50, "A leather-bound tome of arcane knowledge.")
	_reg_misc("priest_pack",     "Priest's Pack",     2.0, 10, "Supplies for a traveling clergyman.")
	_reg_misc("thieves_tools",   "Thieves' Tools",    1.0, 25, "Lock picks, files, and other tools of the trade.")
	_reg_misc("burglar_pack",    "Burglar's Pack",    2.0, 10, "A light pack suited for stealthy work.")

	# ── 7. CRAFTING MATERIAL ITEMS (material_<mat_id>) ───────────────
	for mat_id in materials:
		var mat: MaterialData = materials[mat_id]
		var item_id: String = "material_" + str(mat_id)
		var item := ItemData.new()
		item.item_id = item_id
		item.item_name = mat.material_name
		item.item_type = ItemData.ItemType.MATERIAL
		item.material = mat
		item.stackable = true
		item.max_stack_size = 20
		item.weight = 0.5
		item.base_value = int(5.0 * TIER_VALUE_MULT[int(mat.tier)])
		item.description = mat.get_tier_name() + " " + mat.get_category_name() + " material."
		register_item(item)

	print("ItemDatabase: Loaded ", items.size(), " items")


# ── Build helpers ─────────────────────────────────────────────────────

func _build_armor_item(item_id: String, item_name: String, mat: MaterialData,
		slot: String, ac: int, armor_type: String, dex_limit: int,
		str_req: int, stealth_dis: bool) -> ItemData:
	var item := ItemData.new()
	item.item_id = item_id
	item.item_name = item_name
	item.material = mat
	item.armor_class_bonus = ac
	item.is_armor = true
	item.has_durability = true
	item.max_durability = mat.base_durability
	item.equip_slot = slot
	item.armor_type = armor_type
	item.dex_bonus_limit = dex_limit
	item.strength_requirement = str_req
	item.stealth_disadvantage = stealth_dis

	match slot:
		"head":     item.item_type = ItemData.ItemType.ARMOR_HEAD
		"chest":    item.item_type = ItemData.ItemType.ARMOR_CHEST
		"legs":     item.item_type = ItemData.ItemType.ARMOR_LEGS
		"hands":    item.item_type = ItemData.ItemType.ARMOR_HANDS
		"feet":     item.item_type = ItemData.ItemType.ARMOR_FEET
		"off_hand": item.item_type = ItemData.ItemType.SHIELD
		_:          item.item_type = ItemData.ItemType.ARMOR_CHEST
	return item


func _register_alias_weapon(base_id: String, default_mat: String):
	"""Register a plain-id alias pointing to the default-material weapon."""
	var full_id := default_mat + "_" + base_id
	var src: ItemData = items.get(full_id, null)
	if not src:
		push_error("ItemDatabase: alias source not found: " + full_id)
		return
	var alias := ItemData.new()
	alias.item_id = base_id
	alias.item_name = src.item_name
	alias.description = src.description
	alias.item_type = src.item_type
	alias.material = src.material
	alias.damage_dice = src.damage_dice
	alias.damage_type = src.damage_type
	alias.is_weapon = src.is_weapon
	alias.is_two_handed = src.is_two_handed
	alias.is_ranged = src.is_ranged
	alias.range_normal = src.range_normal
	alias.range_max = src.range_max
	alias.equip_slot = src.equip_slot
	alias.has_durability = src.has_durability
	alias.max_durability = src.max_durability
	alias.special_properties = src.special_properties.duplicate()
	alias.weight = src.weight
	alias.base_value = src.base_value
	register_item(alias)


func _register_alias_armor(base_id: String, default_mat: String):
	"""Register a plain-id alias for the default-material armor."""
	var full_id := default_mat + "_" + base_id
	var src: ItemData = items.get(full_id, null)
	if not src:
		push_error("ItemDatabase: alias source not found: " + full_id)
		return
	var alias := ItemData.new()
	alias.item_id = base_id
	alias.item_name = src.item_name
	alias.description = src.description
	alias.item_type = src.item_type
	alias.material = src.material
	alias.armor_class_bonus = src.armor_class_bonus
	alias.is_armor = src.is_armor
	alias.has_durability = src.has_durability
	alias.max_durability = src.max_durability
	alias.equip_slot = src.equip_slot
	alias.armor_type = src.armor_type
	alias.dex_bonus_limit = src.dex_bonus_limit
	alias.strength_requirement = src.strength_requirement
	alias.stealth_disadvantage = src.stealth_disadvantage
	alias.weight = src.weight
	alias.base_value = src.base_value
	register_item(alias)


func _register_alias_armor_custom(item_id: String, item_name: String, mat_id: String,
		slot: String, ac: int, armor_type: String, dex_limit: int,
		str_req: int, stealth_dis: bool, weight_val: float, value_val: int):
	var mat := get_material(mat_id)
	if not mat:
		push_error("ItemDatabase: material not found for alias: " + mat_id)
		return
	var item := _build_armor_item(item_id, item_name, mat, slot, ac, armor_type,
		dex_limit, str_req, stealth_dis)
	item.weight = weight_val
	item.base_value = value_val
	register_item(item)


func _reg_accessory(item_id: String, item_name: String, equip_slot: String,
		item_type: ItemData.ItemType, stat_bonuses: Dictionary,
		weight: float, base_value: int, description: String):
	var item := ItemData.new()
	item.item_id = item_id
	item.item_name = item_name
	item.item_type = item_type
	item.equip_slot = equip_slot
	item.stat_bonuses = stat_bonuses
	item.weight = weight
	item.base_value = base_value
	item.description = description
	register_item(item)


func _reg_consumable(item_id: String, item_name: String, effect: String,
		power: int, weight: float, base_value: int):
	var item := ItemData.new()
	item.item_id = item_id
	item.item_name = item_name
	item.item_type = ItemData.ItemType.CONSUMABLE
	item.is_consumable = true
	item.consumable_effect = effect
	item.consumable_power = power
	item.stackable = true
	item.max_stack_size = 10
	item.weight = weight
	item.base_value = base_value
	item.description = item_name + " — " + effect
	register_item(item)


func _reg_misc(item_id: String, item_name: String, weight: float,
		base_value: int, description: String):
	var item := ItemData.new()
	item.item_id = item_id
	item.item_name = item_name
	item.item_type = ItemData.ItemType.MISC
	item.weight = weight
	item.base_value = base_value
	item.description = description
	register_item(item)


# =====================================================================
# ITEM REGISTRATION / RETRIEVAL
# =====================================================================

func register_item(item: ItemData):
	"""Register an item in the database"""
	items[item.item_id] = item


func get_item(item_id: String) -> ItemData:
	"""
	Get item by ID. If not in the database but the id matches a generatable
	pattern, rebuilds it deterministically before returning.
	"""
	if items.has(item_id):
		return items[item_id]
	return _try_regenerate(item_id)


func _try_regenerate(item_id: String) -> ItemData:
	"""Attempt to rebuild a generatable item id on demand."""
	# material_<mat_id>
	if item_id.begins_with("material_"):
		var mat_id := item_id.substr(9)
		var mat := get_material(mat_id)
		if mat:
			var item := ItemData.new()
			item.item_id = item_id
			item.item_name = mat.material_name
			item.item_type = ItemData.ItemType.MATERIAL
			item.material = mat
			item.stackable = true
			item.max_stack_size = 20
			item.weight = 0.5
			item.base_value = int(5.0 * TIER_VALUE_MULT[int(mat.tier)])
			item.description = mat.get_tier_name() + " " + mat.get_category_name() + " material."
			register_item(item)
			return item

	# <mat_id>_<base_id>  (weapon or armor)
	for wb in WEAPON_BASES:
		for mat_id in wb["mats"]:
			var try_id: String = str(mat_id) + "_" + str(wb["id"])
			if try_id == item_id:
				# rebuild this one weapon
				var mat: MaterialData = get_material(str(mat_id))
				if mat:
					var tier_idx: int = int(mat.tier)
					var item := ItemData.new()
					item.item_id = item_id
					item.item_name = mat.material_name + " " + str(wb["name"])
					item.item_type = ItemData.ItemType.WEAPON
					item.material = mat
					item.damage_dice = str(wb["dice"])
					item.damage_type = str(wb["dtype"])
					item.is_weapon = true
					item.is_two_handed = bool(wb["2h"])
					item.is_ranged = bool(wb["ranged"])
					item.range_normal = int(wb["rn"])
					item.range_max = int(wb["rm"])
					item.equip_slot = "ranged" if bool(wb["ranged"]) else "main_hand"
					item.has_durability = true
					item.max_durability = mat.base_durability
					for prop in (wb["props"] as Array):
						item.special_properties.append(str(prop))
					item.weight = float(wb["weight"]) * TIER_WEIGHT_MULT[tier_idx]
					item.base_value = int(float(wb["value"]) * TIER_VALUE_MULT[tier_idx])
					register_item(item)
					return item

	for ab in ARMOR_BASES:
		for mat_id in ab["mats"]:
			var try_id: String = str(mat_id) + "_" + str(ab["id"])
			if try_id == item_id:
				var mat: MaterialData = get_material(str(mat_id))
				if mat:
					var tier_idx: int = int(mat.tier)
					var item := _build_armor_item(item_id,
						mat.material_name + " " + str(ab["name"]),
						mat, str(ab["slot"]), int(ab["ac"]) + mat.armor_bonus,
						str(ab["type"]), int(ab["dex"]), int(ab["str"]), bool(ab["stealth"]))
					item.weight = float(ab["weight"]) * TIER_WEIGHT_MULT[tier_idx]
					item.base_value = int(float(ab["value"]) * TIER_VALUE_MULT[tier_idx])
					register_item(item)
					return item

	return null


# =====================================================================
# ITEM INSTANCES
# =====================================================================

func create_item_instance(item_id: String, quality: int = 0, magic: int = 0) -> Dictionary:
	"""Create an item instance with current durability"""
	var item_data := get_item(item_id)
	if not item_data:
		push_error("ItemDatabase: Item not found: " + item_id)
		return {}

	var max_dur: int = item_data.get_calculated_durability()
	if item_data.has_durability and item_data.material:
		max_dur = item_data.material.calculate_item_durability(item_data.max_durability, quality)

	return {
		"item_data": item_data,
		"quality_modifier": quality,
		"magic_modifier": magic,
		"current_durability": max_dur,
		"max_durability": max_dur,
		"stack_count": 1,
		"instance_id": generate_instance_id()
	}


func generate_instance_id() -> String:
	"""Generate unique instance ID"""
	return str(Time.get_unix_time_from_system()) + "_" + str(randi())


# =====================================================================
# CONSUMABLE USE
# =====================================================================

func use_consumable(item_instance: Dictionary, user: Node) -> bool:
	"""
	Apply a consumable's effect to user.
	Emits EventBus.item_used, removes one from the stack via InventoryManager,
	and emits EventBus.player_hp_changed when the user is the player.
	Returns true on success.
	"""
	if item_instance.is_empty():
		push_error("ItemDatabase.use_consumable: empty instance")
		return false

	var item_data: ItemData = item_instance.get("item_data", null)
	if not item_data or not item_data.is_consumable:
		push_error("ItemDatabase.use_consumable: not a consumable")
		return false

	var effect := item_data.consumable_effect
	var power := item_data.consumable_power

	match effect:
		"heal":
			if user and user.get("stats") and user.stats:
				var old_hp: int = user.stats.current_hp
				# Use CharacterStats.heal if available, otherwise direct add
				if user.stats.has_method("heal"):
					user.stats.heal(power)
				else:
					user.stats.current_hp = min(user.stats.current_hp + power, user.stats.max_hp)
				# Emit player_hp_changed when this is the player
				if GameManager.player and user == GameManager.player:
					EventBus.player_hp_changed.emit(user.stats.current_hp, user.stats.max_hp)
				print("ItemDatabase: Healed ", user.name, " for ", power, " HP")
		"cure_poison":
			print("ItemDatabase: Cured poison on ", user.name if user else "?")
			# StatusEffectManager will handle this once wired by orchestrator
		"food_buff":
			print("ItemDatabase: Food buff applied (power ", power, ") to ", user.name if user else "?")
		"elixir":
			_apply_elixir(item_data.item_id, user, power)
		_:
			print("ItemDatabase: Unknown consumable effect: ", effect)

	EventBus.item_used.emit(item_instance, user)
	InventoryManager.remove_item(item_instance.get("instance_id", ""))
	return true


func _apply_elixir(item_id: String, user: Node, power: int):
	"""
	Route elixir consumables to StatusEffectManager (10-turn buffs).
	elixir_strength / elixir_fortitude -> blessed, elixir_agility -> hasted,
	elixir_resist_fire -> shielded; elixir_mana heals `power` HP instead
	(no mana resource exists yet).
	"""
	if user == null or not is_instance_valid(user):
		return

	# Mana elixir: flat restore (heal) until a mana resource exists
	if item_id == "elixir_mana":
		if user.get("stats") and user.stats and user.stats.has_method("heal"):
			user.stats.heal(power)
			if GameManager.player and user == GameManager.player:
				EventBus.player_hp_changed.emit(user.stats.current_hp, user.stats.max_hp)
			print("ItemDatabase: Elixir of Mana invigorates ", user.name, " (+", power, " HP)")
		return

	var effect_map := {
		"elixir_strength":    "blessed",
		"elixir_fortitude":   "blessed",
		"elixir_agility":     "hasted",
		"elixir_resist_fire": "shielded",
	}
	var effect_id: String = effect_map.get(item_id, "")
	if effect_id == "":
		print("ItemDatabase: Unknown elixir: ", item_id)
		return

	if StatusEffectManager.has_method("apply_effect"):
		StatusEffectManager.apply_effect(user, effect_id, 10)
		print("ItemDatabase: ", item_id, " grants '", effect_id, "' (10 turns) to ", user.name)


# =====================================================================
# STARTING KIT
# =====================================================================

func get_starting_kit(class_id: String) -> Array:
	"""
	Returns an Array of item instances from the class's starting_equipment_list
	plus 3 healing potions. Missing ids are skipped with push_error.
	"""
	var class_data = ClassDatabase.get_class_data(class_id)
	if not class_data:
		push_error("ItemDatabase.get_starting_kit: unknown class: " + class_id)
		return []

	var kit: Array = []
	for item_id in class_data.starting_equipment_list:
		var inst := create_item_instance(item_id)
		if inst.is_empty():
			push_error("ItemDatabase.get_starting_kit: missing item id '" + item_id + "' for class " + class_id)
			continue
		kit.append(inst)

	# Always grant 3 minor healing potions
	for _i in range(3):
		var potion := create_item_instance("potion_healing_minor")
		if not potion.is_empty():
			kit.append(potion)

	print("ItemDatabase: Starting kit for '", class_id, "' has ", kit.size(), " items")
	return kit


# =====================================================================
# RANDOM LOOT HELPERS
# =====================================================================

func generate_random_material(tier: MaterialData.Tier = MaterialData.Tier.COMMON) -> MaterialData:
	"""Get a random material of specified tier"""
	var tier_materials := get_materials_by_tier(tier)
	if tier_materials.is_empty():
		return null
	return tier_materials[randi() % tier_materials.size()]


func roll_item_quality() -> int:
	"""Roll for item quality (+0/+1/+2/+3)"""
	var roll := randf()
	if roll < 0.70:
		return 0
	elif roll < 0.90:
		return 1
	elif roll < 0.97:
		return 2
	else:
		return 3


func roll_magic_modifier() -> int:
	"""Roll for magic enhancement (+0/+1/+2/+3)"""
	var roll := randf()
	if roll < 0.85:
		return 0
	elif roll < 0.95:
		return 1
	elif roll < 0.99:
		return 2
	else:
		return 3


func get_random_item_by_type(item_type_str: String, tier: MaterialData.Tier) -> ItemData:
	"""Return a random registered item matching category string and material tier."""
	var candidates: Array = []
	for item in items.values():
		match item_type_str:
			"weapon":
				if item.is_weapon and item.material and item.material.tier == tier:
					candidates.append(item)
			"armor":
				if item.is_armor and item.material and item.material.tier == tier:
					candidates.append(item)
			"material":
				if item.item_type == ItemData.ItemType.MATERIAL and item.material and item.material.tier == tier:
					candidates.append(item)
			"consumable":
				if item.item_type == ItemData.ItemType.CONSUMABLE:
					candidates.append(item)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
