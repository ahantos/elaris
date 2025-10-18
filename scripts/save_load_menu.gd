# save_load_menu.gd - CLEAN WORKING VERSION
extends Control
class_name SaveLoadMenu

enum Mode { SAVE, LOAD }
var current_mode: Mode = Mode.SAVE

var panel: PanelContainer
var title_label: Label
var slots_container: VBoxContainer

func _ready():
	setup_ui()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_ui():
	"""Create UI"""
	# Full screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Panel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 600)
	center.add_child(panel)
	
	# Main layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	margin.add_child(content)
	
	# Title
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)
	
	# Slots
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	content.add_child(scroll)
	
	slots_container = VBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 10)
	scroll.add_child(slots_container)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "CLOSE (ESC)"
	close_btn.pressed.connect(hide_menu)
	content.add_child(close_btn)
	
	create_slot_buttons()

func create_slot_buttons():
	"""Create save slot buttons"""
	for i in range(10):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		
		var info = SaveManager.get_save_info(i)
		if info.is_empty():
			btn.text = "Slot %d - EMPTY" % (i + 1)
			# Disable empty slots in LOAD mode
			if current_mode == Mode.LOAD:
				btn.disabled = true
		else:
			var time = Time.get_datetime_dict_from_unix_time(info.timestamp)
			btn.text = "Slot %d - Level %d\n%04d-%02d-%02d %02d:%02d" % [
				i + 1, info.player_level,
				time.year, time.month, time.day, time.hour, time.minute
			]
		
		btn.pressed.connect(_on_slot_pressed.bind(i))
		slots_container.add_child(btn)

func show_save_menu():
	"""Show in save mode"""
	current_mode = Mode.SAVE
	title_label.text = "SAVE GAME"
	refresh_slots()
	visible = true
	get_tree().paused = true

func show_load_menu():
	"""Show in load mode"""
	current_mode = Mode.LOAD
	title_label.text = "LOAD GAME"
	refresh_slots()
	visible = true
	get_tree().paused = true

func hide_menu():
	"""Hide menu"""
	visible = false
	get_tree().paused = false

func refresh_slots():
	"""Refresh slot buttons"""
	for child in slots_container.get_children():
		child.queue_free()
	create_slot_buttons()

func _on_slot_pressed(slot: int):
	"""Handle slot click"""
	if current_mode == Mode.SAVE:
		SaveManager.save_game(slot)
		refresh_slots()
	else: # LOAD
		# Don't hide menu or unpause - the scene reload will handle it
		SaveManager.load_game(slot)

func _input(event):
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide_menu()
			get_viewport().set_input_as_handled()
