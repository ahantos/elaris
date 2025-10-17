# game_manager.gd
# AutoLoad singleton - manages global game state
extends Node

# Version
const GAME_VERSION: String = "0.2.0-alpha"

# Global references (set by world when ready)
var world: Node = null
var player: Node = null
var current_dungeon: Node = null

# Game state
var game_paused: bool = false
var in_combat: bool = false
var current_save_slot: int = -1

# Settings
var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"vsync": true,
	"show_grid": false,  # Grid visibility toggle
	"show_damage_numbers": true,
	"ui_scale": 1.0
}

func _ready():
	print("GameManager initialized")
	print("Game Version: ", GAME_VERSION)
	load_settings()

# === GAME STATE ===

func set_world(world_node: Node):
	"""Set world reference"""
	world = world_node
	print("GameManager: World reference set")

func set_player(player_node: Node):
	"""Set player reference"""
	player = player_node
	print("GameManager: Player reference set")

func set_dungeon(dungeon_node: Node):
	"""Set dungeon reference"""
	current_dungeon = dungeon_node
	print("GameManager: Dungeon reference set")

func pause_game():
	"""Pause game"""
	game_paused = true
	get_tree().paused = true

func unpause_game():
	"""Unpause game"""
	game_paused = false
	get_tree().paused = false

# === SETTINGS ===

func get_setting(key: String, default = null):
	"""Get a setting value"""
	return settings.get(key, default)

func set_setting(key: String, value):
	"""Set a setting value"""
	settings[key] = value
	apply_settings()
	save_settings()

func apply_settings():
	"""Apply current settings to engine"""
	# Audio
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 
		linear_to_db(settings.master_volume))
	
	# Display
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED
	)

func save_settings():
	"""Save settings to file"""
	var file = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
	if file:
		file.store_var(settings)
		file.close()
		print("Settings saved")

func load_settings():
	"""Load settings from file"""
	if FileAccess.file_exists("user://settings.cfg"):
		var file = FileAccess.open("user://settings.cfg", FileAccess.READ)
		if file:
			var loaded = file.get_var()
			if loaded is Dictionary:
				settings.merge(loaded, true)
			file.close()
			print("Settings loaded")
			apply_settings()
	else:
		print("No settings file found, using defaults")

# === UTILITY ===

func linear_to_db(linear: float) -> float:
	"""Convert linear volume (0-1) to decibels"""
	if linear <= 0:
		return -80
	return 20 * log(linear) / log(10)

func quit_game():
	"""Quit the game"""
	get_tree().quit()
