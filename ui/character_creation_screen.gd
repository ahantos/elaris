# character_creation_screen.gd
# New Game step two (scenes/character_creation_screen.tscn): hosts the character
# creation panel on its own, outside the world. Confirm starts the game with the
# built character; Cancel goes back to the main menu.
extends Control

const CREATION_PANEL := preload("res://ui/character_creation.gd")

var panel: Control = null

func _ready():
	get_tree().paused = false
	panel = CREATION_PANEL.new()
	panel.standalone = true
	add_child(panel)
	panel.confirmed.connect(_on_confirmed)
	panel.cancelled.connect(_on_cancelled)

func _on_confirmed(stats):
	GameManager.start_new_game(stats)

func _on_cancelled():
	GameManager.go_to_main_menu()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_cancelled()
