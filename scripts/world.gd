# world.gd - COMPLETE FILE WITH FIXED REGENERATION

extends Node2D

var DungeonGeneratorScene = preload("res://scenes/dungeon_generator.tscn")
var CharacterScene = preload("res://scenes/character.tscn")
var EnemyScene = preload("res://scenes/enemy.tscn")

var current_dungeon: DungeonGenerator
var player: GridCharacter
var minimap: Minimap
var turn_ui: TurnUI
var initiative_tracker: InitiativeTracker
var bottom_ui: BottomUI
var grid_overlay: GridOverlay
var enemies: Array[Enemy] = []
var combat_detection_range: int = 10
var enemy_activation_range: int = 20
var in_combat: bool = false

func _ready():
	# Generate dungeon
	current_dungeon = DungeonGeneratorScene.instantiate()
	add_child(current_dungeon)
	
	# Wait for dungeon generation
	await get_tree().create_timer(0.2).timeout
	
	# Spawn player
	player = CharacterScene.instantiate()
	player.dungeon_generator = current_dungeon
	add_child(player)
	
	# Position player at start room
	position_player_at_start()
	
	# Make camera follow player
	current_dungeon.set_camera_target(player)
	
	# Connect player turn signal
	player.turn_ended.connect(_on_player_turn_ended)
	
	# Spawn enemies
	spawn_enemies(3)
	
	# Create UI
	create_minimap()
	create_turn_ui()
	create_initiative_tracker()
	create_bottom_ui()
	
	# Get reference to grid overlay (it's created by dungeon_generator)
	grid_overlay = current_dungeon.get_node_or_null("GridOverlay")
	
	# Hide grid initially (exploration mode)
	if grid_overlay:
		grid_overlay.set_enabled(false)
		print("Grid hidden - exploration mode")

func position_player_at_start():
	"""Position player at the start room center"""
	if not current_dungeon.start_room.is_empty():
		var start_room_data = current_dungeon.start_room
		var room_center = start_room_data.center
		
		player.grid_position = room_center
		player.position = player.grid_to_world(room_center)
		player.target_position = player.position
		
		print("Player positioned at start room: ", room_center)
	else:
		push_error("No start room found! Player may be in invalid position.")

func _process(_delta):
	"""Check for enemy proximity"""
	if not player or not player.turn_based_mode:
		check_enemy_proximity()

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		# Manual grid toggle with G key
		if event.keycode == KEY_G:
			if grid_overlay:
				grid_overlay.set_enabled(!grid_overlay.enabled)
				if grid_overlay.enabled:
					print("Grid overlay: ON")
				else:
					print("Grid overlay: OFF")
		
		# Minimap fog of war toggle
		elif event.keycode == KEY_M:
			if minimap:
				minimap.toggle_fog_of_war()
		
		# Regenerate dungeon with R key
		elif event.keycode == KEY_R:
			regenerate_dungeon()

func regenerate_dungeon():
	"""Regenerate the entire dungeon and reset game state"""
	print("=== REGENERATING DUNGEON ===")
	
	# End combat if active
	if in_combat:
		end_combat()
	
	# Clear all enemies
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	
	# Stop player movement
	if player:
		player.stop_moving()
		player.cancel_preview()
		player.turn_based_mode = false
	
	# Regenerate the dungeon
	if current_dungeon:
		current_dungeon.generate_dungeon()
		
		# Wait for generation to complete
		await get_tree().create_timer(0.1).timeout
		
		# Reposition player at new start room
		if player:
			position_player_at_start()
			
			# Reset player state
			player.turn_based_mode = false
			player.attack_mode = false
			player.selected_attack_type = ""
		
		# Update grid overlay reference (in case it was recreated)
		grid_overlay = current_dungeon.get_node_or_null("GridOverlay")
		if grid_overlay:
			grid_overlay.set_enabled(false)
		
		# Update minimap
		if minimap:
			minimap.setup(current_dungeon, player)
		
		# Spawn new enemies
		spawn_enemies(3)
		
		# Recenter camera on player
		current_dungeon.set_camera_target(player)
		
		print("Dungeon regenerated successfully!")

func check_enemy_proximity():
	"""Auto-enable turn-based mode when near enemies"""
	if not player or enemies.is_empty() or in_combat:
		return
	
	var player_pos = player.get_grid_position()
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var enemy_pos = enemy.get_grid_position()
		var distance = player_pos.distance_to(enemy_pos)
		
		if distance <= combat_detection_range:
			# Enter combat
			player.stop_moving()
			player.turn_based_mode = true
			in_combat = true
			
			# SHOW GRID when entering combat
			if grid_overlay:
				grid_overlay.set_enabled(true)
				print("Grid overlay: ON (combat started)")
			
			start_combat()
			return

func spawn_enemies(count: int):
	"""Spawn enemies in the dungeon"""
	for i in range(count):
		var enemy = EnemyScene.instantiate()
		enemy.dungeon_generator = current_dungeon
		enemy.player = player
		add_child(enemy)
		
		var spawn_pos = find_enemy_spawn_position()
		if spawn_pos != Vector2i(-1, -1):
			enemy.spawn_at(spawn_pos)
			enemies.append(enemy)
			print("Enemy ", i + 1, " spawned at ", spawn_pos)

