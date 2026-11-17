# item_database.gd
# AutoLoad singleton - every material and item definition.
# A weapon or armour item is one base type (longsword, chain mail) made of one
# material (steel, cowhide): the base sets what the item does, the material how
# it wears and what it costs. Ids are "{material_id}_{base_id}".
extends Node

# Databases
var materials: Dictionary = {}  # material_id -> MaterialData
var items: Dictionary = {}  # item_id -> ItemData
# Ids that are a copy of another item under a second id: alias id -> source id
var alias_ids: Dictionary = {}

# Material ids that were renamed when the material list was replaced. A save or
# a piece of content that still uses the old id gets the new material, and so
# the new item: get_material("iron") is wrought iron and get_item("iron_longsword")
# is the wrought iron longsword.
const MATERIAL_ALIASES: Dictionary = {
	"iron": "wrought_iron",
	"mithril": "mythril",
	"adamantine": "adamantite",
	"hide": "pigskin",
	"leather": "cowhide",
	"linen": "fine_linen",
}

# What a plain base id ("longsword", "jerkin") is made of, by the kind of
# material the base takes. Class starting kits use plain ids.
const DEFAULT_MATERIALS: Dictionary = {
	"metal": "wrought_iron",
	"wood": "oak",
	"leather": "cowhide",
	"cloth": "fine_linen",
}

const MATERIAL_ITEM_PREFIX: String = "material_"
# Price of one unit of a crafting material at price multiplier 1
const MATERIAL_ITEM_VALUE: float = 5.0

func _ready():
	print("ItemDatabase initializing...")
	load_materials()
	load_items()
	print("ItemDatabase ready: ", materials.size(), " materials, ", items.size(), " items")


# =====================================================================
# MATERIALS
# =====================================================================

