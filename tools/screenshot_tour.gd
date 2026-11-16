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

const MAIN_SCENE := "res://scenes/world.tscn"

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
	player.selected_attack_type = "heavy"
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
	player.selected_attack_type = ""
	player.cancel_preview()
	for drop in drops:
		drop.free()
	await _wait(2.0)  # the floating numbers have gone before the next shot

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

func _run():
	seed(20261116)
	change_scene_to_file(MAIN_SCENE)
	await _wait(2.5)
	var world = root.get_node_or_null("World")
	if world == null:
		print("[TOUR] World node missing")
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
			while world.in_combat and is_instance_valid(player) and not world.initiative_tracker.is_player_turn() and waited < 12.0:
				await _wait(0.2)
				waited += 0.2
			if not world.in_combat or not is_instance_valid(player):
				break
			await _wait(0.4)
			var adjacent = null
			for enemy in world.enemies:
				if is_instance_valid(enemy) and enemy.stats and enemy.stats.is_alive():
					var delta: Vector2i = enemy.grid_position - player.grid_position
					if max(abs(delta.x), abs(delta.y)) == 1:
						adjacent = enemy
						break
			if adjacent != null:
				player.attack_mode = true
				player.selected_attack_type = "heavy"
				player.queue_redraw()
				await _wait(0.25)
				if round_number <= 1:
					await _shot("combat_attack_selected")
				player.attack_enemy(adjacent, "heavy")
				await _wait(0.4)
			player.end_turn()
			await _wait(0.8)
			if round_number == 0:
				await _shot("combat_enemy_turn")
		await _wait(1.5)
		await _shot("after_combat")

	print("[TOUR] done: %d screenshots in %s" % [_index, _out_dir])
	quit(0)
