# test_inventory_setup.gd
# Script to populate ItemDatabase with test items and add them to inventory
# Attach to an AutoLoad or call from World._ready()
extends Node

func _ready():
	print("=== TEST INVENTORY SETUP ===")
	# Wait for ItemDatabase to initialize
	await get_tree().process_frame
	
	create_all_test_items()
	print("Test items created in ItemDatabase")

func create_all_test_items():
	"""Create all test weapons, armor, and consumables"""
	create_weapons()
	create_armor()
	create_accessories()
	create_consumables()
	create_misc_items()

# === WEAPONS ===

func create_weapons():
	"""Create test weapons of various types and materials"""
	
	# SWORDS - One-handed
	var bronze_sword = ItemDatabase.create_weapon(
		"sword_short_bronze", "Bronze Shortsword", "bronze",
		"1d6", "slashing", false
	)
	bronze_sword.equip_slot = "right_weapon"
	bronze_sword.weight = 2.0
	bronze_sword.base_value = 10
	ItemDatabase.register_item(bronze_sword)
	
	var iron_longsword = ItemDatabase.create_weapon(
		"sword_long_iron", "Iron Longsword", "iron",
		"1d8", "slashing", false
	)
	iron_longsword.equip_slot = "right_weapon"
	iron_longsword.weight = 3.0
	iron_longsword.base_value = 50
	ItemDatabase.register_item(iron_longsword)
	
	var steel_longsword = ItemDatabase.create_weapon(
		"sword_long_steel", "Steel Longsword", "steel",
		"1d8", "slashing", false
	)
	steel_longsword.equip_slot = "right_weapon"
	steel_longsword.weight = 3.0
	steel_longsword.base_value = 150
	steel_longsword.description = "A well-crafted blade of tempered steel."
	ItemDatabase.register_item(steel_longsword)
	
	# SWORDS - Two-handed
	var greatsword = ItemDatabase.create_weapon(
		"sword_great_steel", "Steel Greatsword", "steel",
		"2d6", "slashing", true
	)
	greatsword.equip_slot = "right_weapon"
	greatsword.weight = 6.0
	greatsword.base_value = 250
	greatsword.description = "A massive two-handed blade."
	ItemDatabase.register_item(greatsword)
	
	# DAGGERS - Light weapons
	var dagger = ItemDatabase.create_weapon(
		"dagger_iron", "Iron Dagger", "iron",
		"1d4", "piercing", false
	)
	dagger.equip_slot = "right_weapon"
	dagger.weight = 1.0
	dagger.base_value = 20
	dagger.special_properties = ["finesse", "light", "thrown"]
	dagger.range_normal = 20
	dagger.range_max = 60
	ItemDatabase.register_item(dagger)
	
	# AXES
	var handaxe = ItemDatabase.create_weapon(
		"axe_hand_iron", "Iron Handaxe", "iron",
		"1d6", "slashing", false
	)
	handaxe.equip_slot = "right_weapon"
	handaxe.weight = 2.0
	handaxe.base_value = 30
	handaxe.special_properties = ["light", "thrown"]
	ItemDatabase.register_item(handaxe)
	
	var battleaxe = ItemDatabase.create_weapon(
		"axe_battle_steel", "Steel Battleaxe", "steel",
		"1d8", "slashing", false
	)
	battleaxe.equip_slot = "right_weapon"
	battleaxe.weight = 4.0
	battleaxe.base_value = 100
	ItemDatabase.register_item(battleaxe)
	
	# MACES
	var mace = ItemDatabase.create_weapon(
		"mace_iron", "Iron Mace", "iron",
		"1d6", "bludgeoning", false
	)
	mace.equip_slot = "right_weapon"
	mace.weight = 4.0
	mace.base_value = 50
	ItemDatabase.register_item(mace)
	
	# BOWS - Ranged weapons
	var shortbow = ItemDatabase.create_weapon(
		"bow_short", "Shortbow", "oak",
		"1d6", "piercing", true
	)
	shortbow.equip_slot = "right_weapon"
	shortbow.is_ranged = true
	shortbow.range_normal = 80
	shortbow.range_max = 320
	shortbow.weight = 2.0
	shortbow.base_value = 50
	shortbow.material = null  # Wood, not metal
	ItemDatabase.register_item(shortbow)
	
	var longbow = ItemDatabase.create_weapon(
		"bow_long", "Longbow", "oak",
		"1d8", "piercing", true
	)
	longbow.equip_slot = "right_weapon"
	longbow.is_ranged = true
	longbow.range_normal = 150
	longbow.range_max = 600
	longbow.weight = 2.0
	longbow.base_value = 100
	longbow.material = null
	ItemDatabase.register_item(longbow)
	
	# LEGENDARY WEAPONS
	var mithril_sword = ItemDatabase.create_weapon(
		"sword_long_mithril", "Mithril Longsword", "mithril",
		"1d8", "slashing", false
	)
	mithril_sword.equip_slot = "right_weapon"
	mithril_sword.weight = 2.0  # Lighter than steel
	mithril_sword.base_value = 1000
	mithril_sword.description = "A blade forged from legendary mithril, light as a feather yet unbreakable."
	ItemDatabase.register_item(mithril_sword)

