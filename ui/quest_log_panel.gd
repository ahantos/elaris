# quest_log_panel.gd
# Quest log UI panel. Panel id: "quest_log".
# Built entirely in code per contracts section 5 (no .tscn).
# Orchestrator instances this node and calls UIManager.register_panel("quest_log", panel).
#
# Active/Completed tabs, quest list, and a detail pane with objective progress
# lines (x/y) and a rewards preview. Refreshes in on_panel_opened and on
# quest_advanced / quest_completed while visible.
extends Control

const COLOR_BG       := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_PANEL    := Color(0.14, 0.14, 0.20, 0.97)
const COLOR_HEADER   := Color(0.85, 0.75, 0.4)
const COLOR_DONE     := Color(0.3, 0.9, 0.3)
const COLOR_PROGRESS := Color(0.92, 0.92, 0.92)

const TAB_ACTIVE := "active"
const TAB_COMPLETED := "completed"

var _current_tab: String = TAB_ACTIVE
var _selected_quest_id: String = ""

var _tab_active_button: Button
var _tab_completed_button: Button
var _quest_list: ItemList
var _detail_label: RichTextLabel
var _quest_ids_in_list: Array = []  # parallel to _quest_list indices

func _ready():
	"""Build the panel in code and hook quest signals for live refresh."""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	EventBus.quest_advanced.connect(_on_quest_event.unbind(4))
	EventBus.quest_completed.connect(_on_quest_event.unbind(1))
	EventBus.quest_started.connect(_on_quest_event.unbind(1))
	EventBus.quest_failed.connect(_on_quest_event.unbind(1))

func _build_ui():
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
	title.text = "Quest Log"
	title.position = Vector2(0, 8)
	title.size = Vector2(900, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	panel_rect.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.position = Vector2(864, 8)
	close_button.size = Vector2(28, 28)
	close_button.pressed.connect(func(): UIManager.close_panel())
	panel_rect.add_child(close_button)

	_tab_active_button = Button.new()
	_tab_active_button.text = "Active"
	_tab_active_button.position = Vector2(16, 48)
	_tab_active_button.size = Vector2(120, 32)
	_tab_active_button.pressed.connect(_on_tab_pressed.bind(TAB_ACTIVE))
	panel_rect.add_child(_tab_active_button)

	_tab_completed_button = Button.new()
	_tab_completed_button.text = "Completed"
	_tab_completed_button.position = Vector2(144, 48)
	_tab_completed_button.size = Vector2(120, 32)
	_tab_completed_button.pressed.connect(_on_tab_pressed.bind(TAB_COMPLETED))
	panel_rect.add_child(_tab_completed_button)

	_quest_list = ItemList.new()
	_quest_list.position = Vector2(16, 92)
	_quest_list.size = Vector2(340, 542)
	_quest_list.item_selected.connect(_on_quest_selected)
	panel_rect.add_child(_quest_list)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.position = Vector2(372, 92)
	_detail_label.size = Vector2(512, 542)
	_detail_label.scroll_active = true
	panel_rect.add_child(_detail_label)

# === UIManager hooks ===

func on_panel_opened():
	"""Refresh contents whenever the panel opens."""
	_refresh()

# === Refresh ===

func _on_tab_pressed(tab: String):
	_current_tab = tab
	_selected_quest_id = ""
	_refresh()

func _on_quest_event():
	"""Any quest state change refreshes the panel while it is visible."""
	if visible:
		_refresh()

func _refresh():
	"""Rebuild the quest list for the current tab and re-render the detail pane."""
	_tab_active_button.disabled = _current_tab == TAB_ACTIVE
	_tab_completed_button.disabled = _current_tab == TAB_COMPLETED

	var quests: Array = QuestManager.get_active_quests() if _current_tab == TAB_ACTIVE \
		else QuestManager.get_completed_quests()

	_quest_list.clear()
	_quest_ids_in_list.clear()
	var selected_index := -1
	for quest in quests:
		var quest_id: String = str(quest.get("quest_id", ""))
		var label := "%s  [%s]" % [quest.get("title", quest_id), quest.get("quest_type", "side")]
		_quest_list.add_item(label)
		_quest_ids_in_list.append(quest_id)
		if quest_id == _selected_quest_id:
			selected_index = _quest_ids_in_list.size() - 1

	if quests.is_empty():
		_detail_label.text = "[i]No %s quests.[/i]" % _current_tab
		_selected_quest_id = ""
		return

	# Keep the previous selection when possible, else select the first quest.
	if selected_index == -1:
		selected_index = 0
		_selected_quest_id = str(_quest_ids_in_list[0])
	_quest_list.select(selected_index)
	_render_detail(_selected_quest_id)

func _on_quest_selected(index: int):
	if index < 0 or index >= _quest_ids_in_list.size():
		return
	_selected_quest_id = str(_quest_ids_in_list[index])
	_render_detail(_selected_quest_id)

func _render_detail(quest_id: String):
	"""Render title, description, objective x/y lines, and the rewards preview."""
	var quest: Dictionary = QuestManager.get_quest(quest_id)
	if quest.is_empty():
		_detail_label.text = ""
		return

	var lines: Array = []
	lines.append("[b][color=#d9bf66]%s[/color][/b]" % quest.get("title", quest_id))
	lines.append("[i]%s quest — %s[/i]" % [quest.get("quest_type", "side"),
		quest.get("status", "not_started")])
	lines.append("")
	lines.append(str(quest.get("description", "")))
	lines.append("")
	lines.append("[b]Objectives[/b]")

	var progress: Dictionary = quest.get("objective_progress", {})
	for objective in quest.get("objectives", []):
		var objective_id := str(objective.get("objective_id", ""))
		var required: int = int(objective.get("required_count", 1))
		var current: int = int(progress.get(objective_id, 0))
		var mark := "[color=#4ce64c]✓[/color]" if current >= required else "•"
		lines.append("  %s %s (%d/%d)" % [mark, objective.get("description", objective_id),
			current, required])

	var rewards: Dictionary = quest.get("rewards", {})
	if not rewards.is_empty():
		lines.append("")
		lines.append("[b]Rewards[/b]")
		if int(rewards.get("xp", 0)) > 0:
			lines.append("  %d XP" % int(rewards.get("xp", 0)))
		if int(rewards.get("gold", 0)) > 0:
			lines.append("  %d gold" % int(rewards.get("gold", 0)))
		for entry in rewards.get("items", []):
			lines.append("  %dx %s" % [int(entry.get("count", 1)),
				_item_display_name(str(entry.get("item_id", "")))])
		var reputation: Dictionary = rewards.get("reputation", {})
		for faction_id in reputation:
			var delta: int = int(reputation[faction_id])
			lines.append("  %s%d reputation (%s)" % ["+" if delta >= 0 else "", delta,
				_faction_display_name(str(faction_id))])

	_detail_label.text = "\n".join(lines)

func _item_display_name(item_id: String) -> String:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data != null and item_data.get("item_name") != null:
		return str(item_data.item_name)
	return item_id

func _faction_display_name(faction_id: String) -> String:
	return str(FactionManager.factions.get(faction_id, {}).get("display_name", faction_id))