func load_materials():
	"""Register every material. The stage-one rows are Ákos's tables (plan,
	section 8): durability score, hardness, price multiplier and trait. The
	notch count follows from the durability score (MaterialData.notches_for)."""
	var metal := MaterialData.Category.METAL
	var wood := MaterialData.Category.WOOD
	var leather := MaterialData.Category.LEATHER
	var cloth := MaterialData.Category.CLOTH

	# ── STAGE ONE: drops, shops and recipes of levels 1 to 5 ──────────
	#        id                name               kind     score hard price  trait                stage colour
	_reg_mat("copper",         "Copper",          metal,   13, 3, 0.5,   "",                  1, Color(0.80, 0.45, 0.25))
	_reg_mat("wrought_iron",   "Wrought Iron",    metal,   18, 3, 0.7,   "rusts_easily",      1, Color(0.42, 0.42, 0.45))
	_reg_mat("bronze",         "Bronze",          metal,   22, 4, 0.8,   "resists_corrosion", 1, Color(0.80, 0.50, 0.20))
	_reg_mat("steel",          "Steel",           metal,   30, 5, 1.0,   "",                  1, Color(0.70, 0.70, 0.80))
	_reg_mat("silver",         "Silver",          metal,   22, 4, 2.0,   "silvered",          1, Color(0.85, 0.87, 0.90))
	_reg_mat("damascus_steel", "Damascus Steel",  metal,   38, 6, 3.0,   "counts_as_magical", 1, Color(0.45, 0.50, 0.60))

	_reg_mat("pine",           "Pine",            wood,    15, 2, 0.4,   "",                  1, Color(0.80, 0.68, 0.45))
	_reg_mat("oak",            "Oak",             wood,    19, 3, 0.7,   "",                  1, Color(0.55, 0.35, 0.15))
	_reg_mat("ash",            "Ash",             wood,    19, 3, 0.7,   "resists_cracking",  1, Color(0.60, 0.45, 0.30))
	_reg_mat("maple",          "Maple",           wood,    18, 2, 0.6,   "",                  1, Color(0.75, 0.55, 0.35))
	_reg_mat("hickory",        "Hickory",         wood,    20, 4, 0.8,   "resists_cracking",  1, Color(0.50, 0.38, 0.25))
	_reg_mat("ironwood",       "Ironwood",        wood,    30, 5, 5.0,   "",                  1, Color(0.30, 0.24, 0.20))

	_reg_mat("pigskin",        "Pigskin",         leather, 10, 2, 0.3,   "",                  1, Color(0.80, 0.62, 0.50))
	_reg_mat("deerskin",       "Deerskin",        leather, 14, 2, 0.5,   "quiet",             1, Color(0.70, 0.55, 0.38))
	_reg_mat("cowhide",        "Cowhide",         leather, 15, 3, 1.0,   "",                  1, Color(0.50, 0.30, 0.20))
	_reg_mat("boiled_leather", "Boiled Leather",  leather, 16, 3, 0.7,   "",                  1, Color(0.35, 0.22, 0.15))
	_reg_mat("wolfhide",       "Wolfhide",        leather, 15, 3, 0.8,   "warm",              1, Color(0.55, 0.55, 0.60))
	_reg_mat("bearhide",       "Bearhide",        leather, 18, 3, 0.9,   "warm",              1, Color(0.40, 0.28, 0.18))

	_reg_mat("burlap",         "Burlap",          cloth,   6,  1, 0.16,  "noisy",             1, Color(0.70, 0.62, 0.45))
	_reg_mat("roughspun_wool", "Roughspun Wool",  cloth,   8,  1, 0.48,  "warm",              1, Color(0.65, 0.60, 0.55))
	_reg_mat("cotton",         "Cotton",          cloth,   9,  1, 0.6,   "soaks_water",       1, Color(0.95, 0.92, 0.85))
	_reg_mat("wool",           "Wool",            cloth,   11, 2, 0.95,  "warm",              1, Color(0.88, 0.86, 0.80))
	_reg_mat("fine_linen",     "Fine Linen",      cloth,   12, 2, 1.0,   "",                  1, Color(0.90, 0.90, 0.80))
	_reg_mat("silk",           "Silk",            cloth,   15, 2, 12.74, "",                  1, Color(1.00, 0.90, 0.90))

	# ── DEFINED, NOT HANDED OUT: nothing drops, sells or crafts these yet ─
	_reg_mat("mythril",        "Mythril",         metal,   50, 6, 10.0,  "rustproof",         0, Color(0.80, 0.90, 1.00))
	_reg_mat("adamantite",     "Adamantite",      metal,   60, 10, 10.0, "ignores_resistance", 0, Color(0.30, 0.10, 0.40))
	# Materials of the old list with no equivalent in the new one. Items made of
	# them still load; their numbers are placeholders until their stage comes.
	_reg_mat("yew",            "Yew",             wood,    20, 3, 1.5,   "",                  0, Color(0.40, 0.25, 0.10))
	_reg_mat("ebony",          "Ebony",           wood,    26, 4, 4.0,   "",                  0, Color(0.10, 0.08, 0.08))
	_reg_mat("starwood",       "Starwood",        wood,    34, 5, 8.0,   "",                  0, Color(0.60, 0.60, 1.00))
	_reg_mat("scaled_leather", "Scaled Leather",  leather, 20, 3, 2.0,   "",                  0, Color(0.30, 0.50, 0.30))
	_reg_mat("wyvern_leather", "Wyvern Leather",  leather, 26, 4, 6.0,   "",                  0, Color(0.20, 0.45, 0.20))
	_reg_mat("dragon_leather", "Dragon Leather",  leather, 34, 5, 10.0,  "",                  0, Color(0.60, 0.15, 0.10))
	_reg_mat("spidersilk",     "Spidersilk",      cloth,   18, 2, 8.0,   "",                  0, Color(0.70, 0.70, 0.90))
	_reg_mat("celestial_cloth","Celestial Cloth", cloth,   24, 3, 15.0,  "",                  0, Color(0.90, 0.80, 1.00))

	print("ItemDatabase: Loaded ", materials.size(), " materials")


