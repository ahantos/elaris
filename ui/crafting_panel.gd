# crafting_panel.gd
# Crafting UI panel. Panel id: "crafting".
# Built entirely in code per contracts §5 (no .tscn).
# Orchestrator instances this node and calls UIManager.register_panel("crafting", panel).
# The orchestrator (or game code) may set `current_station` before calling
# UIManager.open_panel("crafting") to pre-select a station tab.
# NOTE: All four station tabs are accessible from this panel.
#       Station-locking (e.g. only show Forge when near a forge) is a future integration task.
extends Control

# --- Public property: set before opening to pre-select a station ---
var current_station: String = "forge"

# Station definitions (id, display label)
const STATIONS := [
	["forge",            "Forge"],
	["alchemy_table",    "Alchemy"],
	["enchanting_table", "Enchanting"],
	["cooking_fire",     "Cooking"],
]

# --- Internal state ---
var _selected_recipe_id: String = ""
var _show_unlearned: bool = false

# --- UI nodes (built in _ready) ---
var _station_buttons: Dictionary = {}   # station_id -> Button
var _recipe_list: ItemList
var _detail_label: RichTextLabel
var _craft_button: Button
var _toggle_unlearned: Button
var _result_label: Label
var _recipe_ids_in_list: Array = []     # parallel to _recipe_list indices

# --- Colors ---
const COLOR_BG      := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_PANEL   := Color(0.14, 0.14, 0.20, 0.97)
const COLOR_CRAFTABLE   := Color(0.3, 0.9, 0.3)
const COLOR_UNCRAFTABLE := Color(0.9, 0.3, 0.3)
const COLOR_UNLEARNED   := Color(0.5, 0.5, 0.5)
const COLOR_HEADER  := Color(0.85, 0.75, 0.4)

func _ready():
	"""Build the entire panel in code. Call on instantiation."""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_event_bus()

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
	panel_rect.custom_minimum_size = Vector2(900, 650)
	panel_rect.offset_left   = -450
	panel_rect.offset_top    = -325
	panel_rect.offset_right  =  450
	panel_rect.offset_bottom =  325
	add_child(panel_rect)

	# --- title ---
	var title := Label.new()
	title.text = "Crafting"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(900, 32)
	_style_label(title, 20, COLOR_HEADER)
	panel_rect.add_child(title)

	# --- close button ---
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(864, 8)
	close_btn.size = Vector2(28, 28)
	close_btn.pressed.connect(_on_close_pressed)
	panel_rect.add_child(close_btn)

	# --- station tab row ---
	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(8, 44)
	tab_row.size = Vector2(884, 36)
	panel_rect.add_child(tab_row)

	for entry in STATIONS:
		var sid: String  = entry[0]
		var slabel: String = entry[1]
		var btn := Button.new()
		btn.text = slabel
		btn.custom_minimum_size = Vector2(200, 34)
		btn.pressed.connect(_on_station_tab_pressed.bind(sid))
		tab_row.add_child(btn)
		_station_buttons[sid] = btn

	# --- toggle unlearned ---
	_toggle_unlearned = Button.new()
	_toggle_unlearned.text = "Show All Recipes"
	_toggle_unlearned.toggle_mode = true
	_toggle_unlearned.position = Vector2(8, 86)
	_toggle_unlearned.size = Vector2(200, 26)
	_toggle_unlearned.toggled.connect(_on_toggle_unlearned)
	panel_rect.add_child(_toggle_unlearned)

	# --- recipe list (left column) ---
	var list_label := Label.new()
	list_label.text = "Recipes"
	list_label.position = Vector2(8, 116)
	list_label.size = Vector2(340, 24)
	_style_label(list_label, 13, Color.WHITE)
	panel_rect.add_child(list_label)

	_recipe_list = ItemList.new()
	_recipe_list.position = Vector2(8, 140)
	_recipe_list.size = Vector2(340, 460)
	_recipe_list.item_selected.connect(_on_recipe_selected)
	panel_rect.add_child(_recipe_list)

	# --- detail panel (right column) ---
	var detail_label_header := Label.new()
	detail_label_header.text = "Recipe Details"
	detail_label_header.position = Vector2(358, 116)
	detail_label_header.size = Vector2(530, 24)
	_style_label(detail_label_header, 13, Color.WHITE)
	panel_rect.add_child(detail_label_header)

	_detail_label = RichTextLabel.new()
	_detail_label.position = Vector2(358, 140)
	_detail_label.size = Vector2(530, 380)
	_detail_label.bbcode_enabled = true
	_detail_label.text = "Select a recipe to see details."
	panel_rect.add_child(_detail_label)

	# --- craft button ---
	_craft_button = Button.new()
	_craft_button.text = "Craft"
	_craft_button.position = Vector2(358, 530)
	_craft_button.size = Vector2(530, 44)
	_craft_button.disabled = true
	_craft_button.pressed.connect(_on_craft_pressed)
	panel_rect.add_child(_craft_button)

	# --- result notification label ---
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.position = Vector2(358, 580)
	_result_label.size = Vector2(530, 28)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_rect.add_child(_result_label)

