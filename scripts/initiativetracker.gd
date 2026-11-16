extends Control
class_name InitiativeTracker

# Visual display of turn order

var combatants: Array[Dictionary] = []
var current_index: int = 0
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

func _process(_delta):
	"""Force redraw every frame to ensure highlighting updates"""
	if not combatants.is_empty():
		queue_redraw()

func setup_initiative(player: GridCharacter, enemies: Array[Enemy]):
	"""Roll initiative for all combatants and sort them"""
	combatants.clear()
	visible = true
	
	# Add player (d20 + DEX modifier via CombatManager)
	var player_initiative = CombatManager.roll_initiative(player.stats)
	var player_sprite = _get_sprite_texture(player)
	combatants.append({
		"entity": player,
		"initiative": player_initiative,
		"sprite": player_sprite,
		"is_player": true,
		"name": "Player"
	})
	
	# Add enemies
	for i in range(enemies.size()):
		if not is_instance_valid(enemies[i]):
			continue
			
		var enemy = enemies[i]
		var enemy_initiative = CombatManager.roll_initiative(enemy.stats)
		var enemy_sprite = _get_sprite_texture(enemy)
		combatants.append({
			"entity": enemy,
			"initiative": enemy_initiative,
			"sprite": enemy_sprite,
			"is_player": false,
			"name": "Enemy %d" % (i + 1)
		})
	
	# Sort by initiative (highest first)
	combatants.sort_custom(func(a, b): return a.initiative > b.initiative)
	
	current_index = 0
	queue_redraw()
	
	print("=== INITIATIVE ORDER ===")
	for i in range(combatants.size()):
		print("%d. %s (Initiative: %d)" % [i + 1, combatants[i].name, combatants[i].initiative])

func _get_sprite_texture(entity: Node) -> Texture:
	"""Get the sprite texture from an entity"""
	var sprite = entity.get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		return sprite.texture
	return null

func next_turn() -> Dictionary:
	"""Advance to next turn and return the combatant"""
	# Check if we have any combatants
	if combatants.is_empty():
		return {}
	
	# Remove dead/invalid combatants
	clean_combatants()
	
	# Check again after cleaning
	if combatants.is_empty():
		return {}
	
	# Advance to next turn
	current_index = (current_index + 1) % combatants.size()
	queue_redraw()
	return combatants[current_index]

func clean_combatants():
	"""Remove dead or invalid combatants from the list"""
	var i = 0
	while i < combatants.size():
		var combatant = combatants[i]
		if not is_instance_valid(combatant.entity):
			combatants.remove_at(i)
			# Adjust current_index if needed
			if i <= current_index and current_index > 0:
				current_index -= 1
		else:
			i += 1

func get_current_combatant() -> Dictionary:
	"""Get the current turn's combatant"""
	if combatants.is_empty():
		return {}
	
	# Clean up dead combatants first
	clean_combatants()
	
	if combatants.is_empty():
		return {}
	
	# Ensure current_index is valid
	if current_index >= combatants.size():
		current_index = 0
	
	return combatants[current_index]

func is_player_turn() -> bool:
	"""Check if it's currently the player's turn"""
	if combatants.is_empty():
		return false
	
	var current = get_current_combatant()
	if current.is_empty():
		return false
	
	return current.is_player

func _draw():
	"""Draw the initiative order: one framed token per combatant, the sprite at
	twice its size (32px art, unfiltered), the roll underneath. Green frame for
	the player, red for enemies, a thick gold one for whoever's turn it is."""
	if combatants.is_empty():
		return

	# Calculate starting X position to center the tokens
	var total_width = combatants.size() * icon_spacing
	var start_x = (size.x - total_width) / 2.0
	var font = ThemeDB.fallback_font

	for i in range(combatants.size()):
		var combatant = combatants[i]
		var is_current: bool = i == current_index
		var center = Vector2(start_x + i * icon_spacing + icon_spacing / 2.0, FRAME_TOP + FRAME_PADDING + icon_size.y / 2.0)

		var frame = Rect2(center - icon_size / 2.0, icon_size).grow(FRAME_PADDING)
		var bg_color = Color(0.08, 0.08, 0.11, 0.9)
		var border_color = Color(0.3, 1.0, 0.3) if combatant.is_player else Color(1.0, 0.3, 0.3)
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
		if combatant.sprite:
			draw_texture_rect(combatant.sprite, Rect2(center - icon_size / 2.0, icon_size), false)

		# Draw initiative number below
		var initiative_text = str(combatant.initiative)
		var font_size = 20 if is_current else 14
		var text_size = font.get_string_size(initiative_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_color = Color(1.0, 0.9, 0.3) if is_current else Color.WHITE
		draw_string(font, Vector2(center.x - text_size.x / 2, ROLL_BASELINE), initiative_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

func remove_combatant(entity: Node):
	"""Remove a specific combatant (e.g., when they die)"""
	for i in range(combatants.size()):
		if combatants[i].entity == entity:
			combatants.remove_at(i)
			# Adjust current_index if needed
			if i < current_index:
				current_index -= 1
			elif i == current_index and current_index >= combatants.size():
				current_index = 0
			break
	
	# Hide if no combatants left
	if combatants.is_empty():
		visible = false
	
	queue_redraw()
