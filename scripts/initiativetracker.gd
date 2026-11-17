extends Control
class_name InitiativeTracker

# Draws the turn order. Display only: it keeps no order of its own and shows,
# every frame, what the CombatController says.

var controller: CombatController = null
var icon_size: Vector2 = Vector2(64, 64)   # 32px sprites drawn at 2x
var icon_spacing: float = 88.0

const FRAME_TOP := 8.0       # gap between the bar's top edge and a token's frame
const FRAME_PADDING := 4.0   # frame around the sprite
const ROLL_BASELINE := 108.0 # where the initiative rolls are written, below every frame

func _ready():
	# anchors AND offsets: set_anchors_preset alone keeps the current 0x0 rect,
	# which gave this bar zero width and drew the icons off the left edge
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# Below the turn banner (which ends near y=55); the current combatant's frame
	# is drawn a little larger and would otherwise overlap the banner text
	offset_top = 66
	offset_bottom = 176
	custom_minimum_size = Vector2(0, 110)
	visible = false

func setup(p_controller: CombatController):
	"""Show the fights this controller runs"""
	controller = p_controller
	controller.combat_started.connect(_on_combat_started)
	controller.combat_ended.connect(_on_combat_ended)

func _on_combat_started(_combatants: Array):
	visible = true
	queue_redraw()

func _on_combat_ended(_victory: bool):
	visible = false

func _process(_delta):
	"""Redraw every frame during a fight so the order and the highlight stay current"""
	if visible:
		queue_redraw()

func _get_sprite_texture(entity: Node) -> Texture:
	"""Get the sprite texture from an entity"""
	var sprite = entity.get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		return sprite.texture
	return null

func _draw():
	"""Draw the initiative order: one framed token per combatant, the sprite at
	twice its size (32px art, unfiltered), the roll underneath. Green frame for
	the party, red for hostiles, a thick gold one for whoever's turn it is."""
	if controller == null or not controller.active:
		return
	var order: Array[Combatant] = controller.get_order()
	if order.is_empty():
		return
	var current: Combatant = controller.current_combatant()

	# Calculate starting X position to center the tokens
	var total_width = order.size() * icon_spacing
	var start_x = (size.x - total_width) / 2.0
	var font = ThemeDB.fallback_font

	for i in range(order.size()):
		var combatant: Combatant = order[i]
		var is_current: bool = combatant == current
		var center = Vector2(start_x + i * icon_spacing + icon_spacing / 2.0, FRAME_TOP + FRAME_PADDING + icon_size.y / 2.0)

		var frame = Rect2(center - icon_size / 2.0, icon_size).grow(FRAME_PADDING)
		var bg_color = Color(0.08, 0.08, 0.11, 0.9)
		var border_color = Color(0.3, 1.0, 0.3) if combatant.team == Combatant.Team.PARTY else Color(1.0, 0.3, 0.3)
		var border_width = 2.0
		if is_current:
			# Highlight current turn - make it obvious
			frame = frame.grow(4.0)
			bg_color = Color(0.30, 0.26, 0.08, 1.0)
			border_color = Color(1.0, 0.85, 0.1)
			border_width = 5.0

		draw_rect(frame, bg_color)
		draw_rect(frame, border_color, false, border_width)

		# The sprite, untinted: each enemy type has its own art
		var sprite = _get_sprite_texture(combatant)
		if sprite:
			draw_texture_rect(sprite, Rect2(center - icon_size / 2.0, icon_size), false)

		# Draw initiative number below
		var initiative_text = str(controller.get_initiative(combatant))
		var font_size = 20 if is_current else 14
		var text_size = font.get_string_size(initiative_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_color = Color(1.0, 0.9, 0.3) if is_current else Color.WHITE
		draw_string(font, Vector2(center.x - text_size.x / 2, ROLL_BASELINE), initiative_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)
