# material_data.gd
# What a weapon or a piece of armour is made of (bronze, steel, oak, cowhide).
# A material sets how the item wears (durability score, notches, hardness), what
# it costs (price multiplier) and one trait. It never changes damage, armour
# class or any other number of the item: two longswords of different metals
# hit alike.
# The values are Ákos's material tables (plan, section 8, "Materials"); the
# registry is ItemDatabase.load_materials().
extends Resource
class_name MaterialData


# Material identity
@export var material_id: String = ""  # "bronze", "steel", "cowhide"
@export var material_name: String = ""  # "Bronze", "Steel", "Cowhide"
@export var description: String = ""

# The kind of material. Repair scrap must be of the same kind as the piece.
enum Category {
	METAL,
	WOOD,
	STONE,
	CLOTH,
	LEATHER,
	EXOTIC
}
@export var category: Category = Category.METAL

# Durability data, read by the durability rules (DurabilityManager)
@export var durability_score: int = 16  # the score in the material tables
@export var hardness: int = 1  # one scale for metal, wood, leather and cloth
@export var notches: int = 2  # what a plain piece of the material has: notches_for(durability_score)

# What an item of this material costs, as a multiple of its base type's price
@export var price_multiplier: float = 1.0

# The material's trait ("rusts_easily", "silvered", "warm"), or "" for a plain
# material. Data only: no trait has an effect yet.
@export var trait_id: String = ""

# Which stage of the game the material belongs to. Stage 1 can drop, be bought
# and be crafted at levels 1 to 5. Stage 0 is defined - an item made of it loads
# and works - but nothing hands it out.
@export var stage: int = 0

# Visual properties
@export var color: Color = Color.WHITE
@export var metallic: bool = false

static func notches_for(score: int) -> int:
	"""The notch count a durability score gives: the score over the notch
	divisor (8), rounded half up, never fewer than the minimum (2). The two
	numbers are dials (DurabilityDials)."""
	return maxi(DurabilityDials.min_notches, int(floor(score / DurabilityDials.notch_divisor + 0.5)))

func is_obtainable() -> bool:
	"""True for a material that loot, shops and recipes may hand out"""
	return stage == 1

func get_kind() -> String:
	"""The material's kind in lower case: metal, wood, leather or cloth"""
	return get_category_name().to_lower()

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

func get_trait_name() -> String:
	"""The trait as the player reads it ("Resists corrosion"), or "" for none"""
	return trait_id.capitalize() if trait_id != "" else ""
