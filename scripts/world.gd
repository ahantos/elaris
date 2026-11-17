# world.gd - WITH SAVE/LOAD MENU SUPPORT + FULL SYSTEMS INTEGRATION

extends Node2D

var DungeonGeneratorScene = preload("res://scenes/dungeon_generator.tscn")
var CharacterScene = preload("res://scenes/character.tscn")
var EnemyScene = preload("res://scenes/enemy.tscn")
const GroundItemScript = preload("res://scripts/ground_item.gd")
const AttackPreviewScene = preload("res://scenes/ui/attack_preview.tscn")

# Enemy identities assigned at spawn (loot tables exist for all four types)
const ENEMY_TYPE_DEFS: Dictionary = {
	"goblin":   {"color": Color(0.35, 0.75, 0.25), "base_hp": 10},
	"skeleton": {"color": Color(0.92, 0.92, 0.82), "base_hp": 12},
	"bandit":   {"color": Color(0.85, 0.45, 0.15), "base_hp": 14},
	"wolf":     {"color": Color(0.55, 0.55, 0.65), "base_hp": 8},
}

var current_dungeon: DungeonGenerator
var player: GridCharacter
var minimap: Minimap
var turn_ui: TurnUI
var initiative_tracker: InitiativeTracker
var bottom_ui: BottomUI
var attack_preview: Control  # the readout beside an enemy an attack is aimed at
var grid_overlay: GridOverlay
var save_load_menu: SaveLoadMenu  # Properly typed now
var enemies: Array[Enemy] = []
var character_screen

# The turn authority: starts and ends fights and says whose turn it is
var combat: CombatController

# True while the combat controller is running a fight (read-only)
var in_combat: bool:
	get:
		return combat != null and combat.active

# Dropped loot container (GroundItem nodes live under this)
var ground_items_node: Node2D = null

# Active companion nodes in the scene, keyed by companion_id
var companion_nodes: Dictionary = {}

# Counter behind unique enemy node names (never reused within a dungeon)
var _enemy_serial: int = 0

# Game-over screen, created when the player dies
var _game_over_screen: Control = null

# Development shortcuts, only live while GameManager.debug_keys is on (F3):
# R regenerate dungeon, N re-create character, Y talk to the Reeve from anywhere,
# M toggle minimap fog
const DEBUG_KEYCODES: Array = [KEY_R, KEY_N, KEY_Y, KEY_M]

func _ready():
	# Register with GameManager
	GameManager.set_world(self)

	# How should this world start? (see GameManager "GAME FLOW")
	var start: Dictionary = GameManager.consume_pending_start()
	var mode: String = str(start.get("mode", ""))
	var save_data: Dictionary = {}
	if mode == "load" and start.get("data") is Dictionary:
		save_data = start["data"]
	var saved_world: Dictionary = {}
	if save_data.get("world") is Dictionary:
		saved_world = save_data["world"]

	# Dungeon first, generated right here (not deferred) so everything after it
	# can rely on the layout. A save carries the seed and biome to rebuild from.
	current_dungeon = DungeonGeneratorScene.instantiate()
	current_dungeon.auto_generate_on_ready = false
	add_child(current_dungeon)
	GameManager.set_dungeon(current_dungeon)
	if saved_world.has("biome") and RoomLibrary.get_available_biomes().has(str(saved_world["biome"])):
		current_dungeon.biome_type = str(saved_world["biome"])
	current_dungeon.generate_dungeon(int(saved_world.get("seed", 0)))

	# Container for dropped loot (GroundItem nodes)
	ground_items_node = Node2D.new()
	ground_items_node.name = "GroundItems"
	add_child(ground_items_node)

	# The combat controller, before anyone who might fight
	combat = CombatController.new()
	combat.name = "CombatController"
	add_child(combat)
	combat.setup(self)
	combat.combat_started.connect(_on_combat_started)
	combat.combat_ended.connect(_on_combat_ended)

	# Spawn player
	player = CharacterScene.instantiate()
	player.dungeon_generator = current_dungeon
	add_child(player)

	# Position player at start room
	position_player_at_start()

	# Make camera follow player
	current_dungeon.set_camera_target(player)

	# Create UI
	create_minimap()
	create_turn_ui()
	create_initiative_tracker()
	create_bottom_ui()
	create_attack_preview()
	create_save_load_menu()  # Create save/load menu

	# Get reference to grid overlay (it's created by dungeon_generator)
	grid_overlay = current_dungeon.get_node_or_null("GridOverlay")

	# Hide grid initially (exploration mode)
	if grid_overlay:
		grid_overlay.set_enabled(false)
		print("Grid hidden - exploration mode")

