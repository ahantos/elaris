# companion_panel.gd
# Companion management UI.  Panel id: "companions".
# Built entirely in code per Architecture Contracts §5 (no .tscn).
# Orchestrator instances this node and registers it:
#   UIManager.register_panel("companions", panel)
# Hooks called by UIManager: on_panel_opened(), on_panel_closed().
extends Control

# ── Colour palette ─────────────────────────────────────────────────────────────
const COLOR_BG      := Color(0.07, 0.07, 0.10, 0.93)
const COLOR_PANEL   := Color(0.13, 0.13, 0.19, 0.97)
const COLOR_HEADER  := Color(0.85, 0.78, 0.40)
const COLOR_POS     := Color(0.35, 0.85, 0.40)   # positive relationship
const COLOR_NEG     := Color(0.85, 0.30, 0.30)   # negative relationship
const COLOR_MID     := Color(0.75, 0.75, 0.75)
const COLOR_ROMANCE := Color(0.95, 0.55, 0.75)
const COLOR_SECTION := Color(0.20, 0.20, 0.28, 1.0)

# ── Internal state ─────────────────────────────────────────────────────────────
var _selected_companion_id: String = ""
var _companion_ids_in_list: Array  = []       # parallel to roster ItemList

# ── UI node references (built in _ready) ──────────────────────────────────────
var _roster_list:      ItemList
var _name_label:       Label
var _class_race_label: Label
var _personality_text: RichTextLabel
var _backstory_text:   RichTextLabel
var _rel_bar:          ProgressBar
var _rel_label:        Label
var _romance_label:    Label
var _party_check:      CheckBox
var _recruit_btn:      Button
var _gift_list:        ItemList
var _gift_instance_ids: Array = []            # parallel to gift ItemList
var _give_btn:         Button
var _status_label:     Label


# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready():
	"""Build the panel entirely in code."""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_signals()


func on_panel_opened():
	"""UIManager calls this when the panel is shown — refresh everything."""
	_refresh_all()


func on_panel_closed():
	"""UIManager calls this when panel is hidden."""
	pass


# ── Signal connections ─────────────────────────────────────────────────────────

func _connect_signals():
	EventBus.companion_recruited.connect(_on_companion_change)
	EventBus.companion_dismissed.connect(_on_companion_change)
	EventBus.relationship_changed.connect(_on_relationship_change)
	EventBus.romance_status_changed.connect(_on_romance_change)
	EventBus.inventory_changed.connect(_on_inventory_change)


func _on_companion_change(_companion_id: String):
	_refresh_all()

func _on_relationship_change(companion_id: String, _old: int, _new: int):
	if companion_id == _selected_companion_id:
		_refresh_detail()

func _on_romance_change(companion_id: String, _status: String):
	if companion_id == _selected_companion_id:
		_refresh_detail()

func _on_inventory_change():
	_refresh_gift_list()


# ── UI Construction ────────────────────────────────────────────────────────────

func _build_ui():
	"""Assemble all child nodes."""

	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# Centered content panel (1760×900 for 1920×1080 design)
	var panel_rect := ColorRect.new()
	panel_rect.color = COLOR_PANEL
	panel_rect.set_anchors_preset(Control.PRESET_CENTER)
	panel_rect.size = Vector2(1760, 900)
	panel_rect.position = Vector2(-880, -450)
	add_child(panel_rect)

	# Title bar
	var title := Label.new()
	title.text = "Companions"
	title.add_theme_color_override("font_color", COLOR_HEADER)
	title.add_theme_font_size_override("font_size", 26)
	title.position = Vector2(-860, -445)
	title.set_anchors_preset(Control.PRESET_CENTER)
	add_child(title)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.position = Vector2(800, -445)
	close_btn.set_anchors_preset(Control.PRESET_CENTER)
	close_btn.pressed.connect(_close_panel)
	add_child(close_btn)

	# Left column — roster (x relative to panel centre)
	_build_roster_column()

	# Right column — detail
	_build_detail_column()

	# Status bar at bottom
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", COLOR_MID)
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_status_label.position = Vector2(-860, 420)
	add_child(_status_label)


