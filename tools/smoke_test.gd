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
#   - a material sets how an item wears and what it costs and nothing else,
#     and ids written with the old materials still resolve,
#   - all damage goes through one pipeline: resistance, vulnerability and
#     immunity apply to weapons, spells and status effects alike, and its
#     hooks can change the outcome (Relentless Endurance),
#   - armour class follows 5e: body armour, Dexterity as it allows, shield,
#     bonuses, and nothing from any other slot,
#   - a character has two weapon sets and attacks with the one in hand;
#     swapping them, equipping and unequipping are requests,
#   - a ranged attack follows range, line of sight and cover (the 5e corner
#     rule: none down an open corridor, half past a corner), and the chance to
#     hit that is shown is the exact one,
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
	await _check_weapon_sets(world)
	_check_materials(world)
	await _check_armor_class(world)
	await _check_damage(world)
	await _check_art(world)
	_check_crafting(world)
	await _check_companions(world)
	_check_loot_safety(world)
	_check_scroll_use(world)
	_check_class_data()
	_check_cover()
	_check_content()
	await _check_fight(world)
	await _check_actions(world)
	await _check_ranged(world)
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

	# The action bar: eight actions in key order, centred in the bottom bar,
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
	check(titles == ["Attack", "Cast", "Use Item", "Dash", "Disengage", "Dodge", "Swap", "End Turn"] and in_order,
		"the action bar shows its eight actions in key order, in one row inside the bottom bar", str(titles))
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

func _click(screen_pos: Vector2):
	"""Send a real left click, press and release, through the viewport"""
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen_pos
		event.global_position = screen_pos
		root.push_input(event, true)  # already in the viewport's own coordinates

func _move_pointer(screen_pos: Vector2):
	"""Move the mouse pointer to a point of the 1920x1080 screen, as the engine
	sees it. The engine keeps the pointer in the window's own pixels."""
	var event := InputEventMouseMotion.new()
	event.position = root.get_screen_transform() * screen_pos
	event.global_position = event.position
	Input.parse_input_event(event)

func _on_screen(node) -> Vector2:
	"""Where a node of the map is on the screen"""
	return node.get_global_transform_with_canvas().origin

func _camera_at_rest(node) -> bool:
	"""Wait until the camera has stopped gliding: a node of the map stays where
	it is on the screen for a tenth of a second. False when it never does."""
	var last: Vector2 = _on_screen(node)
	for sample in range(50):
		await _wait(0.1)
		var now: Vector2 = _on_screen(node)
		if now.distance_to(last) < 0.01:
			return true
		last = now
	return false

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
	check(stats.armor_class == 18 and stats.armor_name == "Wrought Iron Chain Mail" and stats.shield_name == "Wrought Iron Shield",
		"the starting kit gives the fighter chain mail and a shield: armour class 18", "AC %d" % stats.armor_class)
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

	var sword: Dictionary = items.create_item_instance("wrought_iron_longsword")
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
	check(not comp.give_gift("lyra", items.create_item_instance("wrought_iron_dagger")) and comp.get_relationship("lyra") == before + comp.GIFT_DELTA_LIKED,
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
		[items.create_item_instance("wrought_iron_longsword")], 0)
	drop.pickup()
	check(is_instance_valid(drop) and not drop.is_queued_for_deletion() and drop.item_instances.size() == 1,
		"loot the bag refuses stays on the ground")

	var children_before: int = world.ground_items_node.get_child_count()
	var went_in: bool = inv.add_item_or_drop(items.create_item_instance("wrought_iron_dagger"))
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
		[items.create_item_instance("wrought_iron_dagger")], 5)
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
		and items.items["wrought_iron_plate_boots"].icon != items.items["pigskin_boots"].icon,
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
	kit: longsword and shield in weapon set one, a light crossbow in set two"""
	var combat = _mgr("CombatManager")
	var inv = _mgr("InventoryManager")
	var items = _mgr("ItemDatabase")
	var player = world.player
	var stats = player.stats
	var longsword: Dictionary = inv.get_equipped_item(stats, "main_hand")
	var shield: Dictionary = inv.get_equipped_item(stats, "off_hand")
	var crossbow: Dictionary = inv.get_equipped_item(stats, "main_hand_2")
	check(stats.class_id == "fighter" and stats.get_str_modifier() == 2 and stats.get_dex_modifier() == 1 and stats.proficiency_bonus == 2
		and not longsword.is_empty() and longsword.item_data.item_id == "longsword" and not shield.is_empty() and not crossbow.is_empty(),
		"test setup: the fighter holds a longsword and a shield and carries a crossbow in its second weapon set")
	if longsword.is_empty() or shield.is_empty() or crossbow.is_empty():
		return

	# --- the equipped weapon's die and damage type; versatile with a shield ---
	var profile: Dictionary = combat.get_attack_profile(player)
	check(profile.weapon == longsword.item_data and profile.weapon_name == "Wrought Iron Longsword" and profile.damage_dice == "1d8"
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

	# --- the piece's own bonus: the higher of craftsmanship and magic to hit, magic to damage ---
	var honed: Array = []
	for pair in [[1, 0], [0, 1], [1, 2], [3, 1]]:
		longsword["quality_modifier"] = pair[0]
		longsword["magic_modifier"] = pair[1]
		var bonus_profile: Dictionary = combat.get_attack_profile(player)
		honed.append("%s: +%d, %s, %s" % [bonus_profile.weapon_name, bonus_profile.attack_bonus, combat.get_damage_text(bonus_profile),
			str(_damage_range(combat, bonus_profile))])
	longsword["quality_modifier"] = 0
	longsword["magic_modifier"] = 0
	longsword.item_data.magic_modifier = 3
	longsword.item_data.quality_modifier = 3
	var template_profile: Dictionary = combat.get_attack_profile(player)
	longsword.item_data.magic_modifier = 0
	longsword.item_data.quality_modifier = 0
	check(honed == ["Wrought Iron Longsword +1: +5, 1d8+2 slashing, [3, 10]", "Wrought Iron Longsword +1: +5, 1d8+3 slashing, [4, 11]",
		"Wrought Iron Longsword +2: +6, 1d8+4 slashing, [5, 12]", "Wrought Iron Longsword +3: +7, 1d8+3 slashing, [4, 11]"]
		and template_profile.attack_bonus == 4 and template_profile.weapon_name == "Wrought Iron Longsword",
		"a weapon adds the higher of its own craftsmanship and magic bonus to the attack roll and its magic bonus to the damage, read from the piece",
		str(honed))

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
	check(profile.weapon_name == "Wrought Iron Rapier" and profile.ability == "str" and profile.ability_modifier == 2,
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

	# --- the second weapon set: a ranged weapon in hand, then nothing in hand ---
	inv.swap_weapon_set(stats)
	profile = combat.get_attack_profile(player)
	check(profile.weapon == crossbow.item_data and profile.weapon_name == "Oak Light Crossbow" and profile.is_ranged and profile.usable
		and profile.ability == "dex" and profile.ability_modifier == 1 and profile.attack_bonus == 3 and _damage_range(combat, profile) == [2, 9],
		"with the second weapon set in hand its ranged weapon is the weapon in hand, and it attacks with Dexterity",
		"%s %s %+d, damage %s" % [profile.weapon_name, profile.ability, profile.attack_bonus, str(_damage_range(combat, profile))])
	var ranges: Array = []
	for item_id in ["shortbow", "longbow", "light_crossbow", "heavy_crossbow"]:
		var reach: Dictionary = combat.get_weapon_range(items.get_item(item_id))
		ranges.append("%s %d/%d" % [item_id, reach.normal, reach.max])
	check(ranges == ["shortbow 16/64", "longbow 30/120", "light_crossbow 16/64", "heavy_crossbow 20/80"]
		and combat.get_weapon_range(longsword.item_data) == {"normal": 0, "max": 0},
		"ranged weapons say how far they shoot, in tiles: a normal range and a maximum", str(ranges))
	inv.equipped_items[stats]["off_hand_2"] = shield  # a state the equip rules never produce
	profile = combat.get_attack_profile(player)
	check(not profile.usable and "both hands" in profile.reason, "a two-handed ranged weapon beside a full off hand cannot be fired, and says why", profile.reason)
	inv.equipped_items[stats].erase("off_hand_2")
	inv.unequip_item(stats, "main_hand_2")
	profile = combat.get_attack_profile(player)
	check(profile.weapon == null and profile.weapon_name == "Unarmed strike" and profile.damage_type == "bludgeoning" and profile.proficient
		and profile.attack_bonus == 4 and profile.usable and _damage_range(combat, profile) == [3, 3] and _damage_range(combat, profile, true) == [3, 3],
		"with no weapon the attack is an unarmed strike: 1 + Strength modifier bludgeoning, proficient",
		"%s %s %s" % [profile.weapon_name, str(_damage_range(combat, profile)), profile.damage_type])

	# --- a bow or crossbow cannot share a set with a shield, either way round ---
	inv.equip_item(shield, stats, "off_hand_2")
	var bow_refused: bool = not inv.equip_item(crossbow, stats, "main_hand_2")
	inv.unequip_item(stats, "off_hand_2")
	inv.equip_item(crossbow, stats, "main_hand_2")
	var shield_refused: bool = not inv.equip_item(shield, stats, "off_hand_2")
	check(bow_refused and shield_refused and inv.get_equipped_item(stats, "main_hand_2") == crossbow
		and inv.get_equipped_item(stats, "off_hand_2").is_empty() and "both hands" in inv.get_equip_refusal(shield, stats, "off_hand_2"),
		"a crossbow cannot be equipped in a weapon set whose off hand holds a shield, nor a shield beside a crossbow")
	inv.swap_weapon_set(stats)

	# Back to the starting kit
	inv.equip_item(longsword, stats, "main_hand")
	inv.equip_item(shield, stats, "off_hand")
	inv.remove_item(greatsword.instance_id)
	inv.remove_item(rapier.instance_id)
	stats.current_hp = stats.max_hp
	check(inv.get_equipped_item(stats, "main_hand") == longsword and inv.get_equipped_item(stats, "off_hand") == shield
		and inv.get_equipped_item(stats, "main_hand_2") == crossbow and player.get_weapon_set() == 1,
		"test teardown: the starting kit is back in place")

# ---------------------------------------------------------------------------
#  Materials: durability data, a price and a trait - and nothing else
# ---------------------------------------------------------------------------

# Stage one, as agreed with Ákos:
# [id, kind, durability score, hardness, notches, price multiplier, trait]
const STAGE_ONE_MATERIALS := [
	["copper", "metal", 13, 3, 2, 0.5, ""],
	["wrought_iron", "metal", 18, 3, 2, 0.7, "rusts_easily"],
	["bronze", "metal", 22, 4, 3, 0.8, "resists_corrosion"],
	["steel", "metal", 30, 5, 4, 1.0, ""],
	["silver", "metal", 22, 4, 3, 2.0, "silvered"],
	["damascus_steel", "metal", 38, 6, 5, 3.0, "counts_as_magical"],
	["pine", "wood", 15, 2, 2, 0.4, ""],
	["oak", "wood", 19, 3, 2, 0.7, ""],
	["ash", "wood", 19, 3, 2, 0.7, "resists_cracking"],
	["maple", "wood", 18, 2, 2, 0.6, ""],
	["hickory", "wood", 20, 4, 3, 0.8, "resists_cracking"],
	["ironwood", "wood", 30, 5, 4, 5.0, ""],
	["pigskin", "leather", 10, 2, 2, 0.3, ""],
	["deerskin", "leather", 14, 2, 2, 0.5, "quiet"],
	["cowhide", "leather", 15, 3, 2, 1.0, ""],
	["boiled_leather", "leather", 16, 3, 2, 0.7, ""],
	["wolfhide", "leather", 15, 3, 2, 0.8, "warm"],
	["bearhide", "leather", 18, 3, 2, 0.9, "warm"],
	["burlap", "cloth", 6, 1, 2, 0.16, "noisy"],
	["roughspun_wool", "cloth", 8, 1, 2, 0.48, "warm"],
	["cotton", "cloth", 9, 1, 2, 0.6, "soaks_water"],
	["wool", "cloth", 11, 2, 2, 0.95, "warm"],
	["fine_linen", "cloth", 12, 2, 2, 1.0, ""],
	["silk", "cloth", 15, 2, 2, 12.74, ""],
]

# Item ids as saves and content wrote them before the material list changed,
# and the id each must resolve to: one for every material of the old list
const OLD_ITEM_IDS := [
	["iron_longsword", "wrought_iron_longsword"], ["mithril_dagger", "mythril_dagger"],
	["adamantine_helmet", "adamantite_helmet"], ["hide_boots", "pigskin_boots"],
	["leather_jerkin", "cowhide_jerkin"], ["leather_leather_cap", "cowhide_leather_cap"],
	["linen_robe", "fine_linen_robe"],
	["material_iron", "material_wrought_iron"], ["material_mithril", "material_mythril"],
	["material_adamantine", "material_adamantite"], ["material_hide", "material_pigskin"],
	["material_leather", "material_cowhide"], ["material_linen", "material_fine_linen"],
	["bronze_mace", "bronze_mace"], ["steel_longsword", "steel_longsword"],
	["oak_club", "oak_club"], ["ash_quarterstaff", "ash_quarterstaff"], ["yew_shortbow", "yew_shortbow"],
	["ebony_club", "ebony_club"], ["starwood_longbow", "starwood_longbow"],
	["scaled_leather_gloves", "scaled_leather_gloves"], ["wyvern_leather_boots", "wyvern_leather_boots"],
	["dragon_leather_jerkin", "dragon_leather_jerkin"], ["cotton_pants", "cotton_pants"],
	["silk_slippers", "silk_slippers"], ["spidersilk_hood", "spidersilk_hood"],
	["celestial_cloth_robe", "celestial_cloth_robe"],
	["longsword", "longsword"], ["leather_cap", "leather_cap"], ["leather_armor", "leather_armor"],
]

func _check_materials(world):
	var items = _mgr("ItemDatabase")
	var inv = _mgr("InventoryManager")
	var combat = _mgr("CombatManager")
	var loot = _mgr("LootManager")
	var recipes = _mgr("RecipeDatabase")
	var classes = _mgr("ClassDatabase")
	var material_script = load("res://data/materials/material_data.gd")
	var player = world.player

	# --- the agreed table ---
	var wrong: Array = []
	for row in STAGE_ONE_MATERIALS:
		var mat = items.get_material(row[0])
		if mat == null:
			wrong.append("%s is missing" % row[0])
			continue
		var found: Array = [mat.material_id, mat.get_kind(), mat.durability_score, mat.hardness, mat.notches, mat.price_multiplier, mat.trait_id]
		if found != row or not mat.is_obtainable():
			wrong.append(str(found))
	check(wrong.is_empty() and items.get_obtainable_materials().size() == STAGE_ONE_MATERIALS.size(),
		"every stage-one material has the agreed durability score, hardness, notches, price and trait (%d materials)" % STAGE_ONE_MATERIALS.size(),
		"%d obtainable; wrong: %s" % [items.get_obtainable_materials().size(), str(wrong)])
	var notch_samples: Array = []
	for score in [3, 12, 19, 20, 28, 59, 60]:
		notch_samples.append(material_script.notches_for(score))
	check(notch_samples == [2, 2, 2, 3, 4, 7, 8], "notches are the durability score over 8, rounded half up, never fewer than 2", str(notch_samples))
	var mythril = items.get_material("mythril")
	var adamantite = items.get_material("adamantite")
	check(mythril != null and adamantite != null and not mythril.is_obtainable() and not adamantite.is_obtainable()
		and [mythril.durability_score, mythril.hardness, mythril.notches, mythril.price_multiplier, mythril.trait_id] == [50, 6, 6, 10.0, "rustproof"]
		and [adamantite.durability_score, adamantite.hardness, adamantite.notches, adamantite.price_multiplier, adamantite.trait_id] == [60, 10, 8, 10.0, "ignores_resistance"],
		"mythril and adamantite are defined, with their data, and cannot be obtained")

	# --- old ids ---
	var unresolved: Array = []
	for pair in OLD_ITEM_IDS:
		var item = items.get_item(pair[0])
		if item == null or item.item_id != pair[1] or items.canonical_item_id(pair[0]) != pair[1] or _art_is_missing(item):
			unresolved.append(pair[0])
	check(unresolved.is_empty() and items.get_item("iron_no_such_thing") == null and items.canonical_item_id("no_such_item") == "",
		"an item id written with a material of the old list still resolves to an item (%d ids)" % OLD_ITEM_IDS.size(), str(unresolved))
	var old_save: Dictionary = inv._instance_from_primitive({"item_id": "leather_jerkin", "quality_modifier": 1, "magic_modifier": 0,
		"current_durability": 12, "stack_count": 1})
	check(not old_save.is_empty() and old_save.item_data.item_id == "cowhide_jerkin" and old_save.item_data.material.material_id == "cowhide"
		and int(old_save.quality_modifier) == 1 and inv._instance_to_primitive(old_save).item_id == "cowhide_jerkin",
		"an item saved under an old material id loads as the item it became, and is saved under its new id")

	# --- a material changes nothing an item does ---
	var differing: Array = []
	var variants := 0
	for base in items.WEAPON_BASES:
		var seen: Dictionary = {}
		for item in items.items.values():
			if item.is_weapon and item.material != null and item.item_id == item.material.material_id + "_" + str(base.id):
				var profile: Dictionary = combat.build_attack_profile(player, item)
				seen["%s|%s|%s|%d|%d|%d|%s" % [profile.damage_dice, item.versatile_dice, profile.damage_type, profile.attack_bonus,
					item.range_normal, item.range_max, str(item.weight)]] = true
				variants += 1
		if seen.size() != 1:
			differing.append("%s: %s" % [str(base.id), str(seen.keys())])
	for base in items.ARMOR_BASES:
		var seen: Dictionary = {}
		for item in items.items.values():
			if item.is_armor and item.material != null and item.item_id == item.material.material_id + "_" + str(base.id):
				seen["%d|%d|%s|%d|%d|%s" % [item.armor_base, item.armor_class_bonus, item.armor_type, item.dex_bonus_limit,
					item.strength_requirement, str(item.weight)]] = true
				variants += 1
		if seen.size() != 1:
			differing.append("%s: %s" % [str(base.id), str(seen.keys())])
	var steel = items.get_material("steel")
	check(differing.is_empty() and variants >= 250 and not ("damage_bonus" in steel) and not ("armor_bonus" in steel),
		"a material adds no damage and no armour class: every material of a base has the same dice, attack bonus, range and armour (%d items)" % variants,
		str(differing))
	var prices: Array = []
	for item_id in ["steel_longsword", "copper_longsword", "damascus_steel_longsword", "silk_robe", "burlap_robe", "material_steel", "material_silver"]:
		prices.append(items.get_item(item_id).base_value)
	check(prices == [60, 30, 180, 382, 5, 5, 10], "a material sets the price: the base type's price times its multiplier", str(prices))

	# --- nothing hands out, or asks for, a material outside stage one ---
	var outside: Array = []
	var sizes: Array = []
	for category in ["weapon", "armor", "material"]:
		var candidates: Array = items.get_loot_candidates(category)
		sizes.append(candidates.size())
		for item in candidates:
			if not item.material.is_obtainable() or items.alias_ids.has(item.item_id):
				outside.append("loot category %s: %s" % [category, item.item_id])
	var drops := 0
	for table_id in loot.loot_tables:
		for level in [1, 5, 20]:
			for i in range(150):
				for drop in loot.roll_loot(table_id, level):
					drops += 1
					var mat = drop.item_data.material
					if mat != null and not mat.is_obtainable():
						outside.append("loot table %s: %s" % [table_id, drop.item_data.item_id])
	for recipe in recipes.get_all_recipes():
		var ids: Array = []
		if not recipe.get("is_enchant", false):
			ids.append(str(recipe.get("output_item_id", "")))
		for input in recipe.get("inputs", []):
			ids.append(str(input.get("item_id", "")))
		for item_id in ids:
			var item = items.get_item(item_id)
			if item == null or (item.material != null and not item.material.is_obtainable()):
				outside.append("recipe %s: %s" % [str(recipe.recipe_id), item_id])
	for class_id in classes.get_all_class_ids():
		for instance in items.get_starting_kit(class_id):
			var mat = instance.item_data.material
			if mat != null and not mat.is_obtainable():
				outside.append("starting kit %s: %s" % [class_id, instance.item_data.item_id])
	check(outside.is_empty() and sizes == [102, 108, 24] and drops >= 1000,
		"no loot table, loot category, recipe or starting kit hands out or asks for a material outside stage one (%d drops rolled)" % drops,
		"%s %s" % [str(sizes), str(outside.slice(0, 6))])
	var cheap := 0
	var dear := 0
	for i in range(3000):
		var rolled = items.get_random_item_by_type("weapon")
		if rolled.material.material_id == "copper":
			cheap += 1
		elif rolled.material.material_id == "damascus_steel":
			dear += 1
	check(dear > 0 and cheap > dear * 3, "a dearer material turns up less often in loot", "copper %d, Damascus steel %d" % [cheap, dear])
	seed(20261116)  # back to the run's seed: the rolls above used the generator

	# --- the tooltip names the material, its notches and its hardness ---
	var sheet = world.character_screen
	var steel_tip: String = sheet._item_tooltip(items.create_item_instance("steel_longsword"))
	var iron_tip: String = sheet._item_tooltip(items.create_item_instance("wrought_iron_chain_mail"))
	var potion_tip: String = sheet._item_tooltip(items.create_item_instance("potion_healing"))
	check("Material: Steel (metal)" in steel_tip and "Notches: 4   Hardness: 5" in steel_tip and not "Trait" in steel_tip
		and "Material: Wrought Iron (metal)" in iron_tip and "Notches: 2   Hardness: 3" in iron_tip and "Trait: Rusts Easily" in iron_tip
		and not "Material" in potion_tip and not "Notches" in potion_tip,
		"an item's tooltip names its material, its notches, its hardness and its trait", steel_tip.replace("\n", " / "))

func _art_is_missing(item) -> bool:
	"""True when an item resolved but got the missing-art texture"""
	return load("res://scripts/art_library.gd").is_fallback(item.icon)

# ---------------------------------------------------------------------------
#  Armour class by 5e rules: body armour, Dexterity as it allows, shield, bonuses
# ---------------------------------------------------------------------------

func _put_on(inv, stats, slot: String, instance: Dictionary):
	"""Test setup: place an item in an equipment slot directly ({} empties it)
	and work the character's numbers out again"""
	if not inv.equipped_items.has(stats):
		inv.equipped_items[stats] = {}
	if instance.is_empty():
		inv.equipped_items[stats].erase(slot)
	else:
		inv.equipped_items[stats][slot] = instance
	inv.recalculate_character_stats(stats)