# Add character screen with CanvasLayer
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "CharacterScreenLayer"
	add_child(ui_layer)

	character_screen = preload("res://scenes/ui/character_screen.tscn").instantiate()
	ui_layer.add_child(character_screen)  # Add to CanvasLayer, not directly to world

	# === SYSTEMS INTEGRATION ===
	_register_ui_panels()
	_connect_world_signals()

	# === GAME STATE: restore a save, or begin a new game ===
	if mode == "load":
		_restore_from_save(save_data, int(start.get("slot", -1)))
	else:
		_begin_new_game(start.get("stats"))
		# Only games started from the menu autosave; a direct boot of this
		# scene (editor F6, tools) must not overwrite the player's autosave.
		if mode == "new":
			SaveManager.autosave.call_deferred()

	print("World: ready (mode '", mode, "', seed ", current_dungeon.dungeon_seed, ")")

func _register_ui_panels():
	"""Instance the code-built system panels and register them with UIManager.
	Hotkeys open them (see _input); ESC closes (handled by UIManager)."""
	var panel_defs = [
		["spellbook",          "res://ui/spellbook_panel.gd"],
		["crafting",           "res://ui/crafting_panel.gd"],
		["quest_log",          "res://ui/quest_log_panel.gd"],
		["world_map",          "res://ui/world_map_panel.gd"],
		["companions",         "res://ui/companion_panel.gd"],
		["character_creation", "res://ui/character_creation.gd"],
		["dialogue",           "res://ui/dialogue_panel.gd"],  # no hotkey - opened programmatically
		["pause_menu",         "res://scenes/ui/pause_menu.tscn"],  # ESC - opened by UIManager
	]
	for def in panel_defs:
		var panel_id: String = def[0]
		# Panels live under the UIManager autoload and outlive this scene:
		# after a load or a new game they are already there.
		if UIManager.panels.has(panel_id):
			continue
		var resource = load(def[1])
		var panel: Control = null
		if resource is PackedScene:
			panel = resource.instantiate()
		elif resource is Script and resource.can_instantiate():
			panel = resource.new()
		if panel == null:
			push_error("World: could not load panel: " + str(def[1]))
			continue
		UIManager.register_panel(panel_id, panel)
	print("World: UI panels registered (B spellbook, C crafting, J quests, O map, P companions, N new character)")

