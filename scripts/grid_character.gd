# grid_character.gd
# The player: a Combatant driven by input. Click-to-move with a path preview,
# WASD in exploration, the action keys, attack and spell targeting and the
# player's turn. What the input asks for in a fight - an attack, a move, a
# cast, a dash - goes to the CombatController as a request; nothing here rolls
# a die or spends a turn resource. While an attack is aimed it draws what the
# controller says: who can be attacked, how far the weapons reach, and (through
# ui/attack_preview.gd) what attacking the enemy under the pointer would be.
extends Combatant
class_name GridCharacter

@export var path_preview_color: Color = Color(0, 1, 0, 0.5)
@export var waypoint_color: Color = Color(1, 1, 0, 0.8)

# Aiming an attack: the reach of the melee weapon, the range of the ranged one,
# an enemy that can be attacked, one that cannot
const AIM_REACH_COLOR := Color(1.0, 0.6, 0.1)
const AIM_RANGE_COLOR := Color(0.45, 0.75, 1.0)
const AIM_TARGET_COLOR := Color(1.0, 0.85, 0.2)
const AIM_BLOCKED_COLOR := Color(1.0, 0.3, 0.25)

# Turn-based system
@export_group("Turn-Based Settings")
@export var turn_based_mode: bool = false
@export var out_of_moves_color: Color = Color(1, 0, 0, 0.5)

# WASD movement (exploration only)
var wasd_movement_enabled: bool = true
var wasd_exploration_speed: float = 300.0  # Pixels per second for WASD movement (about 9 tiles)

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

var turn_number: int = 0

# True while the player is picking a target for the Attack action
var attack_mode: bool = false

# What the CombatController says while an attack is aimed, kept for drawing:
# the hostiles that can be attacked, the hostile under the pointer, and what
# attacking that one would be (CombatController.preview_attack)
var _aim_targets: Array[Combatant] = []
var _aim_hover: Combatant = null
var _aim_preview: Dictionary = {}

# Class id the sprite was last chosen for (see _refresh_sprite)
var _sprite_class_id: String = ""

func _init():
	team = Team.PARTY
	damage_flash_color = Color(1.5, 0.5, 0.5)

func is_player_controlled() -> bool:
	return true

func is_taking_turns() -> bool:
	"""In a fight, and in the turn mode the player can switch on outside one"""
	return turn_based_mode

func is_aiming_attack() -> bool:
	return attack_mode

func get_aim_preview() -> Dictionary:
	return _aim_preview if attack_mode else {}

func get_aim_targets() -> Array[Combatant]:
	"""While an attack is aimed: the hostiles marked as targets"""
	var targets: Array[Combatant] = []
	if attack_mode:
		targets.assign(_aim_targets.filter(func(target): return is_instance_valid(target)))
	return targets

func _ready():
	super._ready()

	# Initialize character stats (NEW)
	initialize_stats()

	# Register with GameManager (NEW)
	GameManager.set_player(self)

	EventBus.game_loaded.connect(_on_game_loaded)

	# Sprite for the character's class, drawn at one tile
	_refresh_sprite()
	
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
	
	# Speed is stored in FEET everywhere (30 ft = 6 tiles per turn);
	# get_modified_movement_speed() converts to tiles
	stats.movement_speed = 30
	stats.character_name = "Adventurer"
	
	print("Player stats initialized: HP ", stats.current_hp, "/", stats.max_hp)

func _refresh_sprite():
	"""Show the sprite ArtLibrary has for the character's class, one tile big.
	_process calls this again whenever the class changes (the class is set after
	_ready: new-game defaults, character creation, loading a save)."""
	_sprite_class_id = stats.class_id if stats else ""
	ArtLibrary.fit_sprite(get_node_or_null("Sprite2D"), ArtLibrary.player_sprite(_sprite_class_id), tile_size)