func _armor_class_in(inv, items, stats, chest_id: String, quality: int = 0, magic: int = 0) -> int:
	"""The armour class with one body armour on (or none, for "")"""
	_put_on(inv, stats, "chest", items.create_item_instance(chest_id, quality, magic) if chest_id != "" else {})
	return stats.armor_class

func _check_armor_class(world):
	"""The default fighter (STR 14, DEX 12) with its kit: chain mail and a shield"""
	var items = _mgr("ItemDatabase")
	var inv = _mgr("InventoryManager")
	var combat = _mgr("CombatManager")
	var spells = _mgr("SpellManager")
	var builder = load("res://data/stats/character_builder.gd")
	var controller = world.combat
	var player = world.player
	var stats = player.stats
	var enemy = world.enemies[0]
	var sheet = world.character_screen
	var kit: Dictionary = inv.equipped_items[stats].duplicate()
	var shield: Dictionary = inv.get_equipped_item(stats, "off_hand")
	var dex_was: int = stats.dexterity
	var str_was: int = stats.strength
	var body_armor: Array = ["", "robe", "jerkin", "scale_mail", "chain_mail", "chestplate"]
	check(stats.class_id == "fighter" and dex_was == 12 and str_was == 14 and not shield.is_empty() and stats.armor_class == 18,
		"test setup: the fighter in chain mail with a shield, armour class 18", "AC %d" % stats.armor_class)

	# --- the base and the Dexterity it lets through ---
	_put_on(inv, stats, "off_hand", {})
	var by_dexterity: Array = []
	for dexterity in [18, 12, 6]:
		stats.dexterity = dexterity
		var row: Array = []
		for chest_id in body_armor:
			row.append(_armor_class_in(inv, items, stats, chest_id))
		by_dexterity.append(row)
	check(by_dexterity[0] == [14, 14, 15, 16, 16, 18], "armour class with Dexterity +4: 10 unarmoured or in a robe, leather 11, each plus the modifier; scale mail 14 plus at most 2; chain mail 16 and plate 18 with none",
		str(by_dexterity[0]))
	check(by_dexterity[1] == [11, 11, 12, 15, 16, 18] and by_dexterity[2] == [8, 8, 9, 12, 16, 18],
		"a lower Dexterity modifier counts in full under light and medium armour, and not at all under heavy armour",
		"%s / %s" % [str(by_dexterity[1]), str(by_dexterity[2])])

	# --- the shield ---
	stats.dexterity = 18
	var with_shield: Array = []
	for chest_id in body_armor:
		_put_on(inv, stats, "off_hand", shield)
		var armed: int = _armor_class_in(inv, items, stats, chest_id)
		_put_on(inv, stats, "off_hand", {})
		with_shield.append(armed - stats.armor_class)
	check(with_shield == [2, 2, 2, 2, 2, 2], "a shield adds 2 to the armour class, whatever the body armour", str(with_shield))

	# --- every other slot gives nothing ---
	_put_on(inv, stats, "off_hand", shield)
	var base_ac: int = _armor_class_in(inv, items, stats, "scale_mail")
	var breakdown: Array = []
	for part in stats.get_armor_class_breakdown():
		breakdown.append("%s %d" % [str(part.label), int(part.value)])
	check(base_ac == 18 and breakdown == ["Wrought Iron Scale Mail 14", "Dexterity (at most +2) 2", "Wrought Iron Shield 2"],
		"the armour class can be read as its parts: the armour's base, the Dexterity it lets through, the shield", str(breakdown))
	var adding: Array = []
	for piece in [["head", "helmet"], ["head", "leather_cap"], ["head", "hood"], ["hands", "gauntlets"], ["hands", "gloves"], ["hands", "wraps"],
			["legs", "greaves"], ["legs", "leggings"], ["legs", "pants"], ["feet", "plate_boots"], ["feet", "boots"], ["feet", "slippers"]]:
		_put_on(inv, stats, piece[0], items.create_item_instance(piece[1], 3, 3))
		if stats.armor_class != base_ac or stats.get_armor_class_breakdown().size() != 3:
			adding.append(piece[1])
	for item in items.items.values():
		if item.is_armor and not item.equip_slot in ["chest", "off_hand"] and (item.armor_base != 0 or item.armor_class_bonus != 0 or item.armor_type != ""):
			adding.append(item.item_id)
	check(adding.is_empty() and stats.armor_class == base_ac,
		"a helmet, gauntlets, greaves and boots add nothing to the armour class, in metal, leather or cloth, however well made or enchanted",
		str(adding.slice(0, 6)))
	for slot in ["head", "hands", "legs", "feet"]:
		_put_on(inv, stats, slot, {})

	# --- magic that grants armour class keeps doing so, from any slot ---
	inv.equipped_items[stats]["rings"] = [items.create_item_instance("ring_protection")]
	_put_on(inv, stats, "back", items.create_item_instance("cloak_protection"))
	var warded: int = stats.armor_class
	var warded_parts: Array = stats.get_armor_class_breakdown()
	inv.equipped_items[stats].erase("rings")
	_put_on(inv, stats, "back", {})
	check(warded == base_ac + 2 and warded_parts[-1].label == "Magic" and warded_parts[-1].value == 2 and stats.armor_class == base_ac,
		"a ring and a cloak of protection each add 1 to the armour class", "AC %d" % warded)

	# --- the sheet shows how the armour class is made up ---
	sheet.show_character(stats)
	await _frames(2)
	var ac_label: Label = sheet.stats_panel.find_child("ACLabel", true, false)
	var parts_label: Label = sheet.stats_panel.find_child("ACBreakdownLabel", true, false)
	var shown: Array = []
	for line in parts_label.text.split("\n"):
		shown.append(line.strip_edges())
	check(ac_label.text == "AC: 18" and shown == ["Wrought Iron Scale Mail 14", "Dexterity (at most +2) +2", "Wrought Iron Shield +2"]
		and sheet.stats_panel.get_global_rect().encloses(parts_label.get_global_rect()),
		"the character sheet shows the armour class and what it is made up of", str(shown))
	sheet.hide_screen()
	paused = false

	# --- each piece's own bonus: the higher of craftsmanship and magic, read from the piece ---
	_put_on(inv, stats, "off_hand", {})
	var bonuses: Array = []
	for pair in [[0, 0], [1, 0], [0, 1], [1, 2], [3, 1]]:
		bonuses.append(_armor_class_in(inv, items, stats, "chain_mail", pair[0], pair[1]))
	_put_on(inv, stats, "off_hand", items.create_item_instance("shield", 0, 1))
	var plus_one_shield: int = stats.armor_class
	_put_on(inv, stats, "off_hand", {})
	var template = items.get_item("chain_mail")
	template.magic_modifier = 3
	template.quality_modifier = 3
	var from_template: int = _armor_class_in(inv, items, stats, "chain_mail")
	template.magic_modifier = 0
	template.quality_modifier = 0
	check(bonuses == [16, 17, 17, 18, 19] and plus_one_shield == 19 + 3 and from_template == 16,
		"body armour and a shield add the higher of their own craftsmanship and magic bonus, read from the piece and not from its template",
		"%s, shield %d, template %d" % [str(bonuses), plus_one_shield, from_template])
	var in_metal: Array = []
	for chest_id in ["copper_chain_mail", "damascus_steel_chain_mail", "adamantine_chain_mail"]:
		in_metal.append(_armor_class_in(inv, items, stats, chest_id))
	check(in_metal == [16, 16, 16], "chain mail gives the same armour class in copper, Damascus steel and adamantite", str(in_metal))

	# --- too weak for the armour: 10 feet slower ---
	stats.dexterity = dex_was
	var speeds: Array = []
	for row in [["chain_mail", 13], ["chain_mail", 12], ["chestplate", 15], ["chestplate", 14], ["scale_mail", 8], ["jerkin", 8], ["", 8]]:
		stats.strength = row[1]
		_armor_class_in(inv, items, stats, row[0])
		speeds.append(stats.get_modified_speed_feet())
	check(speeds == [30, 20, 30, 20, 30, 30, 30] , "a wearer below a heavy armour's Strength requirement (chain mail 13, plate 15) moves 10 feet slower",
		str(speeds))
	stats.strength = 12
	_armor_class_in(inv, items, stats, "chain_mail")
	check(stats.is_slowed_by_armor() and stats.get_modified_movement_speed() == 4 and player.get_turn_speed() == 4
		and stats.armor_stealth_disadvantage,
		"the slower wearer has 4 tiles of movement in a turn", "%d tiles" % player.get_turn_speed())
	stats.strength = str_was

	# --- armour and shields need the class's proficiency ---
	var trained: Array = []
	for row in [["fighter", "chestplate", true], ["cleric", "scale_mail", true], ["cleric", "chain_mail", true], ["rogue", "jerkin", false],
			["rogue", "scale_mail", false], ["wizard", "jerkin", false], ["wizard", "robe", false], ["wizard", "robe", true], ["wizard", "", false]]:
		stats.class_id = row[0]
		_put_on(inv, stats, "off_hand", shield if row[2] else {})
		_armor_class_in(inv, items, stats, row[1])
		var names: Array = Array(stats.untrained_armor)
		names.sort()
		var modifiers: Dictionary = combat.get_attack_modifiers(player, enemy, combat.get_attack_profile(player))
		trained.append("%s %s%s: %s%s" % [row[0], row[1] if row[1] != "" else "nothing", " + shield" if row[2] else "",
			", ".join(names) if not names.is_empty() else "fine",
			" (disadvantage)" if modifiers.disadvantage and combat.REASON_UNTRAINED_ARMOR in modifiers.reasons else ""])
	stats.class_id = "fighter"
	check(trained == ["fighter chestplate + shield: fine", "cleric scale_mail + shield: fine",
		"cleric chain_mail + shield: Wrought Iron Chain Mail (disadvantage)", "rogue jerkin: fine",
		"rogue scale_mail: Wrought Iron Scale Mail (disadvantage)", "wizard jerkin: Cowhide Jerkin (disadvantage)", "wizard robe: fine",
		"wizard robe + shield: Wrought Iron Shield (disadvantage)", "wizard nothing: fine"],
		"body armour or a shield worn without the class's proficiency gives disadvantage on attack rolls; clothes need none", str(trained))

	# A wizard of the test's own, for the spell
	var wizard = builder.build("wizard", "human", {"str": 8, "dex": 14, "con": 12, "int": 16, "wis": 12, "cha": 10}, "Armoured Wizard")
	player.stats = wizard
	inv.set_party_members([wizard])
	spells.get_known_spells(wizard)
	_put_on(inv, wizard, "chest", items.create_item_instance("jerkin"))
	var armoured_cast: Dictionary = spells.can_cast(player, "fire_bolt")
	var armoured_request: Dictionary = controller.check_action(player, "cast", {"spell_id": "fire_bolt"})
	_put_on(inv, wizard, "chest", items.create_item_instance("robe"))
	var robed_cast: Dictionary = spells.can_cast(player, "fire_bolt")
	check(not armoured_cast.ok and "no proficiency" in armoured_cast.reason and "Cowhide Jerkin" in armoured_cast.reason
		and not armoured_request.ok and armoured_request.reason == armoured_cast.reason and robed_cast.ok
		and controller.check_action(player, "cast", {"spell_id": "fire_bolt"}).ok,
		"a caster in armour it is not proficient with cannot cast a spell, and is told why; in a robe it can", str(armoured_cast.reason))
	player.stats = stats
	inv.set_party_members([stats])
	inv.equipped_items.erase(wizard)
	spells.known_spells.erase(wizard)
	spells.current_slots.erase(wizard)

	# --- enemies keep the armour class they had ---
	check(enemy.stats.armor_class == 10 and enemy.stats.get_armor_class_breakdown().size() == 2,
		"an enemy's armour class is what it was: 10 plus its Dexterity modifier", "AC %d" % enemy.stats.armor_class)

	# Back to the starting kit
	stats.dexterity = dex_was
	stats.strength = str_was
	inv.equipped_items[stats] = kit
	inv.recalculate_character_stats(stats)
	stats.current_hp = stats.max_hp
	await _frames(2)
	check(stats.armor_class == 18 and stats.class_id == "fighter" and not stats.wears_untrained_armor() and player.stats == stats,
		"test teardown: the fighter is back in its kit, armour class 18")