func _style_label(lbl: Label, font_size: int, color: Color):
	"""Apply common label style."""
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)

# ---------------------------------------------------------------------------
#  EVENT BUS CONNECTIONS
# ---------------------------------------------------------------------------

func _connect_event_bus():
	EventBus.ui_notification.connect(_on_ui_notification)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.item_crafted.connect(_on_item_crafted)

# ---------------------------------------------------------------------------
#  PANEL LIFECYCLE HOOKS  (called by UIManager)
# ---------------------------------------------------------------------------

func on_panel_opened():
	"""Refresh data every time the panel is opened."""
	_result_label.text = ""
	_refresh_station_tabs()
	_populate_recipe_list()

func on_panel_closed():
	"""Optional cleanup."""
	_selected_recipe_id = ""

# ---------------------------------------------------------------------------
#  STATION TABS
# ---------------------------------------------------------------------------

func _refresh_station_tabs():
	"""Highlight the active station tab button."""
	for sid in _station_buttons:
		var btn: Button = _station_buttons[sid]
		if sid == current_station:
			btn.add_theme_color_override("font_color", COLOR_HEADER)
		else:
			btn.remove_theme_color_override("font_color")

func _on_station_tab_pressed(station_id: String):
	current_station = station_id
	_selected_recipe_id = ""
	_refresh_station_tabs()
	_populate_recipe_list()
	_clear_detail()

# ---------------------------------------------------------------------------
#  RECIPE LIST
# ---------------------------------------------------------------------------

func _populate_recipe_list():
	"""Fill the ItemList with recipes for the current station."""
	_recipe_list.clear()
	_recipe_ids_in_list.clear()

	var station_recipes: Array = RecipeDatabase.get_recipes_for_station(current_station)
	# Sort: known first, then by display_name
	station_recipes.sort_custom(func(a, b):
		var ka: bool = CraftingManager.knows_recipe(a.recipe_id)
		var kb: bool = CraftingManager.knows_recipe(b.recipe_id)
		if ka != kb:
			return ka  # known first
		return a.get("display_name", "") < b.get("display_name", "")
	)

	for recipe in station_recipes:
		var rid: String  = recipe.recipe_id
		var known: bool  = CraftingManager.knows_recipe(rid)

		if not known and not _show_unlearned:
			continue

		var check: Dictionary = {}
		if known:
			check = CraftingManager.can_craft(rid)

		var display: String = recipe.get("display_name", rid)
		var idx: int = _recipe_list.add_item(display)
		_recipe_ids_in_list.append(rid)

		if not known:
			_recipe_list.set_item_custom_fg_color(idx, COLOR_UNLEARNED)
			_recipe_list.set_item_disabled(idx, false)  # still selectable for viewing
		elif check.get("ok", false):
			_recipe_list.set_item_custom_fg_color(idx, COLOR_CRAFTABLE)
		else:
			_recipe_list.set_item_custom_fg_color(idx, COLOR_UNCRAFTABLE)

func _on_recipe_selected(index: int):
	if index < 0 or index >= _recipe_ids_in_list.size():
		return
	_selected_recipe_id = _recipe_ids_in_list[index]
	_refresh_detail(_selected_recipe_id)

# ---------------------------------------------------------------------------
#  DETAIL PANEL
# ---------------------------------------------------------------------------

