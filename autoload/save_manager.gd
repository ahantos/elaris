# save_manager.gd
# AutoLoad singleton - versioned, multi-slot save files.
#
# A save holds the player, every stateful manager, and the world the player is
# standing in (dungeon seed, enemies, ground loot, explored map). Payloads
# contain ONLY primitives (store_var-safe).
#
# SaveManager reads and writes files and talks to the managers. It never
# touches scene nodes: the World scene captures its own state
# (World.get_world_state) and rebuilds itself from a save in its _ready().
#
# Loading never patches the running game. GameManager.load_game() wipes all
# state and starts a fresh World scene that restores from the data, so nothing
# from the previous session can survive a load.
extends Node

const DEFAULT_SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_slot_"

# Where save files live. The checks point this at a scratch folder
# (use_save_directory) so they can never touch the player's real saves.
var save_dir: String = DEFAULT_SAVE_DIR
const SAVE_FILE_EXT: String = ".sav"

# Slots 0..MANUAL_SLOT_COUNT-1 are the player's; AUTOSAVE_SLOT is written by the game.
const MANUAL_SLOT_COUNT: int = 10
const AUTOSAVE_SLOT: int = 100

# Save FORMAT version (not the game version - that is stored separately as
# "game_version"). Bump when the payload changes shape and add a _migrate step.
#   1: flat prototype payload (position, HP, gold)
#   2: player stats + every system manager
#   3: + world (dungeon seed and biome, enemies, ground loot, explored map, companions)
#   4: + two weapon sets (the item of the old "ranged" slot is in set two's main
#        hand; systems.inventory.weapon_sets says which set is in hand)
#      + systems.features (what has been used since the last long rest)
#   5: durability. An item instance that wears carries its condition (notches,
#        notches_max, notches_max_original, marks, age, debuffs, buffs,
#        wear_names, and what its buffs count) in place of the old
#        current_durability points; a wand carries charges; a saved enemy
#        carries the condition of its gear
const SAVE_FORMAT_VERSION: int = 5

# from_dict() application order. ORDER MATTERS:
# - factions/zones/world_events/quests/crafting/companions are independent
#   id-keyed state and load first (quests after factions so any future
#   faction-gated quest logic sees final reputations).
# - spells next: resolves the "player" uid through GameManager.player.stats,
#   which must already carry its restored class_id/level.
# - features: resolves the "player" uid the same way.
# - inventory LAST: its equipment resolution needs the final CharacterStats
#   and ends by recalculating equipment bonuses on top of the restored stats.
const SYSTEM_LOAD_ORDER: Array = [
	"factions", "zones", "world_events", "quests",
	"crafting", "companions", "spells", "features", "inventory"
]

func _ready():
	print("SaveManager: initialized (multi-slot, save format v", SAVE_FORMAT_VERSION, ")")
	DirAccess.make_dir_recursive_absolute(save_dir)

func use_save_directory(directory: String):
	"""Read and write saves in a different folder (a 'user://.../' path).
	Used by tools/ so test runs stay out of the real save folder."""
	save_dir = directory if directory.ends_with("/") else directory + "/"
	DirAccess.make_dir_recursive_absolute(save_dir)
	print("SaveManager: using save directory ", save_dir)

# === SAVE ===

func can_save() -> String:
	"""Empty string when saving is allowed right now, otherwise the reason it is not."""
	var player = GameManager.player
	if player == null or not is_instance_valid(player) or player.get("stats") == null:
		return "There is no game to save."
	if GameManager.is_game_over or not player.stats.is_alive():
		return "You cannot save after death."
	var world = GameManager.world
	if world != null and is_instance_valid(world) and world.get("in_combat") == true:
		return "You cannot save during combat."
	return ""

func save_game(slot: int = 0) -> bool:
	"""Save the full game state to a slot. Returns false, with a notification,
	when saving is not allowed (see can_save) or the file cannot be written.
	Emits EventBus.game_saved(slot) on success."""
	var blocked: String = can_save()
	if blocked != "":
		print("SaveManager: save refused - ", blocked)
		EventBus.ui_notification.emit(blocked, "warning")
		return false

	var player = GameManager.player
	var world = GameManager.world
	var world_state: Dictionary = {}
	if world != null and is_instance_valid(world) and world.has_method("get_world_state"):
		world_state = world.get_world_state()

	var save_data: Dictionary = {
		"version": SAVE_FORMAT_VERSION,
		"game_version": GameManager.GAME_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"player": {
			"stats": player.stats.to_dict(),
			"position_x": player.grid_position.x,
			"position_y": player.grid_position.y
		},
		"systems": _collect_system_data(),
		"world": world_state
	}

	var save_path = _get_save_path(slot)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: failed to open save file: " + save_path)
		EventBus.ui_notification.emit("The save file could not be written.", "error")
		return false
	file.store_var(save_data)
	file.close()

	GameManager.current_save_slot = slot
	print("SaveManager: saved slot ", slot,
		" | level ", player.stats.level,
		" | pos (", player.grid_position.x, ", ", player.grid_position.y, ")",
		" | hp ", player.stats.current_hp, "/", player.stats.max_hp,
		" | gold ", InventoryManager.gold,
		" | seed ", world_state.get("seed", 0),
		" | enemies ", (world_state.get("enemies", []) as Array).size())

	EventBus.game_saved.emit(slot)
	if slot != AUTOSAVE_SLOT:
		EventBus.ui_notification.emit("Game saved.", "success")
	return true

