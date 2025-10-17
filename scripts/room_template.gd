class_name RoomTemplate
extends RefCounted

# Room template data structure
var layout: Array[Array] # 2D array of tile types
var width: int
var height: int
var doorways: Array[Vector2i] # Possible door positions (relative to room)
var room_type: String # "normal", "start", "boss", "treasure"
var biome: String # "house", "cave", "dungeon", etc.
var name: String # Template identifier

func _init(p_name: String, p_layout: Array[Array], p_doorways: Array[Vector2i], p_biome: String, p_type: String = "normal"):
	name = p_name
	layout = p_layout
	height = layout.size()
	width = layout[0].size() if height > 0 else 0
	doorways = p_doorways
	biome = p_biome
	room_type = p_type

func get_center() -> Vector2i:
	return Vector2i(int(width / 2), int(height / 2))
