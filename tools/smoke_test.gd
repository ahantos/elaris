extends SceneTree
# tools/smoke_test.gd - headless regression check for the whole game.
#
# Run it through tools/run_checks.bat (which also fails on any SCRIPT ERROR in
# the log). It boots the real main scene and checks that:
#   - every UI panel and HUD strip is laid out on screen,
#   - notifications reach the screen,
#   - the fixed defects stay fixed (gifting, crafting level, loot pickup, ...),
#   - a scripted fight runs to its end,
#   - attacks use the weapon in hand by 5e rules,
#   - a turn has movement, an action, a bonus action and a reaction, and every
#     action is a request the combat controller approves,
#   - the combat controller alone decides whose turn it is,
#   - content ids referenced across systems exist,
#   - every enemy, class, companion, item and biome tile has real art on the 32px grid.
#
# IMPORTANT: a script started with --script is compiled before the autoloads
# exist. Reach them with root.get_node("Name"), never by their global name.

const WORLD_SCENE := "res://scenes/world.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const TEST_SLOT := 3

# Scratch saves go in a folder of this run's own, removed when the run ends.
# user:// is shared by every checkout of the project, so a fixed folder let two
# runs at once delete and read each other's saves.
var _save_dir: String = "user://saves_smoke_test_%d/" % OS.get_process_id()

# Dangling references that are known and scheduled. A new dangling id fails the
# run; so does an entry here that no longer occurs (delete it when it is fixed).
const KNOWN_GAPS := {
	"quest mq_03_the_herald: kill target 'boss' is not a spawnable enemy type":
		"No boss enemy exists until the Phase 2 bestiary.",
	"companion kaelen: recruit dialogue 'recruit_kaelen' is not defined":
		"Recruit dialogues are Phase 4 content; companions join through the debug button until then.",
	"companion lyra: recruit dialogue 'recruit_lyra' is not defined":
		"Recruit dialogues are Phase 4 content.",
	"companion brom: recruit dialogue 'recruit_brom' is not defined":
		"Recruit dialogues are Phase 4 content.",
	"companion whisper: recruit dialogue 'recruit_whisper' is not defined":
		"Recruit dialogues are Phase 4 content.",
}

var _passed: int = 0
var _failures: Array = []

func _initialize():
	_run()

# ---------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------

func check(condition: bool, label: String, detail: String = ""):
	if condition:
		_passed += 1
		print("[SMOKE] pass  ", label)
	else:
		_failures.append(label)
		print("[SMOKE] FAIL  ", label, ("  -> " + detail) if detail != "" else "")

func _wait(seconds: float):
	await create_timer(seconds, true, false, true).timeout  # ignores pause and time scale

func _frames(count: int = 2):
	for i in range(count):
		await process_frame

func _mgr(mgr_name: String) -> Node:
	return root.get_node(mgr_name)

func _clear_test_saves():
	var dir := DirAccess.open(_save_dir)
	if dir:
		for file_name in dir.get_files():
			dir.remove(file_name)

func _remove_test_saves():
	"""Delete this run's scratch folder and everything in it"""
	_clear_test_saves()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_dir))

func _world() -> Node:
	"""The current World scene, or null while another scene is showing"""
	return root.get_node_or_null("World")

func _grid_hash(world) -> int:
	"""One number for the whole dungeon layout"""
	return hash(world.current_dungeon.dungeon_grid)

func _enemy_summary(world) -> Array:
	"""Type, level, HP and position of every living enemy, in a stable order"""
	var rows: Array = []
	for enemy in world.enemies:
		if is_instance_valid(enemy) and enemy.stats and enemy.stats.is_alive():
			rows.append("%s L%d %d/%d @%d,%d" % [enemy.enemy_type, enemy.enemy_level, enemy.stats.current_hp,
				enemy.stats.max_hp, enemy.grid_position.x, enemy.grid_position.y])
	rows.sort()
	return rows

func _free_floor_near(world, origin: Vector2i, min_distance: int = 3) -> Vector2i:
	"""A walkable tile a few steps from origin (not on it)"""
	for radius in range(min_distance, min_distance + 6):
		for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius)]:
			if world.player.is_walkable(origin + offset):
				return origin + offset
	return origin

func _open_tiles_near(world, origin: Vector2i, min_distance: int, max_distance: int, count: int) -> Array:
	"""Free walkable tiles around origin with a clear line to it, nearest first"""
	var grid_script = load("res://scripts/combat_grid.gd")
	var found: Array = []
	for radius in range(min_distance, max_distance + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius or found.size() >= count:
					continue
				var tile: Vector2i = origin + Vector2i(dx, dy)
				if world.player.is_walkable(tile) and grid_script.has_line_of_sight(origin, tile, world.current_dungeon.dungeon_grid):
					found.append(tile)
	return found

func _finish():
	print("[SMOKE] ---------------------------------------------")
	print("[SMOKE] %d passed, %d failed" % [_passed, _failures.size()])
	for label in _failures:
		print("[SMOKE]   failed: ", label)
	print("[SMOKE] RESULT: ", "PASS" if _failures.is_empty() else "FAIL")
	_remove_test_saves()
	quit(0 if _failures.is_empty() else 1)

# ---------------------------------------------------------------------------
#  Run
# ---------------------------------------------------------------------------

func _run():
	seed(20261116)
	# Saves written by this run go to a scratch folder, never the player's own
	var saves = _mgr("SaveManager")
	saves.use_save_directory(_save_dir)

	# Part 1: the world scene on its own (what the editor's F6 does)
	change_scene_to_file(WORLD_SCENE)
	await _wait(2.0)

	var world = root.get_node_or_null("World")
	check(world != null, "the world scene boots on its own")
	if world == null:
		_finish()
		return

	var player = world.player
	check(is_instance_valid(player) and player.stats != null, "player spawned with stats")
	check(world.current_dungeon.placed_rooms.size() >= 2, "dungeon generated at least two rooms")
	check(world.enemies.size() >= 1, "at least one enemy spawned")
	check(world.current_dungeon.dungeon_grid[player.grid_position.y][player.grid_position.x] == 0,
		"player stands on a floor tile")
	_check_combatants(world)

	await _check_layout(world)
	await _check_notifications()
	await _check_debug_keys(world)
	_check_starting_character(world)
	_check_encumbrance(world)
	_check_weapons(world)
	await _check_art(world)
	_check_crafting(world)
	await _check_companions(world)
	_check_loot_safety(world)
	_check_scroll_use(world)
	_check_class_data()
	_check_content()
	await _check_fight(world)
	await _check_actions(world)
	_check_casters(world)  # replaces the player's stats
	await _check_turn_authority(world)  # last in part 1: fights as the wizard _check_casters leaves behind

	# Part 2: the game as a player meets it - menu, new game, save, load, death
	await _check_game_flow()

	_finish()

# ---------------------------------------------------------------------------
#  Combatants: one base for the player, enemies and companions
# ---------------------------------------------------------------------------

func _check_combatants(world):
	var combatant = load("res://scripts/combatant.gd")
	var player = world.player
	var enemy = world.enemies[0]
	check(is_instance_of(player, combatant) and is_instance_of(enemy, combatant),
		"the player and enemies are combatants")
	check(player.team == combatant.Team.PARTY and enemy.team == combatant.Team.HOSTILE,
		"the player is on the party team and enemies on the hostile one", "%d / %d" % [player.team, enemy.team])
	check(player.is_hostile_to(enemy) and enemy.is_hostile_to(player) and not player.is_hostile_to(player)
		and not enemy.is_hostile_to(world.enemies[-1]), "hostility follows the team")
	check(player.is_alive() and enemy.is_alive() and world.get_combatants().has(player) and world.get_combatants().has(enemy),
		"the world lists the living combatants")
	check(world.get_combatant_at(enemy.grid_position) == enemy and world.is_tile_occupied(enemy.grid_position)
		and not world.is_tile_occupied(enemy.grid_position, enemy) and not player.is_walkable(enemy.grid_position)
		and not enemy.is_walkable(player.grid_position),
		"a combatant's tile is occupied for everyone but itself")
	var there: Vector2i = _free_floor_near(world, player.grid_position, 3)
	var route: Array = player.find_path(player.grid_position, there)
	check(route.size() >= 4 and route[0] == player.grid_position and route[-1] == there
		and enemy.find_path(enemy.grid_position, enemy.grid_position) == [enemy.grid_position]
		and enemy.find_path(enemy.grid_position, player.grid_position) == [enemy.grid_position],
		"the shared pathfinder finds a way to a free tile and none onto an occupied one", str(route))

# ---------------------------------------------------------------------------
#  Layout: every panel fills the screen and keeps its content on it
# ---------------------------------------------------------------------------

func _check_layout(world):
	var ui = _mgr("UIManager")
	var dialogue = _mgr("DialogueManager")
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(screen.size == Vector2(1920, 1080), "design resolution is 1920x1080", str(screen.size))

	for panel_id in ui.panels.keys():
		if panel_id == "dialogue":
			dialogue.start_dialogue("reeve_marta", "reeve_marta")
		ui.open_panel(panel_id)
		await _frames(3)
		var control: Control = ui.panels[panel_id].control
		check(control.visible and control.get_global_rect().is_equal_approx(screen),
			"panel '%s' fills the screen" % panel_id, str(control.get_global_rect()))
		var content_ok := true
		var worst := ""
		var widest := 0.0
		for child in control.get_children():
			if not (child is Control) or not child.visible:
				continue
			var rect: Rect2 = child.get_global_rect()
			widest = max(widest, rect.size.x)
			if not screen.grow(1.0).encloses(rect):
				content_ok = false
				worst = "%s at %s" % [child.name, str(rect)]
		check(content_ok and widest >= 400.0, "panel '%s' content is on screen" % panel_id, worst)
		if panel_id == "dialogue":
			dialogue.end_dialogue()
		ui.close_panel()
		await _frames(1)
	check(not paused, "closing panels releases the pause")

	# Crafting panel's own X button must release the pause too
	ui.open_panel("crafting")
	await _frames(2)
	ui.panels["crafting"].control._on_close_pressed()
	await _frames(1)
	check(not paused and not ui.is_panel_open(), "crafting panel X button closes through UIManager")

	# HUD strips
	check(is_equal_approx(world.turn_ui.size.x, screen.size.x), "turn banner spans the screen width", str(world.turn_ui.size))
	check(is_equal_approx(world.initiative_tracker.size.x, screen.size.x), "initiative bar spans the screen width", str(world.initiative_tracker.size))
	var bottom: Rect2 = world.bottom_ui.get_global_rect()
	check(is_equal_approx(bottom.size.x, screen.size.x) and is_equal_approx(bottom.end.y, screen.size.y) and bottom.size.y >= 200.0,
		"bottom bar spans the screen and sits on its lower edge", str(bottom))

	# The action bar: seven actions in key order, centred in the bottom bar,
	# clear of the panels at either end
	var bar = world.bottom_ui.action_bar
	await _frames(2)
	var titles: Array = []
	var in_order := true
	var last_end := 0.0
	var row_top := -1.0
	for action_id in world.combat.ACTION_BAR:
		var button: Button = bar.get_button(action_id)
		var rect: Rect2 = button.get_global_rect()
		titles.append(button.get_title())
		if rect.position.x < last_end or not bottom.encloses(rect) or (row_top >= 0.0 and not is_equal_approx(rect.position.y, row_top)):
			in_order = false
		last_end = rect.end.x
		row_top = rect.position.y
	var first_rect: Rect2 = bar.get_button(world.combat.ACTION_BAR[0]).get_global_rect()
	check(titles == ["Attack", "Cast", "Use Item", "Dash", "Disengage", "Dodge", "End Turn"] and in_order,
		"the action bar shows its seven actions in key order, in one row inside the bottom bar", str(titles))
	check(first_rect.position.x >= 340.0 and last_end <= 1680.0 and absf((first_rect.position.x + last_end) / 2.0 - screen.size.x / 2.0) <= 2.0,
		"the action bar is centred and clear of the panels at either end", "%d to %d" % [first_rect.position.x, last_end])
	check(bottom.encloses(bar._hint.get_global_rect()) and bottom.encloses(bar._movement_label.get_global_rect()),
		"the action bar's resource strip and hint line are inside the bottom bar")

	# Character sheet and save menu (older screens)
	world.character_screen.show_character(world.player.stats)
	await _frames(2)
	check(world.character_screen.visible, "character sheet opens")
	world.character_screen.hide_screen()
	paused = false
	await _frames(1)

func _check_notifications():
	var ui = _mgr("UIManager")
	var bus = _mgr("EventBus")
	check(ui.toasts != null, "UIManager owns a notification renderer")
	if ui.toasts == null:
		return
	bus.ui_notification.emit("smoke-test notification", "warning")
	await _frames(2)
	check("smoke-test notification" in ui.toasts.get_visible_messages(), "ui_notification is drawn on screen")

func _press(keycode: Key):
	"""Send a real key press and release through the viewport"""
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event)