func _connect_world_signals():
	"""EventBus wiring for the systems integrated at the world layer"""
	EventBus.character_created.connect(_on_character_created)
	EventBus.zone_changed.connect(_on_zone_changed)
	EventBus.crisis_phase_changed.connect(_on_crisis_phase_changed)
	EventBus.companion_recruited.connect(_on_companion_recruited)
	EventBus.companion_dismissed.connect(_on_companion_dismissed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.status_effect_ticked.connect(_on_status_effect_ticked)

func _begin_new_game(created_stats = null):
	"""Start a new game in the freshly generated dungeon. created_stats is the
	CharacterStats from the creation screen; without it (direct boot of this
	scene) the player is a default fighter."""
	if created_stats is CharacterStats:
		player.stats = created_stats
		print("World: new game as ", created_stats.character_name, " the ",
			created_stats.race_id, " ", created_stats.class_id)
	elif player.stats.class_id == "":
		player.stats.class_id = "fighter"
		player.stats.recalculate_derived_stats()
		player.stats.current_hp = player.stats.max_hp
		print("World: default class 'fighter' applied to the player")

	# Equipment bookkeeping is keyed by CharacterStats - register the player
	InventoryManager.set_party_members([player.stats])
	_grant_starting_kit()

	# Casters get their spell list now, so the spellbook is ready
	SpellManager.get_known_spells(player.stats)

	spawn_enemies(3)
	EventBus.player_hp_changed.emit(player.stats.current_hp, player.stats.max_hp)

func _grant_starting_kit():
	"""Give the player their class's starting kit and put it on"""
	var kit_class = player.stats.class_id if player.stats.class_id != "" else "fighter"
	for instance in ItemDatabase.get_starting_kit(kit_class):
		InventoryManager.add_item(instance)
	# Wear the kit: an unequipped fighter starts at AC 11 instead of 17
	var worn = InventoryManager.auto_equip_from_inventory(player.stats)
	print("World: starting kit granted (", kit_class, "), ", worn, " items equipped")

# ============================================================================
# SAVE / RESTORE (the world's own part of a save; SaveManager owns the file)
# ============================================================================

func get_world_state() -> Dictionary:
	"""Everything about this dungeon a save needs to rebuild it: the seed and
	biome give the layout back; the rest is what has changed since. Primitives only."""
	var enemy_list: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		enemy_list.append({
			"type": enemy.enemy_type,
			"level": enemy.enemy_level,
			"hp": enemy.stats.current_hp,
			"max_hp": enemy.stats.max_hp,
			"x": enemy.grid_position.x,
			"y": enemy.grid_position.y,
		})

	var drops: Array = []
	if ground_items_node:
		for drop in ground_items_node.get_children():
			if drop.is_queued_for_deletion():
				continue
			var item_list: Array = []
			for instance in drop.item_instances:
				item_list.append(InventoryManager._instance_to_primitive(instance))
			drops.append({"x": drop.grid_pos.x, "y": drop.grid_pos.y, "gold": drop.gold, "items": item_list})

	var companion_state: Dictionary = {}
	for companion_id in companion_nodes:
		var node = companion_nodes[companion_id]
		if is_instance_valid(node) and node.get("stats") != null:
			companion_state[companion_id] = {"hp": node.stats.current_hp}

	return {
		"seed": current_dungeon.dungeon_seed,
		"biome": current_dungeon.biome_type,
		"enemies": enemy_list,
		"ground_items": drops,
		"explored": minimap.get_explored_state() if minimap else [],
		"companions": companion_state,
	}

func _restore_from_save(save_data: Dictionary, slot: int):
	"""Rebuild the game from a save. The dungeon has already been generated
	from the saved seed; this restores who and what is in it."""
	var player_data: Dictionary = save_data.get("player", {}) if save_data.get("player") is Dictionary else {}
	var stats_data: Dictionary = player_data.get("stats", {}) if player_data.get("stats") is Dictionary else {}
	var saved_world: Dictionary = save_data.get("world", {}) if save_data.get("world") is Dictionary else {}

	# Player first: the managers resolve "player" through GameManager.player.stats
	if stats_data.is_empty():
		# Format-1 saves carried no stats: keep the default fighter
		player.stats.class_id = "fighter"
		player.stats.recalculate_derived_stats()
		player.stats.current_hp = player.stats.max_hp
	else:
		player.stats.from_dict(stats_data)
	InventoryManager.set_party_members([player.stats])

	SaveManager.apply_systems(save_data)
	if stats_data.is_empty():
		_grant_starting_kit()

	if saved_world.has("seed"):
		# Same dungeon: put everything back where it was
		var saved_pos := Vector2i(int(player_data.get("position_x", -1)), int(player_data.get("position_y", -1)))
		if current_dungeon.is_floor_tile(saved_pos):
			player.grid_position = saved_pos
			player.position = player.grid_to_world(saved_pos)
			player.target_position = player.position
		else:
			push_warning("World: saved position %s is not walkable - using the entrance" % str(saved_pos))
		for entry in saved_world.get("enemies", []):
			_spawn_enemy(str(entry.get("type", "goblin")), int(entry.get("level", 1)),
				int(entry.get("max_hp", 10)), Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))),
				int(entry.get("hp", -1)))
		for entry in saved_world.get("ground_items", []):
			var instances: Array = []
			for primitive in entry.get("items", []):
				var instance: Dictionary = InventoryManager._instance_from_primitive(primitive)
				if not instance.is_empty():
					instances.append(instance)
			GroundItemScript.spawn(ground_items_node, Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))),
				player.tile_size, instances, int(entry.get("gold", 0)))
		if minimap:
			minimap.set_explored_state(saved_world.get("explored", []))
	else:
		# A save from before dungeons were saved: the old layout is gone.
		# The player starts at the entrance of a new one.
		spawn_enemies(3)
		EventBus.ui_notification.emit("This save predates saved dungeons - a new one was generated.", "info")

	current_dungeon.set_camera_target(player)

	# Companions: nodes for the restored party, then their saved HP
	_resync_companion_nodes()
	var companion_state: Dictionary = saved_world.get("companions", {}) if saved_world.get("companions") is Dictionary else {}
	for companion_id in companion_state:
		var node = companion_nodes.get(companion_id)
		if node != null and is_instance_valid(node) and node.get("stats") != null:
			node.stats.current_hp = clampi(int(companion_state[companion_id].get("hp", node.stats.max_hp)), 1, node.stats.max_hp)

	EventBus.player_hp_changed.emit(player.stats.current_hp, player.stats.max_hp)
	EventBus.game_loaded.emit(slot)
	print("World: restored from save slot ", slot, " - ", enemies.size(), " enemies, ",
		ground_items_node.get_child_count(), " drops")

