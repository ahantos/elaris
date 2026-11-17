# combatant.gd
# The body every creature in a fight shares: the player, party companions and
# enemies. It holds what the three have in common - a tile on the grid, stats, a
# team, hit points, the damage flash, the HP bar, walkability and pathfinding.
# What a combatant does with its turn stays in the subclass: input and path
# preview in GridCharacter, enemy AI in Enemy, following and ally AI in Companion.
extends CharacterBody2D
class_name Combatant

enum Team { PARTY, HOSTILE }

@export var tile_size: int = 32
@export var move_speed: float = 400.0  # Pixels per second (12.5 tiles on the 32px grid)
@export var dungeon_generator: DungeonGenerator

# Which side this combatant fights on. Hostility is decided by team alone.
var team: Team = Team.HOSTILE

var stats: CharacterStats

var grid_position: Vector2i = Vector2i(0, 0)
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

# Death guard (prevents double death handling)
var is_dying: bool = false

# Cached World node (avoids per-call scene tree lookups in hot paths)
var world_node = null

# What the sprite flashes when the combatant is hit
var damage_flash_color: Color = Color(2.0, 0.5, 0.5)

func _ready():
	"""Set-up every combatant shares. Subclasses call super._ready() first, then
	build their stats and sprite."""
	z_index = 200
	world_node = get_tree().root.get_node_or_null("World")

	if dungeon_generator and dungeon_generator.tilemap and dungeon_generator.tilemap.tile_set:
		tile_size = int(dungeon_generator.tilemap.tile_set.tile_size.x)

	# CombatManager applies damage straight to stats; this keeps the visuals in step
	EventBus.damage_dealt.connect(_on_damage_dealt_event)

# ============================================================================
# TEAM AND TURN
# ============================================================================

func is_alive() -> bool:
	"""Still able to fight. A body can outlive its owner (the player's stays in
	the scene after death), so a valid node says nothing about being alive."""
	return not is_dying and stats != null and stats.is_alive()

func is_hostile_to(other) -> bool:
	"""True when other is a combatant on another team"""
	return is_instance_valid(other) and other is Combatant and other.team != team

func is_player_controlled() -> bool:
	"""True when this combatant's turn waits for the player's input. The
	CombatController then calls start_new_turn() and waits for end_turn();
	everyone else gets take_turn()."""
	return false

func take_turn():
	"""Act for one turn without input (see is_player_controlled)"""
	pass

func on_combat_started():
	"""The CombatController calls this on everyone who joins a fight"""
	queue_redraw()

func on_combat_ended():
	"""The CombatController calls this on everyone who took part, when the fight ends"""
	queue_redraw()

func in_combat() -> bool:
	"""True while the world is running a fight"""
	var world = _get_world()
	return world != null and world.in_combat

func can_act() -> bool:
	"""May this combatant act right now? Outside a fight, whenever it likes; in
	a fight, only on its own turn."""
	if not is_alive():
		return false
	var combat = _get_combat()
	return combat == null or not combat.active or combat.is_turn_of(self)

func _get_combat():
	"""The world's CombatController, or null when there is none"""
	var world = _get_world()
	return world.get("combat") if world else null

func _get_world():
	"""Get the cached World node (re-resolves if missing/freed)"""
	if not is_instance_valid(world_node):
		world_node = get_tree().root.get_node_or_null("World")
	return world_node

# ============================================================================
# OTHER COMBATANTS
# ============================================================================

func get_hostiles() -> Array[Combatant]:
	"""Every living combatant in the world that is on another team"""
	var hostiles: Array[Combatant] = []
	var world = _get_world()
	if world == null or not world.has_method("get_combatants"):
		return hostiles
	for other in world.get_combatants():
		if other.is_alive() and is_hostile_to(other):
			hostiles.append(other)
	return hostiles

func get_ally_positions() -> Array:
	"""Tiles of the living combatants on this one's team (flanking partners for
	attack rolls)"""
	var positions: Array = []
	var world = _get_world()
	if world == null or not world.has_method("get_combatants"):
		return positions
	for other in world.get_combatants():
		if other != self and other.team == team and other.is_alive():
			positions.append(other.get_grid_position())
	return positions

func _check_opportunity_attacks(from_tile: Vector2i, to_tile: Vector2i):
	"""Stepping out of a hostile's melee reach (adjacent to from_tile but not to
	to_tile) provokes its opportunity attack. CombatManager self-gates the
	reaction (once per round, status effects, exact adjacency) - just call it."""
	if not in_combat():
		return
	for hostile in get_hostiles():
		var hostile_pos = hostile.get_grid_position()
		if CombatGrid.get_distance_tiles(hostile_pos, from_tile) == 1 and CombatGrid.get_distance_tiles(hostile_pos, to_tile) > 1:
			CombatManager.trigger_opportunity_attack(hostile, self)
			# Stop checking if a reaction dropped us
			if not is_alive():
				return

# ============================================================================
# GRID
# ============================================================================

