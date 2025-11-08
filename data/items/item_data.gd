# item_data.gd
# Base resource for all items in the game
extends Resource
class_name ItemData

# Item identity
@export var item_id: String = ""  # Unique ID: "sword_longsword_steel_001"
@export var item_name: String = ""  # Display name: "Steel Longsword"
@export var description: String = ""
@export var icon: Texture2D  # Inventory icon (48x48)

# Item type
enum ItemType {
	WEAPON,
	ARMOR_HEAD,
	ARMOR_CHEST,
	ARMOR_LEGS,
	ARMOR_HANDS,
	ARMOR_FEET,
	SHIELD,
	ACCESSORY_NECK,
	ACCESSORY_RING,
	ACCESSORY_CLOAK,
	ACCESSORY_BELT,
	CONSUMABLE,
	MATERIAL,
	QUEST_ITEM,
	CURRENCY,  # For coins and gems - ADDED THIS LINE
	MISC
}
@export var item_type: ItemType = ItemType.MISC

# Material and quality
@export var material: MaterialData  # What material is this made from?
@export var quality_modifier: int = 0  # +0, +1, +2, +3 (craftsmanship)
@export var magic_modifier: int = 0  # +0, +1, +2, +3 (enchantment)

# Durability (only for equipment)
@export var has_durability: bool = false
@export var max_durability: int = 0  # Calculated from material + quality
@export var durability_loss_per_damage: int = 20  # Weapons: 1 dur per X damage dealt
@export var can_break_permanently: bool = true

# Physical properties
@export var weight: float = 1.0  # Weight in pounds
@export var stackable: bool = false
@export var max_stack_size: int = 1

# Economic properties
@export var base_value: int = 10  # Base gold value
@export var can_sell: bool = true
@export var can_drop: bool = true

# Equipment stats (if applicable)
@export_group("Equipment Stats")
@export var equip_slot: String = ""  # "main_hand", "head", "chest", etc.
@export var armor_class_bonus: int = 0  # AC bonus for armor
@export var damage_dice: String = ""  # "1d8" for weapons
@export var damage_type: String = ""  # "slashing", "piercing", "bludgeoning"
@export var stat_bonuses: Dictionary = {}  # {"str": 2, "dex": -1, etc.}
@export var special_properties: Array[String] = []  # ["finesse", "reach", "thrown"]

# Weapon properties
@export var is_weapon: bool = false
@export var weapon_type: String = ""  # "longsword", "bow", "dagger"
@export var is_two_handed: bool = false
@export var is_ranged: bool = false
@export var range_normal: int = 0
@export var range_max: int = 0

# Armor properties
@export var is_armor: bool = false
@export var armor_type: String = ""  # "light", "medium", "heavy"
@export var dex_bonus_limit: int = -1  # -1 = unlimited, 2 = max +2 DEX for medium armor
@export var strength_requirement: int = 0
@export var stealth_disadvantage: bool = false

# Consumable properties
@export var is_consumable: bool = false
@export var consumable_effect: String = ""  # "heal", "restore_mana", etc.
@export var consumable_power: int = 0  # Amount healed, damage dealt, etc.

# Visual properties (for paper doll)
@export_group("Visual")
@export var sprite_layer: String = ""  # Which layer this renders on
@export var sprite_texture: Texture2D  # Sprite for character (48x48)
@export var sprite_offset: Vector2 = Vector2.ZERO

# Magical properties
@export_group("Magic Properties")
@export var is_magical: bool = false
@export var enchantment_name: String = ""  # "of Fire", "of Dragon Slaying"
@export var enchantment_description: String = ""
@export var magical_effects: Array[String] = []  # ["fire_damage_1d6", "fire_resist"]

# Rarity (calculated from quality + magic)
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

func get_rarity() -> Rarity:
	"""Calculate rarity based on quality and magic"""
	if magic_modifier >= 3:
		return Rarity.LEGENDARY
	elif magic_modifier >= 2 or quality_modifier >= 3:
		return Rarity.EPIC
	elif magic_modifier >= 1 or quality_modifier >= 2:
		return Rarity.RARE
	elif quality_modifier >= 1:
		return Rarity.UNCOMMON
	else:
		return Rarity.COMMON