func _reg_mat(id: String, material_name: String, category: MaterialData.Category,
		durability_score: int, hardness: int, price_multiplier: float,
		trait_id: String, stage: int, color: Color):
	"""Create and register one material"""
	var mat := MaterialData.new()
	mat.material_id = id
	mat.material_name = material_name
	mat.category = category
	mat.durability_score = durability_score
	mat.hardness = hardness
	mat.notches = MaterialData.notches_for(durability_score)
	mat.price_multiplier = price_multiplier
	mat.trait_id = trait_id
	mat.stage = stage
	mat.color = color
	mat.metallic = category == MaterialData.Category.METAL
	materials[id] = mat


func register_material(material: MaterialData):
	"""Register a material in the database"""
	materials[material.material_id] = material


func get_material(material_id: String) -> MaterialData:
	"""A material by id. A renamed id (MATERIAL_ALIASES) gives the material it
	became."""
	return materials.get(MATERIAL_ALIASES.get(material_id, material_id), null)


func get_materials_by_category(category: MaterialData.Category) -> Array:
	"""Every material of one kind, in the order they were registered"""
	var result = []
	for mat in materials.values():
		if mat.category == category:
			result.append(mat)
	return result


func get_obtainable_materials() -> Array:
	"""The materials loot, shops and recipes may hand out: stage one"""
	var result = []
	for mat in materials.values():
		if mat.is_obtainable():
			result.append(mat)
	return result


# =====================================================================
# ITEM CATALOG
# =====================================================================

