# enemy.gd
# A hostile combatant run by a simple AI: close on the player and attack. What
# the AI decides - a move, an attack - it asks of the CombatController, like
# every other combatant.
extends Combatant
class_name Enemy

@export var moves_per_turn: int = 6
@export var enemy_color: Color = Color(1, 0, 0, 1)  # Unused: each enemy type has its own sprite now

# Identity (assigned by world on spawn; drives loot tables, quest kill credit and XP)
@export var enemy_type: String = "goblin"
@export var enemy_level: int = 1

@export_group("Combat Stats")
@export var max_hp: int = 10
@export var current_hp: int = 10
@export var attack_damage: int = 2

# The one target this AI goes for
var player: GridCharacter = null

# Pathfinding
var path: Array[Vector2i] = []
var path_index: int = 0

# The weapon every enemy attacks with until the bestiary gives each type its own
var _stand_in_weapon: ItemData = null

func _init():
	team = Team.HOSTILE

func _ready():
	super._ready()

	# Sprite for this enemy type, drawn at one tile. No tint: types differ by art.
	ArtLibrary.fit_sprite(get_node_or_null("Sprite2D"), ArtLibrary.enemy_sprite(enemy_type), tile_size)

	initialize_stats()

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
	stats.movement_speed = moves_per_turn * CharacterStats.FEET_PER_TILE  # stats hold feet
	stats.character_name = enemy_type.capitalize()
	stats.level = enemy_level

	print("Enemy stats initialized: ", enemy_type, " lv", enemy_level, " HP ", stats.current_hp, "/", stats.max_hp)

func take_turn():
	"""Enemy takes its turn: attack the player when next to it, otherwise close
	in and attack on arrival. Status-effect hooks run at the start and on every
	exit path; the end-of-turn ones only after the turn's blow has landed."""
	if is_moving:
		return

	# Dead/dying enemies don't act
	if is_dying or not stats or not stats.is_alive():
		return

	# Status-effect ticks at the start of the turn (burning, regenerating, ...)
	StatusEffectManager.process_turn_start(self)

	# The tick may have killed this enemy - die() already notified the world,
	# and the combat controller passes the turn on by itself
	if is_dying or not stats or not stats.is_alive():
		return

	# Incapacitated (stunned/paralyzed/frozen): skip acting, but durations
	# still tick down so the effect can expire
	if StatusEffectManager.is_incapacitated(self):
		print("%s is incapacitated and skips its turn!" % name)
		_finish_turn_effects()
		return

	# Player gone or dead - nothing to do
	if not is_instance_valid(player) or not player.is_alive():
		_finish_turn_effects()
		return

	if _is_next_to(player):
		_attack(player)
		_finish_turn_effects()
		return

	# Rooted in place (restrained etc.) - nothing else to do this turn
	if movement_left <= 0:
		print("%s cannot move this turn!" % name)
		_finish_turn_effects()
		return

	# As far along the way to the player as this turn's movement reaches
	var route: Array = _calculate_path_to_player(player.get_grid_position())
	if route.size() > movement_left + 1:
		route = route.slice(0, movement_left + 1)

	# The turn goes on in _physics_process, and ends in _on_move_finished
	if not request_action(CombatController.ACTION_MOVE, {"path": route}).ok:
		_finish_turn_effects()

func _finish_turn_effects():
	"""End-of-turn status bookkeeping (ticks, end saves, duration countdown)"""
	if is_dying or not stats or not stats.is_alive():
		return
	StatusEffectManager.process_turn_end(self)

func get_wielded_weapon() -> ItemData:
	"""A stand-in until the bestiary gives each enemy type its own attacks: a
	plain 1d6 weapon"""
	if _stand_in_weapon == null:
		_stand_in_weapon = ItemData.new()
		_stand_in_weapon.item_name = "Enemy Weapon"
		_stand_in_weapon.is_weapon = true
		_stand_in_weapon.weapon_category = "simple"
		_stand_in_weapon.damage_dice = "1d6"
	return _stand_in_weapon

func get_flank_partners() -> Array:
	"""Enemies do not flank yet: their attacks stay as they were until the
	bestiary and its behaviours are built"""
	return []

func _is_next_to(other: Combatant) -> bool:
	return CombatGrid.get_distance_tiles(grid_position, other.get_grid_position()) == 1

func _attack(target: Combatant):
	"""One attack on an adjacent target, asked of the CombatController"""
	request_action(CombatController.ACTION_ATTACK, {"target": target})

func follow_path(tiles: Array):
	"""Start walking an approved path (see Combatant.follow_path)"""
	path.assign(tiles)
	path_index = 1

	# Leaving a hostile's melee reach provokes an opportunity attack
	_check_opportunity_attacks(grid_position, path[path_index])
	if is_dying or not stats or not stats.is_alive():
		path.clear()
		path_index = 0
		return

	target_position = grid_to_world(path[path_index])
	is_moving = true

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
	var best_path = find_path(grid_position, best_target)
	var best_dist = best_path.size()
	
	for tile in adjacent_tiles:
		var test_path = find_path(grid_position, tile)
		if test_path.size() < best_dist:
			best_dist = test_path.size()
			best_target = tile
			best_path = test_path
	
	return best_path

func _physics_process(delta):
	if is_moving and path.size() > 0:
		position = position.move_toward(target_position, move_speed * delta)

		if position.distance_to(target_position) < 1.0:
			position = target_position
			grid_position = path[path_index]
			path_index += 1
			spend_movement()

			if path_index < path.size() and movement_left > 0:
				# Leaving a hostile's melee reach provokes an opportunity attack
				_check_opportunity_attacks(grid_position, path[path_index])
				if is_dying or not stats or not stats.is_alive():
					is_moving = false
					path.clear()
					path_index = 0
					return
				target_position = grid_to_world(path[path_index])
			else:
				is_moving = false
				path.clear()
				path_index = 0
				_on_move_finished()

	# Always redraw to show HP bar
	queue_redraw()

func _on_move_finished():
	"""The rest of a turn that began with a move: attack the player if the move
	ended next to it, and only then the end-of-turn status bookkeeping, so that
	what expires at the end of the turn is still in force for the blow"""
	if is_dying:
		return
	if is_instance_valid(player) and player.is_alive() and _is_next_to(player):
		_attack(player)
	_finish_turn_effects()

func _draw():
	"""Draw HP bar above enemy"""
	if in_combat():
		draw_hp_bar()

func die():
	"""Handle death with effects"""
	if is_dying:
		return
	is_dying = true

	print("%s has died!" % name)

	# Stop any movement in progress
	is_moving = false
	path.clear()
	path_index = 0

	# Notify world immediately (before the fade) so the enemy is removed
	# from the enemies array and initiative right away - otherwise it could
	# still get a turn or block tiles while fading out
	var world = _get_world()
	if world and world.has_method("on_enemy_died"):
		world.on_enemy_died(self)

	# Death animation - fade out and shrink
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.5)
		await tween.finished

	queue_free()
