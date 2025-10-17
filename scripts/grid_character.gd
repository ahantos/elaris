# grid_character.gd - REFACTORED WITH CHARACTER STATS SYSTEM
extends CharacterBody2D
class_name GridCharacter

# Grid-based character with click-to-move, WASD movement, and data-driven stats

@export var tile_size: int = 16
@export var move_speed: float = 200.0
@export var dungeon_generator: DungeonGenerator
@export var path_preview_color: Color = Color(0, 1, 0, 0.5)
@export var waypoint_color: Color = Color(1, 1, 0, 0.8)

# Turn-based system
@export_group("Turn-Based Settings")
@export var turn_based_mode: bool = false
@export var out_of_moves_color: Color = Color(1, 0, 0, 0.5)

# WASD movement (exploration only)
var wasd_movement_enabled: bool = true
var wasd_exploration_speed: float = 150.0  # Pixels per second for WASD movement

# CHARACTER STATS (NEW - data-driven)
var stats: CharacterStats

# Attack damage (will be replaced by weapon system in Phase 2)
@export var light_attack_damage: int = 1
@export var medium_attack_damage: int = 5
@export var heavy_attack_damage: int = 10

var grid_position: Vector2i = Vector2i(0, 0)
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

# Pathfinding
var path: Array[Vector2i] = []
var path_index: int = 0

# Path preview system
var preview_path: Array[Vector2i] = []
var preview_destination: Vector2i = Vector2i(-1, -1)
var is_path_selected: bool = false

# Multi-waypoint system
var waypoints: Array[Vector2i] = []
var full_preview_path: Array[Vector2i] = []

# Turn-based movement tracking
var moves_remaining: int = 0
var turn_number: int = 0

# Attack mode
var attack_mode: bool = false
var selected_attack_type: String = ""
var has_attacked_this_turn: bool = false

# Turn management signal
signal turn_ended

func _ready():
	z_index = 200
	
	# Initialize character stats (NEW)
	initialize_stats()
	
	# Register with GameManager (NEW)
	GameManager.set_player(self)
	
	# Auto-detect tile size from dungeon's tilemap
	if dungeon_generator and dungeon_generator.tilemap and dungeon_generator.tilemap.tile_set:
		tile_size = int(dungeon_generator.tilemap.tile_set.tile_size.x)
	
	# Auto-scale sprite to fit tile size
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		var texture_size = sprite.texture.get_size()
		var target_size = tile_size * 0.8
		var scale_factor = target_size / max(texture_size.x, texture_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)
	
	# Spawn in first room
	if dungeon_generator:
		if not dungeon_generator.start_room.is_empty():
			var start_room_data = dungeon_generator.start_room
			var room_center = start_room_data.center
			
			grid_position = room_center
			position = grid_to_world(grid_position)
			target_position = position
			
			# Set camera target
			var camera = get_viewport().get_camera_2d()
			if camera and camera.has_method("set"):
				camera.set("target", self)
		else:
			push_error("No start room found!")
	else:
		push_error("No dungeon generator assigned to character!")
	
	# Initialize turn-based system
	if turn_based_mode:
		start_new_turn()

func initialize_stats():
	"""Initialize character stats (NEW)"""
	# Create stats with starting values
	# These would normally come from race + class data
	stats = CharacterStats.new({
		"str": 14,
		"dex": 12,
		"con": 14,
		"int": 10,
		"wis": 12,
		"cha": 10
	})
	
	# Set movement per turn from stats (could be affected by race/class later)
	stats.movement_speed = 6
	
	print("Player stats initialized: HP ", stats.current_hp, "/", stats.max_hp)

func _process(delta):
	# WASD movement (only in exploration mode)
	if wasd_movement_enabled and not turn_based_mode:
		process_wasd_movement(delta)