# === ARMOR ===

func create_armor():
	"""Create test armor pieces"""
	
	# HELMS
	var leather_helm = ItemDatabase.create_armor(
		"helm_leather", "Leather Helm", "leather",
		"head", 1
	)
	leather_helm.weight = 1.0
	leather_helm.base_value = 20
	ItemDatabase.register_item(leather_helm)
	
	var steel_helm = ItemDatabase.create_armor(
		"helm_steel", "Steel Helm", "steel",
		"head", 2
	)
	steel_helm.weight = 3.0
	steel_helm.base_value = 100
	ItemDatabase.register_item(steel_helm)
	
	# CHEST ARMOR
	var leather_chest = ItemDatabase.create_armor(
		"chest_leather", "Leather Armor", "leather",
		"chest", 2
	)
	leather_chest.weight = 10.0
	leather_chest.base_value = 50
	leather_chest.armor_type = "light"
	ItemDatabase.register_item(leather_chest)
	
	var chainmail = ItemDatabase.create_armor(
		"chest_chain_steel", "Steel Chainmail", "steel",
		"chest", 5
	)
	chainmail.weight = 25.0
	chainmail.base_value = 300
	chainmail.armor_type = "medium"
	chainmail.dex_bonus_limit = 2
	ItemDatabase.register_item(chainmail)
	
	var plate_armor = ItemDatabase.create_armor(
		"chest_plate_steel", "Steel Plate Armor", "steel",
		"chest", 8
	)
	plate_armor.weight = 50.0
	plate_armor.base_value = 800
	plate_armor.armor_type = "heavy"
	plate_armor.strength_requirement = 15
	plate_armor.stealth_disadvantage = true
	ItemDatabase.register_item(plate_armor)
	
	# LEGS
	var leather_legs = ItemDatabase.create_armor(
		"legs_leather", "Leather Leggings", "leather",
		"legs", 1
	)
	leather_legs.weight = 5.0
	leather_legs.base_value = 30
	ItemDatabase.register_item(leather_legs)
	
	var steel_legs = ItemDatabase.create_armor(
		"legs_steel", "Steel Greaves", "steel",
		"legs", 2
	)
	steel_legs.weight = 15.0
	steel_legs.base_value = 150
	ItemDatabase.register_item(steel_legs)
	
	# GLOVES/GAUNTLETS
	var leather_gloves = ItemDatabase.create_armor(
		"gloves_leather", "Leather Gloves", "leather",
		"arm", 0
	)
	leather_gloves.weight = 0.5
	leather_gloves.base_value = 10
	ItemDatabase.register_item(leather_gloves)
	
	var steel_gauntlets = ItemDatabase.create_armor(
		"gauntlets_steel", "Steel Gauntlets", "steel",
		"arm", 1
	)
	steel_gauntlets.weight = 2.0
	steel_gauntlets.base_value = 50
	ItemDatabase.register_item(steel_gauntlets)
	
	# BOOTS
	var leather_boots = ItemDatabase.create_armor(
		"boots_leather", "Leather Boots", "leather",
		"boots", 0
	)
	leather_boots.weight = 2.0
	leather_boots.base_value = 15
	ItemDatabase.register_item(leather_boots)
	
	var steel_boots = ItemDatabase.create_armor(
		"boots_steel", "Steel Boots", "steel",
		"boots", 1
	)
	steel_boots.weight = 4.0
	steel_boots.base_value = 75
	ItemDatabase.register_item(steel_boots)

# === ACCESSORIES ===

