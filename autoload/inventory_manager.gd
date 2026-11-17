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

# Weapon sets. A character has two, each with a main hand and an off hand, and
# holds one of them. Set one's slots are "main_hand" and "off_hand", set two's
# "main_hand_2" and "off_hand_2" (weapon_slot()). An item's equip_slot names the
# hand it goes in ("main_hand" or "off_hand") and it fits that hand of either
# set. Only the set in hand counts for attacks, armour class and anything else
# the gear gives.
const WEAPON_SET_COUNT: int = 2
const HANDS: Array[String] = ["main_hand", "off_hand"]

# CharacterStats -> the weapon set in hand (1 or 2). Absent: set one.
var weapon_sets_in_hand: Dictionary = {}

const STARTING_GOLD: int = 50

func _ready():
	print("InventoryManager initialized")
	print("Starting gold: ", gold)

func reset():
	"""Back to a fresh game: empty bag, starting gold, nothing equipped, no party.
	Called by GameManager.reset_game_state() before a new game or a load."""
	items.clear()
	equipped_items.clear()
	weapon_sets_in_hand.clear()
	party_members.clear()
	gold = STARTING_GOLD
	EventBus.inventory_changed.emit()
	EventBus.gold_changed.emit(gold)

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
				# Stack it (respect the incoming instance's own stack count)
				existing.stack_count = existing.get("stack_count", 1) + item_instance.get("stack_count", 1)
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

func has_disadvantage_on_physical_rolls() -> bool:
	"""Encumbered or overloaded characters have disadvantage on physical rolls"""
	return get_encumbrance_level() != "normal"

# === SLOT MANAGEMENT ===

func get_slots_used() -> int:
	"""Get number of inventory slots currently used (each stack occupies one slot)"""
	# NOTE: ItemData has no slot_size property; revisit if multi-slot items get added
	return items.size()

func get_max_slots() -> int:
	"""Get maximum inventory slots (expandable later)"""
	return 25  # Base inventory size

# === EQUIPMENT SYSTEM ===

func equip_item(item_instance: Dictionary, character: CharacterStats, slot: String) -> bool:
	"""Equip an item from the pack on a character. slot is an equipment slot; a
	weapon or shield goes in its hand of either weapon set ("main_hand",
	"off_hand_2"). Returns false, and changes nothing, when the item does not
	belong in the slot (get_equip_refusal) or what the slot held cannot go back
	into the pack. Rings and trinkets are kept as arrays."""
	if not item_instance.has("item_data"):
		push_error("InventoryManager.equip_item: Invalid item instance!")
		return false

	var item_data: ItemData = item_instance.item_data
	var refusal: String = get_equip_refusal(item_instance, character, slot)
	if refusal != "":
		print("Cannot equip ", item_data.item_name, ": ", refusal)
		return false

	# Initialize equipped items dict for this character if needed
	if not equipped_items.has(character):
		equipped_items[character] = {}

	# Handle multi-item slots (rings, trinkets)
	if slot == "rings" or slot == "trinkets":
		if not equipped_items[character].has(slot):
			equipped_items[character][slot] = []
		equipped_items[character][slot].append(item_instance)
		remove_item(item_instance.instance_id)
		recalculate_character_stats(character)

		print("Equipped %s in %s slot (%d total)" % [item_data.item_name, slot, equipped_items[character][slot].size()])
		EventBus.item_equipped.emit(item_instance, slot)
		EventBus.equipment_changed.emit(character)
		return true

	# Single-item slots: what is there goes back to the pack first
	if equipped_items[character].has(slot):
		unequip_item(character, slot)
		if equipped_items[character].has(slot):
			print("Cannot equip ", item_data.item_name, ": slot occupied and inventory full")
			return false

	equipped_items[character][slot] = item_instance
	remove_item(item_instance.instance_id)
	recalculate_character_stats(character)

	print("Equipped %s in %s slot" % [item_data.item_name, slot])
	EventBus.item_equipped.emit(item_instance, slot)
	EventBus.equipment_changed.emit(character)
	return true