func _check_debug_keys(world):
	var game = _mgr("GameManager")
	var ui = _mgr("UIManager")
	check(not game.debug_keys, "debug keys are off by default")
	var start_before: Vector2i = world.current_dungeon.start_room.center
	var first_enemy = world.enemies[0]
	_press(KEY_R)
	_press(KEY_N)
	_press(KEY_Y)
	await _wait(0.4)
	check(world.current_dungeon.start_room.center == start_before and is_instance_valid(first_enemy)
		and not ui.is_panel_open() and not paused,
		"R, N and Y do nothing while debug keys are off")
	_press(KEY_F3)
	await _frames(2)
	check(game.debug_keys, "F3 switches the debug keys on")
	_press(KEY_F3)
	await _frames(2)
	check(not game.debug_keys, "F3 switches them off again")

# ---------------------------------------------------------------------------
#  Starting character and rules fixes
# ---------------------------------------------------------------------------

func _check_starting_character(world):
	var inv = _mgr("InventoryManager")
	var stats = world.player.stats
	check(stats.class_id == "fighter", "default character is a fighter")
	check(not inv.get_equipped_item(stats, "chest").is_empty(), "starting armour is worn")
	check(not inv.get_equipped_item(stats, "main_hand").is_empty(), "starting weapon is wielded")
	check(stats.armor_class >= 16, "equipped starting kit raises AC", "AC %d" % stats.armor_class)
	check(stats.movement_speed == 30 and stats.get_modified_movement_speed() == 6,
		"speed is stored in feet and converts to 6 tiles",
		"%d ft / %d tiles" % [stats.movement_speed, stats.get_modified_movement_speed()])

func _check_encumbrance(world):
	var inv = _mgr("InventoryManager")
	var combat = _mgr("CombatManager")
	var player = world.player
	var enemy = world.enemies[0]
	var gold_before: int = inv.gold
	inv.gold += 12000  # 240 lb of coin; set directly to skip the "Gained gold" toast
	check(inv.get_encumbrance_level() == "encumbered", "test setup: party is encumbered", inv.get_encumbrance_level())
	check(player.stats.get_modified_movement_speed() == 4, "encumbered party member keeps 4 tiles of movement",
		str(player.stats.get_modified_movement_speed()))
	check(enemy.stats.get_modified_movement_speed() == 6, "enemy speed ignores the party's load",
		str(enemy.stats.get_modified_movement_speed()))
	var enemy_roll: Dictionary = combat.roll_attack(enemy, player)
	check(not enemy_roll.get("disadvantage", false), "enemy attacks are not at disadvantage from the party's load")
	var player_roll: Dictionary = combat.roll_attack(player, enemy)
	check(player_roll.get("disadvantage", false), "encumbered party member attacks at disadvantage")
	inv.gold = gold_before
	check(player.stats.get_modified_movement_speed() == 6, "movement returns to 6 tiles once the load is gone")

func _check_crafting(world):
	var craft = _mgr("CraftingManager")
	check(craft._get_player() == world.player, "crafting can see the player")
	check(craft._get_player_level() == world.player.stats.level, "crafting reads the player's real level",
		"%d vs %d" % [craft._get_player_level(), world.player.stats.level])

func _check_companions(world):
	var comp = _mgr("CompanionManager")
	var inv = _mgr("InventoryManager")
	var items = _mgr("ItemDatabase")
	check(comp.recruit("kaelen"), "companion can be recruited")
	await _wait(0.3)
	check(world.companion_nodes.has("kaelen") and is_instance_valid(world.companion_nodes["kaelen"]), "recruited companion appears in the world")
	if world.companion_nodes.has("kaelen"):
		var combatant = load("res://scripts/combatant.gd")
		var kaelen = world.companion_nodes["kaelen"]
		check(is_instance_of(kaelen, combatant) and kaelen.team == combatant.Team.PARTY
			and not kaelen.is_hostile_to(world.player) and kaelen.is_hostile_to(world.enemies[0]),
			"a companion is a combatant on the party team")
		check(kaelen.tile_size == 32 and world.get_combatants().has(kaelen) and not world.player.is_walkable(kaelen.grid_position),
			"a companion stands on the 32px grid and occupies its tile")
		_check_hostility(world, kaelen)

	var sword: Dictionary = items.create_item_instance("iron_longsword")
	inv.add_item(sword)
	var before: int = comp.get_relationship("kaelen")
	check(comp.give_gift("kaelen", sword), "gifting an item works")
	check(comp.get_relationship("kaelen") == before + comp.GIFT_DELTA_LOVED, "a loved gift raises the relationship by the loved amount",
		"%d -> %d" % [before, comp.get_relationship("kaelen")])
	# Potions stack, so gift the stack that is in the bag, not a fresh instance
	var potion: Dictionary = {}
	for carried in inv.items:
		if carried.item_data.item_id == "potion_healing_minor":
			potion = carried
	before = comp.get_relationship("lyra")
	comp.recruit("lyra")
	check(not potion.is_empty() and comp.give_gift("lyra", potion) and comp.get_relationship("lyra") == before + comp.GIFT_DELTA_LIKED,
		"a consumable matches the 'type:consumable' gift preference")
	check(not comp.give_gift("lyra", items.create_item_instance("iron_dagger")) and comp.get_relationship("lyra") == before + comp.GIFT_DELTA_LIKED,
		"an item that is not in the bag cannot be gifted")

	comp.dismiss("kaelen")
	await _wait(0.2)
	check(not world.companion_nodes.has("kaelen"), "dismissed companion leaves the world")
	check(comp.rejoin_party("kaelen"), "dismissed companion can rejoin")
	await _wait(0.3)
	check("kaelen" in comp.get_party() and world.companion_nodes.has("kaelen"), "rejoined companion is back in the party and the world")
	comp.dismiss("kaelen")
	comp.dismiss("lyra")
	await _wait(0.2)

func _check_hostility(world, companion):
	"""Who counts as an enemy is decided by team, for targeting, allies and area spells"""
	var spells = _mgr("SpellManager")
	var player = world.player
	var enemy = world.enemies[0]
	check(companion.get_hostiles().has(enemy) and not companion.get_hostiles().has(player)
		and enemy.get_hostiles().has(player) and enemy.get_hostiles().has(companion)
		and player.get_hostiles().size() == world.enemies.size(),
		"each combatant's hostiles are the living combatants of the other team")
	check(player.get_ally_positions() == [companion.grid_position] and enemy.get_ally_positions().size() == world.enemies.size() - 1,
		"allies are the rest of a combatant's own team", str(player.get_ally_positions()))
	check(player._hostile_at(enemy.grid_position) == enemy and player._hostile_at(companion.grid_position) == null
		and player._hostile_at(player.grid_position) == null,
		"the player can only aim attacks and enemy spells at a hostile combatant")
	var around_player: Array = spells._resolve_area_targets(player, player.grid_position, 3)
	var around_enemy: Array = spells._resolve_area_targets(player, enemy.grid_position, 0)
	check(around_player.has(player) and not around_player.has(companion) and around_enemy == [enemy],
		"an area spell takes the caster and its hostiles, and spares the caster's side",
		"%d near the player, %d on the enemy" % [around_player.size(), around_enemy.size()])

func _check_loot_safety(world):
	var inv = _mgr("InventoryManager")
	var items = _mgr("ItemDatabase")
	var ground_script = load("res://scripts/ground_item.gd")
	var gold_before: int = inv.gold
	inv.gold += 12000  # over the weight limit: the bag refuses new items

	var drop = ground_script.spawn(world.ground_items_node, world.player.grid_position + Vector2i(1, 0), world.player.tile_size,
		[items.create_item_instance("iron_longsword")], 0)
	drop.pickup()
	check(is_instance_valid(drop) and not drop.is_queued_for_deletion() and drop.item_instances.size() == 1,
		"loot the bag refuses stays on the ground")

	var children_before: int = world.ground_items_node.get_child_count()
	var went_in: bool = inv.add_item_or_drop(items.create_item_instance("iron_dagger"))
	check(not went_in and world.ground_items_node.get_child_count() == children_before + 1,
		"an item the game hands over is dropped at the player's feet when the bag is full")

	inv.gold = gold_before
	drop.pickup()
	check(drop.is_queued_for_deletion(), "the same loot is picked up once there is room")
	for node in world.ground_items_node.get_children():
		node.queue_free()

func _check_scroll_use(world):
	var inv = _mgr("InventoryManager")
	var items = _mgr("ItemDatabase")
	var spells = _mgr("SpellDatabase")
	var scroll_id := ""
	for spell in spells.get_all_spells():
		var candidate := "scroll_" + str(spell.get("spell_id", ""))
		if str(spell.get("target_type", "")) == "enemy" and items.get_item(candidate) != null:
			scroll_id = candidate
			break
	check(scroll_id != "", "test setup: an enemy-target scroll item exists")
	if scroll_id == "":
		return
	var scroll: Dictionary = items.create_item_instance(scroll_id)
	inv.add_item(scroll)
	var index: int = inv.items.find(scroll)
	world.character_screen._use_inventory_item(index)
	check(not inv.get_item(scroll.instance_id).is_empty(), "using an aimed scroll from the sheet does not destroy it", scroll_id)
	inv.remove_item(scroll.instance_id)

func _check_class_data():
	var classes = _mgr("ClassDatabase")
	var wizard = classes.get_class_data("wizard")
	var cleric = classes.get_class_data("cleric")
	check("int" in wizard.saving_throw_proficiencies and "wis" in wizard.saving_throw_proficiencies,
		"wizard saves are INT and WIS", str(wizard.saving_throw_proficiencies))
	var differences: Array = []
	for level in range(1, 21):
		for slot_level in range(1, 10):
			if wizard.get_spell_slots(level, slot_level) != cleric.get_spell_slots(level, slot_level):
				differences.append("L%d/slot%d" % [level, slot_level])
	check(differences.is_empty(), "wizard and cleric share the 5e full-caster slot table", str(differences))
	check(wizard.get_spell_slots(11, 5) == 2 and wizard.get_spell_slots(17, 9) == 1 and wizard.get_spell_slots(20, 7) == 2,
		"wizard high-level slots match 5e (two 5th at 11, a 9th at 17, two 7th at 20)")

# ---------------------------------------------------------------------------
#  Art: every game id resolves to a real texture, and the map is on the 32px grid
# ---------------------------------------------------------------------------

