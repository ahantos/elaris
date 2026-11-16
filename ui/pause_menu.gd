# pause_menu.gd
# In-game pause menu (scenes/ui/pause_menu.tscn), registered with UIManager as
# the "pause_menu" panel. UIManager opens it on ESC when nothing else is open,
# pauses the game while it is up, and closes it on ESC.
extends Control

const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")

var _settings: Control = null

@onready var _resume_button: Button = %ResumeButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton
@onready var _quit_button: Button = %QuitButton
@onready var _note: Label = %Note

func _ready():
	_resume_button.pressed.connect(_on_resume_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_settings = SETTINGS_SCENE.instantiate()
	add_child(_settings)

func on_panel_opened():
	"""UIManager hook: say why saving is unavailable instead of failing later"""
	var blocked: String = SaveManager.can_save()
	_save_button.disabled = blocked != ""
	_load_button.disabled = not SaveManager.has_any_save()
	_note.text = blocked if blocked != "" else "Leaving for the main menu or the desktop does not save."
	_resume_button.grab_focus()

func on_panel_closed():
	if _settings:
		_settings.close()

func _save_load_menu():
	"""The slot list lives in the World scene; it brings its own pause"""
	var world = GameManager.world
	if world != null and is_instance_valid(world):
		return world.get("save_load_menu")
	return null

func _on_resume_pressed():
	UIManager.close_panel("pause_menu")

func _on_save_pressed():
	var menu = _save_load_menu()
	UIManager.close_panel("pause_menu")
	if menu:
		menu.show_save_menu()

func _on_load_pressed():
	var menu = _save_load_menu()
	UIManager.close_panel("pause_menu")
	if menu:
		menu.show_load_menu()

func _on_settings_pressed():
	_settings.open()

func _on_menu_pressed():
	GameManager.go_to_main_menu()

func _on_quit_pressed():
	GameManager.quit_game()