# Weapon base definitions, following the 5e SRD weapon table:
# { id, name, cat ("simple" | "martial"), dice, dtype, 2h, ranged, rn, rm,
#   weight, value, props, kind }
# A weapon with the "versatile" property also gives "vdice": its damage dice
# when it is held in both hands. "rn" and "rm" are a ranged weapon's normal and
# maximum range in tiles of 5 feet (a shortbow's 80 and 320 feet are 16 and 64).
# "kind" is the kind of material the weapon is made of; "value" is its price in
# a material of price multiplier 1.
const WEAPON_BASES := [
	# ── MELEE ────────────────────────────────────────────────────────
	{
		"id": "dagger",        "name": "Dagger",        "cat": "simple",  "dice": "1d4",  "dtype": "piercing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 1.0, "value": 20,
		"props": ["finesse", "thrown"], "kind": "metal"
	},
	{
		"id": "shortsword",    "name": "Shortsword",    "cat": "martial", "dice": "1d6",  "dtype": "piercing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 2.0, "value": 40,
		"props": ["finesse"], "kind": "metal"
	},
	{
		"id": "longsword",     "name": "Longsword",     "cat": "martial", "dice": "1d8",  "dtype": "slashing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 3.0, "value": 60,
		"props": ["versatile"], "vdice": "1d10", "kind": "metal"
	},
	{
		"id": "greatsword",    "name": "Greatsword",    "cat": "martial", "dice": "2d6",  "dtype": "slashing",
		"2h": true,  "ranged": false, "rn": 0, "rm": 0,
		"weight": 6.0, "value": 80,
		"props": [], "kind": "metal"
	},
	{
		"id": "handaxe",       "name": "Handaxe",       "cat": "simple",  "dice": "1d6",  "dtype": "slashing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 2.0, "value": 30,
		"props": ["thrown"], "kind": "metal"
	},
	{
		"id": "battleaxe",     "name": "Battleaxe",     "cat": "martial", "dice": "1d8",  "dtype": "slashing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 4.0, "value": 60,
		"props": ["versatile"], "vdice": "1d10", "kind": "metal"
	},
	{
		"id": "greataxe",      "name": "Greataxe",      "cat": "martial", "dice": "1d12", "dtype": "slashing",
		"2h": true,  "ranged": false, "rn": 0, "rm": 0,
		"weight": 7.0, "value": 90,
		"props": [], "kind": "metal"
	},
	{
		"id": "mace",          "name": "Mace",          "cat": "simple",  "dice": "1d6",  "dtype": "bludgeoning",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 4.0, "value": 50,
		"props": [], "kind": "metal"
	},
	{
		"id": "warhammer",     "name": "Warhammer",     "cat": "martial", "dice": "1d8",  "dtype": "bludgeoning",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 5.0, "value": 70,
		"props": ["versatile"], "vdice": "1d10", "kind": "metal"
	},
	{
		"id": "spear",         "name": "Spear",         "cat": "simple",  "dice": "1d6",  "dtype": "piercing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 3.0, "value": 30,
		"props": ["thrown", "versatile"], "vdice": "1d8", "kind": "metal"
	},
	{
		"id": "rapier",        "name": "Rapier",        "cat": "martial", "dice": "1d8",  "dtype": "piercing",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 2.0, "value": 55,
		"props": ["finesse"], "kind": "metal"
	},
	# ── WOOD MELEE ───────────────────────────────────────────────────
	{
		"id": "quarterstaff",  "name": "Quarterstaff",  "cat": "simple",  "dice": "1d6",  "dtype": "bludgeoning",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 4.0, "value": 20,
		"props": ["versatile"], "vdice": "1d8", "kind": "wood"
	},
	{
		"id": "club",          "name": "Club",          "cat": "simple",  "dice": "1d4",  "dtype": "bludgeoning",
		"2h": false, "ranged": false, "rn": 0, "rm": 0,
		"weight": 2.0, "value": 10,
		"props": [], "kind": "wood"
	},
	# ── RANGED ───────────────────────────────────────────────────────
	{
		"id": "shortbow",      "name": "Shortbow",      "cat": "simple",  "dice": "1d6",  "dtype": "piercing",
		"2h": true,  "ranged": true,  "rn": 16, "rm": 64,
		"weight": 2.0, "value": 40,
		"props": [], "kind": "wood"
	},
	{
		"id": "longbow",       "name": "Longbow",       "cat": "martial", "dice": "1d8",  "dtype": "piercing",
		"2h": true,  "ranged": true,  "rn": 30, "rm": 120,
		"weight": 2.0, "value": 70,
		"props": [], "kind": "wood"
	},
	{
		"id": "light_crossbow","name": "Light Crossbow","cat": "simple",  "dice": "1d8",  "dtype": "piercing",
		"2h": true,  "ranged": true,  "rn": 16, "rm": 64,
		"weight": 5.0, "value": 60,
		"props": [], "kind": "wood"
	},
	{
		"id": "heavy_crossbow","name": "Heavy Crossbow","cat": "martial", "dice": "1d10", "dtype": "piercing",
		"2h": true,  "ranged": true,  "rn": 20, "rm": 80,
		"weight": 8.0, "value": 100,
		"props": [], "kind": "wood"
	},
]

