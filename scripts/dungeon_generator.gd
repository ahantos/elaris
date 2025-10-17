extends Node2D
class_name DungeonGenerator

# Main dungeon generation coordinator

@export_group("Dungeon Settings")
@export var dungeon_width: int = 200
@export var dungeon_height: int = 200
@export var num_rooms: int = 3
@export var max_placement_attempts: int = 100
@export var min_room_distance: int = 15
@export var corridor_width: int = 5

@export_group("Biome Selection")
@export_enum("house", "cave", "dungeon", "crypt", "forest") var biome_type: String = "dungeon"

@export_group("Room Distribution")
@export var guarantee_start_room: bool = true
@export var guarantee_boss_room: bool = true
@export var treasure_room_chance: float = 0.0

@export_group("Grid Settings")
@export var show_grid: bool = true
@export var grid_color: Color = Color(0, 0, 0, 0.5)
@export var grid_thickness: float = 1.0

@export_group("Camera Settings")
@export var initial_camera_zoom: float = 3.5  # Higher = more zoomed in

@export_group("Debug")
@export var auto_generate_on_ready: bool = true
@export var show_debug_info: bool = true

@export_group("TileSet Settings")
@export var tileset_path: String = "res://tilesets/dungeon_tileset.tres"

enum TileType {
	EMPTY = -1,
	FLOOR = 0,
	WALL = 1,
	DOOR = 2,
	DECORATION = 3
}

var camera: Camera2D = null
var grid_overlay: GridOverlay = null
var tilemap: TileMap = null

var room_templates: Array[RoomTemplate] = []
var placed_rooms: Array[Dictionary] = []
var dungeon_grid: Array[Array] = []
var start_room: Dictionary = {}
var boss_room: Dictionary = {}

func _ready():
	tilemap = get_node_or_null("TileMap")
	if not tilemap:
		push_error("TileMap child node not found!")
		return
	
	if not tilemap.tile_set and FileAccess.file_exists(tileset_path):
		tilemap.tile_set = load(tileset_path)
	
	camera = get_node_or_null("Camera2D")
	if not camera:
		camera = Camera2D.new()
		camera.name = "DungeonCamera"
		add_child(camera)
	
	camera.enabled = true
	camera.make_current()
	camera.zoom = Vector2(initial_camera_zoom, initial_camera_zoom)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	
	if show_grid:
		grid_overlay = GridOverlay.new()
		grid_overlay.name = "GridOverlay"
		grid_overlay.grid_color = grid_color
		grid_overlay.grid_thickness = grid_thickness
		add_child(grid_overlay)
	
	if auto_generate_on_ready:
		call_deferred("generate_dungeon")

func _process(delta):
	# Camera follows player smoothly
	if camera:
		var world = get_tree().root.get_node_or_null("World")
		if world and world.player:
			# UI takes up bottom 25% of screen
			# Account for zoom level with slight adjustment for extreme zooms
			var viewport_height = get_viewport_rect().size.y
			var screen_offset = viewport_height * 0.14  # Increased from 0.125 to 0.14 (14%)
			var world_offset = screen_offset / camera.zoom.y  # Convert to world space
			
			# Apply slight compensation for extreme zoom levels
			var zoom_factor = clamp(camera.zoom.y / 3.5, 0.8, 1.2)  # Updated baseline to 3.5
			world_offset *= zoom_factor
			
			var target_pos = world.player.global_position + Vector2(0, world_offset)
			camera.global_position = camera.global_position.lerp(target_pos, 5.0 * delta)
	
	# Zoom controls
	if Input.is_action_pressed("ui_page_up"):
		camera.zoom += Vector2(0.05, 0.05) * delta * 60.0
		camera.zoom.x = clamp(camera.zoom.x, 0.5, 10.0)
		camera.zoom.y = clamp(camera.zoom.y, 0.5, 10.0)
	if Input.is_action_pressed("ui_page_down"):
		camera.zoom -= Vector2(0.05, 0.05) * delta * 60.0
		camera.zoom.x = clamp(camera.zoom.x, 0.5, 10.0)
		camera.zoom.y = clamp(camera.zoom.y, 0.5, 10.0)
	
	# Regenerate dungeon with R key
	if Input.is_key_pressed(KEY_R):
		regenerate()