func _check_art(world):
	var art = load("res://scripts/art_library.gd")
	var manifest = load("res://data/art/art_manifest.gd")
	var items = _mgr("ItemDatabase")
	var dungeon = world.current_dungeon
	var player = world.player
	var enemy = world.enemies[0]

	# Nothing so far (boot, dungeon, spawns, item registration) may have fallen back
	check(art.get_missing().is_empty(), "no art fell back to the missing-art checker while booting", str(art.get_missing()))
	var problems: Array = art.validate_manifest()
	for problem in problems:
		print("[SMOKE]   art: ", problem)
	check(problems.is_empty(), "every file in the art manifest exists and has the right size", "%d problems" % problems.size())

	# Grid and scale
	check(dungeon.tilemap is TileMapLayer and dungeon.tilemap.tile_set != null
		and dungeon.tilemap.tile_set.tile_size == Vector2i(32, 32),
		"the dungeon draws on a TileMapLayer with 32x32 tiles")
	check(player.tile_size == 32 and enemy.tile_size == 32, "player and enemies move on the 32px grid",
		"%d / %d" % [player.tile_size, enemy.tile_size])
	var zoom: Vector2 = dungeon.camera.zoom
	check(is_equal_approx(zoom.x, roundf(zoom.x)) and is_equal_approx(zoom.x, zoom.y), "camera zoom is a whole number", str(zoom))
	check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 1)) == 0,
		"textures are drawn unfiltered (nearest neighbour)")

	# Tiles: every biome and role, and what the generator actually drew
	var roles: Array = ["floor", "wall", "door", "decoration"]
	var tile_gaps: Array = []
	for biome in load("res://scripts/room_library.gd").get_available_biomes():
		for tile_type in range(roles.size()):
			var role: String = art.tile_role(tile_type)
			var textures: Array = art.tile_textures(biome, role)
			var real: bool = role == roles[tile_type] and not textures.is_empty()
			for texture in textures:
				if art.is_fallback(texture):
					real = false
			var source_id: int = art.tile_source_id(biome, role, Vector2i(3, 7))
			if not real or not dungeon.tilemap.tile_set.has_source(source_id):
				tile_gaps.append("%s/%s" % [biome, roles[tile_type]])
	check(tile_gaps.is_empty(), "every biome has real floor, wall, door and decoration tiles", str(tile_gaps))

	var used := 0
	var features := 0
	for row in dungeon.dungeon_grid:
		for tile_type in row:
			if tile_type != -1:
				used += 1
				if tile_type != 0:
					features += 1
	check(dungeon.tilemap.get_used_cells().size() == used and dungeon.feature_layer.get_used_cells().size() == features,
		"the map has a floor tile under every cell and a feature tile on every wall, door and decoration",
		"%d/%d floor, %d/%d features" % [dungeon.tilemap.get_used_cells().size(), used, dungeon.feature_layer.get_used_cells().size(), features])

	# Variants come from the cell, not from the random number generator
	seed(4242)
	var expected_roll: int = randi()
	seed(4242)
	var first_pass: Array = []
	var distinct: Dictionary = {}
	for y in range(12):
		for x in range(12):
			var variant_id: int = art.tile_source_id("forest", "floor", Vector2i(x, y))
			first_pass.append(variant_id)
			distinct[variant_id] = true
	var rng_untouched: bool = randi() == expected_roll
	var second_pass: Array = []
	for y in range(12):
		for x in range(12):
			second_pass.append(art.tile_source_id("forest", "floor", Vector2i(x, y)))
	seed(20261116)  # back to the run's seed; the probe above re-seeded the generator
	check(rng_untouched and first_pass == second_pass and distinct.size() >= 2,
		"tile variants depend only on the cell and leave the random number generator alone",
		"rng untouched %s, repeatable %s, %d variants" % [rng_untouched, first_pass == second_pass, distinct.size()])

	# Creatures
	var enemy_gaps: Array = []
	for enemy_type in world.ENEMY_TYPE_DEFS.keys():
		if art.is_fallback(art.enemy_sprite(enemy_type)):
			enemy_gaps.append(enemy_type)
	check(enemy_gaps.is_empty(), "every spawnable enemy type has a sprite", str(enemy_gaps))

	var class_gaps: Array = []
	for class_id in [""] + _mgr("ClassDatabase").get_all_class_ids():
		if art.is_fallback(art.player_sprite(class_id)):
			class_gaps.append(class_id)
	check(class_gaps.is_empty(), "the player has a sprite for every class", str(class_gaps))

	var companion_gaps: Array = []
	var companion_defs: Dictionary = _mgr("CompanionManager").companion_definitions
	for companion_id in companion_defs.keys():
		if art.is_fallback(art.companion_sprite(companion_id, str(companion_defs[companion_id].get("class_id", "")))):
			companion_gaps.append(companion_id)
	check(companion_gaps.is_empty(), "every companion has a sprite", str(companion_gaps))

	var player_sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	var enemy_sprite: Sprite2D = enemy.get_node_or_null("Sprite2D")
	check(player_sprite != null and player_sprite.texture == art.player_sprite(player.stats.class_id)
		and player_sprite.scale.is_equal_approx(Vector2.ONE),
		"the player in the world wears the sprite of their class at one tile")
	check(enemy_sprite != null and enemy_sprite.texture == art.enemy_sprite(enemy.enemy_type)
		and enemy_sprite.scale.is_equal_approx(Vector2.ONE) and enemy_sprite.modulate == Color.WHITE,
		"an enemy in the world wears the sprite of its type, untinted, at one tile")
	check(world.initiative_tracker._get_sprite_texture(enemy) == art.enemy_sprite(enemy.enemy_type),
		"the initiative bar shows a combatant's own sprite")

	# The class is set after the player node is ready (new game, creation, load)
	var class_before: String = player.stats.class_id
	player.stats.class_id = "wizard"
	await _frames(2)
	var followed: bool = player_sprite.texture == art.player_sprite("wizard") and art.player_sprite("wizard") != art.player_sprite("fighter")
	player.stats.class_id = class_before
	await _frames(2)
	check(followed and player_sprite.texture == art.player_sprite(class_before), "the player's sprite follows a change of class")

	# Loot on the floor
	var ground_script = load("res://scripts/ground_item.gd")
	var bag = ground_script.spawn(world.ground_items_node, player.grid_position + Vector2i(2, 0), player.tile_size,
		[items.create_item_instance("iron_dagger")], 5)
	var coins = ground_script.spawn(world.ground_items_node, player.grid_position + Vector2i(3, 0), player.tile_size, [], 5)
	var bag_sprite: Sprite2D = bag.get_node_or_null("Sprite2D")
	var coin_sprite: Sprite2D = coins.get_node_or_null("Sprite2D")
	check(bag_sprite != null and coin_sprite != null
		and not art.is_fallback(bag_sprite.texture) and not art.is_fallback(coin_sprite.texture)
		and bag_sprite.texture == art.loot_marker(true) and coin_sprite.texture == art.loot_marker(false),
		"loot on the floor is a sprite: a bag for items, coins for gold alone")
	bag.free()
	coins.free()

	# Items
	var icon_gaps: Array = []
	for item_id in items.items.keys():
		if art.is_fallback(items.items[item_id].icon):
			icon_gaps.append(item_id)
	icon_gaps.sort()
	check(icon_gaps.is_empty(), "every item in ItemDatabase has an icon (%d items)" % items.items.size(),
		"%d without: %s" % [icon_gaps.size(), str(icon_gaps.slice(0, 12))])
	check(items.items["steel_longsword"].icon == items.items["longsword"].icon
		and items.items["iron_plate_boots"].icon != items.items["hide_boots"].icon,
		"material variants share the icon of their base type")

	# The character sheet shows the icon instead of the name, and keeps count and tooltip
	var sheet = world.character_screen
	sheet.show_character(player.stats)
	var weapon_slot: Button = sheet.slot_buttons["main_hand"]
	var weapon_icon: TextureRect = weapon_slot.get_node_or_null("ItemIcon")
	check(weapon_icon != null and weapon_icon.texture != null and not art.is_fallback(weapon_icon.texture)
		and weapon_slot.text == "" and weapon_slot.tooltip_text != "",
		"an equipment slot shows the item's icon, no name text, and keeps its tooltip")
	var stacked_ok := false
	var inventory = _mgr("InventoryManager")
	for i in range(min(inventory.items.size(), sheet.inventory_slots.size())):
		if int(inventory.items[i].get("stack_count", 1)) > 1:
			var slot: Button = sheet.inventory_slots[i]
			var count_label: Label = slot.get_node_or_null("StackCount")
			var slot_icon: TextureRect = slot.get_node_or_null("ItemIcon")
			stacked_ok = (count_label != null and count_label.text == "x%d" % int(inventory.items[i].stack_count)
				and slot_icon != null and slot_icon.texture != null and slot.text == "" and slot.tooltip_text != "")
			break
	check(stacked_ok, "an inventory slot shows the icon with the stack count over it")
	sheet.hide_screen()
	paused = false

	# The checklist the art gets drawn against lists every file
	var checklist := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://docs/ART_CHECKLIST.md"))
	var unlisted: Array = []
	for entry in art.all_entries():
		if not str(entry["path"]).trim_prefix("res://") in checklist:
			unlisted.append(entry["path"])
	check(unlisted.is_empty() and manifest.TILE_SIZE == 32, "docs/ART_CHECKLIST.md lists every file in the art manifest",
		"%d not listed - run tools/art_checklist.gd: %s" % [unlisted.size(), str(unlisted.slice(0, 5))])

	# Last, on purpose: unknown ids give the visible fallback, never null, and are reported
	check(art.get_missing().is_empty(), "no art fell back to the missing-art checker during the art checks", str(art.get_missing()))
	var fallback: Texture2D = art.fallback_texture()
	var fell_back: bool = (fallback != null
		and art.enemy_sprite("no_such_enemy") == fallback
		and art.item_icon("no_such_item") == fallback
		and art.player_sprite("no_such_class") == fallback
		and art.companion_sprite("no_such_companion", "") == fallback
		and art.tile_texture("no_such_biome", "floor", Vector2i.ZERO) == fallback
		and dungeon.tilemap.tile_set.has_source(art.tile_source_id("no_such_biome", "wall", Vector2i.ZERO)))
	check(fell_back and art.get_missing().size() == 6, "unknown ids get the visible missing-art texture and are reported",
		"%d reported" % art.get_missing().size())
	art.clear_missing()

# ---------------------------------------------------------------------------
#  Content: every id referenced across systems must exist
# ---------------------------------------------------------------------------

func _check_content():
	var validator = load("res://tools/content_validator.gd")
	var issues: Array = validator.find_issues(root)
	var unexpected: Array = []
	for issue in issues:
		if KNOWN_GAPS.has(issue):
			print("[SMOKE] known ", issue, "  (", KNOWN_GAPS[issue], ")")
		else:
			unexpected.append(issue)
	for issue in unexpected:
		print("[SMOKE]   dangling: ", issue)
	check(unexpected.is_empty(), "no new dangling content references", "%d found" % unexpected.size())
	var stale: Array = []
	for gap in KNOWN_GAPS.keys():
		if not gap in issues:
			stale.append(gap)
	check(stale.is_empty(), "the known-gaps list has no stale entries", str(stale))

# ---------------------------------------------------------------------------
#  A scripted fight, start to finish
# ---------------------------------------------------------------------------

