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
var moves_granted_this_turn: int = 0
var turn_number: int = 0

# Attack mode
var attack_mode: bool = false
var selected_attack_type: String = ""
var has_attacked_this_turn: bool = false

# Turn management signal
signal turn_ended

# Cached world reference (avoids per-call scene tree lookups in hot paths)
var world_node = null

# Death guard (prevents double death handling)
var is_dying: bool = false

func _ready():
	z_index = 200

	# Initialize character stats (NEW)
	initialize_stats()

	# Register with GameManager (NEW)
	GameManager.set_player(self)

	# Cache world reference (used in hot paths like is_walkable)
	world_node = get_tree().root.get_node_or_null("World")

	# Keep HP signal/visuals in sync when CombatManager applies damage directly to stats
	EventBus.damage_dealt.connect(_on_damage_dealt_event)
	EventBus.game_loaded.connect(_on_game_loaded)
	
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

		# Track tile changes for step-on loot pickup
		var previous_grid = grid_position

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

		# Stepped onto a new tile - pick up any ground loot there
		if grid_position != previous_grid:
			_check_ground_pickup()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var click_pos = get_global_mouse_position()
			var click_grid = world_to_grid(click_pos)
			var ctrl_held = Input.is_key_pressed(KEY_CTRL)

			# A readied spell (set via the spellbook) intercepts the click
			if SpellManager.get_pending_cast(self) != "":
				_handle_pending_spell_click(click_grid)
				return

			# Check if in attack mode
			if attack_mode:
				var world = _get_world()
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
			if SpellManager.get_pending_cast(self) != "":
				SpellManager.clear_pending_cast(self)
				print("Spell cast cancelled.")
				queue_redraw()
			elif attack_mode:
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

		# Leaving an enemy's melee reach provokes opportunity attacks (combat only)
		_check_opportunity_attacks(grid_position, path[path_index])
		if is_dying or not stats or not stats.is_alive():
			path.clear()
			path_index = 0
			queue_redraw()
			return

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

			# Deduct movement per completed tile so stopping
			# mid-path still counts the moves already used
			if turn_based_mode:
				moves_remaining -= 1

			# Step-on pickup of ground loot
			_check_ground_pickup()

			if path_index < path.size():
				# Leaving an enemy's melee reach provokes opportunity attacks
				_check_opportunity_attacks(grid_position, path[path_index])
				if is_dying or not stats or not stats.is_alive():
					is_moving = false
					path.clear()
					path_index = 0
					queue_redraw()
					return
				target_position = grid_to_world(path[path_index])
			else:
				is_moving = false

				if turn_based_mode:
					print("Moves remaining: ", moves_remaining)

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

func _get_world():
	"""Get the cached World node (re-resolves if missing/freed)"""
	if not is_instance_valid(world_node):
		world_node = get_tree().root.get_node_or_null("World")
	return world_node

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

	var world = _get_world()
	if world and world.has_method("is_position_occupied_by_enemy"):
		if world.is_position_occupied_by_enemy(grid_pos, self):
			return false

	# Party companions block tiles too
	if world and world.has_method("is_position_occupied_by_companion"):
		if world.is_position_occupied_by_companion(grid_pos, self):
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

func create_temp_weapon(attack_type: String) -> ItemData:
	"""Create temporary weapon for current attack system (TEMPORARY - Phase 2 will use real weapons)"""
	var weapon = ItemData.new()
	weapon.item_name = "Temporary Weapon"
	weapon.is_weapon = true
	weapon.weapon_type = "simple"
	
	match attack_type:
		"light":
			weapon.damage_dice = "1d4"  # Light attack
		"medium":
			weapon.damage_dice = "1d8"  # Medium attack
		"heavy":
			weapon.damage_dice = "1d12"  # Heavy attack
	
	return weapon

