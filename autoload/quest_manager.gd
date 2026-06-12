# quest_manager.gd
# AutoLoad singleton - quest tracking: main/side/faction/procedural quests, objectives, rewards.
# Advances objectives by listening to EventBus:
#   kill    <- enemy_died      (target_id matches enemy.enemy_type, or "any")
#   collect <- item_picked_up  (target_id matches item_data.item_id)
#   talk    <- dialogue_ended  (target_id matches dialogue_id or npc_id)
#   reach   <- zone_changed    (target_id matches the new zone_id)
# Owned by A6 (World & Story). Hand-authored quests live in data/quests/zone_1_quests.gd.
#
# Quest statuses: "not_started" (no state entry) | "active" | "completed" | "failed".
# Failed quests may be restarted via start_quest(). Completing a quest pays rewards
# and auto-starts next_quest_id when one is set (falling back to quest_available).
extends Node

const Zone1Quests = preload("res://data/quests/zone_1_quests.gd")

# quest_id -> quest definition (see contracts doc for the schema)
var quest_definitions: Dictionary = {}
# quest_id -> runtime state {status: String, objective_progress: {objective_id: int}}
var quest_states: Dictionary = {}
# Monotonic counter so procedural quest ids stay unique across a session/save
var procedural_counter: int = 0

# Procedural generation pools: [enemy_type, plural display label]
const PROC_KILL_TARGETS: Array = [
	["goblin", "Goblins"],
	["skeleton", "Skeletons"],
	["bandit", "Bandits"],
	["wolf", "Wolves"],
]
# [item_id, plural display label]
const PROC_COLLECT_TARGETS: Array = [
	["material_hide", "Hides"],
	["material_iron", "Iron Ingots"],
	["potion_healing_minor", "Minor Healing Potions"],
]

func _ready():
	var defs: Dictionary = Zone1Quests.get_definitions()
	for quest_id in defs:
		register_quest(quest_id, defs[quest_id])

	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.zone_changed.connect(_on_zone_changed)

	print("Quests: QuestManager initialized — ", quest_definitions.size(), " quests registered")

func register_quest(quest_id: String, quest: Dictionary):
	quest_definitions[quest_id] = quest

# === LIFECYCLE ===

func start_quest(quest_id: String) -> bool:
	"""Start a quest. Fails if unknown, already active, or already completed.
	Failed quests restart fresh. Emits EventBus.quest_started."""
	if not quest_definitions.has(quest_id):
		push_error("Quests: start_quest on unknown quest: " + quest_id)
		return false
	var status := get_quest_status(quest_id)
	if status == "active" or status == "completed":
		print("Quests: start_quest ignored — ", quest_id, " is ", status)
		return false

	var definition: Dictionary = quest_definitions[quest_id]
	var progress: Dictionary = {}
	for objective in definition.get("objectives", []):
		progress[str(objective.get("objective_id", ""))] = 0
	quest_states[quest_id] = {
		"status": "active",
		"objective_progress": progress,
	}

	print("Quests: started '", quest_id, "'")
	EventBus.quest_started.emit(quest_id)
	EventBus.notify("Quest started: %s" % definition.get("title", quest_id), "info")
	return true

func complete_quest(quest_id: String):
	"""Mark a quest completed, pay its rewards, emit quest_completed, and
	auto-start next_quest_id (falling back to quest_available if it can't start)."""
	if not quest_definitions.has(quest_id):
		push_error("Quests: complete_quest on unknown quest: " + quest_id)
		return
	if get_quest_status(quest_id) != "active":
		return

	var definition: Dictionary = quest_definitions[quest_id]
	quest_states[quest_id]["status"] = "completed"
	_grant_rewards(definition.get("rewards", {}))

	print("Quests: completed '", quest_id, "'")
	EventBus.quest_completed.emit(quest_id)
	EventBus.notify("Quest complete: %s" % definition.get("title", quest_id), "success")

	var next_quest_id: String = str(definition.get("next_quest_id", ""))
	if next_quest_id != "":
		if not start_quest(next_quest_id):
			EventBus.quest_available.emit(next_quest_id)

func fail_quest(quest_id: String):
	"""Mark an active quest failed. Emits EventBus.quest_failed."""
	if get_quest_status(quest_id) != "active":
		return
	quest_states[quest_id]["status"] = "failed"
	var title: String = quest_definitions.get(quest_id, {}).get("title", quest_id)
	print("Quests: failed '", quest_id, "'")
	EventBus.quest_failed.emit(quest_id)
	EventBus.notify("Quest failed: %s" % title, "error")