func process_wasd_movement(delta):
	"""Handle smooth WASD movement in exploration mode"""
	# Get input direction
	var input_dir = Vector2.ZERO
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	
	# Normalize diagonal movement
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		
		# Cancel click-based movement and previews
		if is_moving:
			is_moving = false
			path.clear()
		
		if preview_path.size() > 0 or waypoints.size() > 0:
			cancel_preview()
		
		# Calculate desired position
		var movement_delta = input_dir * wasd_exploration_speed * delta
		var desired_position = position + movement_delta
		var desired_grid = world_to_grid(desired_position)
		
		# Check if the target tile is walkable
		if is_walkable(desired_grid):
			# Move smoothly
			position = desired_position
			grid_position = world_to_grid(position)
		else:
			# Hit a wall - try sliding along it
			# Try horizontal movement only
			var horizontal_pos = position + Vector2(movement_delta.x, 0)
			var horizontal_grid = world_to_grid(horizontal_pos)
			if is_walkable(horizontal_grid):
				position = horizontal_pos
				grid_position = world_to_grid(position)
			else:
				# Try vertical movement only
				var vertical_pos = position + Vector2(0, movement_delta.y)
				var vertical_grid = world_to_grid(vertical_pos)
				if is_walkable(vertical_grid):
					position = vertical_pos
					grid_position = world_to_grid(position)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var click_pos = get_global_mouse_position()
			var click_grid = world_to_grid(click_pos)
			var ctrl_held = Input.is_key_pressed(KEY_CTRL)
			
			# Check if in attack mode
			if attack_mode:
				var world = get_tree().root.get_node_or_null("World")
				if world:
					var clicked_enemy = world.get_enemy_at_position(click_grid)
					if clicked_enemy:
						# Check if adjacent
						var dx = abs(grid_position.x - click_grid.x)
						var dy = abs(grid_position.y - click_grid.y)
						if dx <= 1 and dy <= 1 and (dx + dy) > 0:
							attack_enemy(clicked_enemy, selected_attack_type)
						else:
							print("Enemy is too far away! Must be adjacent.")
					else:
						print("No enemy at that location.")
				attack_mode = false
				selected_attack_type = ""
				queue_redraw()
				return
			
			if ctrl_held:
				add_waypoint(click_grid)
			else:
				if is_path_selected or waypoints.size() > 0:
					var is_clicking_destination = false
					if waypoints.size() > 0:
						is_clicking_destination = (click_grid == waypoints[-1])
					else:
						is_clicking_destination = (click_grid == preview_destination)
					
					if is_clicking_destination:
						execute_move()
					else:
						cancel_preview()
				else:
					show_path_preview(click_grid)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_path_selected or waypoints.size() > 0:
				cancel_preview()
			elif is_moving:
				stop_moving()
	
	elif event is InputEventKey:
		if event.keycode == KEY_T and event.pressed and not event.echo:
			toggle_turn_based_mode()
		
		elif event.keycode == KEY_SPACE and event.pressed and not event.echo:
			if turn_based_mode:
				end_turn()
		
		elif event.keycode == KEY_1 and event.pressed and not event.echo:
			if turn_based_mode and not is_moving:
				if has_attacked_this_turn:
					print("You've already attacked this turn!")
				else:
					if attack_mode and selected_attack_type == "light":
						attack_mode = false
						selected_attack_type = ""
						print("Attack cancelled.")
					else:
						attack_mode = true
						selected_attack_type = "light"
						print("💛 Light attack selected (1 damage)! Click on an adjacent enemy.")
					queue_redraw()
		
		elif event.keycode == KEY_2 and event.pressed and not event.echo:
			if turn_based_mode and not is_moving:
				if has_attacked_this_turn:
					print("You've already attacked this turn!")
				else:
					if attack_mode and selected_attack_type == "medium":
						attack_mode = false
						selected_attack_type = ""
						print("Attack cancelled.")
					else:
						attack_mode = true
						selected_attack_type = "medium"
						print("🧡 Medium attack selected (5 damage)! Click on an adjacent enemy.")
					queue_redraw()
		
		elif event.keycode == KEY_3 and event.pressed and not event.echo:
			if turn_based_mode and not is_moving:
				if has_attacked_this_turn:
					print("You've already attacked this turn!")
				else:
					if attack_mode and selected_attack_type == "heavy":
						attack_mode = false
						selected_attack_type = ""
						print("Attack cancelled.")
					else:
						attack_mode = true
						selected_attack_type = "heavy"
						print("❤️ Heavy attack selected (10 damage)! Click on an adjacent enemy.")
					queue_redraw()
		
		elif event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			if attack_mode:
				attack_mode = false
				selected_attack_type = ""
				print("Attack cancelled.")
				queue_redraw()

