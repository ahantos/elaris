class_name RoomLibrary
extends RefCounted

# Tile type constants (should match DungeonGenerator)
const EMPTY = -1
const FLOOR = 0
const WALL = 1
const DOOR = 2
const DECORATION = 3

# Get all room templates for a specific biome
static func get_rooms_for_biome(biome: String) -> Array[RoomTemplate]:
	match biome:
		"house":
			return _create_house_templates()
		"cave":
			return _create_cave_templates()
		"dungeon":
			return _create_dungeon_templates()
		"crypt":
			return _create_crypt_templates()
		"forest":
			return _create_forest_templates()
		_:
			push_error("Unknown biome: %s" % biome)
			return []

# Get list of all available biomes
static func get_available_biomes() -> Array[String]:
	return ["house", "cave", "dungeon", "crypt", "forest"]

# ============================================================================
# HOUSE BIOME
# ============================================================================

static func _create_house_templates() -> Array[RoomTemplate]:
	var house_rooms: Array[RoomTemplate] = []
	
	# Small bedroom
	house_rooms.append(RoomTemplate.new("bedroom_small", [
		[1, 1, 1, 1, 1, 1],
		[1, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 1]
	], [Vector2i(3, 0), Vector2i(0, 2), Vector2i(5, 2)], "house", "normal"))
	
	# Kitchen with island
	house_rooms.append(RoomTemplate.new("kitchen", [
		[1, 1, 1, 1, 1, 1, 1, 1],
		[1, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 1, 1, 0, 0, 1],
		[1, 0, 0, 1, 1, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 1, 1, 1]
	], [Vector2i(4, 0), Vector2i(0, 3), Vector2i(7, 3)], "house", "normal"))
	
	# Living room (start room)
	house_rooms.append(RoomTemplate.new("living_room", [
		[1, 1, 1, 1, 1, 1, 1, 1, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 1, 1, 1, 1]
	], [Vector2i(4, 0), Vector2i(4, 6), Vector2i(0, 3), Vector2i(8, 3)], "house", "start"))
	
	# L-shaped hallway
	house_rooms.append(RoomTemplate.new("hallway_l", [
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1, 1, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 1, 1]
	], [Vector2i(2, 0), Vector2i(0, 3), Vector2i(6, 6)], "house", "normal"))
	
	return house_rooms

# ============================================================================
# CAVE BIOME
# ============================================================================