# ---------------------------------------------------------------------------
#  Damage: one pipeline, with resistance, vulnerability, immunity and hooks
# ---------------------------------------------------------------------------

func _spawn_far(world, enemy_type: String, hp: int, place_seed: int):
	"""A staged enemy well away from the player, so that no fight starts, at a
	place that depends only on the seed"""
	var rng := RandomNumberGenerator.new()
	rng.seed = place_seed
	return world._spawn_enemy(enemy_type, 1, hp, world.find_enemy_spawn_position(rng))

func _hit(combat, attacker, target, profile: Dictionary = {}, wanted: String = "hit") -> Dictionary:
	"""Make weapon attacks until one comes out as wanted: "hit" (any hit),
	"critical", "miss" or "natural_1". {} when none does in 600 tries."""
	for attempt in range(600):
		var attack: Dictionary = combat.make_attack(attacker, target, profile)
		if attack.is_empty():
			return {}
		var outcome: String = combat._attack_outcome(attack)
		if outcome == wanted or (wanted == "hit" and attack.hit):
			return attack
	return {}

func _set_nature(combatant, resistances: Array, vulnerabilities: Array, immunities: Array):
	"""Test setup: what a combatant's own nature makes it to each damage type"""
	combatant.damage_resistances.assign(resistances)
	combatant.damage_vulnerabilities.assign(vulnerabilities)
	combatant.damage_immunities.assign(immunities)

func _newest_popup(world):
	"""The floating number added to the world last, or null"""
	var popup_script = load("res://scripts/damage_popup.gd")
	var newest = null
	for child in world.get_children():
		if is_instance_of(child, popup_script) and not child.is_queued_for_deletion():
			newest = child
	return newest