func create_accessories():
	"""Create rings, amulets, cloaks, etc."""
	
	# RINGS (accessory slots)
	var ring_strength = create_magic_ring("ring_strength", "Ring of Strength", 1, "str")
	ItemDatabase.register_item(ring_strength)
	
	var ring_dex = create_magic_ring("ring_dexterity", "Ring of Dexterity", 1, "dex")
	ItemDatabase.register_item(ring_dex)
	
	var ring_con = create_magic_ring("ring_constitution", "Ring of Constitution", 2, "con")
	ItemDatabase.register_item(ring_con)
	
	var ring_protection = ItemData.new()
	ring_protection.item_id = "ring_protection"
	ring_protection.item_name = "Ring of Protection"
	ring_protection.item_type = ItemData.ItemType.ACCESSORY_RING
	ring_protection.equip_slot = "accessory_1"
	ring_protection.armor_class_bonus = 1
	ring_protection.weight = 0.0
	ring_protection.base_value = 500
	ring_protection.description = "A magical ring that wards away danger. +1 AC"
	ItemDatabase.register_item(ring_protection)
	
	# AMULETS (neck slot)
	var amulet_health = ItemData.new()
	amulet_health.item_id = "amulet_health"
	amulet_health.item_name = "Amulet of Health"
	amulet_health.item_type = ItemData.ItemType.ACCESSORY_NECK
	amulet_health.equip_slot = "neck"
	amulet_health.constitution_bonus = 2
	amulet_health.weight = 0.0
	amulet_health.base_value = 800
	amulet_health.description = "A glowing amulet that enhances vitality. +2 CON"
	ItemDatabase.register_item(amulet_health)
	
	# CLOAKS (back slot)
	var cloak_protection = ItemData.new()
	cloak_protection.item_id = "cloak_protection"
	cloak_protection.item_name = "Cloak of Protection"
	cloak_protection.item_type = ItemData.ItemType.ACCESSORY_CLOAK
	cloak_protection.equip_slot = "back"
	cloak_protection.armor_class_bonus = 1
	cloak_protection.weight = 1.0
	cloak_protection.base_value = 500
	cloak_protection.description = "A shimmering cloak that deflects blows. +1 AC"
	ItemDatabase.register_item(cloak_protection)
	
	var cloak_elvenkind = ItemData.new()
	cloak_elvenkind.item_id = "cloak_elvenkind"
	cloak_elvenkind.item_name = "Cloak of Elvenkind"
	cloak_elvenkind.item_type = ItemData.ItemType.ACCESSORY_CLOAK
	cloak_elvenkind.equip_slot = "back"
	cloak_elvenkind.dexterity_bonus = 1
	cloak_elvenkind.weight = 0.5
	cloak_elvenkind.base_value = 600
	cloak_elvenkind.description = "A fine elven cloak that helps the wearer move silently. +1 DEX"
	ItemDatabase.register_item(cloak_elvenkind)

func create_magic_ring(ring_id: String, ring_name: String, bonus: int, stat: String) -> ItemData:
	"""Helper to create stat-boosting rings"""
	var ring = ItemData.new()
	ring.item_id = ring_id
	ring.item_name = ring_name
	ring.item_type = ItemData.ItemType.ACCESSORY_RING
	ring.equip_slot = "accessory_1"  # Can go in any accessory slot
	ring.weight = 0.0
	ring.base_value = 300 * bonus
	
	match stat:
		"str": ring.strength_bonus = bonus
		"dex": ring.dexterity_bonus = bonus
		"con": ring.constitution_bonus = bonus
		"int": ring.intelligence_bonus = bonus
		"wis": ring.wisdom_bonus = bonus
		"cha": ring.charisma_bonus = bonus
	
	ring.description = "A magical ring that enhances " + stat.to_upper() + ". +" + str(bonus) + " " + stat.to_upper()
	return ring

# === CONSUMABLES ===

func create_consumables():
	"""Create potions, scrolls, food"""
	
	# POTIONS
	var potion_minor = create_healing_potion("potion_heal_minor", "Minor Healing Potion", "2d4", 25)
	ItemDatabase.register_item(potion_minor)
	
	var potion_normal = create_healing_potion("potion_heal", "Healing Potion", "2d8", 50)
	ItemDatabase.register_item(potion_normal)
	
	var potion_greater = create_healing_potion("potion_heal_greater", "Greater Healing Potion", "4d8", 150)
	ItemDatabase.register_item(potion_greater)
	
	# FOOD (light items)
	var rations = ItemData.new()
	rations.item_id = "rations"
	rations.item_name = "Rations"
	rations.item_type = ItemData.ItemType.CONSUMABLE
	rations.is_consumable = true
	rations.stackable = true
	rations.max_stack_size = 5
	rations.weight = 1.0
	rations.base_value = 5
	rations.description = "A day's worth of dried food."
	ItemDatabase.register_item(rations)
	
	# TORCHES (light items)
	var torch = ItemData.new()
	torch.item_id = "torch"
	torch.item_name = "Torch"
	torch.item_type = ItemData.ItemType.MISC
	torch.stackable = true
	torch.max_stack_size = 5
	torch.weight = 1.0
	torch.base_value = 1
	torch.description = "Provides light in dark dungeons."
	ItemDatabase.register_item(torch)

