# companion.gd
# A recruited companion in the dungeon: a party Combatant that follows the player
# while exploring and fights by a simple AI. What the AI decides - a move, an
# attack - it asks of the CombatController, like every other combatant.
# CompanionManager.create_companion_node() builds the node in code; the World
# scene parents it and sets dungeon_generator and player.
extends Combatant
class_name Companion

# ── Identity ───────────────────────────────────────────────────────────────────
var companion_id: String = ""   # Set by create_companion_node() before _ready()

# ── References (set by the world after spawning) ──────────────────────────────
var player = null               # The GridCharacter this companion follows

# ── Pathfinding ───────────────────────────────────────────────────────────────
var _path: Array[Vector2i] = []
var _path_index: int = 0

# ── Sprite reference ──────────────────────────────────────────────────────────
var _sprite: Sprite2D = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _init():
	team = Team.PARTY
	move_speed = 360.0  # Pixels per second (about 11 tiles on the 32px grid)
	damage_flash_color = Color(2.0, 2.0, 0.5)


func _ready():
	"""Build sprite and load stats."""
	super._ready()
	z_index = 190  # Just below enemies (200)

	# Sprite from ArtLibrary: the companion's own, else the one for its class.
	# Named like the player's and the enemies' so the same lookups find it.
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	var sprite_defn: Dictionary = CompanionManager.companion_definitions.get(companion_id, {})
	ArtLibrary.fit_sprite(_sprite, ArtLibrary.companion_sprite(companion_id, str(sprite_defn.get("class_id", ""))), tile_size)
	add_child(_sprite)

	_init_stats()

	target_position = position


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


# ── Exploration follow ────────────────────────────────────────────────────────

func _follow_player():
	"""
	If player is more than 2 tiles away, walk to the closest free tile
	adjacent to the player.
	"""
	if not is_instance_valid(player):
		return

	var player_pos = player.get_grid_position()
	if CombatGrid.get_distance_tiles(grid_position, player_pos) <= 2:
		return  # Close enough — stay put

	var route = find_path(grid_position, _adjacent_tile_toward(player_pos))
	if route.size() < 2:
		return
	request_action(CombatController.ACTION_MOVE, {"path": route})


func follow_path(tiles: Array):
	"""Start walking an approved path (see Combatant.follow_path). A companion's
	move provokes no opportunity attacks yet: nothing may hurt one until
	companions have death rules."""
	_path.assign(tiles)
	_path_index = 1
	target_position = grid_to_world(_path[1])
	is_moving = true


# ── Combat turn ───────────────────────────────────────────────────────────────

func take_turn():
	"""
	Companion turn: if adjacent to a living enemy → attack;
	else move toward the nearest enemy, as far as this turn's movement reaches.
	"""
	if is_moving or not is_alive():
		return

	var enemies: Array[Combatant] = get_hostiles()
	if enemies.is_empty():
		return

	for enemy in enemies:
		if CombatGrid.get_distance_tiles(grid_position, enemy.grid_position) <= 1:
			request_action(CombatController.ACTION_ATTACK, {"target": enemy})
			return

	# No adjacent enemy — head for the nearest
	var nearest = _find_nearest(enemies)
	if nearest == null or movement_left <= 0:
		return

	var route = find_path(grid_position, _adjacent_tile_toward(nearest.grid_position))
	if route.size() > movement_left + 1:
		route = route.slice(0, movement_left + 1)
	if route.size() >= 2:
		request_action(CombatController.ACTION_MOVE, {"path": route})


func _find_nearest(others: Array):
	"""Return the nearest of the given combatants."""
	var nearest = null
	var nearest_dist: int = 999999
	for other in others:
		if not is_instance_valid(other):
			continue
		var d = CombatGrid.get_distance_tiles(grid_position, other.grid_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = other
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
	var best_d = CombatGrid.get_distance_tiles(grid_position, best)
	for c in candidates:
		var d = CombatGrid.get_distance_tiles(grid_position, c)
		if d < best_d:
			best_d = d
			best   = c
	return best


# ── Physics process ───────────────────────────────────────────────────────────

func _physics_process(delta):
	if not is_moving:
		# Outside combat — follow player
		if not in_combat():
			_follow_player()
		return

	position = position.move_toward(target_position, move_speed * delta)
	if position.distance_to(target_position) < 1.0:
		position = target_position
		grid_position = _path[_path_index] if _path_index < _path.size() else grid_position
		_path_index += 1

		# In a fight each tile costs movement, and the walk stops when the
		# movement or the turn runs out (a fight can start mid-stride)
		var counted: bool = is_taking_turns()
		if counted:
			spend_movement()

		if _path_index < _path.size() and (not counted or (movement_left > 0 and can_act())):
			target_position = grid_to_world(_path[_path_index])
		else:
			is_moving = false
			_path.clear()
			_path_index = 0

	queue_redraw()


# ── Visual feedback ───────────────────────────────────────────────────────────

func _draw():
	if in_combat():
		draw_hp_bar()
