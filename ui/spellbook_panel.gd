# spellbook_panel.gd
# Spellbook UI panel. Panel id: "spellbook".
# Built entirely in code per contracts section 5 (no .tscn, full-rect, no pause handling).
# The orchestrator instances this node and calls UIManager.register_panel("spellbook", panel).
# Left: known spells grouped by level. Right: spell detail + per-level slot summary +
# Cast button (Cast -> SpellManager.set_pending_cast(player, spell_id) + close panel;
# the combat/targeting flow consumes the pending cast during integration).
# Non-casters get a friendly empty state instead of a spell list.
extends Control

# --- UI nodes (built in _ready) ---
var _spell_list: ItemList
var _slot_label: Label
var _detail_label: RichTextLabel
var _cast_button: Button
var _hint_label: Label

# --- State ---
var _list_spell_ids: Array = []  # parallel to _spell_list indices ("" = header row)
var _selected_spell_id: String = ""

# --- Colors ---
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_PANEL := Color(0.12, 0.12, 0.20, 0.97)
const COLOR_HEADER := Color(0.65, 0.55, 0.95)
const COLOR_CASTABLE := Color(0.85, 0.9, 1.0)
const COLOR_BLOCKED := Color(0.55, 0.55, 0.6)

const SCHOOL_COLORS := {
	"abjuration": "#7fb2e5", "conjuration": "#e5b27f", "divination": "#e5e07f",
	"enchantment": "#e57fd8", "evocation": "#e57f7f", "illusion": "#b27fe5",
	"necromancy": "#9fe57f", "transmutation": "#7fe5d8"
}


func _ready():
	"""Build the entire panel in code."""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


# === UI CONSTRUCTION ===

func _build_ui():
	"""Assemble all child nodes in code (ColorRect/Label/Button/ItemList/RichTextLabel only)."""
	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel_rect := ColorRect.new()
	panel_rect.color = COLOR_PANEL
	panel_rect.set_anchors_preset(Control.PRESET_CENTER)
	panel_rect.custom_minimum_size = Vector2(900, 650)
	panel_rect.offset_left = -450
	panel_rect.offset_top = -325
	panel_rect.offset_right = 450
	panel_rect.offset_bottom = 325
	add_child(panel_rect)

	var title := Label.new()
	title.text = "Spellbook"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(900, 32)
	_style_label(title, 20, COLOR_HEADER)
	panel_rect.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(864, 8)
	close_btn.size = Vector2(28, 28)
	close_btn.pressed.connect(_on_close_pressed)
	panel_rect.add_child(close_btn)

	# --- left column: known spells ---
	var list_label := Label.new()
	list_label.text = "Known Spells"
	list_label.position = Vector2(8, 48)
	list_label.size = Vector2(320, 24)
	_style_label(list_label, 13, Color.WHITE)
	panel_rect.add_child(list_label)

	_spell_list = ItemList.new()
	_spell_list.position = Vector2(8, 76)
	_spell_list.size = Vector2(320, 530)
	_spell_list.item_selected.connect(_on_spell_selected)
	panel_rect.add_child(_spell_list)

	# --- right column: slots + detail + cast ---
	_slot_label = Label.new()
	_slot_label.text = "Spell Slots: -"
	_slot_label.position = Vector2(340, 48)
	_slot_label.size = Vector2(552, 48)
	_slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_slot_label, 13, Color(1.0, 0.9, 0.5))
	panel_rect.add_child(_slot_label)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.position = Vector2(340, 100)
	_detail_label.size = Vector2(552, 458)
	_detail_label.scroll_active = true
	panel_rect.add_child(_detail_label)

	_cast_button = Button.new()
	_cast_button.text = "Cast"
	_cast_button.position = Vector2(340, 566)
	_cast_button.size = Vector2(552, 40)
	_cast_button.disabled = true
	_cast_button.pressed.connect(_on_cast_pressed)
	panel_rect.add_child(_cast_button)

	_hint_label = Label.new()
	_hint_label.text = "Select a spell, then Cast to ready it. ESC closes the spellbook."
	_hint_label.position = Vector2(8, 614)
	_hint_label.size = Vector2(884, 24)
	_style_label(_hint_label, 11, Color(0.6, 0.6, 0.65))
	panel_rect.add_child(_hint_label)


