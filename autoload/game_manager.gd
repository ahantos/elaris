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

# Development shortcuts (regenerate dungeon, re-create character, talk to the
# Reeve from anywhere, reveal the map, debug-recruit companions). Off by default;
# F3 toggles it in game. Not saved.
var debug_keys: bool = false

# === GAME FLOW ===
#
# The game moves between three scenes. Every transition into the World scene
# says HOW the world should start by filling pending_start first:
#   {}                                  -> direct boot (editor F6, tools): default fighter
#   {"mode": "new",  "stats": CharacterStats}        -> a new game with that character
#   {"mode": "load", "slot": int, "data": Dictionary} -> restore a save
# World._ready() consumes it. Loading always goes through a fresh World scene
# after reset_game_state(), so nothing from the previous session can leak in.

const SCENE_MAIN_MENU: String = "res://scenes/main_menu.tscn"
const SCENE_CHARACTER_CREATION: String = "res://scenes/character_creation_screen.tscn"
const SCENE_WORLD: String = "res://scenes/world.tscn"

# Autoloads that hold per-game state, in the order they are reset.
# UIManager goes first: closing an open dialogue panel ends the conversation,
# which may advance a quest - that has to happen before the quest state is wiped.
const STATEFUL_MANAGERS: Array = [
	"UIManager", "DialogueManager", "StatusEffectManager",
	"SpellManager", "FeatureManager", "InventoryManager", "CraftingManager", "QuestManager",
	"FactionManager", "WorldEventManager", "ZoneManager", "CompanionManager",
]

var pending_start: Dictionary = {}
var is_game_over: bool = false

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

func reset_game_state():
	"""Wipe everything that belongs to one playthrough. Called before a new
	game, before a load and when returning to the main menu."""
	for manager_name in STATEFUL_MANAGERS:
		var manager = get_node_or_null("/root/" + manager_name)
		if manager != null and manager.has_method("reset"):
			manager.reset()
		else:
			push_error("GameManager: stateful manager '%s' has no reset()" % manager_name)
	world = null
	player = null
	current_dungeon = null
	in_combat = false
	is_game_over = false
	game_paused = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	print("GameManager: game state reset")

func consume_pending_start() -> Dictionary:
	"""Hand the start instructions to the World scene (once)."""
	var start := pending_start
	pending_start = {}
	return start

func go_to_main_menu():
	"""Leave the current game for the main menu."""
	reset_game_state()
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)

func begin_character_creation():
	"""New Game: wipe state and open the creation screen."""
	reset_game_state()
	get_tree().change_scene_to_file(SCENE_CHARACTER_CREATION)

func start_new_game(stats):
	"""Enter the world with a freshly created character (a CharacterStats)."""
	reset_game_state()
	pending_start = {"mode": "new", "stats": stats}
	get_tree().change_scene_to_file(SCENE_WORLD)

func load_game(slot: int) -> bool:
	"""Restore a save: read it, wipe the current state, and start a fresh
	World scene that rebuilds itself from the data. Returns false (and changes
	nothing) when the slot is empty or unreadable."""
	var data: Dictionary = SaveManager.read_save(slot)
	if data.is_empty():
		EventBus.ui_notification.emit("That save could not be read.", "error")
		return false
	reset_game_state()
	current_save_slot = slot
	pending_start = {"mode": "load", "slot": slot, "data": data}
	get_tree().change_scene_to_file(SCENE_WORLD)
	return true

func continue_game() -> bool:
	"""Load the most recent save. Returns false when there is none."""
	var slot: int = SaveManager.get_latest_slot()
	if slot < 0:
		return false
	return load_game(slot)

func game_over():
	"""The player died. The World scene shows the game-over screen."""
	if is_game_over:
		return
	is_game_over = true
	in_combat = false
	print("GameManager: game over")
	EventBus.game_over.emit()

func pause_game():
	"""Pause game"""
	game_paused = true
	get_tree().paused = true

func unpause_game():
	"""Unpause game"""
	game_paused = false
	get_tree().paused = false

# === RESTING ===

func take_short_rest():
	"""Take a short rest (1 hour). Systems restore resources by listening to EventBus.rest_taken."""
	print("Party takes a short rest")
	EventBus.rest_taken.emit("short")

func take_long_rest():
	"""Take a long rest (8 hours). Restores HP here; other systems listen to EventBus.rest_taken."""
	print("Party takes a long rest")
	if player and player.get("stats") and player.stats:
		player.stats.current_hp = player.stats.max_hp
		EventBus.player_hp_changed.emit(player.stats.current_hp, player.stats.max_hp)
	EventBus.rest_taken.emit("long")

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
	
	# Display: only switch when the mode really differs, so changing another
	# setting does not un-maximise or resize the window
	var current_mode = DisplayServer.window_get_mode()
	var is_fullscreen: bool = current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if settings.fullscreen and not is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not settings.fullscreen and is_fullscreen:
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
