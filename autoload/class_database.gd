# autoload/class_database.gd
extends Node

var classes: Dictionary = {}

func _ready():
	classes["fighter"] = load("res://data/classes/fighter.tres")
	classes["wizard"] = load("res://data/classes/wizard.tres")
	classes["rogue"] = load("res://data/classes/rogue.tres")
	classes["cleric"] = load("res://data/classes/cleric.tres")
	print("ClassDatabase loaded: ", classes.size(), " classes")

func get_class_data(class_id: String) -> ClassData:  # Changed from get_class
	return classes.get(class_id, null)

func get_all_classes() -> Array:
	return classes.values()
