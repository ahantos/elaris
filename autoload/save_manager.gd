# save_manager.gd - MULTI-SLOT VERSION
extends Node

const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_slot_"
const SAVE_FILE_EXT: String = ".sav"

func _ready():
	print("SaveManager initialized (multi-slot)")
	# Ensure save directory exists
	DirAccess.make_dir_absolute(SAVE_DIR)

# === SAVE ===

func save_game(slot: int = 0) -> bool:
	"""Save game to specific slot"""
	print("=== SAVING GAME TO SLOT ", slot, " ===")
	
	if not GameManager.player:
		push_error("No player to save")
		return false
	
	var save_data = {
		"version": GameManager.GAME_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"player_level": GameManager.player.stats.level,
		"position_x": GameManager.player.grid_position.x,
		"position_y": GameManager.player.grid_position.y,
		"hp": GameManager.player.stats.current_hp,
		"max_hp": GameManager.player.stats.max_hp,
		"gold": InventoryManager.gold,
	}
	
	var save_path = _get_save_path(slot)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file: ", save_path)
		return false
	
	file.store_var(save_data)
	file.close()
	
	print("✅ SAVE COMPLETE - Slot ", slot)
	print("  Position: (%d, %d)" % [save_data.position_x, save_data.position_y])
	print("  HP: %d/%d" % [save_data.hp, save_data.max_hp])
	print("  Gold: %d" % save_data.gold)
	
	EventBus.game_saved.emit(slot)
	return true

# === LOAD ===

func load_game(slot: int = 0) -> bool:
	"""Load game from specific slot"""
	print("=== LOADING GAME FROM SLOT ", slot, " ===")
	
	var save_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		print("❌ No save file found in slot ", slot)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file: ", save_path)
		return false
	
	var save_data = file.get_var()
	file.close()
	
	if not save_data is Dictionary:
		push_error("Save file corrupted in slot ", slot)
		return false
	
	# Check player exists
	if not GameManager.player:
		push_error("No player to load data into")
		return false
	
	# Apply the data
	GameManager.player.grid_position = Vector2i(save_data.position_x, save_data.position_y)
	GameManager.player.position = GameManager.player.grid_to_world(GameManager.player.grid_position)
	GameManager.player.target_position = GameManager.player.position
	
	# Reset movement state
	GameManager.player.stop_moving()
	GameManager.player.cancel_preview()
	GameManager.player.is_moving = false
	GameManager.player.path.clear()
	GameManager.player.path_index = 0
	
	# Restore HP
	GameManager.player.stats.current_hp = save_data.hp
	GameManager.player.stats.max_hp = save_data.max_hp
	
	# Restore gold
	InventoryManager.gold = save_data.gold
	
	# Force redraw
	GameManager.player.queue_redraw()
	
	print("✅ GAME LOADED - Slot ", slot)
	print("  Position: (%d, %d)" % [save_data.position_x, save_data.position_y])
	print("  HP: %d/%d" % [save_data.hp, save_data.max_hp])
	print("  Gold: %d" % save_data.gold)
	
	EventBus.game_loaded.emit(slot)
	return true

# === SLOT MANAGEMENT ===

func get_save_info(slot: int) -> Dictionary:
	"""Get save file info for a slot (for UI display)"""
	var save_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		return {}  # Empty slot
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}
	
	var save_data = file.get_var()
	file.close()
	
	if not save_data is Dictionary:
		return {}
	
	# Return metadata for UI
	return {
		"timestamp": save_data.get("timestamp", 0),
		"player_level": save_data.get("player_level", 1),
		"position": Vector2i(save_data.get("position_x", 0), save_data.get("position_y", 0)),
		"hp": save_data.get("hp", 0),
		"max_hp": save_data.get("max_hp", 0),
		"gold": save_data.get("gold", 0),
	}

func save_exists(slot: int) -> bool:
	"""Check if a save exists in slot"""
	return FileAccess.file_exists(_get_save_path(slot))

func delete_save(slot: int) -> bool:
	"""Delete save in specific slot"""
	var save_path = _get_save_path(slot)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("Save slot ", slot, " deleted")
		return true
	return false

func _get_save_path(slot: int) -> String:
	"""Get file path for save slot"""
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
