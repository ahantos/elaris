extends CharacterBody2D
class_name Enemy

# Basic grid-based enemy with AI and combat effects

@export var tile_size: int = 16
@export var move_speed: float = 200.0
@export var dungeon_generator: DungeonGenerator
@export var moves_per_turn: int = 6
@export var enemy_color: Color = Color(1, 0, 0, 1)

@export_group("Combat Stats")
@export var max_hp: int = 10
@export var current_hp: int = 10
@export var attack_damage: int = 2

var grid_position: Vector2i = Vector2i(0, 0)
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var player: GridCharacter = null

# Pathfinding
var path: Array[Vector2i] = []
var path_index: int = 0

# Stats system (NEW)
var stats: CharacterStats

func _ready():
	z_index = 200
	
	# Auto-detect tile size
	if dungeon_generator and dungeon_generator.tilemap and dungeon_generator.tilemap.tile_set:
		tile_size = int(dungeon_generator.tilemap.tile_set.tile_size.x)
	
	# Initialize enemy stats (NEW)
	initialize_stats()
	
	# Auto-scale sprite
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		var texture_size = sprite.texture.get_size()
		var target_size = tile_size * 0.8
		var scale_factor = target_size / max(texture_size.x, texture_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.modulate = enemy_color

func initialize_stats():
	"""Initialize enemy stats"""
	stats = CharacterStats.new({
		"str": 12,
		"dex": 10,
		"con": 12,
		"int": 8,
		"wis": 10,
		"cha": 8
	})
	
	# Override HP with enemy's max_hp
	stats.max_hp = max_hp
	stats.current_hp = current_hp
	stats.movement_speed = moves_per_turn
	
	print("Enemy stats initialized: HP ", stats.current_hp, "/", stats.max_hp)

func spawn_at(spawn_pos: Vector2i):
	"""Spawn enemy at specific grid position"""
	grid_position = spawn_pos
	position = grid_to_world(grid_position)
	target_position = position

func take_turn():
	"""Enemy takes its turn"""
	if is_moving:
		return
	
	if not player:
		return
	
	var player_pos = player.get_grid_position()
	
	# Check if already adjacent to player
	var dx = abs(grid_position.x - player_pos.x)
	var dy = abs(grid_position.y - player_pos.y)
	
	if dx <= 1 and dy <= 1 and (dx + dy) > 0:
		# Already adjacent - attack
		attack_player()
		return
	
	# Calculate path toward player
	path = _calculate_path_to_player(player_pos)
	
	if path.size() <= 1:
		return
	
	# Take up to moves_per_turn steps
	var steps = min(moves_per_turn, path.size() - 1)
	
	# Start moving
	path_index = 1
	target_position = grid_to_world(path[path_index])
	is_moving = true

func create_temp_weapon() -> ItemData:
	"""Create temporary weapon for enemy (TEMPORARY - Phase 2 will give enemies real weapons)"""
	var weapon = ItemData.new()
	weapon.item_name = "Enemy Weapon"
	weapon.is_weapon = true
	weapon.weapon_type = "simple"
	weapon.damage_dice = "1d6"  # Simple enemy attack
	
	return weapon

func attack_player():
	"""Attack the player with animation (REFACTORED)"""
	if player:
		# Get weapon (TODO: enemies will have weapons in Phase 2)
		var weapon = create_temp_weapon()
		
		# Attack animation
		animate_attack(player.global_position)
		
		# Wait for animation
		await get_tree().create_timer(0.15).timeout
		
		# Roll attack using CombatManager
		var result = CombatManager.roll_attack(stats, player.stats, weapon)
		
		if result.is_fumble:
			print("%s fumbled the attack!" % name)
			DamagePopup.spawn_miss_popup_at(get_parent(), player.global_position + Vector2(0, -tile_size * 0.8))
		elif result.hit:
			if result.is_crit:
				print("%s lands a CRITICAL HIT on Player for %d damage!" % [name, result.damage])
				DamagePopup.spawn_damage_popup_at(get_parent(), player.global_position + Vector2(0, -tile_size * 0.8), result.damage, true)
			else:
				print("%s hits Player for %d damage!" % [name, result.damage])
				DamagePopup.spawn_damage_popup_at(get_parent(), player.global_position + Vector2(0, -tile_size * 0.8), result.damage, false)
			
			# Apply damage using CombatManager
			CombatManager.apply_damage(player, result.damage, CombatManager.DamageType.PHYSICAL, self)
		else:
			print("%s missed Player! (Rolled %d vs AC %d)" % [name, result.total, result.target_ac])
			DamagePopup.spawn_miss_popup_at(get_parent(), player.global_position + Vector2(0, -tile_size * 0.8))

func animate_attack(target_pos: Vector2):
	"""Animate a quick lunge toward the target"""
	var original_pos = global_position
	var direction = (target_pos - original_pos).normalized()
	var lunge_distance = tile_size * 0.5
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", original_pos + direction * lunge_distance, 0.1)
	tween.tween_property(self, "global_position", original_pos, 0.15)

func _calculate_path_to_player(player_pos: Vector2i) -> Array[Vector2i]:
	"""Calculate path using A* to get adjacent to player"""
	# Find all tiles adjacent to player
	var adjacent_tiles: Array[Vector2i] = []
	
	# Prioritize cardinal directions
	var cardinals = [
		player_pos + Vector2i(1, 0),
		player_pos + Vector2i(-1, 0),
		player_pos + Vector2i(0, 1),
		player_pos + Vector2i(0, -1)
	]
	
	var diagonals = [
		player_pos + Vector2i(1, 1),
		player_pos + Vector2i(1, -1),
		player_pos + Vector2i(-1, 1),
		player_pos + Vector2i(-1, -1)
	]
	
	# Add walkable cardinals first
	for pos in cardinals:
		if is_walkable(pos):
			adjacent_tiles.append(pos)
	
	# Add diagonals if no cardinals available
	if adjacent_tiles.is_empty():
		for pos in diagonals:
			if is_walkable(pos):
				adjacent_tiles.append(pos)
	
	if adjacent_tiles.is_empty():
		return [grid_position]
	
	# Find closest adjacent tile
	var best_target = adjacent_tiles[0]
	var best_path = _astar_path(grid_position, best_target)
	var best_dist = best_path.size()
	
	for tile in adjacent_tiles:
		var test_path = _astar_path(grid_position, tile)
		if test_path.size() < best_dist:
			best_dist = test_path.size()
			best_target = tile
			best_path = test_path
	
	return best_path

func _astar_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	"""A* pathfinding implementation"""
	if from == to:
		return [from]
	
	var open_set: Array[Vector2i] = [from]
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0}
	var f_score: Dictionary = {from: _heuristic(from, to)}
	
	while not open_set.is_empty():
		# Find node with lowest f_score
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
		
		# Reached destination
		if current == to:
			return _reconstruct_path(came_from, current)
		
		# Move to closed set
		open_set.remove_at(current_idx)
		closed_set[current] = true
		
		# Check neighbors
		for neighbor in _get_neighbors(current):
			if neighbor in closed_set:
				continue
			
			if not is_walkable(neighbor):
				continue
			
			var tentative_g = g_score.get(current, INF) + 1
			
			if neighbor not in open_set:
				open_set.append(neighbor)
			elif tentative_g >= g_score.get(neighbor, INF):
				continue
			
			came_from[neighbor] = current
			g_score[neighbor] = tentative_g
			f_score[neighbor] = tentative_g + _heuristic(neighbor, to)
	
	# No path found
	return [from]