# Armour base definitions:
# { id, name, slot, armor, base, bonus, dex, str, stealth, weight, value, kind }
# Armour class comes from the body armour (the chest slot) and the shield alone,
# as in 5e:
#   "armor"  the category a class is proficient with: "light", "medium" or
#            "heavy" for body armour, "shield" for a shield, "" for a piece that
#            is not armour in the rules' sense (clothes, and every other slot)
#   "base"   the armour class a body armour sets (leather 11, plate 18); 0 for
#            everything else. A robe is clothing: its wearer is unarmoured.
#   "bonus"  what a shield adds
#   "dex"    how much of the Dexterity modifier the body armour lets through:
#            -1 all of it (light), 2 (medium), 0 none (heavy)
#   "str"    the Strength a heavy armour needs; below it the wearer is slower
# Helmets, gauntlets, greaves, boots and the cloth and leather pieces for the
# same slots give no armour class. They wear like everything else, and their
# own job comes in a later phase.
const ARMOR_BASES := [
	# ── METAL ARMOR ──────────────────────────────────────────────────
	{
		"id": "helmet",       "name": "Helmet",      "slot": "head",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 3.0, "value": 50, "kind": "metal"
	},
	{
		"id": "chestplate",   "name": "Chestplate",  "slot": "chest",
		"armor": "heavy", "base": 18, "bonus": 0, "dex": 0,  "str": 15, "stealth": true,
		"weight": 15.0, "value": 200, "kind": "metal"
	},
	{
		"id": "chain_mail",   "name": "Chain Mail",  "slot": "chest",
		"armor": "heavy", "base": 16, "bonus": 0, "dex": 0,  "str": 13, "stealth": true,
		"weight": 12.0, "value": 120, "kind": "metal"
	},
	{
		"id": "scale_mail",   "name": "Scale Mail",  "slot": "chest",
		"armor": "medium", "base": 14, "bonus": 0, "dex": 2,  "str": 0,  "stealth": true,
		"weight": 11.0, "value": 110, "kind": "metal"
	},
	{
		"id": "gauntlets",    "name": "Gauntlets",   "slot": "hands",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 3.0, "value": 40, "kind": "metal"
	},
	{
		"id": "greaves",      "name": "Greaves",     "slot": "legs",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 5.0, "value": 70, "kind": "metal"
	},
	{
		"id": "plate_boots",  "name": "Plate Boots", "slot": "feet",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 3.0, "value": 50, "kind": "metal"
	},
	{
		"id": "shield",       "name": "Shield",      "slot": "off_hand",
		"armor": "shield", "base": 0, "bonus": 2, "dex": -1, "str": 0,  "stealth": false,
		"weight": 6.0, "value": 40, "kind": "metal"
	},
	# ── LEATHER ARMOR ────────────────────────────────────────────────
	{
		"id": "leather_cap",  "name": "Leather Cap", "slot": "head",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 1.0, "value": 20, "kind": "leather"
	},
	{
		"id": "jerkin",       "name": "Jerkin",      "slot": "chest",
		"armor": "light", "base": 11, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 8.0, "value": 80, "kind": "leather"
	},
	{
		"id": "gloves",       "name": "Gloves",      "slot": "hands",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 0.5, "value": 15, "kind": "leather"
	},
	{
		"id": "leggings",     "name": "Leggings",    "slot": "legs",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 3.0, "value": 40, "kind": "leather"
	},
	{
		"id": "boots",        "name": "Boots",       "slot": "feet",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 1.0, "value": 20, "kind": "leather"
	},
	# ── CLOTH ARMOR ──────────────────────────────────────────────────
	{
		"id": "hood",         "name": "Hood",        "slot": "head",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 0.5, "value": 10, "kind": "cloth"
	},
	{
		"id": "robe",         "name": "Robe",        "slot": "chest",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 4.0, "value": 30, "kind": "cloth"
	},
	{
		"id": "wraps",        "name": "Wraps",       "slot": "hands",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 0.5, "value": 8, "kind": "cloth"
	},
	{
		"id": "pants",        "name": "Pants",       "slot": "legs",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 1.5, "value": 12, "kind": "cloth"
	},
	{
		"id": "slippers",     "name": "Slippers",    "slot": "feet",
		"armor": "", "base": 0, "bonus": 0, "dex": -1, "str": 0,  "stealth": false,
		"weight": 0.5, "value": 8, "kind": "cloth"
	},
]


