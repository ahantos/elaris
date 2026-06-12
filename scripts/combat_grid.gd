# combat_grid.gd
# Static grid-combat helpers: line of sight, cover, flanking, distance, movement cost.
# All functions are static and side-effect free. `dungeon_grid` is the DungeonGenerator's
# [y][x] Array of TileType ints (EMPTY=-1, FLOOR=0, WALL=1, DOOR=2, DECORATION=3).
# Owned by A3 (Combat Expansion) - see docs/ARCHITECTURE_CONTRACTS.md section 4.
class_name CombatGrid
extends RefCounted

# Cover AC bonuses
const COVER_NONE: int = 0
const COVER_HALF: int = 2
const COVER_FULL: int = 5

# How close to the target (in tiles) a wall-hugging line cell must be to count as half cover
const COVER_NEAR_TARGET_RANGE: int = 2


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


static func get_cover_ac_bonus(from: Vector2i, to: Vector2i, dungeon_grid: Array) -> int:
	"""Cover AC bonus for an attack from `from` against a target at `to`.
	Returns COVER_NONE (0), COVER_HALF (+2) or COVER_FULL (+5).

	Approximation used:
	- An empty grid yields 0 (graceful skip when no dungeon is available).
	- Adjacent attacks (Chebyshev distance <= 1) never have cover (point blank / melee).
	- No line of sight at all = full cover (+5). Such attacks normally should not be
	  rolled at all; this is the defensive edge case.
	- Half cover (+2) when the target is effectively hugging a wall relative to the shot:
	  (a) a WALL tile sits cardinally adjacent to the target, perpendicular to the main
	      attack axis (mostly-horizontal shots check above/below the target and vice
	      versa), or
	  (b) the sight line grazes a wall near the target: any line cell within
	      COVER_NEAR_TARGET_RANGE tiles of the target (endpoints excluded) that has a
	      cardinally adjacent WALL.
	  Note: this intentionally means shots down narrow corridors usually grant +2 -
	  defenders are treated as leaning into the corridor walls."""
	if dungeon_grid.is_empty():
		return COVER_NONE
	if get_distance_tiles(from, to) <= 1:
		return COVER_NONE
	if not has_line_of_sight(from, to, dungeon_grid):
		return COVER_FULL

	var delta = to - from

	# (a) wall flanking the target perpendicular to the attack axis
	var perpendiculars: Array = []
	if abs(delta.x) >= abs(delta.y):
		perpendiculars = [Vector2i(0, 1), Vector2i(0, -1)]
	else:
		perpendiculars = [Vector2i(1, 0), Vector2i(-1, 0)]
	for offset in perpendiculars:
		if _tile_at(dungeon_grid, to + offset) == DungeonGenerator.TileType.WALL:
			return COVER_HALF

	# (b) the sight line passes adjacent to a wall close to the target
	var cardinals = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var cells = get_line_cells(from, to)
	for i in range(1, cells.size() - 1):
		var cell: Vector2i = cells[i]
		if get_distance_tiles(cell, to) > COVER_NEAR_TARGET_RANGE:
			continue
		for offset in cardinals:
			if _tile_at(dungeon_grid, cell + offset) == DungeonGenerator.TileType.WALL:
				return COVER_HALF

	return COVER_NONE


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
