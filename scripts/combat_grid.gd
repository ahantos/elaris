# combat_grid.gd
# Static grid-combat helpers: line of sight, cover (the 5e corner rule), flanking,
# distance, movement cost.
# All functions are static and side-effect free. `dungeon_grid` is the DungeonGenerator's
# [y][x] Array of TileType ints (EMPTY=-1, FLOOR=0, WALL=1, DOOR=2, DECORATION=3).
# Owned by A3 (Combat Expansion) - see docs/ARCHITECTURE_CONTRACTS.md section 4.
class_name CombatGrid
extends RefCounted

# Cover, as what it adds to the target's armour class (5e): half cover +2,
# three-quarters cover +5
const COVER_NONE: int = 0
const COVER_HALF: int = 2
const COVER_THREE_QUARTERS: int = 5

# The corners of a tile, as offsets from the tile's own coordinates: a tile at
# (x, y) covers the square from (x, y) to (x + 1, y + 1)
const _TILE_CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const _EPSILON: float = 0.000001


static func get_distance_tiles(a: Vector2i, b: Vector2i) -> int:
	"""Chebyshev distance in tiles (diagonal steps count as 1)."""
	return max(abs(a.x - b.x), abs(a.y - b.y))


static func get_movement_cost(tile_type: int) -> float:
	"""Movement cost for entering a tile of the given type.
	DECORATION counts as difficult terrain (2.0); everything else costs 1.0.
	Walkability itself is NOT decided here - callers filter non-walkable tiles first."""
	if tile_type == DungeonGenerator.TileType.DECORATION:
		return 2.0
	return 1.0


static func get_line_cells(from: Vector2i, to: Vector2i) -> Array:
	"""All grid cells on the Bresenham line from -> to, endpoints included."""
	var cells: Array = []
	var x0 = from.x
	var y0 = from.y
	var x1 = to.x
	var y1 = to.y
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return cells


static func has_line_of_sight(from: Vector2i, to: Vector2i, dungeon_grid: Array) -> bool:
	"""True when no sight-blocking tile (WALL or EMPTY) lies strictly between from and to
	along the Bresenham line. Endpoints never block (combatants stand on them).
	Out-of-bounds reads count as EMPTY (blocking). An empty grid counts as open
	(graceful skip when no dungeon is available)."""
	if dungeon_grid.is_empty():
		return true
	if from == to:
		return true
	var cells = get_line_cells(from, to)
	for i in range(1, cells.size() - 1):
		if _blocks_sight(_tile_at(dungeon_grid, cells[i])):
			return false
	return true


static func get_cover(from: Vector2i, to: Vector2i, dungeon_grid: Array) -> Dictionary:
	"""The cover a target at `to` has from an attacker at `from`, by the 5e
	rule for a grid: from the corner of the attacker's tile that gives the best
	view, lines are drawn to the four corners of the target's tile. None of them
	blocked: no cover. One or two: half cover (+2 armour class). Three:
	three-quarters cover (+5). All four: no line of sight at all.
	Only walls block (and the void beyond the map). Doors are open floor: there
	is no closed door in the game yet; when there is, _blocks_sight is where it
	blocks. An unobstructed shot down a corridor has no cover, however near the
	walls are: a line that runs along a wall's face, or touches a corner, is not
	blocked.
	Returns {lines_blocked (0 to 4), ac_bonus (COVER_NONE, COVER_HALF or
	COVER_THREE_QUARTERS; the last also when nothing can be seen), line_of_sight}.
	An empty grid (no dungeon to look at) and an adjacent target give no cover."""
	var cover: Dictionary = {"lines_blocked": 0, "ac_bonus": COVER_NONE, "line_of_sight": true}
	if dungeon_grid.is_empty() or get_distance_tiles(from, to) <= 1:
		return cover

	var fewest: int = _TILE_CORNERS.size()
	for corner in _TILE_CORNERS:
		var blocked: int = 0
		for target_corner in _TILE_CORNERS:
			if _corner_line_blocked(from + corner, to + target_corner, from, to, dungeon_grid):
				blocked += 1
		fewest = mini(fewest, blocked)
		if fewest == 0:
			break

	cover["lines_blocked"] = fewest
	cover["line_of_sight"] = fewest < _TILE_CORNERS.size()
	if fewest >= 3:
		cover["ac_bonus"] = COVER_THREE_QUARTERS
	elif fewest >= 1:
		cover["ac_bonus"] = COVER_HALF
	return cover


static func get_cover_ac_bonus(from: Vector2i, to: Vector2i, dungeon_grid: Array) -> int:
	"""What cover adds to the armour class of a target at `to` against an attack
	from `from`: COVER_NONE (0), COVER_HALF (+2) or COVER_THREE_QUARTERS (+5).
	See get_cover."""
	return int(get_cover(from, to, dungeon_grid).ac_bonus)