func _style_label(label: Label, font_size: int, color: Color):
	"""Apply consistent placeholder styling to a Label."""
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


# === UIMANAGER HOOKS ===

func on_panel_opened():
	"""Refresh spells and slots every time the panel opens (UIManager hook)."""
	_refresh()


func on_panel_closed():
	"""UIManager hook - nothing to tear down."""
	pass


# === DATA REFRESH ===

func _get_player_stats():
	"""The player's CharacterStats, or null when no player exists yet."""
	var player = GameManager.player
	if player == null or not is_instance_valid(player):
		return null
	return player.get("stats")


func _refresh():
	"""Rebuild the spell list (grouped by level), slot summary and detail pane."""
	_spell_list.clear()
	_list_spell_ids.clear()
	_selected_spell_id = ""
	_cast_button.disabled = true

	var stats = _get_player_stats()
	if stats == null:
		_show_empty_state("No adventurer found.\n\nThe spellbook will fill in once a character exists.")
		return

	# get_known_spells lazily grants class spells to casters with none learned yet
	var known: Array = SpellManager.get_known_spells(stats)
	if known.is_empty():
		_show_empty_state("You have no spellcasting ability.\n\nWizards and Clerics fill these pages as they level. Other adventurers can still use spell scrolls and wands from their inventory.")
		return

	_slot_label.text = _build_slot_summary(stats)

	# Group known spell ids by level, alphabetical within a level
	var by_level: Dictionary = {}
	for spell_id in known:
		var spell: Dictionary = SpellDatabase.get_spell(str(spell_id))
		if spell.is_empty():
			continue
		var level = int(spell.get("level", 0))
		if not by_level.has(level):
			by_level[level] = []
		by_level[level].append(spell)
	var levels: Array = by_level.keys()
	levels.sort()

	for level in levels:
		var header = "- Cantrips -" if level == 0 else "- Level %d -" % level
		var header_idx = _spell_list.add_item(header)
		_spell_list.set_item_disabled(header_idx, true)
		_spell_list.set_item_selectable(header_idx, false)
		_spell_list.set_item_custom_fg_color(header_idx, COLOR_HEADER)
		_list_spell_ids.append("")

		var group: Array = by_level[level]
		group.sort_custom(func(a, b): return str(a.get("display_name", "")) < str(b.get("display_name", "")))
		for spell in group:
			var spell_id = str(spell.get("spell_id", ""))
			var idx = _spell_list.add_item(str(spell.get("display_name", spell_id)))
			var castable = SpellManager.can_cast(GameManager.player, spell_id).get("ok", false)
			_spell_list.set_item_custom_fg_color(idx, COLOR_CASTABLE if castable else COLOR_BLOCKED)
			_list_spell_ids.append(spell_id)

	_detail_label.text = "[i]Select a spell to see its details.[/i]"


func _show_empty_state(message: String):
	"""Friendly non-caster / no-player presentation."""
	_slot_label.text = "Spell Slots: none"
	_detail_label.text = "[center]\n\n[b]The pages are blank.[/b]\n\n%s[/center]" % message


func _build_slot_summary(stats) -> String:
	"""One-line per-level slot summary, e.g. 'Cantrips: at will | L1: 2/3 | L2: 1/2'."""
	var parts: Array = ["Cantrips: at will"]
	for slot_level in range(1, 10):
		var max_slots = SpellManager.get_max_slots(stats, slot_level)
		if max_slots <= 0:
			continue
		parts.append("L%d: %d/%d" % [slot_level, SpellManager.get_remaining_slots(stats, slot_level), max_slots])
	return "Spell Slots - " + " | ".join(parts)


# === DETAIL PANE ===