func _refresh_detail(recipe_id: String):
	"""Update the detail RichTextLabel and craft button state."""
	var recipe := RecipeDatabase.get_recipe(recipe_id)
	if recipe.is_empty():
		_clear_detail()
		return

	var known: bool         = CraftingManager.knows_recipe(recipe_id)
	var check: Dictionary   = CraftingManager.can_craft(recipe_id) if known else {"ok": false, "missing": []}
	var is_enchant: bool    = recipe.get("is_enchant", false)

	var bb := ""
	bb += "[b][color=#D4B960]%s[/color][/b]\n" % recipe.get("display_name", recipe_id)
	bb += "[color=#AAAAAA]Station: %s[/color]\n\n" % recipe.get("station", "?")

	if not known:
		bb += "[color=#888888][i]Recipe not yet learned.[/i][/color]\n\n"

	# Inputs
	var inputs: Array = recipe.get("inputs", [])
	if inputs.is_empty():
		bb += "[b]Inputs:[/b] (none)\n"
	else:
		bb += "[b]Inputs:[/b]\n"
		for inp in inputs:
			var iid: String = inp.item_id
			var need: int   = inp.count
			var have: int   = CraftingManager._count_item_in_inventory(iid)
			var col: String = "#55FF55" if have >= need else "#FF5555"
			bb += "  • %s  [color=%s]%d/%d[/color]\n" % [iid, col, have, need]

	# Gold cost
	var gold_cost: int = recipe.get("gold_cost", 0)
	if gold_cost > 0:
		var gold_col: String = "#55FF55" if InventoryManager.gold >= gold_cost else "#FF5555"
		bb += "\n[b]Gold Cost:[/b] [color=%s]%d[/color] (have %d)\n" % [gold_col, gold_cost, InventoryManager.gold]

	# Level requirement
	var req_lvl: int = recipe.get("required_player_level", 1)
	if req_lvl > 1:
		var plvl := CraftingManager._get_player_level()
		var lvl_col: String = "#55FF55" if plvl >= req_lvl else "#FF5555"
		bb += "[b]Required Level:[/b] [color=%s]%d[/color]\n" % [lvl_col, req_lvl]

	# Output / enchant info
	if is_enchant:
		var slot: String    = recipe.get("enchant_slot", "main_hand")
		var plus: int       = recipe.get("plus_level", 1)
		bb += "\n[b]Effect:[/b] Enchant equipped item in [i]%s[/i] slot to [color=#AADDFF]+%d magic[/color] (caps at +3)\n" % [slot, plus]
	else:
		var out_id: String  = recipe.get("output_item_id", "")
		var out_ct: int     = recipe.get("output_count", 1)
		bb += "\n[b]Output:[/b] %s" % out_id
		if out_ct > 1:
			bb += " ×%d" % out_ct
		bb += "\n"

	# Description
	var desc: String = recipe.get("description", "")
	if desc != "":
		bb += "\n[color=#BBBBBB][i]%s[/i][/color]\n" % desc

	# Missing items warning
	if known and not check.ok:
		bb += "\n[color=#FF7777][b]Cannot craft:[/b][/color]\n"
		for m in check.missing:
			if m.has("reason"):
				bb += "  • %s\n" % m.reason
			elif m.item_id != "" and m.item_id != "gold":
				bb += "  • %s: need %d, have %d\n" % [m.item_id, m.needed, m.have]

	_detail_label.text = bb

	# Craft button
	_craft_button.disabled = not (known and check.ok)
	if not known:
		_craft_button.text = "Recipe Not Learned"
	elif check.ok:
		if is_enchant:
			_craft_button.text = "Enchant"
		else:
			_craft_button.text = "Craft"
	else:
		_craft_button.text = "Cannot Craft"

func _clear_detail():
	_detail_label.text = "Select a recipe to see details."
	_craft_button.disabled = true
	_craft_button.text = "Craft"

# ---------------------------------------------------------------------------
#  ACTIONS
# ---------------------------------------------------------------------------

func _on_craft_pressed():
	if _selected_recipe_id == "":
		return
	var result := CraftingManager.craft(_selected_recipe_id)
	if result.is_empty():
		_set_result("Crafting failed.", Color.RED)
	else:
		var recipe := RecipeDatabase.get_recipe(_selected_recipe_id)
		_set_result("Crafted: %s" % recipe.get("display_name", _selected_recipe_id), COLOR_CRAFTABLE)
	# Refresh list and detail after crafting
	_populate_recipe_list()
	_refresh_detail(_selected_recipe_id)

func _on_close_pressed():
	if has_method("hide"):
		hide()
	elif get_parent() and get_parent().has_method("close_panel"):
		get_parent().close_panel("crafting")

func _on_toggle_unlearned(pressed: bool):
	_show_unlearned = pressed
	_toggle_unlearned.text = "Hide Unknown" if pressed else "Show All Recipes"
	_populate_recipe_list()

# ---------------------------------------------------------------------------
#  EVENT BUS CALLBACKS
# ---------------------------------------------------------------------------

func _on_ui_notification(_msg: String, _type: String):
	pass  # panel uses its own result label; global notifications handled by HUD

func _on_inventory_changed():
	# Re-tint the recipe list when inventory changes (gold or items gained/lost)
	if visible:
		_populate_recipe_list()
		if _selected_recipe_id != "":
			_refresh_detail(_selected_recipe_id)

func _on_item_crafted(_recipe_id: String, _item_instance):
	# Handled by on_craft_pressed; no extra action needed
	pass

# ---------------------------------------------------------------------------
#  HELPERS
# ---------------------------------------------------------------------------

func _set_result(text: String, color: Color):
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)
	# Auto-clear after a few seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(_result_label):
		_result_label.text = ""