func add_waypoint(destination: Vector2i):
	"""Add a waypoint to the queue (Ctrl+Click)"""
	if not is_walkable(destination):
		return
	
	if is_moving:
		return
	
	waypoints.append(destination)
	recalculate_waypoint_path()

func recalculate_waypoint_path():
	"""Calculate path through all waypoints"""
	if waypoints.is_empty():
		full_preview_path.clear()
		is_path_selected = false
		queue_redraw()
		return
	
	full_preview_path.clear()
	var current_pos = grid_position
	
	for waypoint in waypoints:
		var segment = _calculate_straight_path(current_pos, waypoint)
		
		if segment.size() <= 1:
			var idx = waypoints.find(waypoint)
			waypoints.resize(idx)
			recalculate_waypoint_path()
			return
		
		if full_preview_path.is_empty():
			full_preview_path.append_array(segment)
		else:
			for i in range(1, segment.size()):
				full_preview_path.append(segment[i])
		
		current_pos = waypoint
	
	preview_destination = waypoints[-1]
	is_path_selected = true
	queue_redraw()

func show_path_preview(destination: Vector2i):
	"""Show path preview for first click"""
	if not is_walkable(destination):
		cancel_preview()
		return
	
	if is_moving:
		return
	
	waypoints.clear()
	
	preview_path = _calculate_straight_path(grid_position, destination)
	full_preview_path = preview_path.duplicate()
	
	if preview_path.size() > 1:
		preview_destination = destination
		is_path_selected = true
		queue_redraw()
		
		if turn_based_mode:
			var path_length = preview_path.size() - 1
			if path_length > moves_remaining:
				print("Path requires ", path_length, " moves, but only ", moves_remaining, " remaining this turn")
	else:
		preview_path.clear()
		full_preview_path.clear()
		preview_destination = Vector2i(-1, -1)
		is_path_selected = false
		queue_redraw()

func execute_move():
	"""Execute the previewed path"""
	var path_to_execute: Array[Vector2i]
	
	if waypoints.size() > 0:
		path_to_execute = full_preview_path.duplicate()
	else:
		path_to_execute = preview_path.duplicate()
	
	if turn_based_mode:
		var path_length = path_to_execute.size() - 1
		if path_length > moves_remaining:
			print("Not enough moves! Need ", path_length, " but only have ", moves_remaining)
			return
	
	path = path_to_execute
	
	preview_path.clear()
	full_preview_path.clear()
	preview_destination = Vector2i(-1, -1)
	waypoints.clear()
	is_path_selected = false
	
	if path.size() > 1:
		path_index = 1
		target_position = grid_to_world(path[path_index])
		is_moving = true
	
	queue_redraw()

func cancel_preview():
	"""Cancel the path preview and clear all waypoints"""
	preview_path.clear()
	full_preview_path.clear()
	preview_destination = Vector2i(-1, -1)
	waypoints.clear()
	is_path_selected = false
	queue_redraw()

