# notification_toasts.gd
# On-screen renderer for EventBus.ui_notification(message, type).
#
# Every system reports to the player through that signal ("Out of range!",
# "Inventory full", "Quest started", ...). Until this existed nothing drew it, so
# all of that feedback only reached the console.
#
# Owned by UIManager, which puts it on a CanvasLayer above every panel. It keeps
# running while the tree is paused, so messages raised inside paused panels
# (crafting, dialogue, companions) are visible too.
extends Control

const MAX_VISIBLE: int = 5
const LIFETIME: float = 3.5      # seconds fully visible
const FADE_TIME: float = 0.5
const TOP_OFFSET: float = 224.0   # just under the minimap
const RIGHT_MARGIN: float = 10.0
const TOAST_WIDTH: float = 420.0

const TYPE_COLORS: Dictionary = {
	"info":    Color(0.55, 0.75, 1.0),
	"success": Color(0.45, 0.9, 0.45),
	"warning": Color(1.0, 0.8, 0.3),
	"error":   Color(1.0, 0.4, 0.4),
}

var _box: VBoxContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	# A column down the right edge, under the minimap, growing downwards. The
	# centre of the screen belongs to the map and to panels; the top to the turn
	# banner and the initiative bar.
	_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_box.offset_left = -(TOAST_WIDTH + RIGHT_MARGIN)
	_box.offset_right = -RIGHT_MARGIN
	_box.offset_top = TOP_OFFSET
	_box.offset_bottom = TOP_OFFSET

	EventBus.ui_notification.connect(show_message)

func show_message(message: String, type: String = "info"):
	"""Show one toast. A repeat of the newest message refreshes it instead of stacking."""
	if message.strip_edges() == "":
		return

	var newest = _newest_toast()
	if newest != null and newest.get_meta("message", "") == message:
		_start_lifetime(newest)
		return

	while _box.get_child_count() >= MAX_VISIBLE:
		var oldest = _box.get_child(0)
		_box.remove_child(oldest)
		oldest.queue_free()

	var color: Color = TYPE_COLORS.get(type, TYPE_COLORS["info"])

	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_meta("message", message)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.92)
	style.border_color = color
	style.border_width_left = 4
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	toast.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.55))
	toast.add_child(label)

	_box.add_child(toast)
	_start_lifetime(toast)

func get_visible_messages() -> Array:
	"""Messages currently on screen, oldest first (used by the smoke test)."""
	var messages: Array = []
	for toast in _box.get_children():
		if not toast.is_queued_for_deletion():
			messages.append(str(toast.get_meta("message", "")))
	return messages

func _newest_toast():
	for i in range(_box.get_child_count() - 1, -1, -1):
		var toast = _box.get_child(i)
		if not toast.is_queued_for_deletion():
			return toast
	return null

func _start_lifetime(toast: Control):
	"""(Re)start the show-then-fade timer of a toast."""
	if toast.has_meta("tween"):
		var old_tween = toast.get_meta("tween")
		if old_tween is Tween and old_tween.is_valid():
			old_tween.kill()
	toast.modulate.a = 1.0
	var tween := toast.create_tween()
	tween.tween_interval(LIFETIME)
	tween.tween_property(toast, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(toast.queue_free)
	toast.set_meta("tween", tween)
