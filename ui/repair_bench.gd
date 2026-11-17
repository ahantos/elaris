# repair_bench.gd
# Field repair on the character sheet (scenes/ui/repair_bench.tscn): how many
# repair kits and what scrap the pack holds, a place to drop a worn piece to
# mend one notch of it, a place to drop a spare piece to turn it into scrap,
# and a button that mends everything worn while kits and scrap last.
# Display and input only. It shows what the sheet tells it and reports the
# button; the sheet asks the CombatController for the repair or the salvage.
extends PanelContainer

signal repair_all_pressed()

@onready var _supplies: Label = %Supplies
@onready var _scrap: Label = %Scrap
@onready var _repair_zone: PanelContainer = %RepairZone
@onready var _salvage_zone: PanelContainer = %SalvageZone
@onready var _repair_all: Button = %RepairAll
@onready var _note: Label = %Note

func _ready():
	_repair_all.pressed.connect(func(): repair_all_pressed.emit())

func refresh(character: CharacterStats, repair_all_refusal: String):
	"""Show the supplies in the pack and what the character's gear needs.
	repair_all_refusal is why everything cannot be repaired now ("" when it
	can): the controller's answer, which the sheet asked for."""
	var kits: int = DurabilityManager.count_repair_kits()
	_supplies.text = "Repair kits: %d" % kits
	var scraps: Array = []
	for carried in InventoryManager.items:
		if ItemDatabase.is_scrap(carried.item_data):
			scraps.append("%s x%d (%s %d)" % [carried.item_data.material.material_name, int(carried.get("stack_count", 1)),
				carried.item_data.material.get_kind(), carried.item_data.material.hardness])
	_scrap.text = "Scrap: %s" % (", ".join(scraps) if not scraps.is_empty() else "none - salvage a spare piece")

	var lost: int = 0
	if character != null:
		for piece in DurabilityManager.get_repairable_pieces(character):
			lost += DurabilityManager.get_lost_notches(piece)
	_repair_all.text = "REPAIR ALL WORN" if lost == 0 else "REPAIR ALL WORN - %d %s lost" % [lost, "notch" if lost == 1 else "notches"]
	_repair_all.disabled = repair_all_refusal != ""
	_repair_all.tooltip_text = repair_all_refusal
	_note.text = repair_all_refusal if repair_all_refusal != "" and lost > 0 else "A kit and one scrap of the piece's kind, at least as hard, mend one notch. Right-click a worn slot to repair it."

func is_over_repair(point: Vector2) -> bool:
	"""True when a point of the screen is on the place a piece is dropped to be repaired"""
	return _repair_zone.is_visible_in_tree() and _repair_zone.get_global_rect().has_point(point)

func is_over_salvage(point: Vector2) -> bool:
	"""True when a point of the screen is on the place a piece is dropped to be salvaged"""
	return _salvage_zone.is_visible_in_tree() and _salvage_zone.get_global_rect().has_point(point)

func get_repair_all_button() -> Button:
	return _repair_all

func get_lines() -> Array[String]:
	"""The text on show: for checks"""
	return [_supplies.text, _scrap.text, _repair_all.text, _note.text]
