# companion.gd
# CharacterBody2D script for a recruited companion node in the dungeon.
# Modelled on enemy.gd: grid-based movement, A*-lite pathfinding, combat turn.
# The node is built purely in code by CompanionManager.create_companion_node()
# and then UNPARENTED — the integration layer (world.gd / orchestrator) adds it
# to the scene and sets dungeon_generator / player references.
extends CharacterBody2D
class_name Companion

# ── Exports (integration sets these after spawning) ────────────────────────────
@export var tile_size: int = 16
@export var move_speed: float = 180.0

# ── Identity ───────────────────────────────────────────────────────────────────
var companion_id: String = ""   # Set by create_companion_node() before _ready()

# ── References (set by integration / world after spawning) ────────────────────
var dungeon_generator = null    # DungeonGenerator node
var player = null               # GridCharacter node
var world_node = null           # World node

# ── Grid state ────────────────────────────────────────────────────────────────
var grid_position: Vector2i = Vector2i(0, 0)
var target_position: Vector2  = Vector2.ZERO
var is_moving: bool = false

# ── Pathfinding ───────────────────────────────────────────────────────────────
var _path: Array[Vector2i] = []
var _path_index: int = 0

# ── Stats (built from CharacterBuilder / CharacterStats at _ready) ────────────
var stats: CharacterStats = null

# ── Sprite reference ──────────────────────────────────────────────────────────
var _sprite: Sprite2D = null

const _COMPANION_COLOR = Color(0.3, 0.9, 0.4, 1.0)   # green tint placeholder


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready():
	"""Build sprite, load stats, cache world reference."""
	z_index = 190  # Just below enemies (200)

	# Build Sprite2D placeholder (green-tinted icon.svg like enemy.tscn)
	_sprite = Sprite2D.new()
	var icon_tex = load("res://icon.svg") if ResourceLoader.exists("res://icon.svg") else null
	if icon_tex:
		_sprite.texture = icon_tex
		var tex_size = icon_tex.get_size()
		var target_sz = tile_size * 0.8
		var sf = target_sz / max(tex_size.x, tex_size.y)
		_sprite.scale = Vector2(sf, sf)
	_sprite.modulate = _COMPANION_COLOR
	add_child(_sprite)

	# Cache world reference
	world_node = get_tree().root.get_node_or_null("World")

	# Initialise stats
	_init_stats()

	# Listen to damage events for visual feedback
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		pass
	else:
		EventBus.damage_dealt.connect(_on_damage_dealt)

	target_position = position


func _get_world():
	"""Re-resolve World node if stale."""
	if not is_instance_valid(world_node):
		world_node = get_tree().root.get_node_or_null("World")
	return world_node


func _on_damage_dealt(_attacker, target, _amount, _is_critical):
	"""Flash when this companion is hit."""
	if target == self:
		_flash_damage()
		queue_redraw()


func _init_stats():
	"""
	Build CharacterStats using CharacterBuilder if available,
	falling back to a plain CharacterStats from base_stats.
	"""
	var defn: Dictionary = {}
	if CompanionManager.companion_definitions.has(companion_id):
		defn = CompanionManager.companion_definitions[companion_id]

	var base_stats: Dictionary = defn.get("base_stats", {
		"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10
	})
	var class_id: String  = defn.get("class_id",  "")
	var race_id:  String  = defn.get("race_id",   "")
	var char_name: String = defn.get("display_name", companion_id)

	var builder_path = "res://data/stats/character_builder.gd"
	var builder_script = load(builder_path) if ResourceLoader.exists(builder_path) else null

	if builder_script and builder_script.has_method("build"):
		stats = builder_script.build(class_id, race_id, base_stats, char_name)
	else:
		stats = CharacterStats.new(base_stats)

	if stats:
		stats.character_uid  = "companion_%s" % companion_id
		stats.character_name = char_name
		stats.class_id       = class_id
		stats.race_id        = race_id
		print("Companions: %s stats initialised — HP %d/%d" % [
			char_name, stats.current_hp, stats.max_hp
		])
	else:
		push_error("Companions: _init_stats() produced null stats for '%s'" % companion_id)


# ── Grid helpers ──────────────────────────────────────────────────────────────

func spawn_at(spawn_pos: Vector2i):
	"""Place companion at a grid position."""
	grid_position = spawn_pos
	position = grid_to_world(grid_position)
	target_position = position


func grid_to_world(gp: Vector2i) -> Vector2:
	return Vector2(gp.x * tile_size + tile_size / 2.0,
	               gp.y * tile_size + tile_size / 2.0)