func _build_roster_column():
	"""Left side: ItemList of all companions."""
	var lbl := Label.new()
	lbl.text = "Roster"
	lbl.add_theme_color_override("font_color", COLOR_HEADER)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(-860, -410)
	add_child(lbl)

	_roster_list = ItemList.new()
	_roster_list.set_anchors_preset(Control.PRESET_CENTER)
	_roster_list.position = Vector2(-860, -390)
	_roster_list.size = Vector2(380, 800)
	_roster_list.item_selected.connect(_on_roster_selected)
	add_child(_roster_list)


func _build_detail_column():
	"""Right side: companion detail, relationship bar, recruit/dismiss, gift section."""
	var x_off: float = -440.0   # right panel starts here (relative to center)

	# Name
	_name_label = Label.new()
	_name_label.text = "Select a companion"
	_name_label.add_theme_color_override("font_color", COLOR_HEADER)
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.set_anchors_preset(Control.PRESET_CENTER)
	_name_label.position = Vector2(x_off, -410)
	add_child(_name_label)

	# Class / race line
	_class_race_label = Label.new()
	_class_race_label.text = ""
	_class_race_label.add_theme_color_override("font_color", COLOR_MID)
	_class_race_label.set_anchors_preset(Control.PRESET_CENTER)
	_class_race_label.position = Vector2(x_off, -382)
	add_child(_class_race_label)

	# Personality
	var pers_lbl := Label.new()
	pers_lbl.text = "Personality"
	pers_lbl.add_theme_color_override("font_color", COLOR_HEADER)
	pers_lbl.set_anchors_preset(Control.PRESET_CENTER)
	pers_lbl.position = Vector2(x_off, -355)
	add_child(pers_lbl)

	_personality_text = RichTextLabel.new()
	_personality_text.set_anchors_preset(Control.PRESET_CENTER)
	_personality_text.position = Vector2(x_off, -335)
	_personality_text.size = Vector2(1300, 80)
	_personality_text.bbcode_enabled = false
	_personality_text.fit_content = false
	add_child(_personality_text)

	# Backstory
	var back_lbl := Label.new()
	back_lbl.text = "Backstory"
	back_lbl.add_theme_color_override("font_color", COLOR_HEADER)
	back_lbl.set_anchors_preset(Control.PRESET_CENTER)
	back_lbl.position = Vector2(x_off, -248)
	add_child(back_lbl)

	_backstory_text = RichTextLabel.new()
	_backstory_text.set_anchors_preset(Control.PRESET_CENTER)
	_backstory_text.position = Vector2(x_off, -228)
	_backstory_text.size = Vector2(1300, 100)
	_backstory_text.bbcode_enabled = false
	_backstory_text.fit_content = false
	add_child(_backstory_text)

	# Relationship bar
	var rel_lbl := Label.new()
	rel_lbl.text = "Relationship"
	rel_lbl.add_theme_color_override("font_color", COLOR_HEADER)
	rel_lbl.set_anchors_preset(Control.PRESET_CENTER)
	rel_lbl.position = Vector2(x_off, -118)
	add_child(rel_lbl)

	_rel_bar = ProgressBar.new()
	_rel_bar.set_anchors_preset(Control.PRESET_CENTER)
	_rel_bar.position = Vector2(x_off, -98)
	_rel_bar.size     = Vector2(600, 22)
	_rel_bar.min_value = -100
	_rel_bar.max_value = 100
	_rel_bar.value     = 0
	add_child(_rel_bar)

	_rel_label = Label.new()
	_rel_label.text = "0"
	_rel_label.add_theme_color_override("font_color", COLOR_MID)
	_rel_label.set_anchors_preset(Control.PRESET_CENTER)
	_rel_label.position = Vector2(x_off + 610, -98)
	add_child(_rel_label)

	# Romance status
	_romance_label = Label.new()
	_romance_label.text = ""
	_romance_label.add_theme_color_override("font_color", COLOR_ROMANCE)
	_romance_label.set_anchors_preset(Control.PRESET_CENTER)
	_romance_label.position = Vector2(x_off, -68)
	add_child(_romance_label)

	# In Party checkbox
	_party_check = CheckBox.new()
	_party_check.text = "In Party"
	_party_check.set_anchors_preset(Control.PRESET_CENTER)
	_party_check.position = Vector2(x_off, -38)
	_party_check.toggled.connect(_on_party_toggled)
	add_child(_party_check)

	# Recruit (debug) button
	_recruit_btn = Button.new()
	_recruit_btn.text = "[Recruit — Debug]"
	_recruit_btn.set_anchors_preset(Control.PRESET_CENTER)
	_recruit_btn.position = Vector2(x_off + 160, -38)
	_recruit_btn.pressed.connect(_on_recruit_pressed)
	add_child(_recruit_btn)

	# ── Gift section ──────────────────────────────────────────────────
	var gift_lbl := Label.new()
	gift_lbl.text = "Give Gift"
	gift_lbl.add_theme_color_override("font_color", COLOR_HEADER)
	gift_lbl.set_anchors_preset(Control.PRESET_CENTER)
	gift_lbl.position = Vector2(x_off, 0)
	add_child(gift_lbl)

	_gift_list = ItemList.new()
	_gift_list.set_anchors_preset(Control.PRESET_CENTER)
	_gift_list.position = Vector2(x_off, 22)
	_gift_list.size = Vector2(860, 300)
	add_child(_gift_list)

	_give_btn = Button.new()
	_give_btn.text = "Give Selected Item"
	_give_btn.set_anchors_preset(Control.PRESET_CENTER)
	_give_btn.position = Vector2(x_off, 330)
	_give_btn.pressed.connect(_on_give_pressed)
	add_child(_give_btn)


