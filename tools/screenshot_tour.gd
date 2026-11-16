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
	camera.zoom = Vector2(0.55, 0.55)
	await _wait(1.2)
	await _shot("dungeon_overview")
	camera.zoom = zoom
	await _wait(0.8)

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