func set_camera_target(target: Node2D):
	"""Make camera follow a target - snaps to position immediately"""
	if camera and target:
		var viewport_height = get_viewport_rect().size.y
		var screen_offset = viewport_height * 0.14  # Increased from 0.125 to 0.14
		var world_offset = screen_offset / camera.zoom.y
		
		# Apply zoom compensation
		var zoom_factor = clamp(camera.zoom.y / 3.5, 0.8, 1.2)  # Updated baseline to 3.5
		world_offset *= zoom_factor
		
		camera.global_position = target.global_position + Vector2(0, world_offset)

func generate_dungeon():
	_initialize_grid()
	placed_rooms.clear()
	start_room = {}
	boss_room = {}
	
	room_templates = RoomLibrary.get_rooms_for_biome(biome_type)
	
	var large_templates = room_templates.filter(func(t): return t.width >= 7 or t.height >= 7)
	if large_templates.is_empty():
		large_templates = room_templates
	
	# Place start room
	var start_template = large_templates.filter(func(t): return t.room_type == "start")
	if start_template.is_empty():
		start_template = [large_templates[0]]
	
	var start_placed = false
	for attempt in range(max_placement_attempts):
		var pos = Vector2i(
			randi() % (dungeon_width - start_template[0].width - 20) + 10,
			randi() % (dungeon_height - start_template[0].height - 20) + 10
		)
		if _can_place_room(pos, start_template[0]):
			_place_room(pos, start_template[0])
			start_room = placed_rooms[0]
			start_placed = true
			break
	
	if not start_placed:
		push_error("Failed to place start room!")
		return
	
	# Place middle room
	var normal_templates = large_templates.filter(func(t): return t.room_type == "normal")
	if normal_templates.is_empty():
		normal_templates = large_templates
	var middle_template = normal_templates[randi() % normal_templates.size()]
	_attempt_place_room(middle_template)
	
	# Place boss room
	var boss_template = large_templates.filter(func(t): return t.room_type == "boss")
	if boss_template.is_empty():
		boss_template = [large_templates[randi() % large_templates.size()]]
	_attempt_place_room(boss_template[0])
	
	if placed_rooms.size() >= 2:
		boss_room = placed_rooms[placed_rooms.size() - 1]
	
	# Connect rooms
	if placed_rooms.size() >= 2:
		_create_corridor(placed_rooms[0], placed_rooms[1])
	if placed_rooms.size() >= 3:
		_create_corridor(placed_rooms[1], placed_rooms[2])
	
	_add_corridor_walls()
	_render_to_tilemap()
	
	if grid_overlay:
		grid_overlay.setup(dungeon_grid, tilemap.tile_set.tile_size, dungeon_width, dungeon_height)
	
	print("=== DUNGEON GENERATED ===")
	print("Rooms placed: %d" % placed_rooms.size())

func _initialize_grid():
	dungeon_grid.clear()
	for y in range(dungeon_height):
		var row: Array[int] = []
		row.resize(dungeon_width)
		row.fill(TileType.EMPTY)
		dungeon_grid.append(row)

func _attempt_place_room(template: RoomTemplate) -> bool:
	for attempt in range(max_placement_attempts):
		var pos = Vector2i(
			randi() % (dungeon_width - template.width - min_room_distance * 2) + min_room_distance,
			randi() % (dungeon_height - template.height - min_room_distance * 2) + min_room_distance
		)
		if _can_place_room(pos, template):
			_place_room(pos, template)
			return true
	return false

func _can_place_room(pos: Vector2i, template: RoomTemplate) -> bool:
	if pos.x + template.width >= dungeon_width or pos.y + template.height >= dungeon_height:
		return false
	if pos.x < 0 or pos.y < 0:
		return false
	
	for y in range(-min_room_distance, template.height + min_room_distance):
		for x in range(-min_room_distance, template.width + min_room_distance):
			var check_x = pos.x + x
			var check_y = pos.y + y
			if check_x >= 0 and check_x < dungeon_width and check_y >= 0 and check_y < dungeon_height:
				if dungeon_grid[check_y][check_x] != TileType.EMPTY:
					return false
	return true

func _place_room(pos: Vector2i, template: RoomTemplate):
	for y in range(template.height):
		for x in range(template.width):
			var tile = template.layout[y][x]
			if tile != TileType.EMPTY:
				dungeon_grid[pos.y + y][pos.x + x] = tile
	
	var world_doorways: Array[Vector2i] = []
	for doorway in template.doorways:
		world_doorways.append(pos + doorway)
	
	var room_data = {
		"position": pos,
		"template": template,
		"center": pos + template.get_center(),
		"doorways": world_doorways
	}
	
	placed_rooms.append(room_data)
	
	if template.room_type == "start":
		start_room = room_data
	elif template.room_type == "boss":
		boss_room = room_data

