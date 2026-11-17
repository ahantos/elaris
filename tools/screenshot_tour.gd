extends SceneTree
# tools/screenshot_tour.gd - opens the game in a real window, walks every screen
# and one fight, and saves a PNG of each to tools/out/screenshots/.
#
# The headless smoke test proves the rules run; this is how you SEE the result.
# Look at the pictures after any change that touches UI or the map.
# Run through tools/run_checks.bat, or directly:
#   <godot> --path <project> --resolution 1920x1080 --script res://tools/screenshot_tour.gd
#
# Like every --script file it must reach autoloads with root.get_node("Name").

const MENU_SCENE := "res://scenes/main_menu.tscn"
# The tour's saves go in a folder of this run's own, removed when the run ends
# (user:// is shared by every checkout of the project)
var _save_dir: String = "user://saves_tour_%d/" % OS.get_process_id()

var _out_dir: String = ""
var _index: int = 0

func _initialize():
	_out_dir = ProjectSettings.globalize_path("res://tools/out/screenshots")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# start clean so pictures from an earlier run cannot be mistaken for this one
	var old := DirAccess.open(_out_dir)
	if old:
		for file_name in old.get_files():
			if file_name.ends_with(".png"):
				old.remove(file_name)
	# keep Godot from importing the screenshots as project textures
	var marker := FileAccess.open(ProjectSettings.globalize_path("res://tools/out/.gdignore"), FileAccess.WRITE)
	if marker:
		marker.close()
	_run()

func _wait(seconds: float):
	await create_timer(seconds, true, false, true).timeout

func _shot(label: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_index += 1
	var path := "%s/%02d_%s.png" % [_out_dir, _index, label]
	var error := root.get_texture().get_image().save_png(path)
	print("[TOUR] ", path, "" if error == OK else "  (save failed: %d)" % error)

# ---------------------------------------------------------------------------
#  Art: one shot per biome with every creature and loot sprite standing on that
#  biome's floor, then one of everything the game draws over the map itself.
#  Add "-- --grid" to the command line to see the combat grid in the biome shots.
# ---------------------------------------------------------------------------

func _art_tour(world):
	var art = load("res://scripts/art_library.gd")
	var manifest = load("res://data/art/art_manifest.gd")
	var player = world.player
	var start_biome: String = world.current_dungeon.biome_type
	var show_grid: bool = "--grid" in OS.get_cmdline_user_args()  # combat grid in the biome shots

	for biome in load("res://scripts/room_library.gd").get_available_biomes():
		await world.regenerate_dungeon(biome)
		await _wait(0.5)
		if show_grid:
			world.grid_overlay.set_enabled(true)
		var sheet := _add_art_sheet(world, art, manifest)
		await _wait(0.2)
		await _shot("biome_" + biome)
		sheet.free()

	# Back to the biome the rest of the tour expects
	await world.regenerate_dungeon(start_biome)
	await _wait(0.5)

	# Path preview through two waypoints, attack range, loot, floating numbers
	var here: Vector2i = player.grid_position
	player.add_waypoint(here + Vector2i(4, 0))
	player.add_waypoint(here + Vector2i(4, 3))
	player.attack_mode = true
	player.queue_redraw()
	var ground_script = load("res://scripts/ground_item.gd")
	var dagger: Dictionary = root.get_node("ItemDatabase").create_item_instance("iron_dagger")
	var drops: Array = [
		ground_script.spawn(world.ground_items_node, here + Vector2i(-3, 1), player.tile_size, [dagger], 0),
		ground_script.spawn(world.ground_items_node, here + Vector2i(-4, 1), player.tile_size, [], 25),
	]
	var popups = load("res://scripts/damage_popup.gd")
	var tile := float(player.tile_size)
	popups.spawn_damage_popup_at(world, player.global_position + Vector2(-3, -2) * tile, 7, false)
	popups.spawn_damage_popup_at(world, player.global_position + Vector2(0, -3) * tile, 12, true)
	popups.spawn_miss_popup_at(world, player.global_position + Vector2(3, -2) * tile)
	popups.spawn_heal_popup_at(world, player.global_position + Vector2(-5, -1) * tile, 5)
	await _wait(0.25)
	await _shot("map_overlays")
	player.attack_mode = false
	player.cancel_preview()
	for drop in drops:
		drop.free()
	# The floating numbers, and any toast a regeneration raised (random world
	# events), have gone before the next shot
	await _wait(4.5)

func _add_art_sheet(world, art, manifest) -> Node2D:
	"""Stand every creature and loot sprite on the floor tiles around the player.
	Sprites only, no game objects: nothing moves, attacks or starts a fight."""
	var textures: Array = []
	for enemy_type in manifest.ENEMY_SPRITES.keys():
		textures.append(art.enemy_sprite(enemy_type))
	for class_id in manifest.PLAYER_SPRITES.keys():
		textures.append(art.player_sprite(class_id))
	for companion_id in manifest.COMPANION_SPRITES.keys():
		textures.append(art.companion_sprite(companion_id))
	textures.append(art.loot_marker(true))
	textures.append(art.loot_marker(false))

	var sheet := Node2D.new()
	sheet.name = "ArtSheet"
	sheet.z_index = 150
	world.add_child(sheet)

	var player = world.player
	var grid: Array = world.current_dungeon.dungeon_grid
	var next := 0
	for radius in range(1, 6):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius or next >= textures.size():
					continue
				var cell: Vector2i = player.grid_position + Vector2i(dx, dy)
				if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].size():
					continue
				if grid[cell.y][cell.x] != 0:
					continue
				var sprite := Sprite2D.new()
				art.fit_sprite(sprite, textures[next], player.tile_size)
				sprite.position = player.grid_to_world(cell)
				sheet.add_child(sprite)
				next += 1
	return sheet