func world_to_grid(world_pos: Vector2) -> Vector2i:
	"""Convert world position to grid coordinates"""
	return Vector2i(
		int(world_pos.x / tile_size),
		int(world_pos.y / tile_size)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Convert grid coordinates to the world position of the tile's centre"""
	return Vector2(
		grid_pos.x * tile_size + tile_size / 2.0,
		grid_pos.y * tile_size + tile_size / 2.0
	)

func get_grid_position() -> Vector2i:
	"""Get current grid position"""
	return grid_position

func spawn_at(spawn_pos: Vector2i):
	"""Put the combatant on a tile, standing still"""
	grid_position = spawn_pos
	position = grid_to_world(grid_position)
	target_position = position

func is_walkable(grid_pos: Vector2i) -> bool:
	"""A floor or door tile inside the dungeon that no other combatant stands on"""
	if not is_instance_valid(dungeon_generator):
		return false

	if grid_pos.x < 0 or grid_pos.x >= dungeon_generator.dungeon_width:
		return false
	if grid_pos.y < 0 or grid_pos.y >= dungeon_generator.dungeon_height:
		return false

	var tile_type = dungeon_generator.dungeon_grid[grid_pos.y][grid_pos.x]
	if tile_type != dungeon_generator.TileType.FLOOR and tile_type != dungeon_generator.TileType.DOOR:
		return false

	var world = _get_world()
	if world and world.has_method("is_tile_occupied") and world.is_tile_occupied(grid_pos, self):
		return false

	return true

# ============================================================================
# PATHFINDING (the one A* every combatant uses)
# ============================================================================

func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	"""A* over walkable tiles, eight directions. Returns the tiles from `from` to
	`to`, both included, or [from] when there is no way. Diagonal steps cost a
	little more so a straight line beats a zigzag of the same length."""
	if not is_walkable(to):
		return [from]

	if from == to:
		return [from]

	var open_set: Array[Vector2i] = [from]
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0}
	var f_score: Dictionary = {from: _path_heuristic(from, to)}

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

		for neighbor in _path_neighbors(current):
			if neighbor in closed_set:
				continue

			if not is_walkable(neighbor):
				continue

			var move_cost = 1.0
			if abs(neighbor.x - current.x) + abs(neighbor.y - current.y) == 2:
				move_cost = 1.414

			var tentative_g = g_score.get(current, INF) + move_cost

			if neighbor not in open_set:
				open_set.append(neighbor)
			elif tentative_g >= g_score.get(neighbor, INF):
				continue

			came_from[neighbor] = current
			g_score[neighbor] = tentative_g
			f_score[neighbor] = tentative_g + _path_heuristic(neighbor, to)

	return [from]

func _path_neighbors(pos: Vector2i) -> Array[Vector2i]:
	"""The four cardinal neighbours, then each diagonal that does not cut a corner
	(both tiles beside it must be walkable)"""
	var neighbors: Array[Vector2i] = [
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x, pos.y - 1),
	]

	for step in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if is_walkable(Vector2i(pos.x + step.x, pos.y)) and is_walkable(Vector2i(pos.x, pos.y + step.y)):
			neighbors.append(pos + step)

	return neighbors

func _path_heuristic(a: Vector2i, b: Vector2i) -> int:
	"""Diagonal (Chebyshev) distance"""
	return max(abs(a.x - b.x), abs(a.y - b.y))

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	"""Walk came_from back to the start"""
	var path_result: Array[Vector2i] = [current]
	while current in came_from:
		current = came_from[current]
		path_result.insert(0, current)
	return path_result

# ============================================================================
# HIT POINTS AND DAMAGE FEEDBACK
# ============================================================================

func get_hp() -> int:
	"""Get current HP"""
	return stats.current_hp if stats else 0

func get_max_hp() -> int:
	"""Get max HP"""
	return stats.max_hp if stats else 0

func take_damage(amount: int):
	"""Apply direct damage with visual effects (e.g. traps, hazards).
	NOTE: attacks should go through CombatManager.apply_damage instead."""
	if not stats:
		return

	var still_alive = stats.take_damage(amount)
	print("%s took %d damage! HP: %d/%d" % [name, amount, stats.current_hp, stats.max_hp])

	flash_damage()
	queue_redraw()

	if not still_alive:
		# Route through CombatManager so death events stay consistent
		CombatManager.handle_death(self)

func _on_damage_dealt_event(_attacker, target, _amount, _is_critical):
	"""Flash when CombatManager applies damage to this combatant"""
	if target == self:
		flash_damage()
		queue_redraw()

func flash_damage():
	"""Quick flash when taking damage"""
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", damage_flash_color, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func animate_attack(target_pos: Vector2):
	"""Animate a quick lunge toward the target"""
	var original_pos = global_position
	var direction = (target_pos - original_pos).normalized()
	var lunge_distance = tile_size * 0.5

	var tween = create_tween()
	tween.tween_property(self, "global_position", original_pos + direction * lunge_distance, 0.1)
	tween.tween_property(self, "global_position", original_pos, 0.15)

func draw_hp_bar():
	"""Draw the HP bar above the combatant (call from _draw)"""
	if not stats:
		return

	# Narrower than a tile so neighbours' bars do not run together, and on whole
	# pixels so the edges stay sharp at 2x
	var bar_width = round(tile_size * 0.8)
	var bar_height = 4.0
	var bar_offset = Vector2(-bar_width / 2, -tile_size / 2.0 - bar_height - 3.0)

	# Background
	draw_rect(Rect2(bar_offset, Vector2(bar_width, bar_height)), Color.BLACK)

	# Health, green to red as it drops
	var hp_percent = stats.get_hp_percent()
	var health_width = bar_width * hp_percent
	var health_color = Color.GREEN.lerp(Color.RED, 1.0 - hp_percent)

	if health_width > 0:
		draw_rect(Rect2(bar_offset, Vector2(health_width, bar_height)), health_color)

	# Border
	draw_rect(Rect2(bar_offset, Vector2(bar_width, bar_height)), Color.WHITE, false, 1.0)
