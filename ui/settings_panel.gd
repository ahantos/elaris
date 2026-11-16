# settings_panel.gd
# Settings overlay (scenes/ui/settings_panel.tscn), used from the main menu and
# from the pause menu. Values live in GameManager.settings, which applies them
# and writes them to user://settings.cfg.
extends Control

var _loading: bool = false

@onready var _fullscreen: CheckButton = %FullscreenCheck
@onready var _vsync: CheckButton = %VsyncCheck
@onready var _volume: HSlider = %VolumeSlider
@onready var _volume_label: Label = %VolumeLabel
@onready var _close_button: Button = %CloseButton

func _ready():
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_vsync.toggled.connect(_on_vsync_toggled)
	_volume.value_changed.connect(_on_volume_changed)
	_close_button.pressed.connect(close)

func open():
	"""Show the overlay with the current values"""
	_loading = true  # setting the controls must not write the settings back
	_fullscreen.button_pressed = bool(GameManager.get_setting("fullscreen", false))
	_vsync.button_pressed = bool(GameManager.get_setting("vsync", true))
	_volume.value = float(GameManager.get_setting("master_volume", 1.0))
	_update_volume_label()
	_loading = false
	visible = true
	_close_button.grab_focus()

func close():
	visible = false

func _update_volume_label():
	_volume_label.text = "Master volume  %d%%" % int(round(_volume.value * 100.0))

func _on_fullscreen_toggled(pressed: bool):
	if not _loading:
		GameManager.set_setting("fullscreen", pressed)

func _on_vsync_toggled(pressed: bool):
	if not _loading:
		GameManager.set_setting("vsync", pressed)

func _on_volume_changed(value: float):
	_update_volume_label()
	if not _loading:
		GameManager.set_setting("master_volume", value)

func _input(event):
	# ESC closes the overlay first, before the menu underneath reacts to it
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
