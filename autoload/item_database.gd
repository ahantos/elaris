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

# === MATERIALS ===

func load_materials():
	"""Load all material definitions"""
	# We'll create materials programmatically for now
	# Later these can be loaded from .tres resource files
	
	# METALS
	register_material(create_material(
		"bronze", "Bronze", MaterialData.Category.METAL, MaterialData.Tier.COMMON,
		20, Color(0.8, 0.5, 0.2), 1.0
	))
	
	register_material(create_material(
		"iron", "Iron", MaterialData.Category.METAL, MaterialData.Tier.UNCOMMON,
		40, Color(0.5, 0.5, 0.5), 2.0
	))
	
	register_material(create_material(
		"steel", "Steel", MaterialData.Category.METAL, MaterialData.Tier.RARE,
		70, Color(0.7, 0.7, 0.8), 5.0
	))
	
	register_material(create_material(
		"mithril", "Mithril", MaterialData.Category.METAL, MaterialData.Tier.EPIC,
		100, Color(0.8, 0.9, 1.0), 20.0
	))
	
	register_material(create_material(
		"adamantine", "Adamantine", MaterialData.Category.METAL, MaterialData.Tier.LEGENDARY,
		150, Color(0.3, 0.1, 0.4), 100.0
	))
	
	# LEATHER
	register_material(create_material(
		"hide", "Hide", MaterialData.Category.LEATHER, MaterialData.Tier.COMMON,
		15, Color(0.6, 0.4, 0.2), 0.8
	))
	
	register_material(create_material(
		"leather", "Leather", MaterialData.Category.LEATHER, MaterialData.Tier.UNCOMMON,
		30, Color(0.5, 0.3, 0.2), 1.5
	))
	
	register_material(create_material(
		"scaled_leather", "Scaled Leather", MaterialData.Category.LEATHER, MaterialData.Tier.RARE,
		50, Color(0.3, 0.5, 0.3), 4.0
	))
	
	# CLOTH
	register_material(create_material(
		"linen", "Linen", MaterialData.Category.CLOTH, MaterialData.Tier.COMMON,
		10, Color(0.9, 0.9, 0.8), 0.5
	))
	
	register_material(create_material(
		"silk", "Silk", MaterialData.Category.CLOTH, MaterialData.Tier.RARE,
		40, Color(1.0, 0.9, 0.9), 3.0
	))
	
	print("Loaded ", materials.size(), " materials")

func create_material(id: String, name: String, category: MaterialData.Category, 
					 tier: MaterialData.Tier, durability: int, color: Color, 
					 value_mult: float) -> MaterialData:
	"""Helper to create material data"""
	var mat = MaterialData.new()
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

# === ITEMS ===

func load_items():
	"""Load all item definitions"""
	# For now, items will be created programmatically
	# Later these can be loaded from .tres resource files in res://data/items/
	
	# Example: Create a basic longsword template
	# In full implementation, we'd have hundreds of these
	
	print("Items will be loaded in Phase 2")
	# Placeholder - we'll add items in Phase 2

func register_item(item: ItemData):
	"""Register an item in the database"""
	items[item.item_id] = item

func get_item(item_id: String) -> ItemData:
	"""Get item by ID"""
	return items.get(item_id, null)

func create_item_instance(item_id: String, quality: int = 0, magic: int = 0) -> Dictionary:
	"""Create an item instance with current durability"""
	var item_data = get_item(item_id)
	if not item_data:
		push_error("Item not found: " + item_id)
		return {}
	
	var instance = {
		"item_data": item_data,
		"quality_modifier": quality,
		"magic_modifier": magic,
		"current_durability": item_data.get_calculated_durability(),
		"max_durability": item_data.get_calculated_durability(),
		"instance_id": generate_instance_id()
	}
	
	return instance

func generate_instance_id() -> String:
	"""Generate unique instance ID"""
	return str(Time.get_unix_time_from_system()) + "_" + str(randi())

# === ITEM CREATION HELPERS ===

func create_weapon(weapon_id: String, weapon_name: String, material_id: String, 
				   damage_dice: String, weapon_type: String, two_handed: bool = false) -> ItemData:
	"""Helper to create a weapon"""
	var item = ItemData.new()
	item.item_id = weapon_id
	item.item_name = weapon_name
	item.item_type = ItemData.ItemType.WEAPON
	item.material = get_material(material_id)
	item.damage_dice = damage_dice
	item.weapon_type = weapon_type
	item.is_weapon = true
	item.is_two_handed = two_handed
	item.has_durability = true
	item.equip_slot = "main_hand"
	item.weight = 3.0
	item.base_value = 50
	
	if item.material:
		item.max_durability = item.material.base_durability
	
	return item

func create_armor(armor_id: String, armor_name: String, material_id: String,
				  armor_slot: String, ac_bonus: int) -> ItemData:
	"""Helper to create armor"""
	var item = ItemData.new()
	item.item_id = armor_id
	item.item_name = armor_name
	
	# Determine armor type from slot
	match armor_slot:
		"head": item.item_type = ItemData.ItemType.ARMOR_HEAD
		"chest": item.item_type = ItemData.ItemType.ARMOR_CHEST
		"legs": item.item_type = ItemData.ItemType.ARMOR_LEGS
		"hands": item.item_type = ItemData.ItemType.ARMOR_HANDS
		"feet": item.item_type = ItemData.ItemType.ARMOR_FEET
	
	item.material = get_material(material_id)
	item.armor_class_bonus = ac_bonus
	item.is_armor = true
	item.has_durability = true
	item.equip_slot = armor_slot
	item.weight = 5.0
	item.base_value = 100
	
	if item.material:
		item.max_durability = item.material.base_durability
	
	return item

# === RANDOM LOOT GENERATION ===

func generate_random_material(tier: MaterialData.Tier = MaterialData.Tier.COMMON) -> MaterialData:
	"""Get a random material of specified tier"""
	var tier_materials = get_materials_by_tier(tier)
	if tier_materials.is_empty():
		return null
	return tier_materials[randi() % tier_materials.size()]

func roll_item_quality() -> int:
	"""Roll for item quality (+0/+1/+2/+3)"""
	var roll = randf()
	if roll < 0.70:  # 70% chance
		return 0  # Common
	elif roll < 0.90:  # 20% chance
		return 1  # Uncommon
	elif roll < 0.97:  # 7% chance
		return 2  # Epic
	else:  # 3% chance
		return 3  # Legendary

func roll_magic_modifier() -> int:
	"""Roll for magic enhancement (+0/+1/+2/+3)"""
	var roll = randf()
	if roll < 0.85:  # 85% no magic
		return 0
	elif roll < 0.95:  # 10% +1
		return 1
	elif roll < 0.99:  # 4% +2
		return 2
	else:  # 1% +3
		return 3
