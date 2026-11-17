# enemy.gd
# A hostile combatant run by a simple AI: close on the player and attack.
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

# Effective move budget for the current turn (moves_per_turn +/- status effects)
var moves_budget_this_turn: int = 6

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
	moves_budget_this_turn = moves_per_turn

	print("Enemy stats initialized: ", enemy_type, " lv", enemy_level, " HP ", stats.current_hp, "/", stats.max_hp)

func take_turn():
	"""Enemy takes its turn (status-effect hooks run at start and on every exit path)"""
	if is_moving:
		return

	# Dead/dying enemies don't act
	if is_dying or not stats or not stats.is_alive():
		return

	# Status-effect ticks at the start of the turn (burning, regenerating, ...)
	StatusEffectManager.process_turn_start(self)

	# The tick may have killed this enemy - die() already notified the world,
	# and the world's loop advances the chain on its own
	if is_dying or not stats or not stats.is_alive():
		return

	# Incapacitated (stunned/paralyzed/frozen): skip acting, but durations
	# still tick down so the effect can expire
	if StatusEffectManager.is_incapacitated(self):
		print("%s is incapacitated and skips its turn!" % name)
		_finish_turn_effects()
		return

	# Player gone or dead - nothing to do
	if not is_instance_valid(player) or not player.stats or not player.stats.is_alive():
		_finish_turn_effects()
		return

	# Combat move budget for this turn (slowed/hasted/restrained adjust it)
	moves_budget_this_turn = max(0, moves_per_turn + StatusEffectManager.get_speed_modifier_tiles(self))

	var player_pos = player.get_grid_position()

	# Check if already adjacent to player
	var dx = abs(grid_position.x - player_pos.x)
	var dy = abs(grid_position.y - player_pos.y)

	if dx <= 1 and dy <= 1 and (dx + dy) > 0:
		# Already adjacent - attack (await so turn-end effects land after the swing)
		await attack_player()
		if is_dying or not stats or not stats.is_alive():
			return
		_finish_turn_effects()
		return

	# Rooted in place (restrained etc.) - nothing else to do this turn
	if moves_budget_this_turn <= 0:
		print("%s cannot move this turn!" % name)
		_finish_turn_effects()
		return

	# Calculate path toward player
	path = _calculate_path_to_player(player_pos)

	if path.size() <= 1:
		path.clear()
		_finish_turn_effects()
		return

	# Start moving (movement is capped to moves_budget_this_turn in _physics_process)
	path_index = 1

	# Leaving a hostile's melee reach provokes an opportunity attack
	_check_opportunity_attacks(grid_position, path[path_index])
	if is_dying or not stats or not stats.is_alive():
		path.clear()
		path_index = 0
		return

	target_position = grid_to_world(path[path_index])
	is_moving = true

func _finish_turn_effects():
	"""End-of-turn status bookkeeping (ticks, end saves, duration countdown)"""
	if is_dying or not stats or not stats.is_alive():
		return
	StatusEffectManager.process_turn_end(self)

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
	if not is_instance_valid(player) or not player.stats:
		return

	# Get weapon (TODO: enemies will have weapons in Phase 2)
	var weapon = create_temp_weapon()

	# Attack animation
	animate_attack(player.global_position)

	# Wait for animation (pauses with the tree so damage can't resolve
	# while a pause menu is open)
	await get_tree().create_timer(0.15, false).timeout

	# Player may have been freed during the animation delay
	if not is_instance_valid(player) or not player.stats:
		return

	# Roll attack using CombatManager (nodes unlock status effects, cover and AC mods)
	var result = CombatManager.roll_attack(stats, player.stats, weapon, false, false, self, player, [])
	if result.is_empty():
		return

	if result.get("auto_fail", false):
		print("%s is incapacitated and cannot attack!" % name)
		return

	var popup_pos = player.global_position + Vector2(0, -tile_size * 0.8)

	if result.is_fumble:
		print("%s fumbled the attack!" % name)
		DamagePopup.spawn_miss_popup_at(get_parent(), popup_pos)
	elif result.hit:
		if result.is_crit:
			print("%s lands a CRITICAL HIT on Player for %d damage!" % [name, result.damage])
			DamagePopup.spawn_damage_popup_at(get_parent(), popup_pos, result.damage, true)
		else:
			print("%s hits Player for %d damage!" % [name, result.damage])
			DamagePopup.spawn_damage_popup_at(get_parent(), popup_pos, result.damage, false)

		# Apply damage using CombatManager
		CombatManager.apply_damage(player, result.damage, CombatManager.DamageType.PHYSICAL, self, result.is_crit)
	else:
		print("%s missed Player! (Rolled %d vs AC %d)" % [name, result.total, result.target_ac])
		DamagePopup.spawn_miss_popup_at(get_parent(), popup_pos)

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
			
			# Check if should continue moving
			if path_index < path.size() and path_index <= moves_budget_this_turn:
				# Leaving a hostile's melee reach provokes an opportunity attack
				_check_opportunity_attacks(grid_position, path[path_index])
				if is_dying or not stats or not stats.is_alive():
					is_moving = false
					path.clear()
					path_index = 0
					return
				target_position = grid_to_world(path[path_index])
			else:
				# Done moving this turn
				is_moving = false
				path.clear()
				path_index = 0

				# After moving, check if adjacent to player and attack
				check_and_attack_player()

				# End-of-turn status bookkeeping (ticks, end saves, durations)
				_finish_turn_effects()
	
	# Always redraw to show HP bar
	queue_redraw()

func check_and_attack_player():
	"""Check if adjacent to player after moving and attack if so"""
	if is_dying or not is_instance_valid(player):
		return

	var player_pos = player.get_grid_position()
	var dx = abs(grid_position.x - player_pos.x)
	var dy = abs(grid_position.y - player_pos.y)
	
	# Adjacent means within 1 tile (including diagonals)
	if dx <= 1 and dy <= 1 and (dx + dy) > 0:
		attack_player()

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