func _process(delta):
	# The sprite follows the character's class
	if stats and stats.class_id != _sprite_class_id:
		_refresh_sprite()

	# Aiming an attack: the markers follow the pointer and the fight
	if attack_mode:
		_update_aim(_pointer_tile())
	elif _aim_hover != null or not _aim_targets.is_empty():
		_update_aim(Vector2i(-1, -1))

	# WASD movement (only in exploration mode)
	if wasd_movement_enabled and not turn_based_mode and not is_dying:
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
	if is_dying:
		return  # the dead take no input
	if event is InputEventMouseButton:
		# A click on the bottom bar is for the bar, not for the map behind it
		if _is_over_hud(event.position):
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var click_pos = get_global_mouse_position()
			var click_grid = world_to_grid(click_pos)
			var ctrl_held = Input.is_key_pressed(KEY_CTRL)

			# A readied spell (set via the spellbook) intercepts the click
			if SpellManager.get_pending_cast(self) != "":
				_handle_pending_spell_click(click_grid)
				return

			# Aiming the Attack action: the click names the target
			if attack_mode:
				_handle_attack_click(click_grid)
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

		elif event.keycode >= KEY_1 and event.keycode < KEY_1 + CombatController.ACTION_BAR.size() and event.pressed and not event.echo:
			# The number keys are the action bar's buttons, in order
			choose_action(CombatController.ACTION_BAR[event.keycode - KEY_1])

		elif event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			# Cancelling something uses the key up: mark it handled so ESC does
			# not also open the pause menu on the same press
			if SpellManager.get_pending_cast(self) != "":
				SpellManager.clear_pending_cast(self)
				print("Spell cast cancelled.")
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif attack_mode:
				attack_mode = false
				print("Attack cancelled.")
				queue_redraw()
				get_viewport().set_input_as_handled()

func _is_over_hud(screen_pos: Vector2) -> bool:
	"""True when a point of the screen is on the bottom bar"""
	var world = _get_world()
	var hud = world.get("bottom_ui") if world != null else null
	return hud != null and is_instance_valid(hud) and hud.get_global_rect().has_point(screen_pos)

# ============================================================================
# AIMING AN ATTACK
# ============================================================================

func _handle_attack_click(click_grid: Vector2i):
	"""The click names the target of the attack being aimed; the
	CombatController decides whether it can be attacked. A click on an enemy
	that cannot be says why and leaves the attack selected while someone else
	can still be attacked; a click on no enemy at all puts the attack away."""
	var target = _hostile_at(click_grid)
	if target == null:
		attack_mode = false
		EventBus.ui_notification.emit("No enemy there.", "warning")
	else:
		var result: Dictionary = request_action(CombatController.ACTION_ATTACK, {"target": target})
		if result.ok:
			attack_mode = false
		else:
			EventBus.ui_notification.emit(str(result.reason), "warning")
			var combat = _get_combat()
			attack_mode = combat != null and combat.check_action(self, CombatController.ACTION_ATTACK).ok
	queue_redraw()

func _pointer_tile() -> Vector2i:
	"""The tile under the mouse pointer; no tile at all while the pointer is on
	the bottom bar"""
	if _is_over_hud(get_viewport().get_mouse_position()):
		return Vector2i(-1, -1)
	return world_to_grid(get_global_mouse_position())

func _update_aim(pointer_tile: Vector2i):
	"""Ask the CombatController what there is to show while an attack is aimed:
	who can be attacked, and what attacking the hostile under the pointer would
	be. Nothing is decided here."""
	var combat = _get_combat()
	_aim_targets.clear()
	_aim_hover = null
	_aim_preview = {}
	if attack_mode and combat != null:
		_aim_targets = combat.get_attack_targets(self)
		_aim_hover = _hostile_at(pointer_tile)
		if _aim_hover != null:
			_aim_preview = combat.preview_attack(self, _aim_hover)
	queue_redraw()

