class_name GridOverlay
extends Node2D

# Grid rendering for tile-based movement visualization

@export var grid_color: Color = Color(0, 0, 0, 0.5)
@export var grid_thickness: float = 1.0
@export var enabled: bool = true

var dungeon_grid: Array[Array] = []
var tile_size: Vector2 = Vector2(16, 16)
var dungeon_width: int = 0
var dungeon_height: int = 0

const FLOOR_TILE = 0

func _ready():
	z_index = 100  # Draw on top of everything

func setup(p_dungeon_grid: Array[Array], p_tile_size: Vector2, p_width: int, p_height: int):
	"""Initialize the grid with dungeon data"""
	dungeon_grid = p_dungeon_grid
	tile_size = p_tile_size
	dungeon_width = p_width
	dungeon_height = p_height
	queue_redraw()

func _draw():
	if not enabled or dungeon_grid.is_empty():
		return
	
	# Only draw grid on floor tiles (walkable areas)
	for y in range(dungeon_height):
		for x in range(dungeon_width):
			if y >= dungeon_grid.size() or x >= dungeon_grid[y].size():
				continue
			
			var tile_type = dungeon_grid[y][x]
			# Only draw grid on floor tiles
			if tile_type == FLOOR_TILE:
				var top_left = Vector2(x * tile_size.x, y * tile_size.y)
				var top_right = Vector2((x + 1) * tile_size.x, y * tile_size.y)
				var bottom_left = Vector2(x * tile_size.x, (y + 1) * tile_size.y)
				var bottom_right = Vector2((x + 1) * tile_size.x, (y + 1) * tile_size.y)
				
				# Draw the 4 edges of this tile
				draw_line(top_left, top_right, grid_color, grid_thickness)
				draw_line(top_right, bottom_right, grid_color, grid_thickness)
				draw_line(bottom_right, bottom_left, grid_color, grid_thickness)
				draw_line(bottom_left, top_left, grid_color, grid_thickness)

func refresh():
	"""Redraw the grid"""
	queue_redraw()

func set_enabled(value: bool):
	"""Enable or disable grid rendering"""
	enabled = value
	queue_redraw()
