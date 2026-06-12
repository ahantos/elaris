# autoload/race_database.gd
extends Node

var races: Dictionary = {}

func _ready():
	_load_race("human", "res://data/races/human.tres")
	_load_race("elf", "res://data/races/elf.tres")
	_load_race("dwarf", "res://data/races/dwarf.tres")
	_load_race("halfling", "res://data/races/halfling.tres")
	_load_race("half_orc", "res://data/races/half_orc.tres")
	print("RaceDatabase loaded: ", races.size(), " races")

func _load_race(race_id: String, path: String):
	"""Load a RaceData .tres into the registry (skips with an error if missing/broken)"""
	if not ResourceLoader.exists(path):
		push_error("RaceDatabase: missing race resource: " + path)
		return
	var race_data = load(path)
	if race_data == null:
		push_error("RaceDatabase: failed to load race resource: " + path)
		return
	races[race_id] = race_data

func get_race_data(race_id: String) -> RaceData:  # Changed from get_race
	return races.get(race_id, null)

func get_all_races() -> Array:
	return races.values()

func get_all_race_ids() -> Array:
	return races.keys()
