# event_bus.gd
# AutoLoad singleton - central event hub for decoupled communication
extends Node

# === COMBAT EVENTS ===
signal combat_started(enemies: Array)
signal combat_ended(victory: bool)
signal turn_started(character)
signal turn_ended(character)
signal damage_dealt(attacker, target, amount, is_critical)
signal character_died(character)
signal enemy_died(enemy)

# === PLAYER EVENTS ===
signal player_moved(old_pos: Vector2i, new_pos: Vector2i)
signal player_hp_changed(current_hp: int, max_hp: int)
signal player_leveled_up(new_level: int)
signal player_gained_xp(amount: int)

# === ITEM EVENTS ===
signal item_picked_up(item_instance)
signal item_dropped(item_instance)
signal item_equipped(item_instance, slot: String)
signal item_unequipped(item_instance, slot: String)
signal item_durability_changed(item_instance, current: int, max: int)
signal item_broken(item_instance)

# === INVENTORY EVENTS ===
signal inventory_changed()
signal weight_changed(current_weight: float, max_weight: float)
signal equipment_changed(character: CharacterStats)  # NEW - for character screen updates
signal slots_changed(used_slots: int, max_slots: int)  # NEW - for slot-based encumbrance
signal gold_changed(amount: int)  # NEW - for gold updates

# === UI EVENTS ===
signal ui_notification(message: String, type: String)  # type: "info", "warning", "error", "success"
signal tooltip_show(text: String, position: Vector2)
signal tooltip_hide()

# === WORLD EVENTS ===
signal dungeon_generated()
signal dungeon_regenerated()
signal location_discovered(location_name: String)
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

# === FACTION EVENTS ===
signal reputation_changed(faction_id: String, old_value: int, new_value: int)
signal faction_status_changed(faction_id: String, new_status: String)

# === GAME STATE EVENTS ===
signal game_paused()
signal game_unpaused()
signal game_saved(slot: int)
signal game_loaded(slot: int)

# === HELPER FUNCTIONS ===

func notify(message: String, type: String = "info"):
	"""Send a UI notification"""
	ui_notification.emit(message, type)

func notify_info(message: String):
	"""Send info notification (white)"""
	notify(message, "info")

func notify_success(message: String):
	"""Send success notification (green)"""
	notify(message, "success")

func notify_warning(message: String):
	"""Send warning notification (yellow)"""
	notify(message, "warning")

func notify_error(message: String):
	"""Send error notification (red)"""
	notify(message, "error")
