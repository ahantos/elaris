extends Node2D

@onready var dungeon: DungeonGenerator = $DungeonGenerator
@onready var camera: Camera2D = $Camera2D

func _ready():
	# Center camera on dungeon
	camera.position = Vector2(dungeon.dungeon_width * 8, dungeon.dungeon_height * 8)
	camera.zoom = Vector2(0.5, 0.5)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		# Regenerate same biome
		dungeon.regenerate()
		print("Dungeon regenerated!")
	
	elif event.is_action_pressed("ui_cancel"):
		# Cycle through biomes
		var biomes = ["house", "cave", "dungeon", "crypt", "forest"]
		var current_index = biomes.find(dungeon.biome_type)
		var next_index = (current_index + 1) % biomes.size()
		dungeon.set_biome(biomes[next_index])
		print("Switched to biome: ", biomes[next_index])