static func _create_cave_templates() -> Array[RoomTemplate]:
	var cave_rooms: Array[RoomTemplate] = []
	
	# Organic cave chamber
	cave_rooms.append(RoomTemplate.new("cave_chamber", [
		[-1, -1, 1, 1, 1, 1, -1, -1],
		[-1, 1, 0, 0, 0, 0, 1, -1],
		[1, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 1],
		[-1, 1, 0, 0, 0, 0, 1, -1],
		[-1, -1, 1, 1, 1, 1, -1, -1]
	], [Vector2i(3, 0), Vector2i(4, 6), Vector2i(0, 3), Vector2i(7, 3)], "cave", "normal"))
	
	# Narrow passage
	cave_rooms.append(RoomTemplate.new("cave_passage", [
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1]
	], [Vector2i(2, 0), Vector2i(2, 6)], "cave", "normal"))
	
	# Large cavern (start)
	cave_rooms.append(RoomTemplate.new("large_cavern", [
		[-1, -1, 1, 1, 1, 1, 1, 1, -1, -1],
		[-1, 1, 0, 0, 0, 0, 0, 0, 1, -1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[-1, 1, 0, 0, 0, 0, 0, 0, 1, -1],
		[-1, -1, 1, 1, 1, 1, 1, 1, -1, -1]
	], [Vector2i(5, 0), Vector2i(5, 7), Vector2i(0, 4), Vector2i(9, 4)], "cave", "start"))
	
	# Crystal cave (treasure)
	cave_rooms.append(RoomTemplate.new("crystal_cave", [
		[-1, 1, 1, 1, 1, 1, -1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 0, 3, 0, 3, 0, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 0, 3, 0, 3, 0, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[-1, 1, 1, 1, 1, 1, -1]
	], [Vector2i(3, 0)], "cave", "treasure"))
	
	return cave_rooms

# ============================================================================
# DUNGEON BIOME
# ============================================================================

static func _create_dungeon_templates() -> Array[RoomTemplate]:
	var dungeon_rooms: Array[RoomTemplate] = []
	
	# Large entry hall (start) - 3x bigger
	var large_entry: Array[Array] = []
	for i in range(25):
		var row: Array[int] = []
		if i == 0 or i == 24:
			for j in range(30):
				row.append(WALL)
		else:
			row.append(WALL)
			for j in range(28):
				row.append(FLOOR)
			row.append(WALL)
		large_entry.append(row)
	
	var entry_doors: Array[Vector2i] = [Vector2i(15, 24), Vector2i(0, 12), Vector2i(29, 12)]
	dungeon_rooms.append(RoomTemplate.new("large_entry_hall", large_entry, entry_doors, "dungeon", "start"))
	
	# Large throne room (boss) - 3x bigger
	var large_throne: Array[Array] = []
	for i in range(30):
		var row: Array[int] = []
		if i == 0 or i == 29:
			for j in range(35):
				row.append(WALL)
		else:
			row.append(WALL)
			for j in range(33):
				if (i >= 15 and i <= 20) and (j >= 15 and j <= 18):
					row.append(DECORATION)  # Throne area
				else:
					row.append(FLOOR)
			row.append(WALL)
		large_throne.append(row)
	
	var throne_doors: Array[Vector2i] = [Vector2i(17, 0)]
	dungeon_rooms.append(RoomTemplate.new("large_throne_room", large_throne, throne_doors, "dungeon", "boss"))
	
	# Large pillar room (normal) - 3x bigger  
	var large_pillar: Array[Array] = []
	for i in range(28):
		var row: Array[int] = []
		if i == 0 or i == 27:
			for j in range(30):
				row.append(WALL)
		else:
			row.append(WALL)
			for j in range(28):
				# Add pillars
				if (i >= 8 and i <= 10 and j >= 8 and j <= 10) or \
				   (i >= 8 and i <= 10 and j >= 18 and j <= 20) or \
				   (i >= 17 and i <= 19 and j >= 8 and j <= 10) or \
				   (i >= 17 and i <= 19 and j >= 18 and j <= 20):
					row.append(WALL)
				else:
					row.append(FLOOR)
			row.append(WALL)
		large_pillar.append(row)
	
	var pillar_doors: Array[Vector2i] = [Vector2i(15, 0), Vector2i(15, 27), Vector2i(0, 14), Vector2i(29, 14)]
	dungeon_rooms.append(RoomTemplate.new("large_pillar_room", large_pillar, pillar_doors, "dungeon", "normal"))
	
	return dungeon_rooms

# ============================================================================
# CRYPT BIOME
# ============================================================================

static func _create_crypt_templates() -> Array[RoomTemplate]:
	var crypt_rooms: Array[RoomTemplate] = []
	
	# Tomb chamber
	crypt_rooms.append(RoomTemplate.new("tomb_chamber", [
		[1, 1, 1, 1, 1, 1, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 0, 3, 0, 3, 0, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 0, 3, 0, 3, 0, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 1, 1]
	], [Vector2i(3, 0), Vector2i(0, 3), Vector2i(6, 3)], "crypt", "normal"))
	
	# Sarcophagus hall
	crypt_rooms.append(RoomTemplate.new("sarcophagus_hall", [
		[1, 1, 1, 1, 1, 1, 1, 1, 1],
		[1, 3, 0, 0, 0, 0, 0, 3, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 3, 0, 0, 0, 0, 0, 3, 1],
		[1, 1, 1, 1, 1, 1, 1, 1, 1]
	], [Vector2i(4, 0), Vector2i(4, 5), Vector2i(0, 3), Vector2i(8, 3)], "crypt", "start"))
	
	# Crypt boss chamber
	crypt_rooms.append(RoomTemplate.new("crypt_boss", [
		[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 3, 0, 0, 0, 0, 3, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 3, 3, 0, 0, 0, 1],
		[1, 0, 0, 0, 3, 3, 0, 0, 0, 1],
		[1, 0, 3, 0, 0, 0, 0, 3, 0, 1],
		[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
	], [Vector2i(5, 0)], "crypt", "boss"))
	
	return crypt_rooms

# ============================================================================
# FOREST BIOME
# ============================================================================

static func _create_forest_templates() -> Array[RoomTemplate]:
	var forest_rooms: Array[RoomTemplate] = []
	
	# Forest clearing
	forest_rooms.append(RoomTemplate.new("clearing", [
		[-1, 1, 1, 1, 1, 1, -1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 3, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[-1, 1, 1, 1, 1, 1, -1]
	], [Vector2i(3, 0), Vector2i(3, 6), Vector2i(0, 3), Vector2i(6, 3)], "forest", "start"))
	
	# Tree grove
	forest_rooms.append(RoomTemplate.new("grove", [
		[1, 1, 1, 1, 1, 1, 1, 1],
		[1, 0, 0, 3, 0, 0, 3, 1],
		[1, 0, 0, 0, 0, 0, 0, 1],
		[1, 3, 0, 0, 0, 0, 0, 1],
		[1, 0, 0, 0, 0, 0, 3, 1],
		[1, 1, 1, 1, 1, 1, 1, 1]
	], [Vector2i(4, 0), Vector2i(0, 3), Vector2i(7, 3)], "forest", "normal"))
	
	return forest_rooms