func _check_damage(world):
	"""Outside any fight: the default fighter and staged enemies far away from
	it. Fixed amounts where the arithmetic is checked, so no die decides a
	result; where a d20 is needed the attack is repeated until it lands."""
	var combat = _mgr("CombatManager")
	var effects = _mgr("StatusEffectManager")
	var spells = _mgr("SpellManager")
	var features = _mgr("FeatureManager")
	var items = _mgr("ItemDatabase")
	var inv = _mgr("InventoryManager")
	var game = _mgr("GameManager")
	var bus = _mgr("EventBus")
	var builder = load("res://data/stats/character_builder.gd")
	var player = world.player
	var stats = player.stats
	var combat_log = world.get_node("UI/CombatLog")
	var longsword: Dictionary = inv.get_equipped_item(stats, "main_hand")
	var shield: Dictionary = inv.get_equipped_item(stats, "off_hand")
	var sword: Dictionary = combat.build_attack_profile(player, longsword.item_data)
	var xp_before: int = stats.experience

	var goblin = _spawn_far(world, "goblin", 500, 101)
	var skeleton = _spawn_far(world, "skeleton", 500, 102)
	goblin.stats.armor_class = -100
	skeleton.stats.armor_class = -100
	check(not world.in_combat and goblin.get_resistances().is_empty() and goblin.get_vulnerabilities().is_empty()
		and goblin.get_immunities().is_empty(), "test setup: staged enemies far from the player, and a goblin with no resistances")

	var incoming: Array = []
	var applied: Array = []
	var dropping: Array = []
	var attacks: Array = []
	var on_incoming = func(event): incoming.append(event.duplicate())
	var on_applied = func(event): applied.append(event.duplicate())
	var on_dropping = func(event): dropping.append(event.duplicate())
	var on_attack = func(event): attacks.append(event.duplicate())
	bus.damage_incoming.connect(on_incoming)
	bus.damage_applied.connect(on_applied)
	bus.dropping_to_zero.connect(on_dropping)
	bus.attack_resolved.connect(on_attack)

	# --- the arithmetic: none, half rounded down, double ---
	var amounts: Array = []
	var responses: Array = []
	for nature in [[[], [], []], [["fire"], [], []], [[], ["fire"], []], [[], [], ["fire"]], [["fire"], ["fire"], []], [["cold", "charm"], ["cold"], ["cold"]]]:
		_set_nature(goblin, nature[0], nature[1], nature[2])
		var hp_before: int = goblin.stats.current_hp
		var dealt: Dictionary = combat.deal_damage(player, goblin, 7, "fire")
		amounts.append(hp_before - goblin.stats.current_hp)
		responses.append("%d %s" % [int(dealt.amount), str(dealt.response)])
	check(amounts == [7, 3, 14, 0, 6, 7] and responses == ["7 ", "3 resisted", "14 vulnerable", "0 immune", "6 ", "7 "],
		"resistance halves damage of its type, rounded down, vulnerability doubles it, immunity negates it, and other types are untouched",
		"%s %s" % [str(amounts), str(responses)])
	_set_nature(goblin, ["charm", "sleep", "poison"], [], [])
	check(goblin.get_resistances() == ["poison"], "only real damage types count as resistances", str(goblin.get_resistances()))

	# --- the same three, for a weapon hit, a spell and a status effect's tick ---
	var strike: Dictionary = combat.get_unarmed_profile(player)
	strike["flat_damage"] = 7
	strike["ability_modifier"] = 0
	strike["damage_type"] = "fire"
	var bolt := {"spell_id": "smoke_bolt", "display_name": "Smoke Bolt", "attack_roll": true, "damage_dice": "7", "damage_type": "fire",
		"target_type": "enemy", "range_tiles": 12}
	var burst := {"spell_id": "smoke_burst", "display_name": "Smoke Burst", "damage_dice": "7", "damage_type": "fire", "target_type": "enemy"}
	effects.effect_definitions["smoke_scald"] = {"effect_id": "smoke_scald", "display_name": "Scalded", "kind": "debuff",
		"tick": {"timing": "turn_start", "damage_dice": "7", "damage_type": "fire"}, "default_duration": 9}
	combat_log.clear_log()
	var by_weapon: Array = []
	var by_spell: Array = []
	var by_tick: Array = []
	var shown: Array = []
	for nature in [[["fire"], [], []], [[], ["fire"], []], [[], [], ["fire"]]]:
		_set_nature(goblin, nature[0], nature[1], nature[2])
		var hp_before: int = goblin.stats.current_hp
		var swing: Dictionary = _hit(combat, player, goblin, strike)
		by_weapon.append("%d of %d %s, hp -%d" % [int(swing.get("damage", -1)), int(swing.get("damage_rolled", -1)),
			str(swing.get("damage_response", "?")), hp_before - goblin.stats.current_hp])

		hp_before = goblin.stats.current_hp
		var cast: Dictionary = spells._resolve_cast(player, burst, goblin, [], spells._blank_result("smoke_burst"))
		var ray: Dictionary = {}
		for attempt in range(60):
			ray = combat.make_spell_attack(player, goblin, bolt)
			if ray.hit and not ray.is_crit:
				break
		by_spell.append("%d %s, total %d; attack %d of %d %s" % [int(cast.hits[0].damage), str(cast.hits[0].response), int(cast.total_damage),
			int(ray.damage), int(ray.damage_rolled), str(ray.damage_response)])

		hp_before = goblin.stats.current_hp
		applied.clear()
		effects.apply_effect(goblin, "smoke_scald", 9, player)
		effects.process_turn_start(goblin)
		effects.clear_effects(goblin)
		var tick: Dictionary = applied[0] if applied.size() == 1 else {}
		var popup = _newest_popup(world)
		by_tick.append("%d of %d %s %s, hp -%d" % [int(tick.get("amount", -1)), int(tick.get("rolled", -1)), str(tick.get("response", "?")),
			str(tick.get("kind", "?")), hp_before - goblin.stats.current_hp])
		shown.append("%d %s" % [popup.damage, popup.response] if popup != null else "no number")
	effects.effect_definitions.erase("smoke_scald")
	check(by_weapon == ["3 of 7 resisted, hp -3", "14 of 7 vulnerable, hp -14", "0 of 7 immune, hp -0"],
		"a weapon hit is halved by resistance, doubled by vulnerability and negated by immunity", str(by_weapon))
	check(by_spell == ["3 resisted, total 3; attack 3 of 7 resisted", "14 vulnerable, total 14; attack 14 of 7 vulnerable",
		"0 immune, total 0; attack 0 of 7 immune"],
		"a spell's damage, with an attack roll or without, is halved, doubled and negated the same way", str(by_spell))
	check(by_tick == ["3 of 7 resisted effect, hp -3", "14 of 7 vulnerable effect, hp -14", "0 of 7 immune effect, hp -0"],
		"a status effect's tick is halved, doubled and negated the same way", str(by_tick))
	check(shown == ["3 resisted", "14 vulnerable", "0 immune"],
		"the floating number of a tick says when the damage was resisted, doubled or negated", str(shown))
	var log_now: String = combat_log.log_text.get_parsed_text()
	check("for 3 fire damage (resisted: halved)" in log_now and "for 14 fire damage (vulnerable: doubled)" in log_now
		and "is immune to fire: no damage" in log_now,
		"the combat log says when damage was resisted, doubled or negated")
	_set_nature(goblin, [], [], [])

	# --- damage with nobody behind it goes the same way ---
	applied.clear()
	_set_nature(goblin, ["acid"], [], [])
	var hp_before_trap: int = goblin.stats.current_hp
	goblin.take_damage(9, "acid")
	check(hp_before_trap - goblin.stats.current_hp == 4 and applied.size() == 1 and applied[0].kind == "other" and applied[0].source == null,
		"damage with nobody behind it (a trap) goes through the same pipeline", "%d lost" % (hp_before_trap - goblin.stats.current_hp))
	_set_nature(goblin, [], [], [])

	# --- the skeleton: vulnerable to bludgeoning ---
	var bone_hits: Array = []
	for damage_type in ["bludgeoning", "slashing", "piercing"]:
		var hp_before: int = skeleton.stats.current_hp
		combat.deal_damage(player, skeleton, 10, damage_type)
		bone_hits.append(hp_before - skeleton.stats.current_hp)
	var mace_hit: Dictionary = _hit(combat, player, skeleton, combat.build_attack_profile(player, items.get_item("mace")))
	var sword_hit: Dictionary = _hit(combat, player, skeleton, combat.build_attack_profile(player, items.get_item("longsword")))
	var goblin_mace: Dictionary = _hit(combat, player, goblin, combat.build_attack_profile(player, items.get_item("mace")))
	check(skeleton.get_vulnerabilities() == ["bludgeoning"] and bone_hits == [20, 10, 10]
		and not mace_hit.is_empty() and mace_hit.damage == mace_hit.damage_rolled * 2 and mace_hit.damage_response == "vulnerable"
		and sword_hit.damage == sword_hit.damage_rolled and sword_hit.damage_response == ""
		and goblin_mace.damage == goblin_mace.damage_rolled,
		"a skeleton takes double damage from bludgeoning weapons, and only from those",
		"%s, mace %s of %s" % [str(bone_hits), str(mace_hit.get("damage", "?")), str(mace_hit.get("damage_rolled", "?"))])

	# --- a dwarf resists poison ---
	var dwarf = builder.build("fighter", "dwarf", {"str": 15, "dex": 12, "con": 14, "int": 10, "wis": 10, "cha": 8}, "Smoke Dwarf")
	var elf = builder.build("fighter", "elf", {"str": 15, "dex": 12, "con": 14, "int": 10, "wis": 10, "cha": 8}, "Smoke Elf")
	player.stats = elf
	var elf_resists: Array = player.get_resistances()
	player.stats = dwarf
	dwarf.max_hp = 100  # no blow of this check may fell the body the player wears
	dwarf.current_hp = 100
	var dwarf_hp: int = dwarf.current_hp
	var venom: Dictionary = combat.deal_damage(goblin, player, 7, "poison")
	var blade: Dictionary = combat.deal_damage(goblin, player, 2, "slashing")
	applied.clear()
	effects.apply_effect(player, "poisoned", 3, goblin)
	effects.process_turn_start(player)
	effects.clear_effects(player)
	var poison_tick: Dictionary = applied[0] if applied.size() == 1 else {}
	check(player.get_resistances() == ["poison"] and elf_resists.is_empty() and int(venom.amount) == 3 and venom.response == "resisted"
		and int(blade.amount) == 2 and blade.response == "" and poison_tick.get("response", "") == "resisted"
		and int(poison_tick.get("amount", -1)) == int(int(poison_tick.get("rolled", 0)) / 2.0)
		and dwarf_hp - dwarf.current_hp == 3 + 2 + int(poison_tick.get("amount", 0)),
		"a dwarf takes half damage from poison, struck or poisoned, and full damage from a blade",
		"resists %s, poison %s, tick %s of %s" % [str(player.get_resistances()), str(venom.get("amount", "?")),
			str(poison_tick.get("amount", "?")), str(poison_tick.get("rolled", "?"))])
	player.stats = stats

	# --- a status effect and a worn item can grant resistance too ---
	effects.apply_effect(goblin, "fire_resistance", 5)
	var warded: Dictionary = combat.deal_damage(player, goblin, 9, "fire")
	effects.clear_effects(goblin)
	var charm = load("res://data/items/item_data.gd").new()
	charm.item_id = "smoke_charm"
	charm.item_name = "Test Charm"
	charm.equip_slot = "neck"
	charm.damage_resistances.assign(["cold"])
	charm.damage_immunities.assign(["psychic"])
	charm.damage_vulnerabilities.assign(["radiant"])
	_put_on(inv, stats, "neck", {"item_data": charm})
	var worn: Array = [player.get_resistances(), player.get_immunities(), player.get_vulnerabilities()]
	_put_on(inv, stats, "neck", {})
	check(int(warded.amount) == 4 and warded.response == "resisted" and worn == [["cold"], ["psychic"], ["radiant"]]
		and player.get_resistances().is_empty(),
		"a status effect and a worn item give their resistances, immunities and vulnerabilities to the one who has them", str(worn))

	# --- Relentless Endurance: a half-orc drops to 1 instead of 0, once between long rests ---
	var orc = _spawn_far(world, "bandit", 30, 103)
	orc.stats = builder.build("fighter", "half_orc", {"str": 15, "dex": 12, "con": 14, "int": 10, "wis": 10, "cha": 8}, "Smoke Half-Orc")
	orc.stats.character_uid = "smoke_half_orc"
	var orc_max: int = orc.stats.max_hp
	dropping.clear()
	var first_blow: Dictionary = combat.deal_damage(player, orc, 9999, "slashing")
	var after_first: int = orc.stats.current_hp
	var alive_after_first: bool = orc.is_alive()
	orc.stats.current_hp = orc_max
	var second_blow: Dictionary = combat.deal_damage(player, orc, 9999, "slashing")
	check(features.has_feature(orc.stats, "relentless_endurance") and first_blow.prevented and first_blow.prevented_by == "Relentless Endurance"
		and after_first == 1 and alive_after_first and int(first_blow.amount) == orc_max - 1 and not first_blow.killed,
		"Relentless Endurance leaves a half-orc on 1 hit point when damage would drop it to 0", "hp %d" % after_first)
	check(not second_blow.prevented and second_blow.killed and not orc.is_alive() and dropping.size() == 2
		and features.is_used(orc.stats, "relentless_endurance"),
		"Relentless Endurance works once: the next such blow before a long rest kills", "hp %d" % orc.stats.current_hp)
	var orc_two = _spawn_far(world, "bandit", 30, 104)
	orc_two.stats = builder.build("fighter", "half_orc", {"str": 15, "dex": 12, "con": 14, "int": 10, "wis": 10, "cha": 8}, "Smoke Half-Orc II")
	orc_two.stats.character_uid = "smoke_half_orc_2"
	orc_two.stats.armor_class = -100
	var struck: Dictionary = _hit(combat, player, orc_two, sword)
	for attempt in range(40):
		if struck.get("prevented_by", "") != "":
			break
		struck = _hit(combat, player, orc_two, sword)
	var used_before_rest: bool = features.is_used(orc_two.stats, "relentless_endurance")
	game.take_long_rest()
	var back_after_rest: bool = features.is_available(orc_two.stats, "relentless_endurance")
	var after_rest: Dictionary = combat.deal_damage(player, orc_two, 9999, "slashing")
	check(struck.get("prevented_by", "") == "Relentless Endurance" and used_before_rest and back_after_rest and after_rest.prevented
		and orc_two.stats.current_hp == 1 and orc_two.is_alive(),
		"a weapon's blow is turned the same way, and a long rest gives Relentless Endurance back", "hp %d" % orc_two.stats.current_hp)
	var human_dies: Dictionary = combat.deal_damage(player, _spawn_far(world, "wolf", 5, 105), 9999, "slashing")
	check(human_dies.killed and not human_dies.prevented, "a creature without the trait drops as before")

	# --- the hooks: an attack was resolved ---
	attacks.clear()
	var landed: Dictionary = _hit(combat, player, goblin, sword)
	var hit_event: Dictionary = attacks[-1]
	check(hit_event.attacker == player and hit_event.target == goblin and hit_event.kind == "weapon" and hit_event.hit
		and hit_event.roll == landed.roll and hit_event.roll >= 2 and hit_event.roll <= 20 and hit_event.outcome in ["hit", "critical"]
		and hit_event.weapon == longsword.item_data and hit_event.weapon_instance == longsword and not hit_event.natural_weapon
		and hit_event.weapon_name == "Wrought Iron Longsword" and hit_event.damage_type == "slashing" and not hit_event.is_ranged
		and not hit_event.two_handed and not hit_event.two_handed_grip and hit_event.damage == landed.damage and hit_event.result == landed,
		"a resolved attack is announced with the attacker, the target, the natural d20, the outcome, the weapon's item instance and its damage type",
		str(hit_event.get("outcome", "?")))
	goblin.stats.armor_class = 100
	var missed: Dictionary = _hit(combat, player, goblin, sword, "miss")
	var miss_event: Dictionary = attacks[-1]
	var fumbled: Dictionary = _hit(combat, player, goblin, sword, "natural_1")
	var fumble_event: Dictionary = attacks[-1]
	var crit: Dictionary = _hit(combat, player, goblin, sword, "critical")
	var crit_event: Dictionary = attacks[-1]
	goblin.stats.armor_class = -100
	check(not missed.is_empty() and miss_event.outcome == "miss" and not miss_event.hit and miss_event.damage == 0 and miss_event.roll >= 2
		and not fumbled.is_empty() and fumble_event.outcome == "natural_1" and fumble_event.roll == 1 and fumble_event.is_fumble and not fumble_event.hit
		and not crit.is_empty() and crit_event.outcome == "critical" and crit_event.roll == 20 and crit_event.is_crit and crit_event.hit,
		"a miss, a natural 1 and a critical hit are each announced as what they are",
		"%s / %s / %s" % [str(miss_event.get("outcome", "?")), str(fumble_event.get("outcome", "?")), str(crit_event.get("outcome", "?"))])
	_put_on(inv, stats, "off_hand", {})
	_hit(combat, player, goblin, combat.build_attack_profile(player, items.get_item("greatsword")))
	var greatsword_event: Dictionary = attacks[-1]
	_hit(combat, player, goblin, combat.build_attack_profile(player, longsword.item_data))
	var both_hands_event: Dictionary = attacks[-1]
	_put_on(inv, stats, "off_hand", shield)
	_hit(combat, player, goblin, combat.get_unarmed_profile(player))
	var fist_event: Dictionary = attacks[-1]
	_hit(combat, goblin, skeleton, {})
	var claw_event: Dictionary = attacks[-1]
	var ray_result: Dictionary = combat.make_spell_attack(player, goblin, bolt)
	var ray_event: Dictionary = attacks[-1]
	check(greatsword_event.two_handed and greatsword_event.two_handed_grip
		and not both_hands_event.two_handed and both_hands_event.two_handed_grip
		and fist_event.kind == "unarmed" and fist_event.weapon == null and fist_event.natural_weapon and fist_event.damage_type == "bludgeoning"
		and claw_event.attacker == goblin and claw_event.kind == "weapon" and claw_event.natural_weapon and claw_event.weapon_instance.is_empty()
		and ray_event.kind == "spell" and ray_event.spell_id == "smoke_bolt" and ray_event.roll == ray_result.roll
		and ray_event.weapon == null and not ray_event.natural_weapon and ray_event.damage_type == "fire",
		"the announcement says whether the weapon is two-handed, a natural weapon or a spell")

	# --- the hooks: damage about to be applied, and applied ---
	var doubler = func(event):
		if event.target == goblin and event.damage_type == "cold":
			event["amount"] = int(event.amount) + 13
	bus.damage_incoming.connect(doubler)
	incoming.clear()
	applied.clear()
	var hp_before_cold: int = goblin.stats.current_hp
	var plain_cold: Dictionary = combat.deal_damage(player, goblin, 7, "cold", {"kind": "spell", "spell_id": "smoke_frost", "is_critical": true})
	_set_nature(goblin, ["cold"], [], [])
	var resisted_cold: Dictionary = combat.deal_damage(player, goblin, 7, "cold")
	_set_nature(goblin, [], [], [])
	bus.damage_incoming.disconnect(doubler)
	check(int(plain_cold.amount) == 20 and int(resisted_cold.amount) == 10 and hp_before_cold - goblin.stats.current_hp == 30
		and incoming.size() == 2 and incoming[0].amount == 7 and incoming[0].rolled == 7 and incoming[1].resistant,
		"a listener of the incoming-damage hook can change the amount, before resistance is applied",
		"%s then %s" % [str(plain_cold.get("amount", "?")), str(resisted_cold.get("amount", "?"))])
	var report: Dictionary = applied[0] if applied.size() == 2 else {}
	check(report.get("source") == player and report.get("target") == goblin and report.get("amount", 0) == 20 and report.get("rolled", 0) == 7
		and report.get("damage_type", "") == "cold" and report.get("kind", "") == "spell" and report.get("is_critical", false)
		and report.get("context", {}).get("spell_id", "") == "smoke_frost" and report.get("hp_before", 0) == hp_before_cold
		and report.get("hp_after", 0) == hp_before_cold - 20 and not report.get("killed", true),
		"applied damage is announced with its source, target, amount, type, kind and the hit points before and after")

	# --- the hooks: a combatant would drop to 0 hit points ---
	dropping.clear()
	combat.deal_damage(player, goblin, 5, "slashing")
	var ward = func(event):
		if event.target == goblin:
			event["prevented"] = true
			event["hp_left"] = 3
			event["prevented_by"] = "Smoke Ward"
	bus.dropping_to_zero.connect(ward)
	var hp_before_doom: int = goblin.stats.current_hp
	var doom: Dictionary = combat.deal_damage(player, goblin, 9999, "slashing")
	bus.dropping_to_zero.disconnect(ward)
	check(dropping.size() == 1 and dropping[0].target == goblin and dropping[0].amount == 9999 and not dropping[0].prevented
		and doom.prevented and doom.prevented_by == "Smoke Ward" and goblin.stats.current_hp == 3 and goblin.is_alive()
		and int(doom.amount) == hp_before_doom - 3 and not doom.killed,
		"a listener of the drop-to-zero hook can keep the combatant standing; damage that leaves it standing does not raise the hook",
		"%d raised, hp %d" % [dropping.size(), goblin.stats.current_hp])

	bus.damage_incoming.disconnect(on_incoming)
	bus.damage_applied.disconnect(on_applied)
	bus.dropping_to_zero.disconnect(on_dropping)
	bus.attack_resolved.disconnect(on_attack)
	for staged in [goblin, skeleton, orc_two]:
		_remove_enemy(world, staged)
	for node in world.ground_items_node.get_children():
		node.queue_free()
	var level_now: int = stats.level
	stats.experience = xp_before  # the two staged deaths gave experience; the checks after this one count their own
	stats.current_hp = stats.max_hp
	await _frames(2)
	check(player.stats == stats and not world.in_combat and stats.is_alive() and level_now == 1 and stats.armor_class == 18,
		"test teardown: the staged enemies are gone, no fight started and the fighter is as it was")

# ---------------------------------------------------------------------------
#  Cover: the 5e rule for a grid, on maps drawn for the purpose
# ---------------------------------------------------------------------------

func _text_grid(rows: Array) -> Array:
	"""A dungeon grid from rows of text: '#' a wall, '.' floor, 'D' a door,
	'o' a decoration, anything else nothing at all"""
	var grid: Array = []
	for line in rows:
		var row: Array = []
		for symbol in str(line):
			row.append({"#": 1, ".": 0, "D": 2, "o": 3}.get(symbol, -1))
		grid.append(row)
	return grid

func _cover_text(grid_script, grid: Array, from: Vector2i, to: Vector2i) -> String:
	"""'2 lines, +2' or '4 lines, +5, out of sight': what get_cover answers"""
	var cover: Dictionary = grid_script.get_cover(from, to, grid)
	return "%d lines, +%d%s" % [int(cover.lines_blocked), int(cover.ac_bonus), "" if cover.line_of_sight else ", out of sight"]

func _check_cover():
	var grid_script = load("res://scripts/combat_grid.gd")
	var narrow: Array = _text_grid([
		"###########",
		"#.........#",
		"###########"])
	var wide: Array = _text_grid([
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"############"])
	var open: Array = []
	for shot in [[narrow, Vector2i(1, 1), Vector2i(9, 1)], [narrow, Vector2i(9, 1), Vector2i(3, 1)], [wide, Vector2i(1, 1), Vector2i(10, 3)],
			[wide, Vector2i(1, 3), Vector2i(10, 3)], [wide, Vector2i(2, 1), Vector2i(9, 2)], [wide, Vector2i(10, 2), Vector2i(1, 1)]]:
		open.append(_cover_text(grid_script, shot[0], shot[1], shot[2]))
	check(open == ["0 lines, +0", "0 lines, +0", "0 lines, +0", "0 lines, +0", "0 lines, +0", "0 lines, +0"]
		and grid_script.get_cover_ac_bonus(Vector2i(1, 1), Vector2i(9, 1), narrow) == grid_script.COVER_NONE,
		"an unobstructed shot down a corridor has no cover, however near the walls are", str(open))

	var corner: Array = _text_grid([
		"#######",
		"#.....#",
		"#...#.#",
		"#.....#",
		"#######"])
	var beside: Array = _text_grid([
		"#######",
		"#.....#",
		"#....##",
		"#.....#",
		"#######"])
	var pillar: Array = _text_grid([
		"#######",
		"#.....#",
		"#.....#",
		"#..#..#",
		"#.....#",
		"#######"])
	var past_corner: Array = [_cover_text(grid_script, corner, Vector2i(1, 1), Vector2i(5, 3)),
		_cover_text(grid_script, beside, Vector2i(1, 1), Vector2i(5, 3)), _cover_text(grid_script, pillar, Vector2i(1, 3), Vector2i(5, 3))]
	check(past_corner == ["2 lines, +2", "1 lines, +2", "2 lines, +2"] and grid_script.has_line_of_sight(Vector2i(1, 1), Vector2i(5, 3), corner)
		and grid_script.get_cover_ac_bonus(Vector2i(1, 1), Vector2i(5, 3), corner) == grid_script.COVER_HALF,
		"a shot past a corner meets half cover: one or two of the four lines to the target's corners are blocked", str(past_corner))

	var slit: Array = _text_grid([
		"#######",
		"#.....#",
		"#..#..#",
		"#.....#",
		"#######"])
	var three_quarters: String = _cover_text(grid_script, slit, Vector2i(1, 1), Vector2i(5, 3))
	check(three_quarters == "3 lines, +5" and grid_script.get_cover_ac_bonus(Vector2i(1, 1), Vector2i(5, 3), slit) == grid_script.COVER_THREE_QUARTERS,
		"three lines blocked is three-quarters cover", three_quarters)

	var walled: Array = _text_grid([
		"###########",
		"#....#....#",
		"###########"])
	var pinched: Array = _text_grid([
		"#####",
		"#.#.#",
		"##..#",
		"#...#",
		"#####"])
	var blocked: Array = [_cover_text(grid_script, walled, Vector2i(1, 1), Vector2i(9, 1)), _cover_text(grid_script, pinched, Vector2i(1, 1), Vector2i(3, 3))]
	check(blocked == ["4 lines, +5, out of sight", "4 lines, +5, out of sight"] and not grid_script.has_line_of_sight(Vector2i(1, 1), Vector2i(9, 1), walled),
		"a blocked shot has no line of sight: a wall across the corridor, or a gap of no width between two wall corners", str(blocked))

	var furnished: Array = _text_grid([
		"###########",
		"#..D.o....#",
		"###########"])
	var harmless: Array = [_cover_text(grid_script, furnished, Vector2i(1, 1), Vector2i(9, 1)), _cover_text(grid_script, walled, Vector2i(3, 1), Vector2i(4, 1)),
		_cover_text(grid_script, pinched, Vector2i(1, 1), Vector2i(2, 2)), _cover_text(grid_script, [], Vector2i(0, 0), Vector2i(9, 9))]
	check(harmless == ["0 lines, +0", "0 lines, +0", "0 lines, +0", "0 lines, +0"],
		"only walls block: a door or a decoration on the line gives no cover, and neither does anything to an adjacent target", str(harmless))