func _check_fight(world):
	var player = world.player
	var stats = player.stats
	var xp_before: int = stats.experience

	# Nearest enemy; stand next to it
	var target = null
	var best := 1e9
	for enemy in world.enemies:
		var d: float = Vector2(enemy.grid_position - player.grid_position).length()
		if d < best:
			best = d
			target = enemy
	var placed := false
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var tile: Vector2i = target.grid_position + offset
		if player.is_walkable(tile):
			player.teleport_to_grid(tile)
			placed = true
			break
	check(placed, "test setup: player placed next to an enemy")
	if not placed:
		return

	# The fight checks flow, not balance: enough HP that no crit can end it
	stats.max_hp = 500
	stats.current_hp = 500

	Engine.time_scale = 6.0
	await _wait(0.5)
	check(world.in_combat, "combat starts when an enemy is near")
	check(world.combat.get_order().size() >= 2 and world.combat.get_order().has(player), "initiative holds the player and the enemy")

	var rounds := 0
	while world.in_combat and is_instance_valid(player) and rounds < 40:
		var waited := 0.0
		while world.in_combat and not world.combat.is_turn_of(player) and waited < 6.0:
			await _wait(0.05)
			waited += 0.05
		if not world.in_combat:
			break
		stats.current_hp = stats.max_hp
		var adjacent = null
		for enemy in world.enemies:
			if is_instance_valid(enemy) and enemy.stats and enemy.stats.is_alive():
				var delta: Vector2i = enemy.grid_position - player.grid_position
				if max(abs(delta.x), abs(delta.y)) == 1:
					adjacent = enemy
					break
		if adjacent != null:
			world.combat.request_action(player, "attack", {"target": adjacent})
		player.end_turn()
		await _wait(0.1)
		rounds += 1
	Engine.time_scale = 1.0
	stats.recalculate_derived_stats()  # back to the real maximum
	stats.current_hp = stats.max_hp

	check(is_instance_valid(player) and stats.is_alive(), "player survives the scripted fight")
	check(not world.in_combat, "combat ends when the nearby enemies are dead", "still in combat after %d rounds" % rounds)
	check(stats.experience > xp_before, "kills award XP", "%d -> %d" % [xp_before, stats.experience])
	check(not player.turn_based_mode, "player returns to free movement after combat")

# ---------------------------------------------------------------------------
#  Weapons: an attack is made with what is in the hand, by 5e rules
# ---------------------------------------------------------------------------

func _damage_range(combat, profile: Dictionary, is_crit: bool = false) -> Array:
	"""The lowest and highest damage in 300 rolls of an attack profile"""
	var lowest := 1000000
	var highest := -1000000
	for i in range(300):
		var damage: int = combat.roll_damage(profile, is_crit)
		lowest = min(lowest, damage)
		highest = max(highest, damage)
	return [lowest, highest]

func _check_weapons(world):
	"""The default fighter (STR 14, DEX 12, proficiency +2) with its starting
	kit: longsword, shield, light crossbow in the ranged slot"""
	var combat = _mgr("CombatManager")
	var inv = _mgr("InventoryManager")
	var items = _mgr("ItemDatabase")
	var player = world.player
	var stats = player.stats
	var longsword: Dictionary = inv.get_equipped_item(stats, "main_hand")
	var shield: Dictionary = inv.get_equipped_item(stats, "off_hand")
	var crossbow: Dictionary = inv.get_equipped_item(stats, "ranged")
	check(stats.class_id == "fighter" and stats.get_str_modifier() == 2 and stats.get_dex_modifier() == 1 and stats.proficiency_bonus == 2
		and not longsword.is_empty() and longsword.item_data.item_id == "longsword" and not shield.is_empty() and not crossbow.is_empty(),
		"test setup: the fighter holds a longsword and a shield and carries a crossbow")
	if longsword.is_empty() or shield.is_empty() or crossbow.is_empty():
		return

	# --- the equipped weapon's die and damage type; versatile with a shield ---
	var profile: Dictionary = combat.get_attack_profile(player)
	check(profile.weapon == longsword.item_data and profile.weapon_name == "Iron Longsword" and profile.damage_dice == "1d8"
		and profile.damage_type == "slashing" and profile.usable,
		"an attack uses the weapon in the main hand: its die and its damage type",
		"%s %s %s" % [profile.weapon_name, profile.damage_dice, profile.damage_type])
	check(profile.ability == "str" and profile.ability_modifier == 2 and profile.proficient and profile.attack_bonus == 4,
		"the attack roll adds the Strength modifier and the proficiency bonus", "+%d" % profile.attack_bonus)
	check(_damage_range(combat, profile) == [3, 10], "damage is the weapon's die plus the same ability modifier",
		str(_damage_range(combat, profile)))
	var crit_range: Array = _damage_range(combat, profile, true)
	check(crit_range[0] >= 4 and crit_range[1] > 10 and crit_range[1] <= 18, "a critical hit rolls the weapon's die twice", str(crit_range))
	check(not profile.two_handed_grip, "a versatile weapon held beside a shield uses its one-handed die")

	# --- versatile: the larger die with the off hand empty ---
	inv.unequip_item(stats, "off_hand")
	profile = combat.get_attack_profile(player)
	check(profile.damage_dice == "1d10" and profile.two_handed_grip and _damage_range(combat, profile) == [3, 12],
		"a versatile weapon uses its larger die when the off hand is empty", "%s %s" % [profile.damage_dice, str(_damage_range(combat, profile))])
	var versatile_ids: Array = []
	for item_id in ["longsword", "battleaxe", "warhammer", "quarterstaff", "spear"]:
		var weapon = items.get_item(item_id)
		versatile_ids.append("%s %s/%s%s" % [item_id, weapon.damage_dice, weapon.versatile_dice, " 2h" if weapon.is_two_handed else ""])
	check(versatile_ids == ["longsword 1d8/1d10", "battleaxe 1d8/1d10", "warhammer 1d8/1d10", "quarterstaff 1d6/1d8", "spear 1d6/1d8"],
		"the versatile weapons carry their two-handed die, as in the 5e weapon table", str(versatile_ids))

	# --- two-handed: both hands, enforced where equipping happens ---
	var greatsword: Dictionary = items.create_item_instance("greatsword")
	inv.add_item(greatsword)
	inv.equip_item(shield, stats, "off_hand")
	check(not inv.equip_item(greatsword, stats, "main_hand") and inv.get_equipped_item(stats, "main_hand") == longsword,
		"a two-handed weapon cannot be equipped while the off hand holds something")
	inv.unequip_item(stats, "off_hand")
	check(inv.equip_item(greatsword, stats, "main_hand") and not inv.equip_item(shield, stats, "off_hand")
		and inv.get_equipped_item(stats, "off_hand").is_empty(),
		"nothing can be equipped in the off hand beside a two-handed weapon")
	profile = combat.get_attack_profile(player)
	check(profile.damage_dice == "2d6" and profile.usable, "a two-handed weapon in both hands attacks with its own dice", profile.damage_dice)
	inv.equipped_items[stats]["off_hand"] = shield  # a state an old save can hold
	profile = combat.get_attack_profile(player)
	check(not profile.usable and "both hands" in profile.reason, "a two-handed weapon beside a full off hand cannot attack, and says why", profile.reason)
	inv.equipped_items[stats].erase("off_hand")

	# --- finesse: the better of Strength and Dexterity ---
	var rapier: Dictionary = items.create_item_instance("rapier")
	inv.add_item(rapier)
	inv.equip_item(rapier, stats, "main_hand")
	profile = combat.get_attack_profile(player)
	check(profile.weapon_name == "Iron Rapier" and profile.ability == "str" and profile.ability_modifier == 2,
		"a finesse weapon uses Strength when that is the higher modifier", "%s %+d" % [profile.ability, profile.ability_modifier])
	stats.dexterity = 18
	profile = combat.get_attack_profile(player)
	check(profile.ability == "dex" and profile.ability_modifier == 4 and profile.attack_bonus == 6 and _damage_range(combat, profile) == [5, 12],
		"a finesse weapon uses Dexterity when that is the higher modifier, for the attack roll and the damage",
		"%s %+d, damage %s" % [profile.ability, profile.ability_modifier, str(_damage_range(combat, profile))])
	var plain: Dictionary = combat.build_attack_profile(player, longsword.item_data)
	check(plain.ability == "str" and plain.ability_modifier == 2, "a weapon without finesse uses Strength however high Dexterity is")
	stats.dexterity = 12

	# --- proficiency comes from the class, by weapon group or by name ---
	var battleaxe = items.get_item("battleaxe")
	var club = items.get_item("club")
	check(rapier.item_data.weapon_category == "martial" and club.weapon_category == "simple" and items.get_item("longbow").weapon_category == "martial"
		and items.get_item("light_crossbow").weapon_category == "simple" and items.get_item("steel_dagger").weapon_category == "simple",
		"weapons say whether they are simple or martial")
	stats.class_id = "wizard"
	profile = combat.get_attack_profile(player)
	var wizard_club: Dictionary = combat.build_attack_profile(player, club)
	check(not profile.proficient and profile.attack_bonus == 2 and wizard_club.proficient and wizard_club.attack_bonus == 4,
		"a weapon the class is not proficient with gets no proficiency bonus", "rapier +%d, club +%d" % [profile.attack_bonus, wizard_club.attack_bonus])
	stats.class_id = "rogue"
	check(combat.get_attack_profile(player).proficient and not combat.build_attack_profile(player, battleaxe).proficient,
		"a class can be proficient with a weapon by name: a rogue with a rapier, not with a battleaxe")
	stats.class_id = "fighter"
	check(combat.get_attack_profile(player).proficient and combat.build_attack_profile(player, battleaxe).proficient,
		"a fighter is proficient with martial weapons")

	# --- a ranged weapon in hand, then nothing in hand ---
	inv.unequip_item(stats, "main_hand")
	profile = combat.get_attack_profile(player)
	check(profile.weapon == crossbow.item_data and profile.is_ranged and not profile.usable and "ranged" in profile.reason,
		"with the main hand empty the carried ranged weapon is the weapon in hand, and it cannot attack yet", profile.reason)
	inv.unequip_item(stats, "ranged")
	profile = combat.get_attack_profile(player)
	check(profile.weapon == null and profile.weapon_name == "Unarmed strike" and profile.damage_type == "bludgeoning" and profile.proficient
		and profile.attack_bonus == 4 and profile.usable and _damage_range(combat, profile) == [3, 3] and _damage_range(combat, profile, true) == [3, 3],
		"with no weapon the attack is an unarmed strike: 1 + Strength modifier bludgeoning, proficient",
		"%s %s %s" % [profile.weapon_name, str(_damage_range(combat, profile)), profile.damage_type])

	# Back to the starting kit
	inv.equip_item(longsword, stats, "main_hand")
	inv.equip_item(shield, stats, "off_hand")
	inv.equip_item(crossbow, stats, "ranged")
	inv.remove_item(greatsword.instance_id)
	inv.remove_item(rapier.instance_id)
	stats.current_hp = stats.max_hp
	check(inv.get_equipped_item(stats, "main_hand") == longsword and inv.get_equipped_item(stats, "off_hand") == shield
		and inv.get_equipped_item(stats, "ranged") == crossbow, "test teardown: the starting kit is back in place")

# ---------------------------------------------------------------------------
#  Turn resources and actions: everything done in a turn is a request
# ---------------------------------------------------------------------------

func _until(condition: Callable, timeout: float = 15.0) -> bool:
	"""Wait until the condition holds; false when it never does"""
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await _wait(0.02)
		waited += 0.02
	return condition.call()

func _walk(player, tile: Vector2i) -> bool:
	"""Walk the player to a tile the way a click does; true when it got there"""
	player.show_path_preview(tile)
	player.execute_move()
	await _until(func(): return not player.is_moving, 5.0)
	player.cancel_preview()
	return player.grid_position == tile

func _toughen(stats):
	"""Enough HP that no blow can end a staged fight (changing equipment recalculates it)"""
	stats.max_hp = 500
	stats.current_hp = 500

func _find_lane(world, origin: Vector2i) -> Array:
	"""[centre, step]: five free floor tiles in a straight line near origin, for
	a staged fight. The centre may be the player's own tile. [] when none."""
	var player = world.player
	for radius in range(0, 7):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var centre: Vector2i = origin + Vector2i(dx, dy)
				if centre != player.grid_position and not player.is_walkable(centre):
					continue
				for step in [Vector2i(1, 0), Vector2i(0, 1)]:
					var free := true
					for offset in [-2, -1, 1, 2]:
						if not player.is_walkable(centre + step * offset):
							free = false
					if free:
						return [centre, step]
	return []

func _potion_stack(inv) -> Dictionary:
	for carried in inv.items:
		if carried.item_data.item_id == "potion_healing_minor":
			return carried
	return {}

