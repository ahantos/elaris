# action_button.gd
# One button of the action bar (scenes/ui/action_button.tscn): the number key
# that triggers it, the action's name, a line or two of detail (the weapon and
# its die, what a Dash adds) and, when the action cannot be taken, the reason.
extends Button

@onready var _key: Label = %Key
@onready var _title: Label = %Title
@onready var _detail: Label = %Detail
@onready var _reason: Label = %Reason

func show_action(key_text: String, title: String, detail: String, reason: String, selected: bool = false, hint: String = ""):
	"""Fill the button. A reason means the action is not available now: the
	button is disabled and says why. hint is the longer explanation shown when
	the mouse rests on the button."""
	_key.text = key_text
	_title.text = title
	_detail.text = detail
	_reason.text = reason
	disabled = reason != ""
	set_pressed_no_signal(selected and not disabled)
	var fade: float = 0.55 if disabled else 1.0
	_key.modulate.a = fade
	_title.modulate.a = fade
	_detail.modulate.a = fade
	tooltip_text = hint if reason == "" else "%s\n\nNot available: %s" % [hint, reason]

func get_title() -> String:
	return _title.text

func get_detail() -> String:
	return _detail.text

func get_reason() -> String:
	return _reason.text