func _on_character_created(new_stats):
	"""Apply a panel-confirmed character to the player. CharacterBuilder.build
	also fires this signal when companions build their stats, so only react
	while the character_creation panel is open (the confirm flow)."""
	if not UIManager.is_panel_open("character_creation"):
		return
	if not is_instance_valid(player) or new_stats == null:
		return

	# A confirmed creation replaces the character outright. Drop the old
	# character's equipment bookkeeping and bag first, so nothing is orphaned
	# under the old stats object and no second starting kit piles up.
	if player.stats:
		InventoryManager.equipped_items.erase(player.stats)
	InventoryManager.items.clear()

	player.stats = new_stats
	InventoryManager.set_party_members([new_stats])

	# Starting kit for the chosen class, worn straight away
	for instance in ItemDatabase.get_starting_kit(new_stats.class_id):
		InventoryManager.add_item(instance)
	InventoryManager.auto_equip_from_inventory(new_stats)
	EventBus.inventory_changed.emit()

	EventBus.player_hp_changed.emit(new_stats.current_hp, new_stats.max_hp)

	# Trigger the lazy class spell grants (spellbook is ready immediately)
	SpellManager.get_known_spells(new_stats)

	print("World: player is now ", new_stats.character_name, " the ",
		new_stats.race_id, " ", new_stats.class_id,
		" (HP ", new_stats.current_hp, "/", new_stats.max_hp, ")")
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

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		# F3 switches the debug keys on and off (off by default)
		if event.keycode == KEY_F3:
			GameManager.debug_keys = not GameManager.debug_keys
			if GameManager.debug_keys:
				EventBus.ui_notification.emit("Debug keys ON: R new dungeon, N new character, Y talk to the Reeve, M reveal map", "info")
			else:
				EventBus.ui_notification.emit("Debug keys OFF", "info")
			return

		# Development shortcuts: ignored unless the debug keys are switched on
		if event.keycode in DEBUG_KEYCODES and not GameManager.debug_keys:
			return

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
		
		# SAVE MENU with F5
		elif event.keycode == KEY_F5:
			if save_load_menu:
				var blocked: String = SaveManager.can_save()
				if blocked != "":
					EventBus.ui_notification.emit(blocked, "warning")
				else:
					save_load_menu.show_save_menu()
		
		# LOAD MENU with F6
		elif event.keycode == KEY_F6:
			if save_load_menu:
				save_load_menu.show_load_menu()
				
		elif event.keycode == KEY_I:  # Or KEY_I or whatever key you want
			if character_screen and is_instance_valid(player) and player.stats:
				character_screen.show_character(player.stats)

		# === System panels (UIManager owns exclusivity + pause; ESC closes) ===
		elif event.keycode == KEY_B:
			UIManager.toggle_panel("spellbook")

		elif event.keycode == KEY_C:
			UIManager.toggle_panel("crafting")

		elif event.keycode == KEY_J:
			UIManager.toggle_panel("quest_log")

		elif event.keycode == KEY_O:
			UIManager.toggle_panel("world_map")

		elif event.keycode == KEY_P:
			UIManager.toggle_panel("companions")

		elif event.keycode == KEY_N:
			UIManager.toggle_panel("character_creation")

		# Talk to the Reeve of Brackenford (placeholder dialogue entry point)
		elif event.keycode == KEY_Y:
			if in_combat:
				EventBus.ui_notification.emit("Not while in combat!", "warning")
			elif DialogueManager.start_dialogue("reeve_marta", "reeve_marta"):
				UIManager.open_panel("dialogue")

		# Rests (blocked during combat)
		elif event.keycode == KEY_F7:
			if in_combat:
				EventBus.ui_notification.emit("You cannot rest during combat!", "warning")
			else:
				GameManager.take_short_rest()

		elif event.keycode == KEY_F8:
			if in_combat:
				EventBus.ui_notification.emit("You cannot rest during combat!", "warning")
			else:
				GameManager.take_long_rest()