func _check_actions(world):
	"""A staged fight: the default fighter against one goblin that cannot be
	killed and that anything but a natural 1 hits. Checks what a turn is given,
	what each action costs, and that every action is a request the controller
	approves - the player's, the enemy's and a companion's alike."""
	var combat_mgr = _mgr("CombatManager")
	var effects = _mgr("StatusEffectManager")
	var inv = _mgr("InventoryManager")
	var items = _mgr("ItemDatabase")
	var comp = _mgr("CompanionManager")
	var bus = _mgr("EventBus")
	var ui = _mgr("UIManager")
	var controller = world.combat
	var player = world.player
	var stats = player.stats
	var bar = world.bottom_ui.action_bar
	var sheet = world.character_screen
	var home: Vector2i = player.grid_position

	var lane: Array = _find_lane(world, home)
	check(not lane.is_empty() and not world.in_combat, "test setup: a lane of free floor for the staged fight")
	if lane.is_empty() or world.in_combat:
		return
	var here: Vector2i = lane[0]
	var step: Vector2i = lane[1]
	if here != home:
		player.teleport_to_grid(here)
	_toughen(stats)
	for i in range(4):
		inv.add_item(items.create_item_instance("potion_healing_minor"))
	var potions: Dictionary = _potion_stack(inv)

	# What the fight announces
	var taken: Array = []  # [combatant, action id, result] for every approved request
	var on_action = func(combatant, action_id, result): taken.append([combatant, action_id, result])
	controller.action_taken.connect(on_action)
	var blows: Array = []  # [attacker, target, amount, damage type]
	var on_damage = func(attacker, target, amount, _is_crit, damage_type): blows.append([attacker, target, amount, damage_type])
	bus.damage_dealt.connect(on_damage)
	var reactions: Array = []
	var on_reaction = func(reactor, _reaction_id, _source): reactions.append(reactor)
	bus.reaction_triggered.connect(on_reaction)
	var turn_log: Array = []  # [combatant, was its reaction spent when its turn began]
	var on_turn = func(combatant): turn_log.append([combatant, combatant.reaction_used])
	controller.turn_started.connect(on_turn)
	var notes: Array = []
	var on_note = func(message, _type): notes.append(message)
	bus.ui_notification.connect(on_note)

	var goblin = world._spawn_enemy("goblin", 1, 500, here + step)
	goblin.stats.armor_class = -100
	Engine.time_scale = 4.0
	var started: bool = await _until(func(): return world.in_combat, 3.0)
	# Only the staged goblin fights: anyone else the fight pulled in sits it out
	for other in controller.get_order():
		if other != player and other != goblin:
			controller.remove_combatant(other)
	var my_turn: bool = started and await _until(func(): return controller.is_turn_of(player) or not world.in_combat)
	var fighters: Array = controller.get_order()
	check(started and my_turn and controller.is_turn_of(player) and fighters.size() == 2 and fighters.has(goblin),
		"test setup: the staged fight started, the player against the goblin, and the player's turn came",
		"%d in the order" % fighters.size())
	if not controller.is_turn_of(player):
		Engine.time_scale = 1.0
		return

	# --- what a turn is given ---
	check(player.movement_left == 6 and player.movement_granted == 6 and not player.action_used
		and not player.bonus_action_used and not player.reaction_used,
		"a turn starts with a speed's worth of movement, the action, the bonus action and the reaction",
		"movement %d" % player.movement_left)
	await _frames(2)
	var attack_button = bar.get_button("attack")
	check(not attack_button.disabled and "Iron Longsword" in attack_button.get_detail() and "1d8" in attack_button.get_detail(),
		"the Attack button names the equipped weapon and its die", attack_button.get_detail())
	check(bar._turn_label.text == "Your turn" and bar._movement_label.text == "Movement 6 / 6" and bar._action_label.text == "Action ready"
		and bar._bonus_label.text == "Bonus action ready" and bar._action_label.visible,
		"the HUD shows the turn-holder's movement and that its action and bonus action are unspent",
		"%s | %s | %s" % [bar._turn_label.text, bar._movement_label.text, bar._action_label.text])

	# --- a request out of turn ---
	var goblin_before: Array = [goblin.action_used, goblin.movement_left]
	var out_of_turn: Dictionary = controller.request_action(goblin, "dash")
	check(not out_of_turn.ok and out_of_turn.reason == "Not your turn" and [goblin.action_used, goblin.movement_left] == goblin_before,
		"a request from a combatant whose turn it is not is refused and costs nothing", str(out_of_turn))

	# --- Attack: the equipped weapon, once a turn ---
	var hit: Dictionary = {}
	var hp_lost := 0
	for attempt in range(40):
		player.action_used = false
		blows.clear()
		var hp_before: int = goblin.stats.current_hp
		var swing: Dictionary = controller.request_action(player, "attack", {"target": goblin})
		if swing.ok and swing.hit:
			hit = swing
			hp_lost = hp_before - goblin.stats.current_hp
			break
	check(not hit.is_empty() and hit.weapon_name == "Iron Longsword" and hit.damage_dice == "1d8" and hit.damage_type == "slashing"
		and hit.damage >= (4 if hit.is_crit else 3) and hit.damage <= (18 if hit.is_crit else 10) and hp_lost == hit.damage,
		"the Attack action hits with the equipped weapon's die and damage type", str(hit.get("damage", "no hit")))
	check(blows.size() == 1 and blows[0][0] == player and blows[0][1] == goblin and blows[0][2] == hp_lost
		and blows[0][3] == combat_mgr.DamageType.SLASHING,
		"the weapon's damage type travels with the damage to where it is applied", str(blows))
	var hp_after_first: int = goblin.stats.current_hp
	var second: Dictionary = controller.request_action(player, "attack", {"target": goblin})
	check(player.action_used and not second.ok and second.reason == "Action spent" and goblin.stats.current_hp == hp_after_first,
		"a second attack in the same turn is refused", str(second))
	await _frames(2)
	check(attack_button.disabled and attack_button.get_reason() == "Action spent" and bar._action_label.text == "Action spent",
		"with the action spent the Attack button is disabled and says why", attack_button.get_reason())
	player.refresh_turn_resources()  # test setup, here and below: a fresh turn's resources without waiting a round
	var friendly: Dictionary = controller.request_action(player, "attack", {"target": player})
	check(not friendly.ok and not player.action_used, "an attack on anything but a hostile combatant is refused")

	# --- a ranged weapon in hand, then nothing in hand ---
	var sword: Dictionary = inv.unequip_item(stats, "main_hand")
	_toughen(stats)
	var ranged_check: Dictionary = controller.check_action(player, "attack")
	var ranged_try: Dictionary = controller.request_action(player, "attack", {"target": goblin})
	await _frames(2)
	check(not ranged_check.ok and "ranged" in ranged_check.reason and not ranged_try.ok and not player.action_used,
		"an attack with a ranged weapon in hand is refused: ranged attacks cannot be made yet", str(ranged_check.reason))
	check(attack_button.disabled and attack_button.get_reason() == "Ranged attacks cannot be made yet" and "Crossbow" in attack_button.get_detail(),
		"the action bar says that the ranged weapon in hand cannot attack yet",
		"%s / %s" % [attack_button.get_detail(), attack_button.get_reason()])
	var bow: Dictionary = inv.unequip_item(stats, "ranged")
	_toughen(stats)
	var punch: Dictionary = {}
	for attempt in range(40):
		player.action_used = false
		blows.clear()
		var swing: Dictionary = controller.request_action(player, "attack", {"target": goblin})
		if swing.ok and swing.hit:
			punch = swing
			break
	check(not punch.is_empty() and punch.weapon_name == "Unarmed strike" and punch.damage == 3 and punch.damage_type == "bludgeoning"
		and blows.size() == 1 and blows[0][3] == combat_mgr.DamageType.BLUDGEONING,
		"with nothing in hand the Attack action is an unarmed strike for 1 + Strength modifier", str(punch.get("damage", "no hit")))
	inv.equip_item(sword, stats, "main_hand")
	inv.equip_item(bow, stats, "ranged")
	_toughen(stats)

	# --- Dash ---
	player.refresh_turn_resources()
	var dash: Dictionary = controller.request_action(player, "dash")
	check(dash.ok and player.action_used and player.movement_left == 12 and player.movement_granted == 12 and dash.movement_added == 6,
		"Dash costs the action and adds the combatant's speed to this turn's movement", "movement %d" % player.movement_left)
	check(not controller.request_action(player, "dash").ok and player.movement_left == 12, "a second Dash in the same turn is refused")

	# --- Disengage, and the opportunity attack it prevents ---
	player.refresh_turn_resources()
	var hp_before_walk: int = stats.current_hp
	var disengage: Dictionary = controller.request_action(player, "disengage")
	var walked_away: bool = await _walk(player, here - step)
	check(disengage.ok and walked_away and reactions.is_empty() and not goblin.reaction_used and stats.current_hp == hp_before_walk,
		"after Disengage, walking out of an enemy's reach provokes no opportunity attack", "%d reactions" % reactions.size())
	check(player.movement_left == 5, "each tile walked costs a tile of this turn's movement", "movement %d" % player.movement_left)
	await _walk(player, here)
	player.refresh_turn_resources()
	walked_away = await _walk(player, here - step)
	check(walked_away and reactions == [goblin] and goblin.reaction_used,
		"without Disengage the same step provokes an opportunity attack, which spends the attacker's reaction", "%d reactions" % reactions.size())
	await _walk(player, here)
	await _walk(player, here - step)
	check(reactions == [goblin], "one reaction a round: no second opportunity attack before the attacker's next turn", "%d reactions" % reactions.size())
	await _walk(player, here)
	player.movement_left = 0
	check(not await _walk(player, here - step) and player.grid_position == here, "a move is refused when the turn's movement is used up")

	# --- Dodge ---
	player.refresh_turn_resources()
	var dodge: Dictionary = controller.request_action(player, "dodge")
	var dex_save: Dictionary = combat_mgr.make_saving_throw(stats, "dex", 10, false, false, player)
	var wis_save: Dictionary = combat_mgr.make_saving_throw(stats, "wis", 10, false, false, player)
	check(dodge.ok and player.action_used and player.is_dodging() and combat_mgr.roll_attack(goblin, player).disadvantage,
		"Dodge costs the action and gives attack rolls against the dodger disadvantage")
	check(dex_save.advantage and not wis_save.advantage, "a dodging combatant makes Dexterity saves, and only those, with advantage")

	# --- the enemy's turn: SPACE ends ours; nothing of ours is approved meanwhile ---
	var spent_before: bool = goblin.reaction_used
	turn_log.clear()
	taken.clear()
	_press(KEY_SPACE)
	await _frames(1)
	check(controller.is_turn_of(goblin) and player.movement_left == 0, "SPACE ends the player's turn and unused movement is lost")
	check(spent_before and turn_log.size() == 1 and turn_log[0] == [goblin, false] and not goblin.reaction_used,
		"the reaction spent on an opportunity attack is back at the start of the combatant's own turn", str(turn_log))
	var enemy_swings: Array = taken.filter(func(entry): return entry[0] == goblin and entry[1] == "attack")
	check(enemy_swings.size() == 1 and enemy_swings[0][2].disadvantage and enemy_swings[0][2].weapon_name == "Enemy Weapon"
		and combat_mgr.roll_attack(goblin, player).disadvantage,
		"an enemy attacks through the same request, at disadvantage while the Dodge lasts", "%d attacks" % enemy_swings.size())
	var count_before: int = int(potions.stack_count)
	notes.clear()
	sheet.show_character(stats)
	sheet._use_inventory_item(inv.items.find(potions))
	sheet.hide_screen()
	check(int(potions.stack_count) == count_before and notes == ["Not your turn"] and not controller.request_action(player, "dodge").ok,
		"an item cannot be used, nor an action taken, on someone else's turn", str(notes))

	# --- our next turn: the Dodge is over ---
	await _until(func(): return controller.is_turn_of(player) or not world.in_combat)
	check(controller.is_turn_of(player) and not player.is_dodging() and not combat_mgr.roll_attack(goblin, player).disadvantage,
		"the Dodge ends at the start of the dodger's next turn")
	controller.request_action(player, "dodge")
	effects.apply_effect(player, "stunned", 1)
	check(not player.is_dodging() and not combat_mgr.roll_attack(goblin, player).disadvantage, "a Dodge ends early when the dodger is incapacitated")
	effects.clear_effects(player)

	# --- Use Item costs the action ---
	player.refresh_turn_resources()
	notes.clear()
	sheet.show_character(stats)
	sheet._use_inventory_item(inv.items.find(potions))
	var after_first: int = int(potions.stack_count)
	var action_after_first: bool = player.action_used
	sheet._use_inventory_item(inv.items.find(potions))
	sheet.hide_screen()
	check(after_first == count_before - 1 and action_after_first, "using a potion in a fight costs the action",
		"%d -> %d" % [count_before, after_first])
	check(int(potions.stack_count) == after_first and notes == ["Action spent"], "a second item in the same turn is refused", str(notes))

	# --- the action bar's keys and buttons ---
	player.refresh_turn_resources()
	_press(KEY_4)
	check(player.action_used and player.movement_left == 12, "key 4 takes the Dash action")
	player.refresh_turn_resources()
	_press(KEY_5)
	check(player.action_used and player.disengaged, "key 5 takes the Disengage action")
	player.refresh_turn_resources()
	_press(KEY_6)
	check(player.action_used and player.is_dodging(), "key 6 takes the Dodge action")
	player.refresh_turn_resources()
	_press(KEY_1)
	await _frames(2)
	check(player.attack_mode and attack_button.button_pressed and "click an adjacent enemy" in bar._hint.text,
		"key 1 starts aiming the Attack action, and the bar shows it", bar._hint.text)
	_press(KEY_1)
	check(not player.attack_mode, "key 1 again puts the attack away")
	_press(KEY_3)
	await _frames(1)
	check(sheet.visible, "key 3, Use Item, opens the pack")
	sheet.hide_screen()
	notes.clear()
	_press(KEY_2)
	await _frames(1)
	check(not ui.is_panel_open() and notes == ["Cast: No spells known"], "key 2, Cast, tells a character without spells that it has none", str(notes))
	bar.get_button("dodge").pressed.emit()
	check(player.action_used and player.is_dodging(), "a button of the action bar takes its action")
	await _frames(2)
	var cast_button = bar.get_button("cast")
	check(bar.get_button("dash").disabled and bar.get_button("dash").get_reason() == "Action spent" and not bar.get_button("end_turn").disabled
		and cast_button.disabled and cast_button.get_reason() == "No spells known" and "Dodging" in bar._state_label.text,
		"the bar disables what cannot be done, with the reason, and leaves End Turn open",
		"dash '%s', end turn '%s', cast '%s', state '%s'" % [bar.get_button("dash").get_reason(), bar.get_button("end_turn").get_reason(),
			cast_button.get_reason(), bar._state_label.text])

	# --- an enemy that moves and then attacks: end-of-turn effects come after the blow ---
	player.refresh_turn_resources()
	player.teleport_to_grid(here - step * 2)
	effects.apply_effect(goblin, "prone", 1)  # disadvantage on its attacks; gone at the end of its turn
	taken.clear()
	_press(KEY_7)
	check(controller.is_turn_of(goblin), "key 7 ends the turn")
	await _frames(2)
	check(bar._turn_label.text == "Goblin's turn" and attack_button.disabled and attack_button.get_reason() == "Not your turn",
		"on an enemy's turn the HUD shows that combatant's resources and the buttons say it is not our turn", bar._turn_label.text)
	await _until(func(): return controller.is_turn_of(player) or not world.in_combat)
	var goblin_turn: Array = taken.filter(func(entry): return entry[0] == goblin)
	check(goblin_turn.size() == 2 and goblin_turn[0][1] == "move" and goblin_turn[1][1] == "attack" and goblin.grid_position == here - step,
		"an enemy's move and its attack are both requests to the controller", "%d requests" % goblin_turn.size())
	check(goblin_turn.size() == 2 and goblin_turn[1][2].disadvantage and not effects.has_effect(goblin, "prone"),
		"an enemy that moves and then attacks runs its end-of-turn effects after the blow, not before")

	# --- a companion's turn is made of requests too, within its movement ---
	comp.rejoin_party("kaelen")
	await _wait(0.3)
	var kaelen = world.companion_nodes.get("kaelen")
	check(kaelen != null and controller.get_order().has(kaelen) and controller.is_turn_of(player), "test setup: a companion joined the fight")
	if kaelen != null:
		kaelen.teleport_to_grid(here + step * 2)
		kaelen.stats.movement_speed = 5  # one tile a turn
		taken.clear()
		controller.request_action(player, "end_turn")
		await _until(func(): return controller.is_turn_of(player) or not world.in_combat)
		var kaelen_turn: Array = taken.filter(func(entry): return entry[0] == kaelen)
		var strayed: Vector2i = kaelen.grid_position - (here + step * 2)
		check(kaelen_turn.size() == 1 and kaelen_turn[0][1] == "move" and kaelen_turn[0][2].steps == 1
			and max(abs(strayed.x), abs(strayed.y)) == 1 and kaelen.movement_left == 0,
			"a companion's move is a request, and stops where its movement for the turn runs out", "%d requests" % kaelen_turn.size())
		kaelen.teleport_to_grid(here)
		var punches: Array = []
		for round_number in range(8):
			taken.clear()
			controller.request_action(player, "end_turn")
			await _until(func(): return controller.is_turn_of(player) or not world.in_combat)
			punches = taken.filter(func(entry): return entry[0] == kaelen and entry[1] == "attack" and entry[2].hit)
			if not punches.is_empty():
				break
		check(not punches.is_empty() and punches[0][2].weapon_name == "Unarmed strike" and punches[0][2].damage_type == "bludgeoning"
			and punches[0][2].damage == max(1, 1 + kaelen.stats.get_str_modifier()),
			"a companion with nothing equipped attacks through the same request, with an unarmed strike")
		comp.dismiss("kaelen")

	# --- the fight ends; outside one nothing is spent ---
	combat_mgr.apply_damage(goblin, 9999, combat_mgr.DamageType.PHYSICAL, player, false)
	await _until(func(): return not world.in_combat, 5.0)
	Engine.time_scale = 1.0
	check(not world.in_combat and not player.action_used and player.movement_left == 0, "test setup: the staged fight is over")
	count_before = int(potions.stack_count)
	sheet.show_character(stats)
	sheet._use_inventory_item(inv.items.find(potions))
	sheet._use_inventory_item(inv.items.find(potions))
	sheet.hide_screen()
	check(int(potions.stack_count) == count_before - 2 and not player.action_used, "outside a fight items are free: two in a row, no action spent")
	var idle_dash: Dictionary = controller.request_action(player, "dash")
	check(not idle_dash.ok and idle_dash.reason == "Not in combat", "Dash, like Attack, Disengage and Dodge, is only taken in a fight", str(idle_dash))
	await _frames(2)
	check(bar._turn_label.text == "Exploring" and not bar._action_label.visible and attack_button.disabled
		and attack_button.get_reason() == "Not in combat" and not bar.get_button("use_item").disabled,
		"outside a fight the bar offers what can still be done: no action economy, items still usable")

	controller.action_taken.disconnect(on_action)
	bus.damage_dealt.disconnect(on_damage)
	bus.reaction_triggered.disconnect(on_reaction)
	controller.turn_started.disconnect(on_turn)
	bus.ui_notification.disconnect(on_note)
	for node in world.ground_items_node.get_children():
		node.queue_free()
	if player.grid_position != home:
		player.teleport_to_grid(home)
	stats.recalculate_derived_stats()  # back to the real maximum
	stats.current_hp = stats.max_hp
	await _frames(2)