func attack_enemy(enemy: Enemy, attack_type: String):
	"""Attack an adjacent enemy with animation (REFACTORED)"""
	if not enemy or not turn_based_mode:
		return

	if has_attacked_this_turn:
		print("You've already attacked this turn!")
		return

	# Enforce melee adjacency (Chebyshev distance 1)
	var enemy_pos = enemy.get_grid_position()
	var dx = abs(grid_position.x - enemy_pos.x)
	var dy = abs(grid_position.y - enemy_pos.y)
	if dx > 1 or dy > 1 or (dx + dy) == 0:
		print("Enemy is too far away! Must be adjacent.")
		return

	# Mark the attack as used immediately so input during the
	# animation delay can't trigger a second attack this turn
	has_attacked_this_turn = true
	attack_mode = false
	selected_attack_type = ""

	# Get weapon (TODO: get from InventoryManager in Phase 2)
	var weapon = create_temp_weapon(attack_type)

	# Attack animation
	animate_attack(enemy.global_position)

	# Wait for animation (pauses with the tree so damage can't resolve
	# while a pause menu is open)
	await get_tree().create_timer(0.15, false).timeout

	# Target may have been freed during the animation delay
	if not is_instance_valid(enemy) or not enemy.stats:
		queue_redraw()
		return

	# Roll attack using CombatManager (nodes unlock status effects, cover and
	# AC mods; companion positions enable flanking advantage)
	var result = CombatManager.roll_attack(stats, enemy.stats, weapon, false, false, self, enemy, _companion_positions())
	if result.is_empty():
		queue_redraw()
		return

	if result.get("auto_fail", false):
		print("You are incapacitated and cannot attack!")
		queue_redraw()
		return

	var popup_pos = enemy.global_position + Vector2(0, -tile_size * 0.8)

	if result.is_fumble:
		print("💀 FUMBLE! Attack missed completely!")
		DamagePopup.spawn_miss_popup_at(get_parent(), popup_pos)
	elif result.hit:
		if result.is_crit:
			print("💥 CRITICAL HIT! ", result.damage, " damage!")
			DamagePopup.spawn_damage_popup_at(get_parent(), popup_pos, result.damage, true)
		else:
			print("⚔️ Hit! ", result.damage, " damage!")
			DamagePopup.spawn_damage_popup_at(get_parent(), popup_pos, result.damage, false)

		# Apply damage using CombatManager
		CombatManager.apply_damage(enemy, result.damage, CombatManager.DamageType.PHYSICAL, self, result.is_crit)
	else:
		print("❌ Miss! (Rolled ", result.total, " vs AC ", result.target_ac, ")")
		DamagePopup.spawn_miss_popup_at(get_parent(), popup_pos)

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
# SPELLCASTING (pending casts readied via the spellbook panel)
# ============================================================================

func _handle_pending_spell_click(click_grid: Vector2i):
	"""Resolve a readied spell against the clicked tile.
	Validation failures (bad target / range / line of sight) keep the cast
	pending so the player can re-aim; ESC cancels it. In combat a successful
	cast consumes the attack action; out of combat only self/ally (heal & buff)
	casts are allowed and no action is consumed."""
	if is_moving:
		return

	var pending = SpellManager.get_pending_cast(self)
	var spell = SpellDatabase.get_spell(pending)
	if spell.is_empty():
		SpellManager.clear_pending_cast(self)
		return

	var world = _get_world()
	var in_world_combat = world != null and world.in_combat

	if in_world_combat and has_attacked_this_turn:
		EventBus.ui_notification.emit("You have already acted this turn!", "warning")
		return

	# Resolve the target from the spell's targeting mode
	var target_type = str(spell.get("target_type", "enemy"))
	var cast_target = null          # argument handed to SpellManager.cast_spell
	var target_tile = click_grid    # tile used for range / line-of-sight checks

	match target_type:
		"enemy":
			var clicked_enemy = world.get_enemy_at_position(click_grid) if world else null
			if clicked_enemy == null:
				EventBus.ui_notification.emit("No enemy there - click a target for %s." % str(spell.get("display_name", pending)), "warning")
				return
			cast_target = clicked_enemy
		"ally", "self":
			# Simplification: ally-targeted casts resolve on the player
			cast_target = self
			target_tile = grid_position
		_:
			# "point" / area spells target the clicked tile itself
			cast_target = click_grid

	# Out of combat, only self/ally casting is allowed
	if not in_world_combat and target_type in ["enemy", "point"]:
		EventBus.ui_notification.emit("That spell needs a combat target.", "warning")
		return

	# Range and line-of-sight validation (range_tiles 0 = self only)
	if target_tile != grid_position:
		var range_tiles = int(spell.get("range_tiles", 0))
		if CombatGrid.get_distance_tiles(grid_position, target_tile) > range_tiles:
			EventBus.ui_notification.emit("Out of range!", "warning")
			return
		if dungeon_generator and not CombatGrid.has_line_of_sight(grid_position, target_tile, dungeon_generator.dungeon_grid):
			EventBus.ui_notification.emit("No line of sight!", "warning")
			return

	var result = SpellManager.cast_spell(self, pending, cast_target)
	if not result.get("ok", false):
		# Hard failure (no slots / not castable) - drop the pending cast
		EventBus.ui_notification.emit(str(result.get("reason", "The spell fizzles.")), "warning")
		SpellManager.clear_pending_cast(self)
		queue_redraw()
		return

	SpellManager.clear_pending_cast(self)
	if in_world_combat:
		has_attacked_this_turn = true

	# Teleport results (misty step) move the player to the destination
	var teleport_to = result.get("teleport_to", null)
	if teleport_to is Vector2i and is_walkable(teleport_to):
		stop_moving()
		cancel_preview()
		grid_position = teleport_to
		position = grid_to_world(teleport_to)
		target_position = position
		_check_ground_pickup()

	_spawn_spell_popups(result)
	queue_redraw()