static func _corner_line_blocked(a: Vector2i, b: Vector2i, from_tile: Vector2i, to_tile: Vector2i, dungeon_grid: Array) -> bool:
	"""Is the straight line from grid point a (a corner of the attacker's tile)
	to grid point b (a corner of the target's tile) blocked? It is when
	- it passes through the inside of a blocking tile, or
	- it runs along a grid line that has a blocking tile on either side, or
	- it passes through a grid point between two blocking tiles that touch
	  there only by their corners (a gap of no width).
	Running along the face of one wall, or touching its corner, does not block."""
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	var x_low: int = mini(a.x, b.x)
	var x_high: int = maxi(a.x, b.x)
	var y_low: int = mini(a.y, b.y)
	var y_high: int = maxi(a.y, b.y)

	# Along a grid line: blocked where the tiles on both sides of it block
	if dy == 0:
		for x in range(x_low, x_high):
			if _blocks_sight(_tile_at(dungeon_grid, Vector2i(x, a.y - 1))) and _blocks_sight(_tile_at(dungeon_grid, Vector2i(x, a.y))):
				return true
		return false
	if dx == 0:
		for y in range(y_low, y_high):
			if _blocks_sight(_tile_at(dungeon_grid, Vector2i(a.x - 1, y))) and _blocks_sight(_tile_at(dungeon_grid, Vector2i(a.x, y))):
				return true
		return false

	# Column by column: the tiles whose inside the line passes through
	for column in range(x_low, x_high):
		var y_enter: float = a.y + float(dy) * float(column - a.x) / float(dx)
		var y_leave: float = a.y + float(dy) * float(column + 1 - a.x) / float(dx)
		var low: float = minf(y_enter, y_leave)
		var high: float = maxf(y_enter, y_leave)
		for row in range(int(floor(low + _EPSILON)), int(ceil(high - _EPSILON))):
			if _blocks_sight(_tile_at(dungeon_grid, Vector2i(column, row))):
				return true

	# Grid points the line passes exactly through: it goes from one tile to the
	# tile diagonally across. With the other two tiles at that point both
	# blocking, there is no gap to see through. At its own two ends the line
	# only counts as passing through when it leaves the attacker's tile, or
	# enters the target's, across the corner.
	var step_x: int = 1 if dx > 0 else -1
	var step_y: int = 1 if dy > 0 else -1
	for x in range(x_low, x_high + 1):
		var y: float = a.y + float(dy) * float(x - a.x) / float(dx)
		if absf(y - roundf(y)) > _EPSILON:
			continue
		var point := Vector2i(x, int(roundf(y)))
		var after := Vector2i(point.x + (0 if step_x > 0 else -1), point.y + (0 if step_y > 0 else -1))
		var before := Vector2i(point.x + (-1 if step_x > 0 else 0), point.y + (-1 if step_y > 0 else 0))
		if point == a and before != from_tile:
			continue
		if point == b and after != to_tile:
			continue
		if _blocks_sight(_tile_at(dungeon_grid, Vector2i(after.x, before.y))) and _blocks_sight(_tile_at(dungeon_grid, Vector2i(before.x, after.y))):
			return true
	return false


static func is_flanking(attacker_pos: Vector2i, target_pos: Vector2i, ally_positions: Array) -> bool:
	"""True when the attacker is adjacent to the target (Chebyshev 1) and an ally occupies
	the exact mirrored cell on the opposite side of the target (a 2-sided pincer).
	`ally_positions` is an Array of Vector2i (Vector2 entries are tolerated)."""
	if get_distance_tiles(attacker_pos, target_pos) != 1:
		return false
	var opposite = target_pos + (target_pos - attacker_pos)
	for ally_pos in ally_positions:
		if ally_pos is Vector2i and ally_pos == opposite:
			return true
		if ally_pos is Vector2 and Vector2i(ally_pos) == opposite:
			return true
	return false


# === INTERNAL HELPERS ===

static func _tile_at(dungeon_grid: Array, pos: Vector2i) -> int:
	"""Bounds-checked grid read; anything out of bounds or malformed counts as EMPTY."""
	if pos.y < 0 or pos.y >= dungeon_grid.size():
		return DungeonGenerator.TileType.EMPTY
	var row = dungeon_grid[pos.y]
	if not (row is Array) or pos.x < 0 or pos.x >= row.size():
		return DungeonGenerator.TileType.EMPTY
	return int(row[pos.x])


static func _blocks_sight(tile_type: int) -> bool:
	"""WALL and EMPTY (void / out of bounds) block sight; floors, doors and decorations do not."""
	return tile_type == DungeonGenerator.TileType.WALL or tile_type == DungeonGenerator.TileType.EMPTY