func regenerate_dungeon(new_biome: String = ""):
	"""Regenerate the entire dungeon and reset game state.
	new_biome != "" switches the biome first (zone travel) - set_biome()
	regenerates the layout itself, so the plain generate call is skipped."""
	print("=== REGENERATING DUNGEON ===")

	# End combat if active
	combat.end_combat()

	# Clear all enemies
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

	# Clear dropped loot from the old layout
	if ground_items_node:
		for drop in ground_items_node.get_children():
			drop.queue_free()

	# Stop player movement
	if is_instance_valid(player):
		player.stop_moving()
		player.cancel_preview()
		player.turn_based_mode = false

	# Regenerate the dungeon
	if current_dungeon:
		if new_biome != "" and current_dungeon.has_method("set_biome"):
			current_dungeon.set_biome(new_biome)  # sets biome_type + regenerates
		else:
			current_dungeon.generate_dungeon()

		# Wait for generation to complete
		await get_tree().create_timer(0.1).timeout

		# Reposition player at new start room
		if is_instance_valid(player):
			position_player_at_start()

			# Reset player state
			player.turn_based_mode = false
			player.attack_mode = false
			player.reset_turn_resources()

		# Update grid overlay reference (in case it was recreated)
		grid_overlay = current_dungeon.get_node_or_null("GridOverlay")
		if grid_overlay:
			grid_overlay.set_enabled(false)

		# Update minimap
		if minimap and is_instance_valid(player):
			minimap.setup(current_dungeon, player)

		# Spawn new enemies
		spawn_enemies(3)

		# Recenter camera on player
		if is_instance_valid(player):
			current_dungeon.set_camera_target(player)

		# Party companions teleport to the fresh start area
		_resync_companion_nodes()

		print("Dungeon regenerated successfully!")

		# A random world event may fire on any regeneration
		WorldEventManager.maybe_trigger_random_event({"source": "dungeon_regenerated"})

func _on_combat_started(_combatants: Array):
	"""A fight has begun: show the grid"""
	if grid_overlay:
		grid_overlay.set_enabled(true)
		print("Grid overlay: ON (combat started)")

func _on_combat_ended(_victory: bool):
	"""The fight is over: back to exploration"""
	if grid_overlay:
		grid_overlay.set_enabled(false)
		print("Grid overlay: OFF (combat ended)")

func spawn_enemies(count: int):
	"""Populate a fresh dungeon. Each enemy gets a random identity (type drives
	loot tables + quest kill credit; level scales XP, gold and loot tier).
	The rolls come from a generator seeded by the dungeon seed, so the same
	seed gives the same starting enemies."""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([current_dungeon.dungeon_seed, "enemies"])

	var type_ids = ENEMY_TYPE_DEFS.keys()
	var zone_tier = 1
	var zone = ZoneManager.get_current_zone()
	if not zone.is_empty():
		zone_tier = max(1, int(zone.get("danger_tier", 1)))

	for i in range(count):
		var enemy_type: String = type_ids[rng.randi() % type_ids.size()]
		var hp_roll = int(ENEMY_TYPE_DEFS[enemy_type]["base_hp"]) + rng.randi_range(-2, 2) + (zone_tier - 1) * 4
		var spawn_pos = find_enemy_spawn_position(rng)
		if spawn_pos == Vector2i(-1, -1):
			print("Failed to find spawn position for enemy ", i + 1)
			continue
		_spawn_enemy(enemy_type, zone_tier, max(1, hp_roll), spawn_pos)

