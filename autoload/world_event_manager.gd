# world_event_manager.gd
# AutoLoad singleton - random world events and the escalating crisis framework
# ("The Lich King Rises": 4 phases). Owned by A6 (World & Story).
# Event/crisis data lives in data/world_events/world_event_library.gd.
#
# Integration calls maybe_trigger_random_event() at natural beats (e.g. after a
# dungeon regenerates, on zone travel, or after a rest); it rolls an overall
# chance, weighted-picks an event, applies its effects, and emits
# EventBus.random_event_triggered.
extends Node

const WorldEventLibrary = preload("res://data/world_events/world_event_library.gd")

# Default overall chance that maybe_trigger_random_event fires at all.
const DEFAULT_EVENT_CHANCE: float = 0.25

# event_id -> event definition; crisis_id -> crisis definition (see library schema)
var random_events: Dictionary = {}
var crises: Dictionary = {}

# crisis_id -> current phase int (0 = dormant; 1..N = phase index)
var crisis_phases: Dictionary = {}
# Array of event_id Strings, in trigger order
var event_history: Array = []

func _ready():
	random_events = WorldEventLibrary.get_event_definitions()
	crises = WorldEventLibrary.get_crisis_definitions()
	for crisis_id in crises:
		if not crisis_phases.has(crisis_id):
			crisis_phases[crisis_id] = 0
	print("WorldEvents: WorldEventManager initialized — ", random_events.size(),
		" random events, ", crises.size(), " crises registered")

# === RANDOM EVENTS ===

func maybe_trigger_random_event(context: Dictionary = {}) -> String:
	"""Roll for a random event; on success applies its effects, emits
	random_event_triggered and returns the event_id (else ''). Context keys:
	'chance' (float) overrides the default 25% trigger chance."""
	if random_events.is_empty():
		return ""
	var chance: float = float(context.get("chance", DEFAULT_EVENT_CHANCE))
	if randf() >= chance:
		return ""

	var event: Dictionary = _pick_weighted_event()
	if event.is_empty():
		return ""
	var event_id: String = event.get("event_id", "")

	print("WorldEvents: triggered '", event_id, "'")
	EventBus.notify("%s — %s" % [event.get("display_name", event_id), event.get("description", "")],
		str(event.get("effects", {}).get("notify_type", "info")))
	_apply_event_effects(event)

	event_history.append(event_id)
	EventBus.random_event_triggered.emit(event_id)
	return event_id

func _pick_weighted_event() -> Dictionary:
	"""Pick one event definition proportionally to its 'weight'."""
	var total: int = 0
	for event_id in random_events:
		total += maxi(0, int(random_events[event_id].get("weight", 1)))
	if total <= 0:
		return {}
	var roll: int = randi_range(1, total)
	for event_id in random_events:
		roll -= maxi(0, int(random_events[event_id].get("weight", 1)))
		if roll <= 0:
			return random_events[event_id]
	return {}

func _apply_event_effects(event: Dictionary):
	"""Apply an event's effects Dictionary (see world_event_library.gd header)."""
	var effects: Dictionary = event.get("effects", {})

	# Gold
	var gold_amount: int = int(effects.get("gold", 0))
	if gold_amount > 0:
		InventoryManager.add_gold(gold_amount)

	# Items
	for entry in effects.get("items", []):
		var item_id: String = str(entry.get("item_id", ""))
		var count: int = int(entry.get("count", 1))
		for _i in range(count):
			var instance: Dictionary = ItemDatabase.create_item_instance(item_id)
			if instance.is_empty():
				push_error("WorldEvents: event item not found: " + item_id)
				break
			InventoryManager.add_item(instance)

	# Full heal (wandering_healer)
	if bool(effects.get("heal_full", false)):
		_heal_player_fully()

	# Status effect on the player node (shrine_blessing)
	var status: Dictionary = effects.get("status_effect", {})
	if not status.is_empty():
		var player = GameManager.player
		if player != null and is_instance_valid(player) \
				and StatusEffectManager.has_method("apply_effect"):
			StatusEffectManager.apply_effect(player, str(status.get("effect_id", "")),
				int(status.get("duration", 0)))

	# Reputation ("random" picks a random known faction)
	var rep: Dictionary = effects.get("reputation", {})
	if not rep.is_empty():
		var faction_id: String = str(rep.get("faction_id", ""))
		if faction_id == "random":
			var ids: Array = FactionManager.factions.keys()
			if not ids.is_empty():
				faction_id = ids[randi() % ids.size()]
			else:
				faction_id = ""
		if faction_id != "":
			FactionManager.modify_reputation(faction_id, int(rep.get("delta", 0)))

func _heal_player_fully():
	"""Fully heal the player, defensively (player may not exist in headless boots)."""
	var player = GameManager.player
	if player == null or not is_instance_valid(player):
		return
	var stats = player.get("stats")
	if stats == null:
		return
	var missing: int = int(stats.max_hp) - int(stats.current_hp)
	if missing <= 0:
		return
	if player.has_method("heal"):
		player.heal(missing)
	elif stats.has_method("heal"):
		stats.heal(missing)
	EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)

# === CRISIS FRAMEWORK ===

func get_crisis_phase(crisis_id: String) -> int:
	"""Current phase of a crisis: 0 = dormant, 1..N = active phase index."""
	return int(crisis_phases.get(crisis_id, 0))

func advance_crisis(crisis_id: String):
	"""Advance a crisis to its next phase. Emits crisis_phase_changed and a
	UI notification with the new phase's name and description."""
	if not crises.has(crisis_id):
		push_error("WorldEvents: advance_crisis on unknown crisis: " + crisis_id)
		return
	var phases: Array = crises[crisis_id].get("phases", [])
	var current: int = get_crisis_phase(crisis_id)
	if current >= phases.size():
		print("WorldEvents: crisis '", crisis_id, "' already at final phase")
		return

	var new_phase: int = current + 1
	crisis_phases[crisis_id] = new_phase
	var phase_data: Dictionary = phases[new_phase - 1]
	var crisis_name: String = crises[crisis_id].get("display_name", crisis_id)

	print("WorldEvents: crisis '", crisis_id, "' advanced to phase ", new_phase,
		" (", phase_data.get("name", "?"), ")")
	EventBus.crisis_phase_changed.emit(crisis_id, new_phase)
	EventBus.notify("%s — %s: %s" % [crisis_name, phase_data.get("name", ""),
		phase_data.get("description", "")], "warning")

func get_crisis(crisis_id: String) -> Dictionary:
	"""Full crisis definition (display_name + phases array)."""
	return crises.get(crisis_id, {})

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Export crisis phases + triggered-event history (definitions are static)."""
	return {
		"crisis_phases": crisis_phases.duplicate(),
		"event_history": event_history.duplicate(),
	}

func from_dict(data: Dictionary):
	"""Restore crisis phases + event history. No signals are emitted while loading."""
	var loaded_phases: Dictionary = data.get("crisis_phases", {})
	for crisis_id in loaded_phases:
		crisis_phases[crisis_id] = int(loaded_phases[crisis_id])
	event_history = data.get("event_history", []).duplicate()
	print("WorldEvents: loaded — ", event_history.size(), " events in history, crisis phases: ",
		crisis_phases)
