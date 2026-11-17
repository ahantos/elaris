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

# An enemy's weapon sets are its own, not equipment. Set one is `weapon`; left
# null it is a stand-in, the same for every enemy until the bestiary gives each
# type its attacks. A second set is optional (`second_weapon`); with one, the
# enemy can swap like anyone else. The AI below only ever attacks an adjacent
# target, whatever it holds.
var weapon: ItemData = null
var second_weapon: ItemData = null
var weapon_set: int = 1
var _stand_in_weapon: ItemData = null

# Wear data, from the type's "wear" entry in World.ENEMY_TYPE_DEFS (the world
# sets it before the enemy enters the scene):
#   weapon          {material, damage_type} for a weapon of that material, or
#                   {hardness, damage_type} for claws and teeth
#   shield, armor   {name, material, notches, bonus, armor_type}: a piece that
#                   a critical hit can notch. bonus is the part of the type's
#                   armour class the piece accounts for: the enemy loses it as
#                   the piece wears, by the rules a character's armour follows.
#   hide_hardness   how hard the body itself is
var wear_data: Dictionary = {}
# The pieces built from it, as item instances: "shield" and "armor"
var gear: Dictionary = {}
# Condition of the gear to restore, from a save (set before _ready)
var saved_gear: Dictionary = {}

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
	_build_gear()

	print("Enemy stats initialized: ", enemy_type, " lv", enemy_level, " HP ", stats.current_hp, "/", stats.max_hp)

func _build_gear():
	"""The shield and armour the type's wear data gives this enemy, whole or in
	the condition a save kept"""
	gear.clear()
	for slot in ["shield", "armor"]:
		var entry = wear_data.get(slot)
		if not (entry is Dictionary) or ItemDatabase.get_material(str(entry.get("material", ""))) == null:
			continue
		var piece := ItemData.new()
		piece.item_name = str(entry.get("name", slot.capitalize()))
		piece.material = ItemDatabase.get_material(str(entry.get("material", "")))
		piece.is_armor = true
		if slot == "shield":
			piece.item_type = ItemData.ItemType.SHIELD
			piece.equip_slot = "off_hand"
			piece.armor_type = "shield"
			piece.armor_class_bonus = int(entry.get("bonus", 0))
		else:
			piece.item_type = ItemData.ItemType.ARMOR_CHEST
			piece.equip_slot = "chest"
			piece.armor_type = str(entry.get("armor_type", "light"))
			piece.armor_base = CharacterStats.UNARMORED_AC + int(entry.get("bonus", 0))
		var instance: Dictionary = {"item_data": piece, "quality_modifier": 0, "magic_modifier": 0}
		DurabilityManager.init_instance(instance, int(entry.get("notches", 0)))
		if saved_gear.get(slot) is Dictionary:
			DurabilityManager.read_primitive(instance, saved_gear[slot])
		gear[slot] = instance

func get_gear_state() -> Dictionary:
	"""The condition of this enemy's gear, for a save (primitives only)"""
	var state: Dictionary = {}
	for slot in gear:
		var primitive: Dictionary = {}
		DurabilityManager.write_primitive(gear[slot], primitive)
		state[slot] = primitive
	return state

func get_wear_pieces() -> Array:
	"""An enemy's wearing pieces are its own: the shield and armour of its type"""
	var pieces: Array = []
	for slot in ["shield", "armor"]:
		if gear.has(slot):
			pieces.append(gear[slot])
	return pieces

func get_hide_hardness() -> int:
	return int(wear_data.get("hide_hardness", DurabilityDials.flesh_hardness))

func get_natural_weapon_hardness() -> int:
	"""How hard this enemy's weapon is: its material's hardness, or that of its
	claws and teeth"""
	var entry: Dictionary = wear_data.get("weapon", {}) if wear_data.get("weapon") is Dictionary else {}
	var material: MaterialData = ItemDatabase.get_material(str(entry.get("material", "")))
	if material != null:
		return material.hardness
	return int(entry.get("hardness", DurabilityDials.flesh_hardness))

func get_gear_armor_class_loss() -> int:
	"""Armour class lost with the shield and armour of the type as they wear:
	the type's armour class counts them whole"""
	var loss: int = 0
	for piece in get_wear_pieces():
		loss += DurabilityManager.get_gear_armor_class_loss(piece)
	return loss

func get_turn_speed() -> int:
	"""An enemy in dented gear is slower, like anyone"""
	return max(0, super.get_turn_speed() - DurabilityManager.get_speed_penalty_tiles(get_wear_pieces()))

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

func get_weapon_set() -> int:
	return weapon_set

func get_weapon_set_count() -> int:
	return 2 if second_weapon != null else 1

func get_weapon(set_index: int = 0) -> ItemData:
	"""Set one: the enemy's weapon, or the stand-in until the bestiary gives
	each type its own attacks, a plain 1d6 weapon. Set two: its second weapon,
	if it has one."""
	if (set_index if set_index > 0 else weapon_set) == 2:
		return second_weapon
	if weapon != null:
		return weapon
	if _stand_in_weapon == null:
		_stand_in_weapon = ItemData.new()
		_stand_in_weapon.item_name = "Enemy Weapon"
		_stand_in_weapon.is_weapon = true
		_stand_in_weapon.weapon_category = "simple"
		_stand_in_weapon.damage_dice = "1d6"
		# What the type's weapon is made of and how it wounds (wear data)
		var entry: Dictionary = wear_data.get("weapon", {}) if wear_data.get("weapon") is Dictionary else {}
		_stand_in_weapon.material = ItemDatabase.get_material(str(entry.get("material", "")))
		_stand_in_weapon.damage_type = str(entry.get("damage_type", ""))
	return _stand_in_weapon

func get_hand_instance(_hand: String, _set_index: int = 0) -> Dictionary:
	"""An enemy's weapons are not items: no instance stands behind them"""
	return {}

func is_weapon_set_empty(set_index: int) -> bool:
	return get_weapon(set_index) == null

func swap_weapon_set() -> int:
	weapon_set = get_other_weapon_set()
	return weapon_set

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