func _spawn_enemy(enemy_type: String, level: int, max_hp: int, grid_pos: Vector2i, current_hp: int = -1) -> Enemy:
	"""Put one enemy into the dungeon. Used for fresh spawns and when a save
	restores the enemies that were alive. current_hp -1 means full health."""
	var enemy = EnemyScene.instantiate()
	enemy.dungeon_generator = current_dungeon
	enemy.player = player

	# Identity: set BEFORE add_child so _ready/initialize_stats picks it up
	var type_def: Dictionary = ENEMY_TYPE_DEFS.get(enemy_type, {})
	enemy.enemy_type = enemy_type
	enemy.enemy_level = level
	enemy.enemy_color = type_def.get("color", Color(1, 0, 0))
	enemy.max_hp = max(1, max_hp)
	enemy.current_hp = enemy.max_hp if current_hp < 0 else clampi(current_hp, 1, enemy.max_hp)
	_enemy_serial += 1
	enemy.name = enemy_type.capitalize() + "_" + str(_enemy_serial)

	add_child(enemy)
	enemy.spawn_at(grid_pos)
	enemies.append(enemy)
	print("Enemy ", enemy.name, " (", enemy_type, " lv", level, ", ", enemy.current_hp, "/", enemy.max_hp, " hp) at ", grid_pos)
	return enemy

func find_enemy_spawn_position(rng: RandomNumberGenerator = null) -> Vector2i:
	"""Find a floor tile well away from the player for an enemy to start on"""
	if not player:
		return Vector2i(-1, -1)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var player_pos = player.get_grid_position()
	var min_distance = 15

	for attempt in range(100):
		var x = rng.randi() % current_dungeon.dungeon_width
		var y = rng.randi() % current_dungeon.dungeon_height
		var pos = Vector2i(x, y)

		if current_dungeon.dungeon_grid[y][x] == current_dungeon.TileType.FLOOR:
			if pos.distance_to(player_pos) >= min_distance and not is_tile_occupied(pos):
				return pos

	return Vector2i(-1, -1)

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
	turn_ui.setup(player, combat)

func create_initiative_tracker():
	"""Create initiative tracker"""
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "InitiativeTrackerLayer"
	add_child(canvas_layer)
	
	initiative_tracker = InitiativeTracker.new()
	canvas_layer.add_child(initiative_tracker)
	initiative_tracker.setup(combat)

func create_bottom_ui():
	"""Create bottom UI panel"""
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "BottomUILayer"
	add_child(canvas_layer)
	
	bottom_ui = BottomUI.new()
	canvas_layer.add_child(bottom_ui)
	bottom_ui.setup(player, combat)

func create_attack_preview():
	"""The hit-chance readout shown beside an enemy while an attack is aimed"""
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "AttackPreviewLayer"
	add_child(canvas_layer)

	attack_preview = AttackPreviewScene.instantiate()
	canvas_layer.add_child(attack_preview)
	attack_preview.setup(player, bottom_ui)

func create_save_load_menu():
	"""Create save/load menu"""
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "SaveLoadMenuLayer"
	add_child(canvas_layer)
	
	save_load_menu = SaveLoadMenu.new()
	canvas_layer.add_child(save_load_menu)
	
	print("SaveLoadMenu created successfully")

func get_combatants() -> Array[Combatant]:
	"""Every combatant body in the scene: the player, party companions and
	enemies. The player's body stays after death - ask is_alive()."""
	var combatants: Array[Combatant] = []
	if is_instance_valid(player):
		combatants.append(player)
	for node in companion_nodes.values():
		if is_instance_valid(node):
			combatants.append(node)
	for enemy in enemies:
		if is_instance_valid(enemy):
			combatants.append(enemy)
	return combatants