func _draw_aim():
	"""What an aimed attack looks like on the map: the tiles the melee weapon
	reaches, how far the ranged weapon shoots plainly and at most, a marker on
	every enemy that can be attacked, and the enemy under the pointer picked
	out - in red when it cannot be attacked."""
	var half := Vector2(tile_size / 2.0, tile_size / 2.0)
	var tile := Vector2(tile_size, tile_size)

	var crosshair_size: float = tile_size * 1.5
	draw_line(Vector2(-crosshair_size, 0), Vector2(crosshair_size, 0), AIM_REACH_COLOR, 3.0)
	draw_line(Vector2(0, -crosshair_size), Vector2(0, crosshair_size), AIM_REACH_COLOR, 3.0)

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0:
				draw_rect(Rect2(Vector2(dx, dy) * tile_size - half, tile), Color(AIM_REACH_COLOR, 0.3), false, 2.0)

	var ranged: Dictionary = CombatManager.get_ranged_profile(self)
	if not ranged.is_empty() and ranged.usable:
		_draw_range_outline(int(ranged.range_normal), Color(AIM_RANGE_COLOR, 0.6), 2.0)
		if int(ranged.range_max) > int(ranged.range_normal):
			_draw_range_outline(int(ranged.range_max), Color(AIM_RANGE_COLOR, 0.3), 1.0)

	for target in _aim_targets:
		if is_instance_valid(target) and target != _aim_hover:
			_draw_target_corners(grid_to_world(target.get_grid_position()) - position, AIM_TARGET_COLOR, 2.0)

	if is_instance_valid(_aim_hover):
		var centre: Vector2 = grid_to_world(_aim_hover.get_grid_position()) - position
		if _aim_preview.get("ok", false):
			draw_dashed_line(Vector2.ZERO, centre, Color(AIM_TARGET_COLOR, 0.7), 1.5, 6.0)
			draw_rect(Rect2(centre - half, tile), AIM_TARGET_COLOR, false, 2.0)
			_draw_target_corners(centre, AIM_TARGET_COLOR, 4.0)
		else:
			draw_rect(Rect2(centre - half, tile), AIM_BLOCKED_COLOR, false, 2.0)
			draw_line(centre - half, centre + half, AIM_BLOCKED_COLOR, 2.0)

func _draw_range_outline(tiles: int, color: Color, width: float):
	"""The square of tiles within a distance: distance counts diagonals as one"""
	var extent: float = (tiles + 0.5) * tile_size
	draw_rect(Rect2(Vector2(-extent, -extent), Vector2(extent, extent) * 2.0), color, false, width)

func _draw_target_corners(centre: Vector2, color: Color, width: float):
	"""Brackets on the four corners of a tile"""
	var reach: float = tile_size / 2.0
	var arm: float = tile_size * 0.3
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point: Vector2 = centre + corner * reach
		draw_line(point, point - Vector2(corner.x * arm, 0), color, width)
		draw_line(point, point - Vector2(0, corner.y * arm), color, width)

