# main_menu.gd
# The first screen of the game (scenes/main_menu.tscn, the project's main scene).
# It only decides where to go next; GameManager owns the transitions.
extends Control

const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")

var _load_menu: SaveLoadMenu = null
var _settings: Control = null

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _load_button: Button = %LoadButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel

func _ready():
	get_tree().paused = false
	_version_label.text = "v" + GameManager.GAME_VERSION

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	# The slot list is the same one the game uses in play
	_load_menu = SaveLoadMenu.new()
	add_child(_load_menu)

	_settings = SETTINGS_SCENE.instantiate()
	add_child(_settings)

	_refresh_buttons()
	(_continue_button if not _continue_button.disabled else _new_game_button).grab_focus()

func _refresh_buttons():
	"""Continue and Load only make sense when a save exists"""
	var latest: int = SaveManager.get_latest_slot()
	_continue_button.disabled = latest < 0
	_load_button.disabled = latest < 0
	if latest >= 0:
		var info: Dictionary = SaveManager.get_save_info(latest)
		var who: String = str(info.get("character_name", ""))
		if who == "":
			who = "Adventurer"
		_continue_button.text = "Continue  -  %s, level %d" % [who, int(info.get("player_level", 1))]
	else:
		_continue_button.text = "Continue"

func _on_continue_pressed():
	if not GameManager.continue_game():
		_refresh_buttons()

func _on_new_game_pressed():
	GameManager.begin_character_creation()

func _on_load_pressed():
	_load_menu.show_load_menu()

func _on_settings_pressed():
	_settings.open()

func _on_quit_pressed():
	GameManager.quit_game()
