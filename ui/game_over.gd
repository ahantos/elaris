# game_over.gd
# Shown by the World scene when the player dies (scenes/ui/game_over.tscn).
# The tree is paused underneath it; this screen keeps processing.
extends Control

@onready var _epitaph: Label = %Epitaph
@onready var _load_button: Button = %LoadButton
@onready var _menu_button: Button = %MenuButton
@onready var _quit_button: Button = %QuitButton

func _ready():
	var player = GameManager.player
	var who := "The adventurer"
	var level := 1
	if player != null and is_instance_valid(player) and player.get("stats") != null:
		if str(player.stats.character_name) != "":
			who = str(player.stats.character_name)
		level = int(player.stats.level)
	_epitaph.text = "%s died at level %d." % [who, level]

	var has_save: bool = SaveManager.has_any_save()
	_load_button.disabled = not has_save
	if not has_save:
		_load_button.text = "No save to load"

	_load_button.pressed.connect(_on_load_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	(_load_button if has_save else _menu_button).grab_focus()

func _on_load_pressed():
	GameManager.continue_game()

func _on_menu_pressed():
	GameManager.go_to_main_menu()

func _on_quit_pressed():
	GameManager.quit_game()