func _check_cast_costs(world, target):
	"""On the wizard's own turn, with the action already spent on a cantrip:
	what the other casting times cost"""
	var spells = _mgr("SpellManager")
	var controller = world.combat
	var player = world.player
	var stats = player.stats
	var again: Dictionary = controller.request_action(player, "cast", {"spell_id": "fire_bolt", "target": target})
	check(not again.ok and again.reason == "Action spent" and not again.get("final", false),
		"a second action spell in the same turn is refused", str(again))

	_press(KEY_2)
	await _frames(1)
	check(_mgr("UIManager").is_panel_open("spellbook"), "key 2, Cast, opens a caster's spellbook")
	_mgr("UIManager").close_panel()

	var back: Vector2i = player.grid_position
	var spots: Array = _open_tiles_near(world, back, 2, 4, 1)
	var slots_before: int = spells.get_remaining_slots(stats, 2)
	check(not spots.is_empty() and slots_before > 0 and spells.knows_spell(stats, "misty_step"),
		"test setup: a bonus-action spell to cast and a place to aim it")
	if spots.is_empty():
		return
	var hop: Dictionary = controller.request_action(player, "cast", {"spell_id": "misty_step", "target": spots[0]})
	check(hop.ok and player.bonus_action_used and player.grid_position == spots[0] and spells.get_remaining_slots(stats, 2) == slots_before - 1,
		"a bonus-action spell costs the bonus action, and its teleport moves the caster", str(hop.get("reason", "")))
	var hop_again: Dictionary = controller.request_action(player, "cast", {"spell_id": "misty_step", "target": back})
	check(not hop_again.ok and hop_again.reason == "Bonus action spent" and spells.get_remaining_slots(stats, 2) == slots_before - 1,
		"a second bonus-action spell in the same turn is refused and spends no slot", str(hop_again))
	player.teleport_to_grid(back)

	var first_slots: int = spells.get_remaining_slots(stats, 1)
	var reaction: Dictionary = controller.request_action(player, "cast", {"spell_id": "shield_spell", "target": player})
	check(not reaction.ok and "reaction" in reaction.reason and reaction.get("final", false) and spells.get_remaining_slots(stats, 1) == first_slots
		and _mgr("StatusEffectManager").get_active_effects(player).is_empty(),
		"a reaction spell cannot be cast on the caster's own turn yet", str(reaction))

# ---------------------------------------------------------------------------
#  Turn authority: the combat controller alone decides whose turn it is
# ---------------------------------------------------------------------------