func autosave() -> bool:
	"""Write the autosave slot if saving is currently allowed. Silent when it is not."""
	if can_save() != "":
		return false
	return save_game(AUTOSAVE_SLOT)

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
	"""Load a save slot. This restarts the World scene from the save - see
	GameManager.load_game(). Returns false when the slot cannot be read."""
	return GameManager.load_game(slot)

func read_save(slot: int) -> Dictionary:
	"""Read a slot and bring it up to the current format. Returns {} when the
	slot is empty, unreadable, or written by a newer version of the game."""
	var raw: Dictionary = _read_save_data(slot)
	if raw.is_empty():
		return {}
	return _migrate(raw)

func apply_systems(save_data: Dictionary):
	"""Restore every system manager from a (migrated) save, in dependency order.
	The World scene calls this once its player exists: SpellManager and
	InventoryManager resolve the "player" uid through GameManager.player.stats."""
	var systems: Dictionary = _dict_at(save_data, "systems")
	for key in systems:
		if not SYSTEM_LOAD_ORDER.has(key):
			print("SaveManager: unknown system '", key, "' in save - ignored")
	var managers = _get_system_managers()
	for key in SYSTEM_LOAD_ORDER:
		if not systems.has(key):
			continue
		var manager = managers.get(key)
		if manager == null or not is_instance_valid(manager) or not manager.has_method("from_dict"):
			push_error("SaveManager: system '" + str(key) + "' has no from_dict() - skipped")
			continue
		manager.from_dict(systems[key])

# === MIGRATIONS ===

func _migrate(save_data: Dictionary) -> Dictionary:
	"""Step an older payload up to SAVE_FORMAT_VERSION, one version at a time.
	Each step only ADDS what its version introduced, so newer code can rely on
	the keys being present."""
	var version: int = _payload_version(save_data)
	if version > SAVE_FORMAT_VERSION:
		# Not a programming error: someone ran a newer build. Unreadable here.
		print("SaveManager: save was written by a newer game version (format v%d) - not readable" % version)
		return {}
	var data: Dictionary = save_data.duplicate(true)
	if version < 2:
		data = _migrate_v1_to_v2(data)
	if version < 3:
		data = _migrate_v2_to_v3(data)
	if version < 4:
		data = _migrate_v3_to_v4(data)
	if version < 5:
		data = _migrate_v4_to_v5(data)
	data["version"] = SAVE_FORMAT_VERSION
	data["migrated_from"] = version
	return data

func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	"""v1 was a flat prototype payload: position, HP, gold, level. Only the gold
	carries over; stats are left empty so the world keeps its default character."""
	return {
		"version": 2,
		"game_version": str(data.get("version", "")),
		"timestamp": data.get("timestamp", 0),
		"player": {
			"stats": {},
			"position_x": int(data.get("position_x", 0)),
			"position_y": int(data.get("position_y", 0))
		},
		"systems": {
			"inventory": {"items": [], "gold": int(data.get("gold", 0)), "equipped_items": {}}
		}
	}

func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	"""v3 added the world. A v2 save has none, so the World scene generates a
	new dungeon and puts the player at its entrance."""
	if not data.has("world"):
		data["world"] = {}
	return data

func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	"""v4 gave every character two weapon sets and dropped the separate ranged
	slot. A ranged weapon carried in that slot becomes the main hand of set two;
	set one, with what was in the hands, stays the set in hand. v4 also added
	what each character has used of its once-a-rest features: nothing, in a
	save from before there were any."""
	var systems = data.get("systems")
	if not (systems is Dictionary):
		return data
	var inventory = systems.get("inventory")
	if inventory is Dictionary:
		var equipped = inventory.get("equipped_items")
		if equipped is Dictionary:
			for uid in equipped:
				var slots = equipped[uid]
				if slots is Dictionary and slots.has("ranged"):
					if not slots.has("main_hand_2"):
						slots["main_hand_2"] = slots["ranged"]
					slots.erase("ranged")
		if not inventory.has("weapon_sets"):
			inventory["weapon_sets"] = {}
	if not systems.has("features"):
		systems["features"] = {"used": {}}
	return data