func choose_action(action_id: String):
	"""The player picked an action, on the action bar or with its number key.
	Attack starts aiming (the next click names the target), Cast opens the
	spellbook and Use Item the character sheet; Dash, Disengage, Dodge and End
	Turn are asked of the CombatController at once. A refusal is shown with
	its reason."""
	if is_dying:
		return
	var combat = _get_combat()
	if combat == null:
		return

	match action_id:
		CombatController.ACTION_ATTACK:
			if attack_mode:
				attack_mode = false
				print("Attack cancelled.")
			else:
				var check: Dictionary = combat.check_action(self, action_id)
				if check.ok:
					attack_mode = true
				else:
					EventBus.ui_notification.emit("Attack: %s" % str(check.reason), "warning")
			queue_redraw()

		CombatController.ACTION_CAST:
			var check: Dictionary = combat.check_action(self, action_id)
			if check.ok:
				UIManager.toggle_panel("spellbook")
			else:
				EventBus.ui_notification.emit("Cast: %s" % str(check.reason), "warning")

		CombatController.ACTION_USE_ITEM:
			var check: Dictionary = combat.check_action(self, action_id)
			var world = _get_world()
			if not check.ok:
				EventBus.ui_notification.emit("Use Item: %s" % str(check.reason), "warning")
			elif world != null and world.get("character_screen") != null:
				world.character_screen.show_character(stats)

		CombatController.ACTION_END_TURN:
			var check: Dictionary = combat.check_action(self, action_id)
			if check.ok:
				end_turn()
			else:
				EventBus.ui_notification.emit("End Turn: %s" % str(check.reason), "warning")

		CombatController.ACTION_DASH, CombatController.ACTION_DISENGAGE, CombatController.ACTION_DODGE:
			var result: Dictionary = combat.request_action(self, action_id)
			var label: String = action_id.capitalize()
			if not result.ok:
				EventBus.ui_notification.emit("%s: %s" % [label, str(result.reason)], "warning")
			elif action_id == CombatController.ACTION_DASH:
				EventBus.ui_notification.emit("Dash: %d tiles of movement this turn." % movement_left, "info")
			elif action_id == CombatController.ACTION_DISENGAGE:
				EventBus.ui_notification.emit("Disengage: your movement provokes no attacks this turn.", "info")
			else:
				EventBus.ui_notification.emit("Dodge: attacks against you have disadvantage until your next turn.", "info")
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
		var segment = find_path(current_pos, waypoint)
		
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
	
	preview_path = find_path(grid_position, destination)
	full_preview_path = preview_path.duplicate()
	
	if preview_path.size() > 1:
		preview_destination = destination
		is_path_selected = true
		queue_redraw()
		
		if turn_based_mode:
			var path_length = preview_path.size() - 1
			if path_length > movement_left:
				print("Path requires ", path_length, " moves, but only ", movement_left, " remaining this turn")
	else:
		preview_path.clear()
		full_preview_path.clear()
		preview_destination = Vector2i(-1, -1)
		is_path_selected = false
		queue_redraw()

func execute_move():
	"""Ask to walk the previewed path. The CombatController checks the turn and
	the movement left; when it agrees it calls follow_path()."""
	var path_to_execute: Array[Vector2i]
	if waypoints.size() > 0:
		path_to_execute = full_preview_path.duplicate()
	else:
		path_to_execute = preview_path.duplicate()

	var result: Dictionary = request_action(CombatController.ACTION_MOVE, {"path": path_to_execute})
	if not result.ok:
		print("Cannot move: ", result.reason)
		if turn_based_mode:
			EventBus.ui_notification.emit(str(result.reason), "warning")
		return

	preview_path.clear()
	full_preview_path.clear()
	preview_destination = Vector2i(-1, -1)
	waypoints.clear()
	is_path_selected = false
	queue_redraw()

func follow_path(tiles: Array):
	"""Start walking an approved path (see Combatant.follow_path)"""
	path.assign(tiles)
	path_index = 1

	# Leaving an enemy's melee reach provokes opportunity attacks (combat only)
	_check_opportunity_attacks(grid_position, path[path_index])
	if not is_alive():
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
	
	# Aiming an attack: reach, range and who can be attacked
	if attack_mode:
		_draw_aim()

	# Draw preview path
	if not is_moving and (is_path_selected or waypoints.size() > 0) and full_preview_path.size() > 1:
		for i in range(full_preview_path.size() - 1):
			var start_world = grid_to_world(full_preview_path[i]) - position
			var end_world = grid_to_world(full_preview_path[i + 1]) - position
			
			var segment_color = path_preview_color
			if turn_based_mode:
				if i >= movement_left:
					segment_color = out_of_moves_color
			
			draw_line(start_world, end_world, segment_color, 3.0)
		
		for i in range(1, full_preview_path.size()):
			var point_world = grid_to_world(full_preview_path[i]) - position
			
			var circle_color = path_preview_color
			if turn_based_mode:
				if i > movement_left:
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

			# Movement is spent tile by tile, so stopping mid-path still
			# counts the tiles already walked
			var counted: bool = is_taking_turns()
			if counted:
				spend_movement()

			# Step-on pickup of ground loot
			_check_ground_pickup()

			if path_index < path.size() and (not counted or movement_left > 0):
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
					print("Moves remaining: ", movement_left)

					if movement_left <= 0:
						print("Out of moves! Press SPACE to end turn.")

				path.clear()
				path_index = 0
				queue_redraw()