func _check_turn_authority(world):
	"""A staged fight: the wizard and a companion against three goblins. Two of
	the goblins have a DEX that puts them first and second in every initiative
	order, so the checks do not depend on the dice."""
	var combat_mgr = _mgr("CombatManager")
	var effects = _mgr("StatusEffectManager")
	var spells = _mgr("SpellManager")
	var comp = _mgr("CompanionManager")
	var bus = _mgr("EventBus")
	var grid_script = load("res://scripts/combat_grid.gd")
	var teams = load("res://scripts/combatant.gd").Team
	var hostile_team: int = teams.HOSTILE
	var controller = world.combat
	var player = world.player
	var stats = player.stats

	check(controller != null and not controller.active and controller.current_combatant() == null
		and not controller.is_turn_of(player) and player.can_act(),
		"outside combat nobody holds the turn and the player is free to act")

	# No blow may end this fight early
	stats.max_hp = 500
	stats.current_hp = 500
	comp.recruit("brom")
	await _wait(0.3)
	var brom = world.companion_nodes.get("brom")
	var here: Vector2i = player.grid_position
	var beside: Array = _open_tiles_near(world, here, 1, 1, 1)
	var further: Array = _open_tiles_near(world, here, 2, 4, 2)
	check(brom != null and beside.size() == 1 and further.size() == 2, "test setup: room for a staged fight around the player")
	if brom == null or beside.size() != 1 or further.size() != 2:
		return

	# Spawned and set up within one frame: the controller notices them on the next
	var first = world._spawn_enemy("goblin", 1, 500, beside[0])
	var second = world._spawn_enemy("goblin", 1, 500, further[0])
	var third = world._spawn_enemy("goblin", 1, 500, further[1])
	first.stats.dexterity = 1010   # initiative +500
	second.stats.dexterity = 510   # initiative +250

	var cast_count: Array = [0]
	var on_cast = func(_caster, _spell_id, _targets): cast_count[0] += 1
	bus.spell_cast.connect(on_cast)
	var turn_starts: Array = []
	var on_turn = func(combatant): turn_starts.append(combatant.get_instance_id())
	controller.turn_started.connect(on_turn)
	var endings: Array = []
	var on_end = func(victory): endings.append([victory, player.turn_based_mode, world.initiative_tracker.visible])
	controller.combat_ended.connect(on_end)

	var waited := 0.0
	while not world.in_combat and waited < 3.0:
		await _wait(0.02)
		waited += 0.02
	check(world.in_combat and controller.active, "test setup: the staged fight started")
	if not world.in_combat:
		return

	var order: Array = controller.get_order()
	for combatant in order:
		if combatant.team == hostile_team:
			combatant.stats.max_hp = 500
			combatant.stats.current_hp = 500
	check(order.has(player) and order.has(brom) and order.has(first) and order.has(second) and order.has(third),
		"a recruited companion is in the initiative order, with the player and every enemy near enough",
		"%d in the order" % order.size())
	var sorted_by_roll := true
	for i in range(1, order.size()):
		if controller.get_initiative(order[i - 1]) < controller.get_initiative(order[i]):
			sorted_by_roll = false
	check(order[0] == first and order[1] == second and sorted_by_roll,
		"the order runs from the highest initiative roll to the lowest")
	check(controller.current_combatant() == first and controller.is_turn_of(first) and not controller.is_turn_of(player)
		and not controller.is_turn_of(brom) and controller.round_number == 1 and turn_starts == [first.get_instance_id()],
		"the fight opens with the first combatant's turn, and nobody else's")
	check(world.initiative_tracker.visible and world.turn_ui.current_turn_type == "enemy" and player.turn_based_mode,
		"the initiative bar and the turn banner show the controller's fight")

	# --- an enemy holds the turn: the player can do nothing ---
	var enemy_hp: int = first.stats.current_hp
	player.action_used = false  # a gate on the action alone would let everything through
	check(not player.can_act(), "the player may not act on an enemy's turn")
	var refused: Dictionary = controller.request_action(player, "attack", {"target": first})
	check(not refused.ok and refused.reason == "Not your turn" and not player.action_used,
		"the player's attack is refused during an enemy's turn", str(refused))

	spells.set_pending_cast(player, "fire_bolt")
	player._handle_pending_spell_click(first.grid_position)
	check(cast_count[0] == 0 and spells.get_pending_cast(player) == "fire_bolt" and not player.action_used,
		"the player's spell cast is refused during an enemy's turn")
	spells.clear_pending_cast(player)

	var step: Array = _open_tiles_near(world, here, 1, 1, 1)
	player.movement_left = 6  # even with movement in hand
	if not step.is_empty():
		player.show_path_preview(step[0])
		player.execute_move()
	check(not step.is_empty() and not player.is_moving and player.grid_position == here,
		"the player's move is refused during an enemy's turn")
	player.cancel_preview()
	player.movement_left = 0

	effects.apply_effect(player, "blessed", 5)
	var turn_before: int = player.turn_number
	_press(KEY_SPACE)
	await _frames(2)
	var blessing: Array = effects.get_active_effects(player)
	check(controller.current_combatant() == first and player.turn_number == turn_before
		and blessing.size() == 1 and int(blessing[0].duration_remaining) == 5,
		"SPACE during an enemy's turn does nothing: no turn ends and no effect ticks down")
	world.bottom_ui.action_bar._on_action_pressed("end_turn")
	world.bottom_ui.action_bar._on_action_pressed("attack")
	world.bottom_ui.action_bar._on_action_pressed("dodge")
	check(controller.current_combatant() == first and not player.attack_mode and not player.action_used and not player.dodging,
		"the action bar's buttons do nothing during an enemy's turn")
	effects.clear_effects(player)
	await _wait(0.3)  # an attack that had gone through would have landed by now
	check(first.stats.current_hp == enemy_hp and controller.current_combatant() == first,
		"no blow from the player lands during the enemy's turn")

	# --- the player's own turn ---
	Engine.time_scale = 4.0
	waited = 0.0
	while world.in_combat and not controller.is_turn_of(player) and waited < 15.0:
		await _wait(0.02)
		waited += 0.02
	check(controller.is_turn_of(player) and player.can_act(), "the player's turn comes round")
	if not controller.is_turn_of(player):
		Engine.time_scale = 1.0
		return

	# The second goblin sits before the player in the order: taking it out moves
	# every later index, and must not move the turn
	combat_mgr.apply_damage(second, 9999, combat_mgr.DamageType.PHYSICAL, player, false)
	check(controller.is_turn_of(player) and not controller.get_order().has(second),
		"removing a dead combatant from the order does not change whose turn it is")

	comp.recruit("whisper")
	await _wait(0.3)
	var whisper = world.companion_nodes.get("whisper")
	check(whisper != null and controller.get_order().has(whisper) and controller.is_turn_of(player),
		"a companion recruited mid-fight joins the order without taking the turn")
	comp.dismiss("whisper")
	comp.dismiss("brom")
	var party_left: Array = controller.get_order().filter(func(combatant): return combatant.team == teams.PARTY)
	check(party_left == [player] and controller.get_order().size() >= 3 and controller.is_turn_of(player),
		"a companion who leaves mid-fight leaves the order without moving the turn")
	await _frames(2)

	var target = null
	for combatant in controller.get_order():
		if combatant.team == hostile_team and grid_script.has_line_of_sight(
				player.grid_position, combatant.grid_position, world.current_dungeon.dungeon_grid):
			target = combatant
	if target != null:
		spells.set_pending_cast(player, "fire_bolt")
		player._handle_pending_spell_click(target.grid_position)
	check(target != null and cast_count[0] == 1 and player.action_used and not player.bonus_action_used and spells.get_pending_cast(player) == "",
		"on the player's own turn the same spell is cast, and costs the action its casting time names")
	await _check_cast_costs(world, target)

	step = _open_tiles_near(world, player.grid_position, 1, 1, 1)
	if not step.is_empty():
		player.show_path_preview(step[0])
		player.execute_move()
	check(not step.is_empty() and player.is_moving, "on the player's own turn the same move is made")
	waited = 0.0
	while player.is_moving and waited < 3.0:
		await _wait(0.02)
		waited += 0.02

	# --- a combatant that dies on its own turn ---
	# The first goblin burns to death as its next turn starts. The turn must pass
	# to whoever follows it in the order; the old loop skipped that combatant.
	first.stats.current_hp = 1
	effects.apply_effect(first, "burning", 5)
	order = controller.get_order()
	var doomed_id: int = first.get_instance_id()
	var successor_id: int = order[1].get_instance_id()
	var after_player_id: int = order[(order.find(player) + 1) % order.size()].get_instance_id()
	var round_before: int = controller.round_number
	check(order[0] == first and order.size() >= 3, "test setup: the doomed goblin is first of at least three in the order",
		"%d in the order" % order.size())
	turn_starts.clear()
	player.end_turn()
	check(turn_starts.size() == 1 and turn_starts[0] == after_player_id and not controller.is_turn_of(player),
		"ending the turn passes it to the next combatant in the order, after all the comings and goings")
	waited = 0.0
	while world.in_combat and waited < 30.0 and (not doomed_id in turn_starts or turn_starts.find(doomed_id) == turn_starts.size() - 1):
		await _wait(0.02)
		waited += 0.02
	var after_doomed: int = turn_starts.find(doomed_id) + 1
	check(after_doomed > 0 and (not is_instance_valid(first) or not first.is_alive()), "test setup: the goblin died on its own turn")
	check(after_doomed > 0 and after_doomed < turn_starts.size() and turn_starts[after_doomed] == successor_id,
		"a combatant that dies on its own turn does not make the next one skip its turn")
	check(controller.round_number == round_before + 1, "the round count goes up by one when the order wraps",
		"%d -> %d" % [round_before, controller.round_number])

	# --- the last hostile falls ---
	check(world.in_combat and endings.is_empty(), "the fight goes on while a hostile combatant is alive")
	for combatant in controller.get_order():
		if combatant.team == hostile_team:
			combat_mgr.apply_damage(combatant, 9999, combat_mgr.DamageType.PHYSICAL, player, false)
	waited = 0.0
	while endings.is_empty() and waited < 5.0:
		await _wait(0.02)
		waited += 0.02
	Engine.time_scale = 1.0
	check(endings.size() == 1 and endings[0] == [true, false, false] and controller.current_combatant() == null,
		"combat ends, as a victory, when no hostile combatant is left alive", str(endings))

	bus.spell_cast.disconnect(on_cast)
	controller.turn_started.disconnect(on_turn)
	controller.combat_ended.disconnect(on_end)

# ---------------------------------------------------------------------------
#  Casters: starting spells and spells gained on level-up
# ---------------------------------------------------------------------------

func _check_casters(world):
	var spells = _mgr("SpellManager")
	var spell_db = _mgr("SpellDatabase")
	var inv = _mgr("InventoryManager")
	var builder = load("res://data/stats/character_builder.gd")

	var cleric = builder.build("cleric", "human", {"str": 12, "dex": 10, "con": 14, "int": 10, "wis": 16, "cha": 12}, "Smoke Cleric")
	var cleric_spells: Array = spells.get_known_spells(cleric)
	check("sacred_flame" in cleric_spells and not "light" in cleric_spells,
		"cleric starts with a damage cantrip rather than Light", str(cleric_spells.slice(0, 4)))

	var wizard = builder.build("wizard", "elf", {"str": 8, "dex": 14, "con": 12, "int": 16, "wis": 12, "cha": 10}, "Smoke Wizard")
	check(wizard.movement_speed == 30 and wizard.get_modified_movement_speed() == 6, "a built character's speed is 30 ft / 6 tiles")
	world.player.stats = wizard
	inv.set_party_members([wizard])
	var known: Array = spells.get_known_spells(wizard)
	check("fire_bolt" in known and not "eldritch_blast" in known, "wizard starts with Fire Bolt and without Eldritch Blast", str(known.slice(0, 4)))

	wizard.gain_experience(900)  # level 3: second-level slots open
	check(wizard.level == 3, "test setup: wizard reached level 3", str(wizard.level))
	var has_second := false
	for spell_id in spells.get_known_spells(wizard):
		if int(spell_db.get_spell(spell_id).get("level", 0)) == 2:
			has_second = true
	check(spells.get_max_slots(wizard, 2) > 0 and has_second, "levelling up grants spells for the new spell level")

# ---------------------------------------------------------------------------
#  The game as a player meets it: menu, new game, save, load, death, old saves
# ---------------------------------------------------------------------------