func get_equip_refusal(item_instance: Dictionary, character: CharacterStats, slot: String) -> String:
	"""Why an item cannot go in a slot, or "" when it can: it is not made for
	that slot, or the hands of the weapon set do not allow it (a two-handed
	weapon needs the off hand of its set empty, and nothing goes in the off hand
	beside one - so a bow or crossbow never shares a set with a shield)."""
	var item_data = item_instance.get("item_data")
	if not (item_data is ItemData):
		return "That cannot be equipped"
	if item_data.equip_slot == "" or item_data.equip_slot != hand_of_slot(slot):
		return "%s does not go there" % item_data.item_name
	var set_index: int = set_of_slot(slot)
	if set_index == 0:
		return ""
	if item_data.equip_slot == "main_hand":
		return _hands_refusal(item_data, get_equipped_item(character, weapon_slot("off_hand", set_index)).get("item_data"))
	return _hands_refusal(get_equipped_item(character, weapon_slot("main_hand", set_index)).get("item_data"), item_data)

func _hands_refusal(main_data, off_data) -> String:
	"""Why a main hand and an off hand cannot be one weapon set, or "" when they can"""
	if main_data is ItemData and main_data.is_two_handed and off_data is ItemData:
		return "%s needs both hands - nothing can be held in the off hand of its set." % main_data.item_name
	return ""

func move_equipped_item(character: CharacterStats, from_slot: String, to_slot: String) -> bool:
	"""Move a weapon or shield from one weapon set to the same hand of the
	other; what was there changes places with it. Returns false, and changes
	nothing, when the two slots are not the same hand of different sets or the
	move would leave a two-handed weapon beside a full off hand."""
	if get_move_refusal(character, from_slot, to_slot) != "":
		return false
	var slots: Dictionary = equipped_items[character]
	var moving: Dictionary = slots[from_slot]
	var displaced: Dictionary = slots.get(to_slot, {})
	slots[to_slot] = moving
	if displaced.is_empty():
		slots.erase(from_slot)
	else:
		slots[from_slot] = displaced
	recalculate_character_stats(character)
	EventBus.equipment_changed.emit(character)
	return true

func get_move_refusal(character: CharacterStats, from_slot: String, to_slot: String) -> String:
	"""Why move_equipped_item would refuse, or "" when it would not"""
	var moving: Dictionary = get_equipped_item(character, from_slot)
	if moving.is_empty() or set_of_slot(from_slot) == 0 or set_of_slot(to_slot) == 0 \
			or set_of_slot(from_slot) == set_of_slot(to_slot) or hand_of_slot(from_slot) != hand_of_slot(to_slot):
		return "That cannot be moved there"
	var hand: String = hand_of_slot(from_slot)
	var other_hand: String = "off_hand" if hand == "main_hand" else "main_hand"
	var displaced = get_equipped_item(character, to_slot).get("item_data")
	for arrangement in [[to_slot, moving.get("item_data")], [from_slot, displaced]]:
		var beside = get_equipped_item(character, weapon_slot(other_hand, set_of_slot(arrangement[0]))).get("item_data")
		var refusal: String = _hands_refusal(arrangement[1], beside) if hand == "main_hand" else _hands_refusal(beside, arrangement[1])
		if refusal != "":
			return refusal
	return ""

# === WEAPON SETS ===

func weapon_slot(hand: String, set_index: int) -> String:
	"""The equipment slot of a hand ("main_hand", "off_hand") in a weapon set
	(1 or 2): "main_hand" for set one, "main_hand_2" for set two"""
	return hand if set_index <= 1 else "%s_%d" % [hand, set_index]

func hand_of_slot(slot: String) -> String:
	"""The kind of slot an item must be made for to go in an equipment slot:
	the hand for a weapon-set slot ("main_hand_2" -> "main_hand"), the slot
	itself for everything else"""
	for hand in HANDS:
		if slot == hand or slot.begins_with(hand + "_"):
			return hand
	return slot

func set_of_slot(slot: String) -> int:
	"""The weapon set an equipment slot belongs to (1 or 2), or 0 for a slot
	that is not a hand"""
	for hand in HANDS:
		for set_index in range(1, WEAPON_SET_COUNT + 1):
			if slot == weapon_slot(hand, set_index):
				return set_index
	return 0

func get_weapon_set(character: CharacterStats) -> int:
	"""The weapon set the character has in hand: 1 or 2"""
	return int(weapon_sets_in_hand.get(character, 1))

func set_weapon_set(character: CharacterStats, set_index: int):
	"""Put a weapon set in the character's hands. What the other set gave - a
	shield's armour class - goes with it. In a fight only the CombatController
	does this, when it approves a swap_weapons request."""
	weapon_sets_in_hand[character] = clampi(set_index, 1, WEAPON_SET_COUNT)
	recalculate_character_stats(character)
	EventBus.equipment_changed.emit(character)

