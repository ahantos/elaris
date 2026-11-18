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
	"""Create save slot buttons. The autosave is listed when loading only:
	the game writes it, the player does not."""
	_confirming_slot = -1
	for slot in SaveManager.get_all_slots():
		var is_autosave: bool = slot == SaveManager.AUTOSAVE_SLOT
		if is_autosave and current_mode == Mode.SAVE:
			continue
		var info = SaveManager.get_save_info(slot)
		if is_autosave and info.is_empty():
			continue

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		btn.text = _slot_text(slot, info)
		# Disable empty slots in LOAD mode
		if info.is_empty() and current_mode == Mode.LOAD:
			btn.disabled = true
		btn.pressed.connect(_on_slot_pressed.bind(slot, btn))
		slots_container.add_child(btn)

func _slot_text(slot: int, info: Dictionary) -> String:
	"""Two-line description of a slot for its button"""
	var slot_name: String = "Autosave" if slot == SaveManager.AUTOSAVE_SLOT else "Slot %d" % (slot + 1)
	if info.is_empty():
		return slot_name + " - EMPTY"
	var who: String = str(info.get("character_name", ""))
	if who == "":
		who = "Adventurer"
	var class_name_text: String = str(info.get("class_id", "")).capitalize()
	var time = Time.get_datetime_dict_from_unix_time(int(info.timestamp))
	return "%s - %s, level %d %s - %s\n%04d-%02d-%02d %02d:%02d  |  %d gold" % [
		slot_name, who, info.player_level, class_name_text,
		_get_zone_display_name(info.get("zone_id", "zone_1")),
		time.year, time.month, time.day, time.hour, time.minute,
		info.get("gold", 0)
	]

func _get_zone_display_name(zone_id: String) -> String:
	"""Resolve a zone id to its display name for slot labels (falls back to the raw id)."""
	var zone = ZoneManager.get_zone(zone_id)
	if zone.is_empty():
		return zone_id
	return str(zone.get("display_name", zone_id))

var _confirming_slot: int = -1  # slot waiting for a second click to overwrite

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

func _on_slot_pressed(slot: int, button: Button = null):
	"""Handle slot click"""
	if current_mode == Mode.SAVE:
		# Overwriting an existing save takes a second click on the same slot
		if SaveManager.save_exists(slot) and _confirming_slot != slot:
			refresh_slots()
			_confirming_slot = slot
			for child in slots_container.get_children():
				if child is Button and not child.is_queued_for_deletion() and child.text.begins_with("Slot %d " % (slot + 1)):
					child.text = "Slot %d - click again to overwrite" % (slot + 1)
			return
		_confirming_slot = -1
		if SaveManager.save_game(slot):
			refresh_slots()
		else:
			hide_menu()  # refused (e.g. combat); the reason was shown as a notification
	else: # LOAD
		# Loading restarts the World scene from the save; close first so the
		# pause this menu holds is released
		hide_menu()
		SaveManager.load_game(slot)

func _input(event):
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide_menu()
			get_viewport().set_input_as_handled()
