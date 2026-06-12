# save_manager.gd
# AutoLoad singleton - full-state, versioned, multi-slot save/load.
# Aggregates to_dict()/from_dict() from the player's CharacterStats and every
# stateful system manager. Payloads contain ONLY primitives (store_var-safe).
# Owned by A8 (Save/Load) - see docs/ARCHITECTURE_CONTRACTS.md section 4.
extends Node

const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_slot_"
const SAVE_FILE_EXT: String = ".sav"

# Save FORMAT version (not the game version - that is stored separately as
# "game_version"). Bump when the payload schema changes shape.
const SAVE_FORMAT_VERSION: int = 2

# from_dict() application order for v2 loads. ORDER MATTERS:
# - factions/zones/world_events/quests/crafting/companions are independent
#   id-keyed state and load first (quests after factions so any future
#   faction-gated quest logic sees final reputations).
# - spells next: resolves the "player" uid through GameManager.player.stats,
#   which must already carry its restored class_id/level.
# - inventory LAST: its equipment resolution needs the final CharacterStats
#   and ends by recalculating equipment bonuses on top of the restored stats.
const SYSTEM_LOAD_ORDER: Array = [
	"factions", "zones", "world_events", "quests",
	"crafting", "companions", "spells", "inventory"
]

func _ready():
	print("SaveManager: initialized (multi-slot, save format v", SAVE_FORMAT_VERSION, ")")
	# Ensure save directory exists
	DirAccess.make_dir_absolute(SAVE_DIR)

# === SAVE ===

func save_game(slot: int = 0) -> bool:
	"""Save the full game state (player stats/position + every system manager)
	to a slot. Returns false (with push_error) when there is no player or the
	file cannot be written. Emits EventBus.game_saved(slot) on success."""
	print("SaveManager: === SAVING GAME TO SLOT ", slot, " ===")

	var player = GameManager.player
	if player == null or not is_instance_valid(player) or player.get("stats") == null:
		push_error("SaveManager: no player to save - aborting")
		return false
	if not player.stats.has_method("to_dict"):
		push_error("SaveManager: player stats missing to_dict() - aborting")
		return false

	var save_data: Dictionary = {
		"version": SAVE_FORMAT_VERSION,
		"game_version": GameManager.GAME_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"player": {
			"stats": player.stats.to_dict(),
			"position_x": player.grid_position.x,
			"position_y": player.grid_position.y
		},
		"systems": _collect_system_data()
	}

	var save_path = _get_save_path(slot)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: failed to open save file: " + save_path)
		return false

	file.store_var(save_data)
	file.close()

	print("SaveManager: SAVE COMPLETE - slot ", slot,
		" | level ", player.stats.level,
		" | pos (", player.grid_position.x, ", ", player.grid_position.y, ")",
		" | hp ", player.stats.current_hp, "/", player.stats.max_hp,
		" | gold ", InventoryManager.gold,
		" | systems ", save_data.systems.keys())

	EventBus.game_saved.emit(slot)
	return true

func _collect_system_data() -> Dictionary:
	"""Call to_dict() on every system manager defensively: a manager without a
	usable to_dict() is skipped with a push_error instead of failing the save."""
	var systems: Dictionary = {}
	var managers = _get_system_managers()
	for key in managers:
		var manager = managers[key]
		if manager == null or not is_instance_valid(manager) or not manager.has_method("to_dict"):
			push_error("SaveManager: system '" + str(key) + "' has no to_dict() - skipped from save")
			continue
		var data = manager.to_dict()
		if data is Dictionary:
			systems[key] = data
		else:
			push_error("SaveManager: system '" + str(key) + "' to_dict() returned a non-Dictionary - skipped")
	return systems

# === LOAD ===