func world_to_grid(wp: Vector2) -> Vector2i:
	return Vector2i(int(wp.x / tile_size), int(wp.y / tile_size))


func get_grid_position() -> Vector2i:
	return grid_position


func is_walkable(gp: Vector2i) -> bool:
	"""Check tile walkability against dungeon grid (mirrors enemy.gd logic)."""
	if not is_instance_valid(dungeon_generator):
		return false
	if gp.x < 0 or gp.x >= dungeon_generator.dungeon_width:
		return false
	if gp.y < 0 or gp.y >= dungeon_generator.dungeon_height:
		return false

	var tile_type = dungeon_generator.dungeon_grid[gp.y][gp.x]
	var is_floor = (tile_type == dungeon_generator.TileType.FLOOR or
	                tile_type == dungeon_generator.TileType.DOOR)
	if not is_floor:
		return false

	# Don't block player's tile
	if is_instance_valid(player) and player.get_grid_position() == gp:
		return false

	# Don't block another companion's tile
	var world = _get_world()
	if world and world.has_method("is_position_occupied_by_companion"):
		if world.is_position_occupied_by_companion(gp, self):
			return false

	return true


# ── Exploration follow ────────────────────────────────────────────────────────

func _follow_player():
	"""
	If player is more than 2 tiles away, step one tile closer along a
	greedy A* path toward a tile adjacent to the player.
	"""
	if not is_instance_valid(player):
		return

	var player_pos = player.get_grid_position()
	var dist = _chebyshev(grid_position, player_pos)
	if dist <= 2:
		return  # Close enough — stay put

	# Find a reachable tile adjacent to player
	var targets: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var t = player_pos + Vector2i(dx, dy)
			if is_walkable(t):
				targets.append(t)

	if targets.is_empty():
		return

	# Pick closest target
	var best_target = targets[0]
	var best_dist   = _chebyshev(grid_position, best_target)
	for t in targets:
		var d = _chebyshev(grid_position, t)
		if d < best_dist:
			best_dist   = d
			best_target = t

	var path = _astar_path(grid_position, best_target)
	if path.size() < 2:
		return

	# Take one greedy step
	var next_tile = path[1]
	if is_walkable(next_tile):
		_path = path
		_path_index = 1
		target_position = grid_to_world(next_tile)
		is_moving = true


# ── Combat turn ───────────────────────────────────────────────────────────────

func take_turn():
	"""
	Companion turn: if adjacent to a living enemy → attack;
	else step toward the nearest enemy.
	"""
	if is_moving:
		return
	if not stats or not stats.is_alive():
		return

	var world = _get_world()
	if not is_instance_valid(world):
		return

	# Gather living enemies
	var enemies: Array = []
	if world.has_method("get") and "enemies" in world:
		enemies = world.enemies.filter(func(e): return is_instance_valid(e) and e.stats and e.stats.is_alive())
	elif world.has_method("get_living_enemies"):
		enemies = world.get_living_enemies()

	if enemies.is_empty():
		return

	# Check adjacency
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var epos = enemy.grid_position if "grid_position" in enemy else Vector2i(-999, -999)
		if _chebyshev(grid_position, epos) <= 1:
			_attack_enemy(enemy)
			return

	# No adjacent enemy — step toward nearest
	var nearest = _find_nearest_enemy(enemies)
	if nearest == null:
		return

	var nepos = nearest.grid_position if "grid_position" in nearest else Vector2i(-999, -999)
	var path = _astar_path(grid_position, _adjacent_tile_toward(nepos))
	if path.size() >= 2:
		var next_tile = path[1]
		if is_walkable(next_tile):
			grid_position = next_tile
			target_position = grid_to_world(next_tile)
			_path = path
			_path_index = 1
			is_moving = true


func _attack_enemy(enemy):
	"""Roll and apply one attack against an enemy via CombatManager."""
	if not is_instance_valid(enemy) or not enemy.stats:
		return
	if not stats:
		return

	var weapon = null  # Companions use unarmed / class default for now

	# Use CombatManager if available
	if CombatManager and CombatManager.has_method("roll_attack"):
		var result = CombatManager.roll_attack(stats, enemy.stats, weapon)
		if result.is_empty():
			return
		if result.get("hit", false):
			var dmg: int = result.get("damage", 1)
			CombatManager.apply_damage(enemy, dmg, CombatManager.DamageType.PHYSICAL, self, result.get("is_crit", false))
			print("Companions: %s hits %s for %d damage" % [companion_id, enemy.name, dmg])
		else:
			print("Companions: %s missed %s" % [companion_id, enemy.name])
	else:
		# Fallback: direct damage
		enemy.take_damage(1)


