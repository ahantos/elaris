# inventory_manager.gd
# AutoLoad singleton - manages party inventory, gold, weight, equipment
extends Node

# Party inventory (shared by all 4 characters)
var items: Array = []  # Array of item instances (Dictionaries with item_data + instance data)
var gold: int = 50  # Starting gold

# Party members (will be populated by World/GameManager)
var party_members: Array[CharacterStats] = []

# Equipment per character (indexed by character)
# Structure: { character_stats: { "head": item_instance, "chest": item_instance, ... } }
# NOTE: "rings" and "trinkets" slots store Arrays instead of single items
var equipped_items: Dictionary = {}

func _ready():
	print("InventoryManager initialized")
	print("Starting gold: ", gold)

# === INVENTORY MANAGEMENT ===

func add_item(item_instance: Dictionary) -> bool:
	"""
	Add item to party inventory
	Returns false if over weight limit
	"""
	
	if not item_instance.has("item_data"):
		push_error("InventoryManager.add_item: Invalid item instance!")
		return false
	
	var item_data: ItemData = item_instance.item_data
	
	# Check if stackable
	if item_data.stackable:
		# Find existing stack
		for existing in items:
			if existing.item_data == item_data:
				# Stack it
				existing.stack_count = existing.get("stack_count", 1) + 1
				print("Stacked item: ", item_data.item_name, " (x", existing.stack_count, ")")
				EventBus.inventory_changed.emit()
				return true
	
	# Check weight limit
	var new_weight = get_total_weight() + item_data.weight
	if new_weight > get_max_weight():
		print("Cannot add item: Over weight limit!")
		EventBus.ui_notification.emit("Inventory full! Over-encumbered.", "warning")
		return false
	
	# Add to inventory
	if not item_instance.has("instance_id"):
		item_instance.instance_id = ItemDatabase.generate_instance_id()
	
	items.append(item_instance)
	print("Added item: ", item_data.item_name, " (", item_data.weight, " lbs)")
	
	EventBus.inventory_changed.emit()
	EventBus.weight_changed.emit(get_total_weight(), get_max_weight())
	
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
			EventBus.weight_changed.emit(get_total_weight(), get_max_weight())
			
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
	"""Sort inventory by name, weight, value, etc."""
	match sort_key:
		"name":
			items.sort_custom(func(a, b): return a.item_data.item_name < b.item_data.item_name)
		"weight":
			items.sort_custom(func(a, b): return a.item_data.weight < b.item_data.weight)
		"value":
			items.sort_custom(func(a, b): return a.item_data.get_calculated_value() > b.item_data.get_calculated_value())
		"type":
			items.sort_custom(func(a, b): return a.item_data.item_type < b.item_data.item_type)

# === WEIGHT SYSTEM ===

func get_total_weight() -> float:
	"""Calculate total weight of all items in inventory"""
	var total = 0.0
	for item in items:
		var item_data: ItemData = item.item_data
		var stack_count = item.get("stack_count", 1)
		total += item_data.weight * stack_count
	
	# Add gold weight (50 coins = 1 lb)
	total += gold / 50.0
	
	return total

func get_max_weight() -> float:
	"""Calculate max carrying capacity (sum of all party members' STR × 15)"""
	var max_weight = 0.0
	for character in party_members:
		max_weight += character.carrying_capacity
	
	# Fallback if no party members yet
	if max_weight == 0:
		max_weight = 150.0  # Default for single character
	
	return max_weight

func is_over_encumbered() -> bool:
	"""Check if party is over-encumbered"""
	return get_total_weight() > get_max_weight()

func get_encumbrance_level() -> String:
	"""Get encumbrance status"""
	var current = get_total_weight()
	var max_cap = get_max_weight()
	
	if current <= max_cap:
		return "normal"
	elif current <= max_cap * 2:
		return "encumbered"
	else:
		return "overloaded"

func get_encumbrance_text() -> String:
	"""Get formatted encumbrance text"""
	match get_encumbrance_level():
		"normal": return "Normal"
		"encumbered": return "Encumbered"
		"overloaded": return "Overloaded"
	return "Normal"

func get_encumbrance_speed_penalty() -> int:
	"""Get speed penalty from encumbrance"""
	match get_encumbrance_level():
		"encumbered": return -10
		"overloaded": return -20
	return 0

# === SLOT MANAGEMENT ===

func get_slots_used() -> int:
	"""Get number of inventory slots currently used"""
	var used = 0
	for item in items:
		var item_data: ItemData = item.item_data
		var slot_size = item_data.get("slot_size", 1)
		used += slot_size
	return used

func get_max_slots() -> int:
	"""Get maximum inventory slots (expandable later)"""
	return 25  # Base inventory size

# === EQUIPMENT SYSTEM ===