func _aim_ranged_shot(world, target):
	"""The player's first turn of the fight: a few tiles from the enemy and in
	its sight, with the melee set in hand - a shot of the bar offering the swap.
	Then the swap to the set with the ranged weapon, as the request a player
	makes, Attack picked and the pointer resting on the enemy; then one shot,
	for the arrow on its way. The enemy is made to survive the shot, the action
	is handed back each time and the first set goes back in hand: the rest of
	the tour is the fight it was."""
	var grid_script = load("res://scripts/combat_grid.gd")
	var player = world.player
	if not is_instance_valid(target) or not target.is_alive():
		return
	for distance in [4, 3, 5, 2]:
		var moved := false
		for offset in [Vector2i(distance, 0), Vector2i(-distance, 0), Vector2i(0, distance), Vector2i(0, -distance)]:
			var tile: Vector2i = target.grid_position + offset
			if not moved and grid_script.has_line_of_sight(tile, target.grid_position, world.current_dungeon.dungeon_grid) \
					and (tile == player.grid_position or player.teleport_to_grid(tile)):
				moved = true
		if moved:
			break
	await _wait(0.3)
	await _shot("combat_out_of_reach")

	var swapped: bool = world.combat.request_action(player, "swap_weapons").ok
	await _wait(0.3)
	await _shot("combat_swapped")
	player.action_used = false
	player.choose_action("attack")
	# The tour's window has a real mouse somewhere: hold the pointer on the
	# enemy for the picture instead
	player.set_process(false)
	player._update_aim(target.grid_position)
	await _wait(0.3)
	await _shot("combat_ranged_aim")
	player.set_process(true)
	player.attack_mode = false
	player.queue_redraw()

	var hp_before: int = target.stats.current_hp
	target.stats.max_hp += 100
	target.stats.current_hp += 100
	world.combat.request_action(player, "attack", {"target": target})
	await _shot("combat_ranged_shot")
	await _wait(1.5)  # the arrow has landed and its number has gone
	target.stats.max_hp -= 100
	target.stats.current_hp = hp_before
	target.queue_redraw()
	player.action_used = false

	if swapped:
		world.combat.request_action(player, "swap_weapons")
		player.action_used = false
	await _wait(0.2)

func _remove_tour_saves():
	"""Delete this run's scratch folder and everything in it"""
	var dir := DirAccess.open(_save_dir)
	if dir:
		for file_name in dir.get_files():
			dir.remove(file_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_dir))