# ── Refresh helpers ────────────────────────────────────────────────────────────

func _refresh_all():
	"""Rebuild roster list and detail panel."""
	_refresh_roster()
	_refresh_detail()
	_refresh_gift_list()


func _refresh_roster():
	"""Rebuild the companion roster ItemList."""
	_roster_list.clear()
	_companion_ids_in_list.clear()

	var companions: Array = CompanionManager.get_companions()
	# Sort by display name for consistency
	companions.sort_custom(func(a, b): return a.display_name < b.display_name)

	for defn in companions:
		var cid: String = defn.companion_id
		var state: Dictionary = CompanionManager.companion_states.get(cid, {})
		var suffix: String = ""
		if state.get("in_party", false):
			suffix = " [PARTY]"
		elif state.get("recruited", false):
			suffix = " (recruited)"
		else:
			suffix = " (not recruited)"

		_roster_list.add_item("%s%s" % [defn.display_name, suffix])
		_companion_ids_in_list.append(cid)

		# Re-select previously selected
		if cid == _selected_companion_id:
			_roster_list.select(_companion_ids_in_list.size() - 1)


func _refresh_detail():
	"""Update detail widgets for the selected companion."""
	if _selected_companion_id == "":
		_name_label.text       = "Select a companion"
		_class_race_label.text = ""
		_personality_text.text = ""
		_backstory_text.text   = ""
		_rel_bar.value         = 0
		_rel_label.text        = "0"
		_romance_label.text    = ""
		_party_check.set_pressed_no_signal(false)
		_party_check.disabled  = true
		_recruit_btn.visible   = false
		_give_btn.disabled     = true
		return

	var cid   = _selected_companion_id
	var defn: Dictionary  = CompanionManager.companion_definitions.get(cid, {})
	var state: Dictionary = CompanionManager.companion_states.get(cid, {})

	if defn.is_empty():
		return

	_name_label.text = defn.get("display_name", cid)
	_class_race_label.text = "%s %s" % [
		defn.get("race_id",  "?").capitalize(),
		defn.get("class_id", "?").capitalize()
	]
	_personality_text.text = defn.get("personality", "")
	_backstory_text.text   = defn.get("backstory",   "")

	var rel: int = state.get("relationship", 0)
	_rel_bar.value = rel
	_rel_label.text = "%+d" % rel
	_rel_label.add_theme_color_override("font_color",
		COLOR_POS if rel > 0 else (COLOR_NEG if rel < 0 else COLOR_MID))

	var romance: String = state.get("romance_status", "none")
	if romance != "none" and defn.get("romanceable", false):
		_romance_label.text = "Romance: %s" % romance.capitalize()
	else:
		_romance_label.text = "(not romanceable)" if not defn.get("romanceable", false) else ""

	var recruited: bool = state.get("recruited", false)
	var in_party:  bool = state.get("in_party",  false)

	_party_check.set_pressed_no_signal(in_party)
	_party_check.disabled = not recruited

	# Recruit debug button: show only when not yet recruited
	_recruit_btn.visible  = not recruited

	_give_btn.disabled = not recruited


