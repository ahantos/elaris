# inventory_manager.gd
# AutoLoad singleton - manages party inventory with SLOT-BASED encumbrance
extends Node

# Party inventory (shared by all 4 characters)
var items: Array = []  # Array of item instances (Dictionaries with item_data + instance data)
var gold: int = 50  # Starting gold

# Party members (will be populated by World/GameManager)
var party_members: Array[CharacterStats] = []

# Equipment per character (indexed by character)
# Structure: { character_stats: { "head": item_instance, "chest": item_instance, ... } }
var equipped_items: Dictionary = {}

# Slot-based encumbrance thresholds
enum EncumbranceLevel {
	NORMAL,          # 0 to STR+10: Full speed
	LIGHTLY,         # STR+11 to STR+20: Speed 20'
	HEAVILY,         # STR+21 to STR+30: Speed 10', disadvantage
	OVER_ENCUMBERED  # STR+31+: Speed 0
}

func _ready():
	print("InventoryManager initialized (SLOT-BASED SYSTEM)")
	print("Starting gold: ", gold)

# === INVENTORY MANAGEMENT ===

func add_item(item_instance: Dictionary) -> bool:
	"""
	Add item to party inventory
	Returns false if over slot limit
	"""
	
	if not item_instance.has("item_data"):
		push_error("InventoryManager.add_item: Invalid item instance!")
		return false
	
	var item_data: ItemData = item_instance.item_data
	
	# Check if stackable (light items, coins, gems)
	if item_data.stackable or is_light_item(item_data):
		# Try to stack with existing
		for existing in items:
			if existing.item_data == item_data:
				var stack_limit = get_stack_limit(item_data)
				if existing.get("stack_count", 1) < stack_limit:
					existing.stack_count = existing.get("stack_count", 1) + 1
					print("Stacked item: ", item_data.item_name, " (x", existing.stack_count, ")")
					EventBus.inventory_changed.emit()
					return true
	
	# Check slot limit
	var slots_needed = get_item_slot_size(item_data)
	if get_slots_used() + slots_needed > get_max_slots():
		print("Cannot add item: Not enough inventory slots!")
		EventBus.ui_notification.emit("Inventory full! No more slots.", "warning")
		return false
	
	# Add to inventory
	if not item_instance.has("instance_id"):
		item_instance.instance_id = ItemDatabase.generate_instance_id()
	
	items.append(item_instance)
	print("Added item: ", item_data.item_name, " (", slots_needed, " slot(s))")
	
	EventBus.inventory_changed.emit()
	EventBus.slots_changed.emit(get_slots_used(), get_max_slots())
	
	return true

func remove_item(instance_id: String) -> Dictionary:
	"""
	Remove item from inventory by instance ID
	Returns the removed item instance (or empty dict if not found)
	"""
	
	for i in range(items.size()):
		if items[i].instance_id == instance_id:
			var removed = items[i]
			
			# Check if stacked
			if removed.has("stack_count") and removed.stack_count > 1:
				removed.stack_count -= 1
				print("Removed 1 from stack: ", removed.item_data.item_name, " (x", removed.stack_count, ")")
			else:
				items.remove_at(i)
				print("Removed item: ", removed.item_data.item_name)
			
			EventBus.inventory_changed.emit()
			EventBus.slots_changed.emit(get_slots_used(), get_max_slots())
			
			return removed
	
	push_error("InventoryManager.remove_item: Item not found: ", instance_id)
	return {}

func get_item(instance_id: String) -> Dictionary:
	"""Get item instance by ID"""
	for item in items:
		if item.instance_id == instance_id:
			return item
	return {}

func has_item(item_id: String) -> bool:
	"""Check if inventory contains item with given item_id"""
	for item in items:
		if item.item_data.item_id == item_id:
			return true
	return false

func get_items_by_type(item_type: ItemData.ItemType) -> Array:
	"""Get all items of a specific type"""
	var result = []
	for item in items:
		if item.item_data.item_type == item_type:
			result.append(item)
	return result

func sort_items_by(sort_key: String = "name"):
	"""Sort inventory by name, slot size, value, etc."""
	match sort_key:
		"name":
			items.sort_custom(func(a, b): return a.item_data.item_name < b.item_data.item_name)
		"slots":
			items.sort_custom(func(a, b): return get_item_slot_size(a.item_data) > get_item_slot_size(b.item_data))
		"value":
			items.sort_custom(func(a, b): return a.item_data.get_calculated_value() > b.item_data.get_calculated_value())
		"type":
			items.sort_custom(func(a, b): return a.item_data.item_type < b.item_data.item_type)

# === SLOT-BASED ENCUMBRANCE SYSTEM ===

