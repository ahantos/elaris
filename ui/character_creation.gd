# character_creation.gd
# Character creation UI panel. Panel id: "character_creation".
# Built entirely in code per contracts §5 (no .tscn).
# Orchestrator instances this node and calls
#   UIManager.register_panel("character_creation", panel)
# during integration.
# On Confirm this panel calls CharacterBuilder.build(...), which emits
# EventBus.character_created - integration listens for that signal and applies
# the new stats to the player there. This panel NEVER mutates the player
# directly and NEVER touches get_tree().paused (UIManager owns pausing).
extends Control

# Standard ability array: each value is assigned to exactly one ability score.
const STANDARD_ARRAY := [15, 14, 13, 12, 10, 8]
const STATS := ["str", "dex", "con", "int", "wis", "cha"]
const STAT_LABELS := {
	"str": "Strength",
	"dex": "Dexterity",
	"con": "Constitution",
	"int": "Intelligence",
	"wis": "Wisdom",
	"cha": "Charisma"
}
const DEFAULT_NAME := "Hero"

# --- Colors (matches the other UI panels) ---
const COLOR_BG     := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_PANEL  := Color(0.14, 0.14, 0.20, 0.97)
const COLOR_HEADER := Color(0.85, 0.75, 0.4)
const COLOR_HINT   := Color(0.65, 0.65, 0.7)

# --- Internal state ---
var _class_ids: Array = []          # parallel to _class_list indices
var _race_ids: Array = []           # parallel to _race_list indices
var _stat_values: Dictionary = {}   # stat key -> assigned standard-array value

# --- UI nodes (built in _ready) ---
var _name_edit: LineEdit
var _class_list: ItemList
var _race_list: ItemList
var _tooltip_label: RichTextLabel
var _stat_buttons: Dictionary = {}  # stat key -> OptionButton

func _ready():
	"""Build the entire panel in code and populate it from the databases."""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_reset_stat_assignment()
	_build_ui()
	_refresh_lists()

func on_panel_opened():
	"""UIManager hook - refresh class/race lists and the tooltip when shown."""
	_refresh_lists()

# ---------------------------------------------------------------------------
#  UI CONSTRUCTION
# ---------------------------------------------------------------------------