func _find_nearest_enemy(enemies: Array):
	"""Return the nearest living enemy node."""
	var nearest = null
	var nearest_dist: int = 999999
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var epos = e.grid_position if "grid_position" in e else Vector2i(-999, -999)
		var d = _chebyshev(grid_position, epos)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest


func _adjacent_tile_toward(target: Vector2i) -> Vector2i:
	"""Return a walkable tile adjacent to target, favouring the closest to self."""
	var candidates: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var t = target + Vector2i(dx, dy)
			if is_walkable(t):
				candidates.append(t)
	if candidates.is_empty():
		return target
	var best = candidates[0]
	var best_d = _chebyshev(grid_position, best)
	for c in candidates:
		var d = _chebyshev(grid_position, c)
		if d < best_d:
			best_d = d
			best   = c
	return best


# ── A* pathfinding (mirrors enemy.gd) ────────────────────────────────────────

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


func _astar_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [from]

	var open_set: Array[Vector2i] = [from]
	var closed_set: Dictionary  = {}
	var came_from:  Dictionary  = {}
	var g_score:    Dictionary  = {from: 0}
	var f_score:    Dictionary  = {from: _chebyshev(from, to)}

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

		for nbr in _get_neighbors(current):
			if nbr in closed_set:
				continue
			if not is_walkable(nbr):
				continue
			var tg = g_score.get(current, INF) + 1
			if nbr not in open_set:
				open_set.append(nbr)
			elif tg >= g_score.get(nbr, INF):
				continue
			came_from[nbr] = current
			g_score[nbr]   = tg
			f_score[nbr]   = tg + _chebyshev(nbr, to)

	return [from]


func _get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nbr = pos + Vector2i(dx, dy)
			if abs(dx) + abs(dy) == 2:
				# Diagonal: both cardinals must be walkable
				if is_walkable(Vector2i(pos.x + dx, pos.y)) and is_walkable(Vector2i(pos.x, pos.y + dy)):
					result.append(nbr)
			else:
				result.append(nbr)
	return result


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [current]
	while current in came_from:
		current = came_from[current]
		result.insert(0, current)
	return result


# ── Physics process ───────────────────────────────────────────────────────────

func _physics_process(delta):
	if not is_moving:
		# Outside combat — follow player
		if not _is_in_combat():
			_follow_player()
		return

	position = position.move_toward(target_position, move_speed * delta)
	if position.distance_to(target_position) < 1.0:
		position = target_position
		grid_position = _path[_path_index] if _path_index < _path.size() else grid_position
		_path_index += 1

		if _path_index < _path.size():
			target_position = grid_to_world(_path[_path_index])
		else:
			is_moving = false
			_path.clear()
			_path_index = 0

	queue_redraw()


func _is_in_combat() -> bool:
	var world = _get_world()
	if world and "in_combat" in world:
		return world.in_combat
	return false


# ── Visual feedback ───────────────────────────────────────────────────────────

func _draw():
	var world = _get_world()
	if world and "in_combat" in world and world.in_combat:
		_draw_hp_bar()


func _draw_hp_bar():
	if not stats:
		return
	var bar_w   = tile_size * 1.2
	var bar_h   = 6.0
	var bar_off = Vector2(-bar_w / 2.0, -tile_size * 0.8)
	draw_rect(Rect2(bar_off, Vector2(bar_w, bar_h)), Color.BLACK)
	var pct = stats.get_hp_percent()
	var col = Color.GREEN.lerp(Color.RED, 1.0 - pct)
	if pct > 0:
		draw_rect(Rect2(bar_off, Vector2(bar_w * pct, bar_h)), col)
	draw_rect(Rect2(bar_off, Vector2(bar_w, bar_h)), Color.WHITE, false, 1.0)


func _flash_damage():
	if not is_instance_valid(_sprite):
		return
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color(2.0, 2.0, 0.5), 0.1)
	tween.tween_property(_sprite, "modulate", _COMPANION_COLOR, 0.2)


# ── Combat damage entry point ─────────────────────────────────────────────────

func take_damage(amount: int):
	"""Direct damage (e.g. traps). Combat attacks should go through CombatManager."""
	if not stats:
		return
	var alive = stats.take_damage(amount)
	print("Companions: %s took %d damage — HP %d/%d" % [
		companion_id, amount, stats.current_hp, stats.max_hp
	])
	_flash_damage()
	queue_redraw()
	if not alive:
		if CombatManager and CombatManager.has_method("handle_death"):
			CombatManager.handle_death(self)


func get_hp() -> int:
	return stats.current_hp if stats else 0

func get_max_hp() -> int:
	return stats.max_hp if stats else 0
