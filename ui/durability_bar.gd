# durability_bar.gd
# The segmented bar of a piece that wears (scenes/ui/durability_bar.tscn): one
# segment for each notch the piece could hold when it was made. A notch it
# still has is filled; the last of those drains from the right as wear marks
# gather towards the next lost notch; a lost notch is an empty frame; a notch
# age has taken for good is a dim stub. A broken piece is all empty frames, in
# red.
# Display only: it draws what DurabilityManager says about the piece.
extends Control

const GAP: float = 2.0

const COLOR_WHOLE := Color(0.85, 0.75, 0.4)
const COLOR_LAST := Color(0.95, 0.62, 0.3)
const COLOR_BROKEN := Color(0.92, 0.3, 0.25)
const COLOR_LOST_FILL := Color(0.16, 0.1, 0.1, 0.95)
const COLOR_LOST_EDGE := Color(0.55, 0.3, 0.28)
const COLOR_AGED := Color(0.22, 0.22, 0.26, 0.9)
const COLOR_TROUGH := Color(0.07, 0.07, 0.1, 0.95)

var _piece: Dictionary = {}

func show_item(item_instance):
	"""Show the condition of an item instance; a piece that does not wear, or
	no piece at all, hides the bar"""
	_piece = item_instance if DurabilityManager.wears(item_instance) else {}
	visible = not _piece.is_empty()
	queue_redraw()

func get_segments() -> Array:
	"""What the bar draws, left to right, a word for each segment: "full",
	"wearing" (the notch the marks are eating), "lost" or "aged". For checks."""
	var segments: Array = []
	if _piece.is_empty():
		return segments
	var notches: int = DurabilityManager.get_notches(_piece)
	var held: int = DurabilityManager.get_max_notches(_piece)
	for index in range(int(_piece.get("notches_max_original", held))):
		if index >= held:
			segments.append("aged")
		elif index >= notches:
			segments.append("lost")
		elif index == notches - 1 and DurabilityManager.get_marks(_piece) > 0:
			segments.append("wearing")
		else:
			segments.append("full")
	return segments

func get_wear_fill() -> float:
	"""How much of the notch being worn is still filled: 1.0 with no marks,
	towards 0.0 as they near the limit"""
	if _piece.is_empty():
		return 1.0
	return 1.0 - clampf(float(DurabilityManager.get_marks(_piece)) / float(maxi(1, DurabilityManager.get_marks_limit(_piece))), 0.0, 1.0)

func _draw():
	var segments: Array = get_segments()
	if segments.is_empty():
		return
	var count: int = segments.size()
	var width: float = (size.x - GAP * (count - 1)) / count
	var broken: bool = DurabilityManager.is_broken(_piece)
	var fill: Color = COLOR_LAST if DurabilityManager.is_on_last_notch(_piece) else COLOR_WHOLE
	for index in range(count):
		var rect := Rect2(Vector2(index * (width + GAP), 0.0), Vector2(width, size.y))
		match segments[index]:
			"full":
				draw_rect(rect, fill)
			"wearing":
				draw_rect(rect, COLOR_TROUGH)
				draw_rect(Rect2(rect.position, Vector2(width * get_wear_fill(), size.y)), fill)
				draw_rect(rect, fill, false, 1.0)
			"lost":
				draw_rect(rect, COLOR_LOST_FILL)
				draw_rect(rect, COLOR_BROKEN if broken else COLOR_LOST_EDGE, false, 1.0)
			"aged":
				draw_rect(Rect2(rect.position + Vector2(0.0, size.y * 0.35), Vector2(width, size.y * 0.3)), COLOR_AGED)