func _refresh_gift_list():
	"""Rebuild the gift ItemList from current inventory."""
	_gift_list.clear()
	_gift_instance_ids.clear()

	for item_instance in InventoryManager.items:
		if not item_instance.has("item_data") or not item_instance.has("instance_id"):
			continue
		var idata = item_instance.item_data
		var label_text: String = ""
		if "item_name" in idata:
			label_text = idata.item_name
		elif idata.has_method("get_item_name"):
			label_text = idata.get_item_name()
		else:
			label_text = str(item_instance.get("instance_id", "???"))

		var stack: int = item_instance.get("stack_count", 1)
		if stack > 1:
			label_text += " x%d" % stack

		_gift_list.add_item(label_text)
		_gift_instance_ids.append(item_instance.instance_id)


# ── Action callbacks ───────────────────────────────────────────────────────────

func _on_roster_selected(index: int):
	if index < 0 or index >= _companion_ids_in_list.size():
		return
	_selected_companion_id = _companion_ids_in_list[index]
	_refresh_detail()
	_refresh_gift_list()


func _on_party_toggled(pressed: bool):
	if _selected_companion_id == "":
		return
	if pressed:
		CompanionManager.recruit(_selected_companion_id)
	else:
		CompanionManager.dismiss(_selected_companion_id)
	_refresh_roster()
	_refresh_detail()


func _on_recruit_pressed():
	"""Debug recruit button: recruits the selected companion directly."""
	if _selected_companion_id == "":
		return
	CompanionManager.recruit(_selected_companion_id)
	_refresh_all()


func _on_give_pressed():
	if _selected_companion_id == "":
		_set_status("No companion selected.")
		return

	var selected_items = _gift_list.get_selected_items()
	if selected_items.is_empty():
		_set_status("Select an item to give.")
		return

	var list_idx: int = selected_items[0]
	if list_idx >= _gift_instance_ids.size():
		return

	var instance_id: String = _gift_instance_ids[list_idx]
	var item_instance: Dictionary = InventoryManager.get_item(instance_id)
	if item_instance.is_empty():
		_set_status("Item not found in inventory.")
		return

	var ok = CompanionManager.give_gift(_selected_companion_id, item_instance)
	if ok:
		_set_status("Gift given!")
	else:
		_set_status("Could not give gift.")

	_refresh_all()


func _close_panel():
	if UIManager and UIManager.has_method("close_panel"):
		UIManager.close_panel("companions")
	else:
		hide()


func _set_status(msg: String):
	if is_instance_valid(_status_label):
		_status_label.text = msg