func load_game(slot: int = 0) -> bool:
	"""Load a save slot onto the LIVE game state (no scene reload).
	v2 saves restore player stats + position + all system managers; legacy v1
	saves restore only position/HP/gold with a UI warning. Emits
	EventBus.game_loaded(slot) exactly once at the very end - the world layer
	listens to resync visuals, companions and combat state."""
	print("SaveManager: === LOADING GAME FROM SLOT ", slot, " ===")

	var save_path = _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		print("SaveManager: no save file found in slot ", slot)
		return false

	var save_data = _read_save_data(slot)
	if save_data.is_empty():
		push_error("SaveManager: save file corrupted in slot " + str(slot))
		return false

	var player = GameManager.player
	if player == null or not is_instance_valid(player) or player.get("stats") == null:
		push_error("SaveManager: no player to load data into - aborting")
		return false

	# Known rough edge: loading mid-combat. Combat teardown is the world
	# layer's job (game_loaded handler) - we only warn, never crash.
	var world = GameManager.world
	if world != null and is_instance_valid(world) and world.get("in_combat") == true:
		print("SaveManager: WARNING - loading while in combat; world layer must tear down combat on game_loaded")

	var version = _payload_version(save_data)
	if version < SAVE_FORMAT_VERSION:
		return _load_legacy_v1(save_data, slot)

	# --- v2 full-state load. ORDER MATTERS (see SYSTEM_LOAD_ORDER docs). ---

	# (a) Player stats first, onto the EXISTING CharacterStats instance.
	# SpellManager/InventoryManager key runtime state by this exact instance,
	# so it must NEVER be replaced.
	var player_data: Dictionary = _dict_at(save_data, "player")
	var stats_data: Dictionary = _dict_at(player_data, "stats")
	if stats_data.is_empty():
		print("SaveManager: save has no player stats - keeping current stats")
	elif player.stats.has_method("from_dict"):
		player.stats.from_dict(stats_data)
	else:
		push_error("SaveManager: player stats missing from_dict() - stats not restored")

	# (b) Player position + full movement-state reset.
	_restore_player_position(player, player_data)

	# (c) System managers in dependency order (inventory LAST - its equipment
	# resolution needs the final stats and recalculates bonuses).
	var systems: Dictionary = _dict_at(save_data, "systems")
	for key in systems:
		if not SYSTEM_LOAD_ORDER.has(key):
			print("SaveManager: unknown system '", key, "' in save - ignored")
	var managers = _get_system_managers()
	for key in SYSTEM_LOAD_ORDER:
		if not systems.has(key):
			print("SaveManager: save has no '", key, "' system data - skipped")
			continue
		var manager = managers.get(key)
		if manager == null or not is_instance_valid(manager) or not manager.has_method("from_dict"):
			push_error("SaveManager: system '" + str(key) + "' has no from_dict() - skipped")
			continue
		manager.from_dict(systems[key])

	# (d) Refresh visuals/UI, then announce ONCE. The world layer resyncs
	# enemy/companion visuals on game_loaded - SaveManager never touches nodes.
	player.queue_redraw()
	EventBus.player_hp_changed.emit(player.stats.current_hp, player.stats.max_hp)

	print("SaveManager: GAME LOADED - slot ", slot,
		" | level ", player.stats.level,
		" | pos (", player.grid_position.x, ", ", player.grid_position.y, ")",
		" | hp ", player.stats.current_hp, "/", player.stats.max_hp,
		" | gold ", InventoryManager.gold)

	EventBus.game_loaded.emit(slot)
	return true

func _load_legacy_v1(save_data: Dictionary, slot: int) -> bool:
	"""Partial load for pre-overhaul (v1) saves: position, HP and gold only.
	System managers keep their current state; the player gets a UI warning."""
	print("SaveManager: legacy v1 save in slot ", slot, " - partial load (position/HP/gold), systems skipped")
	EventBus.ui_notification.emit("Old save format — partial load", "warning")

	var player = GameManager.player
	_restore_player_position(player, save_data)  # v1 stored position_x/y at top level

	player.stats.max_hp = int(save_data.get("max_hp", player.stats.max_hp))
	player.stats.current_hp = clampi(int(save_data.get("hp", player.stats.current_hp)), 0, player.stats.max_hp)

	InventoryManager.gold = int(save_data.get("gold", InventoryManager.gold))
	EventBus.gold_changed.emit(InventoryManager.gold)

	player.queue_redraw()
	EventBus.player_hp_changed.emit(player.stats.current_hp, player.stats.max_hp)

	print("SaveManager: GAME LOADED (legacy v1) - slot ", slot,
		" | pos (", player.grid_position.x, ", ", player.grid_position.y, ")",
		" | hp ", player.stats.current_hp, "/", player.stats.max_hp,
		" | gold ", InventoryManager.gold)

	EventBus.game_loaded.emit(slot)
	return true