func swap_weapon_set(character: CharacterStats) -> int:
	"""Take the other weapon set in hand; returns the set now in hand"""
	set_weapon_set(character, get_weapon_set(character) % WEAPON_SET_COUNT + 1)
	return get_weapon_set(character)

func get_hand_item(character: CharacterStats, hand: String, set_index: int = 0) -> Dictionary:
	"""The item instance in a hand ("main_hand", "off_hand") of a weapon set;
	set_index 0 is the set in hand. {} for an empty hand."""
	if character == null:
		return {}
	return get_equipped_item(character, weapon_slot(hand, set_index if set_index > 0 else get_weapon_set(character)))

func is_weapon_set_empty(character: CharacterStats, set_index: int) -> bool:
	"""True when neither hand of a weapon set holds anything"""
	return get_hand_item(character, "main_hand", set_index).is_empty() and get_hand_item(character, "off_hand", set_index).is_empty()

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
		
		# Add back to inventory first (abort if it doesn't fit)
		if not add_item(item_instance):
			print("Cannot unequip ", item_instance.item_data.item_name, ": inventory full")
			return {}

		slot_array.remove_at(index)

		# Remove the slot key if array is empty
		if slot_array.is_empty():
			equipped_items[character].erase(slot)
		
		# Update character stats
		recalculate_character_stats(character)
		
		print("Unequipped %s from %s slot" % [item_instance.item_data.item_name, slot])
		EventBus.item_unequipped.emit(item_instance, slot)
		EventBus.equipment_changed.emit(character)
		
		return item_instance
	
	# Handle single-item slots
	var unequipped = equipped_items[character][slot]

	# Add back to inventory first (abort if it doesn't fit)
	if not add_item(unequipped):
		print("Cannot unequip ", unequipped.item_data.item_name, ": inventory full")
		return {}

	equipped_items[character].erase(slot)
	
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
	"""Everything the character has equipped, both weapon sets included
	(flattens arrays for rings/trinkets)"""
	return _equipped_items(character, false)

func get_active_equipped_items(character: CharacterStats) -> Array:
	"""What the character's gear gives it right now: everything worn, and the
	weapon set in hand. The other set is carried, not used."""
	return _equipped_items(character, true)

func _equipped_items(character: CharacterStats, in_use_only: bool) -> Array:
	var all_items = []
	if not equipped_items.has(character):
		return all_items
	var in_hand: int = get_weapon_set(character)
	for slot in equipped_items[character]:
		var set_index: int = set_of_slot(slot)
		if in_use_only and set_index != 0 and set_index != in_hand:
			continue
		var item = equipped_items[character][slot]
		if item is Array:
			# Flatten arrays (rings/trinkets)
			all_items.append_array(item)
		else:
			all_items.append(item)
	return all_items

func recalculate_character_stats(character: CharacterStats):
	"""Recalculate character's stats from the gear in use"""
	character.apply_equipment_bonuses(get_active_equipped_items(character))

func add_item_or_drop(item_instance: Dictionary) -> bool:
	"""Add an item to the bag; if it does not fit, put it on the ground at the
	player's feet instead of losing it. Use this for anything the game GIVES the
	player (crafted items, quest/dialogue/event rewards).
	Returns true only if the item went into the bag."""
	if add_item(item_instance):
		return true
	var world = GameManager.world
	if world != null and is_instance_valid(world) and world.has_method("drop_items_at_player"):
		world.drop_items_at_player([item_instance])
		return false
	push_warning("InventoryManager.add_item_or_drop: bag full and no world to drop into - item lost")
	return false

func auto_equip_from_inventory(character: CharacterStats) -> int:
	"""Equip every equippable bag item whose slot is still empty on the character
	(used for starting kits). A weapon or shield goes in weapon set one when its
	hand is free there and the hands allow it, otherwise in set two: a fighter's
	longsword and shield make set one and its crossbow set two. Returns how many
	items were equipped."""
	var equipped_count := 0
	for item_instance in items.duplicate():
		var item_data: ItemData = item_instance.get("item_data")
		if item_data == null or item_data.equip_slot == "":
			continue
		var slot: String = item_data.equip_slot
		if slot == "rings" or slot == "trinkets":
			continue
		var candidates: Array = [slot]
		if slot in HANDS:
			candidates = []
			for set_index in range(1, WEAPON_SET_COUNT + 1):
				candidates.append(weapon_slot(slot, set_index))
		for candidate in candidates:
			if get_equipped_item(character, candidate).is_empty() and get_equip_refusal(item_instance, character, candidate) == "":
				if equip_item(item_instance, character, candidate):
					equipped_count += 1
				break
	return equipped_count