func _spawn_spell_popups(result: Dictionary):
	"""Floating combat text for a spell result's per-target hit entries"""
	var parent = get_parent()
	if not parent:
		return
	for entry in result.get("hits", []):
		var target = entry.get("target", null)
		if target == null or not (target is Node2D) or not is_instance_valid(target):
			continue
		var popup_pos = target.global_position + Vector2(0, -tile_size * 0.8)
		var damage = int(entry.get("damage", 0))
		var healed = int(entry.get("healed", 0))
		if damage > 0:
			DamagePopup.spawn_damage_popup_at(parent, popup_pos, damage, bool(entry.get("is_crit", false)))
		elif healed > 0:
			DamagePopup.spawn_heal_popup_at(parent, popup_pos, healed)
		elif not entry.get("hit", true):
			DamagePopup.spawn_miss_popup_at(parent, popup_pos)

# ============================================================================
# COMBAT MOVEMENT HOOKS (opportunity attacks, allies, loot pickup)
# ============================================================================

func _companion_positions() -> Array:
	"""Grid positions of living party companions (flanking allies for attack rolls)"""
	var positions: Array = []
	var world = _get_world()
	if not world:
		return positions
	var nodes = world.get("companion_nodes")
	if not (nodes is Dictionary):
		return positions
	for node in nodes.values():
		if node != null and is_instance_valid(node) and node.get("stats") != null and node.stats.is_alive():
			positions.append(node.get_grid_position())
	return positions

func _check_opportunity_attacks(from_tile: Vector2i, to_tile: Vector2i):
	"""Stepping out of an enemy's melee reach (adjacent to from_tile but not
	to_tile) provokes its opportunity attack. CombatManager self-gates the
	reaction (once per round, status effects, exact adjacency) - just call it."""
	var world = _get_world()
	if not world or not world.in_combat:
		return
	var hostiles = world.get("enemies")
	if not (hostiles is Array):
		return
	for enemy in hostiles:
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dying"):
			continue
		if enemy.get("stats") == null or not enemy.stats.is_alive():
			continue
		var enemy_pos = enemy.get_grid_position()
		if CombatGrid.get_distance_tiles(enemy_pos, from_tile) == 1 and CombatGrid.get_distance_tiles(enemy_pos, to_tile) > 1:
			CombatManager.trigger_opportunity_attack(enemy, self)
			# Stop checking if a reaction dropped us
			if is_dying or not stats or not stats.is_alive():
				return

func _check_ground_pickup():
	"""Pick up any ground loot on the tile the player now occupies"""
	var world = _get_world()
	if not world:
		return
	var ground = world.get_node_or_null("GroundItems")
	if not ground:
		return
	for drop in ground.get_children():
		if not is_instance_valid(drop):
			continue
		if drop.get("grid_pos") == grid_position and drop.has_method("pickup"):
			drop.pickup()

# ============================================================================
# TURN-BASED SYSTEM
# ============================================================================

func toggle_turn_based_mode():
	"""Toggle turn-based mode on/off"""
	# Turn-based mode is controlled by the world while in combat -
	# toggling it off mid-combat would desync the combat loop
	var world = _get_world()
	if world and world.in_combat:
		print("Cannot toggle turn-based mode during combat!")
		return

	turn_based_mode = !turn_based_mode

	if turn_based_mode:
		# Snap to the grid so turn-based movement starts from a tile center
		stop_moving()
		cancel_preview()
		start_new_turn()
		print("Turn-based mode ENABLED - Press T to toggle, SPACE to end turn")
		print("Turn ", turn_number, " - Moves remaining: ", moves_remaining)
	else:
		print("Turn-based mode DISABLED - Free movement with WASD or click")