func _draw():
	"""Draw the path preview and waypoints"""
	
	# Draw HP bar above character (only in combat)
	if turn_based_mode:
		draw_hp_bar()
	
	# Draw attack mode indicator
	if attack_mode:
		var attack_color = Color.RED
		
		match selected_attack_type:
			"light":
				attack_color = Color(1.0, 1.0, 0.0)
			"medium":
				attack_color = Color(1.0, 0.5, 0.0)
			"heavy":
				attack_color = Color(1.0, 0.0, 0.0)
		
		# Draw crosshairs
		var crosshair_size = tile_size * 1.5
		draw_line(Vector2(-crosshair_size, 0), Vector2(crosshair_size, 0), attack_color, 3.0)
		draw_line(Vector2(0, -crosshair_size), Vector2(0, crosshair_size), attack_color, 3.0)
		
		# Draw attack range indicator (adjacent tiles)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var offset = Vector2(dx * tile_size, dy * tile_size)
				draw_rect(Rect2(offset - Vector2(tile_size/2, tile_size/2), Vector2(tile_size, tile_size)), 
					Color(attack_color.r, attack_color.g, attack_color.b, 0.3), false, 2.0)
	
	# Draw preview path
	if not is_moving and (is_path_selected or waypoints.size() > 0) and full_preview_path.size() > 1:
		for i in range(full_preview_path.size() - 1):
			var start_world = grid_to_world(full_preview_path[i]) - position
			var end_world = grid_to_world(full_preview_path[i + 1]) - position
			
			var segment_color = path_preview_color
			if turn_based_mode:
				if i >= moves_remaining:
					segment_color = out_of_moves_color
			
			draw_line(start_world, end_world, segment_color, 3.0)
		
		for i in range(1, full_preview_path.size()):
			var point_world = grid_to_world(full_preview_path[i]) - position
			
			var circle_color = path_preview_color
			if turn_based_mode:
				if i > moves_remaining:
					circle_color = out_of_moves_color
			
			draw_circle(point_world, tile_size * 0.2, circle_color)
		
		for waypoint in waypoints:
			var waypoint_world = grid_to_world(waypoint) - position
			draw_circle(waypoint_world, tile_size * 0.4, waypoint_color)
			draw_arc(waypoint_world, tile_size * 0.4, 0, TAU, 32, waypoint_color, 2.0)
	
	elif is_moving and path.size() > 0 and path_index < path.size():
		for i in range(path_index, path.size() - 1):
			var start_world = grid_to_world(path[i]) - position
			var end_world = grid_to_world(path[i + 1]) - position
			
			var distance_from_current = i - path_index
			var remaining_steps = path.size() - path_index
			var fade_progress = float(distance_from_current) / float(remaining_steps)
			var segment_fade = lerp(0.1, 1.0, fade_progress)
			var segment_color = Color(path_preview_color.r, path_preview_color.g, path_preview_color.b, path_preview_color.a * segment_fade)
			
			draw_line(start_world, end_world, segment_color, 2.0)
		
		for i in range(path_index, path.size()):
			var point_world = grid_to_world(path[i]) - position
			var distance_from_current = i - path_index
			var remaining_steps = path.size() - path_index
			var fade_progress = float(distance_from_current) / float(remaining_steps)
			var segment_fade = lerp(0.1, 1.0, fade_progress)
			var segment_color = Color(path_preview_color.r, path_preview_color.g, path_preview_color.b, path_preview_color.a * segment_fade)
			draw_circle(point_world, tile_size * 0.15, segment_color)

func _physics_process(delta):
	if is_moving and path.size() > 0:
		position = position.move_toward(target_position, move_speed * delta)
		
		queue_redraw()
		
		if position.distance_to(target_position) < 1.0:
			position = target_position
			grid_position = path[path_index]
			path_index += 1
			
			if path_index < path.size():
				target_position = grid_to_world(path[path_index])
			else:
				is_moving = false
				
				if turn_based_mode:
					var moves_used = path.size() - 1
					moves_remaining -= moves_used
					print("Used ", moves_used, " moves. Remaining: ", moves_remaining)
					
					if moves_remaining <= 0:
						print("Out of moves! Press SPACE to end turn.")
				
				path.clear()
				path_index = 0
				queue_redraw()