func _migrate_v4_to_v5(data: Dictionary) -> Dictionary:
	"""v5 replaced the durability points of an item instance with notches. Every
	saved instance - in the pack, equipped, lying on the ground - is converted:
	a weapon, a shield or a piece of armour gets as large a share of its notches
	as it had of its points (a whole piece stays whole) and the new fields,
	empty; a wand keeps its points as charges; anything else just loses the
	key. Saved enemies have no gear entry: their gear is whole."""
	var systems = data.get("systems")
	var inventory = systems.get("inventory") if systems is Dictionary else null
	if inventory is Dictionary:
		if inventory.get("items") is Array:
			for entry in inventory["items"]:
				_migrate_item_v4_to_v5(entry)
		if inventory.get("equipped_items") is Dictionary:
			for uid in inventory["equipped_items"]:
				var slots = inventory["equipped_items"][uid]
				if not (slots is Dictionary):
					continue
				for slot in slots:
					if slots[slot] is Array:
						for entry in slots[slot]:
							_migrate_item_v4_to_v5(entry)
					else:
						_migrate_item_v4_to_v5(slots[slot])
	var world = data.get("world")
	if world is Dictionary and world.get("ground_items") is Array:
		for drop in world["ground_items"]:
			if drop is Dictionary and drop.get("items") is Array:
				for entry in drop["items"]:
					_migrate_item_v4_to_v5(entry)
	return data

func _migrate_item_v4_to_v5(entry):
	"""One saved item instance, from durability points to notches or charges"""
	if not (entry is Dictionary) or not entry.has("current_durability"):
		return
	var points: int = int(entry["current_durability"])
	entry.erase("current_durability")
	var item_id: String = str(entry.get("item_id", ""))
	var item_data: ItemData = ItemDatabase.get_item(item_id)
	if item_data == null:
		return
	if item_data.max_charges > 0:
		entry["charges"] = clampi(points, 0, item_data.max_charges)
		return
	entry.merge(DurabilityManager.points_to_notches(item_id, int(entry.get("quality_modifier", 0)),
		int(entry.get("magic_modifier", 0)), points))

# === SLOT MANAGEMENT ===

func get_save_info(slot: int) -> Dictionary:
	"""Save metadata for the slot UI. Returns {} for an empty/unreadable slot,
	otherwise {timestamp, player_level, character_name, class_id, hp, max_hp,
	gold, zone_id, version, is_autosave}. 'version' is the format the file was
	written in, before migration."""
	var data: Dictionary = read_save(slot)
	if data.is_empty():
		return {}
	var player_data = _dict_at(data, "player")
	var stats = _dict_at(player_data, "stats")
	var systems = _dict_at(data, "systems")
	var inventory = _dict_at(systems, "inventory")
	var zones = _dict_at(systems, "zones")
	return {
		"timestamp": data.get("timestamp", 0),
		"player_level": int(stats.get("level", 1)),
		"character_name": str(stats.get("character_name", "")),
		"class_id": str(stats.get("class_id", "")),
		"position": Vector2i(int(player_data.get("position_x", 0)), int(player_data.get("position_y", 0))),
		"hp": int(stats.get("current_hp", 0)),
		"max_hp": int(stats.get("max_hp", 0)),
		"gold": int(inventory.get("gold", 0)),
		"zone_id": str(zones.get("current_zone_id", "zone_1")),
		"version": int(data.get("migrated_from", SAVE_FORMAT_VERSION)),
		"is_autosave": slot == AUTOSAVE_SLOT
	}

func get_all_slots() -> Array:
	"""Every slot id the game uses: the autosave first, then the manual slots."""
	var slots: Array = [AUTOSAVE_SLOT]
	for i in range(MANUAL_SLOT_COUNT):
		slots.append(i)
	return slots

func get_latest_slot() -> int:
	"""The slot with the newest readable save, or -1 when there is none."""
	var best_slot: int = -1
	var best_time: float = -1.0
	for slot in get_all_slots():
		if not save_exists(slot):
			continue
		var data: Dictionary = read_save(slot)
		if data.is_empty():
			continue
		var stamp: float = float(data.get("timestamp", 0))
		if stamp > best_time:
			best_time = stamp
			best_slot = slot
	return best_slot

func has_any_save() -> bool:
	"""True when at least one slot holds a readable save"""
	return get_latest_slot() >= 0

func save_exists(slot: int) -> bool:
	"""Check if a save file exists in slot"""
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
		"features": FeatureManager,
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
	return save_dir + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