func start_new_turn():
	"""Start a new turn with full movement"""
	turn_number += 1
	moves_remaining = stats.get_modified_movement_speed()  # UPDATED - Uses encumbrance
	has_attacked_this_turn = false

	# Status-effect ticks at the start of the turn (burning, regenerating, ...)
	StatusEffectManager.process_turn_start(self)

	# A tick may have killed us - the death path owns the rest
	if is_dying or not stats or not stats.is_alive():
		return

	# Speed modifiers from status effects (slowed/hasted/restrained)
	moves_remaining = max(0, moves_remaining + StatusEffectManager.get_speed_modifier_tiles(self))
	moves_granted_this_turn = moves_remaining

	print("=== Turn ", turn_number, " started ===")
	print("Movement available: ", moves_remaining, " tiles")

	# Emit event
	EventBus.turn_started.emit(self)

	# Incapacitated (stunned/paralyzed/frozen): lose the turn. Deferred so the
	# world's combat loop is never advanced re-entrantly from inside this call.
	if StatusEffectManager.is_incapacitated(self):
		moves_remaining = 0
		EventBus.ui_notification.emit("You are incapacitated and lose your turn!", "warning")
		print("Player is incapacitated - turn skipped")
		call_deferred("_auto_end_incapacitated_turn")

func _auto_end_incapacitated_turn():
	"""Deferred auto end-of-turn while incapacitated (world combat only -
	outside combat the player can still press SPACE themselves)"""
	if is_dying or not turn_based_mode or is_moving:
		return
	var world = _get_world()
	if not world or not world.in_combat:
		return
	if world.initiative_tracker and not world.initiative_tracker.is_player_turn():
		return
	end_turn()

func end_turn():
	"""Manually end the current turn"""
	if not turn_based_mode:
		return

	if is_moving:
		print("Cannot end turn while moving!")
		return

	print("Turn ", turn_number, " ended. Moves used: ", max(0, moves_granted_this_turn - moves_remaining))

	var world = _get_world()
	var in_world_combat = world != null and world.in_combat

	if in_world_combat:
		# No leftover movement while enemies take their turns
		moves_remaining = 0

	# End-of-turn status bookkeeping (ticks, end saves, duration countdown)
	StatusEffectManager.process_turn_end(self)

	# Emit event (NEW)
	EventBus.turn_ended.emit(self)
	turn_ended.emit()

	# In combat the world's initiative loop grants the next turn;
	# outside combat (manual T mode) we cycle our own turns
	if not in_world_combat:
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
	"""Apply direct damage with visual effects (e.g. traps, hazards).
	NOTE: attacks should go through CombatManager.apply_damage instead."""
	if not stats:
		return

	var still_alive = stats.take_damage(amount)
	print("%s took %d damage! HP: %d/%d" % [name, amount, stats.current_hp, stats.max_hp])

	# Spawn damage popup
	var world = get_parent()
	if world:
		var popup_pos = global_position + Vector2(0, -tile_size * 0.8)
		DamagePopup.spawn_damage_popup_at(world, popup_pos, amount, false)

	# Flash effect
	flash_damage()

	# Emit event
	EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)

	queue_redraw()

	if not still_alive:
		# Route through CombatManager so death events stay consistent
		CombatManager.handle_death(self)

func _on_damage_dealt_event(_attacker, target, _amount, _is_critical):
	"""Keep HP signal/visuals in sync when CombatManager applies damage to stats"""
	if target == self and stats:
		flash_damage()
		EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)
		queue_redraw()

func _on_game_loaded(_slot: int):
	"""Re-emit HP after SaveManager restores stats directly"""
	if stats:
		EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)
	queue_redraw()

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
	
	# Emit event
	EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)
	
	queue_redraw()

func die():
	"""Handle death"""
	if is_dying:
		return
	is_dying = true

	print("%s has died!" % name)

	# NOTE: EventBus.character_died is emitted by CombatManager.handle_death()
	# before die() is called - emitting it here too would double-fire it

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
	"""Gain XP and potentially level up. Delegates to CharacterStats, which
	emits EventBus.player_gained_xp itself - emitting here too double-counted."""
	stats.gain_experience(amount)
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
		EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)

	if data.has("turn_number"):
		turn_number = data.turn_number
	
	if data.has("turn_based_mode"):
		turn_based_mode = data.turn_based_mode