func get_item_slot_size(item_data: ItemData) -> float:
	"""
	Calculate how many inventory slots an item takes
	Rules:
	- Normal items (weapons, armor, shields): 1 slot
	- Heavy items (2H weapons, heavy armor): 2 slots
	- Medium armor: 2 slots
	- Light items (potions, rations, torches, daggers): 0.2 slots (5 per slot)
	- Coins/gems: 0.01 slots (100 per slot)
	- Tiny items (jewelry, papers, worn clothing): 0 slots
	"""
	
	# Tiny items don't count
	if is_tiny_item(item_data):
		return 0.0
	
	# Coins and gems
	if item_data.item_type == ItemData.ItemType.CURRENCY or item_data.item_id.contains("gem"):
		return 0.01  # 100 per slot
	
	# Light items (bundle 5 per slot)
	if is_light_item(item_data):
		return 0.2
	
	# Heavy items (2 slots)
	if is_heavy_item(item_data):
		return 2.0
	
	# Medium armor (2 slots)
	if item_data.is_armor and item_data.item_id.contains("medium"):
		return 2.0
	
	# Normal items (1 slot)
	return 1.0

func is_tiny_item(item_data: ItemData) -> bool:
	"""Check if item is tiny (doesn't count towards encumbrance)"""
	# Worn clothing, jewelry, papers, quills, anything that fits in palm
	var tiny_keywords = ["ring", "amulet", "necklace", "paper", "quill", "letter", "note"]
	for keyword in tiny_keywords:
		if item_data.item_id.contains(keyword):
			return true
	return false

func is_light_item(item_data: ItemData) -> bool:
	"""Check if item is light (5 items per slot)"""
	# Potions, rations, torches, daggers, light hammers, handaxes
	var light_keywords = ["potion", "ration", "torch", "dagger", "vial", "flask", 
						  "light_hammer", "handaxe", "dart", "oil"]
	for keyword in light_keywords:
		if item_data.item_id.contains(keyword):
			return true
	
	# Weight-based fallback
	if item_data.weight <= 2.0:
		return true
	
	return false

func is_heavy_item(item_data: ItemData) -> bool:
	"""Check if item is heavy (2 slots)"""
	# Two-handed weapons, heavy armor pieces, tents, chests, ladders
	if item_data.is_weapon and item_data.is_two_handed:
		return true
	
	if item_data.is_armor and item_data.item_id.contains("heavy"):
		return true
	
	var heavy_keywords = ["tent", "chest", "ladder", "anvil"]
	for keyword in heavy_keywords:
		if item_data.item_id.contains(keyword):
			return true
	
	return false

func get_stack_limit(item_data: ItemData) -> int:
	"""Get max stack size for an item"""
	if is_light_item(item_data):
		return 5  # Light items: 5 per slot
	elif item_data.item_type == ItemData.ItemType.CURRENCY:
		return 100  # Coins: 100 per slot
	elif item_data.item_id.contains("gem"):
		return 100  # Gems: 100 per slot
	else:
		return 1  # Normal items don't stack

func get_slots_used() -> int:
	"""Calculate total slots used by inventory"""
	var total_slots = 0.0
	
	for item in items:
		var item_data: ItemData = item.item_data
		var stack_count = item.get("stack_count", 1)
		var slot_size = get_item_slot_size(item_data)
		
		# Light items and coins: count stacks
		if is_light_item(item_data) or item_data.item_type == ItemData.ItemType.CURRENCY:
			var stacks_needed = ceil(float(stack_count) / get_stack_limit(item_data))
			total_slots += stacks_needed * slot_size / slot_size  # Full slot per stack
		else:
			total_slots += slot_size * stack_count
	
	# Add gold slots (100 coins per slot)
	total_slots += ceil(gold / 100.0)
	
	return int(ceil(total_slots))

func get_max_slots() -> int:
	"""Calculate max inventory slots (10 + STR modifier per character)"""
	var max_slots = 0
	
	for character in party_members:
		max_slots += 10 + character.get_str_modifier()
	
	# Fallback if no party members yet (assume STR 10 = +0)
	if max_slots == 0:
		max_slots = 10  # Default: 10 slots for single character
	
	return max_slots

func get_encumbrance_level() -> EncumbranceLevel:
	"""Get current encumbrance status"""
	var slots_used = get_slots_used()
	var total_str = get_total_party_str()
	
	if slots_used <= total_str + 10:
		return EncumbranceLevel.NORMAL
	elif slots_used <= total_str + 20:
		return EncumbranceLevel.LIGHTLY
	elif slots_used <= total_str + 30:
		return EncumbranceLevel.HEAVILY
	else:
		return EncumbranceLevel.OVER_ENCUMBERED

func get_encumbrance_speed_penalty() -> int:
	"""Get movement speed based on encumbrance (in feet)"""
	match get_encumbrance_level():
		EncumbranceLevel.NORMAL:
			return 0  # No penalty
		EncumbranceLevel.LIGHTLY:
			return -10  # Base speed becomes 20'
		EncumbranceLevel.HEAVILY:
			return -20  # Base speed becomes 10'
		EncumbranceLevel.OVER_ENCUMBERED:
			return -999  # Speed = 0
	return 0