func get_combatant_at(grid_pos: Vector2i) -> Combatant:
	"""The combatant standing on a tile, or null"""
	for combatant in get_combatants():
		if combatant.get_grid_position() == grid_pos:
			return combatant
	return null

func is_tile_occupied(grid_pos: Vector2i, exclude = null) -> bool:
	"""True when a combatant other than `exclude` stands on the tile. Called for
	every tile a pathfinder looks at, so it walks the lists without copying them."""
	if is_instance_valid(player) and player != exclude and player.grid_position == grid_pos:
		return true
	for enemy in enemies:
		if enemy != exclude and is_instance_valid(enemy) and enemy.grid_position == grid_pos:
			return true
	for node in companion_nodes.values():
		if node != exclude and is_instance_valid(node) and node.grid_position == grid_pos:
			return true
	return false

func on_enemy_died(enemy: Enemy):
	"""Handle enemy death"""
	enemies.erase(enemy)

	# Out of the fight at once; the controller ends it when no hostile is left
	combat.remove_combatant(enemy)

	# XP + loot drops (combat or not - opportunity kills still count)
	_grant_death_rewards(enemy)

# ============================================================================
# DEATH REWARDS (XP + loot drops)
# ============================================================================

func _grant_death_rewards(enemy: Enemy):
	"""Grant kill XP and roll loot/gold drops onto the enemy's tile"""
	if enemy == null or not is_instance_valid(enemy):
		return

	# XP: CharacterStats.gain_experience emits player_gained_xp + handles level-ups
	if is_instance_valid(player) and player.stats:
		var xp = 25 + 25 * enemy.enemy_level
		player.stats.gain_experience(xp)
		print("World: +", xp, " XP for slaying ", enemy.name,
			" (", player.stats.experience, "/", player.stats.experience_to_next_level, ")")

	# Loot + gold from the enemy type's loot table
	var drops: Array = LootManager.roll_loot(enemy.enemy_type, enemy.enemy_level)
	var gold_amount: int = LootManager.roll_gold(enemy.enemy_type, enemy.enemy_level)

	if drops.is_empty() and gold_amount <= 0:
		return
	if ground_items_node == null or not is_instance_valid(ground_items_node):
		return

	var tile_size = player.tile_size if is_instance_valid(player) else ArtLibrary.TILE_SIZE
	GroundItemScript.spawn(ground_items_node, enemy.grid_position, tile_size, drops, gold_amount)
	EventBus.loot_dropped.emit(enemy, drops)

func drop_items_at_player(instances: Array, gold_amount: int = 0):
	"""Put items on the ground on the player's tile. Called by
	InventoryManager.add_item_or_drop when the bag refuses something the game
	handed the player (crafted item, quest/dialogue/event reward)."""
	if instances.is_empty() and gold_amount <= 0:
		return
	if not is_instance_valid(player) or ground_items_node == null or not is_instance_valid(ground_items_node):
		push_warning("World: nowhere to drop items - they are lost")
		return
	GroundItemScript.spawn(ground_items_node, player.get_grid_position(), player.tile_size, instances, gold_amount)
	EventBus.ui_notification.emit("Your pack is full - it was left at your feet.", "warning")

# ============================================================================
# COMPANIONS (recruit/dismiss -> scene nodes; in a fight each one has its own
# place in the initiative order)
# ============================================================================

func _on_companion_recruited(companion_id: String):
	"""A companion joined the party - put their node into the world"""
	_spawn_companion_node(companion_id)

func _on_companion_dismissed(companion_id: String):
	"""A companion left the party - remove their node from the world"""
	if companion_nodes.has(companion_id):
		var node = companion_nodes[companion_id]
		if is_instance_valid(node):
			combat.remove_combatant(node)
			node.queue_free()
		companion_nodes.erase(companion_id)
		print("World: companion node removed (", companion_id, ")")

func _spawn_companion_node(companion_id: String):
	"""Create + place a companion node on a walkable tile next to the player"""
	if companion_nodes.has(companion_id) and is_instance_valid(companion_nodes[companion_id]):
		return

	var node = CompanionManager.create_companion_node(companion_id)
	if node == null:
		return

	node.dungeon_generator = current_dungeon
	node.player = player
	add_child(node)
	node.spawn_at(_find_companion_spawn_tile())
	companion_nodes[companion_id] = node
	# Joining mid-fight: roll initiative and take a place in the order
	combat.add_combatant(node)
	print("World: companion node spawned (", companion_id, ") at ", node.grid_position)

