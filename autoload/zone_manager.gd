# zone_manager.gd
# AutoLoad singleton - the 9 world zones, current zone, travel, zone->biome mapping.
# Travel emits EventBus.zone_changed; the world layer (integration) listens and
# regenerates the dungeon for the new zone's biome/danger tier.
# Owned by A6 (World & Story). Zone data lives in data/zones/zone_library.gd.
extends Node

const ZoneLibrary = preload("res://data/zones/zone_library.gd")

# zone_id -> {zone_id, display_name, description, biome, danger_tier, cities: Array, unlocked: bool}
var zones: Dictionary = {}
var current_zone_id: String = "zone_1"

func _ready():
	zones = ZoneLibrary.get_definitions()
	print("Zones: ZoneManager initialized — ", zones.size(), " zones registered (current: ", current_zone_id, ")")

# === QUERIES ===

func get_zone(zone_id: String) -> Dictionary:
	return zones.get(zone_id, {})

func get_all_zones() -> Array:
	return zones.values()

func get_current_zone() -> Dictionary:
	return zones.get(current_zone_id, {})

func is_unlocked(zone_id: String) -> bool:
	"""True if the zone exists and is unlocked for travel."""
	return bool(zones.get(zone_id, {}).get("unlocked", false))

# === TRAVEL ===

func travel_to(zone_id: String) -> bool:
	"""Travel to a zone. Must exist and be unlocked. Emits EventBus.zone_changed
	(integration regenerates the dungeon in response). Traveling to the current
	zone is a no-op success (no signal)."""
	if not zones.has(zone_id):
		push_error("Zones: travel_to unknown zone: " + zone_id)
		return false
	if not is_unlocked(zone_id):
		print("Zones: travel refused — ", zone_id, " is locked")
		EventBus.notify("That region is not yet open to you.", "warning")
		return false
	if zone_id == current_zone_id:
		print("Zones: already in ", zone_id)
		return true

	var old_zone_id := current_zone_id
	current_zone_id = zone_id
	var display_name: String = zones[zone_id].get("display_name", zone_id)
	print("Zones: traveling ", old_zone_id, " -> ", zone_id)
	EventBus.zone_changed.emit(old_zone_id, zone_id)
	EventBus.notify("You travel to %s." % display_name, "info")
	return true

func unlock_zone(zone_id: String):
	"""Unlock a zone for travel (e.g. from quest rewards or crisis phases)."""
	if not zones.has(zone_id):
		push_error("Zones: unlock_zone unknown zone: " + zone_id)
		return
	if is_unlocked(zone_id):
		return
	zones[zone_id]["unlocked"] = true
	var display_name: String = zones[zone_id].get("display_name", zone_id)
	print("Zones: unlocked ", zone_id)
	EventBus.location_discovered.emit(display_name)
	EventBus.notify("New region unlocked: %s!" % display_name, "success")

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Export current zone + per-zone unlocked flags (definitions are static)."""
	var unlocked: Dictionary = {}
	for zone_id in zones:
		unlocked[zone_id] = bool(zones[zone_id].get("unlocked", false))
	return {
		"current_zone_id": current_zone_id,
		"unlocked": unlocked,
	}

func from_dict(data: Dictionary):
	"""Restore current zone + unlocked flags. Does NOT emit zone_changed —
	the save/load layer is responsible for regenerating the world afterwards."""
	var unlocked: Dictionary = data.get("unlocked", {})
	for zone_id in unlocked:
		if zones.has(zone_id):
			zones[zone_id]["unlocked"] = bool(unlocked[zone_id])
	var loaded_zone: String = str(data.get("current_zone_id", "zone_1"))
	if zones.has(loaded_zone):
		current_zone_id = loaded_zone
	else:
		push_error("Zones: save referenced unknown zone '" + loaded_zone + "', defaulting to zone_1")
		current_zone_id = "zone_1"
	print("Zones: loaded — current zone ", current_zone_id)