func _calculate_straight_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	"""Calculate path using A* algorithm"""
	if not is_walkable(to):
		return [from]
	
	if from == to:
		return [from]
	
	var open_set: Array[Vector2i] = [from]
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0}
	var f_score: Dictionary = {from: _heuristic(from, to)}
	
	while not open_set.is_empty():
		var current = open_set[0]
		var lowest_f = f_score.get(current, INF)
		var current_idx = 0
		
		for i in range(open_set.size()):
			var node = open_set[i]
			var f = f_score.get(node, INF)
			if f < lowest_f:
				current = node
				lowest_f = f
				current_idx = i
		
		if current == to:
			return _reconstruct_path(came_from, current)
		
		open_set.remove_at(current_idx)
		closed_set[current] = true
		
		for neighbor in _get_neighbors(current):
			if neighbor in closed_set:
				continue
			
			if not is_walkable(neighbor):
				continue
			
			var move_cost = 1.0
			var dx = abs(neighbor.x - current.x)
			var dy = abs(neighbor.y - current.y)
			if dx + dy == 2:
				move_cost = 1.414
			
			var tentative_g = g_score.get(current, INF) + move_cost
			
			if neighbor not in open_set:
				open_set.append(neighbor)
			elif tentative_g >= g_score.get(neighbor, INF):
				continue
			
			came_from[neighbor] = current
			g_score[neighbor] = tentative_g
			f_score[neighbor] = tentative_g + _heuristic(neighbor, to)
	
	return [from]

func _get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	"""Get 8 adjacent neighbors"""
	var neighbors: Array[Vector2i] = []
	
	var cardinals = [
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x, pos.y - 1)
	]
	
	var diagonals = [
		Vector2i(pos.x + 1, pos.y + 1),
		Vector2i(pos.x + 1, pos.y - 1),
		Vector2i(pos.x - 1, pos.y + 1),
		Vector2i(pos.x - 1, pos.y - 1)
	]
	
	neighbors.append_array(cardinals)
	
	if is_walkable(Vector2i(pos.x + 1, pos.y)) and is_walkable(Vector2i(pos.x, pos.y + 1)):
		neighbors.append(Vector2i(pos.x + 1, pos.y + 1))
	if is_walkable(Vector2i(pos.x + 1, pos.y)) and is_walkable(Vector2i(pos.x, pos.y - 1)):
		neighbors.append(Vector2i(pos.x + 1, pos.y - 1))
	if is_walkable(Vector2i(pos.x - 1, pos.y)) and is_walkable(Vector2i(pos.x, pos.y + 1)):
		neighbors.append(Vector2i(pos.x - 1, pos.y + 1))
	if is_walkable(Vector2i(pos.x - 1, pos.y)) and is_walkable(Vector2i(pos.x, pos.y - 1)):
		neighbors.append(Vector2i(pos.x - 1, pos.y - 1))
	
	return neighbors

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	"""Diagonal distance heuristic"""
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return max(dx, dy)

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	"""Reconstruct path from came_from dictionary"""
	var path_result: Array[Vector2i] = [current]
	while current in came_from:
		current = came_from[current]
		path_result.insert(0, current)
	return path_result

func is_walkable(grid_pos: Vector2i) -> bool:
	"""Check if a grid position is walkable"""
	if not dungeon_generator:
		return false
	
	if grid_pos.x < 0 or grid_pos.x >= dungeon_generator.dungeon_width:
		return false
	if grid_pos.y < 0 or grid_pos.y >= dungeon_generator.dungeon_height:
		return false
	
	var tile_type = dungeon_generator.dungeon_grid[grid_pos.y][grid_pos.x]
	var is_floor = tile_type == dungeon_generator.TileType.FLOOR or tile_type == dungeon_generator.TileType.DOOR
	
	if not is_floor:
		return false
	
	var world = get_tree().root.get_node_or_null("World")
	if world and world.has_method("is_position_occupied_by_enemy"):
		if world.is_position_occupied_by_enemy(grid_pos, self):
			return false
	
	return true