func find_enemy_spawn_position() -> Vector2i:
	"""Find valid spawn position for enemy"""
	if not player:
		return Vector2i(-1, -1)
		
	var player_pos = player.get_grid_position()
	var min_distance = 15
	
	for attempt in range(100):
		var x = randi() % current_dungeon.dungeon_width
		var y = randi() % current_dungeon.dungeon_height
		var pos = Vector2i(x, y)
		
		if current_dungeon.dungeon_grid[y][x] == current_dungeon.TileType.FLOOR:
			if pos.distance_to(player_pos) >= min_distance:
				return pos
	
	return Vector2i(-1, -1)

func create_initiative_tracker():
	"""Create initiative tracker"""
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "InitiativeTrackerLayer"
	add_child(canvas_layer)
	
	initiative_tracker = InitiativeTracker.new()
	canvas_layer.add_child(initiative_tracker)

func create_bottom_ui():
	"""Create bottom UI panel"""
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "BottomUILayer"
	add_child(canvas_layer)
	
	bottom_ui = BottomUI.new()
	canvas_layer.add_child(bottom_ui)
	bottom_ui.setup(player)

func start_combat():
	"""Initialize combat and roll initiative"""
	print("⚔️ COMBAT INITIATED! ⚔️")
	
	# Clear movement
	if player:
		player.cancel_preview()
	
	# Get nearby enemies
	var active_enemies: Array[Enemy] = []
	var player_pos = player.get_grid_position()
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_pos = enemy.get_grid_position()
		var distance = player_pos.distance_to(enemy_pos)
		if distance <= enemy_activation_range:
			active_enemies.append(enemy)
	
	# Setup initiative
	initiative_tracker.setup_initiative(player, active_enemies)
	
	# Start first turn
	process_next_turn()

func process_next_turn():
	"""Process next turn in initiative"""
	var current = initiative_tracker.get_current_combatant()
	
	if current.is_empty():
		# No valid combatants - end combat
		end_combat()
		return
	
	if current.is_player:
		# Player turn
		player.start_new_turn()
		if turn_ui:
			turn_ui.set_player_turn()
	else:
		# Enemy turn
		var enemy = current.entity as Enemy
		if turn_ui:
			turn_ui.set_enemy_turn(initiative_tracker.current_index + 1, initiative_tracker.combatants.size())
		
		if is_instance_valid(enemy):
			enemy.take_turn()
			# Wait for movement
			while enemy.is_moving:
				await get_tree().create_timer(0.1).timeout
			
			# Delay before next turn
			await get_tree().create_timer(0.3).timeout
		
		# Next turn
		await get_tree().create_timer(1.0).timeout
		initiative_tracker.next_turn()
		process_next_turn()

func _on_player_turn_ended():
	"""Called when player ends turn"""
	# Check if still in combat
	if not in_combat:
		return
	
	# Advance initiative
	initiative_tracker.next_turn()
	process_next_turn()

func create_minimap():
	"""Create minimap"""
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "MinimapLayer"
	add_child(canvas_layer)
	
	minimap = Minimap.new()
	canvas_layer.add_child(minimap)
	minimap.setup(current_dungeon, player)

func create_turn_ui():
	"""Create turn UI"""
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "TurnUILayer"
	add_child(canvas_layer)
	
	turn_ui = TurnUI.new()
	canvas_layer.add_child(turn_ui)
	turn_ui.setup(player)

func get_enemy_at_position(grid_pos: Vector2i) -> Enemy:
	"""Get enemy at grid position"""
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get_grid_position() == grid_pos:
			return enemy
	return null

func is_position_occupied_by_enemy(grid_pos: Vector2i, exclude: Node = null) -> bool:
	"""Check if position occupied by enemy"""
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy == exclude:
			continue
		if enemy.get_grid_position() == grid_pos:
			return true
	return false

func on_enemy_died(enemy: Enemy):
	"""Called when enemy dies"""
	enemies.erase(enemy)
	
	# Remove from initiative tracker
	if initiative_tracker:
		initiative_tracker.remove_combatant(enemy)
	
	# Check if combat should end
	if in_combat:
		check_combat_end()

func check_combat_end():
	"""Check if all enemies dead"""
	if not player or not in_combat:
		return
	
	var player_pos = player.get_grid_position()
	var active_enemies_alive = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_pos = enemy.get_grid_position()
		var distance = player_pos.distance_to(enemy_pos)
		if distance <= enemy_activation_range:
			active_enemies_alive += 1
	
	if active_enemies_alive == 0:
		end_combat()

func end_combat():
	"""End combat"""
	print("⚔️ COMBAT ENDED - VICTORY! ⚔️")
	in_combat = false
	player.turn_based_mode = false
	
	# HIDE GRID when exiting combat
	if grid_overlay:
		grid_overlay.set_enabled(false)
		print("Grid overlay: OFF (combat ended)")
	
	# Hide initiative tracker
	if initiative_tracker:
		initiative_tracker.visible = false
