# item_tooltip.gd
# What the character sheet shows beside an item the pointer rests on
# (scenes/ui/item_tooltip.tscn): its name, what it does, and for a piece that
# wears its condition - the segmented bar, the notches and marks in words, its
# debuffs and buffs with what each does, and the names of its plain wear.
# Display only: the sheet hands it the words (CharacterScreen._item_tooltip_parts)
# and the piece.
extends PanelContainer

@onready var _name: Label = %Name
@onready var _body: Label = %Body
@onready var _condition_box: VBoxContainer = %ConditionBox
@onready var _bar: Control = %Bar
@onready var _condition: Label = %Condition
@onready var _debuffs: Label = %Debuffs
@onready var _buffs: Label = %Buffs
@onready var _wear: Label = %Wear
@onready var _footer: Label = %Footer

const COLOR_CONDITION := Color(0.88, 0.88, 0.92)
const COLOR_BROKEN := Color(0.92, 0.3, 0.25)

func show_item(item_instance: Dictionary, parts: Dictionary):
	"""Fill the tooltip. parts: {title, body, condition, broken, debuffs, buffs,
	wear, footer} - a String for the title, the condition and the wear, a list
	of lines for the rest. Lines that are empty take no room."""
	_name.text = str(parts.get("title", ""))
	_set_lines(_body, parts.get("body", []))
	var condition: String = str(parts.get("condition", ""))
	_condition_box.visible = condition != ""
	_bar.show_item(item_instance)
	_condition.text = condition
	_condition.add_theme_color_override("font_color", COLOR_BROKEN if parts.get("broken", false) else COLOR_CONDITION)
	_set_lines(_debuffs, parts.get("debuffs", []))
	_set_lines(_buffs, parts.get("buffs", []))
	_wear.text = str(parts.get("wear", ""))
	_wear.visible = _wear.text != ""
	_set_lines(_footer, parts.get("footer", []))
	reset_size()

func get_lines() -> Array[String]:
	"""The text on show, top to bottom: for checks"""
	var lines: Array[String] = []
	for label in [_name, _body, _condition, _debuffs, _buffs, _wear, _footer]:
		if label.is_visible_in_tree() and label.text != "":
			lines.append_array(label.text.split("\n"))
	return lines

func get_bar() -> Control:
	"""The segmented bar, for checks"""
	return _bar

func _set_lines(label: Label, lines):
	label.text = "\n".join(lines)
	label.visible = label.text != ""