func _check_game_flow():
	var game = _mgr("GameManager")
	var saves = _mgr("SaveManager")
	var inv = _mgr("InventoryManager")
	var quests = _mgr("QuestManager")
	var comp = _mgr("CompanionManager")
	var effects = _mgr("StatusEffectManager")
	var spells = _mgr("SpellManager")
	var combat = _mgr("CombatManager")
	var items = _mgr("ItemDatabase")
	var ui = _mgr("UIManager")

	# --- main menu, no saves yet ---
	game.go_to_main_menu()
	await _wait(0.5)
	var menu = current_scene
	check(menu != null and menu.name == "MainMenu", "the main menu opens")
	if menu == null or menu.name != "MainMenu":
		return
	check(menu.get_node("%ContinueButton").disabled and menu.get_node("%LoadButton").disabled,
		"Continue and Load are disabled when there is no save")
	check(_world() == null and not paused and inv.items.is_empty() and inv.gold == inv.STARTING_GOLD
		and quests.quest_states.is_empty() and comp.get_party().is_empty() and spells.known_spells.is_empty(),
		"returning to the menu wipes the previous game's state")

	# --- New Game -> character creation ---
	menu.get_node("%NewGameButton").pressed.emit()
	await _wait(0.5)
	var creation = current_scene
	check(creation != null and creation.name == "CharacterCreationScreen", "New Game opens character creation")
	if creation == null or creation.name != "CharacterCreationScreen":
		return
	var panel = creation.panel
	check(panel.get_global_rect().is_equal_approx(Rect2(Vector2.ZERO, root.get_visible_rect().size)),
		"the creation panel fills the screen", str(panel.get_global_rect()))
	panel._name_edit.text = "Smoke Tester"
	panel._class_list.select(panel._class_ids.find("wizard"))
	panel._on_class_selected(0)
	panel._race_list.select(panel._race_ids.find("elf"))
	panel._on_race_selected(0)
	check(panel._skill_pick_count() == 2 and panel._get_chosen_skills().size() == 2,
		"creation offers the class's skill choices with a valid default")
	panel._skill_list.deselect_all()
	panel._on_confirm_pressed()
	await _frames(2)
	check(current_scene == creation, "creation refuses to confirm with the wrong number of skills")
	var skill_count: int = panel._skill_ids.size()
	panel._skill_list.select(skill_count - 1, false)
	panel._skill_list.select(skill_count - 2, false)
	var chosen: Array = panel._get_chosen_skills()
	panel._on_confirm_pressed()
	await _wait(1.0)

	var world = _world()
	check(world != null, "confirming creation starts the game")
	if world == null:
		return
	var stats = world.player.stats
	check(stats.character_name == "Smoke Tester" and stats.class_id == "wizard" and stats.race_id == "elf",
		"the game starts with the created character", "%s / %s / %s" % [stats.character_name, stats.class_id, stats.race_id])
	check(chosen.size() == 2 and chosen[0] in stats.skill_proficiencies and chosen[1] in stats.skill_proficiencies,
		"the chosen skills are the character's skills", str(stats.skill_proficiencies))
	check(not inv.get_equipped_item(stats, "main_hand").is_empty(), "the new character's starting kit is equipped")
	check("fire_bolt" in spells.get_known_spells(stats), "a new wizard knows spells")
	check(world.enemies.size() >= 1 and world.current_dungeon.is_floor_tile(world.player.grid_position),
		"the new game has enemies and the player stands on floor")
	await _frames(4)
	check(saves.save_exists(saves.AUTOSAVE_SLOT), "starting a new game writes the autosave")

	# --- change the world, save it ---
	var seed_saved: int = world.current_dungeon.dungeon_seed
	var grid_saved: int = _grid_hash(world)
	var spot: Vector2i = _free_floor_near(world, world.player.grid_position, 4)
	world.player.teleport_to_grid(spot)
	await _frames(4)  # the minimap explores around the new position
	var victim = world.enemies[0]
	victim.stats.current_hp = max(1, victim.stats.current_hp - 3)
	var ground_script = load("res://scripts/ground_item.gd")
	ground_script.spawn(world.ground_items_node, spot + Vector2i(1, 0), world.player.tile_size,
		[items.create_item_instance("iron_dagger")], 7)
	inv.gold += 123
	quests.start_quest("mq_01_strange_tidings")
	comp.recruit("kaelen")
	await _wait(0.3)
	world.companion_nodes["kaelen"].stats.current_hp = 5
	stats.current_hp = max(1, stats.max_hp - 2)
	var expected := {
		"pos": world.player.grid_position,
		"hp": stats.current_hp,
		"gold": inv.gold,
		"enemies": _enemy_summary(world),
		"explored": world.minimap.explored_tiles.size(),
		"bag": inv.items.size(),
	}
	check(expected.explored > 0, "test setup: some of the map is explored")
	check(saves.save_game(TEST_SLOT), "the game saves to a slot")

	# --- change it further, then load: the save must win ---
	inv.gold += 999
	world.player.teleport_to_grid(_free_floor_near(world, spot, 7))
	victim.stats.current_hp = 1
	effects.apply_effect(world.player, "blessed", 5)
	inv.add_item(items.create_item_instance("iron_dagger"))
	check(game.load_game(TEST_SLOT), "the save loads")
	await _wait(1.0)
	world = _world()
	check(world != null and world.player != null, "loading starts a fresh world")
	if world == null:
		return
	stats = world.player.stats
	check(world.current_dungeon.dungeon_seed == seed_saved and _grid_hash(world) == grid_saved,
		"the loaded dungeon is the same dungeon", "seed %d vs %d" % [world.current_dungeon.dungeon_seed, seed_saved])
	check(world.player.grid_position == expected.pos, "the player is where they saved", str(world.player.grid_position))
	check(stats.character_name == "Smoke Tester" and stats.current_hp == expected.hp, "the character and their HP are restored",
		"%s %d" % [stats.character_name, stats.current_hp])
	check(inv.gold == expected.gold and inv.items.size() == expected.bag, "gold and bag are as saved, not as left",
		"gold %d bag %d" % [inv.gold, inv.items.size()])
	check(not inv.get_equipped_item(stats, "main_hand").is_empty(), "equipment is restored")
	check(_enemy_summary(world) == expected.enemies, "the enemies are the same ones, with the same wounds",
		"%s vs %s" % [str(_enemy_summary(world)), str(expected.enemies)])
	var drop_ok := false
	for drop in world.ground_items_node.get_children():
		if drop.grid_pos == expected.pos + Vector2i(1, 0) and drop.gold == 7 and drop.item_instances.size() == 1:
			drop_ok = true
	check(drop_ok, "loot on the ground is still there")
	check(world.minimap.explored_tiles.size() == expected.explored, "the explored map is restored",
		"%d vs %d" % [world.minimap.explored_tiles.size(), expected.explored])
	check(quests.get_quest_status("mq_01_strange_tidings") == "active", "quest progress is restored")
	check("kaelen" in comp.get_party() and world.companion_nodes.has("kaelen")
		and world.companion_nodes["kaelen"].stats.current_hp == 5, "the companion is back with their saved HP")
	check(effects.get_active_effects(world.player).is_empty(), "status effects from before the load are gone")
	check("fire_bolt" in spells.get_known_spells(stats), "known spells are restored")

	# --- no saving in combat ---
	var enemy = world.enemies[0]
	world.player.stats.max_hp = 500  # the enemy's first blow must not end this fight before the checks
	world.player.stats.current_hp = 500
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if world.player.is_walkable(enemy.grid_position + offset):
			world.player.teleport_to_grid(enemy.grid_position + offset)
			break
	await _wait(0.5)
	check(world.in_combat, "test setup: combat started")
	check(saves.can_save() != "" and not saves.save_game(TEST_SLOT + 1) and not saves.save_exists(TEST_SLOT + 1),
		"saving is refused during combat")

	# --- death leads to a screen with a way back ---
	combat.apply_damage(world.player, 9999, combat.DamageType.PHYSICAL, enemy, false)
	await _frames(4)
	check(game.is_game_over and is_instance_valid(world.player) and not world.in_combat,
		"death ends the fight and keeps the world intact")
	check(world._game_over_screen != null and is_instance_valid(world._game_over_screen) and paused,
		"the game-over screen is shown")
	check(saves.can_save() != "", "saving is refused after death")
	if world._game_over_screen != null and is_instance_valid(world._game_over_screen):
		check(not world._game_over_screen.get_node("%LoadButton").disabled, "game over offers the last save")
		world._game_over_screen.get_node("%LoadButton").pressed.emit()
	await _wait(1.0)
	world = _world()
	check(world != null and not game.is_game_over and not paused and world.player.stats.is_alive()
		and world.player.stats.current_hp == expected.hp, "loading from game over brings the character back")
	if world == null:
		return

	# --- pause menu on ESC ---
	_press(KEY_ESCAPE)
	await _frames(3)
	check(ui.is_panel_open("pause_menu") and paused, "ESC opens the pause menu and pauses")
	_press(KEY_ESCAPE)
	await _frames(3)
	check(not ui.is_panel_open() and not paused, "ESC closes the pause menu again")
	world.player.attack_mode = true
	world.player.turn_based_mode = true
	_press(KEY_ESCAPE)
	await _frames(3)
	check(not world.player.attack_mode and not ui.is_panel_open(), "ESC cancels a selected attack without opening the menu")
	world.player.turn_based_mode = false

	# --- older save formats ---
	var raw: Dictionary = saves._read_save_data(TEST_SLOT)
	var v2: Dictionary = raw.duplicate(true)
	v2.erase("world")
	v2["version"] = 2
	_write_raw_save(saves, 5, v2)
	_write_raw_save(saves, 6, {"version": "0.1.0", "timestamp": 1000, "position_x": 5, "position_y": 5,
		"hp": 7, "max_hp": 12, "gold": 77, "player_level": 1})
	_write_raw_save(saves, 7, {"version": 99, "timestamp": 2000})

	var migrated: Dictionary = saves.read_save(5)
	check(int(migrated.get("version", 0)) == saves.SAVE_FORMAT_VERSION and migrated.get("world") is Dictionary
		and int(migrated.get("migrated_from", 0)) == 2, "a format-2 save is migrated on read")
	check(int(saves.get_save_info(6).get("gold", -1)) == 77, "a format-1 save is readable in the slot list")
	check(saves.read_save(7).is_empty() and not game.load_game(7) and _world() == world,
		"a save from a newer version is refused and nothing changes")

	check(game.load_game(5), "a format-2 save loads")
	await _wait(1.0)
	world = _world()
	check(world != null and world.current_dungeon.is_floor_tile(world.player.grid_position) and world.enemies.size() >= 1
		and world.player.stats.character_name == "Smoke Tester" and inv.gold == expected.gold,
		"a format-2 save gets a new dungeon with the player at its entrance")

	check(game.load_game(6), "a format-1 save loads")
	await _wait(1.0)
	world = _world()
	check(world != null and world.current_dungeon.is_floor_tile(world.player.grid_position) and inv.gold == 77
		and world.player.stats.class_id == "fighter" and not inv.get_equipped_item(world.player.stats, "main_hand").is_empty(),
		"a format-1 save keeps its gold and gets a default character")

	# --- back at the menu, Continue is on offer ---
	game.go_to_main_menu()
	await _wait(0.5)
	menu = current_scene
	check(menu != null and menu.name == "MainMenu" and not menu.get_node("%ContinueButton").disabled,
		"with a save present the main menu offers Continue")
	if menu == null or menu.name != "MainMenu":
		return

	# --- Load Game from the menu, through the slot list a player clicks ---
	menu.get_node("%LoadButton").pressed.emit()
	await _frames(3)
	var slot_list = menu._load_menu
	check(slot_list.visible, "Load Game opens the slot list")
	var slot_button: Button = null
	var has_autosave_row := false
	for child in slot_list.slots_container.get_children():
		if child is Button and not child.is_queued_for_deletion():
			if child.text.begins_with("Slot %d " % (TEST_SLOT + 1)) and not child.disabled:
				slot_button = child
			if child.text.begins_with("Autosave"):
				has_autosave_row = true
	check(has_autosave_row, "the slot list shows the autosave when loading")
	check(slot_button != null and "Smoke Tester" in slot_button.text, "a used slot names its character",
		slot_button.text if slot_button else "no button")
	if slot_button != null:
		slot_button.pressed.emit()
		await _wait(1.0)
		world = _world()
		check(world != null and not paused and world.player.stats.character_name == "Smoke Tester",
			"clicking a slot in the menu loads that game")

func _write_raw_save(saves, slot: int, data: Dictionary):
	"""Write a payload exactly as given (used to fake older save formats)"""
	var file := FileAccess.open(saves._get_save_path(slot), FileAccess.WRITE)
	file.store_var(data)
	file.close()