func has_disadvantage_on_physical_rolls() -> bool:
	"""Check if encumbrance causes disadvantage"""
	return get_encumbrance_level() >= EncumbranceLevel.HEAVILY

func get_total_party_str() -> int:
	"""Get sum of all party members' STR scores"""
	var total = 0
	for character in party_members:
		total += character.strength
	
	# Fallback
	if total == 0:
		total = 10  # Assume STR 10
	
	return total

func get_encumbrance_text() -> String:
	"""Get human-readable encumbrance status"""
	match get_encumbrance_level():
		EncumbranceLevel.NORMAL:
			return "Normal"
		EncumbranceLevel.LIGHTLY:
			return "Lightly Encumbered (Speed 20')"
		EncumbranceLevel.HEAVILY:
			return "Heavily Encumbered (Speed 10', Disadvantage)"
		EncumbranceLevel.OVER_ENCUMBERED:
			return "Over-Encumbered (Speed 0)"
	return "Unknown"

# === EQUIPMENT SYSTEM ===

func equip_item(item_instance: Dictionary, character: CharacterStats, slot: String) -> bool:
	"""
	Equip an item on a character
	Returns false if slot occupied or item incompatible
	"""
	
	if not item_instance.has("item_data"):
		push_error("InventoryManager.equip_item: Invalid item instance!")
		return false
	
	var item_data: ItemData = item_instance.item_data
	
	# Check if item can go in this slot
	if item_data.equip_slot != slot:
		print("Item ", item_data.item_name, " cannot be equipped in ", slot, " slot")
		return false
	
	# Initialize equipment dict for character if needed
	if not equipped_items.has(character):
		equipped_items[character] = {}
	
	# Check if slot is occupied
	if equipped_items[character].has(slot):
		print("Slot ", slot, " is already occupied")
		return false
	
	# Equip the item
	equipped_items[character][slot] = item_instance
	
	# Remove from inventory
	remove_item(item_instance.instance_id)
	
	# Apply stat bonuses
	apply_equipment_stats(character, item_data, true)
	
	print("Equipped ", item_data.item_name, " to ", slot)
	EventBus.equipment_changed.emit(character)
	
	return true

func unequip_item(character: CharacterStats, slot: String) -> bool:
	"""Unequip an item from a character slot"""
	
	if not equipped_items.has(character) or not equipped_items[character].has(slot):
		print("No item equipped in ", slot)
		return false
	
	var item_instance = equipped_items[character][slot]
	var item_data: ItemData = item_instance.item_data
	
	# Try to add back to inventory
	if not add_item(item_instance):
		print("Cannot unequip: Inventory full!")
		return false
	
	# Remove stat bonuses
	apply_equipment_stats(character, item_data, false)
	
	# Remove from equipment
	equipped_items[character].erase(slot)
	
	print("Unequipped ", item_data.item_name, " from ", slot)
	EventBus.equipment_changed.emit(character)
	
	return true

func get_equipped_item(character: CharacterStats, slot: String) -> Dictionary:
	"""Get equipped item in a specific slot"""
	if equipped_items.has(character) and equipped_items[character].has(slot):
		return equipped_items[character][slot]
	return {}

func apply_equipment_stats(character: CharacterStats, item_data: ItemData, apply: bool):
	"""Apply or remove equipment stat bonuses"""
	var multiplier = 1 if apply else -1
	
	# Apply stat bonuses
	character.equipment_str_bonus += item_data.strength_bonus * multiplier
	character.equipment_dex_bonus += item_data.dexterity_bonus * multiplier
	character.equipment_con_bonus += item_data.constitution_bonus * multiplier
	character.equipment_int_bonus += item_data.intelligence_bonus * multiplier
	character.equipment_wis_bonus += item_data.wisdom_bonus * multiplier
	character.equipment_cha_bonus += item_data.charisma_bonus * multiplier
	character.equipment_ac_bonus += item_data.armor_class_bonus * multiplier
	
	# Recalculate derived stats
	character.recalculate_derived_stats()

# === GOLD SYSTEM ===

func add_gold(amount: int):
	"""Add gold to party"""
	gold += amount
	print("Gold +", amount, " (Total: ", gold, ")")
	EventBus.gold_changed.emit(gold)
	EventBus.slots_changed.emit(get_slots_used(), get_max_slots())  # Gold affects slots

func remove_gold(amount: int) -> bool:
	"""Remove gold from party (returns false if insufficient)"""
	if gold < amount:
		print("Not enough gold! Have ", gold, ", need ", amount)
		return false
	
	gold -= amount
	print("Gold -", amount, " (Total: ", gold, ")")
	EventBus.gold_changed.emit(gold)
	EventBus.slots_changed.emit(get_slots_used(), get_max_slots())
	
	return true

func has_gold(amount: int) -> bool:
	"""Check if party has enough gold"""
	return gold >= amount