func _grant_rewards(rewards: Dictionary):
	"""Pay out a quest's rewards: XP, gold, items, faction reputation."""
	# XP (defensive: headless boots may have no player yet)
	var xp: int = int(rewards.get("xp", 0))
	if xp > 0:
		var player = GameManager.player
		if player != null and is_instance_valid(player):
			var stats = player.get("stats")
			if stats != null and stats.has_method("gain_experience"):
				stats.gain_experience(xp)
			else:
				push_warning("Quests: player has no stats.gain_experience — XP reward skipped")

	# Gold
	var gold_amount: int = int(rewards.get("gold", 0))
	if gold_amount > 0:
		InventoryManager.add_gold(gold_amount)

	# Items
	for entry in rewards.get("items", []):
		var item_id: String = str(entry.get("item_id", ""))
		var count: int = int(entry.get("count", 1))
		for _i in range(count):
			var instance: Dictionary = ItemDatabase.create_item_instance(item_id,
				int(entry.get("quality", 0)), int(entry.get("magic", 0)))
			if instance.is_empty():
				push_error("Quests: reward item not found: " + item_id)
				break
			InventoryManager.add_item(instance)

	# Reputation
	var reputation: Dictionary = rewards.get("reputation", {})
	for faction_id in reputation:
		FactionManager.modify_reputation(str(faction_id), int(reputation[faction_id]))

# === QUERIES ===

func get_quest(quest_id: String) -> Dictionary:
	"""Quest definition enriched with runtime 'status' and 'objective_progress'.
	Returns {} for unknown quests."""
	if not quest_definitions.has(quest_id):
		return {}
	var merged: Dictionary = quest_definitions[quest_id].duplicate(true)
	merged["status"] = get_quest_status(quest_id)
	merged["objective_progress"] = quest_states.get(quest_id, {}).get("objective_progress", {}).duplicate()
	return merged

func get_quest_status(quest_id: String) -> String:
	"""'not_started' | 'active' | 'completed' | 'failed'"""
	return str(quest_states.get(quest_id, {}).get("status", "not_started"))

func get_active_quests() -> Array:
	"""Array of enriched quest Dictionaries (see get_quest) with status 'active'."""
	return _get_quests_with_status("active")

func get_completed_quests() -> Array:
	"""Array of enriched quest Dictionaries with status 'completed'."""
	return _get_quests_with_status("completed")

func _get_quests_with_status(status: String) -> Array:
	var result: Array = []
	for quest_id in quest_states:
		if str(quest_states[quest_id].get("status", "")) == status and quest_definitions.has(quest_id):
			result.append(get_quest(quest_id))
	return result

# === OBJECTIVE AUTO-ADVANCE (EventBus listeners) ===

func _on_enemy_died(enemy):
	"""kill objectives. Enemies may already be freed nodes — read defensively.
	Unknown/missing enemy_type still counts toward 'any' targets."""
	var enemy_type := ""
	if enemy != null and is_instance_valid(enemy):
		var value = enemy.get("enemy_type")
		if value != null:
			enemy_type = str(value)
	_advance_objectives("kill", enemy_type, 1)

func _on_item_picked_up(item_instance):
	"""collect objectives. Credits the instance's full stack_count."""
	if not (item_instance is Dictionary):
		return
	var item_data = item_instance.get("item_data")
	if item_data == null:
		return
	var item_id := str(item_data.get("item_id"))
	if item_id == "" or item_id == "<null>":
		return
	_advance_objectives("collect", item_id, int(item_instance.get("stack_count", 1)))

func _on_dialogue_ended(npc_id: String, dialogue_id: String):
	"""talk objectives — target_id may match either the dialogue_id or the npc_id."""
	_advance_objectives("talk", dialogue_id, 1, npc_id)

func _on_zone_changed(_old_zone_id: String, new_zone_id: String):
	"""reach objectives — target_id matches the zone arrived in."""
	_advance_objectives("reach", new_zone_id, 1)

func _advance_objectives(objective_type: String, target: String, amount: int, alt_target: String = ""):
	"""Tick every matching objective on every active quest; emits quest_advanced
	per progress change and completes quests whose objectives are all done."""
	if amount <= 0:
		return
	for quest_id in quest_states.keys():
		if str(quest_states[quest_id].get("status", "")) != "active":
			continue
		var definition: Dictionary = quest_definitions.get(quest_id, {})
		if definition.is_empty():
			continue
		var progress: Dictionary = quest_states[quest_id].get("objective_progress", {})
		var advanced := false

		for objective in definition.get("objectives", []):
			if str(objective.get("type", "")) != objective_type:
				continue
			var target_id := str(objective.get("target_id", ""))
			var matches: bool = target_id == target \
				or (alt_target != "" and target_id == alt_target) \
				or (objective_type == "kill" and target_id == "any")
			if not matches:
				continue

			var objective_id := str(objective.get("objective_id", ""))
			var required: int = int(objective.get("required_count", 1))
			var current: int = int(progress.get(objective_id, 0))
			if current >= required:
				continue

			var new_progress: int = mini(current + amount, required)
			progress[objective_id] = new_progress
			advanced = true
			EventBus.quest_advanced.emit(quest_id, objective_id, new_progress, required)
			print("Quests: '", quest_id, "' ", objective_id, " ", new_progress, "/", required)
			if new_progress >= required:
				EventBus.notify("Objective complete: %s" % objective.get("description", objective_id), "info")

		if advanced and _are_all_objectives_complete(quest_id):
			complete_quest(quest_id)