func equip_item(item_instance: Dictionary, character: CharacterStats, slot: String) -> bool:
	"""
	Equip an item on a character
	Returns false if slot occupied or item incompatible
	Handles multi-item slots (rings, trinkets) as arrays
	"""
	
	if not item_instance.has("item_data"):
		push_error("InventoryManager.equip_item: Invalid item instance!")
		return false
	
	var item_data: ItemData = item_instance.item_data
	
	# Check if item can be equipped in this slot
	if item_data.equip_slot != slot:
		print("Cannot equip ", item_data.item_name, " in slot ", slot)
		return false
	
	# Initialize equipped items dict for this character if needed
	if not equipped_items.has(character):
		equipped_items[character] = {}
	
	# Handle multi-item slots (rings, trinkets)
	if slot == "rings" or slot == "trinkets":
		# Store as array
		if not equipped_items[character].has(slot):
			equipped_items[character][slot] = []
		
		# Add to array
		equipped_items[character][slot].append(item_instance)
		
		# Remove from inventory
		remove_item(item_instance.instance_id)
		
		# Update character stats
		recalculate_character_stats(character)
		
		print("Equipped %s in %s slot (%d total)" % [item_data.item_name, slot, equipped_items[character][slot].size()])
		EventBus.item_equipped.emit(item_instance, slot)
		EventBus.equipment_changed.emit(character)
		
		return true
	
	# Handle single-item slots (normal equipment)
	# Check if slot is occupied
	if equipped_items[character].has(slot):
		# Unequip current item first
		unequip_item(character, slot)
	
	# Equip the item
	equipped_items[character][slot] = item_instance
	
	# Remove from inventory
	remove_item(item_instance.instance_id)
	
	# Update character stats
	recalculate_character_stats(character)
	
	print("Equipped %s in %s slot" % [item_data.item_name, slot])
	EventBus.item_equipped.emit(item_instance, slot)
	EventBus.equipment_changed.emit(character)
	
	return true

func unequip_item(character: CharacterStats, slot: String, item_instance: Dictionary = {}) -> Dictionary:
	"""
	Unequip item from character
	For multi-item slots (rings/trinkets), pass the specific item_instance to remove
	Returns the unequipped item instance
	"""
	
	if not equipped_items.has(character) or not equipped_items[character].has(slot):
		print("No item equipped in slot ", slot)
		return {}
	
	# Handle multi-item slots
	if slot == "rings" or slot == "trinkets":
		if item_instance.is_empty():
			print("Error: Must specify which item to unequip from ", slot)
			return {}
		
		var slot_array: Array = equipped_items[character][slot]
		var index = slot_array.find(item_instance)
		
		if index == -1:
			print("Item not found in ", slot)
			return {}
		
		slot_array.remove_at(index)
		
		# Remove the slot key if array is empty
		if slot_array.is_empty():
			equipped_items[character].erase(slot)
		
		# Add back to inventory
		add_item(item_instance)
		
		# Update character stats
		recalculate_character_stats(character)
		
		print("Unequipped %s from %s slot" % [item_instance.item_data.item_name, slot])
		EventBus.item_unequipped.emit(item_instance, slot)
		EventBus.equipment_changed.emit(character)
		
		return item_instance
	
	# Handle single-item slots
	var unequipped = equipped_items[character][slot]
	equipped_items[character].erase(slot)
	
	# Add back to inventory
	add_item(unequipped)
	
	# Update character stats
	recalculate_character_stats(character)
	
	print("Unequipped %s from %s slot" % [unequipped.item_data.item_name, slot])
	EventBus.item_unequipped.emit(unequipped, slot)
	EventBus.equipment_changed.emit(character)
	
	return unequipped

func get_equipped_item(character: CharacterStats, slot: String) -> Dictionary:
	"""Get item equipped in a specific slot (returns first item for multi-slots)"""
	if equipped_items.has(character) and equipped_items[character].has(slot):
		var item = equipped_items[character][slot]
		# If it's an array (rings/trinkets), return first item or empty
		if item is Array:
			return item[0] if item.size() > 0 else {}
		return item
	return {}

func get_equipped_accessories(character: CharacterStats, slot: String) -> Array:
	"""Get all items in a multi-item slot (rings or trinkets)"""
	if equipped_items.has(character) and equipped_items[character].has(slot):
		var item = equipped_items[character][slot]
		if item is Array:
			return item
	return []

func get_all_equipped_items(character: CharacterStats) -> Array:
	"""Get all equipped items for a character (flattens arrays for rings/trinkets)"""
	if not equipped_items.has(character):
		return []
	
	var all_items = []
	for slot in equipped_items[character]:
		var item = equipped_items[character][slot]
		if item is Array:
			# Flatten arrays (rings/trinkets)
			all_items.append_array(item)
		else:
			all_items.append(item)
	
	return all_items

func recalculate_character_stats(character: CharacterStats):
	"""Recalculate character's stats based on equipped items"""
	var equipped = get_all_equipped_items(character)
	character.apply_equipment_bonuses(equipped)

# === GOLD MANAGEMENT ===

func add_gold(amount: int):
	"""Add gold to party"""
	gold += amount
	print("Gained ", amount, " gold. Total: ", gold)
	EventBus.gold_changed.emit(gold)
	EventBus.ui_notification.emit("Gained %d gold!" % amount, "success")

func remove_gold(amount: int) -> bool:
	"""
	Remove gold from party
	Returns false if not enough gold
	"""
	if gold < amount:
		print("Not enough gold! Have: ", gold, ", Need: ", amount)
		EventBus.ui_notification.emit("Not enough gold!", "error")
		return false
	
	gold -= amount
	print("Spent ", amount, " gold. Remaining: ", gold)
	EventBus.gold_changed.emit(gold)
	return true

func has_gold(amount: int) -> bool:
	"""Check if party has enough gold"""
	return gold >= amount

# === PARTY MANAGEMENT ===

func set_party_members(members: Array):
	"""Set the party members (called by World/GameManager)"""
	party_members.clear()
	for member in members:
		if member is CharacterStats:
			party_members.append(member)
	
	print("InventoryManager: Party set with ", party_members.size(), " members")

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Export inventory data for saving"""
	return {
		"items": items.duplicate(),
		"gold": gold,
		"equipped_items": equipped_items.duplicate()
	}

func from_dict(data: Dictionary):
	"""Import inventory data from save"""
	items = data.get("items", [])
	gold = data.get("gold", 0)
	equipped_items = data.get("equipped_items", {})
	
	print("InventoryManager: Loaded ", items.size(), " items, ", gold, " gold")