func load_items():
	"""Generate the full item catalog programmatically"""

	# ── 1. WEAPONS and 2. ARMOR: every base in every material of its kind ──
	for wb in WEAPON_BASES:
		for mat in _materials_of_kind(str(wb["kind"])):
			register_item(_build_weapon_item(wb, mat))
	for ab in ARMOR_BASES:
		for mat in _materials_of_kind(str(ab["kind"])):
			register_item(_build_armor_item(ab, mat))

	# ── 3. PLAIN-BASE ALIASES (default-material versions) ────────────
	for wb in WEAPON_BASES:
		_register_alias(str(wb["id"]), DEFAULT_MATERIALS[str(wb["kind"])] + "_" + str(wb["id"]))
	for ab in ARMOR_BASES:
		_register_alias(str(ab["id"]), DEFAULT_MATERIALS[str(ab["kind"])] + "_" + str(ab["id"]))

	# The rogue's starting kit calls its jerkin by the 5e name
	_register_alias("leather_armor", DEFAULT_MATERIALS["leather"] + "_jerkin", "Leather Armor")

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
	for mat in materials.values():
		register_item(_build_material_item(mat))

	print("ItemDatabase: Loaded ", items.size(), " items")


# ── Build helpers ─────────────────────────────────────────────────────

func _materials_of_kind(kind: String) -> Array:
	"""Every material of a kind ("metal", "wood", "leather", "cloth")"""
	var result: Array = []
	for mat in materials.values():
		if mat.get_kind() == kind:
			result.append(mat)
	return result


func _price(base_value: float, mat: MaterialData) -> int:
	"""What an item costs in a material: the base type's price times the
	material's price multiplier, never less than one coin"""
	return maxi(1, int(round(base_value * mat.price_multiplier)))


func _build_weapon_item(wb: Dictionary, mat: MaterialData) -> ItemData:
	"""One weapon of the catalogue: a row of WEAPON_BASES made from a material.
	The material sets the price and the durability data, nothing else."""
	var item := ItemData.new()
	item.item_id = mat.material_id + "_" + str(wb["id"])
	item.item_name = mat.material_name + " " + str(wb["name"])
	item.item_type = ItemData.ItemType.WEAPON
	item.material = mat
	item.damage_dice = str(wb["dice"])
	item.versatile_dice = str(wb.get("vdice", ""))
	item.damage_type = str(wb["dtype"])
	item.is_weapon = true
	item.weapon_type = str(wb["id"])
	item.weapon_category = str(wb["cat"])
	item.is_two_handed = bool(wb["2h"])
	item.is_ranged = bool(wb["ranged"])
	item.range_normal = int(wb["rn"])
	item.range_max = int(wb["rm"])
	item.equip_slot = "main_hand"
	item.has_durability = true
	item.max_durability = mat.durability_score
	for prop in (wb["props"] as Array):
		item.special_properties.append(str(prop))
	item.weight = float(wb["weight"])
	item.base_value = _price(float(wb["value"]), mat)
	item.description = "%s of %s." % [str(wb["name"]), mat.material_name.to_lower()]
	return item


func _build_armor_item(ab: Dictionary, mat: MaterialData) -> ItemData:
	"""One armour piece of the catalogue: a row of ARMOR_BASES made from a
	material. The material sets the price and the durability data, nothing else."""
	var slot: String = str(ab["slot"])
	var item := ItemData.new()
	item.item_id = mat.material_id + "_" + str(ab["id"])
	item.item_name = mat.material_name + " " + str(ab["name"])
	item.material = mat
	item.is_armor = true
	item.equip_slot = slot
	item.armor_type = str(ab["armor"])
	item.armor_base = int(ab["base"])
	item.armor_class_bonus = int(ab["bonus"])
	item.dex_bonus_limit = int(ab["dex"])
	item.strength_requirement = int(ab["str"])
	item.stealth_disadvantage = bool(ab["stealth"])
	item.has_durability = true
	item.max_durability = mat.durability_score
	item.weight = float(ab["weight"])
	item.base_value = _price(float(ab["value"]), mat)
	item.description = "%s of %s." % [str(ab["name"]), mat.material_name.to_lower()]

	match slot:
		"head":     item.item_type = ItemData.ItemType.ARMOR_HEAD
		"chest":    item.item_type = ItemData.ItemType.ARMOR_CHEST
		"legs":     item.item_type = ItemData.ItemType.ARMOR_LEGS
		"hands":    item.item_type = ItemData.ItemType.ARMOR_HANDS
		"feet":     item.item_type = ItemData.ItemType.ARMOR_FEET
		"off_hand": item.item_type = ItemData.ItemType.SHIELD
		_:          item.item_type = ItemData.ItemType.ARMOR_CHEST
	return item