func teleport_to_grid(grid_pos: Vector2i) -> bool:
	"""Instantly teleport to a grid position"""
	if not super.teleport_to_grid(grid_pos):
		return false
	path.clear()
	cancel_preview()
	return true

func on_tile_entered():
	_check_ground_pickup()

func stop_moving():
	"""Stop current movement"""
	is_moving = false
	path.clear()
	path_index = 0
	position = grid_to_world(grid_position)
	target_position = position

func _hostile_at(grid_pos: Vector2i) -> Combatant:
	"""The living hostile combatant on a tile, or null"""
	var world = _get_world()
	if not world:
		return null
	var target = world.get_combatant_at(grid_pos)
	if target != null and target.is_alive() and is_hostile_to(target):
		return target
	return null

# ============================================================================
# SPELLCASTING (pending casts readied via the spellbook panel)
# ============================================================================

func _handle_pending_spell_click(click_grid: Vector2i):
	"""Aim a readied spell at the clicked tile and ask the CombatController to
	cast it. The click only decides what the spell is aimed at; the turn, the
	action or bonus action it costs, range and line of sight are the
	controller's to check. A refusal that another target could cure keeps the
	spell readied so the player can aim again; ESC cancels it."""
	var pending = SpellManager.get_pending_cast(self)
	var spell = SpellDatabase.get_spell(pending)
	if spell.is_empty():
		SpellManager.clear_pending_cast(self)
		return

	# What the click means depends on the spell's targeting mode
	var cast_target = null
	match str(spell.get("target_type", "enemy")):
		"enemy":
			cast_target = _hostile_at(click_grid)
			if cast_target == null:
				EventBus.ui_notification.emit("No enemy there - click a target for %s." % str(spell.get("display_name", pending)), "warning")
				return
		"ally", "self":
			# Simplification: ally-targeted casts resolve on the caster
			cast_target = self
		_:
			# "point" / area spells target the clicked tile itself
			cast_target = click_grid

	var result: Dictionary = request_action(CombatController.ACTION_CAST, {"spell_id": pending, "target": cast_target})
	if not result.ok:
		EventBus.ui_notification.emit(str(result.get("reason", "The spell fizzles.")), "warning")
		if result.get("final", false):
			SpellManager.clear_pending_cast(self)
			queue_redraw()
		return

	SpellManager.clear_pending_cast(self)
	queue_redraw()

# ============================================================================
# MOVEMENT HOOKS (loot pickup)
# ============================================================================

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
	# Turn-based mode belongs to the combat controller while in combat -
	# toggling it off mid-combat would desync the turn loop
	if in_combat():
		print("Cannot toggle turn-based mode during combat!")
		return

	turn_based_mode = !turn_based_mode

	if turn_based_mode:
		# Snap to the grid so turn-based movement starts from a tile center
		stop_moving()
		cancel_preview()
		start_new_turn()
		print("Turn-based mode ENABLED - Press T to toggle, SPACE to end turn")
		print("Turn ", turn_number, " - Moves remaining: ", movement_left)
	else:
		print("Turn-based mode DISABLED - Free movement with WASD or click")

func on_combat_started():
	"""A fight has begun: stop where we stand and wait for a turn"""
	stop_moving()
	cancel_preview()
	attack_mode = false
	turn_based_mode = true
	# No movement until initiative grants the player a turn
	super.on_combat_started()

func on_combat_ended():
	"""Back to free movement"""
	turn_based_mode = false
	wasd_movement_enabled = true
	attack_mode = false
	super.on_combat_ended()

