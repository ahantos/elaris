# world_map_panel.gd
# World map UI panel. Panel id: "world_map".
# Built entirely in code per contracts section 5 (no .tscn).
# Orchestrator instances this node and calls UIManager.register_panel("world_map", panel).
#
# 3x3 grid of zone buttons (locked zones greyed with a lock glyph, current zone
# highlighted), a zone detail pane, and a Travel button that calls
# ZoneManager.travel_to() and closes the panel on success (integration listens
# to EventBus.zone_changed and regenerates the dungeon).
extends Control

const COLOR_BG       := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_PANEL    := Color(0.14, 0.14, 0.20, 0.97)
const COLOR_HEADER   := Color(0.85, 0.75, 0.4)
const COLOR_CURRENT  := Color(0.95, 0.85, 0.45)
const COLOR_LOCKED   := Color(0.55, 0.55, 0.55)
const COLOR_UNLOCKED := Color(0.92, 0.92, 0.92)

var _selected_zone_id: String = ""
var _zone_buttons: Dictionary = {}  # zone_id -> Button
var _detail_label: RichTextLabel
var _travel_button: Button

func _ready():
	"""Build the panel in code."""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel_rect := ColorRect.new()
	panel_rect.color = COLOR_PANEL
	panel_rect.set_anchors_preset(Control.PRESET_CENTER)
	panel_rect.custom_minimum_size = Vector2(960, 650)
	panel_rect.offset_left = -480
	panel_rect.offset_top = -325
	panel_rect.offset_right = 480
	panel_rect.offset_bottom = 325
	add_child(panel_rect)

	var title := Label.new()
	title.text = "World Map — Elaris"
	title.position = Vector2(0, 8)
	title.size = Vector2(960, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	panel_rect.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.position = Vector2(924, 8)
	close_button.size = Vector2(28, 28)
	close_button.pressed.connect(func(): UIManager.close_panel())
	panel_rect.add_child(close_button)

	# 3x3 zone grid (zone_1..zone_9 in order)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(24, 56)
	grid.size = Vector2(520, 560)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	panel_rect.add_child(grid)

	for i in range(1, 10):
		var zone_id := "zone_%d" % i
		var button := Button.new()
		button.custom_minimum_size = Vector2(165, 170)
		button.clip_text = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_zone_pressed.bind(zone_id))
		grid.add_child(button)
		_zone_buttons[zone_id] = button

	# Detail pane
	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.position = Vector2(568, 56)
	_detail_label.size = Vector2(368, 500)
	_detail_label.scroll_active = true
	panel_rect.add_child(_detail_label)

	_travel_button = Button.new()
	_travel_button.text = "Travel"
	_travel_button.position = Vector2(568, 572)
	_travel_button.size = Vector2(368, 44)
	_travel_button.disabled = true
	_travel_button.pressed.connect(_on_travel_pressed)
	panel_rect.add_child(_travel_button)

# === UIManager hooks ===

func on_panel_opened():
	"""Refresh lock states and select the current zone whenever the panel opens."""
	if _selected_zone_id == "":
		_selected_zone_id = ZoneManager.current_zone_id
	_refresh()

# === Refresh ===

func _refresh():
	"""Restyle every zone button and re-render the selected zone's details."""
	for zone_id in _zone_buttons:
		var button: Button = _zone_buttons[zone_id]
		var zone: Dictionary = ZoneManager.get_zone(zone_id)
		if zone.is_empty():
			button.text = "?"
			button.disabled = true
			continue

		var unlocked: bool = bool(zone.get("unlocked", false))
		var is_current: bool = zone_id == ZoneManager.current_zone_id
		var label: String = str(zone.get("display_name", zone_id))
		var prefix := ""
		if is_current:
			prefix = "▶ "
		elif not unlocked:
			prefix = "🔒 "
		button.text = "%s%s\nDanger %d" % [prefix, label, int(zone.get("danger_tier", 0))]

		var color := COLOR_UNLOCKED
		if is_current:
			color = COLOR_CURRENT
		elif not unlocked:
			color = COLOR_LOCKED
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_pressed_color", color)
		button.add_theme_color_override("font_focus_color", color)

	_render_detail(_selected_zone_id)

func _on_zone_pressed(zone_id: String):
	_selected_zone_id = zone_id
	_refresh()

func _render_detail(zone_id: String):
	var zone: Dictionary = ZoneManager.get_zone(zone_id)
	if zone.is_empty():
		_detail_label.text = "[i]Select a region.[/i]"
		_travel_button.disabled = true
		return

	var unlocked: bool = bool(zone.get("unlocked", false))
	var is_current: bool = zone_id == ZoneManager.current_zone_id

	var lines: Array = []
	lines.append("[b][color=#d9bf66]%s[/color][/b]" % zone.get("display_name", zone_id))
	var status := "Current location" if is_current else ("Open to travel" if unlocked else "Locked")
	lines.append("[i]%s — danger tier %d — %s[/i]" % [status, int(zone.get("danger_tier", 0)),
		str(zone.get("biome", "?"))])
	lines.append("")
	lines.append(str(zone.get("description", "")))

	var cities: Array = zone.get("cities", [])
	if not cities.is_empty():
		lines.append("")
		lines.append("[b]Settlements[/b]")
		for city in cities:
			lines.append("  [b]%s[/b] — %s" % [city.get("name", "?"), city.get("description", "")])

	_detail_label.text = "\n".join(lines)
	_travel_button.disabled = not unlocked or is_current
	_travel_button.text = "Travel" if not is_current else "You are here"

func _on_travel_pressed():
	if _selected_zone_id == "":
		return
	if ZoneManager.travel_to(_selected_zone_id):
		UIManager.close_panel()