func _build_material_item(mat: MaterialData) -> ItemData:
	"""A unit of a crafting material as an item: material_<material id>"""
	var item := ItemData.new()
	item.item_id = MATERIAL_ITEM_PREFIX + mat.material_id
	item.item_name = mat.material_name
	item.item_type = ItemData.ItemType.MATERIAL
	item.material = mat
	item.stackable = true
	item.max_stack_size = 20
	item.weight = 0.5
	item.base_value = _price(MATERIAL_ITEM_VALUE, mat)
	item.description = mat.get_category_name() + " for crafting and repairs."
	return item


func _register_alias(alias_id: String, source_id: String, alias_name: String = ""):
	"""Register a copy of an item under another id: a plain base id for the
	default-material version ("longsword"), or a second name for one item."""
	var source: ItemData = items.get(source_id, null)
	if source == null:
		push_error("ItemDatabase: alias source not found: " + source_id)
		return
	var alias: ItemData = source.duplicate()
	alias.item_id = alias_id
	if alias_name != "":
		alias.item_name = alias_name
	alias_ids[alias_id] = source_id
	register_item(alias)


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
	"""Register an item in the database. An item without an icon of its own gets
	the one ArtLibrary maps to its id (data/art/art_manifest.gd)."""
	if item.icon == null:
		item.icon = ArtLibrary.item_icon(item.item_id)
	items[item.item_id] = item


func get_item(item_id: String) -> ItemData:
	"""An item by id, or null. An id that is not registered is rebuilt when it
	follows a generated pattern, and an id written with a renamed material
	("iron_longsword") gives the item it became - so saves and content written
	before the material list changed still resolve."""
	if items.has(item_id):
		return items[item_id]
	var rebuilt: ItemData = _try_regenerate(item_id)
	if rebuilt != null:
		return rebuilt
	var renamed: String = _renamed_item_id(item_id)
	if renamed != item_id:
		return get_item(renamed)
	return null


func canonical_item_id(item_id: String) -> String:
	"""The id the database knows an item by: the id itself, or, for an id
	written with a renamed material, the id of the item it became. "" for an
	id that names nothing."""
	var item: ItemData = get_item(item_id)
	return item.item_id if item != null else ""


func _renamed_item_id(item_id: String) -> String:
	"""An item id with a renamed material in it, rewritten with the new
	material: "iron_longsword" -> "wrought_iron_longsword", "material_hide" ->
	"material_pigskin". The id itself when no renamed material is in it."""
	if item_id.begins_with(MATERIAL_ITEM_PREFIX):
		var mat_id: String = item_id.substr(MATERIAL_ITEM_PREFIX.length())
		if MATERIAL_ALIASES.has(mat_id):
			return MATERIAL_ITEM_PREFIX + str(MATERIAL_ALIASES[mat_id])
		return item_id
	for old_id in MATERIAL_ALIASES:
		if item_id.begins_with(str(old_id) + "_"):
			return str(MATERIAL_ALIASES[old_id]) + item_id.substr(str(old_id).length())
	return item_id