func _restore_player_position(player: Node, position_data: Dictionary):
	"""Restore the player's grid position and fully reset movement state
	(mirrors the pre-overhaul load behavior so no stale path/preview survives).
	position_data needs position_x/position_y; missing keys keep the current tile."""
	var grid_pos = Vector2i(
		int(position_data.get("position_x", player.grid_position.x)),
		int(position_data.get("position_y", player.grid_position.y)))
	player.grid_position = grid_pos
	player.position = player.grid_to_world(grid_pos)
	player.target_position = player.position

	# Reset movement state
	player.stop_moving()
	player.cancel_preview()
	player.is_moving = false
	player.path.clear()
	player.path_index = 0

# === SLOT MANAGEMENT ===

func get_save_info(slot: int) -> Dictionary:
	"""Save metadata for the slot UI. Tolerant of both v1 (flat) and v2 (nested)
	payloads. Returns {} for an empty/corrupt slot, otherwise
	{timestamp, player_level, position, hp, max_hp, gold, zone_id, version}."""
	var save_data = _read_save_data(slot)
	if save_data.is_empty():
		return {}

	var version = _payload_version(save_data)
	if version >= 2:
		var player_data = _dict_at(save_data, "player")
		var stats = _dict_at(player_data, "stats")
		var systems = _dict_at(save_data, "systems")
		var inventory = _dict_at(systems, "inventory")
		var zones = _dict_at(systems, "zones")
		return {
			"timestamp": save_data.get("timestamp", 0),
			"player_level": int(stats.get("level", 1)),
			"position": Vector2i(int(player_data.get("position_x", 0)), int(player_data.get("position_y", 0))),
			"hp": int(stats.get("current_hp", 0)),
			"max_hp": int(stats.get("max_hp", 0)),
			"gold": int(inventory.get("gold", 0)),
			"zone_id": str(zones.get("current_zone_id", "zone_1")),
			"version": version
		}

	# Legacy v1 flat payload
	return {
		"timestamp": save_data.get("timestamp", 0),
		"player_level": int(save_data.get("player_level", 1)),
		"position": Vector2i(int(save_data.get("position_x", 0)), int(save_data.get("position_y", 0))),
		"hp": int(save_data.get("hp", 0)),
		"max_hp": int(save_data.get("max_hp", 0)),
		"gold": int(save_data.get("gold", 0)),
		"zone_id": "zone_1",
		"version": 1
	}

func save_exists(slot: int) -> bool:
	"""Check if a save exists in slot"""
	return FileAccess.file_exists(_get_save_path(slot))

func delete_save(slot: int) -> bool:
	"""Delete save in specific slot"""
	var save_path = _get_save_path(slot)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("SaveManager: save slot ", slot, " deleted")
		return true
	return false

# === INTERNAL HELPERS ===

func _get_system_managers() -> Dictionary:
	"""Save-key -> autoload manager map. Keys are the payload's systems.* keys;
	SYSTEM_LOAD_ORDER must list every key here (load order is defined there)."""
	return {
		"inventory": InventoryManager,
		"spells": SpellManager,
		"crafting": CraftingManager,
		"quests": QuestManager,
		"factions": FactionManager,
		"world_events": WorldEventManager,
		"zones": ZoneManager,
		"companions": CompanionManager
	}

func _read_save_data(slot: int) -> Dictionary:
	"""Read and parse a slot's save file. Returns {} when missing/unreadable/corrupt."""
	var save_path = _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return {}
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}
	var save_data = file.get_var()
	file.close()
	if save_data is Dictionary:
		return save_data
	return {}

func _payload_version(save_data: Dictionary) -> int:
	"""Numeric save-format version of a payload. Legacy saves stored the game
	version STRING under "version" (or nothing at all) - both normalize to 1."""
	var raw = save_data.get("version")
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	return 1

func _dict_at(source: Dictionary, key: String) -> Dictionary:
	"""Nested Dictionary lookup that tolerates missing or non-Dictionary values."""
	var value = source.get(key)
	return value if value is Dictionary else {}

func _get_save_path(slot: int) -> String:
	"""Get file path for save slot"""
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