func _build_ui():
	"""Assemble all child nodes in code."""
	# --- dark backdrop ---
	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# --- centre panel ---
	var panel_rect := ColorRect.new()
	panel_rect.color = COLOR_PANEL
	panel_rect.set_anchors_preset(Control.PRESET_CENTER)
	panel_rect.custom_minimum_size = Vector2(1100, 720)
	panel_rect.offset_left   = -550
	panel_rect.offset_top    = -360
	panel_rect.offset_right  =  550
	panel_rect.offset_bottom =  360
	add_child(panel_rect)

	# --- title ---
	var title := Label.new()
	title.text = "Create Your Character"
	title.position = Vector2(0, 8)
	title.size = Vector2(1100, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 20, COLOR_HEADER)
	panel_rect.add_child(title)

	# --- close button (acts like Cancel) ---
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(1064, 8)
	close_btn.size = Vector2(28, 28)
	close_btn.pressed.connect(_on_cancel_pressed)
	panel_rect.add_child(close_btn)

	# === LEFT COLUMN: name + class + race ===
	var name_label := Label.new()
	name_label.text = "Character Name"
	name_label.position = Vector2(24, 52)
	name_label.size = Vector2(330, 22)
	_style_label(name_label, 14, Color.WHITE)
	panel_rect.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(24, 78)
	_name_edit.size = Vector2(330, 32)
	_name_edit.placeholder_text = DEFAULT_NAME
	_name_edit.max_length = 24
	panel_rect.add_child(_name_edit)

	var class_label := Label.new()
	class_label.text = "Class"
	class_label.position = Vector2(24, 126)
	class_label.size = Vector2(330, 22)
	_style_label(class_label, 14, Color.WHITE)
	panel_rect.add_child(class_label)

	_class_list = ItemList.new()
	_class_list.position = Vector2(24, 152)
	_class_list.size = Vector2(330, 180)
	_class_list.item_selected.connect(_on_class_selected)
	panel_rect.add_child(_class_list)

	var race_label := Label.new()
	race_label.text = "Race"
	race_label.position = Vector2(24, 348)
	race_label.size = Vector2(330, 22)
	_style_label(race_label, 14, Color.WHITE)
	panel_rect.add_child(race_label)

	_race_list = ItemList.new()
	_race_list.position = Vector2(24, 374)
	_race_list.size = Vector2(330, 210)
	_race_list.item_selected.connect(_on_race_selected)
	panel_rect.add_child(_race_list)

	# === MIDDLE COLUMN: standard-array ability assignment ===
	var stats_label := Label.new()
	stats_label.text = "Ability Scores"
	stats_label.position = Vector2(384, 52)
	stats_label.size = Vector2(300, 22)
	_style_label(stats_label, 14, Color.WHITE)
	panel_rect.add_child(stats_label)

	var hint := Label.new()
	hint.text = "Standard array: 15, 14, 13, 12, 10, 8.\nPicking a value already in use swaps the two scores."
	hint.position = Vector2(384, 78)
	hint.size = Vector2(310, 44)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(hint, 11, COLOR_HINT)
	panel_rect.add_child(hint)

	var row_y := 136
	for stat in STATS:
		var stat_label := Label.new()
		stat_label.text = STAT_LABELS[stat]
		stat_label.position = Vector2(384, row_y + 3)
		stat_label.size = Vector2(130, 26)
		_style_label(stat_label, 13, Color.WHITE)
		panel_rect.add_child(stat_label)

		var option := OptionButton.new()
		option.position = Vector2(524, row_y)
		option.size = Vector2(100, 30)
		for value in STANDARD_ARRAY:
			option.add_item(str(value))
		option.item_selected.connect(_on_stat_value_selected.bind(stat))
		panel_rect.add_child(option)
		_stat_buttons[stat] = option

		row_y += 42

	var reset_btn := Button.new()
	reset_btn.text = "Reset Scores"
	reset_btn.position = Vector2(384, row_y + 8)
	reset_btn.size = Vector2(150, 30)
	reset_btn.pressed.connect(_on_reset_stats_pressed)
	panel_rect.add_child(reset_btn)

	# === RIGHT COLUMN: class/race details tooltip ===
	var details_label := Label.new()
	details_label.text = "Details"
	details_label.position = Vector2(714, 52)
	details_label.size = Vector2(362, 22)
	_style_label(details_label, 14, Color.WHITE)
	panel_rect.add_child(details_label)

	_tooltip_label = RichTextLabel.new()
	_tooltip_label.position = Vector2(714, 78)
	_tooltip_label.size = Vector2(362, 556)
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.scroll_active = true
	panel_rect.add_child(_tooltip_label)

	# === BOTTOM: cancel / confirm ===
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.position = Vector2(714, 654)
	cancel_btn.size = Vector2(170, 42)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	panel_rect.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.position = Vector2(906, 654)
	confirm_btn.size = Vector2(170, 42)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	panel_rect.add_child(confirm_btn)

	_sync_stat_buttons()

func _style_label(label: Label, font_size: int, color: Color):
	"""Apply font size + color theme overrides to a Label."""
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

# ---------------------------------------------------------------------------
#  DATA / REFRESH
# ---------------------------------------------------------------------------

func _refresh_lists():
	"""(Re)populate the class and race lists from the databases, keeping selection."""
	var previous_class := _get_selected_id(_class_list, _class_ids)
	var previous_race := _get_selected_id(_race_list, _race_ids)

	_class_list.clear()
	_class_ids.clear()
	for class_id in ClassDatabase.get_all_class_ids():
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data == null:
			continue
		_class_ids.append(class_id)
		_class_list.add_item(class_data.display_name)

	_race_list.clear()
	_race_ids.clear()
	for race_id in RaceDatabase.get_all_race_ids():
		var race_data = RaceDatabase.get_race_data(race_id)
		if race_data == null:
			continue
		_race_ids.append(race_id)
		_race_list.add_item(race_data.display_name)

	_select_id_or_first(_class_list, _class_ids, previous_class)
	_select_id_or_first(_race_list, _race_ids, previous_race)
	_update_tooltip()