func _run():
	seed(20261116)
	# The tour's autosave goes to a scratch folder, never the player's saves
	root.get_node("SaveManager").use_save_directory(_save_dir)

	# Front of the game: menu, settings, character creation
	change_scene_to_file(MENU_SCENE)
	await _wait(1.5)
	await _shot("main_menu")
	current_scene.get_node("%SettingsButton").pressed.emit()
	await _wait(0.3)
	await _shot("settings")
	current_scene._settings.close()
	current_scene.get_node("%NewGameButton").pressed.emit()
	await _wait(0.8)
	await _shot("character_creation")
	current_scene.panel._name_edit.text = "Aldric"
	current_scene.panel._on_confirm_pressed()
	await _wait(2.5)

	var world = root.get_node_or_null("World")
	if world == null:
		print("[TOUR] World node missing")
		_remove_tour_saves()
		quit(1)
		return
	var ui = root.get_node("UIManager")
	var dialogue = root.get_node("DialogueManager")
	var companions = root.get_node("CompanionManager")
	var bus = root.get_node("EventBus")
	var game = root.get_node("GameManager")
	var player = world.player

	await _shot("exploration")

	var camera = world.current_dungeon.camera
	var zoom = camera.zoom
	camera.zoom = Vector2(0.5, 0.5)  # exactly half: unfiltered tiles shrink evenly
	await _wait(1.2)
	await _shot("dungeon_overview")
	camera.zoom = zoom
	await _wait(0.8)

	await _art_tour(world)

	world.character_screen.show_character(player.stats)
	await _wait(0.3)
	await _shot("character_sheet")
	world.character_screen.hide_screen()
	paused = false
	await _wait(0.2)

	# Panels, with something in them: a companion recruited, debug keys on
	game.debug_keys = true
	companions.recruit("kaelen")
	await _wait(0.4)
	for panel_id in ["spellbook", "crafting", "quest_log", "world_map", "companions", "character_creation"]:
		ui.open_panel(panel_id)
		await _wait(0.4)
		await _shot("panel_" + panel_id)
		ui.close_panel()
		await _wait(0.15)

	if dialogue.start_dialogue("reeve_marta", "reeve_marta"):
		ui.open_panel("dialogue")
		await _wait(0.4)
		await _shot("dialogue")
		dialogue.end_dialogue()
		ui.close_panel()
		await _wait(0.2)

	world.save_load_menu.show_save_menu()
	await _wait(0.3)
	await _shot("save_menu")
	world.save_load_menu.hide_menu()
	paused = false
	await _wait(0.2)

	ui.open_panel("pause_menu")
	await _wait(0.3)
	await _shot("pause_menu")
	ui.close_panel()
	await _wait(0.2)

	for sample in [["A plain message", "info"], ["Something went well", "success"], ["Out of range!", "warning"], ["Not enough gold!", "error"]]:
		bus.ui_notification.emit(sample[0], sample[1])
	await _wait(0.3)
	await _shot("notifications")
	await _wait(0.5)

	# One fight
	var target = null
	var best := 1e9
	for enemy in world.enemies:
		var d: float = Vector2(enemy.grid_position - player.grid_position).length()
		if d < best:
			best = d
			target = enemy
	if target != null:
		for offset in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			if player.is_walkable(target.grid_position + offset):
				player.teleport_to_grid(target.grid_position + offset)
				break
		await _wait(1.2)
		await _shot("combat_start")
		for round_number in range(12):
			var waited := 0.0
			while world.in_combat and is_instance_valid(player) and not world.combat.is_turn_of(player) and waited < 12.0:
				await _wait(0.2)
				waited += 0.2
			if not world.in_combat or not is_instance_valid(player):
				break
			await _wait(0.4)
			if round_number == 0:
				await _aim_ranged_shot(world, target)
			var adjacent = null
			for enemy in world.enemies:
				if is_instance_valid(enemy) and enemy.stats and enemy.stats.is_alive():
					var delta: Vector2i = enemy.grid_position - player.grid_position
					if max(abs(delta.x), abs(delta.y)) == 1:
						adjacent = enemy
						break
			if adjacent != null:
				# The way a player does it: pick Attack on the bar, then the target
				player.choose_action("attack")
				await _wait(0.25)
				if round_number <= 1:
					await _shot("combat_attack_selected")
				player.attack_mode = false
				player.queue_redraw()
				world.combat.request_action(player, "attack", {"target": adjacent})
				await _wait(0.4)
				if round_number <= 1:
					await _shot("combat_action_spent")
			elif round_number == 0:
				player.choose_action("dash")
				await _wait(0.3)
				await _shot("combat_dash")
			player.end_turn()
			await _wait(0.8)
			if round_number == 0:
				await _shot("combat_enemy_turn")
		await _wait(1.5)
		await _shot("after_combat")

	# Death
	if is_instance_valid(player):
		root.get_node("CombatManager").deal_damage(null, player, 9999)
		await _wait(0.6)
		await _shot("game_over")

	_remove_tour_saves()
	print("[TOUR] done: %d screenshots in %s" % [_index, _out_dir])
	quit(0)