func _on_spell_selected(index: int):
	"""Show the selected spell's details and enable Cast when castable."""
	if index < 0 or index >= _list_spell_ids.size():
		return
	var spell_id = str(_list_spell_ids[index])
	if spell_id == "":
		return
	_selected_spell_id = spell_id
	_detail_label.text = _build_detail_text(spell_id)
	var check = SpellManager.can_cast(GameManager.player, spell_id)
	_cast_button.disabled = not check.get("ok", false)
	_cast_button.text = "Cast" if check.get("ok", false) else "Cast (%s)" % str(check.get("reason", "unavailable"))


func _build_detail_text(spell_id: String) -> String:
	"""BBCode detail block for one spell."""
	var spell: Dictionary = SpellDatabase.get_spell(spell_id)
	if spell.is_empty():
		return "[i]Unknown spell.[/i]"

	var school = str(spell.get("school", ""))
	var school_color = str(SCHOOL_COLORS.get(school, "#ffffff"))
	var level = int(spell.get("level", 0))
	var level_text = "Cantrip" if level == 0 else "Level %d" % level

	var text = "[b][font_size=18]%s[/font_size][/b]\n" % str(spell.get("display_name", spell_id))
	text += "[color=%s]%s %s[/color]\n\n" % [school_color, level_text, school.capitalize()]
	text += "[b]Casting Time:[/b] %s\n" % str(spell.get("casting_time", "action")).capitalize().replace("_", " ")
	var range_tiles = int(spell.get("range_tiles", 0))
	text += "[b]Range:[/b] %s\n" % ("Self" if range_tiles == 0 else "%d tiles" % range_tiles)
	text += "[b]Target:[/b] %s\n" % str(spell.get("target_type", "enemy")).capitalize()
	var area = int(spell.get("area_radius_tiles", 0))
	if area > 0:
		text += "[b]Area:[/b] %d-tile radius\n" % area

	if spell.get("attack_roll", false):
		var rays = int(spell.get("attack_count", 1))
		text += "[b]Attack:[/b] spell attack%s\n" % (" x%d" % rays if rays > 1 else "")
	var save_info: Dictionary = spell.get("save", {})
	if not save_info.is_empty():
		text += "[b]Save:[/b] %s%s\n" % [str(save_info.get("stat", "dex")).to_upper(),
			" (half on save)" if save_info.get("half_on_save", false) else " negates"]
	if str(spell.get("damage_dice", "")) != "":
		text += "[b]Damage:[/b] %s %s\n" % [str(spell.get("damage_dice", "")), str(spell.get("damage_type", ""))]
	if str(spell.get("heal_dice", "")) != "":
		text += "[b]Healing:[/b] %s\n" % str(spell.get("heal_dice", ""))
	var effect_info: Dictionary = spell.get("applies_effect", {})
	if not effect_info.is_empty():
		text += "[b]Effect:[/b] %s (%d turns)\n" % [str(effect_info.get("effect_id", "")).capitalize(), int(effect_info.get("duration", 0))]
	if spell.get("concentration", false):
		text += "[b]Concentration[/b]\n"

	text += "\n[i]%s[/i]\n" % str(spell.get("description", ""))

	var check = SpellManager.can_cast(GameManager.player, spell_id)
	if check.get("ok", false):
		text += "\n[color=#60d060]Ready to cast.[/color]"
	else:
		text += "\n[color=#d06060]%s[/color]" % str(check.get("reason", "Cannot cast right now"))
	return text


# === BUTTONS ===

func _on_cast_pressed():
	"""Ready the selected spell as the player's pending cast and close the panel."""
	if _selected_spell_id == "":
		return
	var player = GameManager.player
	if player == null or not is_instance_valid(player):
		return
	SpellManager.set_pending_cast(player, _selected_spell_id)
	EventBus.ui_notification.emit("%s readied. Choose a target." % str(SpellDatabase.get_spell(_selected_spell_id).get("display_name", _selected_spell_id)), "info")
	UIManager.close_panel()


func _on_close_pressed():
	"""Close via UIManager so pause state stays centralized."""
	UIManager.close_panel()