func _select_id_or_first(list: ItemList, ids: Array, wanted_id: String):
	"""Select wanted_id in the list if present, otherwise the first entry."""
	if ids.is_empty():
		return
	var index := maxi(ids.find(wanted_id), 0)
	list.select(index)

func _get_selected_id(list: ItemList, ids: Array) -> String:
	"""Get the id behind the list's current selection ('' if none)."""
	if list == null:
		return ""
	var selected := list.get_selected_items()
	if selected.is_empty() or selected[0] >= ids.size():
		return ""
	return ids[selected[0]]

func _update_tooltip():
	"""Show the selected class and race details in the tooltip label."""
	if _tooltip_label == null:
		return
	var text := ""
	var class_data = ClassDatabase.get_class_data(_get_selected_id(_class_list, _class_ids))
	if class_data:
		text += class_data.get_tooltip_text()
	var race_data = RaceDatabase.get_race_data(_get_selected_id(_race_list, _race_ids))
	if race_data:
		if text != "":
			text += "\n"
		text += race_data.get_tooltip_text()
	_tooltip_label.text = text

# ---------------------------------------------------------------------------
#  STANDARD-ARRAY ASSIGNMENT
# ---------------------------------------------------------------------------

func _reset_stat_assignment():
	"""Reset the ability assignment to the default standard-array spread."""
	for i in range(STATS.size()):
		_stat_values[STATS[i]] = STANDARD_ARRAY[i]

func _sync_stat_buttons():
	"""Point every OptionButton at the standard-array entry its stat currently holds."""
	for stat in _stat_buttons:
		var index: int = STANDARD_ARRAY.find(_stat_values[stat])
		if index >= 0:
			_stat_buttons[stat].select(index)

# ---------------------------------------------------------------------------
#  SIGNAL HANDLERS
# ---------------------------------------------------------------------------

func _on_class_selected(_index: int):
	"""Class list selection changed - refresh the details tooltip."""
	_update_tooltip()

func _on_race_selected(_index: int):
	"""Race list selection changed - refresh the details tooltip."""
	_update_tooltip()

func _on_stat_value_selected(index: int, stat: String):
	"""Assign a standard-array value to a stat; swap with whichever stat held it
	before (duplicate prevention - the six values always form a permutation)."""
	var new_value: int = STANDARD_ARRAY[index]
	var old_value: int = _stat_values[stat]
	if new_value == old_value:
		return
	for other_stat in STATS:
		if other_stat != stat and _stat_values[other_stat] == new_value:
			_stat_values[other_stat] = old_value
			break
	_stat_values[stat] = new_value
	_sync_stat_buttons()

func _on_reset_stats_pressed():
	"""Reset button - restore the default stat spread."""
	_reset_stat_assignment()
	_sync_stat_buttons()

func _on_cancel_pressed():
	"""Cancel / close - dismiss the panel without creating a character."""
	UIManager.close_panel()

func _on_confirm_pressed():
	"""Confirm - build the character (emits EventBus.character_created) and close."""
	var class_id := _get_selected_id(_class_list, _class_ids)
	var race_id := _get_selected_id(_race_list, _race_ids)
	if class_id == "" or race_id == "":
		EventBus.notify_warning("Select a class and a race first")
		return

	var character_name := _name_edit.text.strip_edges()
	if character_name == "":
		character_name = DEFAULT_NAME

	var base_stats := {}
	for stat in STATS:
		base_stats[stat] = _stat_values[stat]

	print("CharacterCreation: confirmed '", character_name, "' (", class_id, " / ", race_id, ") ", base_stats)
	CharacterBuilder.build(class_id, race_id, base_stats, character_name)
	UIManager.close_panel()