func world_to_grid(world_pos: Vector2) -> Vector2i:
	"""Convert world position to grid coordinates"""
	return Vector2i(
		int(world_pos.x / tile_size),
		int(world_pos.y / tile_size)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Convert grid coordinates to world position"""
	return Vector2(
		grid_pos.x * tile_size + tile_size / 2.0,
		grid_pos.y * tile_size + tile_size / 2.0
	)

func teleport_to_grid(grid_pos: Vector2i):
	"""Instantly teleport to a grid position"""
	if is_walkable(grid_pos):
		grid_position = grid_pos
		position = grid_to_world(grid_position)
		target_position = position
		is_moving = false
		path.clear()
		cancel_preview()

func get_grid_position() -> Vector2i:
	"""Get current grid position"""
	return grid_position

func stop_moving():
	"""Stop current movement"""
	is_moving = false
	path.clear()
	path_index = 0
	position = grid_to_world(grid_position)
	target_position = position

func attack_enemy(enemy: Enemy, attack_type: String):
	"""Attack an adjacent enemy with animation"""
	if not enemy or not turn_based_mode:
		return
	
	if has_attacked_this_turn:
		print("You've already attacked this turn!")
		return
	
	var damage = 0
	var attack_name = ""
	
	match attack_type:
		"light":
			damage = light_attack_damage
			attack_name = "Light Attack"
		"medium":
			damage = medium_attack_damage
			attack_name = "Medium Attack"
		"heavy":
			damage = heavy_attack_damage
			attack_name = "Heavy Attack"
	
	# Attack animation
	animate_attack(enemy.global_position)
	
	print("Player uses %s on %s for %d damage!" % [attack_name, enemy.name, damage])
	
	# Delay damage until animation halfway through
	await get_tree().create_timer(0.15).timeout
	enemy.take_damage(damage)
	
	# Emit event (NEW)
	EventBus.damage_dealt.emit(self, enemy, damage, false)
	
	has_attacked_this_turn = true
	attack_mode = false
	selected_attack_type = ""
	queue_redraw()

func animate_attack(target_pos: Vector2):
	"""Animate a quick lunge toward the target"""
	var original_pos = global_position
	var direction = (target_pos - original_pos).normalized()
	var lunge_distance = tile_size * 0.5
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", original_pos + direction * lunge_distance, 0.1)
	tween.tween_property(self, "global_position", original_pos, 0.15)

# ============================================================================
# TURN-BASED SYSTEM
# ============================================================================

func toggle_turn_based_mode():
	"""Toggle turn-based mode on/off"""
	turn_based_mode = !turn_based_mode
	
	if turn_based_mode:
		start_new_turn()
		print("Turn-based mode ENABLED - Press T to toggle, SPACE to end turn")
		print("Turn ", turn_number, " - Moves remaining: ", moves_remaining)
	else:
		print("Turn-based mode DISABLED - Free movement with WASD or click")

func start_new_turn():
	"""Start a new turn with full movement"""
	turn_number += 1
	moves_remaining = stats.movement_speed  # Use stats (NEW)
	has_attacked_this_turn = false
	print("=== Turn ", turn_number, " started ===")
	print("Movement available: ", moves_remaining, " tiles")
	
	# Emit event (NEW)
	EventBus.turn_started.emit(self)

func end_turn():
	"""Manually end the current turn"""
	if not turn_based_mode:
		return
	
	print("Turn ", turn_number, " ended. Moves used: ", stats.movement_speed - moves_remaining)
	
	# Emit event (NEW)
	EventBus.turn_ended.emit(self)
	turn_ended.emit()
	
	start_new_turn()

func get_moves_remaining() -> int:
	"""Get remaining moves this turn"""
	return moves_remaining

func get_turn_number() -> int:
	"""Get current turn number"""
	return turn_number

# ============================================================================
# COMBAT SYSTEM (REFACTORED TO USE CHARACTERSTATS)
# ============================================================================

func take_damage(amount: int):
	"""Take damage with visual effects (REFACTORED)"""
	var was_alive = stats.is_alive()
	var still_alive = stats.take_damage(amount)
	
	print("%s took %d damage! HP: %d/%d" % [name, amount, stats.current_hp, stats.max_hp])
	
	# Spawn damage popup
	var world = get_parent()
	if world:
		var popup_pos = global_position + Vector2(0, -tile_size * 0.8)
		DamagePopup.spawn_damage_popup_at(world, popup_pos, amount, false)
	
	# Flash effect
	flash_damage()
	
	# Emit event (NEW)
	EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)
	
	queue_redraw()
	
	if was_alive and not still_alive:
		die()

func flash_damage():
	"""Quick red flash when taking damage"""
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func heal(amount: int):
	"""Heal HP with visual effects (REFACTORED)"""
	stats.heal(amount)
	print("%s healed %d HP! HP: %d/%d" % [name, amount, stats.current_hp, stats.max_hp])
	
	# Spawn heal popup
	var world = get_parent()
	if world:
		var popup_pos = global_position + Vector2(0, -tile_size * 0.8)
		DamagePopup.spawn_heal_popup_at(world, popup_pos, amount)
	
	# Emit event (NEW)
	EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)
	
	queue_redraw()

func die():
	"""Handle death"""
	print("%s has died!" % name)
	
	# Emit event (NEW)
	EventBus.character_died.emit(self)
	
	queue_free()

func get_hp() -> int:
	"""Get current HP (REFACTORED)"""
	return stats.current_hp if stats else 0

func get_max_hp() -> int:
	"""Get max HP (REFACTORED)"""
	return stats.max_hp if stats else 0

func draw_hp_bar():
	"""Draw HP bar above the character (REFACTORED)"""
	if not stats:
		return
	
	var bar_width = tile_size * 1.2
	var bar_height = 6.0
	var bar_offset = Vector2(-bar_width / 2, -tile_size * 0.8)
	
	# Background
	draw_rect(Rect2(bar_offset, Vector2(bar_width, bar_height)), Color.BLACK)
	
	# Health bar
	var hp_percent = stats.get_hp_percent()
	var health_width = bar_width * hp_percent
	var health_color = Color.GREEN.lerp(Color.RED, 1.0 - hp_percent)
	
	if health_width > 0:
		draw_rect(Rect2(bar_offset, Vector2(health_width, bar_height)), health_color)
	
	# Border
	draw_rect(Rect2(bar_offset, Vector2(bar_width, bar_height)), Color.WHITE, false, 1.0)

# ============================================================================
# LEVELING (NEW)
# ============================================================================

func gain_experience(amount: int):
	"""Gain XP and potentially level up (NEW)"""
	stats.gain_experience(amount)
	
	# Emit event
	EventBus.player_gained_xp.emit(amount)
	
	print("Gained ", amount, " XP! (", stats.experience, "/", stats.experience_to_next_level, ")")

func get_level() -> int:
	"""Get current level (NEW)"""
	return stats.level if stats else 1

# ============================================================================
# DATA EXPORT/IMPORT (for saving)
# ============================================================================

func to_dict() -> Dictionary:
	"""Export character data for saving (NEW)"""
	return {
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"stats": stats.to_dict() if stats else {},
		"turn_number": turn_number,
		"turn_based_mode": turn_based_mode
	}

func from_dict(data: Dictionary):
	"""Import character data from save (NEW)"""
	if data.has("grid_position"):
		var pos_data = data.grid_position
		grid_position = Vector2i(pos_data.x, pos_data.y)
		position = grid_to_world(grid_position)
		target_position = position
	
	if data.has("stats") and stats:
		stats.from_dict(data.stats)
	
	if data.has("turn_number"):
		turn_number = data.turn_number
	
	if data.has("turn_based_mode"):
		turn_based_mode = data.turn_based_mode