func _find_companion_spawn_tile() -> Vector2i:
	"""Closest free walkable tile adjacent to the player (rings of radius 1-3)"""
	if not is_instance_valid(player):
		return Vector2i(0, 0)
	var player_pos = player.get_grid_position()
	for radius in range(1, 4):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var tile = player_pos + Vector2i(dx, dy)
				if _is_tile_free_for_companion(tile):
					return tile
	return player_pos  # degenerate fallback - everything around is blocked

func _is_tile_free_for_companion(tile: Vector2i) -> bool:
	"""Floor/door tile no combatant stands on"""
	if not current_dungeon:
		return false
	if tile.x < 0 or tile.x >= current_dungeon.dungeon_width:
		return false
	if tile.y < 0 or tile.y >= current_dungeon.dungeon_height:
		return false
	var tile_type = current_dungeon.dungeon_grid[tile.y][tile.x]
	if tile_type != current_dungeon.TileType.FLOOR and tile_type != current_dungeon.TileType.DOOR:
		return false
	return not is_tile_occupied(tile)

func _resync_companion_nodes():
	"""Clear all companion nodes and respawn the saved party next to the player
	(used after load and after dungeon regeneration)"""
	for companion_id in companion_nodes.keys():
		var node = companion_nodes[companion_id]
		if is_instance_valid(node):
			node.queue_free()
	companion_nodes.clear()

	for companion_id in CompanionManager.get_party():
		_spawn_companion_node(companion_id)

# ============================================================================
# ZONES / CRISIS / LOAD RESYNC / STATUS TICK FEEDBACK
# ============================================================================

func _on_zone_changed(_old_zone_id: String, new_zone_id: String):
	"""Zone travel: switch the dungeon to the zone's biome and regenerate
	(regenerate_dungeon repositions player/enemies/minimap/companions)"""
	var biome = "dungeon"
	var zone = ZoneManager.get_current_zone()
	if not zone.is_empty():
		biome = str(zone.get("biome", "dungeon"))
	print("World: zone changed to ", new_zone_id, " (biome: ", biome, ")")
	await regenerate_dungeon(biome)
	# Arriving somewhere new is a natural point to keep
	SaveManager.autosave()

func _on_crisis_phase_changed(crisis_id: String, phase: int):
	"""Crisis escalation opens up the world (phase 2+ unlocks zone_2)"""
	print("World: crisis '", crisis_id, "' reached phase ", phase)
	if phase >= 2:
		ZoneManager.unlock_zone("zone_2")

func _player_alive() -> bool:
	"""The player exists and can still act. The node is no longer freed on
	death, so validity alone does not mean alive."""
	return is_instance_valid(player) and player.is_alive()

func _on_game_over():
	"""The player died: stop the fight and offer a way back"""
	combat.end_combat()
	if _game_over_screen != null and is_instance_valid(_game_over_screen):
		return
	var layer := CanvasLayer.new()
	layer.name = "GameOverLayer"
	layer.layer = 70
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_game_over_screen = load("res://scenes/ui/game_over.tscn").instantiate()
	layer.add_child(_game_over_screen)
	# The HUD stops updating once the tree is paused: show the final HP first
	if bottom_ui:
		bottom_ui.update_display()
	get_tree().paused = true
	print("World: game over screen shown")

func _on_status_effect_ticked(target, effect_id: String, amount: int):
	"""Floating combat text when a status effect ticks damage or healing"""
	if target == null or not (target is Node2D) or not is_instance_valid(target):
		return
	var definition = StatusEffectManager.get_effect_definition(effect_id)
	var tick = definition.get("tick", {})
	var popup_pos = target.global_position + Vector2(0, -10)
	if str(tick.get("heal_dice", "")) != "":
		DamagePopup.spawn_heal_popup_at(self, popup_pos, amount)
	else:
		DamagePopup.spawn_damage_popup_at(self, popup_pos, amount, false)