# ---------------------------------------------------------------------------
#  Weapon sets: two, one in hand; every change of gear is a request
# ---------------------------------------------------------------------------

func _bag_snapshot(inv) -> Array:
	"""What is in the pack, to put back after a check: [instance, stack count]"""
	var snapshot: Array = []
	for instance in inv.items:
		snapshot.append([instance, int(instance.get("stack_count", 1))])
	return snapshot

func _bag_restore(inv, snapshot: Array):
	inv.items.clear()
	for entry in snapshot:
		entry[0]["stack_count"] = entry[1]
		inv.items.append(entry[0])

func _drag(sheet, inv, item: Dictionary, from_slot: String, to_slot: String):
	"""Drag an item on the character sheet the way the mouse does: from an
	equipment slot ("" for the pack) onto an equipment slot ("" for the pack)"""
	if from_slot == "":
		sheet.start_drag(item, "inventory", str(inv.items.find(item)))
	else:
		sheet.start_drag(item, "equipment", from_slot)
	if to_slot == "":
		sheet.end_drag_on_inventory(0)
	else:
		sheet.end_drag_on_equipment(to_slot)

func _check_weapon_sets(world):
	"""Outside a fight: the default fighter with its kit - longsword and shield
	in weapon set one, a light crossbow in set two. What a fight adds (the swap
	costs the action, the sheet cannot change gear) is checked in the staged
	fights."""
	var inv = _mgr("InventoryManager")
	var items = _mgr("ItemDatabase")
	var combat = _mgr("CombatManager")
	var bus = _mgr("EventBus")
	var builder = load("res://data/stats/character_builder.gd")
	var controller = world.combat
	var player = world.player
	var stats = player.stats
	var sheet = world.character_screen
	var sword: Dictionary = inv.get_equipped_item(stats, "main_hand")
	var shield: Dictionary = inv.get_equipped_item(stats, "off_hand")
	var crossbow: Dictionary = inv.get_equipped_item(stats, "main_hand_2")
	var bag: Array = _bag_snapshot(inv)
	var taken: Array = []
	var on_action = func(combatant, action_id, result): taken.append([combatant, action_id, result])
	controller.action_taken.connect(on_action)
	var notes: Array = []
	var on_note = func(message, _type): notes.append(message)
	bus.ui_notification.connect(on_note)

	check(not sword.is_empty() and not shield.is_empty() and not crossbow.is_empty() and inv.get_equipped_item(stats, "off_hand_2").is_empty()
		and sword.item_data.item_id == "longsword" and crossbow.item_data.item_id == "light_crossbow"
		and not inv.equipped_items[stats].has("ranged") and items.get_item("light_crossbow").equip_slot == "main_hand",
		"the fighter's kit is two weapon sets: longsword and shield in the first, the light crossbow in the second; there is no ranged slot")

	# --- every class's kit ---
	var kits: Array = []
	for class_id in ["fighter", "rogue", "wizard", "cleric"]:
		var kit_stats = builder.build(class_id, "human", {"str": 15, "dex": 14, "con": 13, "int": 12, "wis": 10, "cha": 8}, "Kit")
		for instance in items.get_starting_kit(class_id):
			inv.add_item(instance)
		inv.auto_equip_from_inventory(kit_stats)
		var held: Array = []
		for slot in ["main_hand", "off_hand", "main_hand_2", "off_hand_2", "chest"]:
			var item_data = inv.get_equipped_item(kit_stats, slot).get("item_data")
			held.append(item_data.item_id if item_data != null else "-")
		kits.append("%s: %s (AC %d, set %d)" % [class_id, " ".join(held), kit_stats.armor_class, inv.get_weapon_set(kit_stats)])
		inv.equipped_items.erase(kit_stats)
		inv.weapon_sets_in_hand.erase(kit_stats)
		_bag_restore(inv, bag)
	check(kits == ["fighter: longsword shield light_crossbow - chain_mail (AC 18, set 1)", "rogue: rapier - shortbow - leather_armor (AC 13, set 1)",
		"wizard: quarterstaff - dagger - - (AC 12, set 1)", "cleric: mace shield light_crossbow - scale_mail (AC 18, set 1)"],
		"every class's starting kit is put on in two weapon sets, the first in hand", str(kits))

	# --- one set is in hand ---
	check(player.get_weapon_set() == 1 and player.get_other_weapon_set() == 2 and player.get_weapon() == sword.item_data
		and player.get_weapon(2) == crossbow.item_data and not player.is_off_hand_free() and player.is_off_hand_free(2)
		and combat.get_attack_profile(player).weapon == sword.item_data and combat.get_set_profile(player, 2).weapon == crossbow.item_data
		and stats.armor_class == 18 and inv.get_active_equipped_items(stats).has(shield) and not inv.get_active_equipped_items(stats).has(crossbow)
		and inv.get_all_equipped_items(stats).has(crossbow),
		"an attack, and what the gear gives, come from the weapon set in hand; the other set is carried")

	# --- outside a fight the swap is a request that costs nothing ---
	taken.clear()
	var swap: Dictionary = controller.request_action(player, "swap_weapons")
	var with_crossbow: Array = [player.get_weapon_set(), stats.armor_class, combat.get_attack_profile(player).weapon_name, player.action_used]
	var back: Dictionary = controller.request_action(player, "swap_weapons")
	check(swap.ok and swap.weapon_set == 2 and with_crossbow == [2, 16, "Oak Light Crossbow", false] and taken.size() == 2
		and taken[0][0] == player and taken[0][1] == "swap_weapons" and back.ok and player.get_weapon_set() == 1 and stats.armor_class == 18,
		"outside a fight swapping weapon sets is a request that costs nothing, and the shield's armour class goes with its set",
		str(with_crossbow))

	# --- the hands of a set ---
	var bow: Dictionary = items.create_item_instance("shortbow")
	var spare_shield: Dictionary = items.create_item_instance("shield")
	var dagger: Dictionary = items.create_item_instance("dagger")
	for instance in [bow, spare_shield, dagger]:
		inv.add_item(instance)
	var bow_beside_shield: Dictionary = controller.request_action(player, "equip", {"item": bow, "slot": "main_hand"})
	var shield_beside_crossbow: Dictionary = controller.request_action(player, "equip", {"item": spare_shield, "slot": "off_hand_2"})
	var wrong_hand: Dictionary = controller.request_action(player, "equip", {"item": bow, "slot": "off_hand_2"})
	var not_carried: Dictionary = controller.request_action(player, "equip", {"item": items.create_item_instance("dagger"), "slot": "main_hand_2"})
	check(not bow_beside_shield.ok and "both hands" in bow_beside_shield.reason and inv.get_equipped_item(stats, "main_hand") == sword
		and not inv.get_item(bow.instance_id).is_empty(),
		"a bow is refused in a weapon set whose off hand holds a shield, and the request says why", str(bow_beside_shield.reason))
	check(not shield_beside_crossbow.ok and "both hands" in shield_beside_crossbow.reason and inv.get_equipped_item(stats, "off_hand_2").is_empty()
		and not wrong_hand.ok and "does not go there" in wrong_hand.reason and not not_carried.ok and not_carried.reason == "That is not in the pack",
		"a shield is refused beside a crossbow, a weapon in the wrong hand, and an item that is not carried",
		"%s / %s / %s" % [str(shield_beside_crossbow.reason), str(wrong_hand.reason), str(not_carried.reason)])

	# --- the character sheet shows both sets ---
	sheet.show_character(stats)
	await _frames(2)
	var panel_rect: Rect2 = sheet.equipment_panel.get_global_rect()
	var shown: Array = []
	var misplaced: Array = []  # what lies outside the equipment panel or over something else
	var rects: Array = []
	for slot in ["main_hand", "off_hand", "main_hand_2", "off_hand_2"]:
		var button: Button = sheet.slot_buttons.get(slot)
		var icon: TextureRect = button.get_node_or_null("ItemIcon") if button != null else null
		var item_data = inv.get_equipped_item(stats, slot).get("item_data")
		shown.append(icon != null and icon.texture == (item_data.icon if item_data != null else null))
		if button == null or not panel_rect.encloses(button.get_global_rect()):
			misplaced.append("%s outside the panel" % slot)
		else:
			for other in rects:
				if other.intersects(button.get_global_rect()):
					misplaced.append("%s over another hand" % slot)
			rects.append(button.get_global_rect())
	for other_slot in sheet.slot_buttons:
		if not other_slot in ["main_hand", "off_hand", "main_hand_2", "off_hand_2"]:
			for weapon_rect in rects:
				if weapon_rect.intersects(sheet.slot_buttons[other_slot].get_global_rect()):
					misplaced.append("%s over a hand" % other_slot)
	var sheet_swap: Button = sheet.equipment_panel.find_child("SwapWeaponsButton", true, false)
	for control in [sheet_swap, sheet.weapon_set_captions.get(1), sheet.weapon_set_captions.get(2)]:
		if control == null or not panel_rect.encloses(control.get_global_rect()):
			misplaced.append("%s outside the panel" % (str(control.name) if control != null else "a missing control"))
		else:
			for weapon_rect in rects:
				if weapon_rect.intersects(control.get_global_rect()):
					misplaced.append("%s %s over a hand %s" % [str(control.name), str(control.get_global_rect()), str(weapon_rect)])
	check(shown == [true, true, true, true] and not sheet.slot_buttons.has("ranged") and misplaced.is_empty()
		and sheet.weapon_set_captions[1].text == "WEAPON SET 1 - IN HAND" and sheet.weapon_set_captions[2].text == "WEAPON SET 2",
		"the character sheet shows both weapon sets, each hand with its item, and says which set is in hand",
		"%s, misplaced %s, '%s'" % [str(shown), str(misplaced), sheet.weapon_set_captions[1].text])

	# --- on the sheet every change of gear is a request ---
	taken.clear()
	_drag(sheet, inv, dagger, "", "main_hand_2")
	check(inv.get_equipped_item(stats, "main_hand_2") == dagger and not inv.get_item(crossbow.instance_id).is_empty()
		and taken.size() == 1 and taken[0][1] == "equip" and taken[0][0] == player,
		"dropping a weapon on a slot of the sheet asks the controller to equip it there; what the slot held goes to the pack")
	_drag(sheet, inv, dagger, "main_hand_2", "main_hand")
	check(inv.get_equipped_item(stats, "main_hand") == dagger and inv.get_equipped_item(stats, "main_hand_2") == sword
		and taken.size() == 2 and taken[1][1] == "equip" and inv.get_item(sword.instance_id).is_empty(),
		"dragging a weapon to the same hand of the other set makes the two change places")
	_drag(sheet, inv, crossbow, "", "main_hand_2")
	notes.clear()
	_drag(sheet, inv, crossbow, "main_hand_2", "main_hand")
	check(inv.get_equipped_item(stats, "main_hand") == dagger and inv.get_equipped_item(stats, "main_hand_2") == crossbow
		and notes.size() == 1 and "both hands" in notes[0],
		"a two-handed weapon cannot be dragged into the set that holds the shield, and the sheet says why", str(notes))
	_drag(sheet, inv, dagger, "main_hand", "")
	check(inv.get_equipped_item(stats, "main_hand").is_empty() and not inv.get_item(dagger.instance_id).is_empty() and taken[-1][1] == "unequip",
		"dragging an item from a slot to the pack asks the controller to unequip it")
	_drag(sheet, inv, sword, "", "main_hand")
	sheet._on_swap_weapons_pressed()
	await _frames(1)
	var ac_label: Label = sheet.stats_panel.find_child("ACLabel", true, false)
	var swapped_shown: Array = [player.get_weapon_set(), sheet.weapon_set_captions[1].text, sheet.weapon_set_captions[2].text, ac_label.text]
	sheet._on_swap_weapons_pressed()
	check(swapped_shown == [2, "WEAPON SET 1", "WEAPON SET 2 - IN HAND", "AC: 16"] and player.get_weapon_set() == 1 and taken[-1][1] == "swap_weapons",
		"the SWAP button of the sheet takes the other set in hand, and the sheet shows it", str(swapped_shown))
	sheet.hide_screen()
	paused = false

	# --- a character created over leaves nothing behind for a save to pick up ---
	# Its stats carry the same uid as the character that replaces it
	var replaced = builder.build("fighter", "human", {"str": 15, "dex": 14, "con": 13, "int": 12, "wis": 10, "cha": 8}, "Replaced")
	inv.equipped_items[replaced] = {}
	inv.set_weapon_set(replaced, 2)
	inv.forget_character(replaced)
	var forgotten: bool = not inv.equipped_items.has(replaced) and not inv.weapon_sets_in_hand.has(replaced)
	inv.weapon_sets_in_hand[replaced] = 2
	var saved_sets: Dictionary = inv.to_dict()["weapon_sets"]
	inv.weapon_sets_in_hand.erase(replaced)
	check(forgotten and replaced.character_uid == stats.character_uid and saved_sets.size() == 1 and int(saved_sets.get("player", 0)) == 1,
		"a save takes the set in hand from the characters whose gear it holds, not from one that was created over", str(saved_sets))

	# --- enemies and companions: set one, a second if they have one ---
	var enemy = world.enemies[0]
	var no_second: Dictionary = controller.check_action(enemy, "swap_weapons")
	enemy.second_weapon = items.get_item("shortbow")
	var enemy_swap: Dictionary = controller.request_action(enemy, "swap_weapons")
	var enemy_holds = enemy.get_weapon()
	controller.request_action(enemy, "swap_weapons")
	enemy.second_weapon = null
	check(not no_second.ok and no_second.reason == "No second weapon set" and enemy_swap.ok and enemy_holds == items.get_item("shortbow")
		and enemy.get_weapon_set() == 1 and enemy.get_weapon_set_count() == 1 and enemy.get_weapon().item_name == "Enemy Weapon",
		"an enemy fights with its first weapon set; a second is optional, and swapped to the same way", str(no_second.reason))

	controller.action_taken.disconnect(on_action)
	bus.ui_notification.disconnect(on_note)
	_bag_restore(inv, bag)
	stats.current_hp = stats.max_hp
	await _frames(2)
	check(inv.get_equipped_item(stats, "main_hand") == sword and inv.get_equipped_item(stats, "off_hand") == shield
		and inv.get_equipped_item(stats, "main_hand_2") == crossbow and inv.get_equipped_item(stats, "off_hand_2").is_empty()
		and player.get_weapon_set() == 1 and stats.armor_class == 18,
		"test teardown: the starting kit is back in its two sets, the first in hand")

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
	var swap_button = bar.get_button("swap_weapons")
	check(not attack_button.disabled and attack_button.get_detail() == "Longsword\n1d8+2 slashing" and attack_button.get_reason() == "",
		"the Attack button names the weapon in hand and its damage", attack_button.get_detail())
	check(not swap_button.disabled and swap_button.get_title() == "Swap" and swap_button.get_detail() == "Light Crossbow\n1d8+1 piercing",
		"the Swap button shows what the other weapon set holds", swap_button.get_detail())
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
	check(not hit.is_empty() and hit.weapon_name == "Wrought Iron Longsword" and hit.damage_dice == "1d8" and hit.damage_type == "slashing"
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

	# --- nothing in hand (ranged weapons and the swap have their own checks, _check_ranged) ---
	var sword: Dictionary = inv.unequip_item(stats, "main_hand")
	_toughen(stats)
	await _frames(2)
	check(attack_button.get_detail() == "Unarmed strike\n3 bludgeoning", "with nothing in hand the Attack button offers an unarmed strike",
		attack_button.get_detail())
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
	_toughen(stats)

	# --- gear cannot be changed from the sheet in a fight ---
	var spare: Dictionary = items.create_item_instance("dagger")
	inv.add_item(spare)
	player.refresh_turn_resources()
	notes.clear()
	sheet.show_character(stats)
	_drag(sheet, inv, spare, "", "main_hand")
	_drag(sheet, inv, inv.get_equipped_item(stats, "off_hand"), "off_hand", "")
	_drag(sheet, inv, sword, "main_hand", "main_hand_2")
	sheet.hide_screen()
	var gear_request: Dictionary = controller.request_action(player, "unequip", {"slot": "chest"})
	check(inv.get_equipped_item(stats, "main_hand") == sword and not inv.get_equipped_item(stats, "off_hand").is_empty()
		and not inv.get_item(spare.instance_id).is_empty() and not inv.get_equipped_item(stats, "chest").is_empty()
		and notes == [controller.REASON_GEAR_IN_FIGHT, controller.REASON_GEAR_IN_FIGHT, controller.REASON_GEAR_IN_FIGHT]
		and not gear_request.ok and gear_request.reason == controller.REASON_GEAR_IN_FIGHT and not player.action_used,
		"in a fight the character sheet cannot equip, unequip or move gear: each request is refused and says to swap weapon sets", str(notes))
	inv.remove_item(spare.instance_id)

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
	_press(KEY_7)
	check(player.action_used and player.get_weapon_set() == 2, "key 7 takes the Swap action")
	player.refresh_turn_resources()
	controller.request_action(player, "swap_weapons")
	_toughen(stats)
	player.refresh_turn_resources()
	_press(KEY_1)
	await _frames(2)
	check(player.attack_mode and attack_button.button_pressed and "click a marked enemy" in bar._hint.text,
		"key 1 starts aiming the Attack action, and the bar shows it", bar._hint.text)
	_press(KEY_1)
	check(not player.attack_mode, "key 1 again puts the attack away")
	_press(KEY_1)
	notes.clear()
	_click(attack_button.get_global_rect().get_center())
	await _frames(1)
	check(notes.is_empty() and not player.is_moving and not player.is_path_selected,
		"a click on the action bar is not a click on the map behind it", str(notes))
	check(not player.attack_mode, "clicking the Attack button while aiming puts the attack away")
	player.attack_mode = false
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
	_press(KEY_8)
	check(controller.is_turn_of(goblin), "key 8 ends the turn")
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

	# --- the fight ends; outside one nothing is spent ---
	combat_mgr.deal_damage(player, goblin, 9999)
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

	# --- outside a fight a move is still a request, with no movement to count ---
	var stroll_to: Vector2i = player.grid_position
	for tile in _open_tiles_near(world, player.grid_position, 4, 6, 12):
		var clear := true
		for enemy in world.enemies:
			if is_instance_valid(enemy) and enemy.is_alive() and Vector2(enemy.grid_position - tile).length() < 14.0:
				clear = false
		if clear:
			stroll_to = tile
			break
	check(stroll_to != player.grid_position, "test setup: somewhere to walk to, well away from any enemy")
	taken.clear()
	var strolled: bool = await _walk(player, stroll_to)
	var stroll: Array = taken.filter(func(entry): return entry[0] == player and entry[1] == "move")
	check(strolled and not world.in_combat and stroll.size() == 1 and stroll[0][2].steps >= 4 and player.movement_left == 0,
		"outside a fight a move is still a request to the controller, and needs no movement", "%d requests" % stroll.size())
	if kaelen != null and is_instance_valid(kaelen):
		var near_enough = func(): return not kaelen.is_moving and Vector2(kaelen.grid_position - player.grid_position).length() < 3.0
		var caught_up: bool = await _until(near_enough, 8.0)
		var follow: Array = taken.filter(func(entry): return entry[0] == kaelen and entry[1] == "move")
		check(caught_up and not follow.is_empty(), "outside a fight a companion follows the player, asking for its moves", "%d requests" % follow.size())
		comp.dismiss("kaelen")
		await _wait(0.2)

	# --- the turn mode outside a fight counts movement out, and nothing else ---
	var beside: Array = _open_tiles_near(world, player.grid_position, 1, 1, 1)
	player.toggle_turn_based_mode()
	var granted: int = player.movement_left
	if not beside.is_empty():
		await _walk(player, beside[0])
	var after_step: int = player.movement_left
	await _frames(2)
	var mode_shown: String = "%s | %s" % [bar._turn_label.text, bar._movement_label.text]
	var end_open: bool = not bar.get_button("end_turn").disabled
	var dodge_in_turn_mode: Dictionary = controller.request_action(player, "dodge")
	_press(KEY_SPACE)
	check(player.turn_based_mode and not world.in_combat and granted == 6 and after_step == 5 and player.movement_left == 6,
		"in the turn mode outside a fight a turn's movement is counted out, and SPACE starts a new turn",
		"%d, %d, %d" % [granted, after_step, player.movement_left])
	check(mode_shown == "Turn mode | Movement 5 / 6" and end_open and not dodge_in_turn_mode.ok and not player.action_used,
		"the turn mode has no action economy: End Turn is open, Dodge is not", mode_shown)
	player.toggle_turn_based_mode()
	check(not player.turn_based_mode, "test teardown: back to free movement")

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

# ---------------------------------------------------------------------------
#  The set in hand: sword or crossbow, and the swap; range, sight and cover
# ---------------------------------------------------------------------------

func _find_strip(world, origin: Vector2i, length: int) -> Array:
	"""[start, step, side]: `length` free floor tiles in a straight line from
	start, each with free floor on both sides of it, as near to origin as there
	is such a strip. A shot along it has a clear line and no wall near enough
	to give cover, and nobody stands next to start. start may be the player's
	own tile. A strip that runs left or right is preferred to one that runs up
	or down. [] when there is none."""
	var player = world.player
	for steps in [[Vector2i(1, 0), Vector2i(-1, 0)], [Vector2i(0, 1), Vector2i(0, -1)]]:
		for radius in range(0, 30):
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					if max(abs(dx), abs(dy)) != radius:
						continue
					var start: Vector2i = origin + Vector2i(dx, dy)
					var crowded := false
					for nx in range(-1, 2):
						for ny in range(-1, 2):
							if world.is_tile_occupied(start + Vector2i(nx, ny), player):
								crowded = true
					if crowded:
						continue
					for step in steps:
						var side := Vector2i(step.y, step.x)
						var open := true
						for i in range(length):
							for tile in [start + step * i, start + step * i + side, start + step * i - side]:
								if open and tile != player.grid_position and not player.is_walkable(tile):
									open = false
						if open:
							return [start, step, side]
	return []

func _count_nodes(parent: Node, script: Script) -> int:
	"""How many children of parent are instances of a script"""
	var count := 0
	for child in parent.get_children():
		if is_instance_of(child, script) and not child.is_queued_for_deletion():
			count += 1
	return count

func _attack_until_hit(controller, attacker, target, blows: Array) -> Dictionary:
	"""Ask for the Attack action, the action handed back each time, until an
	attack lands. For a target that only a natural 1 misses. Returns the
	request's result with hp_lost added; {} when the request is refused or
	nothing lands in 40 tries. blows is left holding the damage events of the
	attack that landed."""
	for attempt in range(40):
		attacker.action_used = false
		blows.clear()
		var hp_before: int = target.stats.current_hp
		var attack: Dictionary = controller.request_action(attacker, "attack", {"target": target})
		if not attack.ok:
			return {}
		if attack.hit:
			attack["hp_lost"] = hp_before - target.stats.current_hp
			return attack
	return {}

func _remove_enemy(world, enemy):
	"""Take a staged enemy out of the world without a death: no XP, no loot"""
	world.combat.remove_combatant(enemy)
	world.enemies.erase(enemy)
	enemy.queue_free()

func _close_to(value: float, expected: float) -> bool:
	return absf(value - expected) < 0.000001

func _is_beyond(rect: Rect2, target, shooter) -> bool:
	"""True when a rectangle of the screen lies wholly on the side of the
	target that is away from the shooter, left or right"""
	var target_x: float = target.get_global_transform_with_canvas().origin.x
	if shooter.get_global_transform_with_canvas().origin.x < target_x:
		return rect.position.x > target_x
	return rect.end.x < target_x

func _check_ranged(world):
	"""A staged fight on a strip of open floor: the default fighter (STR 14,
	DEX 12, proficiency +2; longsword and shield in weapon set one, a light
	crossbow in set two) and a goblin that stands still a few tiles away. Checks
	that an attack is made with the set in hand and nothing else, and what
	swapping sets costs; what range, line of sight, cover and a hostile next to
	the shooter do to a shot; that the chance shown before the shot is the
	exact one; what aiming shows; and that an enemy shoots through the same
	request."""
	var combat_mgr = _mgr("CombatManager")
	var effects = _mgr("StatusEffectManager")
	var inv = _mgr("InventoryManager")
	var items = _mgr("ItemDatabase")
	var bus = _mgr("EventBus")
	var projectile_script = load("res://scripts/projectile.gd")
	var popup_script = load("res://scripts/damage_popup.gd")
	var item_script = load("res://data/items/item_data.gd")
	var controller = world.combat
	var player = world.player
	var stats = player.stats
	var bar = world.bottom_ui.action_bar
	var attack_button = bar.get_button("attack")
	var swap_button = bar.get_button("swap_weapons")
	var readout = world.attack_preview
	var grid: Array = world.current_dungeon.dungeon_grid
	var wall: int = world.current_dungeon.TileType.WALL
	var piercing: int = combat_mgr.DamageType.PIERCING
	var home: Vector2i = player.grid_position
	var sword: Dictionary = inv.get_equipped_item(stats, "main_hand")
	var shield: Dictionary = inv.get_equipped_item(stats, "off_hand")
	var crossbow: Dictionary = inv.get_equipped_item(stats, "main_hand_2")

	var strip: Array = _find_strip(world, home, 8)
	var set_up: bool = not strip.is_empty() and not world.in_combat and not sword.is_empty() and not crossbow.is_empty() and not shield.is_empty() \
		and player.get_weapon_set() == 1 and stats.class_id == "fighter" and stats.get_str_modifier() == 2 and stats.get_dex_modifier() == 1 \
		and stats.proficiency_bonus == 2
	check(set_up, "test setup: a strip of open floor, and the fighter with its longsword and shield in hand and its crossbow in the second set")
	if not set_up:
		return
	var here: Vector2i = strip[0]
	var step: Vector2i = strip[1]
	var side: Vector2i = strip[2]
	if here != home:
		player.teleport_to_grid(here)
	_toughen(stats)
	# Where a check puts a wall, in the rules' grid only, between the shooter and
	# the target four tiles off; it is floor again when the check is done
	var wall_tile: Vector2i = here + step * 2
	var wall_was: int = grid[wall_tile.y][wall_tile.x]

	var taken: Array = []  # [combatant, action id, result] for every approved request
	var on_action = func(combatant, action_id, result): taken.append([combatant, action_id, result])
	controller.action_taken.connect(on_action)
	var blows: Array = []  # [attacker, target, amount, damage type]
	var on_damage = func(attacker, target, amount, _is_crit, damage_type): blows.append([attacker, target, amount, damage_type])
	bus.damage_dealt.connect(on_damage)
	var notes: Array = []
	var on_note = func(message, _type): notes.append(message)
	bus.ui_notification.connect(on_note)

	# The target: four tiles off, in plain sight, and it stays where it is put
	var far = world._spawn_enemy("goblin", 1, 500, here + step * 4)
	far.stats.movement_speed = 0
	far.stats.armor_class = 13
	Engine.time_scale = 4.0
	var started: bool = await _until(func(): return world.in_combat, 3.0)
	for other in controller.get_order():
		if other != player and other != far:
			controller.remove_combatant(other)
	var my_turn: bool = started and await _until(func(): return controller.is_turn_of(player) or not world.in_combat)
	check(started and my_turn and controller.is_turn_of(player) and controller.get_order().size() == 2,
		"test setup: the staged fight started, the player against a goblin four tiles away, and the player's turn came",
		"%d in the order" % controller.get_order().size())
	if not controller.is_turn_of(player):
		Engine.time_scale = 1.0
		return

	# --- the set in hand, and only that: a sword does not reach four tiles ---
	var blocked_check: Dictionary = controller.check_action(player, "attack")
	var blocked_shot: Dictionary = controller.request_action(player, "attack", {"target": far})
	await _frames(2)
	check(not blocked_check.ok and blocked_check.reason == "No enemy in reach - swap to the Oak Light Crossbow"
		and not blocked_shot.ok and blocked_shot.reason == "Out of reach - swap to the Oak Light Crossbow"
		and not player.action_used and far.stats.current_hp == 500 and controller.get_attack_targets(player).is_empty(),
		"Attack uses only the weapon set in hand: with sword and shield an enemy four tiles off cannot be attacked, and the refusal says to swap to the crossbow",
		"%s / %s" % [str(blocked_check.get("reason", "")), str(blocked_shot.get("reason", ""))])
	check(attack_button.disabled and attack_button.get_reason() == blocked_check.reason and attack_button.get_detail() == "Longsword\n1d8+2 slashing"
		and not swap_button.disabled and swap_button.get_title() == "Swap" and swap_button.get_detail() == "Light Crossbow\n1d8+1 piercing",
		"the Attack button names the weapon in hand and says to swap; the Swap button shows what the other set holds",
		"%s / %s / %s" % [attack_button.get_detail(), attack_button.get_reason(), swap_button.get_detail()])

	# --- swapping sets: a request, the action in a fight ---
	var ac_with_shield: int = stats.armor_class
	taken.clear()
	var swap: Dictionary = controller.request_action(player, "swap_weapons")
	_toughen(stats)  # here and below: a change of gear works the character's numbers out again
	check(swap.ok and swap.weapon_set == 2 and player.get_weapon_set() == 2 and player.action_used and swap.weapon_name == "Oak Light Crossbow"
		and taken.size() == 1 and taken[0][0] == player and taken[0][1] == "swap_weapons",
		"swapping weapon sets is a request the controller approves, and in a fight it costs the action", str(swap))
	check(ac_with_shield == 18 and stats.armor_class == 16 and stats.shield_name == "" and not player.is_off_hand_free(1) and player.is_off_hand_free(),
		"the shield goes away with its set: armour class 18 with it in hand, 16 with the crossbow", "AC %d" % stats.armor_class)
	var second_swap: Dictionary = controller.request_action(player, "swap_weapons")
	var attack_after_swap: Dictionary = controller.request_action(player, "attack", {"target": far})
	await _frames(2)
	check(not second_swap.ok and second_swap.reason == "Action spent" and player.get_weapon_set() == 2
		and not attack_after_swap.ok and attack_after_swap.reason == "Action spent" and far.stats.current_hp == 500,
		"the swap was the turn's action: no second swap and no attack after it", "%s / %s" % [str(second_swap.reason), str(attack_after_swap.reason)])
	check(swap_button.disabled and swap_button.get_reason() == "Action spent" and swap_button.get_detail() == "Longsword\n+ Shield"
		and attack_button.get_detail() == "Light Crossbow\n1d8+1 piercing",
		"the bar follows the swap: Attack names the crossbow, Swap the sword and shield", "%s / %s" % [attack_button.get_detail(), swap_button.get_detail()])
	player.refresh_turn_resources()  # test setup, here and below: a fresh turn's resources without waiting a round

	# --- the ranged weapon in hand ---
	var profile: Dictionary = combat_mgr.get_attack_profile(player)
	check(profile.weapon == crossbow.item_data and profile.is_ranged and profile.usable and profile.ability == "dex" and profile.ability_modifier == 1
		and profile.proficient and profile.attack_bonus == 3 and profile.damage_dice == "1d8" and profile.damage_type == "piercing"
		and profile.range_normal == 16 and profile.range_max == 64 and _damage_range(combat_mgr, profile) == [2, 9],
		"with the second set in hand the attack is made with its ranged weapon: Dexterity for the roll and the damage, its die, its damage type",
		"%s %s %+d %s %s" % [profile.weapon_name, profile.ability, profile.attack_bonus, profile.damage_dice, profile.damage_type])
	check(controller.check_action(player, "attack").ok and controller.get_attack_targets(player).has(far),
		"with the crossbow in hand the enemy in range and in sight can be attacked")

	far.stats.armor_class = -100
	var popups_before: int = _count_nodes(world, popup_script)
	var shot: Dictionary = _attack_until_hit(controller, player, far, blows)
	var in_flight: int = _count_nodes(world, projectile_script)
	var popups_in_flight: int = _count_nodes(world, popup_script)
	check(not shot.is_empty() and shot.weapon_name == "Oak Light Crossbow" and shot.is_ranged and shot.damage_dice == "1d8"
		and shot.damage_type == "piercing" and shot.attack_bonus == 3 and shot.distance == 4 and not shot.disadvantage
		and shot.damage >= (3 if shot.is_crit else 2) and shot.damage <= (17 if shot.is_crit else 9) and shot.hp_lost == shot.damage
		and blows.size() == 1 and blows[0][0] == player and blows[0][1] == far and blows[0][2] == shot.damage and blows[0][3] == piercing,
		"the Attack action on a distant enemy shoots the ranged weapon in hand, a plain roll at normal range, and its damage is piercing",
		str(shot.get("damage", "no hit")))
	var landed: bool = await _until(func(): return _count_nodes(world, projectile_script) == 0, 3.0)
	check(in_flight >= 1 and popups_in_flight == popups_before and landed and _count_nodes(world, popup_script) > popups_before,
		"a ranged attack sends a projectile to the target, and the number appears when it lands",
		"%d in flight, popups %d -> %d -> %d" % [in_flight, popups_before, popups_in_flight, _count_nodes(world, popup_script)])
	var hp_after_shot: int = far.stats.current_hp
	var again: Dictionary = controller.request_action(player, "attack", {"target": far})
	check(player.action_used and not again.ok and again.reason == "Action spent" and far.stats.current_hp == hp_after_shot,
		"a second shot in the same turn is refused: the action is spent", str(again))

	# --- an enemy in reach as well: it is shot too, and that spoils every shot ---
	var near = world._spawn_enemy("goblin", 1, 500, here + side)
	near.stats.movement_speed = 0
	near.stats.armor_class = -100
	var point_blank: Dictionary = _attack_until_hit(controller, player, near, blows)
	check(not point_blank.is_empty() and point_blank.weapon_name == "Oak Light Crossbow" and point_blank.is_ranged and point_blank.distance == 1
		and point_blank.disadvantage and "enemy adjacent" in point_blank.reasons,
		"with a ranged weapon in hand an adjacent enemy is shot, at disadvantage: Attack never reaches for the other set",
		str(point_blank.get("weapon_name", "refused")))
	check(controller.get_order().has(near) and controller.is_turn_of(player),
		"a hostile that is attacked from outside the fight joins it, without taking the turn", "%d in the order" % controller.get_order().size())
	player.reaction_used = false
	var snap: Dictionary = combat_mgr.trigger_opportunity_attack(player, near)
	check(snap.triggered and snap.result.weapon_name == "Unarmed strike" and not snap.result.is_ranged and player.reaction_used,
		"an opportunity attack is never a shot: with a ranged weapon in hand it is an unarmed strike", str(snap.get("reason", "")))
	player.reaction_used = false

	far.stats.armor_class = 13
	var crowded: Dictionary = combat_mgr.get_hit_chance(player, far)
	player.action_used = false
	var crowded_shot: Dictionary = controller.request_action(player, "attack", {"target": far})
	effects.apply_effect(near, "stunned", 5)
	var beside_stunned: Dictionary = combat_mgr.get_hit_chance(player, far)
	effects.clear_effects(near)
	check(crowded.disadvantage and ", ".join(crowded.reasons) == "enemy adjacent" and crowded_shot.ok and crowded_shot.disadvantage
		and "enemy adjacent" in crowded_shot.reasons and not beside_stunned.disadvantage and beside_stunned.reasons.is_empty(),
		"a ranged attack has disadvantage while a hostile that is not incapacitated stands next to the shooter",
		"%s / stunned: %s" % [str(crowded.reasons), str(beside_stunned.reasons)])

	# --- aiming: who can be attacked is marked, and the readout says what the attack would be ---
	player.refresh_turn_resources()
	_press(KEY_1)
	player._update_aim(far.grid_position)
	readout.refresh()
	var aimed: Dictionary = player.get_aim_preview()
	var lines: Array = readout.get_lines()
	var readout_rect: Rect2 = readout._panel.get_global_rect()
	check(player.attack_mode and player.get_aim_targets().has(far) and player.get_aim_targets().has(near),
		"while an attack is aimed every enemy that can be attacked is marked: the one in reach and the one in range and in sight",
		"%d marked" % player.get_aim_targets().size())
	check(aimed.get("ok", false) and aimed.target == far and aimed.weapon_name == "Oak Light Crossbow" and aimed.damage_text == "1d8+1 piercing"
		and aimed.hit_chance.percent == 30 and aimed.hit_chance.disadvantage and aimed.distance == 4,
		"resting the pointer on an enemy asks the controller what attacking it would be: weapon, chance, damage, and why", str(aimed.get("reason", "")))
	check(lines == ["Goblin", "Oak Light Crossbow", "30% to hit", "1d8+1 piercing damage", "Disadvantage: enemy adjacent"],
		"the readout beside the enemy shows the weapon, the chance to hit, the damage and the reason for disadvantage", str(lines))
	var answers: Array = []
	for nature in [[["piercing"], [], []], [[], ["piercing"], []], [[], [], ["piercing"]], [["slashing"], ["fire"], ["cold"]]]:
		_set_nature(far, nature[0], nature[1], nature[2])
		player._update_aim(far.grid_position)
		readout.refresh()
		answers.append(" | ".join(readout.get_lines().slice(4)))
	_set_nature(far, [], [], [])
	player._update_aim(far.grid_position)
	readout.refresh()
	check(answers == ["Resists piercing: half damage | Disadvantage: enemy adjacent", "Vulnerable to piercing: double damage | Disadvantage: enemy adjacent",
		"Immune to piercing: no damage | Disadvantage: enemy adjacent", "Disadvantage: enemy adjacent"]
		and readout.get_lines() == lines,
		"before the player commits, the readout says when the enemy resists the weapon's damage, is vulnerable to it or immune", str(answers))
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(readout.is_showing() and screen.encloses(readout_rect) and readout_rect.end.y <= world.bottom_ui.get_global_rect().position.y,
		"the readout is on the screen and clear of the bottom bar", str(readout_rect))
	# The same with the edge it must keep clear of moved up to just above the enemy
	var ledge := Control.new()
	root.add_child(ledge)
	ledge.position = Vector2(0, far.get_global_transform_with_canvas().origin.y - 20.0)
	ledge.size = Vector2(screen.size.x, 400)
	readout.setup(player, ledge)
	var squeezed: Rect2 = readout._panel.get_global_rect()
	var ledge_top: float = ledge.position.y
	readout.setup(player, world.bottom_ui)
	ledge.free()
	check(ledge_top > squeezed.size.y + 16.0 and squeezed.end.y <= ledge_top and screen.encloses(squeezed),
		"the readout moves up rather than cover the HUD it is told to keep clear of", "%s above %d" % [str(squeezed), ledge_top])
	# Seen from either side, the readout is beyond the enemy: the line from the shooter stays in view
	var beyond_first: bool = _is_beyond(readout_rect, far, player)
	player.teleport_to_grid(here + step * 6)
	player._update_aim(far.grid_position)
	readout.refresh()
	var beyond_second: bool = _is_beyond(readout._panel.get_global_rect(), far, player)
	player.teleport_to_grid(here)
	check(step.y == 0 and beyond_first and beyond_second,
		"the readout sits beyond the enemy, away from the shooter, on whichever side that is", "%s, %s" % [beyond_first, beyond_second])
	player._update_aim(near.grid_position)
	readout.refresh()
	check(player.get_aim_preview().get("weapon_name", "") == "Oak Light Crossbow" and readout.get_lines().slice(0, 2) == ["Goblin", "Oak Light Crossbow"]
		and readout.get_lines()[-1] == "Disadvantage: enemy adjacent",
		"on an enemy in reach the readout names the weapon in hand all the same, and the disadvantage of shooting it", str(readout.get_lines()))
	# The mouse itself: the pointer moved onto the far goblin, and then onto the bottom bar
	var camera_still: bool = await _camera_at_rest(far)
	_move_pointer(_on_screen(far))
	await _frames(3)
	var pointed_at = player.get_aim_preview().get("target")
	var pointed_tile: Vector2i = player._pointer_tile()
	var pointed_lines: Array = readout.get_lines()
	_move_pointer(world.bottom_ui.get_global_rect().get_center())
	await _frames(3)
	check(camera_still and pointed_tile == far.grid_position and pointed_at == far and pointed_lines.slice(0, 2) == ["Goblin", "Oak Light Crossbow"],
		"with the mouse pointer on an enemy the readout shows that enemy", "%s: %s" % [str(pointed_tile), str(pointed_lines)])
	check(player.attack_mode and player._pointer_tile() == Vector2i(-1, -1) and player.get_aim_preview().is_empty() and not readout.is_showing(),
		"with the mouse pointer on the bottom bar no tile of the map is pointed at, and the readout is gone", str(player._pointer_tile()))
	_move_pointer(Vector2.ZERO)
	check(attack_button.button_pressed and "click a marked enemy" in bar._hint.text
		and "Oak Light Crossbow to 16 tiles (to 64 at disadvantage)" in bar._hint.text and not "Longsword" in bar._hint.text,
		"while aiming, the bar says how far the weapon in hand reaches", bar._hint.text)

	grid[wall_tile.y][wall_tile.x] = wall
	player._update_aim(far.grid_position)
	readout.refresh()
	var blocked_lines: Array = readout.get_lines()
	var marked_behind_wall: bool = player.get_aim_targets().has(far)
	notes.clear()
	player._handle_attack_click(far.grid_position)
	check(not marked_behind_wall and blocked_lines == ["Goblin", "Cannot attack: No line of sight"],
		"an enemy that cannot be attacked is not marked, and the readout says why", str(blocked_lines))
	check(notes == ["No line of sight"] and player.attack_mode and not player.action_used,
		"a click on an enemy that cannot be attacked says why and leaves the attack selected", str(notes))
	grid[wall_tile.y][wall_tile.x] = wall_was
	taken.clear()
	player._handle_attack_click(far.grid_position)
	check(taken.size() == 1 and taken[0][0] == player and taken[0][1] == "attack" and taken[0][2].target == far and taken[0][2].is_ranged
		and player.action_used and not player.attack_mode,
		"a click on a marked enemy sends the attack request and puts the attack away", "%d requests" % taken.size())
	await _frames(2)
	check(not readout.is_showing(), "the readout goes away with the aim")

	# --- the first set back in hand: the sword for the enemy in reach ---
	player.refresh_turn_resources()
	notes.clear()
	_press(KEY_1)
	_press(KEY_7)
	_toughen(stats)
	check(player.get_weapon_set() == 1 and player.action_used and not player.attack_mode and notes == ["In hand: Wrought Iron Longsword."],
		"key 7 swaps the weapon sets, says what is in hand now, and puts an aimed attack away", str(notes))
	player.refresh_turn_resources()
	await _until(func(): return _count_nodes(world, projectile_script) == 0, 3.0)  # the last shot has landed
	var swing: Dictionary = _attack_until_hit(controller, player, near, blows)
	check(not swing.is_empty() and swing.weapon_name == "Wrought Iron Longsword" and not swing.is_ranged and swing.damage_type == "slashing"
		and swing.attack_bonus == 4 and swing.distance == 1 and _count_nodes(world, projectile_script) == 0,
		"with the first set back in hand the enemy in reach is struck with the sword", str(swing.get("weapon_name", "refused")))

	# --- what the target is to the damage shows on the number over its head ---
	_set_nature(near, [], ["slashing"], [])
	var doubled: Dictionary = _attack_until_hit(controller, player, near, blows)
	var doubled_popup = _newest_popup(world)
	_set_nature(near, [], [], [])
	check(not doubled.is_empty() and doubled.damage == doubled.damage_rolled * 2 and doubled.damage_response == "vulnerable"
		and doubled.hp_lost == doubled.damage and blows.size() == 1 and blows[0][2] == doubled.damage
		and doubled_popup != null and doubled_popup.response == "vulnerable" and doubled_popup.damage == doubled.damage,
		"the Attack action on a vulnerable enemy does double damage, and the number over its head says so",
		"%s of %s" % [str(doubled.get("damage", "?")), str(doubled.get("damage_rolled", "?"))])
	_remove_enemy(world, near)

	# --- range: plain up to normal, disadvantage up to the maximum, then not at all ---
	# A bow of the test's own with a short reach, in the second set: 2 tiles normal, 5 at most
	player.refresh_turn_resources()
	controller.request_action(player, "swap_weapons")
	var short_bow = item_script.new()
	short_bow.item_id = "smoke_shortbow"
	short_bow.item_name = "Test Bow"
	short_bow.item_type = item_script.ItemType.WEAPON
	short_bow.is_weapon = true
	short_bow.is_ranged = true
	short_bow.is_two_handed = true
	short_bow.weapon_type = "shortbow"
	short_bow.weapon_category = "simple"
	short_bow.damage_dice = "1d6"
	short_bow.damage_type = "piercing"
	short_bow.range_normal = 2
	short_bow.range_max = 5
	short_bow.equip_slot = "main_hand"
	var test_bow: Dictionary = {"item_data": short_bow}
	inv.add_item(test_bow)
	inv.equip_item(test_bow, stats, "main_hand_2")
	_toughen(stats)
	var bands: Array = []
	for tiles in [2, 3, 5, 6]:
		far.teleport_to_grid(here + step * tiles)
		var chance: Dictionary = combat_mgr.get_hit_chance(player, far)
		var hp_before: int = far.stats.current_hp
		player.action_used = false
		var try_shot: Dictionary = controller.request_action(player, "attack", {"target": far})
		if try_shot.ok:
			bands.append("%d: %s (%s)" % [tiles, "disadvantage" if try_shot.disadvantage else "plain", ", ".join(chance.reasons)])
		else:
			bands.append("%d: %s, action %s, %d damage" % [tiles, try_shot.reason, "spent" if player.action_used else "kept",
				hp_before - far.stats.current_hp])
	check(bands == ["2: plain ()", "3: disadvantage (long range)", "5: disadvantage (long range)",
		"6: Out of range - Test Bow reaches 5 tiles, action kept, 0 damage"],
		"a shot is plain up to the weapon's normal range, at disadvantage up to its maximum, and refused beyond it", str(bands))

	# --- line of sight ---
	far.teleport_to_grid(here + step * 4)
	grid[wall_tile.y][wall_tile.x] = wall
	player.action_used = false
	var hp_before_wall: int = far.stats.current_hp
	var walled: Dictionary = controller.request_action(player, "attack", {"target": far})
	var seen_through_wall: bool = controller.get_attack_targets(player).has(far)
	grid[wall_tile.y][wall_tile.x] = wall_was
	check(not walled.ok and walled.reason == "No line of sight" and not player.action_used and far.stats.current_hp == hp_before_wall
		and not seen_through_wall and controller.check_action(player, "attack", {"target": far}).ok,
		"a wall between the shooter and the target blocks the shot: the attack is refused", str(walled.get("reason", "")))

	# --- a gap of no width: nothing is shot between two wall corners that touch ---
	# The goblin stands two tiles off diagonally; the two tiles beside the
	# shooter's corner on that side become walls, in the rules' grid only
	var gap_tiles: Array = [here + step, here + side]
	var beyond_gap: Vector2i = here + step * 2 + side * 2
	var in_bounds: bool = beyond_gap.y >= 0 and beyond_gap.y < grid.size() and beyond_gap.x >= 0 and beyond_gap.x < grid[0].size()
	var through_gap: Dictionary = {}
	var straight_line_clear := false
	var marked_through_gap := true
	if in_bounds:
		var beyond_was: int = grid[beyond_gap.y][beyond_gap.x]
		grid[beyond_gap.y][beyond_gap.x] = world.current_dungeon.TileType.FLOOR
		var stands: bool = far.teleport_to_grid(beyond_gap)
		for tile in gap_tiles:
			grid[tile.y][tile.x] = wall
		player.action_used = false
		if stands:
			through_gap = controller.request_action(player, "attack", {"target": far})
			marked_through_gap = controller.get_attack_targets(player).has(far)
			straight_line_clear = load("res://scripts/combat_grid.gd").has_line_of_sight(here, beyond_gap, grid)
		for tile in gap_tiles:
			grid[tile.y][tile.x] = world.current_dungeon.TileType.FLOOR
		far.teleport_to_grid(here + step * 4)
		grid[beyond_gap.y][beyond_gap.x] = beyond_was
	check(straight_line_clear and not through_gap.get("ok", true) and through_gap.get("reason", "") == "No line of sight" and not marked_through_gap
		and not player.action_used and far.grid_position == here + step * 4,
		"a shot through a gap of no width between two wall corners is refused, though the straight line between the two tiles is clear",
		str(through_gap.get("reason", "not staged")))

	# --- the chance to hit, before anything is rolled ---
	# The crossbow again: +3 to hit against armour class 13 needs a 10 on the die
	inv.equip_item(crossbow, stats, "main_hand_2")
	inv.remove_item(test_bow.instance_id)
	_toughen(stats)
	# For cover the goblin steps one tile aside, and two walls go up in the
	# rules' grid: one beside the shooter's line, one whose corner the shot
	# has to pass. A wall next to the goblin, off the line, gives it none.
	var in_line: Vector2i = far.grid_position
	var aside: Vector2i = in_line + side
	var corner_tiles: Array = [here + step + side, here + step * 3]
	var corner_was: Array = [grid[corner_tiles[0].y][corner_tiles[0].x], grid[corner_tiles[1].y][corner_tiles[1].x]]
	var aside_was: int = grid[aside.y][aside.x]
	seed(20261117)
	var next_roll: int = randi()
	seed(20261117)
	var plain: Dictionary = combat_mgr.get_hit_chance(player, far)
	effects.apply_effect(far, "stunned", 5)
	var with_advantage: Dictionary = combat_mgr.get_hit_chance(player, far)
	effects.apply_effect(player, "poisoned", 5)
	var with_both: Dictionary = combat_mgr.get_hit_chance(player, far)
	effects.clear_effects(far)
	var with_disadvantage: Dictionary = combat_mgr.get_hit_chance(player, far)
	effects.clear_effects(player)
	grid[aside.y][aside.x] = wall
	var beside_wall: Dictionary = combat_mgr.get_hit_chance(player, far)
	grid[aside.y][aside.x] = aside_was
	far.teleport_to_grid(aside)
	for tile in corner_tiles:
		grid[tile.y][tile.x] = wall
	var behind_cover: Dictionary = combat_mgr.get_hit_chance(player, far)
	var previewed: Dictionary = controller.preview_attack(player, far)
	controller.get_attack_targets(player)
	far.stats.armor_class = 100
	var hopeless: Dictionary = combat_mgr.get_hit_chance(player, far)
	far.stats.armor_class = -100
	var certain: Dictionary = combat_mgr.get_hit_chance(player, far)
	var rolled_nothing: bool = randi() == next_roll
	far.stats.armor_class = 13

	check(_close_to(plain.chance, 0.55) and plain.percent == 55 and plain.needed == 10 and plain.attack_bonus == 3 and plain.target_ac == 13
		and not plain.advantage and not plain.disadvantage and plain.reasons.is_empty() and plain.cover_bonus == 0,
		"the chance to hit of a plain attack is exact: 11 faces of 20", "%f, needs %d" % [plain.chance, plain.needed])
	check(_close_to(with_advantage.chance, 0.7975) and with_advantage.percent == 80 and with_advantage.advantage and not with_advantage.disadvantage
		and ", ".join(with_advantage.reasons) == "target stunned",
		"with advantage the chance is that of the better of two dice, and the reason is given",
		"%f %s" % [with_advantage.chance, str(with_advantage.reasons)])
	check(_close_to(with_disadvantage.chance, 0.3025) and with_disadvantage.percent == 30 and with_disadvantage.disadvantage
		and not with_disadvantage.advantage and ", ".join(with_disadvantage.reasons) == "poisoned",
		"with disadvantage the chance is that of the worse of two dice, and the reason is given",
		"%f %s" % [with_disadvantage.chance, str(with_disadvantage.reasons)])
	check(_close_to(with_both.chance, 0.55) and with_both.advantage and with_both.disadvantage,
		"advantage and disadvantage together are a plain roll", "%f" % with_both.chance)
	check(_close_to(behind_cover.chance, 0.45) and behind_cover.cover_bonus == 2 and behind_cover.target_ac == 15 and behind_cover.needed == 12
		and ", ".join(behind_cover.reasons) == "half cover" and previewed.ok and previewed.hit_chance.percent == 45,
		"past a corner the target has half cover: the chance drops by its bonus to the armour class, and the cover is named",
		"%f %s" % [behind_cover.chance, str(behind_cover.reasons)])
	check(_close_to(beside_wall.chance, 0.55) and beside_wall.cover_bonus == 0 and beside_wall.reasons.is_empty(),
		"a wall next to the target, off the line of the shot, gives no cover", "%f %s" % [beside_wall.chance, str(beside_wall.reasons)])
	check(_close_to(hopeless.chance, 0.05) and _close_to(certain.chance, 0.95),
		"a natural 20 always hits and a natural 1 always misses: the chance never leaves 5% to 95%", "%f, %f" % [hopeless.chance, certain.chance])
	check(rolled_nothing, "working out the chance to hit rolls no dice")

	# --- cover, in the roll itself ---
	player.action_used = false
	var covered_shot: Dictionary = controller.request_action(player, "attack", {"target": far})
	for i in range(corner_tiles.size()):
		grid[corner_tiles[i].y][corner_tiles[i].x] = corner_was[i]
	player.action_used = false
	var open_shot: Dictionary = controller.request_action(player, "attack", {"target": far})
	far.teleport_to_grid(in_line)
	check(covered_shot.ok and covered_shot.cover_bonus == 2 and covered_shot.target_ac == 15 and "half cover" in covered_shot.reasons
		and open_shot.ok and open_shot.cover_bonus == 0 and open_shot.target_ac == 13,
		"cover raises the target's armour class for a ranged attack", "AC %s behind cover, %s in the open"
		% [str(covered_shot.get("target_ac", "?")), str(open_shot.get("target_ac", "?"))])

	# --- an enemy shoots through the same request, and swaps through it too ---
	far.weapon = items.get_item("shortbow")
	far.second_weapon = items.get_item("club")
	stats.armor_class = -100
	taken.clear()
	controller.request_action(player, "end_turn")
	var their_turn: bool = controller.is_turn_of(far)
	var hp_off_turn: int = far.stats.current_hp
	player.action_used = false  # a gate on the action alone would let the shot through
	var off_turn: Dictionary = controller.request_action(player, "attack", {"target": far})
	var off_turn_swap: Dictionary = controller.request_action(player, "swap_weapons")
	check(their_turn and not off_turn.ok and off_turn.reason == "Not your turn" and not player.action_used and far.stats.current_hp == hp_off_turn,
		"a shot is refused when it is not the shooter's turn", str(off_turn))
	check(their_turn and not off_turn_swap.ok and off_turn_swap.reason == "Not your turn" and player.get_weapon_set() == 2 and not player.action_used,
		"a swap of weapon sets is refused when it is not the combatant's turn", str(off_turn_swap))
	var arrow: Dictionary = _attack_until_hit(controller, far, player, blows)
	var arrows_in_flight: int = _count_nodes(world, projectile_script)
	check(not arrow.is_empty() and arrow.weapon_name == "Oak Shortbow" and arrow.is_ranged and arrow.damage_dice == "1d6"
		and arrow.damage_type == "piercing" and arrow.distance == 4 and arrow.hp_lost == arrow.damage and arrows_in_flight >= 1
		and blows.size() == 1 and blows[0][0] == far and blows[0][1] == player and blows[0][3] == piercing
		and taken.any(func(entry): return entry[0] == far and entry[1] == "attack" and entry[2].is_ranged),
		"an enemy given a ranged weapon shoots through the same request", str(arrow.get("weapon_name", "refused")))
	far.action_used = false
	var enemy_swap: Dictionary = controller.request_action(far, "swap_weapons")
	check(enemy_swap.ok and enemy_swap.weapon_set == 2 and far.action_used and far.get_weapon() == items.get_item("club")
		and combat_mgr.get_attack_profile(far).weapon_name == "Oak Club",
		"an enemy with a second weapon set swaps through the same request, for its action", str(enemy_swap))
	far.weapon = null
	far.second_weapon = null
	far.weapon_set = 1
	await _until(func(): return controller.is_turn_of(player) or not world.in_combat)

	# --- the fight ends; outside it the swap back is free ---
	combat_mgr.deal_damage(player, far, 9999)
	await _until(func(): return not world.in_combat, 5.0)
	Engine.time_scale = 1.0
	var free_swap: Dictionary = controller.request_action(player, "swap_weapons")
	check(not world.in_combat and free_swap.ok and player.get_weapon_set() == 1 and not player.action_used,
		"outside a fight swapping weapon sets costs nothing", str(free_swap))
	check(inv.get_equipped_item(stats, "main_hand") == sword and inv.get_equipped_item(stats, "off_hand") == shield
		and inv.get_equipped_item(stats, "main_hand_2") == crossbow and inv.get_equipped_item(stats, "off_hand_2").is_empty()
		and grid[wall_tile.y][wall_tile.x] == wall_was and grid[aside.y][aside.x] == aside_was
		and grid[corner_tiles[0].y][corner_tiles[0].x] == corner_was[0] and grid[corner_tiles[1].y][corner_tiles[1].x] == corner_was[1],
		"test teardown: the staged fight is over, the starting kit is in its two sets and the floor is floor again")

	controller.action_taken.disconnect(on_action)
	bus.damage_dealt.disconnect(on_damage)
	bus.ui_notification.disconnect(on_note)
	for node in world.ground_items_node.get_children():
		node.queue_free()
	if player.grid_position != home:
		player.teleport_to_grid(home)
	stats.recalculate_derived_stats()  # back to the real maximum and armour class
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
	combat_mgr.deal_damage(player, second, 9999)
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
			combat_mgr.deal_damage(player, combatant, 9999)
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
	var features = _mgr("FeatureManager")

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
		[items.create_item_instance("wrought_iron_dagger")], 7)
	inv.gold += 123
	quests.start_quest("mq_01_strange_tidings")
	comp.recruit("kaelen")
	await _wait(0.3)
	world.companion_nodes["kaelen"].stats.current_hp = 5
	# Of the gear a save carries both weapon sets, which one is in hand, and
	# what has been used since the last long rest
	var swapped: Dictionary = world.combat.request_action(world.player, "swap_weapons")
	features._mark_used(stats, "relentless_endurance")
	check(swapped.ok and inv.get_weapon_set(stats) == 2 and inv.get_equipped_item(stats, "main_hand").item_data.item_id == "quarterstaff"
		and inv.get_equipped_item(stats, "main_hand_2").item_data.item_id == "dagger",
		"test setup: the new wizard has its staff in the first weapon set and its dagger, now in hand, in the second")
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
	inv.add_item(items.create_item_instance("wrought_iron_dagger"))
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
	check(inv.get_equipped_item(stats, "main_hand").item_data.item_id == "quarterstaff"
		and inv.get_equipped_item(stats, "main_hand_2").item_data.item_id == "dagger" and inv.get_weapon_set(stats) == 2
		and world.player.get_weapon().item_id == "dagger" and features.is_used(stats, "relentless_endurance"),
		"both weapon sets, which of them is in hand, and what was used since the last long rest are restored")
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
	combat.deal_damage(enemy, world.player, 9999)
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
	# Format 3: one pair of hands and a ranged slot, items under the material ids of the time
	var v3: Dictionary = raw.duplicate(true)
	v3["version"] = 3
	var v3_gear: Dictionary = v3["systems"]["inventory"]["equipped_items"]["player"]
	v3_gear.erase("main_hand_2")
	v3_gear.erase("off_hand_2")
	v3_gear["main_hand"] = {"item_id": "iron_dagger", "quality_modifier": 0, "magic_modifier": 0, "current_durability": 40, "stack_count": 1}
	v3_gear["ranged"] = {"item_id": "ash_shortbow", "quality_modifier": 1, "magic_modifier": 0, "current_durability": 28, "stack_count": 1}
	v3["systems"]["inventory"].erase("weapon_sets")
	v3["systems"]["inventory"]["items"].append({"item_id": "leather_jerkin", "quality_modifier": 0, "magic_modifier": 0,
		"current_durability": 30, "stack_count": 1})
	v3["systems"].erase("features")
	_write_raw_save(saves, 8, v3)

	var migrated: Dictionary = saves.read_save(5)
	check(int(migrated.get("version", 0)) == saves.SAVE_FORMAT_VERSION and migrated.get("world") is Dictionary
		and int(migrated.get("migrated_from", 0)) == 2, "a format-2 save is migrated on read")
	check(int(saves.get_save_info(6).get("gold", -1)) == 77, "a format-1 save is readable in the slot list")
	check(saves.read_save(7).is_empty() and not game.load_game(7) and _world() == world,
		"a save from a newer version is refused and nothing changes")

	var from_v3: Dictionary = saves.read_save(8)
	var migrated_gear: Dictionary = from_v3["systems"]["inventory"]["equipped_items"]["player"]
	check(int(from_v3.get("version", 0)) == 4 and saves.SAVE_FORMAT_VERSION == 4 and int(from_v3.get("migrated_from", 0)) == 3
		and not migrated_gear.has("ranged") and migrated_gear.get("main_hand_2", {}).get("item_id", "") == "ash_shortbow"
		and from_v3["systems"]["inventory"].get("weapon_sets") is Dictionary and from_v3["systems"].get("features") is Dictionary,
		"a format-3 save is migrated on read: the item of the ranged slot becomes the main hand of the second weapon set")
	check(game.load_game(8), "a format-3 save loads")
	await _wait(1.0)
	world = _world()
	var old_stats = world.player.stats if world != null else null
	var carried: Array = []
	for carried_item in inv.items:
		carried.append(carried_item.item_data.item_id)
	var old_bow: Dictionary = inv.get_equipped_item(old_stats, "main_hand_2") if old_stats != null else {}
	check(not old_bow.is_empty() and old_bow.item_data.item_id == "ash_shortbow" and int(old_bow.quality_modifier) == 1
		and inv.get_weapon_set(old_stats) == 1 and world.player.get_weapon(2) == old_bow.item_data and not inv.equipped_items[old_stats].has("ranged")
		and not features.is_used(old_stats, "relentless_endurance"),
		"an old save's ranged weapon is in the second weapon set after loading, and the first set is in hand")
	check(old_stats != null and inv.get_equipped_item(old_stats, "main_hand").item_data.item_id == "wrought_iron_dagger"
		and world.player.get_weapon().item_name == "Wrought Iron Dagger" and "cowhide_jerkin" in carried,
		"items an old save holds under old material ids load as the items they became", str(carried))

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
