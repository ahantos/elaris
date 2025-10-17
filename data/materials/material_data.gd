# material_data.gd
# Resource defining a crafting material (bronze, steel, leather, etc.)
extends Resource
class_name MaterialData

# Material identity
@export var material_id: String = ""  # Unique ID: "bronze", "steel", "mithril"
@export var material_name: String = ""  # Display name: "Bronze", "Steel"
@export var description: String = ""

# Material tier (affects rarity and base stats)
enum Tier {
	COMMON = 0,      # Bronze, Oak, Linen, Hide
	UNCOMMON = 1,    # Iron, Ash, Cotton, Leather
	RARE = 2,        # Steel, Yew, Silk, Scaled
	EPIC = 3,        # Mithril, Ebony, Spidersilk, Wyvern
	LEGENDARY = 4    # Adamantine, Starwood, Celestial, Dragon
}
@export var tier: Tier = Tier.COMMON

# Material category
enum Category {
	METAL,
	WOOD,
	STONE,
	CLOTH,
	LEATHER,
	EXOTIC
}
@export var category: Category = Category.METAL

# Durability properties
@export var base_durability: int = 20  # Base durability for items made from this material
@export var durability_multiplier: float = 1.0  # Multiplier for quality bonuses

# Visual properties
@export var color: Color = Color.WHITE  # Primary color for this material
@export var color_secondary: Color = Color.GRAY  # Secondary/accent color
@export var metallic: bool = false  # Is this a shiny metal?
@export var texture_pattern: String = ""  # Reference to texture pattern (optional)

# Economic properties
@export var base_value_multiplier: float = 1.0  # Multiplier for item value
@export var rarity_weight: float = 1.0  # Weight in loot tables (lower = rarer)

# Crafting properties
@export var weight_per_unit: float = 1.0  # Weight in pounds per material unit
@export var units_per_item: int = 3  # How many units needed to craft typical item

# Special properties (optional)
@export var damage_bonus: int = 0  # Extra damage for weapons
@export var armor_bonus: int = 0  # Extra AC for armor
@export var special_properties: Array[String] = []  # e.g., ["fire_resist", "lightweight"]

func get_tier_name() -> String:
	"""Get human-readable tier name"""
	match tier:
		Tier.COMMON: return "Common"
		Tier.UNCOMMON: return "Uncommon"
		Tier.RARE: return "Rare"
		Tier.EPIC: return "Epic"
		Tier.LEGENDARY: return "Legendary"
	return "Unknown"

func get_category_name() -> String:
	"""Get human-readable category name"""
	match category:
		Category.METAL: return "Metal"
		Category.WOOD: return "Wood"
		Category.STONE: return "Stone"
		Category.CLOTH: return "Cloth"
		Category.LEATHER: return "Leather"
		Category.EXOTIC: return "Exotic"
	return "Unknown"

func calculate_item_durability(base_item_durability: int, quality_modifier: int) -> int:
	"""Calculate final durability for an item made from this material"""
	var material_durability = base_durability
	var quality_bonus = 1.0 + (quality_modifier * 0.15)  # +15% per quality level
	return int(material_durability * quality_bonus * durability_multiplier)

func calculate_item_value(base_item_value: int, quality_modifier: int, magic_modifier: int) -> int:
	"""Calculate final value for an item made from this material"""
	var value = float(base_item_value) * base_value_multiplier
	
	# Quality increases value
	if quality_modifier > 0:
		value *= (1.0 + quality_modifier * 0.5)  # +50% per quality level
	
	# Magic increases value exponentially
	if magic_modifier > 0:
		value *= pow(10, magic_modifier)  # ×10 per magic level
	
	return int(value)
