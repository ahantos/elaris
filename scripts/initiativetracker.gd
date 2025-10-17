extends Control
class_name InitiativeTracker

# Visual display of turn order

var combatants: Array[Dictionary] = []
var current_index: int = 0
var icon_size: Vector2 = Vector2(48, 48)
var icon_spacing: float = 60.0

func _ready():
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	position.y = 50
	custom_minimum_size = Vector2(0, 70)
	size = Vector2(get_viewport().size.x, 70)
	visible = false

func _process(_delta):
	"""Force redraw every frame to ensure highlighting updates"""
	if not combatants.is_empty():
		queue_redraw()

func setup_initiative(player: GridCharacter, enemies: Array[Enemy]):
	"""Roll initiative for all combatants and sort them"""
	combatants.clear()
	visible = true
	
	# Add player
	var player_initiative = randi() % 20 + 1
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
		randomize()
		var enemy_initiative = (randi() % 20) + 1
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
	"""Draw the initiative order"""
	if combatants.is_empty():
		return
	
	# Calculate starting X position to center the icons
	var total_width = combatants.size() * icon_spacing
	var start_x = (size.x - total_width) / 2.0
	
	for i in range(combatants.size()):
		var combatant = combatants[i]
		var x_pos = start_x + i * icon_spacing + icon_spacing / 2.0
		var y_pos = 10.0
		
		# Determine colors
		var bg_color = Color(0.2, 0.2, 0.2, 0.8)
		var border_color = Color.WHITE
		var border_width = 2.0
		var icon_scale = 1.0
		
		if i == current_index:
			# Highlight current turn - make it obvious
			bg_color = Color(1.0, 0.9, 0.0, 1.0)
			border_color = Color(1.0, 1.0, 1.0)
			border_width = 6.0
			icon_scale = 1.5
		elif combatant.is_player:
			border_color = Color(0.3, 1.0, 0.3)
		else:
			border_color = Color(1.0, 0.3, 0.3)
		
		var scaled_icon_size = icon_size * icon_scale
		var center = Vector2(x_pos, y_pos + icon_size.y / 2)
		
		# Draw background circle
		draw_circle(center, scaled_icon_size.x / 2, bg_color)
		
		# Draw border
		draw_arc(center, scaled_icon_size.x / 2, 0, TAU, 32, border_color, border_width)
		
		# Draw sprite
		if combatant.sprite:
			var sprite_pos = Vector2(x_pos - scaled_icon_size.x / 2, y_pos + (icon_size.y - scaled_icon_size.y) / 2)
			var sprite_rect = Rect2(sprite_pos, scaled_icon_size)
			var sprite_color = Color.WHITE
			draw_texture_rect(combatant.sprite, sprite_rect, false, sprite_color)
		
		# Draw initiative number below
		var initiative_text = str(combatant.initiative)
		var font = ThemeDB.fallback_font
		var font_size = 20 if i == current_index else 14
		var text_size = font.get_string_size(initiative_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_color = Color.WHITE
		draw_string(font, Vector2(x_pos - text_size.x / 2, y_pos + icon_size.y + 20), initiative_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

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
