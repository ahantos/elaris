# dialogue_panel.gd
# Dialogue UI panel. Panel id: "dialogue" (register with pauses_game = true).
# Built entirely in code per contracts section 5 (no .tscn).
#
# Integration: when DialogueManager.start_dialogue(...) returns true, call
# UIManager.open_panel("dialogue"). The panel refreshes from
# DialogueManager.get_current_node() and closes itself (UIManager.close_panel)
# when the dialogue ends. It also listens to EventBus.dialogue_started so a
# dialogue begun while the panel is already open refreshes correctly.
#
# Layout: full-rect Control with a light dim; the dialog box itself sits in the
# bottom third of the screen (speaker name, text, dynamically rebuilt choices).
extends Control

const COLOR_DIM     := Color(0.0, 0.0, 0.0, 0.25)
const COLOR_BOX     := Color(0.10, 0.10, 0.16, 0.96)
const COLOR_SPEAKER := Color(0.85, 0.75, 0.4)
const COLOR_TEXT    := Color(0.92, 0.92, 0.92)

var _speaker_label: Label
var _text_label: RichTextLabel
var _choices_box: VBoxContainer

func _ready():
	"""Build the panel in code and hook DialogueManager session signals."""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)

func _build_ui():
	# Light dim over the whole screen (gameplay stays visible behind the box)
	var dim := ColorRect.new()
	dim.color = COLOR_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Bottom-third dialog box
	var box := ColorRect.new()
	box.color = COLOR_BOX
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 60
	box.offset_right = -60
	box.offset_top = -340
	box.offset_bottom = -24
	add_child(box)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	box.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	_speaker_label = Label.new()
	_speaker_label.text = ""
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_speaker_label.add_theme_color_override("font_color", COLOR_SPEAKER)
	layout.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = false
	_text_label.scroll_active = true
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 17)
	_text_label.add_theme_color_override("default_color", COLOR_TEXT)
	layout.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 4)
	layout.add_child(_choices_box)

# === UIManager hooks ===

func on_panel_opened():
	"""Called by UIManager when the panel opens — show the current node."""
	_refresh()

func on_panel_closed():
	"""If the panel is dismissed (e.g. ESC) mid-conversation, end the session
	cleanly so is_active() never lingers."""
	if DialogueManager.is_active():
		DialogueManager.end_dialogue()

# === Refresh ===

func _refresh():
	"""Rebuild speaker, text, and choice buttons from the current dialogue node."""
	for child in _choices_box.get_children():
		child.queue_free()

	var node: Dictionary = DialogueManager.get_current_node()
	if node.is_empty():
		_speaker_label.text = ""
		_text_label.text = "(There is no one to talk to.)"
		var leave := Button.new()
		leave.text = "Leave"
		leave.pressed.connect(_close_panel)
		_choices_box.add_child(leave)
		return

	_speaker_label.text = str(node.get("speaker", node.get("npc_name", "")))
	_text_label.text = str(node.get("text", ""))

	var choices: Array = node.get("choices", [])
	for i in range(choices.size()):
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, str(choices[i].get("text", "..."))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choices_box.add_child(button)

	# Malformed node with no choices: offer a way out instead of soft-locking.
	if choices.is_empty():
		var end_button := Button.new()
		end_button.text = "(End conversation)"
		end_button.pressed.connect(_on_end_pressed)
		_choices_box.add_child(end_button)

func _on_choice_pressed(index: int):
	DialogueManager.make_choice(index)
	# If the choice ended the dialogue, _on_dialogue_ended already closed us.
	if DialogueManager.is_active():
		_refresh()

func _on_end_pressed():
	DialogueManager.end_dialogue()

# === EventBus listeners ===

func _on_dialogue_started(_npc_id: String, _dialogue_id: String):
	if visible:
		_refresh()

func _on_dialogue_ended(_npc_id: String, _dialogue_id: String):
	_close_panel()

func _close_panel():
	# The `visible` guard prevents re-entrant close_panel() calls: UIManager hides
	# the control BEFORE invoking on_panel_closed, and on_panel_closed may itself
	# end the dialogue (which signals back into _on_dialogue_ended -> here).
	if visible and UIManager.is_panel_open("dialogue"):
		UIManager.close_panel()