func _try_regenerate(item_id: String) -> ItemData:
	"""Rebuild a generated item id on demand: material_<material id>, or
	<material id>_<base id> for a weapon or armour base in a material of its
	kind. null when the id follows neither pattern."""
	if item_id.begins_with(MATERIAL_ITEM_PREFIX):
		var mat: MaterialData = materials.get(item_id.substr(MATERIAL_ITEM_PREFIX.length()), null)
		if mat != null:
			var item := _build_material_item(mat)
			register_item(item)
			return item
		return null

	for wb in WEAPON_BASES:
		for mat in _materials_of_kind(str(wb["kind"])):
			if mat.material_id + "_" + str(wb["id"]) == item_id:
				var item := _build_weapon_item(wb, mat)
				register_item(item)
				return item
	for ab in ARMOR_BASES:
		for mat in _materials_of_kind(str(ab["kind"])):
			if mat.material_id + "_" + str(ab["id"]) == item_id:
				var item := _build_armor_item(ab, mat)
				register_item(item)
				return item
	return null


# =====================================================================
# ITEM INSTANCES
# =====================================================================

func create_item_instance(item_id: String, quality: int = 0, magic: int = 0) -> Dictionary:
	"""An item instance: the item's data with what belongs to this one piece -
	its craftsmanship (quality_modifier) and magic (magic_modifier) bonuses, its
	charges or condition, its stack count and an id of its own."""
	var item_data := get_item(item_id)
	if not item_data:
		push_error("ItemDatabase: Item not found: " + item_id)
		return {}

	var max_dur: int = item_data.max_durability if item_data.has_durability else 0
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


func get_instance_bonus(item_instance: Dictionary) -> int:
	"""The bonus one piece carries from how it was made or enchanted: the higher
	of its craftsmanship (quality_modifier) and its magic (magic_modifier). A
	weapon adds it to its attack rolls; body armour and a shield add it to
	armour class. The two do not stack."""
	return maxi(0, maxi(int(item_instance.get("quality_modifier", 0)), int(item_instance.get("magic_modifier", 0))))


func get_instance_magic_bonus(item_instance: Dictionary) -> int:
	"""The magic bonus of one piece: what a weapon adds to its damage"""
	return maxi(0, int(item_instance.get("magic_modifier", 0)))


func get_instance_name(item_instance: Dictionary) -> String:
	"""What to call one piece: its item's name, with its bonus when it has one
	("Steel Longsword +1")"""
	var item_data = item_instance.get("item_data")
	if not (item_data is ItemData):
		return ""
	var bonus: int = get_instance_bonus(item_instance)
	return item_data.item_name if bonus <= 0 else "%s +%d" % [item_data.item_name, bonus]


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
	elixir_resist_fire -> fire_resistance; elixir_mana heals `power` HP instead
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
		"elixir_resist_fire": "fire_resistance",
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


func get_loot_candidates(item_type_str: String) -> Array:
	"""Every item a loot roll for a category ("weapon", "armor", "material",
	"consumable") may hand out. Weapons, armour and crafting materials only in
	a material that can be obtained (MaterialData.is_obtainable); the plain-id
	copies of the default-material versions are left out, so that no item is
	in the list twice."""
	var candidates: Array = []
	for item in items.values():
		if alias_ids.has(item.item_id):
			continue
		var obtainable: bool = item.material != null and item.material.is_obtainable()
		match item_type_str:
			"weapon":
				if item.is_weapon and obtainable:
					candidates.append(item)
			"armor":
				if item.is_armor and obtainable:
					candidates.append(item)
			"material":
				if item.item_type == ItemData.ItemType.MATERIAL and obtainable:
					candidates.append(item)
			"consumable":
				if item.item_type == ItemData.ItemType.CONSUMABLE:
					candidates.append(item)
	return candidates


func get_random_item_by_type(item_type_str: String) -> ItemData:
	"""A random item of a loot category. A dearer material turns up less often:
	each item's weight is one over its material's price multiplier, so copper is
	found twice as often as steel and steel three times as often as Damascus
	steel. null when the category holds nothing."""
	var candidates: Array = get_loot_candidates(item_type_str)
	if candidates.is_empty():
		return null
	var total := 0.0
	var weights: Array = []
	for item in candidates:
		var weight: float = 1.0
		if item.material != null:
			weight = 1.0 / maxf(0.01, item.material.price_multiplier)
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for i in range(candidates.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[-1]