func start_new_turn():
	"""Start a new turn. In a fight the CombatController calls this when the
	player's turn comes up, having handed out the turn's resources; in the turn
	mode outside a fight the player cycles its own turns and takes them here."""
	turn_number += 1
	attack_mode = false
	if not in_combat():
		refresh_turn_resources()

	# Status-effect ticks at the start of the turn (burning, regenerating, ...)
	StatusEffectManager.process_turn_start(self)

	# A tick may have killed us - the death path owns the rest
	if is_dying or not stats or not stats.is_alive():
		return

	print("=== Turn ", turn_number, " started ===")
	print("Movement available: ", movement_left, " tiles")

	# In combat the CombatController announces every turn itself
	if not in_combat():
		EventBus.turn_started.emit(self)

	# Incapacitated (stunned/paralyzed/frozen): lose the turn. Deferred so the
	# turn loop is never advanced re-entrantly from inside this call.
	if StatusEffectManager.is_incapacitated(self):
		movement_left = 0
		EventBus.ui_notification.emit("You are incapacitated and lose your turn!", "warning")
		print("Player is incapacitated - turn skipped")
		call_deferred("_auto_end_incapacitated_turn")

func _auto_end_incapacitated_turn():
	"""Deferred auto end-of-turn while incapacitated (combat only - outside
	combat the player can still press SPACE themselves)"""
	if is_dying or not turn_based_mode or is_moving:
		return
	if not in_combat():
		return
	end_turn()

func end_turn():
	"""End the player's turn. In combat only the turn-holder has a turn to end:
	on anyone else's turn this does nothing at all."""
	if not turn_based_mode:
		return

	var combat = _get_combat()
	if combat == null:
		return
	var check: Dictionary = combat.check_action(self, CombatController.ACTION_END_TURN)
	if not check.ok:
		print("Cannot end the turn: ", check.reason)
		return
	var in_world_combat: bool = combat.active

	print("Turn ", turn_number, " ended. Moves used: ", max(0, movement_granted - movement_left))
	attack_mode = false
	queue_redraw()

	# End-of-turn status bookkeeping (ticks, end saves, duration countdown)
	StatusEffectManager.process_turn_end(self)

	if in_world_combat:
		# The controller announces the end of the turn and starts the next one
		combat.request_action(self, CombatController.ACTION_END_TURN)
	else:
		# Outside combat (manual T mode) we cycle our own turns
		expire_turn_resources()
		EventBus.turn_ended.emit(self)
		start_new_turn()

func get_turn_number() -> int:
	"""Get current turn number"""
	return turn_number

# ============================================================================
# COMBAT SYSTEM (REFACTORED TO USE CHARACTERSTATS)
# ============================================================================

func take_damage(amount: int):
	"""Direct damage (traps, hazards) also shows a number and updates the HUD.
	NOTE: attacks should go through CombatManager.apply_damage instead."""
	if not stats:
		return

	var world = get_parent()
	if world:
		var popup_pos = global_position + Vector2(0, -tile_size * 0.8)
		DamagePopup.spawn_damage_popup_at(world, popup_pos, amount, false)

	super.take_damage(amount)
	EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)

func _on_damage_dealt_event(attacker, target, amount, is_critical, damage_type):
	"""Keep the HP signal in sync when CombatManager applies damage to stats"""
	super._on_damage_dealt_event(attacker, target, amount, is_critical, damage_type)
	if target == self and stats:
		EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)

func _on_game_loaded(_slot: int):
	"""Re-emit HP after SaveManager restores stats directly"""
	if stats:
		EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)
	queue_redraw()

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

	# The body stays in the scene: freeing the player used to leave the game
	# with no way forward (and blocked loading). Stop everything, fade, and hand
	# over to the game-over flow.
	is_moving = false
	path.clear()
	path_index = 0
	attack_mode = false
	cancel_preview()
	SpellManager.clear_pending_cast(self)
	modulate = Color(1, 1, 1, 0.35)
	queue_redraw()
	GameManager.game_over()

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