func create_healing_potion(potion_id: String, potion_name: String, heal_dice: String, value: int) -> ItemData:
	"""Helper to create healing potions"""
	var potion = ItemData.new()
	potion.item_id = potion_id
	potion.item_name = potion_name
	potion.item_type = ItemData.ItemType.CONSUMABLE
	potion.is_consumable = true
	potion.consumable_effect = "heal"
	potion.consumable_power = heal_dice  # Store dice string
	potion.stackable = true
	potion.max_stack_size = 5
	potion.weight = 0.5
	potion.base_value = value
	potion.description = "Restores " + heal_dice + " hit points when consumed."
	return potion

# === MISC ITEMS ===

func create_misc_items():
	"""Create gold, gems, quest items"""
	
	# GOLD (currency)
	var gold = ItemData.new()
	gold.item_id = "gold"
	gold.item_name = "Gold Coins"
	gold.item_type = ItemData.ItemType.MISC
	gold.stackable = true
	gold.max_stack_size = 100
	gold.weight = 0.02  # 50 coins = 1 lb
	gold.base_value = 1
	gold.description = "Standard currency of the realm."
	ItemDatabase.register_item(gold)
	
	# GEMS (valuable, stackable)
	var ruby = create_gem("gem_ruby", "Ruby", 500)
	ItemDatabase.register_item(ruby)
	
	var sapphire = create_gem("gem_sapphire", "Sapphire", 1000)
	ItemDatabase.register_item(sapphire)
	
	var diamond = create_gem("gem_diamond", "Diamond", 5000)
	ItemDatabase.register_item(diamond)

func create_gem(gem_id: String, gem_name: String, value: int) -> ItemData:
	"""Helper to create gems"""
	var gem = ItemData.new()
	gem.item_id = gem_id
	gem.item_name = gem_name
	gem.item_type = ItemData.ItemType.MISC
	gem.stackable = true
	gem.max_stack_size = 100
	gem.weight = 0.0
	gem.base_value = value
	gem.description = "A precious gemstone."
	return gem

# === TEST INVENTORY POPULATION ===

func populate_test_inventory():
	"""Add a variety of test items to the player's inventory"""
	print("Populating test inventory...")
	
	# Add some weapons
	add_test_item("sword_short_bronze")
	add_test_item("sword_long_steel")
	add_test_item("dagger_iron")
	add_test_item("axe_battle_steel")
	add_test_item("bow_long")
	
	# Add some armor
	add_test_item("helm_steel")
	add_test_item("chest_leather")
	add_test_item("legs_steel")
	add_test_item("boots_leather")
	add_test_item("gauntlets_steel")
	
	# Add some accessories
	add_test_item("ring_strength")
	add_test_item("ring_dex")
	add_test_item("amulet_health")
	add_test_item("cloak_protection")
	
	# Add consumables
	add_test_item("potion_heal", 0, 0, 3)  # 3 potions
	add_test_item("potion_heal_greater", 0, 0, 2)  # 2 greater potions
	add_test_item("rations", 0, 0, 5)  # 5 rations
	add_test_item("torch", 0, 0, 5)  # 5 torches
	
	# Add some gold
	InventoryManager.add_gold(250)
	
	# Add a legendary item
	add_test_item("sword_long_mithril", 2, 1)  # +2 quality, +1 magic
	
	print("Test inventory populated with ", InventoryManager.items.size(), " items")

func add_test_item(item_id: String, quality: int = 0, magic: int = 0, count: int = 1):
	"""Add a test item to inventory"""
	for i in range(count):
		var item_instance = ItemDatabase.create_item_instance(item_id, quality, magic)
		if not item_instance.is_empty():
			InventoryManager.add_item(item_instance)
		else:
			push_error("Failed to create item: " + item_id)

# === CALL THIS TO TEST ===

func setup_complete_test_scenario():
	"""Complete test setup - call this from World or a test scene"""
	populate_test_inventory()
	print("=== TEST SCENARIO READY ===")
	print("Items in database: ", ItemDatabase.items.size())
	print("Items in inventory: ", InventoryManager.items.size())
	print("Gold: ", InventoryManager.gold)
	print("Slots used: ", InventoryManager.get_slots_used(), "/", InventoryManager.get_max_slots())
