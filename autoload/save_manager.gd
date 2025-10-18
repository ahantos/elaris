# save_manager.gd - SIMPLE WORKING VERSION
extends Node

const SAVE_FILE: String = "user://savegame.sav"

func _ready():
	print("SaveManager initialized (simple)")

# === SAVE ===

func save_game() -> bool:
	"""Save game to file"""
	print("Saving game...")
	
	if not GameManager.player:
		push_error("No player to save")
		return false
	
	var save_data = {
		"position_x": GameManager.player.grid_position.x,
		"position_y": GameManager.player.grid_position.y,
		"hp": GameManager.player.stats.current_hp,
		"max_hp": GameManager.player.stats.max_hp,
		"gold": InventoryManager.gold,
	}
	
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file")
		return false
	
	file.store_var(save_data)
	file.close()
	
	print("✅ Game saved!")
	print("  Position: (%d, %d)" % [save_data.position_x, save_data.position_y])
	print("  HP: %d/%d" % [save_data.hp, save_data.max_hp])
	print("  Gold: %d" % save_data.gold)
	return true

# === LOAD ===

func load_game() -> bool:
	"""Load game from file"""
	print("Loading game...")
	
	if not FileAccess.file_exists(SAVE_FILE):
		print("❌ No save file found")
		return false
	
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		push_error("Failed to open save file")
		return false
	
	var save_data = file.get_var()
	file.close()
	
	if not save_data is Dictionary:
		push_error("Save file corrupted")
		return false
	
	# Apply the data
	if GameManager.player:
		# Restore position
		GameManager.player.grid_position = Vector2i(save_data.position_x, save_data.position_y)
		GameManager.player.position = GameManager.player.grid_to_world(GameManager.player.grid_position)
		GameManager.player.target_position = GameManager.player.position
		
		# Restore HP
		GameManager.player.stats.current_hp = save_data.hp
		GameManager.player.stats.max_hp = save_data.max_hp
		
		# Restore gold
		InventoryManager.gold = save_data.gold
		
		print("✅ Game loaded!")
		print("  Position: (%d, %d)" % [save_data.position_x, save_data.position_y])
		print("  HP: %d/%d" % [save_data.hp, save_data.max_hp])
		print("  Gold: %d" % save_data.gold)
		return true
	else:
		push_error("No player to load data into")
		return false

func save_exists() -> bool:
	"""Check if a save file exists"""
	return FileAccess.file_exists(SAVE_FILE)

func delete_save() -> bool:
	"""Delete the save file"""
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
		print("Save file deleted")
		return true
	return false
