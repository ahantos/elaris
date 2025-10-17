extends Control
class_name Minimap

# Minimap that shows dungeon layout and player position

@export var minimap_size: Vector2 = Vector2(200, 200)
@export var background_color: Color = Color(0, 0, 0, 0.7)
@export var wall_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var floor_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var player_color: Color = Color(0, 1, 0, 1.0)
@export var unexplored_color: Color = Color(0.1, 0.1, 0.1, 1.0)
@export var border_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var fog_of_war_enabled: bool = true
@export var exploration_radius: int = 8  # Tiles visible around player

var dungeon_generator: DungeonGenerator
var player: GridCharacter
var explored_tiles: Dictionary = {}  # Track which tiles have been explored
var pixel_per_tile: float = 1.0
var last_player_pos: Vector2i = Vector2i(-999, -999)  # Track player movement
var needs_redraw: bool = true

func _ready():
	# Position in top-right corner
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -minimap_size.x - 10
	offset_top = 10
	custom_minimum_size = minimap_size
	size = minimap_size

func setup(p_dungeon_generator: DungeonGenerator, p_player: GridCharacter):
	"""Initialize minimap with dungeon and player references"""
	dungeon_generator = p_dungeon_generator
	player = p_player
	
	if dungeon_generator:
		# Calculate how many pixels per tile to fit the dungeon in minimap
		var dungeon_size = Vector2(dungeon_generator.dungeon_width, dungeon_generator.dungeon_height)
		pixel_per_tile = min(minimap_size.x / dungeon_size.x, minimap_size.y / dungeon_size.y)
		
		print("Minimap setup - pixel_per_tile: ", pixel_per_tile)
	
	queue_redraw()

func _process(_delta):
	# Update exploration around player
	if fog_of_war_enabled and player and dungeon_generator:
		update_exploration()
	
	# Redraw every frame to show player position
	queue_redraw()

func update_exploration():
	"""Mark tiles around player as explored"""
	var player_pos = player.get_grid_position()
	
	for y in range(player_pos.y - exploration_radius, player_pos.y + exploration_radius + 1):
		for x in range(player_pos.x - exploration_radius, player_pos.x + exploration_radius + 1):
			# Check if in bounds
			if x >= 0 and x < dungeon_generator.dungeon_width and y >= 0 and y < dungeon_generator.dungeon_height:
				# Check if within circular radius
				var dist = Vector2(x, y).distance_to(Vector2(player_pos.x, player_pos.y))
				if dist <= exploration_radius:
					var key = Vector2i(x, y)
					explored_tiles[key] = true

func _draw():
	if not dungeon_generator or not player:
		return
	
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, minimap_size), background_color)
	
	# Draw dungeon tiles
	for y in range(dungeon_generator.dungeon_height):
		for x in range(dungeon_generator.dungeon_width):
			var tile_pos = Vector2i(x, y)
			
			# Skip if fog of war is enabled and tile not explored
			if fog_of_war_enabled and tile_pos not in explored_tiles:
				var screen_pos = Vector2(x * pixel_per_tile, y * pixel_per_tile)
				draw_rect(Rect2(screen_pos, Vector2(pixel_per_tile, pixel_per_tile)), unexplored_color)
				continue
			
			var tile_type = dungeon_generator.dungeon_grid[y][x]
			var color: Color
			
			match tile_type:
				dungeon_generator.TileType.FLOOR, dungeon_generator.TileType.DOOR:
					color = floor_color
				dungeon_generator.TileType.WALL:
					color = wall_color
				_:
					color = Color.TRANSPARENT
			
			if color != Color.TRANSPARENT:
				var screen_pos = Vector2(x * pixel_per_tile, y * pixel_per_tile)
				draw_rect(Rect2(screen_pos, Vector2(pixel_per_tile, pixel_per_tile)), color)
	
	# Draw player position
	var player_grid = player.get_grid_position()
	var player_screen = Vector2(player_grid.x * pixel_per_tile, player_grid.y * pixel_per_tile)
	var player_size = max(pixel_per_tile * 2, 3.0)  # At least 3 pixels
	draw_circle(player_screen + Vector2(pixel_per_tile / 2, pixel_per_tile / 2), player_size, player_color)
	
	# Draw border
	draw_rect(Rect2(Vector2.ZERO, minimap_size), border_color, false, 2.0)

func toggle_fog_of_war():
	"""Toggle fog of war on/off"""
	fog_of_war_enabled = !fog_of_war_enabled
	print("Fog of war: ", "enabled" if fog_of_war_enabled else "disabled")
	queue_redraw()
