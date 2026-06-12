# ui_manager.gd
# AutoLoad singleton - central registry for full-screen UI panels (spellbook, quest log,
# crafting, dialogue, companions, ...). Panels register here; opening is exclusive
# (one panel at a time) and pause handling is centralized so individual panels
# never touch get_tree().paused themselves.
extends Node

# panel_id -> {control: Control, pauses_game: bool}
var panels: Dictionary = {}
var open_panel_id: String = ""
var ui_layer: CanvasLayer = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 50
	ui_layer.name = "UIManagerLayer"
	add_child(ui_layer)
	print("UIManager initialized")

func register_panel(panel_id: String, panel: Control, pauses_game: bool = true):
	"""Register a full-screen panel. It is reparented under UIManager's CanvasLayer and hidden."""
	if panels.has(panel_id):
		push_error("UIManager: panel already registered: " + panel_id)
		return
	if panel.get_parent():
		panel.get_parent().remove_child(panel)
	ui_layer.add_child(panel)
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel.visible = false
	panels[panel_id] = {"control": panel, "pauses_game": pauses_game}
	print("UIManager: registered panel '", panel_id, "'")

func toggle_panel(panel_id: String):
	"""Open the panel, or close it if it is already the open one"""
	if open_panel_id == panel_id:
		close_panel()
	else:
		open_panel(panel_id)

func open_panel(panel_id: String):
	"""Open a panel exclusively (closes any other open panel first)"""
	if not panels.has(panel_id):
		push_error("UIManager: unknown panel: " + panel_id)
		return
	if open_panel_id != "":
		close_panel()
	var entry = panels[panel_id]
	entry.control.visible = true
	open_panel_id = panel_id
	if entry.pauses_game:
		get_tree().paused = true
	if entry.control.has_method("on_panel_opened"):
		entry.control.on_panel_opened()
	EventBus.ui_panel_opened.emit(panel_id)

func close_panel(panel_id: String = ""):
	"""Close the currently open panel (if any).
	Optional panel_id: only close if THAT panel is the open one (lets panels
	close themselves without yanking a different panel shut - companion_panel
	calls close_panel("companions"))."""
	if open_panel_id == "":
		return
	if panel_id != "" and panel_id != open_panel_id:
		return
	var entry = panels[open_panel_id]
	entry.control.visible = false
	if entry.control.has_method("on_panel_closed"):
		entry.control.on_panel_closed()
	var closed_id = open_panel_id
	open_panel_id = ""
	get_tree().paused = false
	EventBus.ui_panel_closed.emit(closed_id)

func is_panel_open(panel_id: String = "") -> bool:
	"""With no argument: is ANY panel open? With an argument: is that specific panel open?"""
	if panel_id == "":
		return open_panel_id != ""
	return open_panel_id == panel_id

func _unhandled_input(event):
	# ESC closes the open panel (consumed so gameplay ESC handlers don't also fire)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if open_panel_id != "":
			close_panel()
			get_viewport().set_input_as_handled()
