# faction_manager.gd
# AutoLoad singleton - faction definitions and player reputation with each.
# Status thresholds: hostile < -50 <= unfriendly < -10 <= neutral <= 10 < friendly <= 50 < allied.
# Owned by A6 (World & Story). See docs/ARCHITECTURE_CONTRACTS.md sections 2.6 and 3.
extends Node

const REP_MIN: int = -100
const REP_MAX: int = 100

# faction_id -> {faction_id, display_name, description}
var factions: Dictionary = {}
# faction_id -> int reputation (-100..100)
var reputations: Dictionary = {}

func _ready():
	_register_default_factions()
	print("Factions: FactionManager initialized — ", factions.size(), " factions registered")

func _register_default_factions():
	"""Register the three Zone 1 factions, all starting at neutral (0)."""
	register_faction("merchants_guild", "The Merchants' Guild",
		"Caravan masters and coin-counters who keep the Borderlands' roads and markets alive. They pay well for safe roads and recovered cargo.")
	register_faction("order_of_dawn", "The Order of the Dawn",
		"A knightly order sworn to burn back the undead. Zealous, disciplined, and stretched thin along the border forts.")
	register_faction("gravewardens", "The Gravewardens",
		"Quiet keepers of barrows and burial rites. They know more about the old dead of the Borderlands than anyone living — and say less.")

func register_faction(faction_id: String, display_name: String, description: String):
	"""Register a faction definition; reputation starts at 0 unless already tracked."""
	factions[faction_id] = {
		"faction_id": faction_id,
		"display_name": display_name,
		"description": description,
	}
	if not reputations.has(faction_id):
		reputations[faction_id] = 0

# === REPUTATION ===

func get_reputation(faction_id: String) -> int:
	return reputations.get(faction_id, 0)

func modify_reputation(faction_id: String, delta: int):
	"""Adjust reputation (clamped to -100..100). Emits reputation_changed, and
	faction_status_changed (+ a UI notification) when a status threshold is crossed."""
	if not factions.has(faction_id):
		push_error("Factions: modify_reputation on unknown faction: " + faction_id)
		return
	if delta == 0:
		return

	var old_value: int = int(reputations.get(faction_id, 0))
	var new_value: int = clampi(old_value + delta, REP_MIN, REP_MAX)
	if new_value == old_value:
		return

	reputations[faction_id] = new_value
	EventBus.reputation_changed.emit(faction_id, old_value, new_value)
	print("Factions: %s reputation %d -> %d" % [faction_id, old_value, new_value])

	var old_status := _status_for_value(old_value)
	var new_status := _status_for_value(new_value)
	if old_status != new_status:
		EventBus.faction_status_changed.emit(faction_id, new_status)
		var display_name: String = factions[faction_id].get("display_name", faction_id)
		var type := "success" if new_value > old_value else "warning"
		EventBus.notify("%s now regards you as %s." % [display_name, new_status], type)

func get_status(faction_id: String) -> String:
	"""Returns 'hostile' | 'unfriendly' | 'neutral' | 'friendly' | 'allied'"""
	return _status_for_value(get_reputation(faction_id))

func _status_for_value(value: int) -> String:
	"""Map a reputation value to a status band (thresholds -50/-10/+10/+50)."""
	if value < -50:
		return "hostile"
	elif value < -10:
		return "unfriendly"
	elif value <= 10:
		return "neutral"
	elif value <= 50:
		return "friendly"
	return "allied"

func get_all_factions() -> Array:
	return factions.values()

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Export faction reputations (definitions are static code registries)."""
	return {
		"reputations": reputations.duplicate(),
	}

func from_dict(data: Dictionary):
	"""Restore reputations from a save. No signals are emitted while loading."""
	var loaded: Dictionary = data.get("reputations", {})
	for faction_id in loaded:
		reputations[faction_id] = clampi(int(loaded[faction_id]), REP_MIN, REP_MAX)
	print("Factions: loaded reputations for ", loaded.size(), " factions")
