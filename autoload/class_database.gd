# autoload/class_database.gd
extends Node

var classes: Dictionary = {}

func _ready():
	_load_class("fighter", "res://data/classes/fighter.tres")
	_load_class("wizard", "res://data/classes/wizard.tres")
	_load_class("rogue", "res://data/classes/rogue.tres")
	_load_class("cleric", "res://data/classes/cleric.tres")
	print("ClassDatabase loaded: ", classes.size(), " classes")

func _load_class(class_id: String, path: String):
	"""Load a ClassData .tres into the registry (skips with an error if missing/broken)"""
	if not ResourceLoader.exists(path):
		push_error("ClassDatabase: missing class resource: " + path)
		return
	var class_data = load(path)
	if class_data == null:
		push_error("ClassDatabase: failed to load class resource: " + path)
		return
	classes[class_id] = class_data

func get_class_data(class_id: String) -> ClassData:  # Changed from get_class
	return classes.get(class_id, null)

func get_all_classes() -> Array:
	return classes.values()

func get_all_class_ids() -> Array:
	return classes.keys()