func _get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	"""Get 8 adjacent neighbors"""
	var neighbors: Array[Vector2i] = []
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			
			var neighbor = pos + Vector2i(dx, dy)
			
			# For diagonals, check if both adjacent cardinals are walkable
			if abs(dx) + abs(dy) == 2:
				if is_walkable(Vector2i(pos.x + dx, pos.y)) and is_walkable(Vector2i(pos.x, pos.y + dy)):
					neighbors.append(neighbor)
			else:
				neighbors.append(neighbor)
	
	return neighbors

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	"""Diagonal distance heuristic"""
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return max(dx, dy)

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	"""Reconstruct path from A*"""
	var result: Array[Vector2i] = [current]
	while current in came_from:
		current = came_from[current]
		result.insert(0, current)
	return result

func _physics_process(delta):
	if is_moving and path.size() > 0:
		position = position.move_toward(target_position, move_speed * delta)
		
		if position.distance_to(target_position) < 1.0:
			position = target_position
			grid_position = path[path_index]
			path_index += 1
			
			# Check if should continue moving
			if path_index < path.size() and path_index <= moves_per_turn:
				target_position = grid_to_world(path[path_index])
			else:
				# Done moving this turn
				is_moving = false
				path.clear()
				path_index = 0
				
				# After moving, check if adjacent to player and attack
				check_and_attack_player()
	
	# Always redraw to show HP bar
	queue_redraw()