func _create_corridor(room1: Dictionary, room2: Dictionary):
	if room1.doorways.is_empty() or room2.doorways.is_empty():
		return
	
	var best_door1 = room1.doorways[0]
	var best_door2 = room2.doorways[0]
	var min_dist = INF
	
	for door1 in room1.doorways:
		for door2 in room2.doorways:
			var dist = door1.distance_squared_to(door2)
			if dist < min_dist:
				min_dist = dist
				best_door1 = door1
				best_door2 = door2
	
	_carve_wide_corridor(best_door1, best_door2)
	
	if _is_valid_position(best_door1):
		dungeon_grid[best_door1.y][best_door1.x] = TileType.DOOR
	if _is_valid_position(best_door2):
		dungeon_grid[best_door2.y][best_door2.x] = TileType.DOOR

func _carve_wide_corridor(start: Vector2i, end: Vector2i):
	var current = start
	var target = end
	
	var direction_x = 1 if current.x < target.x else -1
	while current.x != target.x:
		_carve_corridor_section(current)
		current.x += direction_x
	
	var direction_y = 1 if current.y < target.y else -1
	while current.y != target.y:
		_carve_corridor_section(current)
		current.y += direction_y
	
	_carve_corridor_section(current)

func _carve_corridor_section(pos: Vector2i):
	var half_width = int(corridor_width / 2)
	for dy in range(-half_width, half_width + 1):
		for dx in range(-half_width, half_width + 1):
			var carve_pos = Vector2i(pos.x + dx, pos.y + dy)
			if _is_valid_position(carve_pos):
				var current_tile = dungeon_grid[carve_pos.y][carve_pos.x]
				if current_tile == TileType.EMPTY or current_tile == TileType.WALL:
					dungeon_grid[carve_pos.y][carve_pos.x] = TileType.FLOOR

func _is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < dungeon_width and pos.y >= 0 and pos.y < dungeon_height

func _add_corridor_walls():
	var temp_grid: Array[Array] = []
	for row in dungeon_grid:
		var new_row: Array[int] = []
		new_row.assign(row)
		temp_grid.append(new_row)
	
	for y in range(1, dungeon_height - 1):
		for x in range(1, dungeon_width - 1):
			if dungeon_grid[y][x] == TileType.FLOOR:
				var empty_neighbors = 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						if dungeon_grid[y + dy][x + dx] == TileType.EMPTY:
							empty_neighbors += 1
				
				if empty_neighbors > 0:
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if dx == 0 and dy == 0:
								continue
							if temp_grid[y + dy][x + dx] == TileType.EMPTY:
								temp_grid[y + dy][x + dx] = TileType.WALL
	
	dungeon_grid = temp_grid

func _render_to_tilemap():
	if not tilemap or not tilemap.tile_set:
		push_error("TileMap not ready!")
		return
	
	var source_id = tilemap.tile_set.get_source_id(0) if tilemap.tile_set.get_source_count() > 0 else -1
	if source_id == -1:
		push_error("No tile source!")
		return
	
	tilemap.clear()
	
	for y in range(dungeon_height):
		for x in range(dungeon_width):
			var tile_type = dungeon_grid[y][x]
			if tile_type != TileType.EMPTY:
				tilemap.set_cell(0, Vector2i(x, y), source_id, Vector2i(tile_type, 0))
	
	tilemap.force_update()

func regenerate():
	generate_dungeon()

func get_start_position() -> Vector2:
	if start_room.is_empty():
		return Vector2.ZERO
	var tile_size: Vector2 = Vector2(16, 16)
	if tilemap and tilemap.tile_set:
		tile_size = tilemap.tile_set.tile_size
	return Vector2(float(start_room.center.x) * tile_size.x, float(start_room.center.y) * tile_size.y)

func get_boss_position() -> Vector2:
	if boss_room.is_empty():
		return Vector2.ZERO
	var tile_size: Vector2 = Vector2(16, 16)
	if tilemap and tilemap.tile_set:
		tile_size = tilemap.tile_set.tile_size
	return Vector2(float(boss_room.center.x) * tile_size.x, float(boss_room.center.y) * tile_size.y)

func set_biome(new_biome: String):
	if RoomLibrary.get_available_biomes().has(new_biome):
		biome_type = new_biome
		generate_dungeon()
	else:
		push_error("Unknown biome: %s" % new_biome)

func toggle_grid(enabled: bool):
	if grid_overlay:
		grid_overlay.set_enabled(enabled)