func is_party_member(character: CharacterStats) -> bool:
	"""True if these stats belong to someone who carries the party inventory"""
	return character != null and party_members.has(character)

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
	"""Export inventory data for saving (primitives only - see ARCHITECTURE_CONTRACTS.md):
	{items, gold, equipped_items: {character uid: {slot: item}}, weapon_sets:
	{character uid: the set in hand}}"""
	var item_list: Array = []
	for item in items:
		item_list.append(_instance_to_primitive(item))

	var equipped: Dictionary = {}
	for character in equipped_items:
		var uid = "player"
		if "character_uid" in character and character.character_uid != "":
			uid = character.character_uid
		var slots: Dictionary = {}
		for slot in equipped_items[character]:
			var entry = equipped_items[character][slot]
			if entry is Array:
				var arr: Array = []
				for inst in entry:
					arr.append(_instance_to_primitive(inst))
				slots[slot] = arr
			else:
				slots[slot] = _instance_to_primitive(entry)
		equipped[uid] = slots

	var in_hand: Dictionary = {}
	for character in weapon_sets_in_hand:
		if "character_uid" in character and character.character_uid != "":
			in_hand[character.character_uid] = get_weapon_set(character)

	return {
		"items": item_list,
		"gold": gold,
		"equipped_items": equipped,
		"weapon_sets": in_hand
	}

func _instance_to_primitive(item_instance: Dictionary) -> Dictionary:
	"""Serialize an item instance to primitives (rebuilt via ItemDatabase on load)"""
	var item_data = item_instance.get("item_data")
	return {
		"item_id": item_data.item_id if item_data else "",
		"quality_modifier": item_instance.get("quality_modifier", 0),
		"magic_modifier": item_instance.get("magic_modifier", 0),
		"current_durability": item_instance.get("current_durability", 0),
		"stack_count": item_instance.get("stack_count", 1)
	}

func _instance_from_primitive(data: Dictionary) -> Dictionary:
	"""Rebuild an item instance from its primitive save form"""
	var instance = ItemDatabase.create_item_instance(
		data.get("item_id", ""),
		data.get("quality_modifier", 0),
		data.get("magic_modifier", 0)
	)
	if instance.is_empty():
		return {}
	instance.current_durability = data.get("current_durability", instance.get("current_durability", 0))
	if data.get("stack_count", 1) > 1:
		instance.stack_count = data.get("stack_count", 1)
	return instance

func from_dict(data: Dictionary):
	"""Import inventory data from save (rebuilds instances through ItemDatabase)"""
	items.clear()
	for entry in data.get("items", []):
		var instance = _instance_from_primitive(entry)
		if not instance.is_empty():
			items.append(instance)

	gold = data.get("gold", 0)

	# Equipment: resolve character uids back to live CharacterStats
	equipped_items.clear()
	weapon_sets_in_hand.clear()
	var in_hand: Dictionary = data.get("weapon_sets", {}) if data.get("weapon_sets") is Dictionary else {}
	var equipped: Dictionary = data.get("equipped_items", {})
	for uid in equipped:
		var character = _resolve_character_uid(uid)
		if character == null:
			print("InventoryManager: skipping equipment for unknown character uid '", uid, "'")
			continue
		equipped_items[character] = {}
		weapon_sets_in_hand[character] = clampi(int(in_hand.get(uid, 1)), 1, WEAPON_SET_COUNT)
		for slot in equipped[uid]:
			var entry = equipped[uid][slot]
			if entry is Array:
				var arr: Array = []
				for inst_data in entry:
					var inst = _instance_from_primitive(inst_data)
					if not inst.is_empty():
						arr.append(inst)
				if not arr.is_empty():
					equipped_items[character][slot] = arr
			else:
				var inst = _instance_from_primitive(entry)
				if not inst.is_empty():
					equipped_items[character][slot] = inst
		recalculate_character_stats(character)

	EventBus.inventory_changed.emit()
	EventBus.gold_changed.emit(gold)
	print("InventoryManager: Loaded ", items.size(), " items, ", gold, " gold")

func _resolve_character_uid(uid: String):
	"""Map a saved character uid back to a live CharacterStats (null if unknown)"""
	if uid == "player" and GameManager.player and GameManager.player.get("stats"):
		return GameManager.player.stats
	return null
