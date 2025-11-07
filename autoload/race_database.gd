# autoload/race_database.gd
extends Node

var races: Dictionary = {}

func _ready():
	races["human"] = load("res://data/races/human.tres")
	races["elf"] = load("res://data/races/elf.tres")
	races["dwarf"] = load("res://data/races/dwarf.tres")
	races["halfling"] = load("res://data/races/halfling.tres")
	print("RaceDatabase loaded: ", races.size(), " races")

func get_race_data(race_id: String) -> RaceData:  # Changed from get_race
	return races.get(race_id, null)

func get_all_races() -> Array:
	return races.values()