func check_and_attack_player():
	"""Check if adjacent to player after moving and attack if so"""
	if not player:
		return
	
	var player_pos = player.get_grid_position()
	var dx = abs(grid_position.x - player_pos.x)
	var dy = abs(grid_position.y - player_pos.y)
	
	# Adjacent means within 1 tile (including diagonals)
	if dx <= 1 and dy <= 1 and (dx + dy) > 0:
		attack_player()

func _draw():
	"""Draw HP bar above enemy"""
	# Only show HP bar when in combat
	var world = get_tree().root.get_node_or_null("World")
	if world and world.in_combat:
		draw_hp_bar()

func draw_hp_bar():
	"""Draw HP bar above the enemy"""
	var bar_width = tile_size * 1.2
	var bar_height = 6.0
	var bar_offset = Vector2(-bar_width / 2, -tile_size * 0.8)
	
	# Background (black)
	draw_rect(Rect2(bar_offset, Vector2(bar_width, bar_height)), Color.BLACK)
	
	# Health (green to red gradient based on HP percentage)
	var hp_percent = float(stats.current_hp) / float(stats.max_hp)
	var health_width = bar_width * hp_percent
	var health_color = Color.GREEN.lerp(Color.RED, 1.0 - hp_percent)
	
	if health_width > 0:
		draw_rect(Rect2(bar_offset, Vector2(health_width, bar_height)), health_color)
	
	# Border (white)
	draw_rect(Rect2(bar_offset, Vector2(bar_width, bar_height)), Color.WHITE, false, 1.0)

func is_walkable(grid_pos: Vector2i) -> bool:
	"""Check if position is walkable"""
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
	
	# Check if player occupies this position
	if player and player.get_grid_position() == grid_pos:
		return false
	
	# Check if any other enemy occupies this position
	var world = get_tree().root.get_node_or_null("World")
	if world and world.has_method("is_position_occupied_by_enemy"):
		if world.is_position_occupied_by_enemy(grid_pos, self):
			return false
	
	return true

func world_to_grid(world_pos: Vector2) -> Vector2i:
	"""Convert world to grid position"""
	return Vector2i(
		int(world_pos.x / tile_size),
		int(world_pos.y / tile_size)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Convert grid to world position"""
	return Vector2(
		grid_pos.x * tile_size + tile_size / 2.0,
		grid_pos.y * tile_size + tile_size / 2.0
	)

func get_grid_position() -> Vector2i:
	"""Get current grid position"""
	return grid_position

func take_damage(amount: int):
	"""Take damage with visual effects (REFACTORED)"""
	# Flash effect
	flash_damage()
	
	queue_redraw()
	
	if not stats or not stats.is_alive():
		die()

func flash_damage():
	"""Quick red flash when taking damage"""
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 0.5, 0.5), 0.1)
		tween.tween_property(sprite, "modulate", enemy_color, 0.2)

func die():
	"""Handle death with effects"""
	print("%s has died!" % name)
	
	# Death animation - fade out and shrink
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.5)
		await tween.finished
	
	# Notify world that this enemy died
	var world = get_tree().root.get_node_or_null("World")
	if world:
		world.on_enemy_died(self)
	
	queue_free()

func get_hp() -> int:
	"""Get current HP (REFACTORED)"""
	return stats.current_hp if stats else 0

func get_max_hp() -> int:
	"""Get max HP (REFACTORED)"""
	return stats.max_hp if stats else 0