func _are_all_objectives_complete(quest_id: String) -> bool:
	var definition: Dictionary = quest_definitions.get(quest_id, {})
	var progress: Dictionary = quest_states.get(quest_id, {}).get("objective_progress", {})
	for objective in definition.get("objectives", []):
		var objective_id := str(objective.get("objective_id", ""))
		if int(progress.get(objective_id, 0)) < int(objective.get("required_count", 1)):
			return false
	return true

# === PROCEDURAL QUESTS ===

func generate_procedural_quest(player_level: int = 1) -> String:
	"""Generate and register a procedural kill/collect quest scaled to player_level;
	returns its quest_id ('' on failure). The quest is registered but NOT started —
	the caller decides when to start_quest it (e.g. a notice board)."""
	player_level = maxi(1, player_level)
	procedural_counter += 1

	var is_kill: bool = randf() < 0.5
	var objective: Dictionary
	var title: String
	var description: String
	var quest_id: String

	if is_kill:
		var pick: Array = PROC_KILL_TARGETS[randi() % PROC_KILL_TARGETS.size()]
		var count: int = randi_range(3, 8)
		quest_id = "proc_%03d_kill_%s" % [procedural_counter, pick[0]]
		title = "Bounty: %s" % pick[1]
		description = "A notice posted in Brackenford: the Guild pays for %d %s culled from the Borderlands." % [count, pick[1].to_lower()]
		objective = {
			"objective_id": "obj_proc_kill",
			"description": "Slay %d %s" % [count, pick[1].to_lower()],
			"type": "kill",
			"target_id": pick[0],
			"required_count": count,
		}
	else:
		var pick: Array = PROC_COLLECT_TARGETS[randi() % PROC_COLLECT_TARGETS.size()]
		var count: int = randi_range(2, 5)
		quest_id = "proc_%03d_collect_%s" % [procedural_counter, pick[0]]
		title = "Supply Run: %s" % pick[1]
		description = "A notice posted in Brackenford: the Guild pays for %d %s delivered before the caravans leave." % [count, pick[1].to_lower()]
		objective = {
			"objective_id": "obj_proc_collect",
			"description": "Gather %d %s" % [count, pick[1].to_lower()],
			"type": "collect",
			"target_id": pick[0],
			"required_count": count,
		}

	var required: int = int(objective.get("required_count", 1))
	var quest: Dictionary = {
		"quest_id": quest_id,
		"title": title,
		"description": description,
		"quest_type": "procedural",
		"giver_npc_id": "notice_board",
		"objectives": [objective],
		"rewards": {
			"xp": 40 + 20 * player_level + 10 * required,
			"gold": 20 + 10 * player_level + 5 * required,
			"items": [],
			"reputation": {"merchants_guild": 2},
		},
		"next_quest_id": "",
		"faction_id": "",
	}

	register_quest(quest_id, quest)
	print("Quests: generated procedural quest '", quest_id, "' (level ", player_level, ")")
	return quest_id

# === DATA EXPORT/IMPORT (for saving) ===

func to_dict() -> Dictionary:
	"""Export quest states + procedurally generated definitions (so loads never
	reference a quest that no longer exists). Hand-authored definitions are static."""
	var procedural_definitions: Dictionary = {}
	for quest_id in quest_definitions:
		if str(quest_definitions[quest_id].get("quest_type", "")) == "procedural":
			procedural_definitions[quest_id] = quest_definitions[quest_id].duplicate(true)
	return {
		"quest_states": quest_states.duplicate(true),
		"procedural_definitions": procedural_definitions,
		"procedural_counter": procedural_counter,
	}

func from_dict(data: Dictionary):
	"""Restore quest states + re-register saved procedural definitions.
	States referencing unknown quests are dropped with a warning."""
	procedural_counter = int(data.get("procedural_counter", procedural_counter))

	var procedural_definitions: Dictionary = data.get("procedural_definitions", {})
	for quest_id in procedural_definitions:
		register_quest(quest_id, procedural_definitions[quest_id])

	quest_states.clear()
	var loaded_states: Dictionary = data.get("quest_states", {})
	for quest_id in loaded_states:
		if not quest_definitions.has(quest_id):
			push_warning("Quests: save referenced unknown quest '" + str(quest_id) + "' — dropped")
			continue
		var entry: Dictionary = loaded_states[quest_id]
		quest_states[quest_id] = {
			"status": str(entry.get("status", "not_started")),
			"objective_progress": entry.get("objective_progress", {}).duplicate(),
		}
	print("Quests: loaded ", quest_states.size(), " quest states, ",
		procedural_definitions.size(), " procedural definitions")
