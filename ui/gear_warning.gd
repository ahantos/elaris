# gear_warning.gd
# The HUD's warning about gear (scenes/ui/gear_warning.tscn): a line for every
# piece its combatant has in use that is broken or down to its last notch,
# the broken ones first. It sits just above the bottom bar, on the left, and
# shows nothing while every piece in use has more than one notch.
# Display only: the lines are DurabilityManager.get_warnings for what the
# combatant has in use (Combatant.get_wear_pieces).
extends Control

const MAX_LINES: int = 4
const GAP: float = 10.0
const LEFT: float = 20.0

const COLOR_BROKEN := Color(0.95, 0.4, 0.35)
const COLOR_LAST := Color(0.95, 0.72, 0.35)

# Whose gear this warns about, and the part of the HUD (the bottom bar) it sits above
var combatant: Combatant = null
var _keep_clear: Control = null

@onready var _panel: PanelContainer = %Panel
@onready var _lines: VBoxContainer = %Lines

func _ready():
	_panel.visible = false

func setup(p_combatant: Combatant, keep_clear: Control = null):
	"""Give the warning the combatant whose gear it watches and the bottom bar"""
	combatant = p_combatant
	_keep_clear = keep_clear
	refresh()

func _process(_delta):
	refresh()

func is_showing() -> bool:
	return _panel.visible

func get_lines() -> Array[String]:
	"""The lines on show, top to bottom: for checks"""
	var lines: Array[String] = []
	if _panel.visible:
		for label in _lines.get_children():
			if label.visible:
				lines.append(label.text)
	return lines

func refresh():
	"""Show what is broken or on its last notch among the gear in use, or nothing"""
	var warnings: Array = []
	if is_instance_valid(combatant) and combatant.stats != null:
		warnings = DurabilityManager.get_warnings(combatant.get_wear_pieces())
	if warnings.is_empty():
		_panel.visible = false
		return

	var shown: int = mini(warnings.size(), MAX_LINES)
	for index in range(_lines.get_child_count()):
		var label: Label = _lines.get_child(index)
		label.visible = index < shown
		if index >= shown:
			continue
		var warning: Dictionary = warnings[index]
		label.text = str(warning.text)
		if index == MAX_LINES - 1 and warnings.size() > MAX_LINES:
			label.text = "and %d more worn pieces" % (warnings.size() - MAX_LINES + 1)
		label.add_theme_color_override("font_color", COLOR_BROKEN if warning.broken else COLOR_LAST)
	_panel.visible = true
	_panel.reset_size()

	var floor_y: float = get_viewport_rect().end.y
	if is_instance_valid(_keep_clear):
		floor_y = _keep_clear.get_global_rect().position.y
	_panel.position = Vector2(LEFT, floor_y - GAP - _panel.size.y)