func get_rarity_color() -> Color:
	"""Get color for rarity display"""
	match get_rarity():
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
	return Color.WHITE

func get_full_name() -> String:
	"""Get full display name with quality and enchantments"""
	var full_name = ""
	
	# Material prefix
	if material:
		full_name = material.material_name + " "
	
	# Base name
	full_name += item_name
	
	# Quality suffix
	if quality_modifier > 0:
		full_name += " +" + str(quality_modifier)
	
	# Magic suffix
	if is_magical and magic_modifier > 0:
		full_name += " +" + str(magic_modifier)
		if enchantment_name != "":
			full_name += " " + enchantment_name
	
	return full_name

func get_calculated_value() -> int:
	"""Get final gold value"""
	if material:
		return material.calculate_item_value(base_value, quality_modifier, magic_modifier)
	
	var value = base_value
	if quality_modifier > 0:
		value = int(value * (1.0 + quality_modifier * 0.5))
	if magic_modifier > 0:
		value = int(value * pow(10, magic_modifier))
	return value

func get_calculated_durability() -> int:
	"""Get final max durability"""
	if not has_durability:
		return 0
	
	if material:
		return material.calculate_item_durability(max_durability, quality_modifier)
	
	var durability = max_durability
	if quality_modifier > 0:
		durability = int(durability * (1.0 + quality_modifier * 0.15))
	if magic_modifier > 0:
		durability = int(durability * (1.0 + magic_modifier * 0.25))
	return durability

func get_tooltip_text() -> String:
	"""Generate tooltip text for UI"""
	var tooltip = "[b]" + get_full_name() + "[/b]\n"
	
	# Rarity
	var rarity_name = ""
	match get_rarity():
		Rarity.COMMON: rarity_name = "Common"
		Rarity.UNCOMMON: rarity_name = "Uncommon"
		Rarity.RARE: rarity_name = "Rare"
		Rarity.EPIC: rarity_name = "Epic"
		Rarity.LEGENDARY: rarity_name = "Legendary"
	tooltip += "[color=#808080]" + rarity_name + " " + get_type_name() + "[/color]\n\n"
	
	# Weapon stats
	if is_weapon and damage_dice != "":
		tooltip += "Damage: " + damage_dice + " " + damage_type + "\n"
	
	# Armor stats
	if is_armor and armor_class_bonus > 0:
		tooltip += "Armor Class: +" + str(armor_class_bonus) + "\n"
	
	# Durability
	if has_durability:
		tooltip += "Durability: " + str(get_calculated_durability()) + "\n"
	
	# Weight
	tooltip += "Weight: " + str(weight) + " lb\n"
	
	# Value
	tooltip += "Value: " + str(get_calculated_value()) + " gold\n"
	
	# Description
	if description != "":
		tooltip += "\n[i]" + description + "[/i]"
	
	return tooltip

func get_type_name() -> String:
	"""Get human-readable type name"""
	match item_type:
		ItemType.WEAPON: return "Weapon"
		ItemType.ARMOR_HEAD: return "Head Armor"
		ItemType.ARMOR_CHEST: return "Chest Armor"
		ItemType.ARMOR_LEGS: return "Leg Armor"
		ItemType.ARMOR_HANDS: return "Hand Armor"
		ItemType.ARMOR_FEET: return "Foot Armor"
		ItemType.SHIELD: return "Shield"
		ItemType.ACCESSORY_NECK: return "Necklace"
		ItemType.ACCESSORY_RING: return "Ring"
		ItemType.ACCESSORY_CLOAK: return "Cloak"
		ItemType.ACCESSORY_BELT: return "Belt"
		ItemType.CONSUMABLE: return "Consumable"
		ItemType.MATERIAL: return "Material"
		ItemType.QUEST_ITEM: return "Quest Item"
		ItemType.CURRENCY: return "Currency"  # ADDED THIS LINE
		ItemType.MISC: return "Misc"
	return "Unknown"
